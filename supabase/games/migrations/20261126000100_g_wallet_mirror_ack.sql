-- ANIX · Economy E1 (games): the games wallet is a mirror of the core ledger.
--
-- Core (eisstodgncimypdawisy) is authoritative: every games-side delta (cosmetics, tournament entry fees, refunds,
-- prizes) is queued in nx_wallet_tx by the profiles trigger, pushed by the nx_wallet_push cron and applied on core
-- through nx_wallet_apply (ledgered, idempotent on the games tx id, shortfalls flagged, never minted).
-- Core then pushes the absolute balances back with tx_upto = the newest games tx it has applied for that user.
--
-- Before this, nx_mirror_put kept the local balance whenever ANY tx was still unacked, and the ack only arrived on the
-- next cron tick, so the authoritative push that answers an apply was usually ignored and a clamped (shortfall)
-- delta left the mirror diverged until the next unrelated core change. Now the push acks every tx <= tx_upto first,
-- so the mirror takes core's balance unless a newer local tx is still in flight (which core will answer again).
create or replace function public.nx_mirror_put(p_rows jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare e jsonb; n int := 0; pend boolean; u uuid;
begin
  perform set_config('nx.sync', '1', true);
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    u := (e ->> 'id')::uuid;
    if (e ->> 'tx_upto') is not null then
      update nx_wallet_tx set acked_at = now()
       where user_id = u and acked_at is null and id <= (e ->> 'tx_upto')::bigint;
    end if;
    select exists (select 1 from nx_wallet_tx where user_id = u and acked_at is null) into pend;
    insert into profiles(id, username, avatar, xp, level, coins, gems, role, synced_at)
    values (u, e ->> 'username', e ->> 'avatar', coalesce((e ->> 'xp')::int, 0), coalesce((e ->> 'level')::int, 1),
            coalesce((e ->> 'coins')::int, 0), coalesce((e ->> 'gems')::int, 0), e ->> 'role', now())
    on conflict (id) do update set
      username = excluded.username, avatar = excluded.avatar, role = excluded.role, synced_at = now(),
      xp = case when pend then profiles.xp else excluded.xp end,
      level = case when pend then profiles.level else excluded.level end,
      coins = case when pend then profiles.coins else excluded.coins end,
      gems = case when pend then profiles.gems else excluded.gems end;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public.nx_mirror_put(jsonb) from public, anon, authenticated;
grant execute on function public.nx_mirror_put(jsonb) to service_role;
