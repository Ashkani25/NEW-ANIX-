-- RS-01 (games, 2026-11-26, work/rematch-spectator): read-only spectators for live online matches.
--
-- Who may watch a match (nx_can_spectate):
--   * a member of the match's room (nx_room_members, any role, or nx_room_players) who is not one of its players, or
--   * a user a player of THIS match invited to watch (nx_invite_watch -> nx_invites kind 'watch', not declined);
--   * never a banned user (nx_bans), never someone who blocked / is blocked by any player (user_blocks), never in a
--     server-authoritative hidden-information game (mafia / spy_mafia / uno / quiz: nx_hg_state or quiz rows; a
--     spectator would only see a public log, and these games' views are per player), and only while the match is
--     playing or ended less than 10 minutes ago (so the watcher still sees the final result).
-- What a spectator gets: SELECT on the match row, its move log, and RECEIVE on the private Realtime channel nxm:<id>
-- (broadcast + presence). Nothing to write: nx_push_move / nx_match_ping / nx_forfeit / nx_finish_match all check
-- players, nx_match_moves has no insert policy, and the channel INSERT policy (send broadcast / track presence) stays
-- players-only, so a spectator can neither move, chat on the match channel, nor appear in presence.
-- Also: the invitee of an invite may only change its status (column UPDATE grant), so an invite row can not be
-- rewritten into a watch pass for another match.
-- Idempotent; drops no table and touches no user data. Rollback: supabase/maintenance/rollback_rs01_games.sql

create or replace function public.nx_can_spectate(m uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select auth.uid() is not null
     and not public._nx_g_banned(auth.uid())
     and exists (
       select 1 from public.nx_matches x
        where x.id = m
          and not (auth.uid() = any(x.players))
          and (x.status = 'playing' or (x.ended_at is not null and x.ended_at > now() - interval '10 minutes'))
          and x.game not in ('mafia', 'spy_mafia', 'uno', 'quiz')
          and not exists (select 1 from public.nx_hg_state h where h.match_id = x.id)
          and not exists (select 1 from unnest(x.players) p where public._nx_g_blocked(auth.uid(), p))
          and (
            (x.room_id is not null and (
               exists (select 1 from public.nx_room_members rm where rm.room_id = x.room_id and rm.user_id = auth.uid())
               or exists (select 1 from public.nx_room_players rp where rp.room_id = x.room_id and rp.user_id = auth.uid())))
            or exists (select 1 from public.nx_invites i
                        where i.to_user = auth.uid() and i.kind = 'watch' and i.status in ('pending', 'accepted')
                          and i.payload ->> 'match_id' = x.id::text
                          and i.from_user = any(x.players)
                          and i.created_at > now() - interval '6 hours')))
$function$;
revoke all on function public.nx_can_spectate(uuid) from public, anon;
grant execute on function public.nx_can_spectate(uuid) to authenticated;

-- read-only spectator policies (OR'ed with the players' own policies)
drop policy if exists nx_matches_spectate on public.nx_matches;
create policy nx_matches_spectate on public.nx_matches for select to authenticated using (public.nx_can_spectate(id));

drop policy if exists nx_match_moves_spectate on public.nx_match_moves;
create policy nx_match_moves_spectate on public.nx_match_moves for select to authenticated
  using (public.nx_can_spectate(match_id));

drop policy if exists nx_match_channel_spectate on realtime.messages;
create policy nx_match_channel_spectate on realtime.messages for select to authenticated
  using (realtime.topic() ~ '^nxm:[0-9a-fA-F-]{36}$' and public.nx_can_spectate((substr(realtime.topic(), 5))::uuid));

-- invitees may only answer an invite (status), never rewrite who sent it / for what
revoke update on table public.nx_invites from anon, authenticated;
grant update (status) on table public.nx_invites to authenticated;

-- A player of a live match invites a user to watch it. Blocks / bans are enforced by the nx_invites triggers
-- (nx_invites_block, nx_ban_guard) and again by nx_can_spectate when the invitee opens the match.
create or replace function public.nx_invite_watch(p_match uuid, p_user uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare me uuid := auth.uid(); x public.nx_matches; n int;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select * into x from public.nx_matches where id = p_match;
  if x.id is null or not (me = any(x.players)) then raise exception 'not a player' using errcode = '42501'; end if;
  if x.status <> 'playing' then return jsonb_build_object('ok', false, 'reason', 'over'); end if;
  if p_user is null or p_user = me or p_user = any(x.players) then return jsonb_build_object('ok', false, 'reason', 'bad_user'); end if;
  if x.game in ('mafia', 'spy_mafia', 'uno', 'quiz') or exists (select 1 from public.nx_hg_state h where h.match_id = p_match) then
    return jsonb_build_object('ok', false, 'reason', 'not_watchable');
  end if;
  if public._nx_g_blocked(me, p_user) then raise exception 'blocked' using errcode = 'P0001'; end if;
  if public._nx_g_banned(p_user) then return jsonb_build_object('ok', false, 'reason', 'unavailable'); end if;
  if exists (select 1 from public.nx_invites where from_user = me and to_user = p_user and kind = 'watch'
              and payload ->> 'match_id' = p_match::text) then
    return jsonb_build_object('ok', true, 'already', true);
  end if;
  select count(*) into n from public.nx_invites where from_user = me and kind = 'watch' and created_at > now() - interval '10 minutes';
  if n >= 20 then return jsonb_build_object('ok', false, 'reason', 'rate'); end if;
  insert into public.nx_invites(from_user, to_user, kind, room_id, payload)
  values (me, p_user, 'watch', x.room_id, jsonb_build_object('match_id', p_match, 'game', x.game,
          'from_name', (select username from public.profiles where id = me)));
  return jsonb_build_object('ok', true);
end $function$;
revoke all on function public.nx_invite_watch(uuid, uuid) from public, anon;
grant execute on function public.nx_invite_watch(uuid, uuid) to authenticated;
