-- #1 + #3 (games project eyzafhrefnqlwcjpcdyg)
-- * NULL-unsafe owner checks (`r.host <> auth.uid()` is NULL, i.e. passes, for a caller without a JWT): explicit
--   sign-in check + IS DISTINCT FROM in nx_start_match, nx_update_room, nx_room_capacity, nx_put_secret.
-- * Quick rooms could be started by anyone who knew the room id: now only a seated player.
-- * EXECUTE: nothing in public is callable by anon/PUBLIC any more (app guests are Supabase anonymous users and run as
--   `authenticated`). Internal helpers (_nx_*), trigger functions and nx_gen_code are not callable by clients at all.
--   Future functions do not get EXECUTE for anon/PUBLIC by default.

CREATE OR REPLACE FUNCTION public.nx_start_match(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); r public.nx_rooms; b record; ids uuid[]; nm text[]; mid uuid; sd bigint; n int; cap int;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if r.host is distinct from me and not r.quick then raise exception 'host only'; end if;
  -- quick rooms: only a seated player may start them
  if r.quick and not exists (select 1 from public.nx_room_players rp where rp.room_id = p_room and rp.user_id = me) then
    raise exception 'not in this room';
  end if;
  if r.status = 'playing' and r.match_id is not null then
    return jsonb_build_object('match_id', r.match_id, 'already', true);
  end if;
  select * into b from public.nx_game_bounds(r.game);
  cap := greatest(b.min_seats, least(coalesce(r.seats, b.max_seats), b.max_seats));
  select array_agg(rp.user_id order by rp.seat), array_agg(coalesce(p.username, 'Pilot') order by rp.seat), count(*)
    into ids, nm, n
    from public.nx_room_players rp left join public.profiles p on p.id = rp.user_id where rp.room_id = p_room;
  if n < b.min_seats then raise exception 'need % players', b.min_seats; end if;
  if n > cap then raise exception 'this room takes at most % players', cap; end if;
  if r.game = 'finger_soccer' and n % 2 <> 0 then raise exception 'team games need two equal sides'; end if;
  sd := floor(random() * 2147483646)::bigint + 1;
  insert into public.nx_matches(room_id, game, players, names, seed, settings) values (p_room, r.game, ids, nm, sd, r.settings)
  returning id into mid;
  update public.nx_rooms set status = 'playing', match_id = mid, updated_at = now() where id = p_room;
  return jsonb_build_object('match_id', mid, 'seed', sd);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_update_room(p_room uuid, p_seats integer, p_settings jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r nx_rooms; b record; n int;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select * into r from nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if r.host is distinct from auth.uid() then raise exception 'host only'; end if;
  if r.status <> 'lobby' then raise exception 'already started'; end if;
  select * into b from nx_game_bounds(r.game);
  select count(*) into n from nx_room_players where room_id = p_room;
  update nx_rooms set seats = greatest(n, greatest(b.min_seats, least(coalesce(p_seats, r.seats), b.max_seats))),
         settings = coalesce(p_settings, settings), updated_at = now() where id = p_room;
end $function$;

CREATE OR REPLACE FUNCTION public.nx_room_capacity(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms; b record; sel int; aud int; role_v text; g text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into r from public.nx_rooms where id = p_room;
  if r.id is null then raise exception 'room not found'; end if;
  if r.is_private and r.host is distinct from auth.uid() and not public.nx_in_room(r.id) and not public.nx_is_room_member(r.id) then
    raise exception 'room not visible';
  end if;
  g := coalesce(r.selected_game, r.game);
  select * into b from public.nx_game_bounds(g);
  sel := public._nx_room_selected(p_room);
  aud := public._nx_room_audience(p_room);
  role_v := public.nx_room_member_role(p_room);
  return jsonb_build_object(
    'room_id', r.id, 'kind', r.kind, 'game', g, 'status', r.status,
    'min_players', greatest(2, b.min_seats), 'max_players', b.max_seats,
    'capacity', greatest(b.min_seats, least(coalesce(r.seats, b.max_seats), b.max_seats)),
    'selected', sel, 'audience', aud, 'locked', coalesce(r.join_locked, false),
    'is_manager', public._nx_room_can_manage(p_room), 'role', role_v);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_matches;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select * into m from nx_matches where id = p_match;
  if m.id is null or m.players[1] is distinct from auth.uid() then raise exception 'authority only'; end if;
  if not (p_user = any(m.players)) then raise exception 'not a player'; end if;
  insert into nx_match_secrets(match_id, user_id, slot, data) values (p_match, p_user, p_slot, p_data)
  on conflict (match_id, user_id, slot) do update set data = excluded.data, created_at = now();
end $function$;

do $grants$
declare f record;
  keep text[] := array['buy_cosmetic', 'equip_cosmetic', 'is_admin', 'is_owner', 'level_for_xp', 'my_cosmetics', 'nx_admin_close_room', 'nx_admin_end_match', 'nx_admin_kick', 'nx_admin_live_matches', 'nx_admin_mute', 'nx_admin_room_clear_chat', 'nx_admin_room_members', 'nx_admin_room_message', 'nx_admin_room_update', 'nx_admin_rooms', 'nx_admin_rooms_broadcast', 'nx_arcade_limits', 'nx_arcade_submit', 'nx_arcade_top', 'nx_create_room', 'nx_finish_match', 'nx_forfeit', 'nx_g_hello', 'nx_g_is_muted', 'nx_g_push', 'nx_game_bounds', 'nx_has_perm', 'nx_idle_forfeit', 'nx_in_match', 'nx_in_room', 'nx_invite', 'nx_is_owner', 'nx_is_room_member', 'nx_join_room', 'nx_known_game', 'nx_leave_room', 'nx_lobby_ping', 'nx_match_ping', 'nx_match_turn', 'nx_my_active_match', 'nx_owner_tournaments', 'nx_perm', 'nx_push_move', 'nx_put_secret', 'nx_quick', 'nx_quick_cancel', 'nx_quiz_answer', 'nx_quiz_start', 'nx_quiz_state', 'nx_room_capacity', 'nx_room_change_game', 'nx_room_close', 'nx_room_join', 'nx_room_kick', 'nx_room_leave', 'nx_room_member_role', 'nx_room_open', 'nx_room_ping', 'nx_room_select_players', 'nx_room_send_message', 'nx_room_set_capacity', 'nx_room_set_locked', 'nx_room_set_muted', 'nx_room_set_prefs', 'nx_room_set_role', 'nx_room_set_settings', 'nx_room_transfer_host', 'nx_set_ready', 'nx_start_match', 'nx_start_room_match', 'nx_t_admin', 'nx_t_admin_match', 'nx_t_can_manage', 'nx_t_checkin', 'nx_t_code_create', 'nx_t_code_peek', 'nx_t_code_revoke', 'nx_t_decide', 'nx_t_dispute', 'nx_t_gem_budget_left', 'nx_t_is_admin', 'nx_t_is_organizer', 'nx_t_join_code', 'nx_t_logs', 'nx_t_mark_read', 'nx_t_my_role', 'nx_t_ready', 'nx_t_register', 'nx_t_remove_entry', 'nx_t_report', 'nx_t_save', 'nx_t_set_runner', 'nx_t_set_seed', 'nx_t_standings', 'nx_t_visible', 'nx_t_withdraw', 'nx_talk_rooms', 'nx_unlimited', 'nx_update_room'];
begin
  for f in select p.oid::regprocedure as sig, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prokind = 'f'
              and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    if f.proname = any(keep) then execute format('grant execute on function %s to authenticated', f.sig); end if;
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $grants$;

alter default privileges for role postgres in schema public revoke execute on functions from public, anon;
alter default privileges in schema public revoke execute on functions from public, anon;
