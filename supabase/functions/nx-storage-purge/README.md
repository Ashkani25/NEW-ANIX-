# nx-storage-purge (core project `eisstodgncimypdawisy`) — NOT deployed yet

Removes storage files left behind by deleted accounts (legacy `avatars` / `chat` buckets have no client delete policy,
so the app cannot remove them itself). SQL side: `supabase/migrations/20261125210100_p0_01b_storage_purge.sql`
(applied live): queue table `nx_storage_purge_queue`, `nx_storage_purge_claim/done/enqueue_orphans` (service role only),
`_nx_storage_purge_kick()` and the pg_cron job `nx-storage-purge` (every 15 min).
Until the steps below are done the queue simply fills up (paths only) and nothing is removed.

## Deploy

```bash
# 1. a random shared secret
SECRET=$(openssl rand -hex 32)

# 2. the function (pg_net sends no JWT, the function checks the secret header itself)
supabase functions deploy nx-storage-purge --project-ref eisstodgncimypdawisy --no-verify-jwt
supabase secrets set --project-ref eisstodgncimypdawisy STORAGE_PURGE_SECRET=$SECRET
# optional, one-off: also queue files of accounts deleted before the queue existed (owner no longer in auth.users)
# supabase secrets set --project-ref eisstodgncimypdawisy PURGE_ORPHANS=1   (unset again after one run)

# 3. the same secret in Vault, so the database can call the function (SQL editor, core project)
#    select vault.create_secret('<SECRET>', 'nx_storage_purge_secret', 'x-nx-purge-secret for nx-storage-purge');
#    optional when the functions URL is not https://eisstodgncimypdawisy.supabase.co/functions/v1:
#    select vault.create_secret('https://<ref>.supabase.co/functions/v1', 'nx_core_functions_url', 'core functions base');
```

## Check

```sql
select count(*) filter (where done_at is null) pending, count(*) filter (where done_at is not null) done,
       max(last_error) last_error from public.nx_storage_purge_queue;
select public.nx_storage_purge_enqueue_orphans(true);  -- how many orphans an orphan sweep would queue (dry run)
select public._nx_storage_purge_kick();                -- poke it now
```

Rows give up after 10 failed attempts (`attempts`, `last_error`); reset with
`update nx_storage_purge_queue set attempts = 0, claimed_at = null where done_at is null;`.
