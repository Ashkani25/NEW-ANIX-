-- P0 #7b (games): server-authoritative hidden-info games (mafia, spy_mafia, uno) take every input through nx_hg_act,
-- which writes nx_hg_state rather than nx_match_moves. A banned caller cannot change that state either.
-- Server-side runs (cron timeouts) have no auth.uid() and pass.
create or replace function public._nx_g_ban_guard_caller()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if _nx_g_banned(auth.uid()) then raise exception 'banned' using errcode = 'P0001'; end if;
  return new;
end $$;
revoke all on function public._nx_g_ban_guard_caller() from public, anon, authenticated;

do $$
begin
  if to_regclass('public.nx_hg_state') is not null then
    drop trigger if exists nx_ban_guard_caller on public.nx_hg_state;
    create trigger nx_ban_guard_caller before insert or update on public.nx_hg_state
      for each row execute function public._nx_g_ban_guard_caller();
  end if;
end $$;
