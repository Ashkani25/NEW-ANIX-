// ANIX · nx-storage-purge — removes storage files left behind by deleted accounts (P0 #1b).
//
// nx_delete_account cannot delete blobs from SQL (deleting a storage.objects row leaves the file in the bucket store
// and makes it unreachable for the Storage API). It queues the leftover (bucket, path) pairs in
// public.nx_storage_purge_queue and pokes this function after commit; pg_cron (job nx-storage-purge) pokes it every
// 15 minutes while anything is pending. Each run:
//   1. nx_storage_purge_claim(200)  -> pending paths (service role only)
//   2. storage.from(bucket).remove(paths) through the Storage API (removes blob + row)
//   3. nx_storage_purge_done(ids, error)  -> done, or kept for a retry (max 10 attempts)
//   4. when PURGE_ORPHANS=1: nx_storage_purge_enqueue_orphans(false) first, queuing files whose recorded owner no
//      longer exists in auth.users (accounts deleted before the queue existed).
//
// Auth: header x-nx-purge-secret must equal the STORAGE_PURGE_SECRET env var (same value as the Vault secret
// nx_storage_purge_secret). Deploy with --no-verify-jwt (pg_net sends no JWT). See README.md in this folder.
import { createClient } from "npm:@supabase/supabase-js@2";

const URL_ = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SECRET = Deno.env.get("STORAGE_PURGE_SECRET") ?? "";
const ORPHANS = Deno.env.get("PURGE_ORPHANS") === "1";

const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });

function sameSecret(a: string, b: string): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!sameSecret(req.headers.get("x-nx-purge-secret") ?? "", SECRET)) return json({ error: "forbidden" }, 403);

  const sb = createClient(URL_, SERVICE, { auth: { persistSession: false } });
  let orphans = 0;
  if (ORPHANS) {
    const o = await sb.rpc("nx_storage_purge_enqueue_orphans", { p_dry_run: false });
    orphans = typeof o.data === "number" ? o.data : 0;
  }

  const { data, error } = await sb.rpc("nx_storage_purge_claim", { p_limit: 200 });
  if (error) return json({ error: error.message }, 500);
  const rows = (data ?? []) as { id: number; bucket: string; path: string }[];

  const byBucket = new Map<string, { id: number; path: string }[]>();
  for (const r of rows) {
    if (!byBucket.has(r.bucket)) byBucket.set(r.bucket, []);
    byBucket.get(r.bucket)!.push({ id: r.id, path: r.path });
  }

  let removed = 0, failed = 0;
  for (const [bucket, items] of byBucket) {
    // the Storage API takes up to 1000 paths per call; 200 per run keeps each call small
    const res = await sb.storage.from(bucket).remove(items.map((i) => i.path));
    const ids = items.map((i) => i.id);
    if (res.error) {
      failed += ids.length;
      await sb.rpc("nx_storage_purge_done", { p_ids: ids, p_error: res.error.message });
    } else {
      // paths the API did not find are already gone: done as well
      removed += (res.data ?? []).length;
      await sb.rpc("nx_storage_purge_done", { p_ids: ids, p_error: null });
    }
  }
  return json({ ok: true, claimed: rows.length, removed, failed, orphans_queued: orphans });
});
