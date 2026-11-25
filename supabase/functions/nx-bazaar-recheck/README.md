# nx-bazaar-recheck (NOT deployed yet)

Refund sweep for Cafe Bazaar purchases. Needs SQL from `supabase/migrations/20261126000000_economy_ledger.sql`
(applied live on core `eisstodgncimypdawisy` 2026-11-25).

## Deploy (core project)

```bash
supabase secrets set --project-ref eisstodgncimypdawisy BAZAAR_API_SECRET=<Pishkhan API secret> \
  BAZAAR_PACKAGE=com.nexora.nexora NX_CRON_SECRET=$(openssl rand -hex 24)
supabase functions deploy nx-bazaar-verify  --project-ref eisstodgncimypdawisy
supabase functions deploy nx-bazaar-recheck --project-ref eisstodgncimypdawisy --no-verify-jwt
```

Both functions import `../_shared/bazaar.ts`; deploy from the repo root so the shared file is bundled.
`nx-bazaar-recheck` checks its own auth (service-role bearer or `x-cron-secret`), so `--no-verify-jwt` is fine.

## Schedule (after deploy; pure SQL on core, run once)

```sql
-- store the cron secret in vault first: select vault.create_secret('<NX_CRON_SECRET>', 'nx_cron_secret');
select cron.schedule('nx_bazaar_recheck', '17 */6 * * *', $$
  select net.http_post(
    url := 'https://eisstodgncimypdawisy.supabase.co/functions/v1/nx-bazaar-recheck',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'nx_cron_secret')),
    body := '{"limit":100}'::jsonb, timeout_milliseconds := 60000)
$$);
```

## What a refund does

`nx_iap_mark_refunded(store, token)` debits the pack through `nx_wallet_apply` in clamp mode (ledger reason
`iap_refund:bazaar`, idem `iap_refund:bazaar:<token>`), marks the purchase `status = 'refunded'`, and if the player
already spent part of it, records the remainder in `nx_wallet_flags` (`kind = 'iap_refund_shortfall'`) for an admin.
Refund window defaults to 45 days after the purchase (Bazaar does not document one; adjust `window_days`).
Open question: Bazaar's docs do not say whether validate keeps answering for a purchase that was already consumed;
if it starts returning 404 for consumed tokens the sweep logs them as `failed` and never debits.
