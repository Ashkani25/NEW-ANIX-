-- P0 #1: account deletion, games project (eyzafhrefnqlwcjpcdyg).
-- _nx_forget_user removes a deleted account's game data: hosted rooms pass to another member (empty ones close),
-- tournaments they organise pass to the platform owner, then the mirror profile row is deleted (cascades stats,
-- results, room memberships, entries, xp events) and rows without a foreign key are removed. The immutable
-- tournament ledger/audit keep the bare uuid for accounting.
-- Caller: nx_bridge_forget_user (service_role only, sent by core nx_delete_account over pg_net). There is deliberately
-- no client-callable variant: a live account could use it to wipe its own ban / wallet mirror.

create or replace function public._nx_forget_user(u uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare r record; nxt uuid; platform_owner uuid; t text;
begin
  if u is null then return jsonb_build_object('ok', false); end if;
  perform set_config('nx.sync', '1', true);
  select user_id into platform_owner from nx_staff where role = 'owner' and user_id <> u limit 1;

  for r in select id from nx_rooms where host = u for update loop
    select s.user_id into nxt from (
      select m.user_id, m.joined_at, (m.role = 'manager') mgr from nx_room_members m where m.room_id = r.id and m.user_id <> u
      union all
      select p.user_id, p.joined_at, false from nx_room_players p where p.room_id = r.id and p.user_id <> u) s
     order by s.mgr desc, s.joined_at limit 1;
    if nxt is null then
      delete from nx_rooms where id = r.id;
    else
      update nx_room_members set role = 'manager' where room_id = r.id and user_id = nxt;
      update nx_rooms set host = nxt, updated_at = now() where id = r.id;
    end if;
  end loop;

  if platform_owner is not null then
    update nx_tournaments set created_by = platform_owner where created_by = u;
  end if;

  foreach t in array array['nx_wallet_tx.user_id', 'nx_cosmetic_owned.user_id', 'nx_cosmetic_equipped.user_id',
                           'nx_match_presence.user_id', 'nx_quiz_answers.user_id', 'nx_quiz_seen.user_id',
                           'nx_user_mutes.user_id', 'nx_invites.from_user', 'nx_invites.to_user', 'nx_staff.user_id',
                           'nx_t_code_attempts.user_id', 'nx_match_reports.user_id', 'nx_match_disputes.user_id',
                           'nx_match_secrets.user_id', 'nx_t_reports.user_id', 'nx_bans.user_id',
                           'nx_user_blocks.blocker', 'nx_user_blocks.blocked'] loop
    if to_regclass('public.' || split_part(t, '.', 1)) is not null then
      execute format('delete from public.%I where %I = $1', split_part(t, '.', 1), split_part(t, '.', 2)) using u;
    end if;
  end loop;

  delete from profiles where id = u;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public._nx_forget_user(uuid) from public, anon, authenticated;

create or replace function public.nx_bridge_forget_user(p_user uuid)
returns jsonb language sql security definer set search_path = public
as $$ select public._nx_forget_user(p_user) $$;
revoke all on function public.nx_bridge_forget_user(uuid) from public, anon, authenticated;
grant execute on function public.nx_bridge_forget_user(uuid) to service_role;
