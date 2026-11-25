do $$ declare u1 uuid:='a0000000-0000-4000-8000-0000000000a1'; u3 uuid:='a0000000-0000-4000-8000-0000000000a3'; tid uuid; mid uuid; r jsonb; logj jsonb:='{}';
begin
  insert into profiles(id,username) values (u1,'t1'),(u3,'t3') on conflict do nothing;
  insert into nx_tournaments(title, created_by, format, capacity, reg_open_at, reg_close_at, draw_at, start_at, status)
    values ('hark probe', u1, 'single_elim', 4, now(), now() + interval '1 min', now() + interval '2 min', now() + interval '3 min', 'live') returning id into tid;
  insert into nx_t_matches(tournament_id, bracket, round, p1, p2, status) values (tid, 'W', 1, u1, null, 'ready_check') returning id into mid;
  perform set_config('request.jwt.claims', json_build_object('sub',u3,'role','authenticated')::text, true); execute 'set local role authenticated';
  begin r := nx_t_ready(mid); logj := logj || jsonb_build_object('stranger_ready_tbd_slot', r); exception when others then logj := logj || jsonb_build_object('stranger_ready_tbd_slot', sqlerrm); end;
  begin r := nx_t_dispute(mid, 'x'); logj := logj || jsonb_build_object('stranger_dispute', r); exception when others then logj := logj || jsonb_build_object('stranger_dispute', sqlerrm); end;
  perform set_config('request.jwt.claims', json_build_object('sub',u1,'role','authenticated')::text, true);
  begin r := nx_t_ready(mid); logj := logj || jsonb_build_object('ok_player_ready', r); exception when others then logj := logj || jsonb_build_object('ok_player_ready', sqlerrm); end;
  execute 'reset role';
  logj := logj || jsonb_build_object('p2_ready_after', (select p2_ready from nx_t_matches where id=mid));
  raise exception 'HARNESS_RESULT %', logj; end $$;
