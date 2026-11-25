-- #13: leftover catalog backup table had RLS disabled. Keep the data, lock it to service_role/postgres only.
alter table public.nx_catalog_backup_20261124 enable row level security;
revoke all on table public.nx_catalog_backup_20261124 from public, anon, authenticated;
