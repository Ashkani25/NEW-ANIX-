-- Rollback for games/migrations/20261125200000_p0_01_account_deletion.sql
drop function if exists public.nx_bridge_forget_user(uuid);
drop function if exists public._nx_forget_user(uuid);
