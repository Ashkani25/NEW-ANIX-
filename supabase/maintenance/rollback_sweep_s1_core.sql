-- rollback snapshot taken 2026-11-25T17:16:15Z from project eisstodgncimypdawisy (state BEFORE the fix)
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
  return new;
end $function$
;
revoke all on function _nx_profiles_guard() from public, anon, authenticated;
grant update (avatar, avatar_path, avatar_url, bio, online_at, updated_at, username) on table public.profiles to authenticated;
drop policy if exists nx_comments_read on public.nx_post_comments; create policy nx_comments_read on public.nx_post_comments for select to public using (true);
drop policy if exists nx_comments_write on public.nx_post_comments; create policy nx_comments_write on public.nx_post_comments for insert to public with check (author = auth.uid());
drop policy if exists nx_likes_read on public.nx_post_likes; create policy nx_likes_read on public.nx_post_likes for select to public using (true);
drop policy if exists nx_likes_write on public.nx_post_likes; create policy nx_likes_write on public.nx_post_likes for insert to public with check (user_id = auth.uid());
drop policy if exists "ce insert" on public.client_errors; create policy "ce insert" on public.client_errors for insert to anon, authenticated with check ((length(message) <= 2000) AND (length(COALESCE(stack, ''::text)) <= 8000) AND ((user_id IS NULL) OR (user_id = auth.uid())));
grant insert on table public.client_errors to anon;
grant INSERT,TRUNCATE,REFERENCES,TRIGGER on public.client_errors to anon;
grant INSERT,SELECT,DELETE,UPDATE,TRUNCATE,REFERENCES,TRIGGER on public.nx_post_comments to anon;
grant INSERT,SELECT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER on public.nx_post_likes to anon;
grant TRIGGER,INSERT,TRUNCATE,REFERENCES on public.client_errors to authenticated;
grant DELETE,INSERT,SELECT,UPDATE,TRUNCATE,REFERENCES,TRIGGER on public.nx_post_comments to authenticated;
grant INSERT,SELECT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER on public.nx_post_likes to authenticated;
