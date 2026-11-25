-- ANIX · Economy E1 (core): one authoritative, append-only coin / gem ledger.
--
-- * public.nx_wallet_ledger: one row per balance change per currency (user, currency, delta, balance_after, reason,
--   ref, idem_key, source, actor, created_at). Rows can never be updated, deleted or truncated.
-- * public.nx_wallet_apply(...): THE function for every grant and spend. It locks the profile row, enforces the
--   balance rule (strict = refuse if it would go below zero; clamp = debit down to zero and report the shortfall),
--   is idempotent on idem_key, and updates profiles.coins / gems. The ledger row is written by an AFTER trigger on
--   profiles in the same transaction, so a balance can never change without its ledger row (atomic).
-- * The same trigger also catches any change made outside nx_wallet_apply (legacy SQL, the SQL editor): it is still
--   ledgered, with source = 'trigger' and reason 'untracked:<calling function>' so nothing is ever silent.
-- * Backfill: one 'opening_balance' row per user per currency from the current balances (taken under a table lock
--   together with the trigger creation, so no change can slip between the snapshot and the trigger).
-- * Shop purchases, gem purchases, daily rewards, welcome gems, awards, admin grants / sets, Bazaar IAP and every
--   games-project delta (cosmetics, tournament entry fees, refunds, prizes arriving over the pg_net bridge) now call
--   nx_wallet_apply. Bridge deltas are idempotent on the games tx id and a shortfall is flagged, never minted.
-- * Bazaar IAP: credit is idempotent on the purchase token (ledger idem 'iap:bazaar:<token>'); refunds
--   (Bazaar purchaseState = 1) debit the pack back through nx_iap_mark_refunded (clamped at zero, the rest flagged).
-- Requires 20261125180000_nx_bazaar_iap.sql.

-- ───────────────────────── tables ─────────────────────────
create table if not exists public.nx_wallet_ledger (
  id            bigserial primary key,
  user_id       uuid not null,                     -- no FK on purpose: the ledger outlives a deleted account
  currency      text not null check (currency in ('coins', 'gems')),
  delta         integer not null,
  balance_after integer not null,
  reason        text not null,
  ref           text,
  idem_key      text,
  source        text not null check (source in ('fn', 'trigger', 'opening')),
  actor         uuid,
  txid          bigint not null default txid_current(),
  created_at    timestamptz not null default now()
);
create index if not exists nx_wallet_ledger_user on public.nx_wallet_ledger(user_id, id desc);
create unique index if not exists nx_wallet_ledger_idem on public.nx_wallet_ledger(idem_key, currency)
  where idem_key is not null;

alter table public.nx_wallet_ledger enable row level security;
drop policy if exists nx_wallet_ledger_own on public.nx_wallet_ledger;
create policy nx_wallet_ledger_own on public.nx_wallet_ledger for select to authenticated using (user_id = auth.uid());
revoke all on public.nx_wallet_ledger from anon, authenticated;
grant select on public.nx_wallet_ledger to authenticated;
revoke all on sequence public.nx_wallet_ledger_id_seq from anon, authenticated;

create or replace function public._nx_wallet_ledger_immutable()
returns trigger language plpgsql set search_path = public as $$
begin
  raise exception 'nx_wallet_ledger is append-only' using errcode = '42501';
end $$;
drop trigger if exists nx_wallet_ledger_no_update on public.nx_wallet_ledger;
create trigger nx_wallet_ledger_no_update before update or delete on public.nx_wallet_ledger
  for each row execute function public._nx_wallet_ledger_immutable();
drop trigger if exists nx_wallet_ledger_no_truncate on public.nx_wallet_ledger;
create trigger nx_wallet_ledger_no_truncate before truncate on public.nx_wallet_ledger
  for each statement execute function public._nx_wallet_ledger_immutable();

-- things a human must look at: a debit the balance could not cover (games shortfall, refunded IAP already spent)
create table if not exists public.nx_wallet_flags (
  id          bigserial primary key,
  user_id     uuid,
  kind        text not null,
  coins       integer not null default 0,
  gems        integer not null default 0,
  ref         text,
  detail      jsonb,
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid,
  unique (kind, ref)
);
create index if not exists nx_wallet_flags_open on public.nx_wallet_flags(created_at desc) where resolved_at is null;
alter table public.nx_wallet_flags enable row level security;
revoke all on public.nx_wallet_flags from anon, authenticated;
revoke all on sequence public.nx_wallet_flags_id_seq from anon, authenticated;

