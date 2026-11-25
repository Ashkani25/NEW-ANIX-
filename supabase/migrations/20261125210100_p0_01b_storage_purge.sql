-- P0 #1b: storage leftovers after account deletion, core project (eisstodgncimypdawisy).
--
-- Deleting storage.objects rows in SQL (what nx_delete_account did) removes the row but never the blob in the bucket
-- store, and once the row is gone the Storage API cannot find the blob any more. Instead:
--  * nx_storage_purge_queue: (bucket, path) of files still left when an account is deleted (no user ids, just paths).
--  * nx_delete_account queues the leftovers (instead of deleting rows) and kicks the purge after commit.
--  * Edge Function supabase/functions/nx-storage-purge (service role) claims queued paths with nx_storage_purge_claim,
--    removes them through the Storage API (blob + row) and reports back with nx_storage_purge_done.
--    Optional orphan sweep (nx_storage_purge_enqueue_orphans, off unless the function runs with PURGE_ORPHANS=1):
--    objects whose recorded owner no longer exists in auth.users (accounts deleted before this migration).
--  * _nx_storage_purge_kick(): pg_net POST to the function; a no-op until the vault holds nx_storage_purge_secret
--    (and optionally nx_core_functions_url). Called by nx_delete_account and by the pg_cron job nx-storage-purge
--    every 15 minutes while work is pending. Deploy notes: supabase/functions/nx-storage-purge/README.md.
-- No user data is removed by this migration itself.

create table if not exists public.nx_storage_purge_queue (
  id bigserial primary key,
  bucket text not null,
  path text not null,
  queued_at timestamptz not null default now(),
  claimed_at timestamptz,
  attempts int not null default 0,
  last_error text,
  done_at timestamptz,
  unique (bucket, path)
);
alter table public.nx_storage_purge_queue enable row level security;
revoke all on table public.nx_storage_purge_queue from anon, authenticated;
revoke all on sequence public.nx_storage_purge_queue_id_seq from anon, authenticated;
create index if not exists nx_storage_purge_queue_pending on public.nx_storage_purge_queue (queued_at) where done_at is null;

-- POST to the purge function after commit; silent no-op until the secret is configured, never breaks the caller.
create or replace function public._nx_storage_purge_kick()
returns void language plpgsql security definer set search_path = public
as $$
declare
  secret text := _nx_vault('nx_storage_purge_secret');
  base text := coalesce(_nx_vault('nx_core_functions_url'), 'https://eisstodgncimypdawisy.supabase.co/functions/v1');
begin
  if secret is null or secret = '' then return; end if;
  if not exists (select 1 from nx_storage_purge_queue where done_at is null and attempts < 10) then return; end if;
  perform net.http_post(url := rtrim(base, '/') || '/nx-storage-purge',
                        headers := jsonb_build_object('Content-Type', 'application/json', 'x-nx-purge-secret', secret),
                        body := '{}'::jsonb, timeout_milliseconds := 30000);
exception when others then
  null;
end $$;

-- service role (Edge Function): take up to p_limit pending paths (not claimed in the last 5 minutes, < 10 attempts)
create or replace function public.nx_storage_purge_claim(p_limit int default 100)
returns table(id bigint, bucket text, path text)
language plpgsql security definer set search_path = public
as $$
begin
  return query
  update nx_storage_purge_queue q set claimed_at = now(), attempts = q.attempts + 1
   where q.id in (select x.id from nx_storage_purge_queue x
                   where x.done_at is null and x.attempts < 10
                     and (x.claimed_at is null or x.claimed_at < now() - interval '5 minutes')
                   order by x.queued_at limit greatest(1, least(coalesce(p_limit, 100), 500))
                   for update skip locked)
  returning q.id, q.bucket, q.path;
end $$;

-- service role: mark paths done (p_error null) or failed (kept for a retry, up to 10 attempts)
create or replace function public.nx_storage_purge_done(p_ids bigint[], p_error text default null)
returns int language plpgsql security definer set search_path = public
as $$
declare n int;
begin
  if p_error is null then
    update nx_storage_purge_queue set done_at = now(), last_error = null where id = any(p_ids);
  else
    update nx_storage_purge_queue set last_error = left(p_error, 300), claimed_at = null where id = any(p_ids);
  end if;
  get diagnostics n = row_count;
  return n;
end $$;

-- service role: queue objects whose recorded owner no longer exists (accounts deleted before the queue existed).
-- Only the owner columns are trusted (folder names of shared buckets can be chat ids, not user ids).
-- p_dry_run = true only counts.
create or replace function public.nx_storage_purge_enqueue_orphans(p_dry_run boolean default true)
returns int language plpgsql security definer set search_path = public, storage
as $$
declare n int;
begin
  if coalesce(p_dry_run, true) then
    select count(*) into n from storage.objects o
     where coalesce(o.owner_id, o.owner::text) is not null
       and coalesce(o.owner_id, o.owner::text) ~ '^[0-9a-f-]{36}$'
       and not exists (select 1 from auth.users u where u.id::text = coalesce(o.owner_id, o.owner::text))
       and not exists (select 1 from nx_storage_purge_queue q where q.bucket = o.bucket_id and q.path = o.name);
    return n;
  end if;
  insert into nx_storage_purge_queue(bucket, path)
  select o.bucket_id, o.name from storage.objects o
   where coalesce(o.owner_id, o.owner::text) is not null
     and coalesce(o.owner_id, o.owner::text) ~ '^[0-9a-f-]{36}$'
     and not exists (select 1 from auth.users u where u.id::text = coalesce(o.owner_id, o.owner::text))
  on conflict (bucket, path) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public._nx_storage_purge_kick(), public.nx_storage_purge_claim(int),
  public.nx_storage_purge_done(bigint[], text), public.nx_storage_purge_enqueue_orphans(boolean)
  from public, anon, authenticated;
grant execute on function public.nx_storage_purge_claim(int), public.nx_storage_purge_done(bigint[], text),
  public.nx_storage_purge_enqueue_orphans(boolean) to service_role;

-- retry loop: every 15 minutes, only does something while paths are pending and the secret is set
do $cron$
begin
  if exists (select 1 from cron.job where jobname = 'nx-storage-purge') then
    perform cron.unschedule('nx-storage-purge');
  end if;
  perform cron.schedule('nx-storage-purge', '*/15 * * * *', 'select public._nx_storage_purge_kick()');
end $cron$;

-- nx_delete_account: same as P0 #1 except the storage step (queue instead of deleting rows).
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
