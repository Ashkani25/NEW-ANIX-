-- P0 #7: social safety, games project (eyzafhrefnqlwcjpcdyg).
-- * Same profanity filter as core: room titles and tournament titles rejected (name_profane), room chat and tournament
--   descriptions masked.
-- * nx_bans / user_blocks: mirrors of core's nx_account_flags.banned and user_blocks, written by core over the pg_net
--   bridge (nx_bridge_bans_put / nx_bridge_blocks_put, service_role only).
-- * Bans: a banned user cannot create or join rooms (incl. quick match seats), take seats, push moves, write room chat,
--   enter tournaments or send invites (BEFORE INSERT triggers, error 'banned'). Blocks: no invites between a blocked
--   pair (and nx_invite's existing user_blocks check now works: the table was missing on this project).
-- Profanity filter + reserved usernames, shared by both projects (included verbatim in the P0 #7 migrations).
-- Normalisation: lower case, Arabic -> Persian letters (ي ى -> ی, ك -> ک, ة ۀ -> ه, أ إ آ -> ا, ؤ -> و), Persian/Arabic
-- digits -> ASCII, zero-width chars / bidi marks / tatweel / diacritics removed, leet (0 1 3 4 5 7 8 @ $) mapped, all
-- punctuation removed inside a token ("f-u-c-k", "کس‌کش"), repeated letters collapsed ("fuuuck", "کیییر").
-- A word matches a token when equal after collapsing runs to 2, or to 1 when the word has no double letters or is
-- 4+ letters long; words flagged substr also match inside longer tokens (only long, unambiguous words).

create table if not exists public.nx_profanity_words (
  word text primary key,
  w2 text not null,
  w1 text not null,
  substr boolean not null default false,
  lang text not null default 'fa'
);
alter table public.nx_profanity_words enable row level security;
revoke all on table public.nx_profanity_words from anon, authenticated;
create index if not exists nx_profanity_words_w2 on public.nx_profanity_words (w2);
create index if not exists nx_profanity_words_w1 on public.nx_profanity_words (w1);

create or replace function public._nx_text_norm(p text)
returns text language sql immutable parallel safe
as $$
  select translate(
           translate(
             lower(regexp_replace(coalesce(p, ''), '[\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF\u00AD\u0640\u064B-\u065F\u0670\u06D6-\u06ED]', '', 'g')),
             'يىكةۀأإآٱؤ٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
             'ییکههااااو01234567890123456789'),
           '0134578@$', 'oieastbas')
$$;

create or replace function public._nx_token_key(p text, runs int)
returns text language sql immutable parallel safe
as $$
  select case when runs = 1
              then regexp_replace(regexp_replace(public._nx_text_norm(p), '[[:space:][:punct:]،؛؟«»…٫٬]', '', 'g'), '(.)\1+', '\1', 'g')
              else regexp_replace(regexp_replace(public._nx_text_norm(p), '[[:space:][:punct:]،؛؟«»…٫٬]', '', 'g'), '(.)\1{2,}', '\1\1', 'g') end
$$;

create or replace function public._nx_bad_token(p text)
returns boolean language plpgsql stable security definer set search_path = public
as $$
declare c1 text := _nx_token_key(p, 1); c2 text := _nx_token_key(p, 2);
begin
  if c1 = '' then return false; end if;
  return exists (select 1 from nx_profanity_words w
                  where w.w2 = c2
                     or (w.w1 = c1 and (w.w1 = w.w2 or char_length(w.w1) >= 4))
                     or (w.substr and char_length(c1) > char_length(w.w1) and position(w.w1 in c1) > 0));
end $$;

-- true when the text contains a listed word
create or replace function public.nx_profanity_check(p text)
returns boolean language plpgsql stable security definer set search_path = public
as $$
declare t text;
begin
  if p is null or btrim(p) = '' then return false; end if;
  for t in select distinct m[1] from regexp_matches(p, '([^[:space:],.!?;:"''()\[\]{}<>/\\|،؛؟«»…*~^=+]+)', 'g') m loop
    if _nx_bad_token(t) then return true; end if;
  end loop;
  return false;
end $$;

-- the text with every listed word replaced by asterisks of the same length
create or replace function public.nx_profanity_mask(p text)
returns text language plpgsql stable security definer set search_path = public
as $$
declare t text; o text := p;
begin
  if p is null or btrim(p) = '' then return p; end if;
  for t in select distinct m[1] from regexp_matches(p, '([^[:space:],.!?;:"''()\[\]{}<>/\\|،؛؟«»…*~^=+]+)', 'g') m loop
    if _nx_bad_token(t) then o := replace(o, t, repeat('*', char_length(t))); end if;
  end loop;
  return o;
end $$;

-- usernames ([a-z0-9_.]): each part between _ and . and the whole name without separators
create or replace function public._nx_username_bad(p text)
returns boolean language plpgsql stable security definer set search_path = public
as $$
declare part text; whole text := regexp_replace(lower(coalesce(p, '')), '[_.]', '', 'g');
begin
  if whole = '' then return false; end if;
  foreach part in array regexp_split_to_array(lower(p), '[_.]+') loop
    if part <> '' and _nx_bad_token(part) then return true; end if;
  end loop;
  return _nx_bad_token(whole);
end $$;

create or replace function public._nx_username_reserved(p text)
returns boolean language sql immutable
as $$
  select regexp_replace(lower(coalesce(p, '')), '[^a-z]', '', 'g') = any (array[
           'admin', 'administrator', 'admins', 'root', 'system', 'sysadmin', 'support', 'help', 'helpdesk', 'staff', 'team',
           'moderator', 'moderators', 'mod', 'mods', 'owner', 'official', 'anix', 'anixpro', 'nexora', 'security',
           'service', 'services', 'bazaar', 'cafebazaar', 'null', 'undefined', 'guest', 'everyone', 'here', 'api', 'bot',
           'oracle', 'info', 'contact', 'billing', 'payment', 'payments', 'webmaster', 'superuser', 'test'])
      or regexp_replace(lower(coalesce(p, '')), '[^a-z]', '', 'g')
         ~ '^(anix|nexora|admin|support|moderator|official|oracle|sysadmin)'
$$;

-- Who may use reserved names: direct database sessions (maintenance scripts) and the service role.
create or replace function public._nx_name_rules_bypass()
returns boolean language sql stable
as $$
  select session_user not in ('authenticator', 'supabase_auth_admin', 'anon', 'authenticated')
      or coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') = 'service_role'
$$;

revoke all on function public._nx_text_norm(text), public._nx_token_key(text, int), public._nx_bad_token(text),
  public._nx_username_bad(text), public._nx_username_reserved(text), public._nx_name_rules_bypass() from public, anon, authenticated;
revoke all on function public.nx_profanity_check(text), public.nx_profanity_mask(text) from public, anon;
grant execute on function public.nx_profanity_check(text), public.nx_profanity_mask(text) to authenticated;

-- Word list (Persian, Finglish, English). Deliberately left out: bare 'کس' (in «هیچ کس», «هر کس»); 'جنده' is
-- token-only because it sits inside «رنجنده» and «سنجنده». Extend with: select public.nx_profanity_add('word', substr, 'fa').
create or replace function public.nx_profanity_add(p_word text, p_substr boolean default false, p_lang text default 'fa')
returns void language sql security definer set search_path = public
as $$
  insert into nx_profanity_words(word, w2, w1, substr, lang)
  values (lower(btrim(p_word)), _nx_token_key(p_word, 2), _nx_token_key(p_word, 1), p_substr, p_lang)
  on conflict (word) do update set w2 = excluded.w2, w1 = excluded.w1, substr = excluded.substr, lang = excluded.lang
$$;
revoke all on function public.nx_profanity_add(text, boolean, text) from public, anon, authenticated;

select public.nx_profanity_add(w, s, l) from (values
  -- Persian
  ('کیر', false, 'fa'), ('کیرم', false, 'fa'), ('کیرت', false, 'fa'), ('کیری', false, 'fa'), ('کیرخور', true, 'fa'),
  ('کص', false, 'fa'), ('کسکش', true, 'fa'), ('کصکش', true, 'fa'), ('کسخل', true, 'fa'),
  ('کصخل', true, 'fa'), ('کسده', true, 'fa'), ('کصده', true, 'fa'), ('خارکسده', true, 'fa'), ('خارکصده', true, 'fa'),
  ('کسننت', true, 'fa'), ('کسننه', true, 'fa'), ('کسمادرت', true, 'fa'), ('کسنگو', true, 'fa'), ('کسشر', true, 'fa'),
  ('کون', false, 'fa'), ('کونی', false, 'fa'), ('کونده', true, 'fa'), ('کونکش', true, 'fa'),
  ('جنده', false, 'fa'), ('مادرجنده', true, 'fa'), ('جاکش', true, 'fa'), ('پدرسگ', true, 'fa'), ('پدرسوخته', true, 'fa'),
  ('حرومزاده', true, 'fa'), ('حرامزاده', true, 'fa'), ('حرومی', false, 'fa'), ('لاشی', false, 'fa'), ('دیوث', true, 'fa'),
  ('قرمساق', true, 'fa'), ('گوه', false, 'fa'), ('گوهخور', true, 'fa'), ('گاییدم', true, 'fa'), ('گاییدن', true, 'fa'),
  ('بگا', false, 'fa'), ('بگام', false, 'fa'), ('تخمی', false, 'fa'), ('تخمسگ', true, 'fa'), ('بیناموس', true, 'fa'),
  ('سکس', false, 'fa'), ('سکسی', false, 'fa'), ('پورن', false, 'fa'), ('شومبول', false, 'fa'),
  -- Finglish
  ('kir', false, 'fi'), ('kiri', false, 'fi'), ('kirkhor', true, 'fi'), ('kos', false, 'fi'), ('koss', false, 'fi'),
  ('koskesh', true, 'fi'), ('kooskesh', true, 'fi'), ('kosskesh', true, 'fi'), ('koskhol', true, 'fi'), ('kosde', true, 'fi'),
  ('kosdeh', true, 'fi'), ('kharkosde', true, 'fi'), ('kosnanat', true, 'fi'), ('kosnane', true, 'fi'), ('kosmadar', true, 'fi'),
  ('kosmadaret', true, 'fi'), ('kosnagoo', true, 'fi'), ('kossher', true, 'fi'), ('koon', false, 'fi'), ('kooni', false, 'fi'),
  ('koonkesh', true, 'fi'), ('jende', false, 'fi'), ('jendeh', false, 'fi'), ('madarjende', true, 'fi'), ('jakesh', true, 'fi'),
  ('pedarsag', true, 'fi'), ('pedarsookhte', true, 'fi'), ('haroomzade', true, 'fi'), ('haramzade', true, 'fi'),
  ('harumzade', true, 'fi'), ('haroomi', false, 'fi'), ('lashi', false, 'fi'), ('dayus', true, 'fi'), ('dayoos', true, 'fi'),
  ('ghoromsagh', true, 'fi'), ('gaidam', true, 'fi'), ('gayidam', true, 'fi'), ('tokhmi', false, 'fi'),
  ('tokhmesag', true, 'fi'), ('binamoos', true, 'fi'), ('shombool', false, 'fi'),
  -- English
  ('fuck', true, 'en'), ('fucker', true, 'en'), ('fucking', true, 'en'), ('motherfucker', true, 'en'), ('fck', false, 'en'),
  ('shit', false, 'en'), ('bullshit', true, 'en'), ('bitch', true, 'en'), ('bastard', false, 'en'), ('asshole', true, 'en'),
  ('ass', false, 'en'), ('dick', false, 'en'), ('dickhead', true, 'en'), ('cunt', false, 'en'), ('whore', true, 'en'),
  ('slut', true, 'en'), ('pussy', false, 'en'), ('nigger', true, 'en'), ('nigga', true, 'en'), ('faggot', true, 'en'),
  ('fag', false, 'en'), ('retard', false, 'en'), ('cock', false, 'en'), ('cocksucker', true, 'en'), ('porn', true, 'en'),
  ('twat', false, 'en'), ('wanker', true, 'en'), ('jerkoff', true, 'en'), ('blowjob', true, 'en')
) v(w, s, l);

-- ============================================================== games: mirrors of core bans and blocks
-- Written only by the core project through the service-role bridge RPCs below.
create table if not exists public.nx_bans (
  user_id uuid primary key,
  banned boolean not null default true,
  reason text,
  updated_at timestamptz not null default now()
);
alter table public.nx_bans enable row level security;
revoke all on table public.nx_bans from anon, authenticated;

-- Same name and shape as core's user_blocks: nx_invite already reads public.user_blocks (it failed before because the
-- table did not exist on this project).
create table if not exists public.user_blocks (
  blocker uuid not null,
  blocked uuid not null,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked)
);
alter table public.user_blocks enable row level security;
revoke all on table public.user_blocks from anon, authenticated;
create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked);

