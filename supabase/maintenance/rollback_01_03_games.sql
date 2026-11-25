-- rollback snapshot taken 2026-11-25T17:04:25Z from project eyzafhrefnqlwcjpcdyg (state BEFORE the fix)
CREATE OR REPLACE FUNCTION public.nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_matches;
begin
  select * into m from nx_matches where id = p_match;
  if m.id is null or m.players[1] <> auth.uid() then raise exception 'authority only'; end if;
  if not (p_user = any(m.players)) then raise exception 'not a player'; end if;
  insert into nx_match_secrets(match_id, user_id, slot, data) values (p_match, p_user, p_slot, p_data)
  on conflict (match_id, user_id, slot) do update set data = excluded.data, created_at = now();
end $function$
;
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
  if r.is_private and r.host <> auth.uid() and not public.nx_in_room(r.id) and not public.nx_is_room_member(r.id) then
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
end $function$
;
CREATE OR REPLACE FUNCTION public.nx_start_match(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); r public.nx_rooms; b record; ids uuid[]; nm text[]; mid uuid; sd bigint; n int; cap int;
begin
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if r.host <> me and not r.quick then raise exception 'host only'; end if;
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
end $function$
;
CREATE OR REPLACE FUNCTION public.nx_update_room(p_room uuid, p_seats integer, p_settings jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r nx_rooms; b record; n int;
begin
  select * into r from nx_rooms where id = p_room for update;
  if r.host <> auth.uid() then raise exception 'host only'; end if;
  if r.status <> 'lobby' then raise exception 'already started'; end if;
  select * into b from nx_game_bounds(r.game);
  select count(*) into n from nx_room_players where room_id = p_room;
  update nx_rooms set seats = greatest(n, greatest(b.min_seats, least(coalesce(p_seats, r.seats), b.max_seats))),
         settings = coalesce(p_settings, settings), updated_at = now() where id = p_room;
end $function$
;
revoke all on function _nx_t_bo(nx_tournaments,text) from public, anon, authenticated;
revoke all on function _nx_t_new_code() from public, anon, authenticated;
revoke all on function _nx_t_notify_managers(uuid,uuid,text,jsonb,text) from public, anon, authenticated;
revoke all on function _nx_t_on_match_end() from public, anon, authenticated;
revoke all on function nx_apply_physics_contract() from public, anon, authenticated;
revoke all on function nx_set_ready(uuid,boolean) from public, anon, authenticated; grant execute on function nx_set_ready(uuid,boolean) to anon; grant execute on function nx_set_ready(uuid,boolean) to authenticated;
revoke all on function nx_start_match(uuid) from public, anon, authenticated; grant execute on function nx_start_match(uuid) to anon; grant execute on function nx_start_match(uuid) to authenticated;
revoke all on function nx_t_admin_match(uuid,text,jsonb) from public, anon, authenticated; grant execute on function nx_t_admin_match(uuid,text,jsonb) to authenticated;
revoke all on function _nx_secret(text) from public, anon, authenticated;
revoke all on function _nx_profiles_delta() from public, anon, authenticated; grant execute on function _nx_profiles_delta() to public; grant execute on function _nx_profiles_delta() to anon; grant execute on function _nx_profiles_delta() to authenticated;
revoke all on function _nx_wallet_tx_kick() from public, anon, authenticated; grant execute on function _nx_wallet_tx_kick() to public; grant execute on function _nx_wallet_tx_kick() to anon; grant execute on function _nx_wallet_tx_kick() to authenticated;
revoke all on function nx_has_perm(text,uuid) from public, anon, authenticated; grant execute on function nx_has_perm(text,uuid) to public; grant execute on function nx_has_perm(text,uuid) to anon; grant execute on function nx_has_perm(text,uuid) to authenticated;
revoke all on function nx_is_owner(uuid) from public, anon, authenticated; grant execute on function nx_is_owner(uuid) to public; grant execute on function nx_is_owner(uuid) to anon; grant execute on function nx_is_owner(uuid) to authenticated;
revoke all on function level_for_xp(integer) from public, anon, authenticated; grant execute on function level_for_xp(integer) to public; grant execute on function level_for_xp(integer) to anon; grant execute on function level_for_xp(integer) to authenticated;
revoke all on function nx_perm(text) from public, anon, authenticated; grant execute on function nx_perm(text) to public; grant execute on function nx_perm(text) to anon; grant execute on function nx_perm(text) to authenticated;
revoke all on function is_owner(uuid) from public, anon, authenticated; grant execute on function is_owner(uuid) to public; grant execute on function is_owner(uuid) to anon; grant execute on function is_owner(uuid) to authenticated;
revoke all on function is_admin(uuid) from public, anon, authenticated; grant execute on function is_admin(uuid) to public; grant execute on function is_admin(uuid) to anon; grant execute on function is_admin(uuid) to authenticated;
revoke all on function nx_t_is_admin(uuid) from public, anon, authenticated; grant execute on function nx_t_is_admin(uuid) to public; grant execute on function nx_t_is_admin(uuid) to anon; grant execute on function nx_t_is_admin(uuid) to authenticated;
revoke all on function nx_t_is_organizer(uuid) from public, anon, authenticated; grant execute on function nx_t_is_organizer(uuid) to public; grant execute on function nx_t_is_organizer(uuid) to anon; grant execute on function nx_t_is_organizer(uuid) to authenticated;
revoke all on function nx_mirror_put(jsonb) from public, anon, authenticated;
revoke all on function nx_unlimited(uuid) from public, anon, authenticated; grant execute on function nx_unlimited(uuid) to public; grant execute on function nx_unlimited(uuid) to anon; grant execute on function nx_unlimited(uuid) to authenticated;
revoke all on function _nx_owner_guard() from public, anon, authenticated;
revoke all on function _nx_t_planned(nx_tournaments,integer) from public, anon, authenticated;
revoke all on function _nx_t_prize_total(integer,integer,integer,integer) from public, anon, authenticated;
revoke all on function _nx_t_refund(uuid,uuid,text) from public, anon, authenticated;
revoke all on function nx_wallet_push() from public, anon, authenticated;
revoke all on function nx_g_hello() from public, anon, authenticated; grant execute on function nx_g_hello() to public; grant execute on function nx_g_hello() to anon; grant execute on function nx_g_hello() to authenticated;
revoke all on function nx_staff_put(jsonb,boolean) from public, anon, authenticated;
revoke all on function _nx_apply_result(nx_matches,integer[],integer[]) from public, anon, authenticated;
revoke all on function _nx_leave_all(uuid) from public, anon, authenticated;
revoke all on function _nx_t_audit(uuid,uuid,text,jsonb) from public, anon, authenticated;
revoke all on function _nx_t_better_seed(uuid,uuid,uuid) from public, anon, authenticated;
revoke all on function _nx_t_cancel(uuid,text,uuid) from public, anon, authenticated;
revoke all on function _nx_t_cfg_bool(jsonb,text,boolean) from public, anon, authenticated;
revoke all on function _nx_t_cfg_int(jsonb,text,integer) from public, anon, authenticated;
revoke all on function _nx_t_charge(uuid,uuid,integer,integer) from public, anon, authenticated;
revoke all on function _nx_t_check(uuid) from public, anon, authenticated;
revoke all on function _nx_t_check_code(uuid,uuid,text) from public, anon, authenticated;
revoke all on function _nx_t_complete(uuid,uuid,uuid,boolean,text,text) from public, anon, authenticated;
revoke all on function _nx_t_dispute(uuid,uuid,text) from public, anon, authenticated;
revoke all on function _nx_t_downstream_free(uuid) from public, anon, authenticated;
revoke all on function _nx_t_draw(uuid,uuid) from public, anon, authenticated;
revoke all on function _nx_t_fill_from_waitlist(uuid) from public, anon, authenticated;
revoke all on function _nx_t_finish(uuid) from public, anon, authenticated;
revoke all on function _nx_t_game_result(uuid,uuid,integer,integer,text) from public, anon, authenticated;
revoke all on function nx_t_can_manage(uuid,uuid) from public, anon, authenticated; grant execute on function nx_t_can_manage(uuid,uuid) to anon; grant execute on function nx_t_can_manage(uuid,uuid) to authenticated;
revoke all on function _nx_t_gen_de(uuid,uuid[]) from public, anon, authenticated;
revoke all on function _nx_t_gen_on() from public, anon, authenticated;
revoke all on function _nx_t_gen_rr(uuid,uuid[],integer,boolean,integer,integer,text,text) from public, anon, authenticated;
revoke all on function _nx_t_gen_se(uuid,uuid[],text,integer,integer) from public, anon, authenticated;
revoke all on function _nx_t_job(text,uuid,uuid,timestamp with time zone,text) from public, anon, authenticated;
revoke all on function _nx_t_launch(uuid) from public, anon, authenticated;
revoke all on function _nx_t_lb_count(integer,integer) from public, anon, authenticated;
revoke all on function _nx_t_mid(uuid,text,text,integer,integer) from public, anon, authenticated;
revoke all on function nx_t_save(jsonb) from public, anon, authenticated; grant execute on function nx_t_save(jsonb) to authenticated;
revoke all on function _nx_t_new_match(nx_tournaments,text,text,integer,integer,integer,integer,integer,text) from public, anon, authenticated;
revoke all on function _nx_t_no_show(uuid) from public, anon, authenticated;
revoke all on function _nx_t_notify(uuid,uuid,uuid,text,jsonb,text) from public, anon, authenticated;
revoke all on function _nx_t_notify_all(uuid,text,jsonb,text,text[]) from public, anon, authenticated;
revoke all on function _nx_t_open_ready(uuid) from public, anon, authenticated;
revoke all on function _nx_t_payout(uuid) from public, anon, authenticated;
revoke all on function _nx_t_place_elim(uuid,text) from public, anon, authenticated;
revoke all on function _nx_t_progress(uuid) from public, anon, authenticated;
revoke all on function _nx_t_propagate(uuid) from public, anon, authenticated;
revoke all on function _nx_t_put(uuid,integer,uuid) from public, anon, authenticated;
revoke all on function _nx_t_reschedule(uuid) from public, anon, authenticated;
revoke all on function _nx_t_seed_order(integer) from public, anon, authenticated;
revoke all on function _nx_t_sync_jobs(uuid) from public, anon, authenticated;
revoke all on function _nx_t_split(uuid,integer,integer[]) from public, anon, authenticated;
revoke all on function _nx_t_start(uuid,uuid) from public, anon, authenticated;
revoke all on function _nx_t_swiss_round(uuid,integer) from public, anon, authenticated;
revoke all on function _nx_t_table(uuid,text,integer) from public, anon, authenticated;
revoke all on function _nx_t_try_accept(uuid,boolean) from public, anon, authenticated;
revoke all on function _nx_t_validate_cfg(jsonb) from public, anon, authenticated;
revoke all on function nx_in_room(uuid) from public, anon, authenticated; grant execute on function nx_in_room(uuid) to anon; grant execute on function nx_in_room(uuid) to authenticated;
revoke all on function nx_finish_match(uuid,integer[],integer[],text,text) from public, anon, authenticated; grant execute on function nx_finish_match(uuid,integer[],integer[],text,text) to authenticated;
revoke all on function nx_finish_match_as(uuid,integer[],integer) from public, anon, authenticated;
revoke all on function nx_game_bounds(text) from public, anon, authenticated; grant execute on function nx_game_bounds(text) to anon; grant execute on function nx_game_bounds(text) to authenticated;
revoke all on function nx_gen_code() from public, anon, authenticated; grant execute on function nx_gen_code() to anon; grant execute on function nx_gen_code() to authenticated;
revoke all on function nx_in_match(uuid) from public, anon, authenticated; grant execute on function nx_in_match(uuid) to anon; grant execute on function nx_in_match(uuid) to authenticated;
revoke all on function nx_invite(uuid,uuid) from public, anon, authenticated; grant execute on function nx_invite(uuid,uuid) to anon; grant execute on function nx_invite(uuid,uuid) to authenticated;
revoke all on function nx_leave_room(uuid) from public, anon, authenticated; grant execute on function nx_leave_room(uuid) to anon; grant execute on function nx_leave_room(uuid) to authenticated;
revoke all on function nx_my_active_match() from public, anon, authenticated; grant execute on function nx_my_active_match() to authenticated;
revoke all on function nx_owner_tournaments(integer) from public, anon, authenticated; grant execute on function nx_owner_tournaments(integer) to authenticated;
revoke all on function nx_put_secret(uuid,uuid,text,jsonb) from public, anon, authenticated; grant execute on function nx_put_secret(uuid,uuid,text,jsonb) to anon; grant execute on function nx_put_secret(uuid,uuid,text,jsonb) to authenticated;
revoke all on function nx_start_match_quick(uuid) from public, anon, authenticated;
revoke all on function nx_t_admin(uuid,text,text) from public, anon, authenticated; grant execute on function nx_t_admin(uuid,text,text) to authenticated;
revoke all on function nx_t_code_create(uuid,integer,timestamp with time zone,boolean,integer) from public, anon, authenticated; grant execute on function nx_t_code_create(uuid,integer,timestamp with time zone,boolean,integer) to authenticated;
revoke all on function nx_t_code_revoke(uuid) from public, anon, authenticated; grant execute on function nx_t_code_revoke(uuid) to authenticated;
revoke all on function _nx_t_notif_guard() from public, anon, authenticated;
revoke all on function nx_t_decide(uuid,uuid,boolean,text) from public, anon, authenticated; grant execute on function nx_t_decide(uuid,uuid,boolean,text) to authenticated;
revoke all on function nx_t_dispute(uuid,text) from public, anon, authenticated; grant execute on function nx_t_dispute(uuid,text) to authenticated;
revoke all on function nx_t_logs(uuid) from public, anon, authenticated; grant execute on function nx_t_logs(uuid) to authenticated;
revoke all on function nx_t_mark_read() from public, anon, authenticated; grant execute on function nx_t_mark_read() to authenticated;
revoke all on function nx_t_ready(uuid) from public, anon, authenticated; grant execute on function nx_t_ready(uuid) to authenticated;
revoke all on function nx_t_register(uuid,text) from public, anon, authenticated; grant execute on function nx_t_register(uuid,text) to authenticated;
revoke all on function nx_t_remove_entry(uuid,uuid,text) from public, anon, authenticated; grant execute on function nx_t_remove_entry(uuid,uuid,text) to authenticated;
revoke all on function nx_t_report(uuid,integer,integer,integer) from public, anon, authenticated; grant execute on function nx_t_report(uuid,integer,integer,integer) to authenticated;
revoke all on function nx_t_set_runner(uuid,uuid,boolean) from public, anon, authenticated; grant execute on function nx_t_set_runner(uuid,uuid,boolean) to authenticated;
revoke all on function nx_admin_room_members(uuid) from public, anon, authenticated; grant execute on function nx_admin_room_members(uuid) to authenticated;
revoke all on function nx_t_set_seed(uuid,uuid,integer) from public, anon, authenticated; grant execute on function nx_t_set_seed(uuid,uuid,integer) to authenticated;
revoke all on function nx_t_standings(uuid) from public, anon, authenticated; grant execute on function nx_t_standings(uuid) to authenticated;
revoke all on function nx_t_tick() from public, anon, authenticated;
revoke all on function nx_t_visible(uuid) from public, anon, authenticated; grant execute on function nx_t_visible(uuid) to anon; grant execute on function nx_t_visible(uuid) to authenticated;
revoke all on function nx_t_withdraw(uuid) from public, anon, authenticated; grant execute on function nx_t_withdraw(uuid) to authenticated;
revoke all on function nx_update_room(uuid,integer,jsonb) from public, anon, authenticated; grant execute on function nx_update_room(uuid,integer,jsonb) to anon; grant execute on function nx_update_room(uuid,integer,jsonb) to authenticated;
revoke all on function _nx_t_ledger_immutable() from public, anon, authenticated;
revoke all on function nx_t_join_code(text) from public, anon, authenticated; grant execute on function nx_t_join_code(text) to authenticated;
revoke all on function nx_t_my_role() from public, anon, authenticated; grant execute on function nx_t_my_role() to authenticated;
revoke all on function nx_admin_rooms(integer) from public, anon, authenticated; grant execute on function nx_admin_rooms(integer) to authenticated;
revoke all on function nx_admin_close_room(uuid,text) from public, anon, authenticated; grant execute on function nx_admin_close_room(uuid,text) to authenticated;
revoke all on function nx_t_gem_budget_left(uuid,uuid) from public, anon, authenticated; grant execute on function nx_t_gem_budget_left(uuid,uuid) to public; grant execute on function nx_t_gem_budget_left(uuid,uuid) to anon; grant execute on function nx_t_gem_budget_left(uuid,uuid) to authenticated;
revoke all on function _nx_t_run_job(nx_t_jobs) from public, anon, authenticated;
revoke all on function nx_room_leave(uuid) from public, anon, authenticated; grant execute on function nx_room_leave(uuid) to public; grant execute on function nx_room_leave(uuid) to anon; grant execute on function nx_room_leave(uuid) to authenticated;
revoke all on function nx_t_checkin(uuid) from public, anon, authenticated; grant execute on function nx_t_checkin(uuid) to authenticated;
revoke all on function nx_known_game(text) from public, anon, authenticated; grant execute on function nx_known_game(text) to public; grant execute on function nx_known_game(text) to anon; grant execute on function nx_known_game(text) to authenticated;
revoke all on function nx_arcade_limits(text) from public, anon, authenticated; grant execute on function nx_arcade_limits(text) to public; grant execute on function nx_arcade_limits(text) to anon; grant execute on function nx_arcade_limits(text) to authenticated;
revoke all on function nx_arcade_submit(text,integer,integer,boolean,jsonb) from public, anon, authenticated; grant execute on function nx_arcade_submit(text,integer,integer,boolean,jsonb) to public; grant execute on function nx_arcade_submit(text,integer,integer,boolean,jsonb) to anon; grant execute on function nx_arcade_submit(text,integer,integer,boolean,jsonb) to authenticated;
revoke all on function nx_arcade_top(text,boolean,integer) from public, anon, authenticated; grant execute on function nx_arcade_top(text,boolean,integer) to public; grant execute on function nx_arcade_top(text,boolean,integer) to anon; grant execute on function nx_arcade_top(text,boolean,integer) to authenticated;
revoke all on function nx_room_member_role(uuid) from public, anon, authenticated; grant execute on function nx_room_member_role(uuid) to public; grant execute on function nx_room_member_role(uuid) to anon; grant execute on function nx_room_member_role(uuid) to authenticated;
revoke all on function nx_room_set_role(uuid,uuid,text) from public, anon, authenticated; grant execute on function nx_room_set_role(uuid,uuid,text) to authenticated;
revoke all on function nx_room_send_message(uuid,text) from public, anon, authenticated; grant execute on function nx_room_send_message(uuid,text) to public; grant execute on function nx_room_send_message(uuid,text) to anon; grant execute on function nx_room_send_message(uuid,text) to authenticated;
revoke all on function nx_start_room_match(uuid) from public, anon, authenticated; grant execute on function nx_start_room_match(uuid) to public; grant execute on function nx_start_room_match(uuid) to anon; grant execute on function nx_start_room_match(uuid) to authenticated;
revoke all on function _nx_g_turn_times(text) from public, anon, authenticated; grant execute on function _nx_g_turn_times(text) to public; grant execute on function _nx_g_turn_times(text) to anon; grant execute on function _nx_g_turn_times(text) to authenticated;
revoke all on function nx_room_ping(uuid) from public, anon, authenticated; grant execute on function nx_room_ping(uuid) to authenticated;
revoke all on function nx_room_open(text,boolean,text) from public, anon, authenticated; grant execute on function nx_room_open(text,boolean,text) to authenticated;
revoke all on function nx_room_set_prefs(uuid,jsonb) from public, anon, authenticated; grant execute on function nx_room_set_prefs(uuid,jsonb) to authenticated;
revoke all on function nx_room_set_settings(uuid,jsonb) from public, anon, authenticated; grant execute on function nx_room_set_settings(uuid,jsonb) to authenticated;
revoke all on function _nx_server_result_guard() from public, anon, authenticated; grant execute on function _nx_server_result_guard() to public; grant execute on function _nx_server_result_guard() to anon; grant execute on function _nx_server_result_guard() to authenticated;
revoke all on function _nx_quiz_const() from public, anon, authenticated; grant execute on function _nx_quiz_const() to public; grant execute on function _nx_quiz_const() to anon; grant execute on function _nx_quiz_const() to authenticated;
revoke all on function _nx_quiz_tick(uuid) from public, anon, authenticated;
revoke all on function _nx_forfeited_seats(uuid) from public, anon, authenticated;
revoke all on function nx_quiz_state(uuid) from public, anon, authenticated; grant execute on function nx_quiz_state(uuid) to authenticated;
revoke all on function _nx_room_seat_limit(text) from public, anon, authenticated; grant execute on function _nx_room_seat_limit(text) to public; grant execute on function _nx_room_seat_limit(text) to anon; grant execute on function _nx_room_seat_limit(text) to authenticated;
revoke all on function nx_room_join(uuid,text) from public, anon, authenticated; grant execute on function nx_room_join(uuid,text) to authenticated;
revoke all on function nx_is_room_member(uuid) from public, anon, authenticated; grant execute on function nx_is_room_member(uuid) to public; grant execute on function nx_is_room_member(uuid) to anon; grant execute on function nx_is_room_member(uuid) to authenticated;
revoke all on function nx_lobby_ping(uuid) from public, anon, authenticated; grant execute on function nx_lobby_ping(uuid) to authenticated;
revoke all on function nx_admin_mute(uuid,integer,text) from public, anon, authenticated; grant execute on function nx_admin_mute(uuid,integer,text) to authenticated;
revoke all on function nx_admin_live_matches(integer) from public, anon, authenticated; grant execute on function nx_admin_live_matches(integer) to authenticated;
revoke all on function nx_admin_kick(uuid,uuid,text) from public, anon, authenticated; grant execute on function nx_admin_kick(uuid,uuid,text) to authenticated;
revoke all on function nx_admin_end_match(uuid,text) from public, anon, authenticated; grant execute on function nx_admin_end_match(uuid,text) to authenticated;
revoke all on function nx_g_is_muted(uuid) from public, anon, authenticated; grant execute on function nx_g_is_muted(uuid) to public; grant execute on function nx_g_is_muted(uuid) to anon; grant execute on function nx_g_is_muted(uuid) to authenticated;
revoke all on function nx_admin_room_message(uuid,text) from public, anon, authenticated; grant execute on function nx_admin_room_message(uuid,text) to authenticated;
revoke all on function nx_admin_rooms_broadcast(text) from public, anon, authenticated; grant execute on function nx_admin_rooms_broadcast(text) to authenticated;
revoke all on function nx_admin_room_clear_chat(uuid) from public, anon, authenticated; grant execute on function nx_admin_room_clear_chat(uuid) to authenticated;
revoke all on function _nx_room_selected(uuid) from public, anon, authenticated; grant execute on function _nx_room_selected(uuid) to public; grant execute on function _nx_room_selected(uuid) to anon; grant execute on function _nx_room_selected(uuid) to authenticated;
revoke all on function _nx_room_audience(uuid) from public, anon, authenticated; grant execute on function _nx_room_audience(uuid) to public; grant execute on function _nx_room_audience(uuid) to anon; grant execute on function _nx_room_audience(uuid) to authenticated;
revoke all on function nx_admin_room_update(uuid,boolean,integer,text) from public, anon, authenticated; grant execute on function nx_admin_room_update(uuid,boolean,integer,text) to authenticated;
revoke all on function nx_room_select_players(uuid,uuid[]) from public, anon, authenticated; grant execute on function nx_room_select_players(uuid,uuid[]) to public; grant execute on function nx_room_select_players(uuid,uuid[]) to anon; grant execute on function nx_room_select_players(uuid,uuid[]) to authenticated;
revoke all on function nx_room_change_game(uuid,text) from public, anon, authenticated; grant execute on function nx_room_change_game(uuid,text) to public; grant execute on function nx_room_change_game(uuid,text) to anon; grant execute on function nx_room_change_game(uuid,text) to authenticated;
revoke all on function nx_room_close(uuid) from public, anon, authenticated; grant execute on function nx_room_close(uuid) to authenticated;
revoke all on function nx_room_set_muted(uuid,uuid,boolean) from public, anon, authenticated; grant execute on function nx_room_set_muted(uuid,uuid,boolean) to authenticated;
revoke all on function nx_room_set_capacity(uuid,integer) from public, anon, authenticated; grant execute on function nx_room_set_capacity(uuid,integer) to authenticated;
revoke all on function nx_room_set_locked(uuid,boolean) from public, anon, authenticated; grant execute on function nx_room_set_locked(uuid,boolean) to authenticated;
revoke all on function nx_room_capacity(uuid) from public, anon, authenticated; grant execute on function nx_room_capacity(uuid) to authenticated;
revoke all on function nx_room_kick(uuid,uuid) from public, anon, authenticated; grant execute on function nx_room_kick(uuid,uuid) to authenticated;
revoke all on function nx_talk_rooms() from public, anon, authenticated; grant execute on function nx_talk_rooms() to authenticated;
revoke all on function _nx_room_can_manage(uuid) from public, anon, authenticated; grant execute on function _nx_room_can_manage(uuid) to public; grant execute on function _nx_room_can_manage(uuid) to anon; grant execute on function _nx_room_can_manage(uuid) to authenticated;
revoke all on function nx_create_room(text,integer,boolean,boolean,jsonb) from public, anon, authenticated; grant execute on function nx_create_room(text,integer,boolean,boolean,jsonb) to authenticated;
revoke all on function nx_room_transfer_host(uuid,uuid) from public, anon, authenticated; grant execute on function nx_room_transfer_host(uuid,uuid) to authenticated;
revoke all on function nx_match_ping(uuid) from public, anon, authenticated; grant execute on function nx_match_ping(uuid) to authenticated;
revoke all on function _nx_player_active(uuid,uuid,integer,integer) from public, anon, authenticated;
revoke all on function _nx_room_after_match(uuid,uuid) from public, anon, authenticated;
revoke all on function nx_t_code_peek(text) from public, anon, authenticated; grant execute on function nx_t_code_peek(text) to authenticated;
revoke all on function _nx_quick_seats(text,integer) from public, anon, authenticated; grant execute on function _nx_quick_seats(text,integer) to public; grant execute on function _nx_quick_seats(text,integer) to anon; grant execute on function _nx_quick_seats(text,integer) to authenticated;
revoke all on function _nx_quick_lock(text,integer) from public, anon, authenticated;
revoke all on function nx_match_turn(uuid,integer,bigint,integer) from public, anon, authenticated; grant execute on function nx_match_turn(uuid,integer,bigint,integer) to authenticated;
revoke all on function nx_quick(text,integer) from public, anon, authenticated; grant execute on function nx_quick(text,integer) to authenticated;
revoke all on function nx_quick_cancel(uuid) from public, anon, authenticated; grant execute on function nx_quick_cancel(uuid) to authenticated;
revoke all on function nx_forfeit(uuid,integer) from public, anon, authenticated; grant execute on function nx_forfeit(uuid,integer) to authenticated;
revoke all on function nx_push_move(uuid,integer,text,jsonb,text,integer) from public, anon, authenticated; grant execute on function nx_push_move(uuid,integer,text,jsonb,text,integer) to authenticated;
revoke all on function nx_g_push(uuid,integer,text,jsonb,text,integer) from public, anon, authenticated; grant execute on function nx_g_push(uuid,integer,text,jsonb,text,integer) to authenticated;
revoke all on function nx_join_room(text,uuid) from public, anon, authenticated; grant execute on function nx_join_room(text,uuid) to anon; grant execute on function nx_join_room(text,uuid) to authenticated;
revoke all on function nx_quiz_answer(uuid,integer,integer) from public, anon, authenticated; grant execute on function nx_quiz_answer(uuid,integer,integer) to authenticated;
revoke all on function nx_quiz_start(uuid,text) from public, anon, authenticated; grant execute on function nx_quiz_start(uuid,text) to authenticated;
revoke all on function _nx_match_authority(uuid) from public, anon, authenticated;
revoke all on function nx_idle_forfeit(uuid,integer) from public, anon, authenticated; grant execute on function nx_idle_forfeit(uuid,integer) to authenticated;
revoke all on function buy_cosmetic(text) from public, anon, authenticated; grant execute on function buy_cosmetic(text) to authenticated;
revoke all on function equip_cosmetic(text) from public, anon, authenticated; grant execute on function equip_cosmetic(text) to authenticated;
revoke all on function my_cosmetics() from public, anon, authenticated; grant execute on function my_cosmetics() to authenticated;
