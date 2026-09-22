// Practicum CLI — License API
//
//   POST /webhooks/dodo       Dodo Payments webhook → mint license key → KV → email
//   GET  /license/validate    ?key=PRAC-... → entitlements JSON (used by lib/license.sh)
//   GET  /health              liveness
//
// Secrets (wrangler secret put): DODO_WEBHOOK_SECRET, HMAC_SECRET, RESEND_API_KEY

export interface Env {
  LICENSES: KVNamespace;
  ORDERS: KVNamespace;
  ENVIRONMENT: string;
  DODO_WEBHOOK_SECRET?: string;
  HMAC_SECRET?: string;
  RESEND_API_KEY?: string;
}

// ---------------------------------------------------------------------------
// Product → entitlement map. Slugs MUST match courses/<slug>/ in the repo.
// ---------------------------------------------------------------------------

const SINGLE: Record<string, string> = {
  pdt_0No7umC6gaGIE4EXLu2Gu: "linux-foundations",
  pdt_0No7umEyEyApMgJMBRwHI: "git-essentials",
  pdt_0No7umGHodyphlPy7kVuw: "shell-mastery",
  pdt_0No7umI46jJ6QFGzDz9Wn: "data-forging",
  pdt_0No7umIT3vq6wQTDTLitA: "docker-essentials",
  pdt_0No7umIuzv3LovBDw9mJs: "cicd-pipelines",
  pdt_0No7umJqQBlWvxZErrHqv: "terraform-iac",
  pdt_0No7umKG7Jh3e57OeTvC6: "kubernetes",
};

const DATA_TRACK = ["linux-foundations", "shell-mastery", "data-forging"];
const PLATFORM_TRACK = [
  "linux-foundations", "git-essentials", "docker-essentials",
  "cicd-pipelines", "terraform-iac", "kubernetes",
];
const FULL_CATALOG = [
  "linux-foundations", "git-essentials", "shell-mastery", "data-forging",
  "docker-essentials", "cicd-pipelines", "terraform-iac", "kubernetes",
];

export const PRODUCT_ENTITLEMENTS: Record<string, string[]> = {
  ...Object.fromEntries(Object.entries(SINGLE).map(([id, slug]) => [id, [slug]])),
  pdt_0No7umL7kMaekaV8OezhO: DATA_TRACK,       // Data Engineering Track  $99
  pdt_0No7umM8Suwb4dLat0K8G: PLATFORM_TRACK,   // Platform Engineering    $129
  pdt_0No7umMgQG48JrJhqRVkc: FULL_CATALOG,     // Full Catalog v3         $199
  pdt_0No7umNCBCxwKBAZALtnS: FULL_CATALOG,     // Team 5 seats            $899
  pdt_0No7umOh6PEBDCQTfXWzm: FULL_CATALOG,     // Team 10 seats           $1,599
  pdt_0No8Kgf2Z4FOleEA96DEW: FULL_CATALOG,     // Classroom (30+2 seats)   $3,499
};

const PRODUCT_SEATS: Record<string, number> = {
  pdt_0No7umNCBCxwKBAZALtnS: 5,
  pdt_0No7umOh6PEBDCQTfXWzm: 10,
  pdt_0No8Kgf2Z4FOleEA96DEW: 30,
};

const CLASSROOM_PRODUCT = "pdt_0No8Kgf2Z4FOleEA96DEW";
type Role = "learner" | "instructor-admin";
const PRODUCT_ROLE: Record<string, Role> = {
  [CLASSROOM_PRODUCT]: "instructor-admin",
};

const LICENSE_TERM_DAYS = 365;
const DAY_MS = 24 * 60 * 60 * 1000;

interface LicenseRecord {
  key: string;
  email: string;
  product_id: string;
  entitlements: string[];
  order_id: string;
  seats: number;
  role: Role;
  created_at: string;
  expires_at: string;   // ISO, created_at + LICENSE_TERM_DAYS
  activated: boolean;
  activated_at: string | null;
  revoked: boolean;
  revoked_at: string | null;
  revoked_reason: string | null;
}