-- ───────────────────────── ledger trigger on profiles ─────────────────────────
create or replace function public._nx_wallet_ledger_row()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  rs text := nullif(current_setting('nx.w_reason', true), '');
  src text := case when rs is null then 'trigger' else 'fn' end;
  rf text := nullif(current_setting('nx.w_ref', true), '');
  ik text := nullif(current_setting('nx.w_idem', true), '');
  ac uuid := nullif(current_setting('nx.w_actor', true), '')::uuid;
  ctx text; caller text;
  oc int := 0; og int := 0; nc int := 0; ng int := 0; uid uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then oc := coalesce(old.coins, 0); og := coalesce(old.gems, 0); uid := old.id; end if;
  if tg_op in ('UPDATE', 'INSERT') then nc := coalesce(new.coins, 0); ng := coalesce(new.gems, 0); uid := new.id; end if;
  if nc = oc and ng = og then return null; end if;
  if rs is null then
    if tg_op = 'INSERT' then rs := 'signup';
    elsif tg_op = 'DELETE' then rs := 'account_deleted';
    else
      get diagnostics ctx = pg_context;
      select m[1] into caller
        from regexp_matches(ctx, 'function (?:[A-Za-z0-9_]+\.)?([A-Za-z0-9_]+)\(', 'g') as m
       where m[1] <> '_nx_wallet_ledger_row' limit 1;
      rs := left(coalesce(nullif(current_setting('nx.reason', true), ''), 'untracked') || ':' || coalesce(caller, 'direct'), 120);
    end if;
    ik := null; rf := null;
  end if;
  if ac is null then ac := auth.uid(); end if;
  if nc <> oc then
    insert into nx_wallet_ledger(user_id, currency, delta, balance_after, reason, ref, idem_key, source, actor)
    values (uid, 'coins', nc - oc, nc, rs, rf, ik, src, ac);
  end if;
  if ng <> og then
    insert into nx_wallet_ledger(user_id, currency, delta, balance_after, reason, ref, idem_key, source, actor)
    values (uid, 'gems', ng - og, ng, rs, rf, ik, src, ac);
  end if;
  return null;
end $$;
revoke all on function public._nx_wallet_ledger_row() from public, anon, authenticated;

-- ───────────────────────── the one wallet function ─────────────────────────
-- p_mode: 'strict' = refuse when a debit would take a balance below zero (shops, fees, admin);
--         'clamp'  = debit down to zero and report the shortfall (refunds, deltas that already happened elsewhere).
create or replace function public.nx_wallet_apply(p_user uuid, p_coins integer, p_gems integer, p_reason text,
                                                  p_ref text default null, p_idem text default null,
                                                  p_mode text default 'strict')
returns jsonb language plpgsql security definer set search_path = public as $$
declare c0 int; g0 int; dc int := coalesce(p_coins, 0); dg int := coalesce(p_gems, 0); sc int := 0; sg int := 0;
        r record;
