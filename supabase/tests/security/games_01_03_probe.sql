do $$
declare u uuid[] := array['a0000000-0000-4000-8000-0000000000a1','a0000000-0000-4000-8000-0000000000a2','a0000000-0000-4000-8000-0000000000a3']::uuid[];
  r jsonb; rid uuid; code text; logj jsonb := '{}'; qid uuid;
begin
  for i in 1..3 loop insert into profiles(id, username) values (u[i], 'hark_test_'||i) on conflict do nothing; end loop;
  perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
  execute 'set local role authenticated';
  r := nx_create_room('backgammon', 2, true, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
  perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
  perform nx_join_room(code, null);
  r := nx_quick('uno', 2); qid := (r->>'room_id')::uuid;
  execute 'reset role';
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';
  begin perform nx_update_room(rid, 2, '{"pwned":true}'); logj := logj || '{"anon_update_room":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('anon_update_room', sqlerrm); end;
  begin perform nx_start_match(rid); logj := logj || '{"anon_start_match":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('anon_start_match', sqlerrm); end;
  begin perform nx_join_room(code, null); logj := logj || '{"anon_join":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('anon_join', sqlerrm); end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub',u[3],'role','authenticated')::text, true);
  execute 'set local role authenticated';
  begin perform nx_start_match(qid); logj := logj || '{"stranger_start_quick":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('stranger_start_quick', sqlerrm); end;
  begin perform nx_update_room(rid, 2, '{"pwned":true}'); logj := logj || '{"stranger_update_room":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('stranger_update_room', sqlerrm); end;
  execute 'reset role';
  logj := logj || jsonb_build_object('anon_exec_fns', (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and has_function_privilege('anon',p.oid,'execute') and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e')),
     'settings', (select settings from nx_rooms where id=rid));
  raise exception 'HARNESS_RESULT %', logj;
end $$;
