-- Rollback for supabase/games/migrations/20261126000100_g_wallet_mirror_ack.sql (games, eyzafhrefnqlwcjpcdyg).
-- Restores nx_mirror_put as it was live on 2026-11-25 ~23:00 Asia/Tehran. Balances are not touched.
begin;
CREATE OR REPLACE FUNCTION public.nx_mirror_put(p_rows jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare e jsonb; n int := 0; pend boolean;
begin
  perform set_config('nx.sync', '1', true);
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    select exists (select 1 from nx_wallet_tx where user_id = (e ->> 'id')::uuid and acked_at is null) into pend;
    insert into profiles(id, username, avatar, xp, level, coins, gems, role, synced_at)
    values ((e ->> 'id')::uuid, e ->> 'username', e ->> 'avatar', coalesce((e ->> 'xp')::int, 0), coalesce((e ->> 'level')::int, 1),
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
end $function$
;
commit;
