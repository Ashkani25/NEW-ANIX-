do $$ declare u1 uuid:='a0000000-0000-4000-8000-0000000000a1'; u2 uuid:='a0000000-0000-4000-8000-0000000000a2'; u3 uuid:='a0000000-0000-4000-8000-0000000000a3'; r jsonb; rid uuid; logj jsonb:='{}'; code text; mid uuid;
begin
 insert into profiles(id,username) values (u1,'t1'),(u2,'t2'),(u3,'t3') on conflict do nothing;
 perform set_config('request.jwt.claims', json_build_object('sub',u1,'role','authenticated')::text, true); execute 'set local role authenticated';
 r := nx_create_room('ludo', 2, true, false, '{}'); rid := (r->>'room_id')::uuid; code := r->>'code';
 perform set_config('request.jwt.claims', json_build_object('sub',u2,'role','authenticated')::text, true);
 r := nx_join_room(code,null); logj := logj||jsonb_build_object('lobby_join', r->'role', 'lobby_seat', r->'seat');
 perform set_config('request.jwt.claims', json_build_object('sub',u1,'role','authenticated')::text, true); r := nx_start_match(rid); mid := (r->>'match_id')::uuid;
 perform set_config('request.jwt.claims', json_build_object('sub',u3,'role','authenticated')::text, true);
 begin r := nx_join_room(code,null); logj := logj||jsonb_build_object('late_join', r);
 exception when others then logj := logj||jsonb_build_object('late_join','blocked: '||sqlerrm); end;
 logj := logj||jsonb_build_object('late_member_role', (select role from nx_room_members where room_id=rid and user_id=u3),
     'late_in_room_players', exists(select 1 from nx_room_players where room_id=rid and user_id=u3),
     'late_reads_match', (select count(*) from nx_matches where id=mid),
     'players_in_match', (select array_length(players,1) from nx_matches where id=mid));
 perform set_config('request.jwt.claims', json_build_object('sub',u2,'role','authenticated')::text, true);
 r := nx_join_room(code,null); logj := logj||jsonb_build_object('player_rejoin_role', r->'role', 'rejoined', r->'rejoined');
 execute 'reset role';
 raise exception 'HARNESS_RESULT %', logj; end $$;