begin
  if p_user is null or coalesce(p_reason, '') = '' then return jsonb_build_object('ok', false, 'error', 'bad_request'); end if;
  if p_mode not in ('strict', 'clamp') then return jsonb_build_object('ok', false, 'error', 'bad_mode'); end if;
  select coins, coalesce(gems, 0) into c0, g0 from profiles where id = p_user for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'no_profile'); end if;
  if p_idem is not null and exists (select 1 from nx_wallet_ledger where idem_key = p_idem) then
    return jsonb_build_object('ok', true, 'dup', true, 'coins', c0, 'gems', g0, 'applied_coins', 0, 'applied_gems', 0,
                              'short_coins', 0, 'short_gems', 0);
  end if;
  if c0 + dc < 0 then
    if p_mode = 'strict' then
      return jsonb_build_object('ok', false, 'error', 'insufficient_coins', 'coins', c0, 'gems', g0);
    end if;
    sc := -(c0 + dc); dc := -c0;
  end if;
  if g0 + dg < 0 then
    if p_mode = 'strict' then
      return jsonb_build_object('ok', false, 'error', 'insufficient_gems', 'coins', c0, 'gems', g0);
    end if;
    sg := -(g0 + dg); dg := -g0;
  end if;
  if dc = 0 and dg = 0 then
    return jsonb_build_object('ok', true, 'dup', false, 'coins', c0, 'gems', g0, 'applied_coins', 0, 'applied_gems', 0,
                              'short_coins', sc, 'short_gems', sg);
  end if;
  perform set_config('nx.w_reason', left(p_reason, 120), true);
  perform set_config('nx.w_ref', coalesce(left(p_ref, 200), ''), true);
  perform set_config('nx.w_idem', coalesce(left(p_idem, 300), ''), true);
  perform set_config('nx.w_actor', coalesce(auth.uid()::text, ''), true);
  update profiles set coins = coins + dc, gems = coalesce(gems, 0) + dg where id = p_user
    returning coins, gems into r;
  perform set_config('nx.w_reason', '', true);
  perform set_config('nx.w_ref', '', true);
  perform set_config('nx.w_idem', '', true);
  perform set_config('nx.w_actor', '', true);
  return jsonb_build_object('ok', true, 'dup', false, 'coins', r.coins, 'gems', r.gems, 'applied_coins', dc,
                            'applied_gems', dg, 'short_coins', sc, 'short_gems', sg);
end $$;
revoke all on function public.nx_wallet_apply(uuid, integer, integer, text, text, text, text) from public, anon, authenticated;
grant execute on function public.nx_wallet_apply(uuid, integer, integer, text, text, text, text) to service_role;

-- ───────────────────────── trigger + opening balances (atomic) ─────────────────────────
lock table public.profiles in share row exclusive mode;

drop trigger if exists nx_wallet_ledger_upd on public.profiles;
create trigger nx_wallet_ledger_upd after update of coins, gems on public.profiles
  for each row when (old.coins is distinct from new.coins or old.gems is distinct from new.gems)
  execute function public._nx_wallet_ledger_row();
drop trigger if exists nx_wallet_ledger_ins on public.profiles;
create trigger nx_wallet_ledger_ins after insert on public.profiles
  for each row execute function public._nx_wallet_ledger_row();
drop trigger if exists nx_wallet_ledger_del on public.profiles;
create trigger nx_wallet_ledger_del after delete on public.profiles
  for each row execute function public._nx_wallet_ledger_row();

insert into public.nx_wallet_ledger(user_id, currency, delta, balance_after, reason, ref, idem_key, source)
select p.id, c.cur, c.bal, c.bal, 'opening_balance', null, 'opening:' || p.id, 'opening'
  from public.profiles p
  cross join lateral (values ('coins', coalesce(p.coins, 0)), ('gems', coalesce(p.gems, 0))) as c(cur, bal)
on conflict do nothing;

-- ───────────────────────── reads ─────────────────────────
create or replace function public.nx_wallet_history(p_limit integer default 50, p_before bigint default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'currency', l.currency, 'delta', l.delta,
                                               'balance_after', l.balance_after, 'reason', l.reason, 'ref', l.ref,
                                               'created_at', l.created_at) order by l.id desc), '[]'::jsonb)
    from (select * from nx_wallet_ledger
           where user_id = auth.uid() and (p_before is null or id < p_before)
           order by id desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) l
$$;
revoke all on function public.nx_wallet_history(integer, bigint) from public, anon;
grant execute on function public.nx_wallet_history(integer, bigint) to authenticated;

-- every (user, currency) whose ledger does not add up to the live balance. Empty = healthy.
create or replace function public.nx_wallet_audit()
returns table(user_id uuid, currency text, balance integer, ledger_sum bigint, last_balance_after integer)
language sql stable security definer set search_path = public as $$
  with b as (
    select p.id, c.cur, c.bal from profiles p
    cross join lateral (values ('coins', coalesce(p.coins, 0)), ('gems', coalesce(p.gems, 0))) as c(cur, bal)),
  l as (
    select l.user_id, l.currency, sum(l.delta) as s,
           (array_agg(l.balance_after order by l.id desc))[1] as last
      from nx_wallet_ledger l group by 1, 2)
  select b.id, b.cur, b.bal, l.s, l.last
    from b left join l on l.user_id = b.id and l.currency = b.cur
   where l.s is distinct from b.bal::bigint or l.last is distinct from b.bal
