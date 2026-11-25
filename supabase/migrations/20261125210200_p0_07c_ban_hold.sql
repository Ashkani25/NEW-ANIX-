-- P0 #7c: ban evasion hold, core project (eisstodgncimypdawisy).
--
-- A banned user must not be able to delete the account and sign up again under the same identity. When a banned
-- account is deleted (by the user through nx_delete_account, or by staff / the auth admin API: a BEFORE DELETE trigger
-- on auth.users covers every path) we keep a hold: keyed SHA-256 HMACs only, never the plain values, of
--   * the normalised username (lower case),
--   * the normalised e-mail (lower case, "+tag" removed, dots removed for gmail.com / googlemail.com),
--   * the app's random install id (generated on the phone, not a hardware id), when the client sends it.
-- The HMAC key (pepper) lives in Vault (nx_ban_hold_pepper, created here if missing; never rotate it, or existing holds
-- stop matching). The hold lasts as long as the ban: auth.users.banned_until when it is a finite date, otherwise until
-- staff clear it (bans in this app are indefinite until lifted). Expired holds are ignored.
-- Checks:
--   * sign-up / e-mail change (BEFORE INSERT OR UPDATE trigger on auth.users): held e-mail or install id -> refused
--     ('banned'); the install id is removed from the stored user metadata right away.
--   * username claim (profiles trigger: sign-up, nx_set_username, any rename) -> 'username_reserved';
--     nx_username_available says false.
--   * login: nx_install_held(p_install) for the client right after sign-in (signs out on true); the nx-login Edge Function
--     checks the same when the app sends its install id.
-- Staff: nx_owner_ban_holds() lists holds (no hashes), nx_owner_ban_hold_clear(p_group, p_username) lifts one.
-- No existing data is changed.

do $pep$
begin
  if not exists (select 1 from vault.secrets where name = 'nx_ban_hold_pepper') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'nx_ban_hold_pepper',
      'ANIX ban-hold HMAC key. Never rotate: existing holds would stop matching.');
  end if;
end $pep$;

create table if not exists public.nx_ban_holds (
  id bigserial primary key,
  grp uuid not null,
  kind text not null check (kind in ('username', 'email', 'device')),
  hash text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  unique (kind, hash)
);
alter table public.nx_ban_holds enable row level security;
revoke all on table public.nx_ban_holds from anon, authenticated;
revoke all on sequence public.nx_ban_holds_id_seq from anon, authenticated;
create index if not exists nx_ban_holds_grp on public.nx_ban_holds (grp);

-- normalised value per kind (null = nothing to hold)
create or replace function public._nx_hold_norm(p_kind text, p_value text)
returns text language plpgsql immutable
as $$
declare v text := lower(btrim(coalesce(p_value, ''))); l text; d text;
begin
  if v = '' then return null; end if;
  if p_kind = 'username' then
    return v;
  elsif p_kind = 'email' then
    if position('@' in v) = 0 then return null; end if;
    l := split_part(v, '@', 1); d := split_part(v, '@', 2);
    l := split_part(l, '+', 1);
    if d in ('gmail.com', 'googlemail.com') then l := replace(l, '.', ''); d := 'gmail.com'; end if;
    if l = '' or d = '' then return null; end if;
    return l || '@' || d;
  elsif p_kind = 'device' then
    if v !~ '^[a-z0-9-]{16,80}$' then return null; end if;
    return v;
  end if;
  return null;
end $$;

create or replace function public._nx_hold_hash(p_kind text, p_value text)
returns text language plpgsql stable security definer set search_path = public, extensions
as $$
declare n text := _nx_hold_norm(p_kind, p_value); k text := _nx_vault('nx_ban_hold_pepper');
begin
  if n is null or k is null or k = '' then return null; end if;
  return encode(extensions.hmac(p_kind || ':' || n, k, 'sha256'), 'hex');
end $$;

create or replace function public._nx_ban_held(p_kind text, p_value text)
returns boolean language plpgsql stable security definer set search_path = public
as $$
declare h text;
begin
  if p_value is null or btrim(p_value) = '' then return false; end if;
  h := _nx_hold_hash(p_kind, p_value);
  if h is null then return false; end if;
  return exists (select 1 from nx_ban_holds where kind = p_kind and hash = h and (expires_at is null or expires_at > now()));
end $$;

-- record one hold group (skips values that normalise to nothing); a longer / indefinite expiry wins on conflict
create or replace function public._nx_ban_hold_put(p_username text, p_email text, p_install text, p_expires timestamptz)
returns uuid language plpgsql security definer set search_path = public
as $$
declare g uuid := gen_random_uuid(); r record;
begin
  for r in select k, _nx_hold_hash(k, v) h from (values ('username', p_username), ('email', p_email), ('device', p_install)) x(k, v) loop
    if r.h is not null then
      insert into nx_ban_holds(grp, kind, hash, expires_at) values (g, r.k, r.h, p_expires)
      on conflict (kind, hash) do update
        set expires_at = case when nx_ban_holds.expires_at is null or excluded.expires_at is null then null
                              else greatest(nx_ban_holds.expires_at, excluded.expires_at) end,
            grp = excluded.grp, created_at = now();
    end if;
  end loop;
  return g;
end $$;

-- BEFORE DELETE on auth.users: a banned account leaves a hold behind (profile + flags still exist at this point)
create or replace function public._nx_ban_hold_on_delete()
returns trigger language plpgsql security definer set search_path = public
as $$
declare un text; exp timestamptz;
begin
  if exists (select 1 from nx_account_flags f where f.user_id = old.id and f.banned)
     or (old.banned_until is not null and old.banned_until > now()) then
    select p.username into un from profiles p where p.id = old.id;
    exp := case when old.banned_until is null or old.banned_until = 'infinity'::timestamptz
                     or old.banned_until > now() + interval '50 years' then null
                else old.banned_until end;
    perform _nx_ban_hold_put(un, old.email, nullif(current_setting('nx.delete_install', true), ''), exp);
  end if;
  return old;
