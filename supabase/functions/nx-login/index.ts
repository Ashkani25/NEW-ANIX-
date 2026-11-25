// nx-login: sign in with a USERNAME + password without exposing anyone's e-mail to the client.
// POST { username, password } -> GoTrue session JSON (same shape as /auth/v1/token?grant_type=password).
// Internal accounts (<username>@users.nexora.invalid, password prefixed "nx#") are tried first,
// then the account whose profile currently owns that username (supporting renamed internal accounts as well).
// Optional { install }: the app's random install id. When a banned account was deleted on that install (ban-evasion
// hold, nx_install_held), the login is refused with 403 user_banned before any password is tried.
const URL_ = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-region",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

/// The CALLER's ip. Supabase's edge gateway sets cf-connecting-ip / x-forwarded-for (first hop = the client); GoTrue
/// only ever sees this function's own egress ip, so its per-ip limit would throttle every user together (#9).
function clientIp(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf.slice(0, 64);
  const xff = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  if (xff) return xff.slice(0, 64);
  return (req.headers.get("x-real-ip") ?? "unknown").trim().slice(0, 64);
}

/// Throttle per client ip + username, per ip and per username (nx_login_throttle, service role only).
async function throttle(ip: string, username: string): Promise<{ ok: boolean; retry_after?: number }> {
  try {
    const r = await fetch(`${URL_}/rest/v1/rpc/nx_login_throttle`, {
      method: "POST",
      headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_ip: ip, p_username: username }),
    });
    if (!r.ok) return { ok: false, retry_after: 30 }; // fail closed
    const b = await r.json();
    return { ok: b?.ok === true, retry_after: b?.retry_after };
  } catch {
    return { ok: false, retry_after: 30 };
  }
}

/// Ban-evasion hold on this install id (P0 #7c). Fails open: the sign-up / username / e-mail checks stay server-side.
async function installHeld(install: string): Promise<boolean> {
  if (!/^[a-z0-9-]{16,80}$/.test(install)) return false;
  try {
    const r = await fetch(`${URL_}/rest/v1/rpc/nx_install_held`, {
      method: "POST",
      headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_install: install }),
    });
    return r.ok && (await r.json()) === true;
  } catch {
    return false;
  }
}

async function grant(email: string, password: string, ip: string) {
  const r = await fetch(`${URL_}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json", "X-Forwarded-For": ip },
    body: JSON.stringify({ email, password }),
  });
  return { status: r.status, body: await r.json().catch(() => ({})) };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error_code: "method_not_allowed" }, 405);
  let username = "", password = "", install = "";
  try {
    const b = await req.json();
    username = String(b.username ?? "").trim().toLowerCase();
    password = String(b.password ?? "");
    install = String(b.install ?? "").trim().toLowerCase().slice(0, 80);
  } catch { /* fallthrough */ }
  if (!/^[a-z0-9_.]{2,24}$/.test(username) || password.length < 6 || password.length > 128) {
    return json({ error_code: "invalid_credentials", msg: "Invalid login credentials" }, 400);
  }
  const ip = clientIp(req);
  const t = await throttle(ip, username);
  if (!t.ok) {
    return new Response(JSON.stringify({ error_code: "over_request_rate_limit", msg: "Too many login attempts" }), {
      status: 429,
      headers: { ...cors, "Content-Type": "application/json", "Retry-After": String(t.retry_after ?? 60) },
    });
  }
  if (install && await installHeld(install)) {
    return json({ error_code: "user_banned", msg: "User is banned" }, 403);
  }
  // 1) internal username account matching initial signup handle
  let r = await grant(`${username}@users.nexora.invalid`, "nx#" + password, ip);
  if (r.status === 200) return json(r.body);
  if (r.status === 429) return json(r.body, 429);
  // 2) account owning that username in public.profiles (either real e-mail or renamed internal account)
  const q = await fetch(`${URL_}/rest/v1/rpc/nx_login_email`, {
    method: "POST",
    headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" },
    body: JSON.stringify({ p_username: username }),
  });
  const email = q.ok ? await q.json() : null;
  if (typeof email === "string" && email) {
    const internal = email.endsWith("@users.nexora.invalid");
    r = await grant(email, internal ? "nx#" + password : password, ip);
    return json(r.body, r.status);
  }
  return json({ error_code: "invalid_credentials", msg: "Invalid login credentials" }, 400);
});
