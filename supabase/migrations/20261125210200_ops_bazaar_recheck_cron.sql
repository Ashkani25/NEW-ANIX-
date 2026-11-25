-- Ops (core): schedule the Cafe Bazaar refund sweep (supabase/functions/nx-bazaar-recheck, README there).
-- Needs Vault secret nx_cron_secret (= function secret NX_CRON_SECRET; both set 2026-11-25). Until BAZAAR_API_SECRET is
-- set the function answers 503 store_not_configured and does nothing. Rollback: maintenance/rollback_ops_bazaar_recheck_cron.sql
do $$ begin
  if exists (select 1 from cron.job where jobname = 'nx_bazaar_recheck') then perform cron.unschedule('nx_bazaar_recheck'); end if;
end $$;
select cron.schedule('nx_bazaar_recheck', '17 */6 * * *', $cmd$
  select net.http_post(
    url := 'https://eisstodgncimypdawisy.supabase.co/functions/v1/nx-bazaar-recheck',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'nx_cron_secret')),
    body := '{"limit":100}'::jsonb, timeout_milliseconds := 60000)
$cmd$);
