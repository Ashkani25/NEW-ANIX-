-- #9 (core): server-side throttle for the nx-login edge function, keyed on the CLIENT ip (+ username), not on the
-- edge function's own egress ip that GoTrue sees. Called with the service role only.
create table if not exists public.nx_login_attempts (
  bucket text not null,
  window_start timestamptz not null,
  attempts int not null default 0,
  primary key (bucket, window_start)
);
alter table public.nx_login_attempts enable row level security;
revoke all on table public.nx_login_attempts from public, anon, authenticated;

create or replace function public.nx_login_throttle(p_ip text, p_username text)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare
  w timestamptz := date_trunc('minute', now()) - make_interval(mins => (extract(minute from now())::int % 15));
  ip text := left(coalesce(nullif(trim(p_ip), ''), 'unknown'), 64);
  un text := left(lower(coalesce(trim(p_username), '')), 32);
  k text; lim int; n int;
begin
  foreach k in array array['ipu:' || ip || '|' || un, 'ip:' || ip, 'u:' || un] loop
    lim := case when k like 'ipu:%' then 10 when k like 'ip:%' then 60 else 30 end;
    insert into nx_login_attempts(bucket, window_start, attempts) values (k, w, 1)
    on conflict (bucket, window_start) do update set attempts = nx_login_attempts.attempts + 1
    returning attempts into n;
    if n > lim then
      return jsonb_build_object('ok', false, 'retry_after', greatest(1, extract(epoch from (w + interval '15 minutes' - now()))::int));
    end if;
  end loop;
  delete from nx_login_attempts where window_start < now() - interval '1 day';
  return jsonb_build_object('ok', true);
end $f$;
revoke all on function public.nx_login_throttle(text, text) from public, anon, authenticated;
grant execute on function public.nx_login_throttle(text, text) to service_role;
