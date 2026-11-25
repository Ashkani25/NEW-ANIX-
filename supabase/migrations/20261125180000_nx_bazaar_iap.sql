-- ANIX · Cafe Bazaar in-app purchases (coin & gem packs paid in rials).
--
-- Flow: app buys a pack with Poolakey (payload = auth uid) -> Edge Function nx-bazaar-verify checks the purchase
-- token with Bazaar's server API (header CAFEBAZAAR-PISHKHAN-API-SECRET) -> calls nx_iap_credit as service_role ->
-- the app consumes the token. The token is unique, so the same purchase can never be credited twice or to two users.
-- Clients can read the active pack list and their own purchases; nothing else.

create table if not exists public.nx_iap_products (
  sku         text primary key,               -- product id defined in Bazaar's panel (exactly the same string)
  coins       integer not null default 0 check (coins >= 0),
  gems        integer not null default 0 check (gems >= 0),
  price_toman integer not null check (price_toman > 0), -- display only; Bazaar charges the price set in its panel
  title_fa    text not null,
  title_en    text not null,
  badge_fa    text,
  sort        integer not null default 0,
  active      boolean not null default true,
  updated_at  timestamptz not null default now(),
  check (coins > 0 or gems > 0)
);

alter table public.nx_iap_products enable row level security;
drop policy if exists nx_iap_products_read on public.nx_iap_products;
create policy nx_iap_products_read on public.nx_iap_products for select to anon, authenticated using (active);
revoke all on public.nx_iap_products from anon, authenticated;
grant select on public.nx_iap_products to anon, authenticated;

insert into public.nx_iap_products(sku, coins, gems, price_toman, title_fa, title_en, badge_fa, sort) values
  ('anix_coins_500',  500,    0, 100000, '۵۰۰ سکه',    '500 coins',   null,          10),
  ('anix_gems_100',     0,  100, 150000, '۱۰۰ الماس',  '100 gems',    null,          20),
  ('anix_gems_300',     0,  300, 250000, '۳۰۰ الماس',  '300 gems',    'محبوب',       30),
  ('anix_gems_500',     0,  500, 400000, '۵۰۰ الماس',  '500 gems',    null,          40),
  ('anix_gems_1000',    0, 1000, 550000, '۱۰۰۰ الماس', '1000 gems',   'بهترین ارزش', 50)
on conflict (sku) do nothing;

create table if not exists public.nx_iap_purchases (
  id             bigserial primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  store          text not null default 'bazaar',
  sku            text not null references public.nx_iap_products(sku),
  purchase_token text not null,
  order_id       text,
  coins          integer not null default 0,
  gems           integer not null default 0,
  price_toman    integer,
  purchase_time  timestamptz,
  raw            jsonb,
  created_at     timestamptz not null default now(),
  unique (store, purchase_token)
);
create index if not exists nx_iap_purchases_user on public.nx_iap_purchases(user_id, created_at desc);

alter table public.nx_iap_purchases enable row level security;
drop policy if exists nx_iap_purchases_own on public.nx_iap_purchases;
create policy nx_iap_purchases_own on public.nx_iap_purchases for select to authenticated using (user_id = auth.uid());
revoke all on public.nx_iap_purchases from anon, authenticated;
grant select on public.nx_iap_purchases to authenticated;
revoke all on sequence public.nx_iap_purchases_id_seq from anon, authenticated;

-- Credits one verified store purchase. service_role only (called by nx-bazaar-verify after Bazaar confirmed it).
-- Idempotent: a token already recorded returns the current wallet with dup = true and grants nothing.
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
