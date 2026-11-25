do $$ declare ch uuid; a uuid; b uuid; ok boolean; cid uuid; logj jsonb:='{}';
begin
  select id into a from profiles order by created_at limit 1; select id into b from profiles where id<>a order by created_at limit 1;
  insert into nx_chats(kind, name, owner) values ('group','hark_probe', a) returning id into ch;
  insert into nx_chat_members(chat_id,user_id,role) values (ch,a,'owner'),(ch,b,'member') on conflict do nothing;
  insert into nx_communities(name, owner, invite_code) values ('hark_probe', a, 'HARKPRB2') returning id into cid;
  insert into nx_community_members(community_id,user_id,role) values (cid,a,'owner') on conflict do nothing;
  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  begin ok := nx_set_chat_role(ch, b, 'admin'); logj := logj||jsonb_build_object('owner_promotes', ok); exception when others then logj := logj||jsonb_build_object('owner_promotes', sqlerrm); end;
  begin ok := nx_community_delete(cid); logj := logj||jsonb_build_object('owner_deletes_community', ok); exception when others then logj := logj||jsonb_build_object('owner_deletes_community', sqlerrm); end;
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj; end $$;
