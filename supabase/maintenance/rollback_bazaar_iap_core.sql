-- Rollback for 20261125180000_nx_bazaar_iap.sql (core). Run rollback_e1_ledger_core.sql first if E1 is applied.
-- Removes the IAP tables: export nx_iap_purchases first if any real purchase was recorded.
begin;
drop function if exists public.nx_iap_credit(uuid, text, text, text, text, timestamptz, jsonb);
drop table if exists public.nx_iap_purchases;
drop table if exists public.nx_iap_products;
commit;