$$;
revoke all on function public.nx_wallet_audit() from public, anon, authenticated;
grant execute on function public.nx_wallet_audit() to service_role;

-- ───────────────────────── shop: coins ─────────────────────────
create or replace function public.nx_purchase(p_item text, p_price integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); it nx_catalog; c int; inv jsonb; res jsonb;
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
  res := nx_wallet_apply(me, -it.price, 0, 'shop:coins', p_item, null, 'strict');
  c := (res ->> 'coins')::int;
  if not coalesce((res ->> 'ok')::boolean, false) then
    return jsonb_build_object('ok', false, 'coins', c,
                              'error', case when res ->> 'error' = 'insufficient_coins' then 'insufficient_coins'
                                            else coalesce(res ->> 'error', 'failed') end, 'price', it.price);
  end if;
  update nx_profiles set data = jsonb_set(coalesce(data, '{}'::jsonb), '{inv}', inv || to_jsonb(p_item)), updated_at = now()
   where id = me;
  return jsonb_build_object('ok', true, 'coins', c, 'price', it.price);
end $$;

-- ───────────────────────── shop: gems ─────────────────────────
create or replace function public.nx_buy_with_gems(p_item text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); it nx_catalog; inv jsonb; bal integer; res jsonb;
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
    res := nx_wallet_apply(me, 0, -it.price, 'shop:gems', p_item, null, 'strict');
    bal := (res ->> 'gems')::int;
    if not coalesce((res ->> 'ok')::boolean, false) then
      return jsonb_build_object('ok', false, 'error', case when res ->> 'error' = 'insufficient_gems' then 'insufficient_gems'
                                                           else coalesce(res ->> 'error', 'failed') end,
                                'gems', bal, 'price', it.price);
    end if;
    insert into nx_gem_tx(user_id, delta, balance, reason, item) values (me, -it.price, bal, 'purchase', p_item);
  else
    select coalesce(gems, 0) into bal from profiles where id = me;
  end if;
  update nx_profiles set data = jsonb_set(coalesce(data, '{}'::jsonb), '{inv}', inv || to_jsonb(p_item)), updated_at = now()
   where id = me;
  return jsonb_build_object('ok', true, 'gems', bal, 'price', it.price, 'item', p_item);
end $$;

-- ───────────────────────── daily gems ─────────────────────────
create or replace function public.nx_daily_gems()
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare me uuid := auth.uid(); bal integer; anon boolean; today date := (now() at time zone 'utc')::date; res jsonb;
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
  res := nx_wallet_apply(me, 0, 10, 'daily_gems', today::text, 'daily_gems:' || me || ':' || today, 'strict');
  if not coalesce((res ->> 'ok')::boolean, false) then raise exception 'wallet: %', res ->> 'error'; end if;
  bal := (res ->> 'gems')::int;
  insert into nx_gem_tx(user_id, delta, balance, reason) values (me, 10, bal, 'daily');
  return jsonb_build_object('ok', true, 'granted', 10, 'gems', bal);
end $$;

-- ───────────────────────── wallet read + one-time welcome gems ─────────────────────────
create or replace function public.nx_wallet()
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare me uuid := auth.uid(); r record; anon boolean; res jsonb;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select coalesce(is_anonymous, false) into anon from auth.users where id = me;
  insert into nx_profiles(id) values (me) on conflict (id) do nothing;
  if not coalesce(anon, true) and not nx_is_banned(me)
     and exists (select 1 from nx_profiles where id = me and not gems_welcome) then
    update nx_profiles set gems_welcome = true, updated_at = now() where id = me and not gems_welcome;
    if found then
      res := nx_wallet_apply(me, 0, 200, 'welcome_gems', null, 'welcome_gems:' || me, 'strict');
      if coalesce((res ->> 'ok')::boolean, false) and not coalesce((res ->> 'dup')::boolean, false) then
        insert into nx_gem_tx(user_id, delta, balance, reason) values (me, 200, (res ->> 'gems')::int, 'welcome');
      end if;
    end if;
  end if;
  select xp, coins, coalesce(gems, 0) as gems, level into r from profiles where id = me;
  return jsonb_build_object('ok', true, 'xp', r.xp, 'coins', r.coins, 'gems', r.gems, 'level', r.level);
end $$;

