do $$ declare a uuid; r jsonb; r2 jsonb; logj jsonb := '{}';
begin
  select id into a from profiles order by created_at limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true); execute 'set local role authenticated';
  r := nx_award('game.uno.win', 0, 0, 'hark-probe-k1'); r2 := nx_award('game.uno.win', 0, 0, 'hark-probe-k1');
  logj := logj || jsonb_build_object('first', r->'reason', 'dup', r2->'reason');
  r := nx_award('bogus.event', 0, 0, 'hark-probe-k2'); logj := logj || jsonb_build_object('unknown', r->'reason');
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj; end $$;
