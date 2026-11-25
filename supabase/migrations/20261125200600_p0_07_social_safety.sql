-- P0 #7: social safety, core project (eisstodgncimypdawisy).
-- * Profanity filter (Persian + English + Finglish, normalised) and reserved usernames, enforced by triggers so every
--   write path is covered without touching the RPC bodies: usernames/display names/group-chat and community names are
--   rejected (errors username_reserved / username_profane / name_profane), messages / posts / comments / bios /
--   chat descriptions are masked with asterisks.
-- * Blocks: a blocked pair cannot open/re-open a DM (nx_chat_members), write in it (nx_messages: nx_send_message,
--   nx_social_send_dm) or call (nx_calls: nx_start_call). Client API nx_block_user / nx_unblock_user / nx_my_blocks /
--   nx_block_state (the legacy block_user/unblock_user are not executable by clients).
-- * Blocks and bans are mirrored to the games project over the pg_net bridge (games enforces bans on rooms, matches,
--   moves, room chat, tournaments, and blocks on invites).
-- * nx_username_available also refuses reserved and listed names (sign-up pre-check).
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

-- ============================================================== core: names and free text
-- Usernames: reserved names and listed words are rejected; display names likewise; bio is masked.
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
drop trigger if exists nx_profiles_safety on public.profiles;
create trigger nx_profiles_safety before insert or update of username, display_name, bio on public.profiles
  for each row execute function public._nx_profiles_safety();

-- Shared names (group chats, communities) are rejected; descriptions are masked.
create or replace function public._nx_names_safety()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if tg_table_name = 'nx_chats' then
    if new.kind <> 'direct' and (tg_op = 'INSERT' or new.name is distinct from old.name) and nx_profanity_check(new.name) then
      raise exception 'name_profane' using errcode = '22023';
    end if;
    if tg_op = 'INSERT' or new.description is distinct from old.description then
      new.description := nx_profanity_mask(new.description);
    end if;
  elsif tg_table_name = 'nx_communities' then
    if (tg_op = 'INSERT' or new.name is distinct from old.name) and nx_profanity_check(new.name) then
      raise exception 'name_profane' using errcode = '22023';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists nx_chats_safety on public.nx_chats;
create trigger nx_chats_safety before insert or update of name, description on public.nx_chats
  for each row execute function public._nx_names_safety();
drop trigger if exists nx_communities_safety on public.nx_communities;
create trigger nx_communities_safety before insert or update of name on public.nx_communities
  for each row execute function public._nx_names_safety();

-- Posts and comments: masked.
create or replace function public._nx_text_mask_trg()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' or new.text is distinct from old.text then new.text := nx_profanity_mask(new.text); end if;
  return new;
end $$;
drop trigger if exists nx_posts_safety on public.nx_posts;
create trigger nx_posts_safety before insert or update of text on public.nx_posts
  for each row execute function public._nx_text_mask_trg();
drop trigger if exists nx_post_comments_safety on public.nx_post_comments;
create trigger nx_post_comments_safety before insert or update of text on public.nx_post_comments
  for each row execute function public._nx_text_mask_trg();

-- ============================================================== core: blocks enforced on every DM path
-- The other side of a direct chat comes from its dm_key ("<least uuid>:<greatest uuid>").
create or replace function public._nx_dm_peer(p_chat uuid, p_me uuid)
returns uuid language sql stable security definer set search_path = public
as $$
  select case when split_part(c.dm_key, ':', 1) = p_me::text then split_part(c.dm_key, ':', 2)::uuid
              else split_part(c.dm_key, ':', 1)::uuid end
    from nx_chats c where c.id = p_chat and c.kind = 'direct' and c.dm_key like '%:%'
$$;

-- nx_messages: blocked pairs cannot write in their direct chat (nx_send_message, nx_social_send_dm, nx_start_call's
-- call message); text messages are masked.
create or replace function public._nx_messages_safety()
returns trigger language plpgsql security definer set search_path = public
as $$
declare peer uuid;
begin
  if tg_op = 'INSERT' and new.author is not null then
    peer := _nx_dm_peer(new.chat_id, new.author);
    if peer is not null and _nx_blocked(new.author, peer) then raise exception 'blocked' using errcode = 'P0001'; end if;
  end if;
  if new.kind = 'text' and (tg_op = 'INSERT' or new.text is distinct from old.text) then
    new.text := nx_profanity_mask(new.text);
  end if;
  return new;
end $$;
drop trigger if exists nx_messages_safety on public.nx_messages;
create trigger nx_messages_safety before insert or update of text on public.nx_messages
  for each row execute function public._nx_messages_safety();

-- nx_chat_members: nx_open_direct (re)adds both sides; a blocked pair cannot open or re-open their DM.
create or replace function public._nx_chat_members_block()
returns trigger language plpgsql security definer set search_path = public
as $$
declare peer uuid;
begin
  peer := _nx_dm_peer(new.chat_id, new.user_id);
  if peer is not null and peer <> new.user_id and _nx_blocked(new.user_id, peer) then
    raise exception 'blocked' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists nx_chat_members_block on public.nx_chat_members;
create trigger nx_chat_members_block before insert on public.nx_chat_members
  for each row execute function public._nx_chat_members_block();

-- nx_calls: no calls between a blocked pair.
create or replace function public._nx_calls_block()
returns trigger language plpgsql security definer set search_path = public
as $$
declare peer uuid;
begin
  peer := _nx_dm_peer(new.chat_id, new.caller);
  if peer is not null and _nx_blocked(new.caller, peer) then raise exception 'blocked' using errcode = 'P0001'; end if;
  return new;