-- ───────────────────────── awards (daily reward, achievements, match rewards) ─────────────────────────
create or replace function public.nx_award(p_event text, p_xp integer, p_coins integer, p_key text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  ev text := left(coalesce(p_event, ''), 120);
  day0 timestamptz := date_trunc('day', now());
  rl nx_reward_rules;
  today_xp int; today_coins int; n int; streak int := 0;
  gx int; gc int;
  r record; res jsonb;
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
  if gc > 0 then
    res := nx_wallet_apply(me, gc, 0, 'award:' || rl.event, ev, 'award:' || me || ':' || p_key, 'strict');
    if not coalesce((res ->> 'ok')::boolean, false) then raise exception 'wallet: %', res ->> 'error'; end if;
  end if;
  if gx > 0 then
    update profiles set xp = xp + gx, level = level_for_xp(xp + gx) where id = me;
  end if;
  if gx > 0 or gc > 0 then
    select p.xp, p.coins into r from profiles p where p.id = me;
  end if;
  if gx > 0 then insert into xp_events(user_id, amount, reason) values (me, gx, 'nexora:' || left(ev, 100)); end if;
  return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', gx, 'granted_coins', gc, 'dup', false,
                            'granted', gx + gc, 'reason', case when gx + gc > 0 then 'ok' else 'daily_cap' end);
end $$;

