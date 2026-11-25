-- P0 #5: crash / error reporting into public.client_errors (core project).
-- * nx_log_client_error(...): the app's only write path. Signed-in callers are stamped with auth.uid() and limited to
--   30 reports / 10 min; signed-out callers (crashes before sign-in) share a global cap of 300 / hour. Text is
--   truncated; rows older than 30 days are pruned as a side effect.
-- * Direct inserts stay possible for signed-in users but only for their own uid (user_id = auth.uid(), never NULL).
-- * Admins (any admin permission) read through RLS and nx_admin_client_errors.
drop policy if exists "ce insert" on public.client_errors;
create policy "ce insert" on public.client_errors for insert to authenticated
  with check (length(message) <= 2000 and length(coalesce(stack, '')) <= 8000 and user_id = auth.uid());
-- RLS helper: is the caller any kind of admin (nx_is_admin_any itself is not executable by clients).
create or replace function public._nx_caller_is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select auth.uid() is not null and public.nx_is_admin_any(auth.uid()) $$;
revoke all on function public._nx_caller_is_admin() from public, anon;
grant execute on function public._nx_caller_is_admin() to authenticated;

drop policy if exists client_errors_admin_read on public.client_errors;
create policy client_errors_admin_read on public.client_errors for select to authenticated
  using (public._nx_caller_is_admin());
grant select on table public.client_errors to authenticated;
create index if not exists client_errors_user_idx on public.client_errors (user_id, created_at desc);

create or replace function public.nx_log_client_error(p_kind text, p_message text, p_stack text default null,
  p_context jsonb default '{}'::jsonb, p_app_version text default null, p_platform text default null)
returns boolean language plpgsql security definer set search_path = public
as $$
declare me uuid := auth.uid(); n int;
begin
  if coalesce(btrim(p_message), '') = '' then return false; end if;
  if me is not null then
    select count(*) into n from client_errors where user_id = me and created_at > now() - interval '10 minutes';
    if n >= 30 then return false; end if;
  else
    select count(*) into n from client_errors where user_id is null and created_at > now() - interval '1 hour';
    if n >= 300 then return false; end if;
  end if;
  insert into client_errors(user_id, kind, message, stack, context, app_version, platform)
  values (me, left(coalesce(nullif(btrim(p_kind), ''), 'error'), 40), left(p_message, 2000), left(p_stack, 8000),
          case when jsonb_typeof(p_context) = 'object' and length(p_context::text) <= 4000 then p_context else '{}'::jsonb end,
          left(p_app_version, 40), left(p_platform, 60));
  if random() < 0.02 then
    delete from client_errors where created_at < now() - interval '30 days';
  end if;
  return true;
end $$;
revoke all on function public.nx_log_client_error(text, text, text, jsonb, text, text) from public;
grant execute on function public.nx_log_client_error(text, text, text, jsonb, text, text) to anon, authenticated;

create or replace function public.nx_admin_client_errors(p_limit int default 100, p_before timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = public
as $$
declare g text := _nx_admin_guard(null);
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  return jsonb_build_object('ok', true, 'errors', coalesce((select jsonb_agg(x order by x.created_at desc) from (
    select e.id, e.kind, e.message, left(e.stack, 1500) as stack, e.context, e.app_version, e.platform, e.created_at,
           e.user_id, p.username
      from client_errors e left join profiles p on p.id = e.user_id
     where p_before is null or e.created_at < p_before
     order by e.created_at desc limit greatest(1, least(coalesce(p_limit, 100), 300))) x), '[]'::jsonb),
    'last_24h', (select count(*) from client_errors where created_at > now() - interval '24 hours'));
end $$;
revoke all on function public.nx_admin_client_errors(int, timestamptz) from public, anon;
grant execute on function public.nx_admin_client_errors(int, timestamptz) to authenticated;
