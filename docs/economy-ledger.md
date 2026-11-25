# Economy E1 — authoritative coin / gem ledger

**Core project (`eisstodgncimypdawisy`) is the only source of truth for coins and gems.**

| piece | where | what |
|---|---|---|
| `nx_wallet_ledger` | core | append-only (update / delete / truncate raise). One row per change per currency: `user_id, currency, delta, balance_after, reason, ref, idem_key, source (fn / trigger / opening), actor, txid, created_at`. Unique `(idem_key, currency)`. |
| `nx_wallet_apply(user, coins, gems, reason, ref, idem, mode)` | core | the one wallet function (service_role / definer callers only). Locks the profile row, `strict` refuses overdraft, `clamp` debits to zero and reports the shortfall, idempotent on `idem`. |
| ledger trigger on `profiles` | core | AFTER INSERT / UPDATE OF coins, gems / DELETE writes the ledger rows in the same transaction, using the reason/ref/idem `nx_wallet_apply` set. A change made any other way is still ledgered with `source = 'trigger'`, reason `untracked:<calling function>` (or `<nx.reason>:<function>`). |
| `nx_wallet_flags` | core | debits that could not be covered: `games_shortfall`, `iap_refund_shortfall`. |
| `nx_wallet_audit()` | core | rows where `sum(delta)` or the last `balance_after` differs from the live balance. Must be empty. |
| `nx_wallet_history(limit, before)` | core | the player's own ledger (Dart: `lib/core/economy/wallet_ledger.dart`). |
| `nx_mirror_put` + `tx_upto` | games | the games wallet is a mirror: local spends queue in `nx_wallet_tx`, core applies them via `nx_wallet_apply` (idem `games_tx:<id>`, clamp + flag), pushes absolute balances back with `tx_upto`, games acks those tx and overwrites. |

## Routed through `nx_wallet_apply`
`nx_purchase` (shop:coins), `nx_buy_with_gems` (shop:gems), `nx_daily_gems` (daily_gems), `nx_wallet` welcome bonus
(welcome_gems), `nx_award` (award:<rule>, includes the daily reward streak), `nx_admin_grant_wallet`, `nx_owner_grant`,
`nx_admin_set_wallet`, `nx_iap_credit` (iap:bazaar), `nx_iap_mark_refunded` (iap_refund:bazaar),
`nx_bridge_apply_batch` (games:<reason> — carrom cosmetics, tournament entry fees / refunds / prizes on games).

## Not yet routed (still ledgered by the trigger as `untracked:<fn>` / `<nx.reason>:<fn>`)
Legacy core functions with no Dart caller: `_grant`, `buy_disc`, `buy_pack`, `claim_challenge`,
`claim_season_reward`, `create_club`, `create_tournament*`, `cup_create*`, `_cup_*`, `duel_join`, `report_match`,
`_refund_stakes`, `_start_match`, `wc_tick`, core copies of `_nx_t_charge/_nx_t_refund/_nx_t_payout`.
Query: `select reason, count(*) from nx_wallet_ledger where source = 'trigger' group by 1;`

## IAP (Cafe Bazaar)
verify → `nx_iap_credit` (token unique per store, ledger idem `iap:bazaar:<token>`) → app consumes.
Refund: Bazaar `purchaseState = 1` (seen by verify or by the `nx-bazaar-recheck` sweep) → `nx_iap_mark_refunded`:
debit in clamp mode, status `refunded`, remainder flagged. Edge functions are not deployed; see
`supabase/functions/nx-bazaar-recheck/README.md`.

## Rollback
`supabase/maintenance/rollback_e1_ledger_core.sql`, `rollback_e1_mirror_games.sql`, `rollback_bazaar_iap_core.sql`.
Probes: `supabase/tests/economy/*.sql` (always run inside `BEGIN … ROLLBACK`).