create or replace function public.nx_bridge_bans_put(p_rows jsonb)
returns int language plpgsql security definer set search_path = public
as $$
declare e jsonb; n int := 0;
begin
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    if coalesce((e ->> 'banned')::boolean, false) then
      insert into nx_bans(user_id, banned, reason, updated_at) values ((e ->> 'user_id')::uuid, true, left(e ->> 'reason', 300), now())
      on conflict (user_id) do update set banned = true, reason = excluded.reason, updated_at = now();
    else
      delete from nx_bans where user_id = (e ->> 'user_id')::uuid;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.nx_bridge_blocks_put(p_rows jsonb)
returns int language plpgsql security definer set search_path = public
as $$
declare e jsonb; n int := 0;
begin
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    if coalesce((e ->> 'on')::boolean, true) then
      insert into user_blocks(blocker, blocked) values ((e ->> 'blocker')::uuid, (e ->> 'blocked')::uuid) on conflict do nothing;
    else
      delete from user_blocks where blocker = (e ->> 'blocker')::uuid and blocked = (e ->> 'blocked')::uuid;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public.nx_bridge_bans_put(jsonb), public.nx_bridge_blocks_put(jsonb) from public, anon, authenticated;
grant execute on function public.nx_bridge_bans_put(jsonb), public.nx_bridge_blocks_put(jsonb) to service_role;

