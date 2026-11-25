-- rollback snapshot taken 2026-11-25T17:11:20Z from project eyzafhrefnqlwcjpcdyg (state BEFORE the fix)
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
begin
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
$function$
;
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
$function$
;
revoke all on function nx_g_push(uuid,integer,text,jsonb,text,integer) from public, anon, authenticated; grant execute on function nx_g_push(uuid,integer,text,jsonb,text,integer) to authenticated;
revoke all on function nx_push_move(uuid,integer,text,jsonb,text,integer) from public, anon, authenticated; grant execute on function nx_push_move(uuid,integer,text,jsonb,text,integer) to authenticated;
drop function if exists public._nx_may_act_as_authority(uuid, int);
