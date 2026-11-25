-- rollback snapshot taken 2026-11-25T17:07:12Z from project eyzafhrefnqlwcjpcdyg (state BEFORE the fix)
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

  if n_winner_sets > 1 or (n_null_hash = 0 and n_hashes > 1) then
    update nx_matches set status = 'disputed', winner_seats = null, reason = 'disputed', ended_at = now()
     where id = p_match;
    perform _nx_room_after_match(m.room_id, m.id);
    return jsonb_build_object('ok', true, 'disputed', true, 'winners', null);
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
revoke all on function nx_finish_match(uuid,integer[],integer[],text,text) from public, anon, authenticated; grant execute on function nx_finish_match(uuid,integer[],integer[],text,text) to authenticated;
drop view if exists public.nx_dispute_counts;
drop table if exists public.nx_match_disputes;