exception when others then
  return old; -- a hold must never block a deletion
end $$;
drop trigger if exists nx_ban_hold_on_delete on auth.users;
create trigger nx_ban_hold_on_delete before delete on auth.users
  for each row execute function public._nx_ban_hold_on_delete();

-- BEFORE INSERT / e-mail or metadata change on auth.users: held e-mail or install id cannot sign up again.
-- The install id rides in raw_user_meta_data.nx_install and is never stored.
create or replace function public._nx_ban_hold_signup()
returns trigger language plpgsql security definer set search_path = public
as $$
declare inst text := new.raw_user_meta_data ->> 'nx_install';
begin
  if new.raw_user_meta_data ? 'nx_install' then
    new.raw_user_meta_data := new.raw_user_meta_data - 'nx_install';
  end if;
  if _nx_name_rules_bypass() then return new; end if;
  if (tg_op = 'INSERT' or new.email is distinct from old.email) and _nx_ban_held('email', new.email) then
    raise exception 'banned' using errcode = 'P0001', detail = 'ban_hold';
  end if;
  if inst is not null and _nx_ban_held('device', inst) then
    raise exception 'banned' using errcode = 'P0001', detail = 'ban_hold';
  end if;
  return new;
end $$;
drop trigger if exists nx_ban_hold_signup on auth.users;
create trigger nx_ban_hold_signup before insert or update of email, raw_user_meta_data on auth.users
  for each row execute function public._nx_ban_hold_signup();

-- username claim: same rule set as reserved names (P0 #7), plus held usernames
create or replace function public._nx_profiles_safety()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if (tg_op = 'INSERT' or new.username is distinct from old.username) and not _nx_name_rules_bypass() then
    if _nx_username_reserved(new.username) then raise exception 'username_reserved' using errcode = '22023'; end if;
    if _nx_username_bad(new.username) then raise exception 'username_profane' using errcode = '22023'; end if;
    if _nx_ban_held('username', new.username) then raise exception 'username_reserved' using errcode = '22023'; end if;
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
     and not public._nx_ban_held('username', btrim(p_username))
     and not exists(select 1 from public.profiles where lower(username) = lower(btrim(p_username))) $function$;

-- login / app start: is this phone's install id under a hold? (only answers for the id the caller sends)
create or replace function public.nx_install_held(p_install text)
returns boolean language sql stable security definer set search_path = public
as $$ select public._nx_ban_held('device', p_install) $$;

-- staff: list holds (never the hashes) and lift one group (by id, or by the username it was recorded for)
create or replace function public.nx_owner_ban_holds(p_limit int default 200)
returns jsonb language plpgsql stable security definer set search_path = public
as $$
declare g text := _nx_admin_guard('users');
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  return jsonb_build_object('ok', true, 'holds', coalesce((select jsonb_agg(x order by x.created_at desc) from (
    select grp as "group", array_agg(kind order by kind) as kinds, max(created_at) as created_at, max(expires_at) as expires_at,
           bool_or(expires_at is null) as indefinite
      from nx_ban_holds group by grp
     order by max(created_at) desc limit greatest(1, least(coalesce(p_limit, 200), 1000))) x), '[]'::jsonb));
end $$;

create or replace function public.nx_owner_ban_hold_clear(p_group uuid default null, p_username text default null)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare g text := _nx_admin_guard('users'); grp_ uuid := p_group; n int;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  if grp_ is null and p_username is not null then
    select h.grp into grp_ from nx_ban_holds h where h.kind = 'username' and h.hash = _nx_hold_hash('username', p_username);
  end if;
  if grp_ is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  delete from nx_ban_holds where grp = grp_;
  get diagnostics n = row_count;
  perform _nx_owner_log('ban_hold_clear', null, jsonb_build_object('group', grp_, 'rows', n));
  return jsonb_build_object('ok', true, 'cleared', n);
end $$;

revoke all on function public._nx_hold_norm(text, text), public._nx_hold_hash(text, text), public._nx_ban_held(text, text),
  public._nx_ban_hold_put(text, text, text, timestamptz), public._nx_ban_hold_on_delete(), public._nx_ban_hold_signup()
  from public, anon, authenticated;
revoke all on function public.nx_install_held(text), public.nx_owner_ban_holds(int), public.nx_owner_ban_hold_clear(uuid, text)
  from public;
grant execute on function public.nx_install_held(text) to anon, authenticated, service_role;
revoke all on function public.nx_owner_ban_holds(int), public.nx_owner_ban_hold_clear(uuid, text) from anon;
grant execute on function public.nx_owner_ban_holds(int), public.nx_owner_ban_hold_clear(uuid, text) to authenticated;

-- nx_delete_account gains p_install (the phone's install id, only used for a ban hold). The old 3-argument version is
-- replaced so PostgREST calls with or without p_install resolve to one function.
drop function if exists public.nx_delete_account(text, text, boolean);
create or replace function public.nx_delete_account(p_confirm text, p_password text default null, p_dry_run boolean default false,
                                                    p_install text default null)
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

  -- this phone's install id, for the ban hold recorded by the auth.users delete trigger when the account is banned
  perform set_config('nx.delete_install', coalesce(left(p_install, 80), ''), true);

  -- finally the auth user (cascades profiles, wallet, posts, follows, memberships, tokens, sessions, ...)
  delete from auth.users where id = me;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.nx_delete_account(text, text, boolean, text) from public, anon;
grant execute on function public.nx_delete_account(text, text, boolean, text) to authenticated;
