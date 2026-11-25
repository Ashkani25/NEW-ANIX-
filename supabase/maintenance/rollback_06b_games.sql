-- rollback snapshot taken 2026-11-25 (UTC+03:30) from project eyzafhrefnqlwcjpcdyg (state BEFORE #6 part 2)
-- Undo of 20261125200000_sec06b_hidden_games_server.sql. Running matches of mafia/spy_mafia/uno that started
-- under the server engine cannot continue on the old clients (their state is server-only); end them first.
do $c$ begin if exists (select 1 from cron.job where jobname = 'nx_hg_sweep') then perform cron.unschedule('nx_hg_sweep'); end if; end $c$;
drop trigger if exists nx_matches_hidden_deal on public.nx_matches;
drop trigger if exists nx_matches_last_seq_monotonic on public.nx_matches;
drop trigger if exists nx_match_moves_hidden_guard on public.nx_match_moves;
drop trigger if exists nx_match_moves_hidden_forfeit on public.nx_match_moves;
CREATE OR REPLACE FUNCTION public.nx_finish_match(p_match uuid, p_winners integer[], p_scores integer[], p_hash text DEFAULT NULL::text, p_reason text DEFAULT 'finished'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  m nx_matches;
  n int;
  w int[];
  forfeited int[];
  required uuid[];
  missing uuid[];
  n_reports int;
  n_winner_sets int;
  n_hashes int;
  n_null_hash int;
  final_scores int[];
  k int;
  u uuid;
  gone boolean := true;
  a_seat int;
  ar nx_match_reports;
begin
  select * into m from nx_matches where id = p_match for update;
  if m.id is null then raise exception 'match not found'; end if;
  if me is null or not (me = any(m.players)) then raise exception 'not a player'; end if;
  if m.status <> 'playing' then
    return jsonb_build_object('ok', true, 'already', true, 'winners', m.winner_seats, 'status', m.status);
  end if;
  n := coalesce(array_length(m.players, 1), 0);

  if exists (select 1 from unnest(coalesce(p_winners, '{}'::int[])) x where x is null or x < 0 or x >= n) then
    return jsonb_build_object('ok', false, 'error', 'bad_winners');
  end if;
  select coalesce(array_agg(distinct x order by x), '{}'::int[]) into w from unnest(coalesce(p_winners, '{}'::int[])) x;

  insert into nx_match_reports(match_id, user_id, winners, scores, state_hash, reason)
  values (p_match, me, w, p_scores, nullif(left(p_hash, 128), ''), left(coalesce(p_reason, 'finished'), 40))
  on conflict (match_id, user_id) do nothing;

  forfeited := public._nx_forfeited_seats(p_match);
  select coalesce(array_agg(m.players[g]), '{}'::uuid[]) into required
    from generate_series(1, n) g
   where m.players[g] is not null and not ((g - 1) = any(forfeited));
  select coalesce(array_agg(x), '{}'::uuid[]) into missing
    from unnest(required) x
   where not exists (select 1 from nx_match_reports r where r.match_id = p_match and r.user_id = x);

  select count(*), count(distinct winners), count(distinct state_hash), count(*) filter (where state_hash is null)
    into n_reports, n_winner_sets, n_hashes, n_null_hash
    from nx_match_reports where match_id = p_match;

  -- #5: reports that agree on the winners settle even when their state hashes differ (float drift between phones).
  -- #4: reports that disagree on the winners: the match authority's report decides (it runs the authoritative
  -- simulation / posts the snapshots). Everyone who reported something else gets a row in nx_match_disputes so
  -- repeat disputers can be flagged. Without an authority report we wait; when the authority is gone for good the
  -- match is closed as disputed with no rewards (old behaviour).
  if n_winner_sets > 1 then
    a_seat := public._nx_match_authority(p_match);
    select * into ar from nx_match_reports r where r.match_id = p_match and r.user_id = m.players[a_seat + 1];
    if ar.user_id is null then
      if a_seat is not null and (now() <= m.turn_deadline or m.started_at > now() - interval '30 seconds'
          or public._nx_player_active(p_match, m.players[a_seat + 1], 30, 30)) then
        return jsonb_build_object('ok', true, 'pending', true, 'conflict', true, 'reports', n_reports);
      end if;
      update nx_matches set status = 'disputed', winner_seats = null, reason = 'disputed', ended_at = now()
       where id = p_match;
      insert into nx_match_disputes(match_id, user_id, reported, decided, authority_seat)
      select p_match, r.user_id, r.winners, null, a_seat from nx_match_reports r where r.match_id = p_match
      on conflict (match_id, user_id) do nothing;
      perform _nx_room_after_match(m.room_id, m.id);
      return jsonb_build_object('ok', true, 'disputed', true, 'winners', null);
    end if;
    w := ar.winners;
    final_scores := ar.scores;
    insert into nx_match_disputes(match_id, user_id, reported, decided, authority_seat)
    select p_match, r.user_id, r.winners, w, a_seat from nx_match_reports r
     where r.match_id = p_match and r.winners is distinct from w
    on conflict (match_id, user_id) do nothing;
    update nx_matches set status = 'finished', winner_seats = w, scores = final_scores,
           reason = coalesce(ar.reason, 'finished'), state_hash = coalesce(ar.state_hash, state_hash), ended_at = now()
     where id = p_match returning * into m;
    perform _nx_apply_result(m, w, final_scores);
    perform _nx_room_after_match(m.room_id, m.id);
    return jsonb_build_object('ok', true, 'winners', w, 'decided_by', 'authority', 'authority_seat', a_seat);
  end if;

  if coalesce(array_length(missing, 1), 0) > 0 then
    if now() <= m.turn_deadline or m.started_at > now() - interval '30 seconds' then
      gone := false;
    else
      foreach u in array missing loop
        if public._nx_player_active(p_match, u, 30, 30)
           or exists (select 1 from nx_room_players rp where rp.room_id = m.room_id and rp.user_id = u
                    and rp.last_seen > now() - interval '30 seconds') then
          gone := false;
          exit;
        end if;
      end loop;
    end if;
    if not gone then
      return jsonb_build_object('ok', true, 'pending', true, 'reports', n_reports,
                                'needed', coalesce(array_length(required, 1), 0));
    end if;
  end if;

  select r.winners into w from nx_match_reports r where r.match_id = p_match limit 1;
  final_scores := null;
  if not exists (select 1 from nx_match_reports r where r.match_id = p_match and r.scores is null) then
    final_scores := '{}'::int[];
    for k in 1..n loop
      final_scores := final_scores || (select min(r.scores[k]) from nx_match_reports r where r.match_id = p_match);
    end loop;
  end if;
  update nx_matches set status = 'finished', winner_seats = w, scores = final_scores,
         reason = left(coalesce(p_reason, 'finished'), 40),
         state_hash = coalesce((select max(r.state_hash) from nx_match_reports r where r.match_id = p_match), state_hash),
         ended_at = now()
   where id = p_match returning * into m;
  perform _nx_apply_result(m, w, final_scores);
  perform _nx_room_after_match(m.room_id, m.id);
  return jsonb_build_object('ok', true, 'winners', w);
end $function$
;
CREATE OR REPLACE FUNCTION public.nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_matches;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select * into m from nx_matches where id = p_match;
  if m.id is null or m.players[1] is distinct from auth.uid() then raise exception 'authority only'; end if;
  if not (p_user = any(m.players)) then raise exception 'not a player'; end if;
  insert into nx_match_secrets(match_id, user_id, slot, data) values (p_match, p_user, p_slot, p_data)
  on conflict (match_id, user_id, slot) do update set data = excluded.data, created_at = now();
end $function$
;
grant execute on function public.nx_put_secret(uuid, uuid, text, jsonb) to anon, authenticated;
CREATE OR REPLACE FUNCTION public._nx_server_result_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.game = 'quiz'
     and old.status = 'playing' and new.status = 'finished'
     and coalesce(new.reason, 'finished') not like 'forfeit%'
     and exists (select 1 from public.nx_quiz_games q where q.match_id = new.id and q.phase <> 'pick')
     and coalesce(current_setting('nx.server_result', true), '') <> '1' then
    raise exception 'the server decides % results', new.game;
  end if;
  return new;
end $function$
;
grant insert, update, delete, truncate, references, trigger on public.nx_match_secrets to anon, authenticated;
grant select on public.nx_match_secrets to anon;
grant insert, update, delete, truncate, references, trigger on public.nx_match_moves to anon, authenticated;
drop function if exists public.nx_hg_act(uuid, jsonb);
drop function if exists public._nx_hg_sweep();
drop function if exists public._nx_hg_on_match();
drop function if exists public._nx_hg_on_forfeit();
drop function if exists public._nx_hg_moves_guard();
drop function if exists public._nx_last_seq_monotonic();
drop function if exists public._nx_hg_commit(uuid, jsonb);
drop function if exists public._nx_hg_finish(uuid, int[], int[]);
drop function if exists public._nx_hg_publish(uuid, jsonb, int[]);
drop function if exists public._nx_hg_step(text, jsonb, int, jsonb, text[]);
drop function if exists public._nx_uno_view(jsonb, int);
drop function if exists public._nx_uno_step(jsonb, int, jsonb);
drop function if exists public._nx_uno_init(int);
drop function if exists public._nx_uno_points(int);
drop function if exists public._nx_uno_num(int);
drop function if exists public._nx_uno_color(int);
drop function if exists public._nx_uno_kind(int);
drop function if exists public._nx_spy_view(jsonb, int);
drop function if exists public._nx_spy_step(jsonb, int, jsonb);
drop function if exists public._nx_spy_init(int);
drop function if exists public._nx_spy_opts(jsonb, int);
drop function if exists public._nx_mafia_view(jsonb, int, text[]);
drop function if exists public._nx_mafia_step(jsonb, int, jsonb, text[]);
drop function if exists public._nx_mafia_legal(jsonb, int);
drop function if exists public._nx_mafia_actors(jsonb);
drop function if exists public._nx_mafia_init(int);
drop function if exists public._nx_mafia_label(text, boolean);
drop function if exists public._nx_mafia_is_m(text);
drop table if exists public.nx_hg_state;
drop function if exists public._nx_hg_games();
drop function if exists public._nx_jint(jsonb);
drop function if exists public._nx_ja_text(jsonb);
drop function if exists public._nx_ja_bool(jsonb);
drop function if exists public._nx_ja_int(jsonb);
drop function if exists public._nx_shuffle(int[]);
drop function if exists public._nx_rand(int);
