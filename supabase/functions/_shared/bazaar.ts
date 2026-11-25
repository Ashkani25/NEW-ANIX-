// ANIX · Cafe Bazaar developer API helpers shared by nx-bazaar-verify and nx-bazaar-recheck.
// Validation: GET https://pardakht.cafebazaar.ir/devapi/v2/api/validate/<pkg>/inapp/<sku>/purchases/<token>/
// Response: { consumptionState: 0 consumed | 1 not consumed, purchaseState: 0 purchased | 1 refunded,
//             developerPayload, purchaseTime (ms) }   404 = unknown token.
// Docs: https://developers.cafebazaar.ir/fa/guidelines/in-app-billing/api/validation
//       https://developers.cafebazaar.ir/fa/guidelines/in-app-billing/api/refund (purchaseState 1 = refunded)

export const PURCHASED = 0;
export const REFUNDED = 1;

export type BazaarAnswer = { status: number; body: Record<string, unknown> };

export async function bazaarValidate(pkg: string, sku: string, token: string, secret: string): Promise<BazaarAnswer> {
  const url = `https://pardakht.cafebazaar.ir/devapi/v2/api/validate/${encodeURIComponent(pkg)}/inapp/` +
    `${encodeURIComponent(sku)}/purchases/${encodeURIComponent(token)}/`;
  const headers = { "CAFEBAZAAR-PISHKHAN-API-SECRET": secret, "Accept": "application/json" };
  // Bazaar's docs say GET; its support has told developers POST. Try GET, fall back to POST on 405.
  let res = await fetch(url, { method: "GET", headers, signal: AbortSignal.timeout(10000) });
  if (res.status === 405) res = await fetch(url, { method: "POST", headers, signal: AbortSignal.timeout(10000) });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, body: body as Record<string, unknown> };
}

/** purchaseState as a number, or null when Bazaar did not send one. */
export function purchaseState(a: BazaarAnswer): number | null {
  const v = a.body?.purchaseState;
  if (v === undefined || v === null || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}