create or replace function public._nx_g_banned(u uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select u is not null and exists (select 1 from nx_bans where user_id = u and banned) $$;

create or replace function public._nx_g_blocked(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from user_blocks where (blocker = a and blocked = b) or (blocker = b and blocked = a)) $$;

-- ============================================================== games: bans enforced on every write path
-- One trigger function; the column holding the acting user is the trigger argument.
create or replace function public._nx_g_ban_guard()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if _nx_g_banned((to_jsonb(new) ->> tg_argv[0])::uuid) then raise exception 'banned' using errcode = 'P0001'; end if;
  return new;
end $$;

do $$
declare t text; c text;
begin
  foreach t in array array['nx_rooms:host', 'nx_room_members:user_id', 'nx_room_players:user_id', 'nx_room_game_players:user_id',
                           'nx_match_moves:by_user', 'nx_room_messages:author', 'nx_t_entries:user_id', 'nx_invites:from_user'] loop
    c := split_part(t, ':', 2); t := split_part(t, ':', 1);
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists nx_ban_guard on public.%I', t);
      execute format('create trigger nx_ban_guard before insert on public.%I for each row execute function public._nx_g_ban_guard(%L)', t, c);
    end if;
  end loop;
end $$;

-- ============================================================== games: invites between a blocked pair, names, room chat
create or replace function public._nx_g_invites_block()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if _nx_g_blocked(new.from_user, new.to_user) then raise exception 'blocked' using errcode = 'P0001'; end if;
  return new;
end $$;
drop trigger if exists nx_invites_block on public.nx_invites;
create trigger nx_invites_block before insert on public.nx_invites
  for each row execute function public._nx_g_invites_block();

create or replace function public._nx_g_rooms_safety()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if (tg_op = 'INSERT' or new.title is distinct from old.title) and nx_profanity_check(new.title) then
    raise exception 'name_profane' using errcode = '22023';
  end if;
  return new;
end $$;
drop trigger if exists nx_rooms_safety on public.nx_rooms;
create trigger nx_rooms_safety before insert or update of title on public.nx_rooms
  for each row execute function public._nx_g_rooms_safety();

create or replace function public._nx_g_room_messages_safety()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' or new.text is distinct from old.text then new.text := nx_profanity_mask(new.text); end if;
  return new;
end $$;
drop trigger if exists nx_room_messages_safety on public.nx_room_messages;
create trigger nx_room_messages_safety before insert or update of text on public.nx_room_messages
  for each row execute function public._nx_g_room_messages_safety();

-- tournament titles / descriptions created on this project
create or replace function public._nx_g_tournament_safety()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if (tg_op = 'INSERT' or new.title is distinct from old.title) and nx_profanity_check(new.title) then
    raise exception 'name_profane' using errcode = '22023';
  end if;
  if tg_op = 'INSERT' or new.description is distinct from old.description then
    new.description := nx_profanity_mask(new.description);
  end if;
  return new;
end $$;
drop trigger if exists nx_tournaments_safety on public.nx_tournaments;
create trigger nx_tournaments_safety before insert or update of title, description on public.nx_tournaments
  for each row execute function public._nx_g_tournament_safety();

revoke all on function public._nx_g_banned(uuid), public._nx_g_blocked(uuid, uuid), public._nx_g_ban_guard(),
  public._nx_g_invites_block(), public._nx_g_rooms_safety(), public._nx_g_room_messages_safety(),
  public._nx_g_tournament_safety() from public, anon, authenticated;

-- client: "am I banned?" for the banned screen on the games side
create or replace function public.nx_g_my_ban()
returns jsonb language sql stable security definer set search_path = public
as $$ select jsonb_build_object('banned', public._nx_g_banned(auth.uid())) $$;
revoke all on function public.nx_g_my_ban() from public, anon;
grant execute on function public.nx_g_my_ban() to authenticated;