end $$;
drop trigger if exists nx_calls_block on public.nx_calls;
create trigger nx_calls_block before insert on public.nx_calls
  for each row execute function public._nx_calls_block();

-- ============================================================== core: block / unblock / list (client API)
create or replace function public.nx_block_user(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare me uuid := auth.uid();
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  if p_user is null or p_user = me then return jsonb_build_object('ok', false, 'error', 'bad_user'); end if;
  if not exists (select 1 from profiles where id = p_user) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  perform _nx_rate('block', 60, interval '1 hour');
  insert into user_blocks(blocker, blocked) values (me, p_user) on conflict do nothing;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.nx_unblock_user(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  delete from user_blocks where blocker = auth.uid() and blocked = p_user;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.nx_my_blocks()
returns table(user_id uuid, username text, display_name text, avatar_url text)
language sql stable security definer set search_path = public
as $$
  select p.id, p.username, p.display_name, coalesce(p.avatar_url, '')
    from user_blocks b join profiles p on p.id = b.blocked
   where b.blocker = auth.uid()
   order by p.username
$$;

-- whether the caller blocked p_user / is blocked by them (profile button state; never says who blocked whom beyond self)
create or replace function public.nx_block_state(p_user uuid)
returns jsonb language sql stable security definer set search_path = public
as $$
  select jsonb_build_object(
    'blocked_by_me', exists (select 1 from user_blocks where blocker = auth.uid() and blocked = p_user),
    'blocked_me', exists (select 1 from user_blocks where blocker = p_user and blocked = auth.uid()))
$$;

revoke all on function public.nx_block_user(uuid), public.nx_unblock_user(uuid), public.nx_my_blocks(),
  public.nx_block_state(uuid) from public, anon;
grant execute on function public.nx_block_user(uuid), public.nx_unblock_user(uuid), public.nx_my_blocks(),
  public.nx_block_state(uuid) to authenticated;
revoke all on function public._nx_profiles_safety(), public._nx_names_safety(), public._nx_text_mask_trg(),
  public._nx_dm_peer(uuid, uuid), public._nx_messages_safety(), public._nx_chat_members_block(), public._nx_calls_block()
  from public, anon, authenticated;

-- ============================================================== core -> games: blocks and bans mirror (pg_net bridge)
create or replace function public._nx_games_post(p_fn text, p_body jsonb)
returns void language plpgsql security definer set search_path = public
as $$
declare url text := _nx_vault('nx_games_url'); key text := _nx_vault('nx_games_service_key');
begin
  if url is null or key is null then return; end if;
  perform net.http_post(url := url || '/rest/v1/rpc/' || p_fn,
                        headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', key,
                                                      'Authorization', 'Bearer ' || key),
                        body := p_body, timeout_milliseconds := 8000);
exception when others then
  null; -- never break the caller because of the bridge
end $$;
revoke all on function public._nx_games_post(text, jsonb) from public, anon, authenticated;

create or replace function public._nx_blocks_to_games()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform _nx_games_post('nx_bridge_blocks_put', jsonb_build_object('p_rows',
      jsonb_build_array(jsonb_build_object('blocker', new.blocker, 'blocked', new.blocked, 'on', true))));
  else
    perform _nx_games_post('nx_bridge_blocks_put', jsonb_build_object('p_rows',
      jsonb_build_array(jsonb_build_object('blocker', old.blocker, 'blocked', old.blocked, 'on', false))));
  end if;
  return null;
end $$;
drop trigger if exists nx_blocks_to_games on public.user_blocks;
create trigger nx_blocks_to_games after insert or delete on public.user_blocks
  for each row execute function public._nx_blocks_to_games();

create or replace function public._nx_bans_to_games()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform _nx_games_post('nx_bridge_bans_put', jsonb_build_object('p_rows',
      jsonb_build_array(jsonb_build_object('user_id', old.user_id, 'banned', false))));
  elsif tg_op = 'INSERT' or new.banned is distinct from old.banned then
    perform _nx_games_post('nx_bridge_bans_put', jsonb_build_object('p_rows',
      jsonb_build_array(jsonb_build_object('user_id', new.user_id, 'banned', new.banned, 'reason', new.ban_reason))));
  end if;
  return null;
end $$;
drop trigger if exists nx_bans_to_games on public.nx_account_flags;
create trigger nx_bans_to_games after insert or update of banned or delete on public.nx_account_flags
  for each row execute function public._nx_bans_to_games();
revoke all on function public._nx_blocks_to_games(), public._nx_bans_to_games() from public, anon, authenticated;

-- one-off resync of what exists today (both lists may be empty)
select public._nx_games_post('nx_bridge_bans_put', jsonb_build_object('p_rows', coalesce((select jsonb_agg(
         jsonb_build_object('user_id', user_id, 'banned', banned, 'reason', ban_reason)) from public.nx_account_flags where banned), '[]'::jsonb)));
select public._nx_games_post('nx_bridge_blocks_put', jsonb_build_object('p_rows', coalesce((select jsonb_agg(
         jsonb_build_object('blocker', blocker, 'blocked', blocked, 'on', true)) from public.user_blocks), '[]'::jsonb)));

-- ============================================================== core: availability check used by sign-up
-- (live definition from the server, plus the reserved / word-list rules)
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
