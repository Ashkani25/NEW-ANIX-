do $$
declare u uuid[] := array['a0000000-0000-4000-8000-0000000000a1','a0000000-0000-4000-8000-0000000000a2','a0000000-0000-4000-8000-0000000000a3']::uuid[];
  r jsonb; rid uuid; code text; mid uuid; logj jsonb := '{}'; s int := 0;
begin
  for i in 1..3 loop insert into profiles(id, username) values (u[i], 'hark_test_'||i) on conflict do nothing; end loop;
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  execute 'set local role authenticated';
  r := nx_create_room('carrom', 2, true, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  perform nx_join_room(code, null);
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  r := nx_start_match(rid); mid := (r->>'match_id')::uuid;
  perform nx_match_ping(mid);
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  perform nx_match_ping(mid);
  s := s + 1; r := nx_push_move(mid, s, 'snap', '{"nt":1,"board":"fake"}', 'fake', 0); logj := logj || jsonb_build_object('P5_nonauth_snap_other_seat', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  s := s + 1; r := nx_push_move(mid, s, 'snap', '{"nt":1}', 'fake', null); logj := logj || jsonb_build_object('P5b_nonauth_snap_own_seat', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  s := s + 1; r := nx_push_move(mid, s, 'system', '{"_k":"timeout","a":"pass"}', null, 0); logj := logj || jsonb_build_object('P5c_nonauth_timeout_other_seat', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  s := s + 1; r := nx_push_move(mid, s, 'system', '{"_k":"move","a":"shot"}', null, 0); logj := logj || jsonb_build_object('P5d_move_for_other_seat', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  s := s + 1; r := nx_g_push(mid, s, 'snap', '{"nt":1}', 'fake', 0); logj := logj || jsonb_build_object('P5e_g_push_nonauth_snap', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  s := s + 1; r := nx_push_move(mid, s, 'system', '{"_k":"move","x":1}', null, null); logj := logj || jsonb_build_object('ok_own_move', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  s := s + 1; r := nx_push_move(mid, s, 'snap', '{"nt":1}', 'h', null); logj := logj || jsonb_build_object('ok_auth_snap', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  s := s + 1; r := nx_push_move(mid, s, 'system', '{"_k":"timeout","a":"pass"}', null, 1); logj := logj || jsonb_build_object('ok_auth_timeout_other_seat', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  -- authority goes silent: seat 1 takes over
  execute 'reset role';
  update nx_match_presence set last_seen = now() - interval '60 seconds' where match_id = mid and user_id = u[1];
  update nx_match_moves set created_at = now() - interval '60 seconds' where match_id = mid and by_user = u[1];
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  s := s + 1; r := nx_push_move(mid, s, 'system', '{"_k":"timeout","a":"pass"}', null, 0); logj := logj || jsonb_build_object('ok_takeover_timeout_when_seat0_silent', r); if not (r->>'ok')::boolean then s := s - 1; end if;
  -- flood
  for i in 1..45 loop s := s + 1; r := nx_push_move(mid, s, 'system', '{"_k":"move","x":1}', null, null); if not (r->>'ok')::boolean then s := s - 1; exit; end if; end loop;
  logj := logj || jsonb_build_object('flood_last', r);
  perform set_config('request.jwt.claims', json_build_object('sub',u[3],'role','authenticated')::text, true);
  begin r := nx_push_move(mid, s+1, 'move', '{}', null, null); logj := logj || jsonb_build_object('stranger_move', r); exception when others then logj := logj || jsonb_build_object('stranger_move', sqlerrm); end;
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj;
end $$;
