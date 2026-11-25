-- AUTH project · live snapshot (2026-11-25). These two functions were changed on the live database outside the repo
-- (social v2 / username work). The repo's last definitions (20261115000200_nx_social.sql, 20261118121500_auth_username_fallback.sql)
-- are OLDER than live; this file records the live definitions verbatim (pg_get_functiondef) so a fresh database or a
-- re-run of the migration chain does not regress them. Idempotent (create or replace only); already applied live.
--  * nx_my_chats(): peer name = display_name (fallback username), avatar = avatar_url (fallback avatar).
--  * handle_new_user(): lowercase 'pilot…' fallback, case-insensitive uniqueness, stores display_name from signup metadata.

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n text;
begin
  n := nullif(btrim(new.raw_user_meta_data->>'username'), '');
  if n is null or char_length(n) < 3 or char_length(n) > 20 then
    n := 'pilot' || substr(replace(new.id::text, '-', ''), 1, 15);
  end if;
  while exists (select 1 from public.profiles where lower(username) = lower(n)) loop
    n := left(n, 14) || lpad((floor(random() * 99999))::bigint::text, 5, '0');
  end loop;
  insert into public.profiles(id, username, is_guest, display_name)
  values (new.id, n, coalesce(new.is_anonymous, false), coalesce(nullif(btrim(new.raw_user_meta_data->>'display_name'), ''), ''));
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.nx_my_chats()
 RETURNS TABLE(id uuid, kind text, name text, description text, badge_id text, owner uuid, is_public boolean, created_at timestamp with time zone, last_msg_at timestamp with time zone, role text, pinned boolean, muted boolean, last_read_at timestamp with time zone, unread integer, peer uuid, peer_name text, peer_avatar text, peer_online timestamp with time zone, members integer, last jsonb)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select c.id, c.kind, c.name, c.description, c.badge_id, c.owner, c.is_public, c.created_at, c.last_msg_at,
         m.role, m.pinned, m.muted, m.last_read_at,
         (select count(*)::int from nx_messages x where x.chat_id = c.id and x.created_at > m.last_read_at
            and x.author is distinct from auth.uid() and not x.deleted),
         p.id, p.name, p.avatar, p.online_at,
         (select count(*)::int from nx_chat_members y where y.chat_id = c.id),
         (select to_jsonb(l) from (select * from nx_messages z where z.chat_id = c.id order by z.created_at desc limit 1) l)
  from nx_chat_members m
  join nx_chats c on c.id = m.chat_id
  left join lateral (select pr.id, coalesce(nullif(pr.display_name, ''), pr.username) as name,
                            coalesce(nullif(pr.avatar_url, ''), pr.avatar) as avatar, pr.online_at
                     from nx_chat_members o join profiles pr on pr.id = o.user_id
                     where c.kind = 'direct' and o.chat_id = c.id and o.user_id <> auth.uid() limit 1) p on true
  where m.user_id = auth.uid()
  order by m.pinned desc, c.last_msg_at desc;
$function$
;
