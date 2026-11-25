-- Rollback for migrations/20261125210100_p0_01b_storage_purge.sql (core).
-- Restores the P0 #1 nx_delete_account (deletes leftover storage rows in SQL) and removes the purge plumbing.
-- The queue table is kept (never drop data); paths still pending there can be purged by hand.
do $cron$
begin
  if exists (select 1 from cron.job where jobname = 'nx-storage-purge') then
    perform cron.unschedule('nx-storage-purge');
  end if;
end $cron$;

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

  -- storage objects they own (the client removes the files through the Storage API first; this clears leftovers)
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects
   where owner_id = me::text or owner = me
      or (bucket_id in ('nx-media', 'avatars') and (storage.foldername(name))[1] = me::text);

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

drop function if exists public.nx_storage_purge_enqueue_orphans(boolean);
drop function if exists public.nx_storage_purge_done(bigint[], text);
drop function if exists public.nx_storage_purge_claim(int);
drop function if exists public._nx_storage_purge_kick();
