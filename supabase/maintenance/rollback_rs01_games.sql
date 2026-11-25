-- Rollback of supabase/games/migrations/20261126210000_rs01_spectator.sql (games project). Removes the spectator
-- read path and the watch-invite RPC; restores the previous nx_invites UPDATE grant. Watch invites already sent stay
-- (user data) and simply stop granting anything.
drop policy if exists nx_match_channel_spectate on realtime.messages;
drop policy if exists nx_match_moves_spectate on public.nx_match_moves;
drop policy if exists nx_matches_spectate on public.nx_matches;
drop function if exists public.nx_invite_watch(uuid, uuid);
drop function if exists public.nx_can_spectate(uuid);
grant update on table public.nx_invites to authenticated;
