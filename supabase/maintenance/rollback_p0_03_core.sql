-- Rollback for migrations/20261125200200_p0_03_app_config.sql
drop function if exists public.nx_admin_set_app_config(jsonb);
drop function if exists public.nx_app_status();
drop table if exists public.nx_app_config;
