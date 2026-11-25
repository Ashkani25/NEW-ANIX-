-- #2 + #3 (core/social project eisstodgncimypdawisy)
-- * NULL-unsafe role checks: `nx_chat_role(..) <> 'owner'` / `nx_community_role(..) <> 'owner'` is NULL for a stranger,
--   so ANY signed-in user (and anon) could promote chat members or delete any community. Now IS DISTINCT FROM +
--   explicit sign-in check (nx_set_chat_role, nx_community_delete, nx_community_set_role).
-- * EXECUTE lockdown: every public function is revoked from PUBLIC/anon/authenticated, then granted back only to
--   - authenticated: the RPCs the Flutter app calls on this project + the helpers RLS/storage policies use;
--   - anon: the helpers used by policies that apply to the `public` role, and nx_username_available (sign-up form).
--   Legacy RPCs of the old game/tournament/club backend (start_tournament, report_match, update_club, update_room,
--   start_match, gm_*, owner_bank_adjust, ...) are not used by the app any more: they stay in place but no client can
--   call them. The auth hook keeps its supabase_auth_admin grant; service_role keeps everything.

CREATE OR REPLACE FUNCTION public.nx_set_chat_role(p_chat uuid, p_user uuid, p_role text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if nx_chat_role(p_chat) is distinct from 'owner' or coalesce(p_role, '') not in ('admin','member') or p_user is null or p_user = auth.uid() then raise exception 'forbidden'; end if;
  perform set_config('nx.role_change', 'on', true);
  update nx_chat_members set role = p_role where chat_id = p_chat and user_id = p_user and role <> 'owner';
  return found;
end $function$;

CREATE OR REPLACE FUNCTION public.nx_community_delete(p_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if nx_community_role(p_id) is distinct from 'owner' then raise exception 'forbidden'; end if;
  delete from nx_communities where id = p_id;
  return true;
end $function$;

CREATE OR REPLACE FUNCTION public.nx_community_set_role(p_id uuid, p_user uuid, p_role text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a text := nx_community_role(p_id); t text;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select role into t from nx_community_members where community_id = p_id and user_id = p_user;
  if a is null or t is null or p_user = auth.uid() or t = 'owner' or coalesce(p_role, '') not in ('admin','moderator','member')
     or _nx_rank(a) < 2 or _nx_rank(t) >= _nx_rank(a) or _nx_rank(p_role) >= _nx_rank(a) then
    raise exception 'forbidden';
  end if;
  update nx_community_members set role = p_role where community_id = p_id and user_id = p_user;
  return true;
end $function$;

do $grants$
declare f record;
  keep text[] := array['_can_manage', 'can_post', 'cancel_friend_request', 'fs_create_custom_team', 'fs_update_custom_team', 'is_member', 'is_owner', 'nx_add_chat_members', 'nx_admin_announce', 'nx_admin_announce_edit', 'nx_admin_announce_end', 'nx_admin_announcements', 'nx_admin_banned', 'nx_admin_catalog', 'nx_admin_delete_item', 'nx_admin_edit_profile', 'nx_admin_grant_item', 'nx_admin_grant_wallet', 'nx_admin_list', 'nx_admin_mute', 'nx_admin_player', 'nx_admin_recent_content', 'nx_admin_remove', 'nx_admin_rename', 'nx_admin_report_set', 'nx_admin_reports', 'nx_admin_reset_password', 'nx_admin_set_inventory', 'nx_admin_set_manager', 'nx_admin_set_perms', 'nx_admin_set_price', 'nx_admin_set_wallet', 'nx_award', 'nx_buy_with_gems', 'nx_can_read_chat_media', 'nx_chat_role', 'nx_community_create', 'nx_community_delete', 'nx_community_join', 'nx_community_join_open', 'nx_community_kick', 'nx_community_leave', 'nx_community_role', 'nx_community_save', 'nx_community_set_role', 'nx_create_chat', 'nx_daily_gems', 'nx_delete_message', 'nx_edit_message', 'nx_end_call', 'nx_import_local', 'nx_in_match', 'nx_in_room', 'nx_is_chat_member', 'nx_is_owner', 'nx_leave_chat', 'nx_mark_read', 'nx_my_access', 'nx_my_chats', 'nx_open_direct', 'nx_oracle_persona_save', 'nx_owner_audit_list', 'nx_owner_ban', 'nx_owner_stats', 'nx_owner_users', 'nx_purchase', 'nx_redeem_admin_code', 'nx_report_user', 'nx_send_message', 'nx_set_chat_role', 'nx_set_username', 'nx_social_can_view', 'nx_social_profile', 'nx_social_search', 'nx_social_toggle_follow', 'nx_start_call', 'nx_t_can_manage', 'nx_t_is_admin', 'nx_t_set_staff', 'nx_t_visible', 'nx_toggle_pin_message', 'nx_tour_seen_set', 'nx_username_available', 'nx_wallet', 'remove_friend', 'respond_friend_request', 'send_friend_request', 'touch_presence'];
  anon_keep text[] := array['_can_manage', 'is_owner', 'nx_chat_role', 'nx_community_role', 'nx_is_chat_member', 'nx_social_can_view', 'nx_username_available'];
begin
  for f in select p.oid::regprocedure as sig, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prokind = 'f'
              and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
    if f.proname = any(keep) or f.proname = any(anon_keep) then execute format('grant execute on function %s to authenticated', f.sig); end if;
    if f.proname = any(anon_keep) then execute format('grant execute on function %s to anon', f.sig); end if;
  end loop;
end $grants$;

alter default privileges for role postgres in schema public revoke execute on functions from public, anon;
alter default privileges in schema public revoke execute on functions from public, anon;
