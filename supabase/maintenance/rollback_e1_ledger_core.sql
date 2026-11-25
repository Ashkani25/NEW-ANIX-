-- Rollback for 20261126000000_economy_ledger.sql (core, eisstodgncimypdawisy).
-- Snapshot of the function bodies taken live on 2026-11-25 ~23:00 Asia/Tehran, BEFORE the ledger migration.
-- Balances are never touched. The ledger / flags tables and the new nx_iap_purchases columns are KEPT (they are a
-- financial record); drop them by hand only if you really mean to (statements at the bottom, commented out).
begin;
drop trigger if exists nx_wallet_ledger_upd on public.profiles;
drop trigger if exists nx_wallet_ledger_ins on public.profiles;
drop trigger if exists nx_wallet_ledger_del on public.profiles;

CREATE OR REPLACE FUNCTION public.nx_purchase(p_item text, p_price integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); it nx_catalog; c int; inv jsonb;
begin
  if me is null then raise exception 'not signed in'; end if;
  perform set_config('nx.trusted', '1', true);
  if nx_is_banned(me) then
    select coins into c from profiles where id = me;
    return jsonb_build_object('ok', false, 'coins', c, 'error', 'banned');
  end if;
  select * into it from nx_catalog where item_id = p_item;
  if it.item_id is null or not coalesce(it.active, true) or coalesce(it.currency, 'coins') <> 'coins'
     or p_item like 'fs_team:%' or it.price is null or it.price < 0 then
    select coins into c from profiles where id = me;
    return jsonb_build_object('ok', false, 'coins', c, 'error', 'not_for_sale');
  end if;
  insert into nx_profiles(id) values (me) on conflict (id) do nothing;
  select coalesce(data -> 'inv', '[]'::jsonb) into inv from nx_profiles where id = me for update;
  if jsonb_typeof(inv) <> 'array' then inv := '[]'::jsonb; end if;
  if inv ? p_item then
    select coins into c from profiles where id = me;
    return jsonb_build_object('ok', true, 'coins', c, 'owned', true);
  end if;
  update profiles set coins = coins - it.price where id = me and coins >= it.price returning coins into c;
  if c is null then
    select coins into c from profiles where id = me;
    return jsonb_build_object('ok', false, 'coins', c, 'error', 'insufficient_coins', 'price', it.price);
  end if;
  update nx_profiles set data = jsonb_set(coalesce(data, '{}'::jsonb), '{inv}', inv || to_jsonb(p_item)), updated_at = now()
   where id = me;
  return jsonb_build_object('ok', true, 'coins', c, 'price', it.price);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_buy_with_gems(p_item text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); it nx_catalog; inv jsonb; bal integer;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  if nx_is_banned(me) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  select * into it from nx_catalog where item_id = p_item;
  if it.item_id is null or it.currency <> 'gems' or not it.active then
    select coalesce(gems, 0) into bal from profiles where id = me;
    return jsonb_build_object('ok', false, 'error', 'not_for_sale', 'gems', bal);
  end if;
  insert into nx_profiles(id) values (me) on conflict (id) do nothing;
  select coalesce(data -> 'inv', '[]'::jsonb) into inv from nx_profiles where id = me for update;
  if inv ? p_item then
    select coalesce(gems, 0) into bal from profiles where id = me;
    return jsonb_build_object('ok', true, 'owned', true, 'gems', bal);
  end if;
  -- the owner of a shared custom team fields it free: grant, never charge
  if p_item like 'fs\_team:cx\_%' and exists (
      select 1 from fs_custom_teams where 'fs_team:' || team_id = p_item and owner_id = me) then
    update nx_profiles set data = jsonb_set(coalesce(data, '{}'::jsonb), '{inv}', inv || to_jsonb(p_item)), updated_at = now()
     where id = me;
    select coalesce(gems, 0) into bal from profiles where id = me;
    return jsonb_build_object('ok', true, 'owned', true, 'own_team', true, 'gems', bal, 'price', 0, 'item', p_item);
  end if;
  if it.price > 0 then
    update profiles set gems = gems - it.price where id = me and coalesce(gems, 0) >= it.price returning gems into bal;
    if bal is null then
      select coalesce(gems, 0) into bal from profiles where id = me;
      return jsonb_build_object('ok', false, 'error', 'insufficient_gems', 'gems', bal, 'price', it.price);
    end if;
    insert into nx_gem_tx(user_id, delta, balance, reason, item) values (me, -it.price, bal, 'purchase', p_item);
  else
    select coalesce(gems, 0) into bal from profiles where id = me;
  end if;
  update nx_profiles set data = jsonb_set(coalesce(data, '{}'::jsonb), '{inv}', inv || to_jsonb(p_item)), updated_at = now()
   where id = me;
  return jsonb_build_object('ok', true, 'gems', bal, 'price', it.price, 'item', p_item);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_daily_gems()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare me uuid := auth.uid(); bal integer; anon boolean; today date := (now() at time zone 'utc')::date;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  if nx_is_banned(me) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  select coalesce(is_anonymous, false) into anon from auth.users where id = me;
  if coalesce(anon, true) then return jsonb_build_object('ok', false, 'error', 'account_required'); end if;
  insert into nx_profiles(id) values (me) on conflict (id) do nothing;
  update nx_profiles set gems_daily = today, updated_at = now()
   where id = me and (gems_daily is null or gems_daily < today);
  if not found then
    select coalesce(gems, 0) into bal from profiles where id = me;
    return jsonb_build_object('ok', true, 'granted', 0, 'gems', bal, 'already', true);
  end if;
  update profiles set gems = coalesce(gems, 0) + 10 where id = me returning gems into bal;
  insert into nx_gem_tx(user_id, delta, balance, reason) values (me, 10, bal, 'daily');
  return jsonb_build_object('ok', true, 'granted', 10, 'gems', bal);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_wallet()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare me uuid := auth.uid(); r record; anon boolean;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select coalesce(is_anonymous, false) into anon from auth.users where id = me;
  insert into nx_profiles(id) values (me) on conflict (id) do nothing;
  if not coalesce(anon, true) and not nx_is_banned(me)
     and exists (select 1 from nx_profiles where id = me and not gems_welcome) then
    update nx_profiles set gems_welcome = true, updated_at = now() where id = me and not gems_welcome;
    if found then
      update profiles set gems = coalesce(gems, 0) + 200 where id = me returning gems into r;
      if r.gems is not null then
        insert into nx_gem_tx(user_id, delta, balance, reason) values (me, 200, r.gems, 'welcome');
      end if;
    end if;
  end if;
  select xp, coins, coalesce(gems, 0) as gems, level into r from profiles where id = me;
  return jsonb_build_object('ok', true, 'xp', r.xp, 'coins', r.coins, 'gems', r.gems, 'level', r.level);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_award(p_event text, p_xp integer, p_coins integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  ev text := left(coalesce(p_event, ''), 120);
  day0 timestamptz := date_trunc('day', now());
  rl nx_reward_rules;
  today_xp int; today_coins int; n int; streak int := 0;
  gx int; gc int;
  r record;
begin
  if me is null then raise exception 'not signed in'; end if;
  if p_key is null or length(p_key) < 4 then raise exception 'bad key'; end if;
  -- serialize a user's awards: parallel calls could each pass the per-rule / daily caps before any insert landed
  perform pg_advisory_xact_lock(hashtextextended('nx_award:' || me::text, 0));
  if length(p_key) > 200 then raise exception 'bad key'; end if;
  perform set_config('nx.trusted', '1', true);
  select p.xp, p.coins into r from profiles p where p.id = me;
  if exists (select 1 from nx_xp_events x where x.user_id = me and x.idem_key = p_key) then
    return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', true,
                              'granted', 0, 'reason', 'duplicate');
  end if;
  if nx_is_banned(me) then
    return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                              'granted', 0, 'reason', 'banned');
  end if;
  if ev !~ '^[A-Za-z0-9_.:-]{1,120}$' then
    rl := null;
  else
    select * into rl from nx_reward_rules
     where coalesce(nx_reward_rules.active, true)
       and ((not nx_reward_rules.is_pattern and nx_reward_rules.event = ev)
            or (nx_reward_rules.is_pattern and ev like nx_reward_rules.event))
     order by nx_reward_rules.is_pattern, length(nx_reward_rules.event) desc
     limit 1;
  end if;
  if rl.event is null then
    return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                              'granted', 0, 'reason', 'unknown_event');
  end if;

  -- per-rule caps
  if rl.daily_cap is not null then
    select count(*) into n from nx_xp_events x where x.user_id = me and x.rule = rl.event and x.created_at >= day0;
    if n >= rl.daily_cap then
      return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                                'granted', 0, 'reason', 'rule_daily_cap');
    end if;
  end if;
  if rl.weekly_cap is not null then
    select count(*) into n from nx_xp_events x where x.user_id = me and x.rule = rl.event
       and x.created_at >= date_trunc('week', now());
    if n >= rl.weekly_cap then
      return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                                'granted', 0, 'reason', 'rule_weekly_cap');
    end if;
  end if;
  if rl.lifetime_cap is not null then
    select count(*) into n from nx_xp_events x where x.user_id = me and x.rule = rl.event;
    if n >= rl.lifetime_cap then
      return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                                'granted', 0, 'reason', 'rule_lifetime_cap');
    end if;
  end if;

  gx := greatest(0, rl.xp);
  gc := greatest(0, rl.coins);
  -- daily reward: streak bonus computed from the server's own history (+10 per consecutive day, max 7)
  if rl.event = 'daily' then
    streak := 1;
    while streak < 7 and exists (
      select 1 from nx_xp_events x
       where x.user_id = me and x.rule = 'daily'
         and x.created_at >= day0 - make_interval(days => streak)
         and x.created_at <  day0 - make_interval(days => streak - 1)) loop
      streak := streak + 1;
    end loop;
    gc := gc + least(streak, 7) * 10;
  end if;

  -- global daily caps (3000 XP, 1500 coins), achievements excluded
  if rl.counts_to_cap then
    select coalesce(sum(e.xp), 0), coalesce(sum(e.coins), 0) into today_xp, today_coins
      from nx_xp_events e
      left join nx_reward_rules rr on rr.event = e.rule
     where e.user_id = me and e.created_at >= day0 and coalesce(rr.counts_to_cap, true);
    gx := greatest(0, least(gx, 3000 - today_xp));
    gc := greatest(0, least(gc, 1500 - today_coins));
  end if;

  insert into nx_xp_events(user_id, idem_key, event, xp, coins, rule) values (me, p_key, ev, gx, gc, rl.event);
  if gx > 0 or gc > 0 then
    update profiles set xp = xp + gx, coins = coins + gc, level = level_for_xp(xp + gx) where id = me
      returning xp, coins into r;
  end if;
  if gx > 0 then insert into xp_events(user_id, amount, reason) values (me, gx, 'nexora:' || left(ev, 100)); end if;
  return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', gx, 'granted_coins', gc, 'dup', false,
                            'granted', gx + gc, 'reason', case when gx + gc > 0 then 'ok' else 'daily_cap' end);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_admin_grant_wallet(p_user uuid, p_coins integer, p_gems integer, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g text := _nx_admin_guard('currency'); c int := coalesce(p_coins, 0); gm int := coalesce(p_gems, 0);
        cap int := case when nx_is_owner(auth.uid()) then 10000000 else 100000 end; r record;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  if abs(c) > cap or abs(gm) > cap then return jsonb_build_object('ok', false, 'error', 'amount_too_large'); end if;
  if c = 0 and gm = 0 then return jsonb_build_object('ok', false, 'error', 'zero_amount'); end if;
  update profiles set coins = coins + c, gems = coalesce(gems, 0) + gm
   where id = p_user and coins + c >= 0 and coalesce(gems, 0) + gm >= 0 returning coins, gems into r;
  if not found then
    if not exists (select 1 from profiles where id = p_user) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
    return jsonb_build_object('ok', false, 'error', 'insufficient_balance');
  end if;
  if gm <> 0 then
    insert into nx_gem_tx(user_id, delta, balance, reason, actor) values (p_user, gm, r.gems, 'admin:' || left(coalesce(p_reason, ''), 80), auth.uid());
  end if;
  perform _nx_owner_log('grant', p_user, jsonb_build_object('coins', c, 'gems', gm, 'reason', p_reason,
                                                             'balance_coins', r.coins, 'balance_gems', r.gems));
  return jsonb_build_object('ok', true, 'coins', r.coins, 'gems', r.gems);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_owner_grant(p_user uuid, p_coins integer, p_gems integer, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g text := _nx_admin_guard('currency'); c int := coalesce(p_coins, 0); gm int := coalesce(p_gems, 0); r record;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  if abs(c) > 10000000 or abs(gm) > 10000000 then return jsonb_build_object('ok', false, 'error', 'amount_too_large'); end if;
  if c = 0 and gm = 0 then return jsonb_build_object('ok', false, 'error', 'zero_amount'); end if;
  update profiles set coins = coins + c, gems = coalesce(gems, 0) + gm
   where id = p_user and coins + c >= 0 and coalesce(gems, 0) + gm >= 0 returning coins, gems into r;
  if not found then
    if not exists (select 1 from profiles where id = p_user) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
    return jsonb_build_object('ok', false, 'error', 'insufficient_balance');
  end if;
  perform _nx_owner_log('grant', p_user, jsonb_build_object('coins', c, 'gems', gm, 'reason', p_reason,
                                                             'balance_coins', r.coins, 'balance_gems', r.gems));
  return jsonb_build_object('ok', true, 'coins', r.coins, 'gems', r.gems);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_admin_set_wallet(p_user uuid, p_coins integer DEFAULT NULL::integer, p_gems integer DEFAULT NULL::integer, p_xp integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g text := _nx_admin_guard('currency'); old record; r record;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  if coalesce(p_coins, 0) < 0 or coalesce(p_gems, 0) < 0 or coalesce(p_xp, 0) < 0
     or coalesce(p_coins, 0) > 100000000 or coalesce(p_gems, 0) > 100000000 or coalesce(p_xp, 0) > 100000000 then
    return jsonb_build_object('ok', false, 'error', 'bad_amount'); end if;
  if nx_is_owner(p_user) and not nx_is_owner(auth.uid()) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  select coins, coalesce(gems, 0) as gems, xp into old from profiles where id = p_user for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  update profiles set coins = coalesce(p_coins, coins), gems = coalesce(p_gems, gems), xp = coalesce(p_xp, xp),
         level = level_for_xp(coalesce(p_xp, xp))
   where id = p_user returning coins, gems, xp, level into r;
  if r.gems <> old.gems then
    insert into nx_gem_tx(user_id, delta, balance, reason, actor) values (p_user, r.gems - old.gems, r.gems, 'admin_set', auth.uid());
  end if;
  perform _nx_owner_log('set_wallet', p_user, jsonb_build_object('from', to_jsonb(old), 'coins', r.coins, 'gems', r.gems,
                                                                  'xp', r.xp, 'reason', p_reason));
  return jsonb_build_object('ok', true, 'coins', r.coins, 'gems', r.gems, 'xp', r.xp, 'level', r.level);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_bridge_apply_batch(p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare e jsonb; n int := 0; users uuid[] := '{}'; u uuid;
begin
  perform set_config('nx.bridge', '1', true);
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    u := (e ->> 'user_id')::uuid;
    insert into nx_bridge_applied(tx_id, user_id, xp, coins, gems, reason)
    values ((e ->> 'id')::bigint, u, coalesce((e ->> 'xp')::int, 0), coalesce((e ->> 'coins')::int, 0),
            coalesce((e ->> 'gems')::int, 0), left(e ->> 'reason', 80))
    on conflict (tx_id) do nothing;
    if found then
      update profiles set xp = greatest(0, xp + coalesce((e ->> 'xp')::int, 0)),
                          coins = greatest(0, coins + coalesce((e ->> 'coins')::int, 0)),
                          gems = greatest(0, gems + coalesce((e ->> 'gems')::int, 0))
       where id = u;
      update profiles set level = level_for_xp(xp) where id = u;
      n := n + 1;
    end if;
    if not (u = any(users)) then users := users || u; end if;
  end loop;
  perform nx_bridge_push(users);
  return jsonb_build_object('applied', n);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_bridge_push(p_users uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare url text := _nx_vault('nx_games_url'); key text := _nx_vault('nx_games_service_key'); rows jsonb;
begin
  if url is null or key is null or coalesce(array_length(p_users, 1), 0) = 0 then return; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'username', p.username, 'avatar', coalesce(p.avatar_url, p.avatar),
           'xp', p.xp, 'level', p.level, 'coins', p.coins, 'gems', p.gems, 'role', p.role)), '[]'::jsonb)
    into rows from profiles p where p.id = any(p_users);
  if jsonb_array_length(rows) = 0 then return; end if;
  perform net.http_post(url := url || '/rest/v1/rpc/nx_mirror_put',
                        headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', key, 'Authorization', 'Bearer ' || key),
                        body := jsonb_build_object('p_rows', rows), timeout_milliseconds := 8000);
end $function$;

-- nx_iap_credit as shipped in 20261125180000_nx_bazaar_iap.sql
create or replace function public.nx_iap_credit(p_user uuid, p_store text, p_sku text, p_token text,
                                                p_order text default null, p_purchase_time timestamptz default null,
                                                p_raw jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pr nx_iap_products; pid bigint; owner uuid; r record;
begin
  if p_user is null or coalesce(p_token, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'bad_request');
  end if;
  select * into pr from nx_iap_products where sku = p_sku;
  if pr.sku is null then return jsonb_build_object('ok', false, 'error', 'unknown_sku'); end if;

  perform set_config('nx.trusted', '1', true);
  insert into nx_iap_purchases(user_id, store, sku, purchase_token, order_id, coins, gems, price_toman,
                               purchase_time, raw)
  values (p_user, coalesce(p_store, 'bazaar'), pr.sku, p_token, p_order, pr.coins, pr.gems, pr.price_toman,
          p_purchase_time, p_raw)
  on conflict (store, purchase_token) do nothing
  returning id into pid;

  if pid is null then
    select user_id into owner from nx_iap_purchases where store = coalesce(p_store, 'bazaar') and purchase_token = p_token;
    select xp, coins, coalesce(gems, 0) as gems into r from profiles where id = p_user;
    return jsonb_build_object('ok', owner = p_user, 'dup', true, 'error', case when owner <> p_user then 'token_used' end,
                              'coins', r.coins, 'gems', r.gems, 'xp', r.xp);
  end if;

  update profiles set coins = coins + pr.coins, gems = coalesce(gems, 0) + pr.gems where id = p_user
    returning xp, coins, gems into r;
  if not found then raise exception 'profile_missing'; end if;  -- rolls back the purchase row; client retries
  if pr.gems > 0 then
    insert into nx_gem_tx(user_id, delta, balance, reason, item) values (p_user, pr.gems, r.gems, 'iap', pr.sku);
  end if;
  return jsonb_build_object('ok', true, 'dup', false, 'sku', pr.sku, 'granted_coins', pr.coins,
                            'granted_gems', pr.gems, 'coins', r.coins, 'gems', r.gems, 'xp', r.xp);
end $$;
revoke all on function public.nx_iap_credit(uuid, text, text, text, text, timestamptz, jsonb) from public, anon, authenticated;
grant execute on function public.nx_iap_credit(uuid, text, text, text, text, timestamptz, jsonb) to service_role;

drop function if exists public.nx_iap_mark_refunded(text, text, jsonb);
drop function if exists public.nx_iap_recheck_due(integer, integer, integer);
drop function if exists public.nx_iap_mark_checked(bigint, integer);
drop function if exists public.nx_wallet_history(integer, bigint);
drop function if exists public.nx_wallet_audit();
drop function if exists public.nx_wallet_apply(uuid, integer, integer, text, text, text, text);
drop function if exists public._nx_wallet_ledger_row();
commit;

-- Only if the ledger must really go (loses the transaction history, never balances):
-- drop table if exists public.nx_wallet_ledger; drop function if exists public._nx_wallet_ledger_immutable();
-- drop table if exists public.nx_wallet_flags;
-- alter table public.nx_iap_purchases drop constraint if exists nx_iap_purchases_status_chk,
--   drop column if exists status, drop column if exists checked_at, drop column if exists check_count,
--   drop column if exists last_state, drop column if exists refunded_at, drop column if exists refund_debited_coins,
--   drop column if exists refund_debited_gems, drop column if exists refund_raw;
