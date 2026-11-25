-- Rollback of supabase/migrations/20261126210100_rs02_gem_victory_fx.sql (core project).
-- Takes the victory effects off sale. Rows are deactivated, not deleted: players who bought one keep it in their
-- inventory (user data) and the ledger rows keep pointing at a real catalog item.
update public.nx_catalog set active = false, updated_at = now() where item_id like 'nx\_fx:%';
