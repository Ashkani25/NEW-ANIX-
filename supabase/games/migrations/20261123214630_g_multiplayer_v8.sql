-- GAMES project · recovered verbatim from the live migration history (supabase_migrations.schema_migrations, version
-- 20261123214630, applied outside the repo). Added 2026-11-25 so the repo matches live (source of nx_match_turn_state and the
-- current _nx_server_result_guard). Already applied live.
-- ONLINE MULTIPLAYER v8 (games project).
-- App-wide deadlock recovery + result-guard compatibility for all 16 online games.

create table if not exists public.nx_match_turn_state (
  match_id uuid primary key references public.nx_matches(id) on delete cascade,
  authority_user uuid not null,
  epoch bigint not null default 0,
  seat integer not null,
  deadline timestamptz not null,
  updated_at timestamptz not null default now()
);
alter table public.nx_match_turn_state enable row level security;
revoke all on table public.nx_match_turn_state from public, anon, authenticated;
grant all on table public.nx_match_turn_state to service_role;

create or replace function public._nx_match_authority(p_match uuid)
 returns integer language plpgsql stable security definer set search_path to 'public' as $$
declare m public.nx_matches; gone int[]; a int;
begin
  select * into m from public.nx_matches where id = p_match;
  if m.id is null then return null; end if;
  gone := public._nx_forfeited_seats(p_match);
  select min(g) into a
    from generate_series(0, coalesce(array_length(m.players, 1), 0) - 1) g
   where not (g = any(gone))
     and public._nx_player_active(p_match, m.players[g + 1], 25, 30);
  if a is null then
    select min(g) into a
      from generate_series(0, coalesce(array_length(m.players, 1), 0) - 1) g
     where not (g = any(gone));
  end if;
  return a;
end $$;
revoke all on function public._nx_match_authority(uuid) from public, anon, authenticated;
grant execute on function public._nx_match_authority(uuid) to service_role;

create or replace function public.nx_match_turn(
  p_match uuid,
  p_seat integer,
  p_epoch bigint,
  p_seconds integer default 90
) returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); m public.nx_matches; caller int; n int; a int; old public.nx_match_turn_state; secs int;
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into m from public.nx_matches where id = p_match for update;
  if m.id is null or m.status <> 'playing' then return jsonb_build_object('ok', false, 'reason', 'over'); end if;
  caller := array_position(m.players, me) - 1;
  if caller is null then raise exception 'not a player'; end if;
  n := coalesce(array_length(m.players, 1), 0);
  if p_seat is null or p_seat < 0 or p_seat >= n then
    return jsonb_build_object('ok', false, 'reason', 'bad_seat');
  end if;
  if p_seat = any(public._nx_forfeited_seats(p_match)) then
    return jsonb_build_object('ok', false, 'reason', 'forfeited');
  end if;
  a := public._nx_match_authority(p_match);
  if caller <> a then return jsonb_build_object('ok', false, 'reason', 'not_authority', 'authority', a); end if;
  secs := greatest(30, least(coalesce(p_seconds, 90), 300));
  select * into old from public.nx_match_turn_state where match_id = p_match for update;
  if old.match_id is not null and old.authority_user = me and coalesce(p_epoch, 0) <= old.epoch then
    return jsonb_build_object('ok', true, 'unchanged', true, 'seat', old.seat,
                              'deadline', old.deadline, 'epoch', old.epoch);
  end if;
  insert into public.nx_match_turn_state(match_id, authority_user, epoch, seat, deadline, updated_at)
  values (p_match, me, greatest(0, coalesce(p_epoch, 0)), p_seat,
          now() + make_interval(secs => secs), now())
  on conflict (match_id) do update set
    authority_user = excluded.authority_user,
    epoch = excluded.epoch,
    seat = excluded.seat,
    deadline = excluded.deadline,
    updated_at = excluded.updated_at;
  update public.nx_matches set turn_seat = p_seat,
         turn_deadline = now() + make_interval(secs => secs)
   where id = p_match;
  return jsonb_build_object('ok', true, 'seat', p_seat, 'epoch', greatest(0, coalesce(p_epoch, 0)),
                            'deadline', now() + make_interval(secs => secs));
