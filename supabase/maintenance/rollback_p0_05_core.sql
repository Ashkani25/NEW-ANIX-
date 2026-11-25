-- Rollback for migrations/20261125200400_p0_05_client_errors.sql (restores the fix/backend-security S1 policy)
drop function if exists public.nx_admin_client_errors(int, timestamptz);
drop function if exists public.nx_log_client_error(text, text, text, jsonb, text, text);
drop policy if exists client_errors_admin_read on public.client_errors;
revoke select on table public.client_errors from authenticated;
drop policy if exists "ce insert" on public.client_errors;
create policy "ce insert" on public.client_errors for insert to authenticated
  with check (length(message) <= 2000 and length(coalesce(stack, '')) <= 8000 and (user_id is null or user_id = auth.uid()));
drop index if exists public.client_errors_user_idx;
drop function if exists public._nx_caller_is_admin();