// ---------------------------------------------------------------------------
// Crypto helpers
// ---------------------------------------------------------------------------

const enc = new TextEncoder();

async function hmacSha256(secret: ArrayBuffer | Uint8Array, message: string): Promise<ArrayBuffer> {
  const k = await crypto.subtle.importKey("raw", secret, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return crypto.subtle.sign("HMAC", k, enc.encode(message));
}

function toHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function toBase64(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)));
}

function fromBase64(s: string): Uint8Array {
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// Format: PRAC-XXXX-XXXX-XXXX-XXXX (first 16 hex chars of HMAC(order_id), upper-cased)
export async function generateLicenseKey(orderId: string, secret: string): Promise<string> {
  const hex = toHex(await hmacSha256(enc.encode(secret), orderId)).toUpperCase();
  return `PRAC-${hex.slice(0, 4)}-${hex.slice(4, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}`;
}

// Dodo follows the Standard Webhooks spec:
//   signed = `${webhook-id}.${webhook-timestamp}.${body}`
//   header webhook-signature = "v1,<base64 HMAC-SHA256>" (space-separated list, any may match)
//   secret is "whsec_<base64>"
const WEBHOOK_TOLERANCE_SEC = 5 * 60;

export async function verifyDodoSignature(request: Request, body: string, secret: string): Promise<boolean> {
  const id = request.headers.get("webhook-id");
  const ts = request.headers.get("webhook-timestamp");
  const sigHeader = request.headers.get("webhook-signature");
  if (!id || !ts || !sigHeader) return false;

  const tsNum = Number(ts);
  if (!Number.isFinite(tsNum)) return false;
  if (Math.abs(Date.now() / 1000 - tsNum) > WEBHOOK_TOLERANCE_SEC) return false;

  const raw = secret.startsWith("whsec_") ? secret.slice(6) : secret;
  const expected = toBase64(await hmacSha256(fromBase64(raw), `${id}.${ts}.${body}`));

  return sigHeader.split(" ").some((part) => {
    const [version, sig] = part.split(",");
    return version === "v1" && sig !== undefined && timingSafeEqual(sig, expected);
  });
}

// ---------------------------------------------------------------------------
// Email
// ---------------------------------------------------------------------------

async function sendLicenseEmail(env: Env, email: string, key: string, entitlements: string[], expiresAt: string): Promise<boolean> {
  if (!env.RESEND_API_KEY) {
    console.error(`RESEND_API_KEY not set — license ${key} for ${email} NOT emailed`);
    return false;
  }
  const courseList = entitlements.map((e) => `  • ${e}`).join("\n");
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: "Practicum CLI <practicum@mpingo.ai>",
      to: email,
      subject: "Your Practicum CLI License Key",
      text:
        `Your Practicum CLI license key:\n\n${key}\n\n` +
        `Activate with:\n  practicum activate ${key}\n\n` +
        `Courses unlocked:\n${courseList}\n\n` +
        `Valid until ${expiresAt.slice(0, 10)}. Annual license, no autorenewal.\n\n` +
        `Practicum CLI — Precision tools that last.\nhttps://practicum-cli.dev`,
    }),
  });
  if (!res.ok) console.error(`Resend failed (${res.status}) for ${email}: ${await res.text()}`);
  return res.ok;
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

const json = (data: unknown, status = 200) =>
  Response.json(data, { status, headers: { "Access-Control-Allow-Origin": "*" } });

