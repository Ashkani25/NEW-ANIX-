-- Sweep S1 (core): profiles & social privacy
-- * profiles: clients may only update bio / avatar / avatar_url / avatar_path / online_at directly (username goes through
--   nx_set_username's validation; rating, wins, trophies, league ... are server-owned). avatar_url/avatar_path must be
--   the user's own upload in this project's storage.
-- * nx_post_comments / nx_post_likes were readable by everyone (comments/likes of PRIVATE accounts' posts) and
--   writable on posts the user cannot see: both now follow nx_posts visibility (the subquery is RLS-filtered).
-- * client_errors: no longer writable by anon.

revoke update on table public.profiles from anon, authenticated;
grant update (bio, avatar, avatar_url, avatar_path, online_at) on table public.profiles to authenticated;

CREATE OR REPLACE FUNCTION public._nx_profiles_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare j jsonb; o jsonb; k text;
begin
  if _nx_trusted() then return new; end if;
  j := to_jsonb(new);
  if tg_op = 'UPDATE' then
    o := to_jsonb(old);
    foreach k in array array['id', 'xp', 'coins', 'gems', 'level', 'role', 'is_guest'] loop
      if j ? k then j := jsonb_set(j, array[k], coalesce(o -> k, 'null'::jsonb)); end if;
    end loop;
  else
    if j ? 'xp' then j := jsonb_set(j, '{xp}', '0'); end if;
    if j ? 'coins' then j := jsonb_set(j, '{coins}', '0'); end if;
    if j ? 'gems' then j := jsonb_set(j, '{gems}', '0'); end if;
    if j ? 'level' then j := jsonb_set(j, '{level}', '1'); end if;
    if j ? 'role' then j := jsonb_set(j, '{role}', 'null'); end if;
  end if;
  new := jsonb_populate_record(new, j);
  -- avatar must be the user's own upload in this project's storage (no third-party tracking urls / other users' files)
  if new.avatar_url is not null and new.avatar_url <> ''
     and new.avatar_url not like 'https://eisstodgncimypdawisy.supabase.co/storage/v1/object/public/nx-media/' || new.id::text || '/%'
     and new.avatar_url not like 'https://eisstodgncimypdawisy.supabase.co/storage/v1/object/public/avatars/' || new.id::text || '/%' then
    raise exception 'avatar_url must point to your own upload' using errcode = '22023';
  end if;
  if new.avatar_path is not null and new.avatar_path <> '' and new.avatar_path not like new.id::text || '/%' then
    raise exception 'avatar_path must be inside your own folder' using errcode = '22023';
  end if;
  if new.bio is not null and length(new.bio) > 500 then new.bio := left(new.bio, 500); end if;
  return new;
end $function$;

drop policy if exists nx_comments_read on public.nx_post_comments;
create policy nx_comments_read on public.nx_post_comments for select to authenticated
  using (exists (select 1 from public.nx_posts p where p.id = nx_post_comments.post_id));
drop policy if exists nx_comments_write on public.nx_post_comments;
create policy nx_comments_write on public.nx_post_comments for insert to authenticated
  with check (author = auth.uid() and exists (select 1 from public.nx_posts p where p.id = nx_post_comments.post_id));
drop policy if exists nx_likes_read on public.nx_post_likes;
create policy nx_likes_read on public.nx_post_likes for select to authenticated
  using (exists (select 1 from public.nx_posts p where p.id = nx_post_likes.post_id));
drop policy if exists nx_likes_write on public.nx_post_likes;
create policy nx_likes_write on public.nx_post_likes for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from public.nx_posts p where p.id = nx_post_likes.post_id));
revoke all on table public.nx_post_comments from anon;
revoke all on table public.nx_post_likes from anon;

revoke insert on table public.client_errors from anon;
drop policy if exists "ce insert" on public.client_errors;
create policy "ce insert" on public.client_errors for insert to authenticated
  with check (length(message) <= 2000 and length(coalesce(stack, '')) <= 8000 and (user_id is null or user_id = auth.uid()));
