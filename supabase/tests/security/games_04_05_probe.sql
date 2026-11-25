do $$
declare u uuid[] := array['a0000000-0000-4000-8000-0000000000a1','a0000000-0000-4000-8000-0000000000a2']::uuid[];
  r jsonb; r1 jsonb; rid uuid; code text; mid uuid; logj jsonb := '{}';
begin
  for i in 1..2 loop insert into profiles(id, username) values (u[i], 'hark_test_'||i) on conflict do nothing; end loop;
  -- A: loser (seat 1, not authority) reports himself winner AFTER authority reported
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  execute 'set local role authenticated';
  r := nx_create_room('backgammon', 2, true, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  perform nx_join_room(code, null);
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  r := nx_start_match(rid); mid := (r->>'match_id')::uuid;
  r1 := nx_finish_match(mid, array[0], array[5,1], 'hA', 'finished');
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  r := nx_finish_match(mid, array[1], array[1,5], 'hB', 'finished');
  execute 'reset role';
  logj := logj || jsonb_build_object('P2_loser_dispute', jsonb_build_object('r1', r1, 'r2', r, 'status', (select status from nx_matches where id=mid), 'winners', (select winner_seats from nx_matches where id=mid),
     'results', (select count(*) from nx_match_results where match_id=mid), 'xp', (select count(*) from nx_xp_events where idem_key='match:'||mid),
     'dispute_rows', (select jsonb_agg(jsonb_build_object('u', right(user_id::text,2), 'rep', reported, 'dec', decided)) from nx_match_disputes where match_id=mid)));
  -- B: loser reports FIRST (pending), then authority
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  execute 'set local role authenticated';
  r := nx_create_room('uno', 2, true, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  perform nx_join_room(code, null);
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  r := nx_start_match(rid); mid := (r->>'match_id')::uuid;
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  r1 := nx_finish_match(mid, array[1], array[0,1], 'x', 'finished');
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  r := nx_finish_match(mid, array[0], array[1,0], 'y', 'finished');
  execute 'reset role';
  logj := logj || jsonb_build_object('P2b_loser_first', jsonb_build_object('r1', r1, 'r2', r, 'status', (select status from nx_matches where id=mid), 'winners', (select winner_seats from nx_matches where id=mid), 'results', (select count(*) from nx_match_results where match_id=mid)));
  -- C: same winner, different hash
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  execute 'set local role authenticated';
  r := nx_create_room('ludo', 2, true, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  perform nx_join_room(code, null);
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  r := nx_start_match(rid); mid := (r->>'match_id')::uuid;
  r1 := nx_finish_match(mid, array[0], array[1,0], 'hash-x', 'finished');
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  r := nx_finish_match(mid, array[0], array[1,0], 'hash-y', 'finished');
  begin logj := logj || jsonb_build_object('player_reads_dispute_counts', (select count(*) from nx_dispute_counts)); exception when others then logj := logj || jsonb_build_object('player_reads_dispute_counts', sqlerrm); end;
  execute 'reset role';
  logj := logj || jsonb_build_object('P3_same_winner_diff_hash', jsonb_build_object('r2', r, 'status', (select status from nx_matches where id=mid), 'results', (select count(*) from nx_match_results where match_id=mid)),
     'counts', (select jsonb_agg(to_jsonb(d) - 'last_dispute') from nx_dispute_counts d where user_id = any(u)));
  raise exception 'HARNESS_RESULT %', logj;
end $$;
