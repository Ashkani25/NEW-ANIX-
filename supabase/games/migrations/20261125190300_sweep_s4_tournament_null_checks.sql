-- Sweep S4 (games tournaments): `not (me = m.p1 or me = m.p2)` is NULL (= passes) while a slot is still empty (TBD/bye),
-- so ANY signed-in user could report, ready up or dispute such a match. NULL-safe membership checks + winner-seat check.

CREATE OR REPLACE FUNCTION public.nx_t_report(p_game uuid, p_winner_seat integer, p_s0 integer, p_s1 integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); g nx_t_games; w uuid;
begin
  select * into g from nx_t_games where game_match = p_game;
  if g.game_match is null or me is null or (me is distinct from g.home and me is distinct from g.away) then
    return jsonb_build_object('ok', false, 'error', 'not_a_player'); end if;
  if p_winner_seat is null or p_winner_seat not in (-1, 0, 1) or p_s0 is null or p_s1 is null or p_s0 not between 0 and 99 or p_s1 not between 0 and 99 then
    return jsonb_build_object('ok', false, 'error', 'bad_report'); end if;
  if (p_winner_seat = 0 and p_s0 < p_s1) or (p_winner_seat = 1 and p_s1 < p_s0) or (p_winner_seat = -1 and p_s0 <> p_s1) then
    return jsonb_build_object('ok', false, 'error', 'inconsistent_report'); end if;
  w := case p_winner_seat when 0 then g.home when 1 then g.away end;
  insert into nx_t_reports(game_match, user_id, winner, s_home, s_away) values (p_game, me, w, p_s0, p_s1)
  on conflict (game_match, user_id) do nothing;
  perform _nx_t_try_accept(p_game, false);
  return jsonb_build_object('ok', true, 'accepted', (select accepted from nx_t_games where game_match = p_game),
                            'disputed', (select disputed from nx_t_games where game_match = p_game));
end $function$;

CREATE OR REPLACE FUNCTION public.nx_t_dispute(p_m uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m nx_t_matches;
begin
  select * into m from nx_t_matches where id = p_m;
  if m.id is null or me is null or (me is distinct from m.p1 and me is distinct from m.p2) then return jsonb_build_object('ok', false, 'error', 'not_a_player'); end if;
  if m.status in ('done', 'walkover', 'bye', 'void', 'skipped') then return jsonb_build_object('ok', false, 'error', 'too_late'); end if;
  perform _nx_t_dispute(p_m, me, coalesce(nullif(left(p_reason, 120), ''), 'player_dispute'));
  return jsonb_build_object('ok', true);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_t_ready(p_m uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m nx_t_matches; t nx_tournaments; gm uuid;
begin
  select * into m from nx_t_matches where id = p_m for update;
  if m.id is null or me is null or (me is distinct from m.p1 and me is distinct from m.p2) then return jsonb_build_object('ok', false, 'error', 'not_a_player'); end if;
  if m.status = 'playing' then return jsonb_build_object('ok', true, 'status', 'playing', 'game_match', m.game_match); end if;
  if m.status <> 'ready_check' then return jsonb_build_object('ok', false, 'error', 'not_ready_time', 'status', m.status); end if;
  select * into t from nx_tournaments where id = m.tournament_id;
  if t.paused or t.status <> 'live' then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  if me = m.p1 then update nx_t_matches set p1_ready = true, updated_at = now() where id = p_m returning * into m;
  else update nx_t_matches set p2_ready = true, updated_at = now() where id = p_m returning * into m; end if;
  if m.p1_ready and m.p2_ready then
    gm := _nx_t_launch(p_m);
    return jsonb_build_object('ok', true, 'status', 'playing', 'game_match', gm);
  end if;
  return jsonb_build_object('ok', true, 'status', 'ready_check', 'p1_ready', m.p1_ready, 'p2_ready', m.p2_ready);
end $function$;

