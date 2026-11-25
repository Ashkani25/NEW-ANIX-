do $$ declare a uuid; b uuid; logj jsonb := '{}'; pid uuid; n int; v text;
begin
  select id into a from profiles order by created_at limit 1; select id into b from profiles where id<>a order by created_at limit 1;
  insert into nx_posts(author, kind, text) values (b, 'post', 'x') returning id into pid;
  update profiles set is_private = true where id = b;
  delete from follows where follower = a and followee = b;
  insert into nx_post_comments(post_id, author, text) values (pid, b, 'secret comment');
  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  begin update profiles set username = 'admin' where id = a; logj := logj || jsonb_build_object('username_direct', (select username from profiles where id=a)); exception when others then logj := logj || jsonb_build_object('username_direct', sqlerrm); end;
  begin update profiles set rating = 9999 where id = a; logj := logj || '{"rating":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('rating', sqlerrm); end;
  begin update profiles set avatar_url = 'https://evil.example/x.png' where id = a; logj := logj || '{"evil_avatar":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('evil_avatar', sqlerrm); end;
  begin update profiles set bio = 'hi', avatar_url = 'https://eisstodgncimypdawisy.supabase.co/storage/v1/object/public/nx-media/'||a||'/avatar.jpg?v=1', avatar_path = a||'/avatar.jpg' where id = a; logj := logj || '{"ok_own_avatar_bio":true}'; exception when others then logj := logj || jsonb_build_object('ok_own_avatar_bio', sqlerrm); end;
  begin update nx_profiles set data = coalesce(data,'{}') || '{"x":1}' where id = a; logj := logj || '{"ok_nx_profiles_update":true}'; exception when others then logj := logj || jsonb_build_object('ok_nx_profiles_update', sqlerrm); end;
  select count(*) into n from nx_post_comments where post_id = pid; logj := logj || jsonb_build_object('private_comments_visible', n);
  begin insert into nx_post_comments(post_id, author, text) values (pid, a, 'spam'); logj := logj || '{"comment_on_invisible":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('comment_on_invisible', sqlerrm); end;
  begin insert into nx_post_likes(post_id, user_id) values (pid, a); logj := logj || '{"like_invisible":"ALLOWED"}'; exception when others then logj := logj || jsonb_build_object('like_invisible', sqlerrm); end;
  -- visible post flow
  execute 'reset role'; update profiles set is_private = false where id = b; execute 'set local role authenticated';
  begin insert into nx_post_comments(post_id, author, text) values (pid, a, 'nice'); insert into nx_post_likes(post_id, user_id) values (pid, a);
    logj := logj || jsonb_build_object('ok_public_comment_like', (select comment_count||'/'||like_count from nx_posts where id = pid)); exception when others then logj := logj || jsonb_build_object('ok_public_comment_like', sqlerrm); end;
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', logj; end $$;
