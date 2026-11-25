// ANIX · nx-bazaar-recheck — periodic refund sweep for Cafe Bazaar in-app purchases.
//
// For every credited purchase that is still inside the refund window (nx_iap_recheck_due), ask Bazaar again:
//   purchaseState 1 (refunded) -> nx_iap_mark_refunded: debits the pack through nx_wallet_apply (clamped at zero,
//                                 whatever was already spent is flagged in nx_wallet_flags 'iap_refund_shortfall')
//   purchaseState 0            -> nx_iap_mark_checked (checked again in p_every_hours)
//   404 / other                -> left for the next run (logged)
// Auth: Authorization: Bearer <service role key>, or header x-cron-secret = NX_CRON_SECRET. Not callable by players.
// Body (optional): { limit?: number (<=500), window_days?: number, every_hours?: number }
// Secrets: BAZAAR_API_SECRET (required), BAZAAR_PACKAGE (default com.nexora.nexora), NX_CRON_SECRET (optional).
import { createClient } from "npm:@supabase/supabase-js@2";
import { bazaarValidate, purchaseState, PURCHASED, REFUNDED } from "../_shared/bazaar.ts";

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });

function authorised(req: Request, service: string): boolean {
  const cron = Deno.env.get("NX_CRON_SECRET") ?? "";
  if (cron && req.headers.get("x-cron-secret") === cron) return true;
  const auth = req.headers.get("Authorization") ?? "";
  return service.length > 0 && auth === `Bearer ${service}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ ok: false, error: "method" }, 405);
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!authorised(req, service)) return json({ ok: false, error: "unauthorized" }, 401);
  const secret = Deno.env.get("BAZAAR_API_SECRET");
  const pkg = Deno.env.get("BAZAAR_PACKAGE") ?? "com.nexora.nexora";
  if (!secret) return json({ ok: false, error: "store_not_configured" }, 503);

  const b = await req.json().catch(() => ({}));
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, service, { auth: { persistSession: false } });
  const { data: due, error } = await admin.rpc("nx_iap_recheck_due", {
    p_limit: Math.min(Math.max(Number(b.limit) || 50, 1), 500),
    p_window_days: Number(b.window_days) || 45,
    p_every_hours: Number(b.every_hours) || 12,
  });
  if (error) {
    console.error("nx_iap_recheck_due", error.message);
    return json({ ok: false, error: "db" }, 500);
  }
  const out = { checked: 0, refunded: 0, failed: 0, details: [] as unknown[] };
  for (const p of (due ?? []) as { id: number; store: string; sku: string; purchase_token: string }[]) {
    if (p.store !== "bazaar") continue;
    try {
      const v = await bazaarValidate(pkg, p.sku, p.purchase_token, secret);
      const state = v.status === 200 ? purchaseState(v) : null;
      if (state === REFUNDED) {
        const { data, error: e2 } = await admin.rpc("nx_iap_mark_refunded",
          { p_store: "bazaar", p_token: p.purchase_token, p_raw: v.body });
        if (e2) throw new Error(e2.message);
        out.refunded++;
        out.details.push({ id: p.id, refunded: data });
      } else if (state === PURCHASED) {
        const { error: e3 } = await admin.rpc("nx_iap_mark_checked", { p_id: p.id, p_state: PURCHASED });
        if (e3) throw new Error(e3.message);
        out.checked++;
      } else {
        console.warn("bazaar recheck", p.id, v.status, JSON.stringify(v.body).slice(0, 200));
        out.failed++;
      }
    } catch (e) {
      console.error("bazaar recheck", p.id, e);
      out.failed++;
    }
  }
  return json({ ok: true, ...out });
});
