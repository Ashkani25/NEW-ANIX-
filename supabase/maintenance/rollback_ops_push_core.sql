-- Rollback for 20261125210300_ops_push_core.sql (core). device_tokens rows are kept (no user data is deleted).
drop trigger if exists nx_push_message on public.nx_messages;
drop trigger if exists nx_push_call on public.nx_calls;
drop function if exists public._nx_push_on_message();
drop function if exists public._nx_push_on_call();
drop function if exists public.nx_push_notify_batch(jsonb);
drop function if exists public._nx_push_text(text, jsonb, boolean);
drop function if exists public.nx_push_register(text, text, text);
drop function if exists public.nx_push_unregister(text);
