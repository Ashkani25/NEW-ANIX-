-- P0 #1: account deletion (store requirement). Core/auth project (eisstodgncimypdawisy).
--
-- nx_delete_account(p_confirm, p_password, p_dry_run): the signed-in user deletes their own account.
--  * p_confirm must be the literal 'DELETE' (typed by the user in the confirm dialog).
--  * Accounts with a password must re-enter it (checked against auth.users with bcrypt, rate-limited 5 / 15 min).
--    Username accounts store 'nx#' || password; the client sends the stored form.
--  * p_dry_run = true only validates (the client then removes its storage files through the Storage API and calls
--    again for real).
--  * Shared spaces survive: group chats / communities pass ownership to the next member (admins first), empty ones are
--    removed; direct chats stay for the other person. Messages the user wrote stay in other people's chats but are
--    anonymised (author -> null, name '[deleted]'); media messages are blanked. Tournaments they created pass to the
--    platform owner. Everything else of theirs is deleted (profile, wallet, posts, comments, follows, memberships,
--    device tokens, reports they filed, error logs, storage objects), and finally the auth.users row.
--  * The games project is told to forget the user through the existing pg_net bridge (nx_bridge_forget_user).
--  * The platform owner account cannot delete itself (transfer ownership first).

-- Shared spaces must not be cascade-deleted with their creator.
alter table public.nx_chats alter column owner drop not null;
alter table public.nx_chats drop constraint nx_chats_owner_fkey,
  add constraint nx_chats_owner_fkey foreign key (owner) references auth.users(id) on delete set null;
alter table public.nx_communities alter column owner drop not null;
alter table public.nx_communities drop constraint nx_communities_owner_fkey,
  add constraint nx_communities_owner_fkey foreign key (owner) references auth.users(id) on delete set null;

-- The chats guard pins owner on every update; it may now only become NULL, and only once the owner's auth row is gone
-- (the ON DELETE SET NULL action above). Nobody can reassign or clear a live owner.
create or replace function public.nx_chats_guard()
returns trigger language plpgsql
as $$
begin
  new.id := old.id; new.kind := old.kind; new.dm_key := old.dm_key; new.created_at := old.created_at;
  if not (new.owner is null and old.owner is not null
          and not exists (select 1 from auth.users where id = old.owner)) then
    new.owner := old.owner;
  end if;
  return new;
end $$;

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

-- Files the signed-in user owns, so the client can remove them through the Storage API before deleting the account.
create or replace function public.nx_my_storage_objects()
returns table(bucket text, path text)
language sql stable security definer set search_path = public
as $$
  select o.bucket_id::text, o.name::text from storage.objects o
   where auth.uid() is not null
     and (o.owner_id = auth.uid()::text or o.owner = auth.uid()
          or (o.bucket_id in ('nx-media', 'avatars') and (storage.foldername(o.name))[1] = auth.uid()::text))
$$;
revoke all on function public.nx_my_storage_objects() from public, anon;
grant execute on function public.nx_my_storage_objects() to authenticated;