-- ───────────────────────── admin / owner ─────────────────────────
create or replace function public.nx_admin_grant_wallet(p_user uuid, p_coins integer, p_gems integer, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare g text := _nx_admin_guard('currency'); c int := coalesce(p_coins, 0); gm int := coalesce(p_gems, 0);
        cap int := case when nx_is_owner(auth.uid()) then 10000000 else 100000 end; res jsonb; bc int; bg int;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  if abs(c) > cap or abs(gm) > cap then return jsonb_build_object('ok', false, 'error', 'amount_too_large'); end if;
  if c = 0 and gm = 0 then return jsonb_build_object('ok', false, 'error', 'zero_amount'); end if;
  res := nx_wallet_apply(p_user, c, gm, 'admin_grant:' || left(coalesce(p_reason, ''), 80), null, null, 'strict');
  if not coalesce((res ->> 'ok')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', case when res ->> 'error' = 'no_profile' then 'not_found'
                                                         else 'insufficient_balance' end);
  end if;
  bc := (res ->> 'coins')::int; bg := (res ->> 'gems')::int;
  if gm <> 0 then
    insert into nx_gem_tx(user_id, delta, balance, reason, actor) values (p_user, gm, bg, 'admin:' || left(coalesce(p_reason, ''), 80), auth.uid());
  end if;
  perform _nx_owner_log('grant', p_user, jsonb_build_object('coins', c, 'gems', gm, 'reason', p_reason,
                                                             'balance_coins', bc, 'balance_gems', bg));
  return jsonb_build_object('ok', true, 'coins', bc, 'gems', bg);
end $$;

create or replace function public.nx_owner_grant(p_user uuid, p_coins integer, p_gems integer, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare g text := _nx_admin_guard('currency'); c int := coalesce(p_coins, 0); gm int := coalesce(p_gems, 0); res jsonb;
        bc int; bg int;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  if abs(c) > 10000000 or abs(gm) > 10000000 then return jsonb_build_object('ok', false, 'error', 'amount_too_large'); end if;
  if c = 0 and gm = 0 then return jsonb_build_object('ok', false, 'error', 'zero_amount'); end if;
  res := nx_wallet_apply(p_user, c, gm, 'owner_grant:' || left(coalesce(p_reason, ''), 80), null, null, 'strict');
  if not coalesce((res ->> 'ok')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', case when res ->> 'error' = 'no_profile' then 'not_found'
                                                         else 'insufficient_balance' end);
  end if;
  bc := (res ->> 'coins')::int; bg := (res ->> 'gems')::int;
  perform _nx_owner_log('grant', p_user, jsonb_build_object('coins', c, 'gems', gm, 'reason', p_reason,
                                                             'balance_coins', bc, 'balance_gems', bg));
  return jsonb_build_object('ok', true, 'coins', bc, 'gems', bg);
end $$;

create or replace function public.nx_admin_set_wallet(p_user uuid, p_coins integer default null, p_gems integer default null,
                                                      p_xp integer default null, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare g text := _nx_admin_guard('currency'); old record; r record; res jsonb;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  if coalesce(p_coins, 0) < 0 or coalesce(p_gems, 0) < 0 or coalesce(p_xp, 0) < 0
     or coalesce(p_coins, 0) > 100000000 or coalesce(p_gems, 0) > 100000000 or coalesce(p_xp, 0) > 100000000 then
    return jsonb_build_object('ok', false, 'error', 'bad_amount'); end if;
  if nx_is_owner(p_user) and not nx_is_owner(auth.uid()) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  select coins, coalesce(gems, 0) as gems, xp into old from profiles where id = p_user for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  res := nx_wallet_apply(p_user, coalesce(p_coins, old.coins) - old.coins, coalesce(p_gems, old.gems) - old.gems,
                         'admin_set:' || left(coalesce(p_reason, ''), 80), null, null, 'strict');
  if not coalesce((res ->> 'ok')::boolean, false) then return jsonb_build_object('ok', false, 'error', res ->> 'error'); end if;
  if p_xp is not null then
    update profiles set xp = p_xp, level = level_for_xp(p_xp) where id = p_user;
  end if;
  select coins, gems, xp, level into r from profiles where id = p_user;
  if r.gems <> old.gems then
    insert into nx_gem_tx(user_id, delta, balance, reason, actor) values (p_user, r.gems - old.gems, r.gems, 'admin_set', auth.uid());
  end if;
  perform _nx_owner_log('set_wallet', p_user, jsonb_build_object('from', to_jsonb(old), 'coins', r.coins, 'gems', r.gems,
                                                                  'xp', r.xp, 'reason', p_reason));
  return jsonb_build_object('ok', true, 'coins', r.coins, 'gems', r.gems, 'xp', r.xp, 'level', r.level);
end $$;

-- ───────────────────────── games bridge (cosmetics, entry fees, refunds, prizes) ─────────────────────────
create index if not exists nx_bridge_applied_user on public.nx_bridge_applied(user_id, tx_id desc);

-- Games deltas already happened on the mirror, so they are applied in clamp mode: a debit the core balance cannot
-- cover is taken down to zero and flagged (never minted, never negative). Idempotent on the games tx id twice over
-- (nx_bridge_applied + ledger idem 'games_tx:<id>'). The push back carries tx_upto so the mirror can converge.
create or replace function public.nx_bridge_apply_batch(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare e jsonb; n int := 0; users uuid[] := '{}'; u uuid; tid bigint; dx int; res jsonb;
begin
  perform set_config('nx.bridge', '1', true);
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) order by (value ->> 'id')::bigint loop
    u := (e ->> 'user_id')::uuid;
    tid := (e ->> 'id')::bigint;
    insert into nx_bridge_applied(tx_id, user_id, xp, coins, gems, reason)
    values (tid, u, coalesce((e ->> 'xp')::int, 0), coalesce((e ->> 'coins')::int, 0),
            coalesce((e ->> 'gems')::int, 0), left(e ->> 'reason', 80))
    on conflict (tx_id) do nothing;
    if found then
      res := nx_wallet_apply(u, coalesce((e ->> 'coins')::int, 0), coalesce((e ->> 'gems')::int, 0),
                             left('games:' || coalesce(nullif(e ->> 'reason', ''), 'games'), 120), 'games_tx:' || tid,
                             'games_tx:' || tid, 'clamp');
      if coalesce((res ->> 'short_coins')::int, 0) > 0 or coalesce((res ->> 'short_gems')::int, 0) > 0 then
        insert into nx_wallet_flags(user_id, kind, coins, gems, ref, detail)
        values (u, 'games_shortfall', (res ->> 'short_coins')::int, (res ->> 'short_gems')::int, 'games_tx:' || tid, e)
        on conflict (kind, ref) do nothing;
      end if;
      dx := coalesce((e ->> 'xp')::int, 0);
      if dx <> 0 then
        update profiles set xp = greatest(0, xp + dx), level = level_for_xp(greatest(0, xp + dx)) where id = u;
      end if;
      n := n + 1;
    end if;
    if not (u = any(users)) then users := users || u; end if;
  end loop;
  perform nx_bridge_push(users);
  return jsonb_build_object('applied', n);
end $$;

-- the mirror push now also says up to which games tx it already includes (games acks those and overwrites)
create or replace function public.nx_bridge_push(p_users uuid[])
returns void language plpgsql security definer set search_path = public as $$
declare url text := _nx_vault('nx_games_url'); key text := _nx_vault('nx_games_service_key'); rows jsonb;
begin
  if url is null or key is null or coalesce(array_length(p_users, 1), 0) = 0 then return; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'username', p.username, 'avatar', coalesce(p.avatar_url, p.avatar),
           'xp', p.xp, 'level', p.level, 'coins', p.coins, 'gems', p.gems, 'role', p.role,
           'tx_upto', (select max(b.tx_id) from nx_bridge_applied b where b.user_id = p.id))), '[]'::jsonb)
    into rows from profiles p where p.id = any(p_users);
  if jsonb_array_length(rows) = 0 then return; end if;
  perform net.http_post(url := url || '/rest/v1/rpc/nx_mirror_put',
                        headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', key, 'Authorization', 'Bearer ' || key),
                        body := jsonb_build_object('p_rows', rows), timeout_milliseconds := 8000);
