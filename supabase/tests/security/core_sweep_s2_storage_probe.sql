do $$ declare a uuid; b uuid; logj jsonb := '{}'; n int;
begin
  select id into a from profiles order by created_at limit 1; select id into b from profiles where id<>a order by created_at limit 1;
  insert into storage.objects(bucket_id, name, owner) values ('nx-media', b||'/1700000000000.jpg', b), ('nx-media', a||'/avatar.jpg', a);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true); execute 'set local role anon';
  select count(*) into n from storage.objects where bucket_id in ('nx-media','avatars','chat'); logj := logj || jsonb_build_object('anon_list_public_buckets', n);
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into n from storage.objects where bucket_id = 'nx-media' and name like b||'/%'; logj := logj || jsonb_build_object('user_lists_others_media', n);
  select count(*) into n from storage.objects where bucket_id = 'nx-media' and name like a||'/%'; logj := logj || jsonb_build_object('ok_user_sees_own', n);
  begin insert into storage.objects(bucket_id, name, owner) values ('chat', a||'/x.png', a); logj := logj || '{"legacy_chat_upload":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('legacy_chat_upload', sqlerrm); end;
  begin insert into storage.objects(bucket_id, name, owner) values ('nx-media', a||'/new.jpg', a); logj := logj || '{"ok_nx_media_upload":true}'; exception when others then logj := logj || jsonb_build_object('ok_nx_media_upload', sqlerrm); end;
  begin update storage.objects set name = b||'/planted.jpg' where bucket_id='nx-media' and name = a||'/avatar.jpg'; get diagnostics n = row_count; logj := logj || jsonb_build_object('move_into_victim_folder', n); exception when others then logj := logj || jsonb_build_object('move_into_victim_folder', sqlerrm); end;
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj; end $$;
