// Practicum CLI — License API
//
//   POST /webhooks/dodo       Dodo Payments webhook → mint license key → KV → email
//   GET  /license/validate    ?key=PRAC-... → entitlements JSON (used by lib/license.sh)
//   GET  /health              liveness
//
// Secrets (wrangler secret put): DODO_WEBHOOK_SECRET, HMAC_SECRET, RESEND_API_KEY

import { routeClassroom, corsHeaders, type ClassroomEnv } from "./classroom";
import { buildLicenseRecord, type LicenseRecord, type LicenseRole } from "./catalog";

export interface Env extends ClassroomEnv {
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
  pdt_0No8cX1sZ1XCttHIl5fh3: "linux-foundations",
  pdt_0No8cX1r3haaAnMDWlW8C: "git-essentials",
  pdt_0No8cX1sZ1XCttHQ6FwOk: "shell-mastery",
  pdt_0No8cX1rolhdm8TbGSI91: "data-forging",
  pdt_0No8cX1sZQTfyfYqre4BW: "docker-essentials",
  pdt_0No8cX1tLOc3LaVXpGBPw: "cicd-pipelines",
  pdt_0No8cX2J2EoRdkmAVkMCE: "terraform-iac",
  pdt_0No8cX2OJhVBYHfq4V9cs: "kubernetes",
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

// All products are recurring yearly (Dodo). Seats > 1 marks a team product.
export const PRODUCT_ENTITLEMENTS: Record<string, string[]> = {
  ...Object.fromEntries(Object.entries(SINGLE).map(([id, slug]) => [id, [slug]])),
  // Individual tracks
  pdt_0No8cX2PpLQr3eZTRBjov: DATA_TRACK,       // Data Engineering Track   $99/yr
  pdt_0No8cX2P3PLJsBYdbVe29: PLATFORM_TRACK,   // Platform Engineering     $129/yr
  pdt_0No8cX2NZGEmwrUPoCegF: FULL_CATALOG,     // Full Catalog             $199/yr
  // Team tracks
  pdt_0No8cX2WdUc6FfZmRq6no: DATA_TRACK,       // Team Data Eng 5 seats    $349/yr
  pdt_0No8cX2kDV38Olhehkf7o: DATA_TRACK,       // Team Data Eng 10 seats   $599/yr
  pdt_0No8cX2zJK81FG3NaA0st: PLATFORM_TRACK,   // Team Platform 5 seats    $499/yr
  pdt_0No8cX2tGb8qRo7UOMUqr: PLATFORM_TRACK,   // Team Platform 10 seats   $899/yr
  pdt_0No8cX2zJK81FG3VFNdPD: FULL_CATALOG,     // Team Full 5 seats        $899/yr
  pdt_0No8cX2xnVQggiN3WPjoA: FULL_CATALOG,     // Team Full 10 seats       $1,599/yr
  // Cohort
  pdt_0No8Kgf2Z4FOleEA96DEW: FULL_CATALOG,     // Classroom 30+2 seats     $3,499/yr
};

const PRODUCT_SEATS: Record<string, number> = {
  pdt_0No8cX2WdUc6FfZmRq6no: 5,    // Team Data Eng 5
  pdt_0No8cX2kDV38Olhehkf7o: 10,   // Team Data Eng 10
  pdt_0No8cX2zJK81FG3NaA0st: 5,    // Team Platform 5
  pdt_0No8cX2tGb8qRo7UOMUqr: 10,   // Team Platform 10
  pdt_0No8cX2zJK81FG3VFNdPD: 5,    // Team Full 5
  pdt_0No8cX2xnVQggiN3WPjoA: 10,   // Team Full 10
  pdt_0No8Kgf2Z4FOleEA96DEW: 30,   // Classroom
};

const CLASSROOM_PRODUCT = "pdt_0No8Kgf2Z4FOleEA96DEW";
const PRODUCT_ROLE: Record<string, LicenseRole> = {
  [CLASSROOM_PRODUCT]: "instructor-admin",
  // all others default to "learner"
};

const LICENSE_TERM_DAYS = 365;
const DAY_MS = 24 * 60 * 60 * 1000;

// LicenseRecord lives in catalog.ts — one definition shared by the webhook,
// classroom seat provisioning and the smoke-key minter.

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

async function sendLicenseEmail(env: Env, email: string, key: string, entitlements: string[], expiresAt: string, seats: number): Promise<boolean> {
  if (!env.RESEND_API_KEY) {
    console.error(`RESEND_API_KEY not set — license ${key} for ${email} NOT emailed`);
    return false;
  }
  const courseList = entitlements.map((e) => `  • ${e}`).join("\n");
  // Telegram Phase 1: team groups are provisioned manually within 24h.
  const telegramNote = seats > 1
    ? `---\nYour private Telegram group will be set up within 24 hours of purchase.\n` +
      `You will receive a separate email at this address with the invite link.\n` +
      `As the team admin you can invite your engineers directly from the group.\n\n`
    : "";
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
        telegramNote +
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

// A Dodo event payload, as much of it as this worker reads. Named rather than
// `any` so a field that stops arriving is a type error and not a silent null.
interface DodoEventData {
  payment_id?: string;
  subscription_id?: string;
  id?: string;
  product_id?: string;
  customer?: { email?: string };
  customer_email?: string;
  product_cart?: Array<{ product_id?: string }>;
  next_billing_date?: string;
}

// Where a subscription's licence is recorded, so renewals can find it. Payments
// are keyed on their own id; subscriptions get a second, stable pointer.
const subKey = (subscriptionId: string) => `sub:${subscriptionId}`;

// Resolves the licence a dispute or refund event refers to. Dispute payloads
// carry the payment id; subscription-derived ones carry the subscription id.
async function licenceFor(env: Env, data: DodoEventData): Promise<{ key: string; rec: LicenseRecord } | null> {
  const id = data.payment_id ?? data.id;
  const key = (id ? await env.ORDERS.get(id) : null)
    ?? (data.subscription_id ? await env.ORDERS.get(subKey(data.subscription_id)) : null);
  if (!key) return null;
  const rec = await env.LICENSES.get<LicenseRecord>(key, "json");
  return rec ? { key, rec } : null;
}

async function setRevoked(env: Env, data: DodoEventData, revoked: boolean, reason: string): Promise<void> {
  const found = await licenceFor(env, data);
  if (!found) return;
  const { key, rec } = found;

  if (revoked) {
    if (rec.revoked) return;
    rec.revoked = true;
    rec.revoked_at = new Date().toISOString();
    rec.revoked_reason = reason;
  } else {
    // Only undo a revocation this dispute caused. A refund, or a seat an
    // instructor revoked, must survive a dispute being withdrawn.
    if (!rec.revoked || rec.revoked_reason !== "dispute.opened") return;
    rec.revoked = false;
    rec.revoked_at = null;
    rec.revoked_reason = null;
  }
  await env.LICENSES.put(key, JSON.stringify(rec));
}

// Extends a licence for another term. Dodo sends next_billing_date on renewal;
// it is the authoritative end of the paid period, so it is preferred over
// adding a year locally and drifting from what the customer was charged for.
async function extendSubscription(env: Env, data: DodoEventData): Promise<void> {
  const found = await licenceFor(env, data);
  if (!found) {
    console.error(`subscription.renewed for unknown subscription ${data.subscription_id}`);
    return;
  }
  const { key, rec } = found;

  const next = data.next_billing_date ? Date.parse(data.next_billing_date) : NaN;
  // Extending from the current expiry, not from now, so a renewal processed
  // late does not cost the customer the days it was late by.
  const base = Math.max(Date.parse(rec.expires_at), Date.now());
  rec.expires_at = new Date(Number.isFinite(next) ? next : base + LICENSE_TERM_DAYS * DAY_MS).toISOString();

  // A renewal is also the moment a lapsed licence comes back.
  if (rec.revoked && rec.revoked_reason === "subscription.expired") {
    rec.revoked = false;
    rec.revoked_at = null;
    rec.revoked_reason = null;
  }
  await env.LICENSES.put(key, JSON.stringify(rec));
}

async function handleDodoWebhook(request: Request, env: Env): Promise<Response> {
  if (!env.DODO_WEBHOOK_SECRET || !env.HMAC_SECRET) {
    console.error("Webhook secrets not configured");
    return new Response("Not configured", { status: 503 });
  }

  const body = await request.text();
  if (!(await verifyDodoSignature(request, body, env.DODO_WEBHOOK_SECRET))) {
    return new Response("Unauthorized", { status: 401 });
  }

  let event: { type?: string; data?: DodoEventData };
  try {
    event = JSON.parse(body);
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }

  const type: string = event.type ?? "";
  const data = event.data ?? {};

  // Delivery-level idempotency. Dodo retries, and a retried renewal that is
  // processed twice extends a licence by two years. webhook-id is the Standard
  // Webhooks delivery id and is the only identifier every event type carries —
  // subscription events have no payment id to dedupe on. D1, not KV, because a
  // duplicate can arrive inside KV's consistency window (migration 0006).
  const webhookId = request.headers.get("webhook-id");
  if (webhookId) {
    const claim = await env.CLASSROOM_DB.prepare(
      `INSERT OR IGNORE INTO webhook_events (webhook_id, event_type) VALUES (?, ?)`,
    ).bind(webhookId, type).run();
    if ((claim.meta?.changes ?? 0) === 0) return new Response("OK");
  }

  // Dodo publishes two spellings of the success suffix across its own docs and
  // CLI, and we have no way to tell from the outside which one the account
  // actually sends — a wrong guess means refunds silently never revoke. Both
  // are accepted; the cost is one array, and no test we can write would catch
  // the mistake, because our fixtures sign whatever name we believe in.
  const isType = (...names: string[]) => names.includes(type);

  // Money taken back → revoke. dispute.opened is provisional: the money is held
  // but not yet lost, and we revoke to stop further use while it is contested.
  if (isType("refund.succeeded", "refund.success", "dispute.opened", "dispute.lost")) {
    await setRevoked(env, data, true, type);
    return new Response("OK");
  }

  // Dispute resolved in our favour, or withdrawn: the money stays with us, so
  // access must come back. Revoking here — which this handler used to do for
  // dispute.won — punished a customer whose chargeback had already failed.
  // Only a revocation this dispute caused is undone; a refund or an instructor
  // revoking a seat is left alone.
  if (isType("dispute.won", "dispute.cancelled")) {
    await setRevoked(env, data, false, type);
    return new Response("OK");
  }

  // Renewal. Dodo's guidance is to extend on subscription.renewed rather than
  // on the payment: the renewal charge arrives as its own payment.succeeded
  // with a new payment id, which this handler used to treat as a brand new
  // purchase — minting a second key and emailing it while the original expired.
  if (isType("subscription.renewed")) {
    await extendSubscription(env, data);
    return new Response("OK");
  }

  if (!isType("payment.succeeded", "payment.success")) return new Response("OK");

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
  const record: LicenseRecord = buildLicenseRecord({
    key,
    email,
    product_id: productId,
    entitlements,
    order_id: orderId,
    seats: PRODUCT_SEATS[productId] ?? 1,
    role: PRODUCT_ROLE[productId] ?? "learner",
    expires_at: new Date(now + LICENSE_TERM_DAYS * DAY_MS).toISOString(),
  });

  await env.LICENSES.put(key, JSON.stringify(record));
  await env.ORDERS.put(orderId, key);

  // Renewals arrive as subscription events carrying only the subscription id,
  // so record that pointer now. Without it a renewal cannot find the licence it
  // is meant to extend and falls back to logging an unknown subscription.
  const subscriptionId: string | undefined = data.subscription_id;
  if (subscriptionId) await env.ORDERS.put(subKey(subscriptionId), key);

  await sendLicenseEmail(env, email, key, entitlements, record.expires_at, record.seats);
  return new Response("OK");
}

// How stale last_seen_at may get before a validate refreshes it. The CLI
// revalidates on a 24h cache cycle but calls through on every gate when the
// cache is cold, so without this a busy learner would write on every command.
const LAST_SEEN_STALE_AFTER = "-1 hour";

// One statement does all three things, so there is no window where a member is
// half-promoted:
//   - 'invited' becomes 'active' (any other status, including 'revoked', is left alone)
//   - activated_at is stamped once and never overwritten
//   - last_seen_at moves only when it is missing or older than the window
// The WHERE clause excludes revoked members outright: a revoked seat must stay
// revoked even if a stale KV record still validates during propagation.
async function touchClassroomMember(env: Env, classroomId: string, memberId: string): Promise<void> {
  await env.CLASSROOM_DB.prepare(
    `UPDATE members
        SET status       = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
            activated_at = COALESCE(activated_at, datetime('now')),
            last_seen_at = CASE
                             WHEN last_seen_at IS NULL
                               OR last_seen_at < datetime('now', '${LAST_SEEN_STALE_AFTER}')
                             THEN datetime('now')
                             ELSE last_seen_at
                           END
      WHERE id = ? AND classroom_id = ? AND status != 'revoked'`,
  ).bind(memberId, classroomId).run();
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

  // Classroom keys also update the roster so an instructor can see who has
  // actually started. Deliberately non-fatal: a learner must never be locked
  // out of their course because a statistics write failed.
  if (license.classroom_id && license.member_id) {
    try {
      await touchClassroomMember(env, license.classroom_id, license.member_id);
    } catch (e) {
      console.error(`roster touch failed for ${license.member_id}: ${e}`);
    }
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
    // Present only on classroom-issued keys; 7C uses these to attribute
    // progress events without the CLI having to be told where it belongs.
    ...(license.classroom_id ? { classroom_id: license.classroom_id, member_id: license.member_id } : {}),
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const { method } = request;

    if (method === "OPTIONS") {
      // Classroom routes are credentialed, so they need the origin echoed back;
      // the license routes stay wildcard-open.
      if (url.pathname.startsWith("/v1/")) {
        return new Response(null, { headers: corsHeaders(request) });
      }
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    if (url.pathname.startsWith("/v1/")) {
      const handled = await routeClassroom(request, env);
      if (handled) return handled;
    }

    if (method === "GET" && url.pathname === "/health") {
      return json({ status: "ok", worker: "practicum-api", env: env.ENVIRONMENT });
    }
    if (method === "POST" && url.pathname === "/webhooks/dodo") return handleDodoWebhook(request, env);
    if (method === "GET" && url.pathname === "/license/validate") return handleValidate(request, env);

    return new Response("Not found", { status: 404 });
  },
};