end $$;

-- ───────────────────────── Bazaar IAP ─────────────────────────
alter table public.nx_iap_purchases
  add column if not exists status text not null default 'credited',
  add column if not exists checked_at timestamptz,
  add column if not exists check_count integer not null default 0,
  add column if not exists last_state integer,
  add column if not exists refunded_at timestamptz,
  add column if not exists refund_debited_coins integer not null default 0,
  add column if not exists refund_debited_gems integer not null default 0,
  add column if not exists refund_raw jsonb;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'nx_iap_purchases_status_chk') then
    alter table public.nx_iap_purchases add constraint nx_iap_purchases_status_chk check (status in ('credited', 'refunded'));
  end if;
end $$;
create index if not exists nx_iap_purchases_recheck on public.nx_iap_purchases(checked_at nulls first) where status = 'credited';

-- Credits one verified store purchase (service_role, called by nx-bazaar-verify). Idempotent on the token.
create or replace function public.nx_iap_credit(p_user uuid, p_store text, p_sku text, p_token text,
                                                p_order text default null, p_purchase_time timestamptz default null,
                                                p_raw jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pr nx_iap_products; pid bigint; pu nx_iap_purchases; r record; st text := coalesce(p_store, 'bazaar'); res jsonb;
begin
  if p_user is null or coalesce(p_token, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'bad_request');
  end if;
  select * into pr from nx_iap_products where sku = p_sku;
  if pr.sku is null then return jsonb_build_object('ok', false, 'error', 'unknown_sku'); end if;

  insert into nx_iap_purchases(user_id, store, sku, purchase_token, order_id, coins, gems, price_toman,
                               purchase_time, raw, checked_at, check_count, last_state)
  values (p_user, st, pr.sku, p_token, p_order, pr.coins, pr.gems, pr.price_toman, p_purchase_time, p_raw, now(), 1, 0)
  on conflict (store, purchase_token) do nothing
  returning id into pid;

  if pid is null then
    select * into pu from nx_iap_purchases where store = st and purchase_token = p_token;
    select xp, coins, coalesce(gems, 0) as gems into r from profiles where id = p_user;
    return jsonb_build_object('ok', pu.user_id = p_user, 'dup', true,
                              'error', case when pu.user_id <> p_user then 'token_used' end,
                              'refunded', pu.status = 'refunded', 'coins', r.coins, 'gems', r.gems, 'xp', r.xp);
  end if;

  res := nx_wallet_apply(p_user, pr.coins, pr.gems, 'iap:' || st, pr.sku, 'iap:' || st || ':' || p_token, 'strict');
  if not coalesce((res ->> 'ok')::boolean, false) then
    raise exception 'iap credit: %', res ->> 'error';  -- rolls back the purchase row; the app retries
  end if;
  if pr.gems > 0 then
    insert into nx_gem_tx(user_id, delta, balance, reason, item) values (p_user, pr.gems, (res ->> 'gems')::int, 'iap', pr.sku);
  end if;
  select xp, coins, coalesce(gems, 0) as gems into r from profiles where id = p_user;
  return jsonb_build_object('ok', true, 'dup', false, 'sku', pr.sku, 'granted_coins', pr.coins,
                            'granted_gems', pr.gems, 'coins', r.coins, 'gems', r.gems, 'xp', r.xp);
end $$;
revoke all on function public.nx_iap_credit(uuid, text, text, text, text, timestamptz, jsonb) from public, anon, authenticated;
grant execute on function public.nx_iap_credit(uuid, text, text, text, text, timestamptz, jsonb) to service_role;

-- A purchase the store reports as refunded (Bazaar purchaseState = 1): take the pack back. Whatever the player
-- already spent cannot be taken below zero; that part is recorded in nx_wallet_flags ('iap_refund_shortfall').
-- Idempotent: a token already marked refunded changes nothing.
create or replace function public.nx_iap_mark_refunded(p_store text, p_token text, p_raw jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pu nx_iap_purchases; st text := coalesce(p_store, 'bazaar'); res jsonb; dc int := 0; dg int := 0;
        sc int; sg int;
begin
  select * into pu from nx_iap_purchases where store = st and purchase_token = p_token for update;
  if pu.id is null then return jsonb_build_object('ok', false, 'error', 'unknown_token'); end if;
  if pu.status = 'refunded' then return jsonb_build_object('ok', true, 'dup', true, 'user_id', pu.user_id); end if;
  res := nx_wallet_apply(pu.user_id, -pu.coins, -pu.gems, 'iap_refund:' || st, pu.sku, 'iap_refund:' || st || ':' || p_token, 'clamp');
  if coalesce((res ->> 'ok')::boolean, false) then
    dc := -coalesce((res ->> 'applied_coins')::int, 0); dg := -coalesce((res ->> 'applied_gems')::int, 0);
  end if;
  sc := pu.coins - dc; sg := pu.gems - dg;
  update nx_iap_purchases set status = 'refunded', refunded_at = now(), refund_debited_coins = dc,
         refund_debited_gems = dg, refund_raw = p_raw, last_state = 1, checked_at = now(), check_count = check_count + 1
   where id = pu.id;
  if dg > 0 then
    insert into nx_gem_tx(user_id, delta, balance, reason, item) values (pu.user_id, -dg, (res ->> 'gems')::int, 'iap_refund', pu.sku);
  end if;
  if sc > 0 or sg > 0 then
    insert into nx_wallet_flags(user_id, kind, coins, gems, ref, detail)
    values (pu.user_id, 'iap_refund_shortfall', sc, sg, 'iap:' || st || ':' || p_token,
            jsonb_build_object('sku', pu.sku, 'purchase_id', pu.id, 'wallet', res))
    on conflict (kind, ref) do nothing;
  end if;
  return jsonb_build_object('ok', true, 'dup', false, 'user_id', pu.user_id, 'debited_coins', dc, 'debited_gems', dg,
                            'short_coins', sc, 'short_gems', sg);
end $$;
revoke all on function public.nx_iap_mark_refunded(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.nx_iap_mark_refunded(text, text, jsonb) to service_role;

-- purchases the recheck job (Edge Function nx-bazaar-recheck) should ask the store about again
create or replace function public.nx_iap_recheck_due(p_limit integer default 50, p_window_days integer default 45,
                                                     p_every_hours integer default 12)
returns table(id bigint, store text, sku text, purchase_token text)
language sql stable security definer set search_path = public as $$
  select p.id, p.store, p.sku, p.purchase_token from nx_iap_purchases p
   where p.status = 'credited'
     and p.created_at > now() - make_interval(days => greatest(coalesce(p_window_days, 45), 1))
     and (p.checked_at is null or p.checked_at < now() - make_interval(hours => greatest(coalesce(p_every_hours, 12), 1)))
   order by p.checked_at nulls first, p.id
   limit least(greatest(coalesce(p_limit, 50), 1), 500)
$$;
revoke all on function public.nx_iap_recheck_due(integer, integer, integer) from public, anon, authenticated;
grant execute on function public.nx_iap_recheck_due(integer, integer, integer) to service_role;

create or replace function public.nx_iap_mark_checked(p_id bigint, p_state integer default null)
returns void language sql security definer set search_path = public as $$
  update nx_iap_purchases set checked_at = now(), check_count = check_count + 1, last_state = coalesce(p_state, last_state)
   where id = p_id
$$;
revoke all on function public.nx_iap_mark_checked(bigint, integer) from public, anon, authenticated;
grant execute on function public.nx_iap_mark_checked(bigint, integer) to service_role;
