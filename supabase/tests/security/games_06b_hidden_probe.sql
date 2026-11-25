-- #6 part 2 probe: server-authoritative mafia / spy_mafia / uno. Run inside a transaction that is rolled back
-- (after the migration when testing it before applying). Reads HARNESS_RESULT json from the raised error.
do $$
declare
  u uuid[] := array['b0000000-0000-4000-8000-0000000000b1','b0000000-0000-4000-8000-0000000000b2','b0000000-0000-4000-8000-0000000000b3',
                    'b0000000-0000-4000-8000-0000000000b4','b0000000-0000-4000-8000-0000000000b5','b0000000-0000-4000-8000-0000000000b6',
                    'b0000000-0000-4000-8000-0000000000b7','b0000000-0000-4000-8000-0000000000b8','b0000000-0000-4000-8000-0000000000b9']::uuid[];
  res jsonb := '{}'::jsonb; t jsonb; r jsonb; rid uuid; code text; mid uuid; i int; n int; err text;
  sv jsonb; roles text[]; alive boolean[]; seat int; tgt int; lg int[]; guard int; cnt int; v jsonb; hs record;
  m record; legal int[]; okc int; badc int; stage text; mafia_seats int[]; town_seats int[];
begin
  for i in 1..9 loop insert into profiles(id, username, xp, coins) values (u[i], 'hark_hg_'||i, 0, 0) on conflict do nothing; end loop;

  ------------------------------------------------------------------ MAFIA
  t := '{}'::jsonb;
  begin
    n := 7;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    execute 'set local role authenticated';
    r := nx_create_room('mafia', n, false, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
    for i in 2..n loop
      perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
      perform nx_join_room(code, null); perform nx_set_ready(rid, true);
    end loop;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    mid := (nx_start_match(rid)->>'match_id')::uuid;
    -- own view only
    select count(*) into cnt from nx_match_secrets where match_id = mid;
    t := t || jsonb_build_object('secrets_visible_to_p1', cnt);
    select data into v from nx_match_secrets where match_id = mid;
    t := t || jsonb_build_object('p1_view_keys', (select jsonb_agg(k) from jsonb_object_keys(v) k), 'p1_role', v->'role',
                                 'p1_known_roles', (select count(*) from jsonb_array_elements(v->'players') p where p->>'role' is not null));
    begin perform count(*) from nx_hg_state; t := t || '{"hg_state_readable":true}';
    exception when others then t := t || jsonb_build_object('hg_state_readable', false, 'hg_state_err', sqlerrm); end;
    -- client rows / reports / secrets are refused
    begin r := nx_push_move(mid, (select last_seq + 1 from nx_matches where id = mid), 'move', '{"a":"ready"}', null, null);
          t := t || jsonb_build_object('push_move', r);
    exception when others then t := t || jsonb_build_object('push_move_err', sqlerrm); end;
    begin perform nx_put_secret(mid, u[2], 'view', '{"role":"godfather"}'); t := t || '{"put_secret":"ALLOWED"}';
    exception when others then t := t || jsonb_build_object('put_secret_err', sqlerrm); end;
    r := nx_finish_match(mid, array[0], null, 'x', 'finished'); t := t || jsonb_build_object('finish_by_client', r);
    r := nx_hg_act(mid, '{"a":"tick"}'); t := t || jsonb_build_object('tick_early', r->'reason');
    execute 'reset role';
    select count(*) into cnt from nx_match_reports where match_id = mid; t := t || jsonb_build_object('reports_rows', cnt);
    -- a stranger
    perform set_config('request.jwt.claims', json_build_object('sub',u[9],'role','authenticated')::text, true);
    execute 'set local role authenticated';
    begin r := nx_hg_act(mid, '{"a":"ready"}'); t := t || jsonb_build_object('stranger_act', r);
    exception when others then t := t || jsonb_build_object('stranger_act_err', sqlerrm); end;
    select count(*) into cnt from nx_match_secrets where match_id = mid; t := t || jsonb_build_object('stranger_secrets', cnt);
    execute 'reset role';
    -- everyone ready
    for i in 1..n loop
      perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
      execute 'set local role authenticated';
      r := nx_hg_act(mid, '{"a":"ready"}');
      execute 'reset role';
      update nx_hg_state set st = st - 'lt' where match_id = mid;
    end loop;
    select hg.st into sv from nx_hg_state hg where match_id = mid;
    t := t || jsonb_build_object('after_ready_stage', sv->>'stage', 'roles', sv->'roles');
    roles := _nx_ja_text(sv->'roles');
    select array_agg(g) into mafia_seats from generate_series(0, n-1) g where roles[g+1] in ('godfather','mafia');
    select array_agg(g) into town_seats from generate_series(0, n-1) g where not roles[g+1] in ('godfather','mafia');
    -- a citizen may not act at night or use the mafia chat; a mafia member's chat reaches only mafia views
    seat := (select min(g) from generate_series(0,n-1) g where roles[g+1] = 'citizen');
    perform set_config('request.jwt.claims', json_build_object('sub',u[seat+1],'role','authenticated')::text, true);
    execute 'set local role authenticated';
    r := nx_hg_act(mid, jsonb_build_object('a','night','t',0,'d',1)); t := t || jsonb_build_object('citizen_night', r->'reason');
    r := nx_hg_act(mid, '{"a":"chat","t":"hi"}'); t := t || jsonb_build_object('citizen_night_chat', r->'reason');
    execute 'reset role';
    update nx_hg_state set st = st - 'lt' where match_id = mid;
    seat := mafia_seats[2];
    perform set_config('request.jwt.claims', json_build_object('sub',u[seat+1],'role','authenticated')::text, true);
    execute 'set local role authenticated';
    r := nx_hg_act(mid, '{"a":"chat","t":"kill the doctor"}'); t := t || jsonb_build_object('mafia_chat', r->'ok');
    execute 'reset role';
    select count(*) into cnt from nx_match_secrets s where s.match_id = mid and s.slot = 'view' and s.data::text like '%kill the doctor%';
    t := t || jsonb_build_object('views_with_mafia_chat', cnt, 'mafia_count', array_length(mafia_seats,1));
    select count(*) into cnt from nx_match_moves where match_id = mid and move::text like '%kill the doctor%';
    t := t || jsonb_build_object('mafia_chat_in_move_log', cnt);
    -- play to the end: mafia kill town, doctor saves self-ish nobody, detective checks, town votes mafia
    guard := 0;
    loop
      guard := guard + 1; exit when guard > 60;
      select hg.st into sv from nx_hg_state hg where match_id = mid;
      stage := sv->>'stage'; exit when stage = 'over' or sv->>'winner' is not null;
      alive := _nx_ja_bool(sv->'alive');
      for i in 0..n-1 loop
        legal := _nx_mafia_legal(sv, i);
        continue when legal is null;
        if stage = 'night' then
          tgt := case when roles[i+1] in ('godfather','mafia') then legal[1] else null end;
          if roles[i+1] = 'detective' then tgt := legal[1]; end if;
        elsif stage = 'nominate' then
          tgt := (select min(x) from unnest(legal) x where roles[x+1] in ('godfather','mafia'));
          if roles[i+1] in ('godfather','mafia') then tgt := null; end if;
        else
          tgt := (select min(x) from unnest(legal) x where roles[x+1] in ('godfather','mafia'));
          if roles[i+1] in ('godfather','mafia') then tgt := null; end if;
        end if;
        perform set_config('request.jwt.claims', json_build_object('sub',u[i+1],'role','authenticated')::text, true);
        execute 'set local role authenticated';
        r := nx_hg_act(mid, jsonb_build_object('a', case stage when 'night' then 'night' when 'nominate' then 'nom' else 'final' end,
                                               't', tgt, 'd', (sv->>'day')::int));
        execute 'reset role';
        update nx_hg_state set st = st - 'lt' where match_id = mid;
        if not coalesce((r->>'ok')::boolean, false) then t := t || jsonb_build_object('act_fail_'||guard||'_'||i, r); end if;
        select hg.st into sv from nx_hg_state hg where match_id = mid;
        exit when sv->>'stage' <> stage;
      end loop;
    end loop;
    select * into m from nx_matches where id = mid;
    t := t || jsonb_build_object('mafia_loops', guard, 'final_stage', sv->>'stage', 'winner', sv->>'winner', 'match_status', m.status,
      'winner_seats', m.winner_seats, 'mafia_seats', mafia_seats, 'results', (select count(*) from nx_match_results where match_id = mid),
      'hint_rows', (select count(*) from nx_match_moves where match_id = mid and kind = 'srv'),
      'log_tail', (select jsonb_agg(e->>'en') from jsonb_array_elements(sv->'log') e));
    -- after the end every view shows every role
    select count(*) into cnt from nx_match_secrets s, jsonb_array_elements(s.data->'players') p
     where s.match_id = mid and s.slot = 'view' and p->>'role' is null;
    t := t || jsonb_build_object('hidden_roles_after_end', cnt);
  exception when others then
    get stacked diagnostics err = message_text; execute 'reset role'; t := t || jsonb_build_object('ERROR', err);
  end;
  res := res || jsonb_build_object('mafia', t);

  ------------------------------------------------------------------ MAFIA: leave + timeout
  t := '{}'::jsonb;
  begin
    n := 6;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    execute 'set local role authenticated';
    perform nx_leave_room(rid);
    r := nx_create_room('mafia', n, false, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
    for i in 2..n loop
      perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
      begin perform nx_leave_room((select room_id from nx_room_players where user_id = u[i] limit 1)); exception when others then null; end;
      perform nx_join_room(code, null); perform nx_set_ready(rid, true);
    end loop;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    mid := (nx_start_match(rid)->>'match_id')::uuid;
    perform set_config('request.jwt.claims', json_build_object('sub',u[3],'role','authenticated')::text, true);
    r := nx_forfeit(mid, null); t := t || jsonb_build_object('forfeit', r);
    execute 'reset role';
    select hg.st into sv from nx_hg_state hg where match_id = mid;
    t := t || jsonb_build_object('out', sv->'out', 'alive2', sv->'alive'->2, 'last_log', sv->'log'->-1->>'en');
    update nx_hg_state set deadline = now() - interval '1 minute' where match_id = mid;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    execute 'set local role authenticated';
    r := nx_hg_act(mid, '{"a":"tick"}'); t := t || jsonb_build_object('tick', r);
    execute 'reset role';
    select hg.st into sv from nx_hg_state hg where match_id = mid;
    t := t || jsonb_build_object('stage_after_tick', sv->>'stage');
  exception when others then
    get stacked diagnostics err = message_text; execute 'reset role'; t := t || jsonb_build_object('ERROR', err);
  end;
  res := res || jsonb_build_object('mafia_leave', t);

  ------------------------------------------------------------------ SPY
  t := '{}'::jsonb;
  begin
    n := 7;
    for i in 1..n loop
      perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
      execute 'set local role authenticated';
      begin perform nx_leave_room(rid); exception when others then null; end;
      execute 'reset role';
    end loop;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    execute 'set local role authenticated';
    r := nx_create_room('spy_mafia', n, false, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
    for i in 2..n loop
      perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
      perform nx_join_room(code, null); perform nx_set_ready(rid, true);
    end loop;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    mid := (nx_start_match(rid)->>'match_id')::uuid;
    execute 'reset role';
    select hg.st into sv from nx_hg_state hg where match_id = mid;
    t := t || jsonb_build_object('spies', sv->'spies', 'loc', sv->'loc');
    -- spies do not see the location, agents do; only the player on turn sees options
    select jsonb_agg(jsonb_build_object('seat', s.data->'seat', 'spy', s.data->'spy', 'loc', s.data->'loc', 'opts', s.data->'opts',
                     'spies', s.data->'spies')) into v from nx_match_secrets s where s.match_id = mid and s.slot = 'view';
    t := t || jsonb_build_object('views', v);
    guard := 0;
    loop
      guard := guard + 1; exit when guard > 40;
      select hg.st into sv from nx_hg_state hg where match_id = mid; exit when sv->>'phase' = 'over';
      if sv->>'phase' = 'clues' then seat := (sv->>'turn')::int; r := jsonb_build_object('a','clue','v',1);
        -- an off-turn clue is refused
        if guard = 1 then
          perform set_config('request.jwt.claims', json_build_object('sub',u[((seat+1)%n)+1],'role','authenticated')::text, true);
          execute 'set local role authenticated';
          t := t || jsonb_build_object('offturn_clue', nx_hg_act(mid, r)->'reason');
          execute 'reset role'; update nx_hg_state set st = st - 'lt' where match_id = mid;
        end if;
      elsif sv->>'phase' = 'vote' then
        seat := (select min(g) from generate_series(0,n-1) g where not ((sv->'votes') ? g::text));
        tgt := (sv->'spies'->>0)::int; if tgt = seat then tgt := (seat + 1) % n; end if;
        r := jsonb_build_object('a','vote','v',tgt);
      else
        seat := (sv->>'accused')::int; r := jsonb_build_object('a','guess','v',(sv->>'loc')::int);
      end if;
      perform set_config('request.jwt.claims', json_build_object('sub',u[seat+1],'role','authenticated')::text, true);
      execute 'set local role authenticated';
      r := nx_hg_act(mid, r);
      execute 'reset role'; update nx_hg_state set st = st - 'lt' where match_id = mid;
      if not coalesce((r->>'ok')::boolean, false) then t := t || jsonb_build_object('fail_'||guard, r); end if;
    end loop;
    select * into m from nx_matches where id = mid;
    t := t || jsonb_build_object('loops', guard, 'phase', sv->>'phase', 'spies_win', sv->'spies_win', 'guessed', sv->'guessed',
      'status', m.status, 'winner_seats', m.winner_seats, 'results', (select count(*) from nx_match_results where match_id = mid));
  exception when others then
    get stacked diagnostics err = message_text; execute 'reset role'; t := t || jsonb_build_object('ERROR', err);
  end;
  res := res || jsonb_build_object('spy', t);

  ------------------------------------------------------------------ UNO
  t := '{}'::jsonb;
  begin
    n := 3;
    for i in 1..7 loop
      perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
      execute 'set local role authenticated';
      begin perform nx_leave_room(rid); exception when others then null; end;
      execute 'reset role';
    end loop;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    execute 'set local role authenticated';
    r := nx_create_room('uno', n, false, false, '{}'::jsonb); rid := (r->>'room_id')::uuid; code := r->>'code';
    for i in 2..n loop
      perform set_config('request.jwt.claims', json_build_object('sub',u[i],'role','authenticated')::text, true);
      perform nx_join_room(code, null); perform nx_set_ready(rid, true);
    end loop;
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    mid := (nx_start_match(rid)->>'match_id')::uuid;
    select data into v from nx_match_secrets where match_id = mid;
    t := t || jsonb_build_object('p1_hand_n', jsonb_array_length(v->'hand'), 'p1_counts', v->'counts', 'p1_sees_hands', v->'hands',
                                 'p1_view_has_draw_pile', v ? 'draw');
    -- off-turn play is refused
    perform set_config('request.jwt.claims', json_build_object('sub',u[2],'role','authenticated')::text, true);
    select data into v from nx_match_secrets where match_id = mid;
    r := nx_hg_act(mid, jsonb_build_object('a','play','c',(v->'hand'->>0)::int)); t := t || jsonb_build_object('offturn_play', r->'reason');
    -- a card not in hand is refused
    perform set_config('request.jwt.claims', json_build_object('sub',u[1],'role','authenticated')::text, true);
    r := nx_hg_act(mid, jsonb_build_object('a','play','c',(v->'hand'->>0)::int)); t := t || jsonb_build_object('foreign_card', r->'reason');
    execute 'reset role'; update nx_hg_state set st = st - 'lt' where match_id = mid;
    guard := 0; okc := 0; badc := 0;
    loop
      guard := guard + 1; exit when guard > 900;
      select hg.st into sv from nx_hg_state hg where match_id = mid; exit when sv->'winner' is not null and jsonb_typeof(sv->'winner') = 'number';
      seat := (sv->>'cur')::int;
      perform set_config('request.jwt.claims', json_build_object('sub',u[seat+1],'role','authenticated')::text, true);
      execute 'set local role authenticated';
      select data into v from nx_match_secrets where match_id = mid;
      r := null;
      if jsonb_typeof(v->'drawn') = 'number' then
        r := nx_hg_act(mid, jsonb_build_object('a','play','c',(v->>'drawn')::int,'col',0));
        if not coalesce((r->>'ok')::boolean,false) then r := nx_hg_act(mid, '{"a":"pass"}'); end if;
      else
        if jsonb_array_length(v->'hand') = 2 then perform nx_hg_act(mid, '{"a":"nx"}'); end if;
        execute 'reset role'; update nx_hg_state set st = st - 'lt' where match_id = mid; execute 'set local role authenticated';
        for i in 0 .. jsonb_array_length(v->'hand') - 1 loop
          r := nx_hg_act(mid, jsonb_build_object('a','play','c',(v->'hand'->>i)::int,'col',(guard % 4)));
          exit when coalesce((r->>'ok')::boolean,false);
          execute 'reset role'; update nx_hg_state set st = st - 'lt' where match_id = mid; execute 'set local role authenticated';
        end loop;
        if not coalesce((r->>'ok')::boolean,false) then r := nx_hg_act(mid, '{"a":"draw"}'); end if;
      end if;
      execute 'reset role'; update nx_hg_state set st = st - 'lt' where match_id = mid;
      if coalesce((r->>'ok')::boolean,false) then okc := okc + 1; else badc := badc + 1; t := t || jsonb_build_object('fail_'||guard, r); end if;
      -- invariant: 108 cards
      select hg.st into sv from nx_hg_state hg where match_id = mid;
      cnt := jsonb_array_length(sv->'draw') + jsonb_array_length(sv->'disc')
             + (select sum(jsonb_array_length(h)) from jsonb_array_elements(sv->'hands') h);
      if cnt <> 108 then t := t || jsonb_build_object('card_count_'||guard, cnt); exit; end if;
    end loop;
    select * into m from nx_matches where id = mid;
    t := t || jsonb_build_object('loops', guard, 'ok_acts', okc, 'bad_acts', badc, 'winner', sv->'winner', 'status', m.status,
      'winner_seats', m.winner_seats, 'scores', m.scores, 'results', (select count(*) from nx_match_results where match_id = mid),
      'last_events', (select jsonb_agg(e->>'t') from jsonb_array_elements(sv->'ev') e));
  exception when others then
    get stacked diagnostics err = message_text; execute 'reset role'; t := t || jsonb_build_object('ERROR', err);
  end;
  res := res || jsonb_build_object('uno', t);

  -- anon
  execute 'set local role anon';
  begin perform nx_hg_act(mid, '{"a":"tick"}'); res := res || '{"anon_act":"ALLOWED"}';
  exception when others then res := res || jsonb_build_object('anon_act_err', sqlerrm); end;
  begin select count(*) into cnt from nx_match_secrets; res := res || jsonb_build_object('anon_secrets', cnt);
  exception when others then res := res || jsonb_build_object('anon_secrets_err', sqlerrm); end;
  execute 'reset role';
  raise exception 'HARNESS_RESULT %', res;
end $$;