end $$;
revoke all on function public.nx_match_turn(uuid, integer, bigint, integer) from public, anon;
grant execute on function public.nx_match_turn(uuid, integer, bigint, integer) to authenticated, service_role;

create or replace function public.nx_idle_forfeit(p_match uuid, p_seat integer)
 returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); m public.nx_matches; ts public.nx_match_turn_state;
        caller int; a int; n int; gone int[]; alive int[];
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into m from public.nx_matches where id = p_match for update;
  if m.id is null or m.status <> 'playing' then return jsonb_build_object('ok', false, 'reason', 'over'); end if;
  caller := array_position(m.players, me) - 1;
  if caller is null then raise exception 'not a player'; end if;
  n := coalesce(array_length(m.players, 1), 0);
  if p_seat is null or p_seat < 0 or p_seat >= n then
    return jsonb_build_object('ok', false, 'reason', 'bad_seat');
  end if;
  gone := public._nx_forfeited_seats(p_match);
  if p_seat = any(gone) then return jsonb_build_object('ok', true, 'seat', p_seat, 'already', true); end if;
  if caller = any(gone) then return jsonb_build_object('ok', false, 'reason', 'forfeited'); end if;
  a := public._nx_match_authority(p_match);
  if caller <> a then return jsonb_build_object('ok', false, 'reason', 'not_authority', 'authority', a); end if;
  select * into ts from public.nx_match_turn_state where match_id = p_match for update;
  if ts.match_id is null or ts.seat <> p_seat then
    return jsonb_build_object('ok', false, 'reason', 'not_turn');
  end if;
  if now() < ts.deadline then
    return jsonb_build_object('ok', false, 'reason', 'too_early', 'deadline', ts.deadline);
  end if;
  if exists (select 1 from public.nx_match_reports r
              where r.match_id = p_match and r.user_id = m.players[p_seat + 1]) then
    return jsonb_build_object('ok', false, 'reason', 'reported');
  end if;
  insert into public.nx_match_moves(match_id, seq, seat, by_user, kind, move)
  values (p_match, m.last_seq + 1, p_seat, me, 'forfeit',
          jsonb_build_object('seat', p_seat, 'idle', true));
  update public.nx_matches set last_seq = m.last_seq + 1 where id = p_match;
  select coalesce(array_agg(g), '{}'::int[]) into alive
    from generate_series(0, n - 1) g where not (g = any(gone)) and g <> p_seat;
  if coalesce(array_length(alive, 1), 0) = 1 then
    return public.nx_finish_match_as(p_match, alive, p_seat);
  elsif coalesce(array_length(alive, 1), 0) = 0 then
    update public.nx_matches set status = 'abandoned', reason = 'abandoned', ended_at = now()
     where id = p_match;
    perform public._nx_room_after_match(m.room_id, m.id);
  end if;
  return jsonb_build_object('ok', true, 'seat', p_seat, 'idle', true);
end $$;
revoke all on function public.nx_idle_forfeit(uuid, integer) from public, anon;
grant execute on function public.nx_idle_forfeit(uuid, integer) to authenticated, service_role;

create or replace function public._nx_server_result_guard()
 returns trigger language plpgsql as $$
begin
  if new.game = 'quiz'
     and old.status = 'playing' and new.status = 'finished'
     and coalesce(new.reason, 'finished') not like 'forfeit%'
     and exists (select 1 from public.nx_quiz_games q where q.match_id = new.id and q.phase <> 'pick')
     and coalesce(current_setting('nx.server_result', true), '') <> '1' then
    raise exception 'the server decides % results', new.game;
  end if;
  return new;
end $$;
