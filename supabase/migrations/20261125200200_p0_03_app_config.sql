-- P0 #3: min-version / force-update + maintenance mode. Core project (eisstodgncimypdawisy).
-- One public, read-only row. The app reads it at start, on resume and every 10 minutes (nx_app_status), and blocks
-- with a full-screen notice when its build (APP_VC) is below min_version_code or maintenance is on. Owner / admins
-- bypass maintenance (decided server-side in nx_app_status). Only the platform owner can change it
-- (nx_admin_set_app_config, or SQL).
create table if not exists public.nx_app_config (
  id int primary key default 1 check (id = 1),
  min_version_code int not null default 0,
  latest_version_code int not null default 0,
  maintenance boolean not null default false,
  message_fa text not null default '',
  message_en text not null default '',
  store_url text not null default '',
  updated_at timestamptz not null default now(),
  updated_by uuid
);
insert into public.nx_app_config(id) values (1) on conflict (id) do nothing;

alter table public.nx_app_config enable row level security;
revoke all on table public.nx_app_config from anon, authenticated;
grant select on table public.nx_app_config to anon, authenticated;
drop policy if exists nx_app_config_read on public.nx_app_config;
create policy nx_app_config_read on public.nx_app_config for select to anon, authenticated using (true);

create or replace function public.nx_app_status()
returns jsonb language sql stable security definer set search_path = public
as $$
  select jsonb_build_object(
    'min_version_code', c.min_version_code, 'latest_version_code', c.latest_version_code,
    'maintenance', c.maintenance, 'message_fa', c.message_fa, 'message_en', c.message_en, 'store_url', c.store_url,
    'bypass', coalesce(auth.uid() is not null and public.nx_is_admin_any(auth.uid()), false),
    'updated_at', c.updated_at)
  from public.nx_app_config c where c.id = 1
$$;
revoke all on function public.nx_app_status() from public;
grant execute on function public.nx_app_status() to anon, authenticated;

create or replace function public.nx_admin_set_app_config(p jsonb)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare g text := _nx_admin_guard('owner'); c nx_app_config;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  if p is null or jsonb_typeof(p) <> 'object' then return jsonb_build_object('ok', false, 'error', 'bad_input'); end if;
  update nx_app_config set
    min_version_code = coalesce((p ->> 'min_version_code')::int, min_version_code),
    latest_version_code = coalesce((p ->> 'latest_version_code')::int, latest_version_code),
    maintenance = coalesce((p ->> 'maintenance')::boolean, maintenance),
    message_fa = left(coalesce(p ->> 'message_fa', message_fa), 600),
    message_en = left(coalesce(p ->> 'message_en', message_en), 600),
    store_url = left(coalesce(p ->> 'store_url', store_url), 300),
    updated_at = now(), updated_by = auth.uid()
  where id = 1 returning * into c;
  if c.min_version_code < 0 or c.latest_version_code < 0 then raise exception 'bad_version'; end if;
  if c.store_url <> '' and c.store_url !~* '^(https://|bazaar://|market://|myket://)' then raise exception 'bad_store_url'; end if;
  perform _nx_owner_log('app_config', null, p);
  return jsonb_build_object('ok', true, 'config', to_jsonb(c));
end $$;
revoke all on function public.nx_admin_set_app_config(jsonb) from public, anon;
grant execute on function public.nx_admin_set_app_config(jsonb) to authenticated;
