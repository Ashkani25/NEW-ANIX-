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
