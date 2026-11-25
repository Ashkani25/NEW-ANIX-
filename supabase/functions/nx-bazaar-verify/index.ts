// ANIX · nx-bazaar-verify — verifies a Cafe Bazaar in-app purchase on the server and credits the pack.
//
// Body: { sku, purchase_token, order_id?, purchase_time? }   Auth: the player's Supabase JWT.
// 1. Identify the caller (sb.auth.getUser).
// 2. Ask Bazaar: GET https://pardakht.cafebazaar.ir/devapi/v2/api/validate/<pkg>/inapp/<sku>/purchases/<token>/
//    with header CAFEBAZAAR-PISHKHAN-API-SECRET (Pishkhan -> app -> "API پیشخان" -> new token).
//    purchaseState must be 0 and developerPayload (set by the app to the uid) must match the caller.
// 3. nx_iap_credit (service_role) records the token once and adds the coins / gems.
// The app consumes the purchase only after ok = true, so a failure here is retried on the next launch.
//
// Secrets: BAZAAR_API_SECRET (required), BAZAAR_PACKAGE (default com.nexora.nexora).
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-region",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const SKU = /^[a-z0-9_.]{3,64}$/;
const TOKEN = /^[A-Za-z0-9_\-.:]{6,512}$/;

async function bazaarValidate(pkg: string, sku: string, token: string, secret: string) {
  const url = `https://pardakht.cafebazaar.ir/devapi/v2/api/validate/${encodeURIComponent(pkg)}/inapp/` +
    `${encodeURIComponent(sku)}/purchases/${encodeURIComponent(token)}/`;
  const headers = { "CAFEBAZAAR-PISHKHAN-API-SECRET": secret, "Accept": "application/json" };
  // Bazaar's docs say GET; its support has told developers POST. Try GET, fall back to POST on 405.
  let res = await fetch(url, { method: "GET", headers, signal: AbortSignal.timeout(10000) });
  if (res.status === 405) res = await fetch(url, { method: "POST", headers, signal: AbortSignal.timeout(10000) });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, body: body as Record<string, unknown> };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, error: "method" }, 405);
  try {
    const secret = Deno.env.get("BAZAAR_API_SECRET");
    const pkg = Deno.env.get("BAZAAR_PACKAGE") ?? "com.nexora.nexora";
    if (!secret) return json({ ok: false, error: "store_not_configured" }, 503);

    const supaUrl = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const auth = req.headers.get("Authorization") ?? "";
    if (!auth) return json({ ok: false, error: "unauthorized" }, 401);
    const user = await createClient(supaUrl, anon, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false },
    }).auth.getUser().then((r) => r.data?.user ?? null, () => null);
    if (!user) return json({ ok: false, error: "unauthorized" }, 401);
    if (user.is_anonymous) return json({ ok: false, error: "account_required" }, 403);

    const b = await req.json().catch(() => ({}));
    const sku = String(b.sku ?? "");
    const token = String(b.purchase_token ?? "");
    if (!SKU.test(sku) || !TOKEN.test(token)) return json({ ok: false, error: "bad_request" }, 400);

    const admin = createClient(supaUrl, service, { auth: { persistSession: false } });
    const { data: prod } = await admin.from("nx_iap_products").select("sku").eq("sku", sku).maybeSingle();
    if (!prod) return json({ ok: false, error: "unknown_sku" }, 400);

    const v = await bazaarValidate(pkg, sku, token, secret);
    if (v.status === 404) return json({ ok: false, error: "not_found" }, 400);
    if (v.status !== 200) {
      console.error("bazaar validate", v.status, JSON.stringify(v.body).slice(0, 300));
      return json({ ok: false, error: "store_unavailable", retry: true }, 502);
    }
    if (Number(v.body.purchaseState) !== 0) return json({ ok: false, error: "not_purchased" }, 400);
    const payload = String(v.body.developerPayload ?? "");
    if (payload && payload !== user.id) return json({ ok: false, error: "payload_mismatch" }, 403);

    const pt = Number(v.body.purchaseTime);
    const { data, error } = await admin.rpc("nx_iap_credit", {
      p_user: user.id,
      p_store: "bazaar",
      p_sku: sku,
      p_token: token,
      p_order: b.order_id ? String(b.order_id).slice(0, 128) : null,
      p_purchase_time: Number.isFinite(pt) && pt > 0 ? new Date(pt).toISOString() : null,
      p_raw: v.body,
    });
    if (error) {
      console.error("nx_iap_credit", error.message);
      return json({ ok: false, error: "credit_failed", retry: true }, 500);
    }
    return json(data);
  } catch (e) {
    console.error("nx-bazaar-verify", e);
    return json({ ok: false, error: "server", retry: true }, 500);
  }
});
