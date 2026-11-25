-- Rollback for supabase/games/migrations/20261125210300_ops_push_games.sql (games project).
drop trigger if exists nx_push_t_notif on public.nx_t_notifications;
drop trigger if exists nx_push_invite on public.nx_invites;
drop function if exists public._nx_push_on_t_notif();
drop function if exists public._nx_push_on_invite();
drop function if exists public._nx_push_relay(jsonb);
