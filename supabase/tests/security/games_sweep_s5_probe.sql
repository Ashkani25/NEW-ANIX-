do $$ declare u1 uuid:='a0000000-0000-4000-8000-0000000000a1'; u2 uuid:='a0000000-0000-4000-8000-0000000000a2'; u3 uuid:='a0000000-0000-4000-8000-0000000000a3'; mid uuid; n1 int; n3 int; logj jsonb := '{}';
begin
  insert into profiles(id,username) values (u1,'t1'),(u2,'t2'),(u3,'t3') on conflict do nothing;
  insert into nx_matches(game, players, names, seed, settings) values ('uno', array[u1,u2], array['a','b'], 1, '{}') returning id into mid;
  perform set_config('realtime.topic', 'nxm:'||mid, true);
  insert into realtime.messages(topic, extension, payload, event, private) values ('nxm:'||mid, 'broadcast', '{}', 'mv', true);
  perform set_config('request.jwt.claims', json_build_object('sub',u1,'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into n1 from realtime.messages where topic = 'nxm:'||mid;
  begin insert into realtime.messages(topic, extension, payload, event, private) values ('nxm:'||mid, 'broadcast', '{}', 'mv', true); logj := logj || '{"player_send":"ok"}'; exception when others then logj := logj || jsonb_build_object('player_send', sqlerrm); end;
  perform set_config('request.jwt.claims', json_build_object('sub',u3,'role','authenticated')::text, true);
  select count(*) into n3 from realtime.messages where topic = 'nxm:'||mid;
  begin insert into realtime.messages(topic, extension, payload, event, private) values ('nxm:'||mid, 'broadcast', '{}', 'mv', true); logj := logj || '{"outsider_send":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('outsider_send', sqlerrm); end;
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj || jsonb_build_object('player_reads', n1, 'outsider_reads', n3); end $$;
