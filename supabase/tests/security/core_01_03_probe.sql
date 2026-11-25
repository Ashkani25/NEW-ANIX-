do $$
declare logj jsonb := '{}'; ch uuid; mem uuid; ok boolean; tid uuid; cid uuid; own uuid; err text; cnt int;
begin
  select chat_id, user_id into ch, mem from nx_chat_members where role <> 'owner' limit 1;
  select id into own from profiles limit 1;
  insert into nx_communities(name, owner, invite_code) values ('hark_probe', own, 'HARKPRB1') returning id into cid;
  perform set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-0000000000b1","role":"authenticated"}', true);
  execute 'set local role authenticated';
  begin ok := nx_set_chat_role(ch, mem, 'admin'); logj := logj || jsonb_build_object('C1_stranger_promotes', coalesce(ok::text,'null')); exception when others then logj := logj || jsonb_build_object('C1_stranger_promotes', 'blocked: '||sqlerrm); end;
  begin ok := nx_community_delete(cid); logj := logj || jsonb_build_object('C2_stranger_deletes_community', 'ALLOWED'); exception when others then logj := logj || jsonb_build_object('C2_stranger_deletes_community', 'blocked: '||sqlerrm); end;
  begin perform start_tournament(null::uuid); logj := logj || '{"C3_auth_start_tournament":"callable"}'; exception when others then logj := logj || jsonb_build_object('C3_auth_start_tournament', sqlerrm); end;
  begin perform report_match(null::uuid,null::int,null::int); logj := logj || '{"C4_report_match":"callable"}'; exception when others then logj := logj || jsonb_build_object('C4_report_match', sqlerrm); end;
  -- normal flows still callable
  begin perform nx_my_chats(); logj := logj || '{"ok_my_chats":true}'; exception when others then logj := logj || jsonb_build_object('ok_my_chats', sqlerrm); end;
  begin perform nx_username_available('zz_hark_probe'); logj := logj || '{"ok_username_available":true}'; exception when others then logj := logj || jsonb_build_object('ok_username_available', sqlerrm); end;
  begin perform count(*) from nx_chats; perform count(*) from nx_communities; perform count(*) from nx_posts; logj := logj || '{"ok_rls_reads":true}'; exception when others then logj := logj || jsonb_build_object('ok_rls_reads', sqlerrm); end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';
  begin perform nx_username_available('zz_hark_probe'); logj := logj || '{"anon_username_available":true}'; exception when others then logj := logj || jsonb_build_object('anon_username_available', sqlerrm); end;
  begin perform count(*) from nx_communities; perform count(*) from nx_posts; logj := logj || '{"anon_rls_reads":"ok"}'; exception when others then logj := logj || jsonb_build_object('anon_rls_reads', sqlerrm); end;
  begin perform owner_bank_adjust(null::uuid, null::int, null::text); logj := logj || '{"anon_owner_bank_adjust":"callable"}'; exception when others then logj := logj || jsonb_build_object('anon_owner_bank_adjust', sqlerrm); end;
  execute 'reset role';
  select count(*) into cnt from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and has_function_privilege('anon',p.oid,'execute') and not exists (select 1 from pg_depend d where d.objid=p.oid and d.deptype='e');
  logj := logj || jsonb_build_object('anon_exec_fns', cnt, 'auth_exec_fns', (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and has_function_privilege('authenticated',p.oid,'execute')), 'community_exists', exists(select 1 from nx_communities where id=cid),
     'hook_ok', has_function_privilege('supabase_auth_admin','public.nx_access_token_hook(jsonb)','execute'));
  raise exception 'HARNESS_RESULT %', logj;
end $$;
