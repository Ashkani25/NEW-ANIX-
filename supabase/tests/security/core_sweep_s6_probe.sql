do $$ declare a uuid; logj jsonb := '{}'; n int; t text;
begin
  select id into a from profiles order by created_at limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true); execute 'set local role authenticated';
  foreach t in array array['game_state','matches','inventory','admins','clubs','messages','nx_matches','profiles','nx_chats','nx_posts','nx_profiles','follows','nx_notifications','nx_game_stats'] loop
    begin execute format('select count(*) from public.%I', t) into n; logj := logj || jsonb_build_object(t, n); exception when others then logj := logj || jsonb_build_object(t, 'denied'); end;
  end loop;
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj; end $$;
