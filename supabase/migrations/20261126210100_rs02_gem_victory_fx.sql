-- RS-02 (core, 2026-11-26, work/rematch-spectator): the gem (الماس) item for every online game.
--
-- Until now gem items existed only for finger soccer (fs_team:*, fs_custom_team, fs_fx:*). These rows add the
-- game-independent gem item: a victory effect ('nx_fx:<style>') the buyer sees on the online result screen of ANY
-- game when they win (cosmetic only: it never changes play, so it is fair in every game, hidden-role games included).
-- Prices mirror the finger-soccer fs_fx rows. Sold ONLY through the existing nx_buy_with_gems RPC, which takes the
-- price from this catalog and charges through nx_wallet_apply (ledger) and grants the item into nx_profiles.data.inv;
-- no balance is touched here. Admins can re-price / deactivate rows as with every catalog row.
-- Idempotent (never overwrites an existing price). Rollback: supabase/maintenance/rollback_rs02_core.sql
insert into public.nx_catalog(item_id, price, currency, active, kind, name)
values
  ('nx_fx:sparks',    200, 'gems', true, 'fx', 'Victory FX · Sparks'),
  ('nx_fx:neon',      200, 'gems', true, 'fx', 'Victory FX · Neon'),
  ('nx_fx:fire',      250, 'gems', true, 'fx', 'Victory FX · Fire'),
  ('nx_fx:frost',     250, 'gems', true, 'fx', 'Victory FX · Frost'),
  ('nx_fx:lightning', 300, 'gems', true, 'fx', 'Victory FX · Lightning'),
  ('nx_fx:rainbow',   350, 'gems', true, 'fx', 'Victory FX · Rainbow')
on conflict (item_id) do nothing;