async function handleDodoWebhook(request: Request, env: Env): Promise<Response> {
  if (!env.DODO_WEBHOOK_SECRET || !env.HMAC_SECRET) {
    console.error("Webhook secrets not configured");
    return new Response("Not configured", { status: 503 });
  }

  const body = await request.text();
  if (!(await verifyDodoSignature(request, body, env.DODO_WEBHOOK_SECRET))) {
    return new Response("Unauthorized", { status: 401 });
  }

  let event: any;
  try {
    event = JSON.parse(body);
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  const type: string = event.type ?? "";
  const data = event.data ?? {};

  // Refunds / disputes revoke the key minted for that payment.
  if (type === "refund.succeeded" || type === "dispute.opened" || type === "dispute.won") {
    const paymentId: string | undefined = data.payment_id ?? data.id;
    if (paymentId) {
      const key = await env.ORDERS.get(paymentId);
      const rec = key ? await env.LICENSES.get<LicenseRecord>(key, "json") : null;
      if (key && rec && !rec.revoked) {
        rec.revoked = true;
        rec.revoked_at = new Date().toISOString();
        rec.revoked_reason = type;
        await env.LICENSES.put(key, JSON.stringify(rec));
      }
    }
    return new Response("OK");
  }

  if (type !== "payment.succeeded") return new Response("OK");

  // Dodo payment payload: payment_id, customer.email, product_cart[{product_id}]
  const orderId: string | undefined = data.payment_id ?? data.id;
  const email: string | undefined = data.customer?.email ?? data.customer_email;
  const productId: string | undefined = data.product_cart?.[0]?.product_id ?? data.product_id;

  if (!orderId || !email || !productId) {
    console.error(`payment.succeeded missing fields: order=${orderId} email=${email} product=${productId}`);
    return new Response("OK");
  }

  // Idempotency — Dodo retries; never mint twice for one payment.
  if (await env.ORDERS.get(orderId)) return new Response("OK");

  const entitlements = PRODUCT_ENTITLEMENTS[productId];
  if (!entitlements) {
    console.error(`Unknown product_id: ${productId} (order ${orderId})`);
    return new Response("OK");
  }

  const key = await generateLicenseKey(orderId, env.HMAC_SECRET);
  const now = Date.now();
  const record: LicenseRecord = {
    key,
    email,
    product_id: productId,
    entitlements,
    order_id: orderId,
    seats: PRODUCT_SEATS[productId] ?? 1,
    role: PRODUCT_ROLE[productId] ?? "learner",
    created_at: new Date(now).toISOString(),
    expires_at: new Date(now + LICENSE_TERM_DAYS * DAY_MS).toISOString(),
    activated: false,
    activated_at: null,
    revoked: false,
    revoked_at: null,
    revoked_reason: null,
  };

  await env.LICENSES.put(key, JSON.stringify(record));
  await env.ORDERS.put(orderId, key);

  await sendLicenseEmail(env, email, key, entitlements, record.expires_at);
  return new Response("OK");
}

async function handleValidate(request: Request, env: Env): Promise<Response> {
  const key = new URL(request.url).searchParams.get("key")?.trim().toUpperCase();
  if (!key) return json({ valid: false, error: "No key provided" }, 400);

  const license = await env.LICENSES.get<LicenseRecord>(key, "json");
  if (!license) return json({ valid: false, error: "License not found" }, 404);
  if (license.revoked) return json({ valid: false, error: "License revoked" }, 403);

  // Annual term. Records minted before expiry existed fall back to created_at + term.
  const expiresAt = license.expires_at ?? new Date(Date.parse(license.created_at) + LICENSE_TERM_DAYS * DAY_MS).toISOString();
  const expiresEpoch = Math.floor(Date.parse(expiresAt) / 1000);
  if (Date.now() >= expiresEpoch * 1000) {
    return json({ valid: false, error: "License expired", expires_at: expiresAt, expires_epoch: expiresEpoch }, 403);
  }

  if (!license.activated) {
    license.activated = true;
    license.activated_at = new Date().toISOString();
    await env.LICENSES.put(key, JSON.stringify(license));
  }

  return json({
    valid: true,
    key: license.key,
    email: license.email,
    product_id: license.product_id,
    entitlements: license.entitlements,
    seats: license.seats,
    role: license.role ?? "learner",
    activated_at: license.activated_at,
    expires_at: expiresAt,
    expires_epoch: expiresEpoch,
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const { method } = request;

    if (method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    if (method === "GET" && url.pathname === "/health") {
      return json({ status: "ok", worker: "practicum-api", env: env.ENVIRONMENT });
    }
    if (method === "POST" && url.pathname === "/webhooks/dodo") return handleDodoWebhook(request, env);
    if (method === "GET" && url.pathname === "/license/validate") return handleValidate(request, env);

    return new Response("Not found", { status: 404 });
  },
};
