do $$ declare r jsonb; logj jsonb := '{}'; i int;
begin
  for i in 1..11 loop r := nx_login_throttle('203.0.113.9', 'victim'); end loop;
  logj := logj || jsonb_build_object('11th_same_ip_user', r, 'other_ip_same_user', nx_login_throttle('198.51.100.7', 'victim'));
  perform set_config('request.jwt.claims', '{"role":"anon"}', true); execute 'set local role anon';
  begin perform nx_login_throttle('x','y'); logj := logj || '{"anon_call":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('anon_call', sqlerrm); end;
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj; end $$;
