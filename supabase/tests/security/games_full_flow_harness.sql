do $$
declare
  u uuid[] := array['a0000000-0000-4000-8000-0000000000a1','a0000000-0000-4000-8000-0000000000a2','a0000000-0000-4000-8000-0000000000a3',
                    'a0000000-0000-4000-8000-0000000000a4','a0000000-0000-4000-8000-0000000000a5','a0000000-0000-4000-8000-0000000000a6',
                    'a0000000-0000-4000-8000-0000000000a7']::uuid[];
  games text[] := array['finger_soccer','carrom','billiards','backgammon','ludo','snakes_ladders','uno','quiz','mafia',
                        'kart_racing','obstacle_race','bomb_arena','pool8','mini_golf','basketball_battle','spy_mafia'];
  g text; nseat int; r jsonb; rid uuid; code text; mid uuid; i int; logj jsonb := '{}'::jsonb; t jsonb; err text;
  res jsonb; m record; winners int[]; sc int[];
begin
  for i in 1..7 loop insert into profiles(id, username, xp, coins) values (u[i], 'hark_test_'||i, 0, 0) on conflict do nothing; end loop;
  foreach g in array games loop
    t := '{}'::jsonb;
    begin
      nseat := (nx_game_bounds(g)).min_seats;
      perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
      execute 'set local role authenticated';
      r := nx_create_room(g, nseat, false, false, '{}'::jsonb);
      rid := (r->>'room_id')::uuid; code := r->>'code';
      t := t || jsonb_build_object('create', r);
      for i in 2..nseat loop
        perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
        r := nx_join_room(code, null);
        perform nx_set_ready(rid, true);
        t := t || jsonb_build_object('join'||i, r->'seat');
      end loop;
      perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
      r := nx_start_match(rid);
      mid := (r->>'match_id')::uuid;
      t := t || jsonb_build_object('start', r is not null and mid is not null);
      -- each player pushes one move in seat order
      for i in 1..nseat loop
        perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
        perform nx_match_ping(mid);
        if g in ('carrom','billiards') then
          r := nx_g_push(mid, i, 'move', jsonb_build_object('a','aim','x',i), 'h'||i, null);
        else
          r := nx_push_move(mid, i, 'move', jsonb_build_object('x',i), 'h'||i, null);
        end if;
        t := t || jsonb_build_object('move'||i, r);
      end loop;
      if g = 'quiz' then
        perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
        begin r := nx_quiz_start(mid, null); t := t || jsonb_build_object('quiz_start_phase', r->'phase', 'quiz_keys', (select jsonb_agg(k) from jsonb_object_keys(r) k));
        exception when others then t := t || jsonb_build_object('quiz_start_err', sqlerrm); end;
      end if;
      -- everyone reports seat 0 won
      sc := array_fill(0, array[nseat]); sc[1] := 3;
      for i in 1..nseat loop
        perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
        begin
          r := nx_finish_match(mid, array[0], sc, 'final', 'finished');
          t := t || jsonb_build_object('finish'||i, r);
        exception when others then t := t || jsonb_build_object('finish'||i||'_err', sqlerrm); end;
      end loop;
      execute 'reset role';
      select status, winner_seats, reason into m from nx_matches where id = mid;
      t := t || jsonb_build_object('final_status', m.status, 'final_winners', m.winner_seats,
              'results', (select count(*) from nx_match_results where match_id = mid),
              'room_status', (select status from nx_rooms where id = rid),
              'xp_events', (select count(*) from nx_xp_events where idem_key = 'match:'||mid));
      -- cleanup between games: leave room for everyone
      for i in 1..nseat loop
        perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
        execute 'set local role authenticated';
        begin perform nx_leave_room(rid); exception when others then null; end;
      end loop;
      execute 'reset role';
    exception when others then
      get stacked diagnostics err = message_text;
      execute 'reset role';
      t := t || jsonb_build_object('ERROR', err);
    end;
    logj := logj || jsonb_build_object(g, t);
  end loop;
  raise exception 'HARNESS_RESULT %', logj;
end $$;
