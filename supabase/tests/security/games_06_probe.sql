do $$
declare u uuid[] := array['a0000000-0000-4000-8000-0000000000a1','a0000000-0000-4000-8000-0000000000a2','a0000000-0000-4000-8000-0000000000a3']::uuid[];
  r jsonb; rid uuid; code text; mid uuid; logj jsonb := '{}';
begin
  for i in 1..3 loop insert into profiles(id, username) values (u[i], 'hark_test_'||i) on conflict do nothing; end loop;
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  execute 'set local role authenticated';
  r := nx_create_room('mafia', 6, true, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  perform nx_join_room(code, null);
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  begin r := nx_start_match(rid); mid := (r->>'match_id')::uuid; exception when others then logj := logj || jsonb_build_object('start', sqlerrm); end;
  if mid is null then execute 'reset role'; insert into nx_matches(room_id, game, players, names, seed, settings) values (rid,'mafia',array[u[1],u[2]],array['a','b'],42,'{}') returning id into mid; execute 'set local role authenticated'; end if;
  logj := logj || jsonb_build_object('player_reads_own_match', (select count(*) from nx_matches where id = mid));
  perform set_config('request.jwt.claims', json_build_object('sub',u[3],'role','authenticated')::text, true);
  logj := logj || jsonb_build_object('stranger_reads_match', (select count(*) from nx_matches where id = mid), 'stranger_reads_any_seed', (select count(*) from nx_matches));
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj;
end $$;
