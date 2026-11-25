-- rollback #9 (core): new objects only
drop function if exists public.nx_login_throttle(text, text);
drop table if exists public.nx_login_attempts;
