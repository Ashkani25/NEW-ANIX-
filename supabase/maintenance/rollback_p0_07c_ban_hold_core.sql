-- Rollback for migrations/20261125210200_p0_07c_ban_hold.sql (core).
-- Restores nx_delete_account(text, text, boolean) as of P0 #1b (storage purge queue), the P0 #7 profiles trigger and
-- username check, and removes the hold triggers/functions. The nx_ban_holds table and the Vault pepper are kept
-- (never drop data); without the triggers they are inert.
drop trigger if exists nx_ban_hold_on_delete on auth.users;
drop trigger if exists nx_ban_hold_signup on auth.users;
drop function if exists public.nx_delete_account(text, text, boolean, text);
create or replace function public.nx_delete_account(p_confirm text, p_password text default null, p_dry_run boolean default false)
returns jsonb
language plpgsql security definer
set search_path = public, extensions
as $$
declare
  me uuid := auth.uid();
  pw text;
  r record;
  nxt uuid;
  platform_owner uuid;
  url text; key text;
  t text;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  if coalesce(p_confirm, '') <> 'DELETE' then return jsonb_build_object('ok', false, 'error', 'confirm_required'); end if;
  if nx_is_owner(me) then return jsonb_build_object('ok', false, 'error', 'owner_cannot_delete'); end if;
  select encrypted_password into pw from auth.users where id = me;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if coalesce(pw, '') <> '' then
    perform _nx_rate('delete_account_pw', 5, interval '15 minutes');
    if p_password is null or p_password = '' or extensions.crypt(p_password, pw) <> pw then
      return jsonb_build_object('ok', false, 'error', 'wrong_password');
    end if;
  end if;
  if coalesce(p_dry_run, false) then return jsonb_build_object('ok', true, 'dry_run', true); end if;

  perform set_config('nx.trusted', '1', true);
  select user_id into platform_owner from nx_staff where role = 'owner' and user_id <> me order by granted_at limit 1;

  -- chats: leave all; an owner hands the chat to the next member (admins first); empty chats go away
  for r in select chat_id, role from nx_chat_members where user_id = me loop
    delete from nx_chat_members where chat_id = r.chat_id and user_id = me;
    select user_id into nxt from nx_chat_members where chat_id = r.chat_id order by (role = 'admin') desc, joined_at limit 1;
    if nxt is null then
      delete from nx_chats where id = r.chat_id;
    elsif r.role = 'owner' then
      perform set_config('nx.role_change', 'on', true);
      update nx_chat_members set role = 'owner' where chat_id = r.chat_id and user_id = nxt;
    end if;
  end loop;

  -- communities: same rule
  for r in select community_id, role from nx_community_members where user_id = me loop
    delete from nx_community_members where community_id = r.community_id and user_id = me;
    select user_id into nxt from nx_community_members where community_id = r.community_id
      order by (role = 'admin') desc, joined_at limit 1;
    if nxt is null then
      delete from nx_communities where id = r.community_id;
    elsif r.role = 'owner' then
      update nx_community_members set role = 'owner' where community_id = r.community_id and user_id = nxt;
    end if;
  end loop;
  delete from nx_communities c where c.owner = me
    and not exists (select 1 from nx_community_members m where m.community_id = c.id);

  -- messages written in other people's chats stay, anonymised; media is blanked (the files are deleted below)
  update nx_messages set deleted = true, text = '', payload = '{}'::jsonb
   where author = me and kind in ('photo', 'audio', 'file');
  update nx_messages set author_name = '[deleted]' where author = me;

  -- tournaments they organise pass to the platform owner instead of vanishing for every entrant
  if platform_owner is not null then
    update nx_tournaments set created_by = platform_owner where created_by = me;
  end if;

  -- rows that point at the user without a foreign key
  foreach t in array array['client_errors.user_id', 'nx_user_reports.reporter', 'nx_match_secrets.user_id',
                           'oracle_usage.user_id', 'nx_admin_code_attempts.user_id', 'admin_code_attempts.user_id',
                           'nx_t_code_attempts.user_id', 'nx_t_reports.user_id', 'nx_bridge_applied.user_id',
                           'game_moves.user_id', 'cup_payouts.user_id', 'cup_payouts.paid_by', 'cup_matches.p1',
                           'cup_matches.p2', 'cup_games.home_user'] loop
    if to_regclass('public.' || split_part(t, '.', 1)) is not null then
      execute format('delete from public.%I where %I = $1', split_part(t, '.', 1), split_part(t, '.', 2)) using me;
    end if;
  end loop;

  -- storage: the client removes its files through the Storage API first. Whatever is left (legacy avatars / chat
  -- buckets have no client delete policy) is queued for the nx-storage-purge Edge Function, which removes blob + row
  -- through the Storage API (deleting the row here would orphan the blob for good). Kicked after commit (pg_net).
  insert into nx_storage_purge_queue(bucket, path)
  select o.bucket_id, o.name from storage.objects o
   where o.owner_id = me::text or o.owner = me
      or (o.bucket_id in ('nx-media', 'avatars') and (storage.foldername(o.name))[1] = me::text)
  on conflict (bucket, path) do update set done_at = null, attempts = 0, last_error = null, queued_at = now();
  perform _nx_storage_purge_kick();

  -- games project: forget the mirror profile and game data (async, after commit)
  url := _nx_vault('nx_games_url'); key := _nx_vault('nx_games_service_key');
  if url is not null and key is not null then
    perform net.http_post(url := url || '/rest/v1/rpc/nx_bridge_forget_user',
                          headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', key,
                                                        'Authorization', 'Bearer ' || key),
                          body := jsonb_build_object('p_user', me), timeout_milliseconds := 8000);
  end if;

  -- finally the auth user (cascades profiles, wallet, posts, follows, memberships, tokens, sessions, ...)
  delete from auth.users where id = me;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.nx_delete_account(text, text, boolean) from public, anon;
grant execute on function public.nx_delete_account(text, text, boolean) to authenticated;

create or replace function public._nx_profiles_safety()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if (tg_op = 'INSERT' or new.username is distinct from old.username) and not _nx_name_rules_bypass() then
    if _nx_username_reserved(new.username) then raise exception 'username_reserved' using errcode = '22023'; end if;
    if _nx_username_bad(new.username) then raise exception 'username_profane' using errcode = '22023'; end if;
  end if;
  if (tg_op = 'INSERT' or new.display_name is distinct from old.display_name) and nx_profanity_check(new.display_name) then
    raise exception 'name_profane' using errcode = '22023';
  end if;
  if (tg_op = 'INSERT' or new.bio is distinct from old.bio) and new.bio is not null then
    new.bio := nx_profanity_mask(new.bio);
  end if;
  return new;
end $$;

CREATE OR REPLACE FUNCTION public.nx_username_available(p_username text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select lower(btrim(coalesce(p_username, ''))) ~ '^[a-z0-9_.]{3,20}$'
     and not public._nx_username_reserved(btrim(p_username))
     and not public._nx_username_bad(btrim(p_username))
     and not exists(select 1 from public.profiles where lower(username) = lower(btrim(p_username))) $function$;

drop function if exists public.nx_owner_ban_hold_clear(uuid, text), public.nx_owner_ban_holds(int), public.nx_install_held(text),
  public._nx_ban_hold_signup(), public._nx_ban_hold_on_delete(), public._nx_ban_hold_put(text, text, text, timestamptz),
  public._nx_ban_held(text, text), public._nx_hold_hash(text, text), public._nx_hold_norm(text, text);
