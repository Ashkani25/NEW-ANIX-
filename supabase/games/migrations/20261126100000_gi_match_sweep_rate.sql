-- GAME INTEGRITY (games project): server-side match sweep + per-player move rate limit.
--
-- 1. _nx_match_sweep() (pg_cron, every 20 s) closes every online match the phones can no longer close themselves.
--    _nx_hg_sweep (mafia / spy_mafia / uno turn clocks) keeps running unchanged; this sweep covers every other game
--    (ludo, backgammon, snakes & ladders, finger soccer, carrom, billiards, pool, mini golf, quiz, arcade realtime
--    games, ...) and also the hidden games once nobody is left in them (_nx_hg_sweep only ticks while someone is there).
--    The server does not run the game engines, so it never invents a game move; it applies the same rules the
--    authority phone applies (match_link.dart _watchAbsent / nx_forfeit), only later, as a safety net:
--    * Absent seat: a seat that is not forfeited, has not reported a result and has shown no sign of life (match
--      heartbeat nx_match_ping, a move row, the room heartbeat) for 120 s (tournament games: grace_sec + 30 s, at least
--      60 s) is forfeited by a server row (kind 'forfeit', by_user = the all-zero server uuid, move {seat, idle, srv}).
--      A seat on turn whose server turn clock (nx_match_turn_state, written by nx_match_turn) ran out is forfeited
--      after 60 s of silence. Phones apply forfeit rows like any other (seat leaves the game; hidden games step
--      'leave' through _nx_hg_on_forfeit).
--    * One seat left: the match is settled like nx_forfeit does (nx_finish_match_as: the survivor wins, Elo, XP and
--      coins through _nx_apply_result) - unless the survivor already reported a result, then the reports decide.
--    * Everybody gone: settled from the result reports when there are any (same consensus as nx_finish_match: agreeing
--      winners finish, disagreement → the authority's report, else 'disputed' with no rewards); otherwise the match
--      ends 'abandoned' (no rewards) and its room goes back to the lobby / closes (quick rooms).
--    * Stalled: players still connected but nothing happened (no move row, no hidden-game state change, no quiz phase,
--      no report) for 20 min (realtime arcade games: 45 min), or the match is older than 3 h: settled from reports,
--      otherwise 'abandoned'.
--    * Tournament games keep their own rules: the sweep forfeits absent seats as above, but when every player is gone
--      or the game stalls it leaves the game to nx_t_tick (organizer dispute after max_game_minutes) and only closes the
--      match row once the tournament has accepted that game (or no tournament game row exists).
--    Every action is written to nx_match_sweep_log (RLS on, no client access).
-- 2. Per-player move rate limit in nx_push_move / nx_g_push (per player per match, counted on rows actually written,
--    'forfeit' always allowed): at most 12 rows in 3 s and 90 rows in 60 s (the old 40 rows / 2 s flood guard is
--    covered by the burst limit). Turn games post 1-3 rows per turn; realtime games only log results.
-- Forward-only, idempotent, no data is deleted. Rollback: supabase/maintenance/rollback_gi_01_games.sql

-- ---------------------------------------------------------------------------------------------------------------
-- indexes for the per-player counters and the sweep scan
create index if not exists nx_match_moves_user_recent on public.nx_match_moves (match_id, by_user, created_at desc);
create index if not exists nx_matches_playing on public.nx_matches (started_at) where status = 'playing';

-- audit of what the sweep did
create table if not exists public.nx_match_sweep_log (
  id bigserial primary key,
  match_id uuid not null,
  game text,
  action text not null,
  detail jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);
create index if not exists nx_match_sweep_log_match on public.nx_match_sweep_log (match_id, at desc);
alter table public.nx_match_sweep_log enable row level security;
revoke all on table public.nx_match_sweep_log from public, anon, authenticated;
grant all on table public.nx_match_sweep_log to service_role;
grant usage, select on sequence public.nx_match_sweep_log_id_seq to service_role;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. per-player move rate limit
create or replace function public._nx_move_rate_reason(p_match uuid, p_user uuid, p_kind text)
returns text language plpgsql stable security definer set search_path = public as $f$
declare burst int; sustained int;
begin
  if p_kind = 'forfeit' or p_user is null then return null; end if;
  select count(*) filter (where mv.created_at > now() - interval '3 seconds'), count(*)
    into burst, sustained
    from nx_match_moves mv
   where mv.match_id = p_match and mv.by_user = p_user and mv.created_at > now() - interval '60 seconds';
  if burst >= 12 then return 'rate'; end if;
  if sustained >= 90 then return 'rate'; end if;
  return null;
end $f$;
revoke all on function public._nx_move_rate_reason(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public._nx_move_rate_reason(uuid, uuid, text) to service_role;

CREATE OR REPLACE FUNCTION public.nx_push_move(p_match uuid, p_seq integer, p_kind text, p_move jsonb, p_hash text, p_seat integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  m nx_matches;
  caller_seat int;
  effective_seat int;
  n int;
  k text := left(coalesce(p_kind, 'move'), 16);
  vk text;           -- the real kind (app wraps 'move' / 'timeout' as 'system' with move->>'_k')
  gone int[];
  alive int[];
  rr text;
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into m from nx_matches where id = p_match for update;
  if m.id is null then raise exception 'match not found'; end if;
  caller_seat := array_position(m.players, me) - 1;
  if caller_seat is null then raise exception 'not a player'; end if;
  if m.status <> 'playing' then
    return jsonb_build_object('ok', false, 'reason', 'over', 'last_seq', m.last_seq);
  end if;
  if p_seq <> m.last_seq + 1 then
    return jsonb_build_object('ok', false, 'reason', 'seq', 'last_seq', m.last_seq);
  end if;
  if pg_column_size(coalesce(p_move, '{}'::jsonb)) > 16000 then
    return jsonb_build_object('ok', false, 'reason', 'too_large');
  end if;
  n := coalesce(array_length(m.players, 1), 0);
  if p_seat is not null and (p_seat < 0 or p_seat >= n) then
    return jsonb_build_object('ok', false, 'reason', 'bad_seat');
  end if;
  effective_seat := coalesce(p_seat, caller_seat);
  vk := case when k = 'system' and jsonb_typeof(p_move) = 'object' and (p_move ? '_k')
             then left(p_move ->> '_k', 16) else k end;

  gone := public._nx_forfeited_seats(p_match);
  if caller_seat = any(gone) and vk <> 'forfeit' then
    return jsonb_build_object('ok', false, 'reason', 'forfeited', 'last_seq', m.last_seq);
  end if;
  -- seat ownership: gameplay moves and forfeits only for the caller's own seat; the authority may post a snapshot,
  -- a timeout or a genuine system row (pre-match default for an absent side) for another seat
  if effective_seat <> caller_seat and vk not in ('snap', 'timeout', 'system') then
    return jsonb_build_object('ok', false, 'reason', 'seat', 'last_seq', m.last_seq);
  end if;
  -- #7: rows for another seat (timeouts / defaults for absent players) and state snapshots only from the authority
  if (effective_seat <> caller_seat or k = 'snap' or vk = 'snap')
     and not public._nx_may_act_as_authority(p_match, caller_seat) then
    return jsonb_build_object('ok', false, 'reason', 'not_authority', 'last_seq', m.last_seq,
                              'authority', public._nx_match_authority(p_match));
  end if;
  -- GI: per-player rate limit (12 rows / 3 s, 90 rows / 60 s per match; forfeits always pass)
  rr := public._nx_move_rate_reason(p_match, me, vk);
  if rr is not null then
    return jsonb_build_object('ok', false, 'reason', rr, 'last_seq', m.last_seq);
  end if;
  if vk = 'forfeit' and effective_seat = any(gone) then
    return jsonb_build_object('ok', false, 'reason', 'forfeited', 'last_seq', m.last_seq);
  end if;

  insert into nx_match_moves(match_id, seq, seat, by_user, kind, move, hash)
  values (p_match, p_seq, effective_seat, me, k,
          case when k = 'forfeit' then coalesce(p_move, '{}'::jsonb) || jsonb_build_object('seat', effective_seat)
               else coalesce(p_move, '{}'::jsonb) end,
          p_hash);

  update nx_matches
     set last_seq = p_seq,
         state_hash = coalesce(p_hash, state_hash),
         turn_seat = effective_seat,
         turn_deadline = now() + interval '45 seconds'
   where id = p_match;

  -- a player who left through the move log: when one seat is left the match ends for everyone
  if k = 'forfeit' then
    select coalesce(array_agg(g), '{}'::int[]) into alive
      from generate_series(0, n - 1) g where not (g = any(gone)) and g <> effective_seat;
    if coalesce(array_length(alive, 1), 0) = 1 then
      perform nx_finish_match_as(p_match, alive, effective_seat);
    end if;
  end if;
  return jsonb_build_object('ok', true, 'seq', p_seq);
end;
$function$;
revoke all on function public.nx_push_move(uuid, integer, text, jsonb, text, integer) from public, anon;
grant execute on function public.nx_push_move(uuid, integer, text, jsonb, text, integer) to authenticated, service_role;

CREATE OR REPLACE FUNCTION public.nx_g_push(p_match uuid, p_seq integer, p_kind text, p_move jsonb, p_hash text, p_seat integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  m nx_matches;
  caller_seat int;
  seat int;
  n int;
  k text := left(coalesce(p_kind, 'move'), 16);
  t record;
  cur int;
  dl timestamptz;
  nt int;
  rr text;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select * into m from nx_matches where id = p_match for update;
  if m.id is null then raise exception 'match not found'; end if;
  if m.game not in ('carrom', 'billiards') then raise exception 'nx_g_push is for carrom/billiards'; end if;
  caller_seat := array_position(m.players, me) - 1;
  if caller_seat is null then raise exception 'not a player'; end if;
  if m.status <> 'playing' then
    return jsonb_build_object('ok', false, 'reason', 'over', 'last_seq', m.last_seq);
  end if;
  if p_seq <> m.last_seq + 1 then
    return jsonb_build_object('ok', false, 'reason', 'seq', 'last_seq', m.last_seq);
  end if;
  if p_seat is not null and p_seat <> caller_seat and k not in ('snap', 'timeout', 'system') then
    raise exception 'seat mismatch';
  end if;
  if p_seat is not null and (p_seat < 0 or p_seat >= coalesce(array_length(m.players, 1), 0)) then
    return jsonb_build_object('ok', false, 'reason', 'bad_seat');
  end if;
  if ((p_seat is not null and p_seat <> caller_seat) or k = 'snap')
     and not public._nx_may_act_as_authority(p_match, caller_seat) then
    return jsonb_build_object('ok', false, 'reason', 'not_authority', 'last_seq', m.last_seq);
  end if;
  -- GI: per-player rate limit (same as nx_push_move)
  rr := public._nx_move_rate_reason(p_match, me, k);
  if rr is not null then
    return jsonb_build_object('ok', false, 'reason', rr, 'last_seq', m.last_seq);
  end if;
  seat := coalesce(p_seat, caller_seat);
  n := greatest(1, coalesce(array_length(m.players, 1), 1));
  select * into t from _nx_g_turn_times(m.game);
  cur := m.turn_seat;
  dl := m.turn_deadline;
  if m.last_seq = 0 then
    if m.game = 'billiards' then cur := (m.seed % 2)::int; end if;
    dl := greatest(dl, m.started_at + interval '60 seconds');
  end if;

  if k = 'move' then
    if seat <> cur then
      return jsonb_build_object('ok', false, 'reason', 'turn', 'turn_seat', cur);
    end if;
    if now() > dl + interval '2 seconds' then
      return jsonb_build_object('ok', false, 'reason', 'timeout', 'turn_seat', cur);
    end if;
    if coalesce(p_move->>'a', '') = 'shot' then
      dl := now() + make_interval(secs => t.sim_s + t.aim_s + 4);
    end if;
  elsif k = 'timeout' then
    if seat <> cur then
      return jsonb_build_object('ok', false, 'reason', 'turn', 'turn_seat', cur);
    end if;
    if now() < dl - interval '5 seconds' then
      return jsonb_build_object('ok', false, 'reason', 'too_early', 'turn_seat', cur);
    end if;
    cur := (cur + 1) % n;
    dl := now() + make_interval(secs => t.aim_s + 4);
  elsif k = 'snap' then
    nt := nullif(p_move->>'nt', '')::int;
    if nt is not null and nt >= 0 and nt < n then
      cur := nt;
      dl := now() + make_interval(secs => t.aim_s + 4);
    end if;
  elsif k not in ('system', 'forfeit') then
    raise exception 'bad kind';
  end if;

  insert into nx_match_moves(match_id, seq, seat, by_user, kind, move, hash)
  values (p_match, p_seq, seat, me, k, coalesce(p_move, '{}'::jsonb), p_hash);
  update nx_matches
     set last_seq = p_seq, state_hash = coalesce(p_hash, state_hash), turn_seat = cur, turn_deadline = dl
   where id = p_match;
  return jsonb_build_object('ok', true, 'seq', p_seq, 'turn_seat', cur);
end;
$function$;
revoke all on function public.nx_g_push(uuid, integer, text, jsonb, text, integer) from public, anon;
grant execute on function public.nx_g_push(uuid, integer, text, jsonb, text, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. server match sweep

-- Last sign of life of a player in a match (never earlier than the match start).
create or replace function public._nx_match_last_seen(p_match uuid, p_user uuid)
returns timestamptz language sql stable security definer set search_path = public as $f$
  select greatest(
    (select m.started_at from nx_matches m where m.id = p_match),
    (select p.last_seen from nx_match_presence p where p.match_id = p_match and p.user_id = p_user),
    (select max(mv.created_at) from nx_match_moves mv where mv.match_id = p_match and mv.by_user = p_user),
    (select rp.last_seen from nx_room_players rp join nx_matches m on m.room_id = rp.room_id
      where m.id = p_match and rp.user_id = p_user))
$f$;
revoke all on function public._nx_match_last_seen(uuid, uuid) from public, anon, authenticated;
grant execute on function public._nx_match_last_seen(uuid, uuid) to service_role;

-- Last time anything happened in a match (any move row, hidden-game state change, quiz phase, result report).
create or replace function public._nx_match_last_progress(p_match uuid)
returns timestamptz language sql stable security definer set search_path = public as $f$
  select greatest(
    (select m.started_at from nx_matches m where m.id = p_match),
    (select max(mv.created_at) from nx_match_moves mv where mv.match_id = p_match),
    (select h.updated_at from nx_hg_state h where h.match_id = p_match),
    (select least(q.phase_started, now()) from nx_quiz_games q where q.match_id = p_match),
    (select max(r.created_at) from nx_match_reports r where r.match_id = p_match))
$f$;
revoke all on function public._nx_match_last_progress(uuid) from public, anon, authenticated;
grant execute on function public._nx_match_last_progress(uuid) to service_role;

-- Ends a match as abandoned (no result, no rewards); its room goes back to the lobby (quick rooms close).
create or replace function public._nx_match_abandon(p_match uuid, p_why text)
returns boolean language plpgsql security definer set search_path = public as $f$
declare m nx_matches;
begin
  update nx_matches set status = 'abandoned', reason = 'abandoned', ended_at = now()
   where id = p_match and status = 'playing' returning * into m;
  if m.id is null then return false; end if;
  perform _nx_room_after_match(m.room_id, m.id);
  insert into nx_match_sweep_log(match_id, game, action, detail)
  values (m.id, m.game, 'abandoned', jsonb_build_object('why', p_why));
  return true;
end $f$;
revoke all on function public._nx_match_abandon(uuid, text) from public, anon, authenticated;
grant execute on function public._nx_match_abandon(uuid, text) to service_role;

-- Settles a match from the result reports already filed (same consensus as nx_finish_match, without waiting for the
-- players who did not report: the caller decided they are gone). Returns 'finished' / 'disputed' / null (no reports).
create or replace function public._nx_match_settle_reports(p_match uuid, p_why text)
returns text language plpgsql security definer set search_path = public as $f$
declare
  m nx_matches; n int; n_sets int; w int[]; sc int[]; k int; a_seat int; ar nx_match_reports; outcome text;
begin
  select * into m from nx_matches where id = p_match and status = 'playing' for update;
  if m.id is null then return null; end if;
  if not exists (select 1 from nx_match_reports r where r.match_id = p_match) then return null; end if;
  n := coalesce(array_length(m.players, 1), 0);
  select count(distinct r.winners) into n_sets from nx_match_reports r where r.match_id = p_match;
  -- quiz results come from the server itself (_nx_quiz_tick → nx_finish_match)
  if m.game = 'quiz' then perform set_config('nx.server_result', '1', true); end if;
  if n_sets = 1 then
    select r.winners into w from nx_match_reports r where r.match_id = p_match limit 1;
    sc := null;
    if not exists (select 1 from nx_match_reports r where r.match_id = p_match and r.scores is null) then
      sc := '{}'::int[];
      for k in 1..n loop
        sc := sc || (select min(r.scores[k]) from nx_match_reports r where r.match_id = p_match);
      end loop;
    end if;
    update nx_matches set status = 'finished', winner_seats = w, scores = sc, reason = 'finished',
           state_hash = coalesce((select max(r.state_hash) from nx_match_reports r where r.match_id = p_match), state_hash),
           ended_at = now()
     where id = p_match returning * into m;
    perform _nx_apply_result(m, w, sc);
    outcome := 'finished';
  else
    a_seat := public._nx_match_authority(p_match);
    select * into ar from nx_match_reports r where r.match_id = p_match and r.user_id = m.players[a_seat + 1];
    if ar.user_id is null then
      update nx_matches set status = 'disputed', winner_seats = null, reason = 'disputed', ended_at = now()
       where id = p_match;
      insert into nx_match_disputes(match_id, user_id, reported, decided, authority_seat)
      select p_match, r.user_id, r.winners, null, a_seat from nx_match_reports r where r.match_id = p_match
      on conflict (match_id, user_id) do nothing;
      outcome := 'disputed';
    else
      w := ar.winners;
      insert into nx_match_disputes(match_id, user_id, reported, decided, authority_seat)
      select p_match, r.user_id, r.winners, w, a_seat from nx_match_reports r
       where r.match_id = p_match and r.winners is distinct from w
      on conflict (match_id, user_id) do nothing;
      update nx_matches set status = 'finished', winner_seats = w, scores = ar.scores,
             reason = coalesce(ar.reason, 'finished'), state_hash = coalesce(ar.state_hash, state_hash), ended_at = now()
       where id = p_match returning * into m;
      perform _nx_apply_result(m, w, ar.scores);
      outcome := 'finished';
    end if;
  end if;
  if m.game = 'quiz' then perform set_config('nx.server_result', '', true); end if;
  perform _nx_room_after_match(m.room_id, m.id);
  insert into nx_match_sweep_log(match_id, game, action, detail)
  values (m.id, m.game, 'settled_' || outcome, jsonb_build_object('why', p_why));
  return outcome;
end $f$;
revoke all on function public._nx_match_settle_reports(uuid, text) from public, anon, authenticated;
grant execute on function public._nx_match_settle_reports(uuid, text) to service_role;

-- A tournament game is closed by the sweep only after the tournament has dealt with it (accepted, or no game row):
-- otherwise the match-end trigger would turn an open dispute into an accepted no-winner game.
create or replace function public._nx_match_tournament_done(p_match uuid)
returns boolean language sql stable security definer set search_path = public as $f$
  select not exists (select 1 from nx_t_games g where g.game_match = p_match and not g.accepted)
$f$;
revoke all on function public._nx_match_tournament_done(uuid) from public, anon, authenticated;
grant execute on function public._nx_match_tournament_done(uuid) to service_role;

-- Sweeps one match. Returns the action taken (null = nothing to do).
create or replace function public._nx_match_sweep_one(p_match uuid)
returns text language plpgsql security definer set search_path = public as $f$
declare
  srv constant uuid := '00000000-0000-0000-0000-000000000000';
  m nx_matches; ts nx_match_turn_state;
  n int; s int; u uuid; gone int[]; alive int[] := '{}'; absent int[] := '{}'; present int[] := '{}';
  reported uuid[]; limit_s int; seen timestamptz; progress timestamptz; stall interval;
  tourn boolean; realtime boolean; survivors int[]; last_out int; r text;
begin
  select * into m from nx_matches where id = p_match and status = 'playing' for update skip locked;
  if m.id is null then return null; end if;
  n := coalesce(array_length(m.players, 1), 0);
  tourn := m.settings ? 'tmatch';
  realtime := m.game in ('kart_racing', 'obstacle_race', 'basketball_battle', 'bomb_arena');
  gone := public._nx_forfeited_seats(p_match);
  select coalesce(array_agg(r2.user_id), '{}'::uuid[]) into reported from nx_match_reports r2 where r2.match_id = p_match;
  limit_s := case when tourn then greatest(60, coalesce(nullif(m.settings->>'grace_sec', '')::int, 90) + 30) else 120 end;
  select * into ts from nx_match_turn_state t where t.match_id = p_match;

  for s in 0 .. n - 1 loop
    continue when s = any(gone);
    u := m.players[s + 1];
    continue when u is null;
    alive := alive || s;
    seen := public._nx_match_last_seen(p_match, u);
    if seen < now() - make_interval(secs => limit_s)
       or (ts.match_id is not null and ts.seat = s and ts.deadline < now()
           and seen < now() - interval '60 seconds') then
      absent := absent || s;
    else
      present := present || s;
    end if;
  end loop;

  -- nobody left (or a broken match with no seats)
  if coalesce(array_length(present, 1), 0) = 0 then
    if tourn and not public._nx_match_tournament_done(p_match) then return null; end if;
    r := public._nx_match_settle_reports(p_match, 'all_gone');
    if r is not null then return r; end if;
    if public._nx_match_abandon(p_match, 'all_gone') then return 'abandoned'; end if;
    return null;
  end if;

  -- some seats gone, someone still here: forfeit the gone seats that have not reported
  if coalesce(array_length(absent, 1), 0) > 0 then
    foreach s in array absent loop
      continue when m.players[s + 1] = any(reported);
      select * into m from nx_matches where id = p_match;
      exit when m.status <> 'playing';
      insert into nx_match_moves(match_id, seq, seat, by_user, kind, move)
      values (p_match, m.last_seq + 1, s, srv, 'forfeit', jsonb_build_object('seat', s, 'idle', true, 'srv', true));
      update nx_matches set last_seq = m.last_seq + 1 where id = p_match;
      insert into nx_match_sweep_log(match_id, game, action, detail)
      values (p_match, m.game, 'forfeit_seat', jsonb_build_object('seat', s, 'limit_s', limit_s,
              'on_turn', ts.match_id is not null and ts.seat = s));
      last_out := s;
    end loop;
    select * into m from nx_matches where id = p_match;
    if m.status <> 'playing' then return 'forfeit'; end if;   -- a hidden game ended itself on 'leave'
    gone := public._nx_forfeited_seats(p_match);
    select coalesce(array_agg(g), '{}'::int[]) into survivors
      from generate_series(0, n - 1) g where not (g = any(gone));
    if coalesce(array_length(survivors, 1), 0) = 1 then
      if m.players[survivors[1] + 1] = any(reported) then
        return coalesce(public._nx_match_settle_reports(p_match, 'survivor_reported'), 'forfeit');
      end if;
      perform public.nx_finish_match_as(p_match, survivors, coalesce(last_out, absent[1]));
      insert into nx_match_sweep_log(match_id, game, action, detail)
      values (p_match, m.game, 'finished_forfeit', jsonb_build_object('winner', survivors[1]));
      return 'finished_forfeit';
    end if;
    if last_out is not null then return 'forfeit'; end if;
  end if;

  -- everyone here (or the gone ones already reported) but nothing moves any more, or the match is far too old
  progress := public._nx_match_last_progress(p_match);
  stall := case when realtime then interval '45 minutes' else interval '20 minutes' end;
  if progress < now() - stall or m.started_at < now() - interval '3 hours' then
    if tourn and not public._nx_match_tournament_done(p_match) then return null; end if;
    r := public._nx_match_settle_reports(p_match, 'stalled');
    if r is not null then return r; end if;
    if public._nx_match_abandon(p_match, case when m.started_at < now() - interval '3 hours' then 'too_old' else 'stalled' end) then
      return 'abandoned';
    end if;
  end if;
  return null;
end $f$;
revoke all on function public._nx_match_sweep_one(uuid) from public, anon, authenticated;
grant execute on function public._nx_match_sweep_one(uuid) to service_role;

create or replace function public._nx_match_sweep()
returns jsonb language plpgsql security definer set search_path = public as $f$
declare r record; a text; k int := 0; seen int := 0;
begin
  if not pg_try_advisory_xact_lock(74230021) then return jsonb_build_object('skipped', true); end if;
  for r in select m.id from nx_matches m
            where m.status = 'playing' and m.started_at < now() - interval '60 seconds'
            order by m.started_at limit 300 loop
    seen := seen + 1;
    begin
      a := public._nx_match_sweep_one(r.id);
      if a is not null then k := k + 1; end if;
    exception when others then
      raise warning '_nx_match_sweep %: %', r.id, sqlerrm;
      begin
        insert into nx_match_sweep_log(match_id, action, detail)
        values (r.id, 'error', jsonb_build_object('error', left(sqlerrm, 300)));
      exception when others then null;
      end;
    end;
  end loop;
  return jsonb_build_object('checked', seen, 'acted', k);
end $f$;
revoke all on function public._nx_match_sweep() from public, anon, authenticated;
grant execute on function public._nx_match_sweep() to service_role;

-- pg_cron: every 20 s (idempotent)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'nx_match_sweep';
    perform cron.schedule('nx_match_sweep', '20 seconds', 'select public._nx_match_sweep()');
  end if;
end $$;
