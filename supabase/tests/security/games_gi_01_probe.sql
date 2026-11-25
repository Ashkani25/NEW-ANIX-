-- Probe for games/migrations/20261126100000_gi_match_sweep_rate.sql (server match sweep + per-player move rate limit).
-- Run on the games project AFTER the migration: everything happens inside one DO block that ends with
-- `raise exception 'GI_TEST_RESULT {...}'`, so the test matches / rows are always rolled back (nothing is kept).
-- Read the JSON in the error message. Expected (2026-11-25, live run):
--   A ludo, seat 1 silent 5 min          → server forfeit row {seat:1, idle, srv}, finished, winners {0}, reason forfeit:1
--   B backgammon, both silent             → abandoned (no results)
--   C ludo, both connected, no move 30 min→ abandoned (stalled)
--   D snakes, both silent, one report {0} → finished from the report, winners {0}
--   E ludo 3p, seat 2 silent              → forfeit row for seat 2, still playing; second sweep does nothing
--   F uno (hidden game), both silent      → abandoned
--   H fresh match (30 s)                  → untouched; 13th row in 3 s refused with reason 'rate'; a forfeit still passes
do $t$
declare p uuid[]; a uuid; b uuid; c uuid; d uuid; e uuid; f uuid; h uuid; res jsonb := '{}'; r jsonb; i int; sw jsonb;
begin
  select array_agg(id) into p from (select id from profiles order by id limit 6) x;
  -- A: ludo, seat1 gone 5 min, seat0 here -> forfeit + finished
  insert into nx_matches(game, players, names, seed, started_at) values ('ludo', array[p[1],p[2]], array['a','b'], 1, now() - interval '10 minutes') returning id into a;
  insert into nx_match_presence values (a, p[1], now()), (a, p[2], now() - interval '5 minutes');
  -- B: backgammon both gone -> abandoned
  insert into nx_matches(game, players, names, seed, started_at) values ('backgammon', array[p[1],p[2]], array['a','b'], 1, now() - interval '10 minutes') returning id into b;
  -- C: ludo both present, last move 30 min ago -> stalled abandoned
  insert into nx_matches(game, players, names, seed, started_at, last_seq) values ('ludo', array[p[3],p[4]], array['a','b'], 1, now() - interval '40 minutes', 1) returning id into c;
  insert into nx_match_moves(match_id, seq, seat, by_user, kind, move, created_at) values (c, 1, 0, p[3], 'system', '{}', now() - interval '30 minutes');
  insert into nx_match_presence values (c, p[3], now()), (c, p[4], now());
  -- D: snakes both gone, one report winners {0} -> settled finished
  insert into nx_matches(game, players, names, seed, started_at) values ('snakes_ladders', array[p[1],p[3]], array['a','b'], 1, now() - interval '10 minutes') returning id into d;
  insert into nx_match_reports(match_id, user_id, winners, scores, created_at) values (d, p[1], '{0}', '{5,2}', now() - interval '5 minutes');
  -- E: ludo 3p, seat2 gone -> forfeit, still playing
  insert into nx_matches(game, players, names, seed, started_at) values ('ludo', array[p[1],p[2],p[3]], array['a','b','c'], 1, now() - interval '10 minutes') returning id into e;
  insert into nx_match_presence values (e, p[1], now()), (e, p[2], now()), (e, p[3], now() - interval '3 minutes');
  -- F: uno (hidden game) both gone -> abandoned
  insert into nx_matches(game, players, names, seed, started_at) values ('uno', array[p[5],p[6]], array['a','b'], 1, now() - interval '20 minutes') returning id into f;
  -- H: fresh match -> untouched
  insert into nx_matches(game, players, names, seed, started_at) values ('ludo', array[p[5],p[6]], array['a','b'], 1, now() - interval '30 seconds') returning id into h;

  sw := public._nx_match_sweep();
  res := res || jsonb_build_object('sweep', sw);
  for r in select jsonb_build_object('k', k, 'status', m.status, 'reason', m.reason, 'winners', m.winner_seats,
                    'forfeits', (select jsonb_agg(mv.move) from nx_match_moves mv where mv.match_id = m.id and mv.kind = 'forfeit'),
                    'results', (select count(*) from nx_match_results x where x.match_id = m.id),
                    'hg', (select count(*) from nx_hg_state x where x.match_id = m.id))
             from (values ('A', a), ('B', b), ('C', c), ('D', d), ('E', e), ('F', f), ('H', h)) v(k, id) join nx_matches m on m.id = v.id loop
    res := res || jsonb_build_object(r->>'k', r);
  end loop;
  res := res || jsonb_build_object('log', (select jsonb_agg(jsonb_build_object('g', game, 'a', action, 'd', detail)) from nx_match_sweep_log where match_id in (a,b,c,d,e,f,h)));
  -- second sweep: nothing more for E (now within limits) 
  res := res || jsonb_build_object('sweep2', public._nx_match_sweep());

  -- rate limit as player 1 in match H (fresh, playing)
  perform set_config('request.jwt.claims', json_build_object('sub', p[5], 'role', 'authenticated')::text, true);
  for i in 1..13 loop
    r := public.nx_push_move(h, i, 'system', jsonb_build_object('_k', 'move', 'i', i), null, null);
    if not coalesce((r->>'ok')::boolean, false) then res := res || jsonb_build_object('rate_at', i, 'rate_reply', r); exit; end if;
  end loop;
  r := public.nx_push_move(h, (select last_seq + 1 from nx_matches where id = h), 'forfeit', '{}', null, null);
  res := res || jsonb_build_object('forfeit_after_rate', r, 'H_after', (select status || ':' || coalesce(reason,'') from nx_matches where id = h));
  raise exception 'GI_TEST_RESULT %', res::text;
end $t$;
