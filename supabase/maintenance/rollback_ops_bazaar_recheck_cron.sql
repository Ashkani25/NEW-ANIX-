-- Rollback for 20261125210200_ops_bazaar_recheck_cron.sql (core). Vault secret nx_cron_secret is left in place.
select cron.unschedule('nx_bazaar_recheck') where exists (select 1 from cron.job where jobname = 'nx_bazaar_recheck');
