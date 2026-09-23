// Sprint 7A — Classroom foundation: magic-link auth, sessions, classroom summary.
//
// Instructors authenticate by email, never by license key: keys get pasted into
// terminals and screenshares, and this dashboard shows student PII.
//   POST /v1/auth/magic-link  → single-use token in SESSIONS (15 min), emailed
//   GET  /v1/auth/verify      → exchanges it for a session cookie, 302 /dashboard
//   POST /v1/auth/logout      → drops the session
//   GET  /v1/classroom        → summary for the session's classroom
//   GET  /v1/content/manifest → public, cached
//
// Every instructor route is scoped to the classroom on the session. A classroom
// id from the client is never trusted.

import manifest from "../../../content/manifest.json";
import { routeRoster, type RosterEnv } from "./roster";
import { handleProgress, type ProgressEnv } from "./progress";
import { buildLicenseRecord, licenseKeyFrom, type LicenseRecord } from "./catalog";

export interface ClassroomEnv {
  CLASSROOM_DB: D1Database;
  SESSIONS: KVNamespace;
  RESEND_API_KEY?: string;
  DASHBOARD_ORIGIN?: string;
  // Gates the only sanctioned production test path: the X-Smoke-Secret header
  // on /v1/auth/magic-link. Unset means no request can ever obtain a token.
  SMOKE_TOKEN_SECRET?: string;
}

// Licenses issued inside a test classroom are short-lived, so a key that
// escapes a smoke run cannot be used for long. Used by 7B when it mints
// learner keys; smoke also revokes every key it issues.
export const TEST_LICENSE_TTL_HOURS = 24;

const ORIGIN = "https://practicum-cli.dev";
const MAGIC_TTL_SEC = 15 * 60;
const SESSION_TTL_SEC = 7 * 24 * 60 * 60;
const COOKIE = "practicum_session";
// Smoke classrooms (is_test = 1) send nowhere real.
const TEST_EMAIL_SINK = "delivered@resend.dev";

// --- helpers ---------------------------------------------------------------

export function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("Origin");
  const local = !!origin && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  const allowed = origin === ORIGIN || local ? (origin as string) : ORIGIN;
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-License-Key",
    Vary: "Origin",
  };
}

const json = (request: Request, data: unknown, status = 200, extra: Record<string, string> = {}) =>
  Response.json(data, { status, headers: { ...corsHeaders(request), ...extra } });

// Sortable, collision-resistant id: <prefix>_<base36 time><random>.
export function newId(prefix: string): string {
  const t = Date.now().toString(36).padStart(9, "0");
  const r = Array.from(crypto.getRandomValues(new Uint8Array(10)))
    .map((b) => (b % 32).toString(32))
    .join("");
  return `${prefix}_${t}${r}`;
}

function randomToken(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Compares SHA-256 digests rather than the strings themselves: equal-length
// inputs, so neither the comparison nor an early length check leaks anything
// about the configured secret.
async function secretMatches(provided: string | null, expected: string | undefined): Promise<boolean> {
  if (!expected || !provided) return false;
  const a = await sha256Hex(provided.trim());
  const b = await sha256Hex(expected.trim());
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const normaliseEmail = (raw: string) => raw.trim().toLowerCase();
// Deliberately permissive: real validation is whether the link is received.
const isEmail = (v: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);

// Accepts form-encoded or JSON so the CLI never has to build JSON.
export async function readBody(request: Request): Promise<Record<string, string>> {
  const type = request.headers.get("Content-Type") ?? "";
  try {
    if (type.includes("application/json")) {
      const parsed = await request.json();
      const out: Record<string, string> = {};
      for (const [k, v] of Object.entries(parsed as Record<string, unknown>)) {
        if (v !== null && v !== undefined) out[k] = String(v);
      }
      return out;
    }
    const form = await request.formData();
    const out: Record<string, string> = {};
    for (const [k, v] of form.entries()) out[k] = String(v);
    return out;
  } catch {
    return {};
  }
}

// --- sessions --------------------------------------------------------------

export interface Session {
  member_id: string;
  classroom_id: string;
  email: string;
  role: string;
}

function cookieValue(header: string | null, name: string): string | null {
  if (!header) return null;
  for (const part of header.split(";")) {
    const [k, ...rest] = part.trim().split("=");
    if (k === name) return rest.join("=");
  }
  return null;
}

export async function getSession(request: Request, env: ClassroomEnv): Promise<Session | null> {
  const sid = cookieValue(request.headers.get("Cookie"), COOKIE);
  if (!sid) return null;
  return env.SESSIONS.get<Session>(`sess:${sid}`, "json");
}

// Domain and Secure are set only on the real host: a Domain attribute for
// practicum-cli.dev is rejected outright when the worker is reached on
// localhost, which would make the whole dashboard untestable locally.
function sessionCookie(request: Request, sid: string, maxAge: number): string {
  // `wrangler dev` rewrites request.url to the configured custom domain, so the
  // hostname is the same locally and in production — the scheme is what differs,
  // and a Secure cookie is meaningless over http in any case.
  const url = new URL(request.url);
  const production = url.protocol === "https:" && url.hostname.endsWith("practicum-cli.dev");
  const parts = [`${COOKIE}=${sid}`, "HttpOnly", "SameSite=Lax", "Path=/", `Max-Age=${maxAge}`];
  if (production) parts.push("Secure", "Domain=.practicum-cli.dev");
  return parts.join("; ");
}

// --- email -----------------------------------------------------------------

async function sendMagicLinkEmail(
  env: ClassroomEnv,
  to: string,
  link: string,
  classroomName: string,
  isTest: boolean,
  qaMailTo: string | null,
): Promise<void> {
  // A test classroom sends to its QA address when one is set, else the sink.
  const recipient = isTest ? (qaMailTo ?? TEST_EMAIL_SINK) : to;
  if (!env.RESEND_API_KEY) {
    console.error(`RESEND_API_KEY not set — magic link for ${recipient} NOT emailed`);
    return;
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: "Practicum CLI <practicum@mpingo.ai>",
      to: recipient,
      subject: "Your Practicum dashboard sign-in link",
      text:
        `Sign in to the ${classroomName} dashboard:\n\n${link}\n\n` +
        `The link works once and expires in 15 minutes.\n` +
        `If you did not request it you can ignore this email.\n\n` +
        `Practicum CLI\nhttps://practicum-cli.dev`,
    }),
  });
  if (!res.ok) console.error(`Resend failed (${res.status}) for ${recipient}: ${await res.text()}`);
}

// --- routes ----------------------------------------------------------------

// POST /v1/auth/magic-link — always 200, never reveals whether an account exists.
async function handleMagicLink(request: Request, env: ClassroomEnv): Promise<Response> {
  const body = await readBody(request);
  const email = normaliseEmail(body.email ?? "");
  const ok = { ok: true, message: "If that address can access a classroom, a sign-in link is on its way." };

  if (!isEmail(email)) return json(request, ok);

  const row = await env.CLASSROOM_DB.prepare(
    `SELECT m.id AS member_id, m.classroom_id, m.email, m.role,
            c.name AS classroom_name, c.is_test, c.qa_mail_to, c.status
       FROM members m
       JOIN classrooms c ON c.id = m.classroom_id
      WHERE m.email = ? AND m.role = 'instructor' AND m.status = 'active'
        AND c.status IN ('active','grace')
        AND c.expires_at > datetime('now')
      LIMIT 1`,
  )
    .bind(email)
    .first<{
      member_id: string;
      classroom_id: string;
      email: string;
      role: string;
      classroom_name: string;
      is_test: number;
      qa_mail_to: string | null;
    }>();

  // Unknown address, learner address, expired classroom: identical response.
  if (!row) return json(request, ok);

  const token = randomToken();
  await env.SESSIONS.put(
    `magic:${await sha256Hex(token)}`,
    JSON.stringify({ member_id: row.member_id, classroom_id: row.classroom_id, email: row.email, role: row.role }),
    { expirationTtl: MAGIC_TTL_SEC },
  );

  // The link must point at the API worker, which is where /v1/auth/verify
  // lives — the dashboard origin serves static assets only and would 404.
  // Taken from the request so local dev links back to the dev server.
  const base = new URL(request.url).origin;
  const verifyUrl = `${base}/v1/auth/verify?token=${token}`;
  await sendMagicLinkEmail(
    env,
    email,
    verifyUrl,
    row.classroom_name,
    row.is_test === 1,
    row.qa_mail_to,
  );

  await env.CLASSROOM_DB.prepare(
    `INSERT INTO audit_log (classroom_id, actor, action, detail) VALUES (?, ?, 'auth.magic_link_sent', ?)`,
  )
    .bind(row.classroom_id, row.member_id, email)
    .run();

  // The token is handed back only to a caller that proves it holds the smoke
  // secret, and only for a test classroom. Every other caller — no header,
  // wrong header, right header but a real classroom, or no secret configured
  // at all — gets the byte-identical body an unknown address receives.
  const authorised = row.is_test === 1 && (await secretMatches(request.headers.get("X-Smoke-Secret"), env.SMOKE_TOKEN_SECRET));
  // test_verify_url is the exact link the email carries, so smoke asserts the
  // real thing rather than a URL it assembled itself — which is how a link
  // pointing at the wrong host reached production unnoticed.
  if (authorised) return json(request, { ...ok, test_token: token, test_verify_url: verifyUrl });
  return json(request, ok);
}

// GET /v1/auth/verify?token=... — single use; consumed whether or not it works.
async function handleVerify(request: Request, env: ClassroomEnv): Promise<Response> {
  const token = new URL(request.url).searchParams.get("token") ?? "";
  const retry = (msg: string) =>
    new Response(retryPage(msg), { status: 400, headers: { "Content-Type": "text/html; charset=utf-8" } });

  if (!token) return retry("That sign-in link is missing its token.");

  const hash = await sha256Hex(token);
  const key = `magic:${hash}`;
  const payload = await env.SESSIONS.get<Session>(key, "json");
  if (!payload) return retry("That sign-in link has expired or has already been used.");

  // Single use is enforced in D1, not by the KV delete below: KV is eventually
  // consistent, so a deleted token can still read back from an edge cache for a
  // short window. An INSERT reporting 0 changes proves this token was already
  // spent, whatever KV says.
  const claim = await env.CLASSROOM_DB.prepare(
    `INSERT OR IGNORE INTO consumed_tokens (token_hash) VALUES (?)`,
  ).bind(hash).run();
  if ((claim.meta?.changes ?? 0) === 0) {
    return retry("That sign-in link has already been used.");
  }

  await env.SESSIONS.delete(key);   // best-effort cleanup

  // Re-check standing at redemption: a seat revoked since the send must not open.
  const still = await env.CLASSROOM_DB.prepare(
    `SELECT 1 FROM members m JOIN classrooms c ON c.id = m.classroom_id
      WHERE m.id = ? AND m.status = 'active' AND m.role = 'instructor'
        AND c.status IN ('active','grace') AND c.expires_at > datetime('now')`,
  )
    .bind(payload.member_id)
    .first();
  if (!still) return retry("That account no longer has dashboard access.");

  const sid = randomToken();
  await env.SESSIONS.put(`sess:${sid}`, JSON.stringify(payload), { expirationTtl: SESSION_TTL_SEC });

  return new Response(null, {
    status: 302,
    // Absolute: verify runs on the API host, so a relative Location would send
    // the instructor to api.practicum-cli.dev/dashboard/, which does not exist.
    // The cookie's Domain=.practicum-cli.dev covers both hosts.
    headers: {
      Location: `${env.DASHBOARD_ORIGIN ?? ORIGIN}/dashboard/`,
      "Set-Cookie": sessionCookie(request, sid, SESSION_TTL_SEC),
    },
  });
}

async function handleLogout(request: Request, env: ClassroomEnv): Promise<Response> {
  const sid = cookieValue(request.headers.get("Cookie"), COOKIE);
  if (sid) await env.SESSIONS.delete(`sess:${sid}`);
  return json(request, { ok: true }, 200, { "Set-Cookie": sessionCookie(request, "", 0) });
}

// GET /v1/classroom — summary for the session's classroom only.
async function handleClassroomSummary(request: Request, env: ClassroomEnv, session: Session): Promise<Response> {
  const room = await env.CLASSROOM_DB.prepare(
    `SELECT id, name, status, learner_limit, instructor_limit, expires_at, grace_until,
            telegram_invite_url, qa_mail_to, is_test
       FROM classrooms WHERE id = ?`,
  )
    .bind(session.classroom_id)
    .first<{
      id: string;
      name: string;
      status: string;
      learner_limit: number;
      instructor_limit: number;
      expires_at: string;
      grace_until: string | null;
      telegram_invite_url: string | null;
      qa_mail_to: string | null;
      is_test: number;
    }>();
  if (!room) return json(request, { error: "Classroom not found" }, 404);

  const seats = await env.CLASSROOM_DB.prepare(
    `SELECT role, COUNT(*) AS n FROM members
      WHERE classroom_id = ? AND status IN ('invited','active') GROUP BY role`,
  )
    .bind(session.classroom_id)
    .all<{ role: string; n: number }>();

  const used = { learner: 0, instructor: 0 };
  for (const r of seats.results ?? []) {
    if (r.role === "learner") used.learner = r.n;
    if (r.role === "instructor") used.instructor = r.n;
  }

  return json(request, {
    classroom: {
      id: room.id,
      name: room.name,
      status: room.status,
      expires_at: room.expires_at,
      grace_until: room.grace_until,
      telegram_invite_url: room.telegram_invite_url,
      is_test: room.is_test === 1,
      qa_mail_to: room.qa_mail_to,
    },
    seats: {
      learners: { used: used.learner, limit: room.learner_limit },
      instructors: { used: used.instructor, limit: room.instructor_limit },
    },
    signed_in_as: { email: session.email, role: session.role, member_id: session.member_id },
  });
}

// A solo license for smoke use: one course, far-future expiry, is_test set.
// Built by the same buildLicenseRecord() the Dodo webhook uses, so if the
// record shape drifts this fixture drifts with it and the suite notices.
const SMOKE_SOLO_PRODUCT = "pdt_0No8cX1sZ1XCttHIl5fh3";   // Linux Foundations, $49/yr
const SMOKE_SOLO_EMAIL = "smoke-solo@practicum-cli.dev";

async function handleMintSmokeSolo(request: Request, env: ClassroomEnv & RosterEnv): Promise<Response> {
  if (!env.HMAC_SECRET) return json(request, { error: "HMAC_SECRET not configured" }, 503);

  const orderId = `smoke-solo:${SMOKE_SOLO_EMAIL}`;   // stable: re-running replaces, never accumulates
  const key = await licenseKeyFrom(orderId, env.HMAC_SECRET);
  const record = buildLicenseRecord({
    key,
    email: SMOKE_SOLO_EMAIL,
    product_id: SMOKE_SOLO_PRODUCT,
    entitlements: ["linux-foundations"],
    order_id: orderId,
    expires_at: new Date(Date.UTC(2099, 0, 1)).toISOString(),
    is_test: true,
  });
  await env.LICENSES.put(key, JSON.stringify(record));

  return json(request, {
    ok: true,
    key,
    email: record.email,
    entitlements: record.entitlements,
    expires_at: record.expires_at,
    is_test: true,
  });
}

// One-off repair for keys activated before 7C-0 existed: KV knows they were
// activated, but their roster row was never promoted, so instructors see every
// learner as never-started. Dry by default — it reports what it would change
// and writes nothing unless apply=1.
async function handleBackfillActivation(request: Request, env: ClassroomEnv & RosterEnv): Promise<Response> {
  const apply = new URL(request.url).searchParams.get("apply") === "1";
  let scanned = 0, classroomKeys = 0, activatedKeys = 0, promoted = 0, skippedRevoked = 0, alreadyActive = 0;
  const samples: string[] = [];

  let cursor: string | undefined;
  do {
    const page = await env.LICENSES.list({ cursor, limit: 1000 });
    cursor = page.list_complete ? undefined : page.cursor;

    for (const entry of page.keys) {
      scanned++;
      const rec = await env.LICENSES.get<LicenseRecord>(entry.name, "json");
      if (!rec?.classroom_id || !rec.member_id) continue;
      classroomKeys++;
      if (!rec.activated) continue;
      activatedKeys++;

      const member = await env.CLASSROOM_DB.prepare(
        `SELECT status FROM members WHERE id = ? AND classroom_id = ?`,
      ).bind(rec.member_id, rec.classroom_id).first<{ status: string }>();
      if (!member) continue;
      if (member.status === "revoked") { skippedRevoked++; continue; }
      if (member.status !== "invited") { alreadyActive++; continue; }

      promoted++;
      if (samples.length < 5) samples.push(rec.member_id);
      if (apply) {
        await env.CLASSROOM_DB.prepare(
          `UPDATE members
              SET status = 'active',
                  activated_at = COALESCE(activated_at, ?)
            WHERE id = ? AND classroom_id = ? AND status = 'invited'`,
        ).bind(rec.activated_at ?? new Date().toISOString(), rec.member_id, rec.classroom_id).run();
      }
    }
  } while (cursor);

  return json(request, {
    applied: apply,
    scanned_keys: scanned,
    classroom_keys: classroomKeys,
    activated_classroom_keys: activatedKeys,
    would_promote: promoted,
    skipped_revoked: skippedRevoked,
    already_active: alreadyActive,
    sample_member_ids: samples,
  });
}

function retryPage(message: string): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sign-in link problem</title><style>
:root{color-scheme:dark;--bg:#1a1b2e;--bg2:#232438;--g:#2ecc71;--w:#fff;--t:#94a3b8;--br:#2d2e42}
body{margin:0;min-height:100vh;display:grid;place-items:center;background:var(--bg);color:var(--t);
font-family:system-ui,-apple-system,sans-serif;padding:16px}
.card{background:var(--bg2);border:1px solid var(--br);border-radius:8px;padding:2rem;max-width:26rem}
h1{font-family:'JetBrains Mono',ui-monospace,monospace;color:var(--w);font-size:1.1rem;margin:0 0 .75rem}
p{line-height:1.7;margin:0 0 1.25rem}
a{display:inline-block;font-family:'JetBrains Mono',ui-monospace,monospace;font-size:.9rem;font-weight:600;
padding:.85rem 2rem;background:var(--g);color:var(--bg);border-radius:6px;text-decoration:none}
</style></head><body><div class="card"><h1>Sign-in link problem</h1>
<p>${message}</p><a href="/dashboard/">Request a new link</a></div></body></html>`;
}

// --- router ----------------------------------------------------------------

export async function routeClassroom(request: Request, env: ClassroomEnv): Promise<Response | null> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/$/, "") || "/";
  const method = request.method;

  if (path === "/v1/content/manifest" && method === "GET") {
    return Response.json(manifest, {
      headers: { ...corsHeaders(request), "Cache-Control": "public, max-age=3600" },
    });
  }

  // Mints the synthetic solo license the smoke suite validates against, so no
  // customer key is ever used as a fixture. Gated on the same X-Smoke-Secret as
  // the magic-link test path — the only sanctioned production test entry point.
  // The record is is_test, so it is excluded from customer and revenue counts.
  if (path === "/v1/admin/backfill-activation" && method === "POST") {
    if (!(await secretMatches(request.headers.get("X-Smoke-Secret"), env.SMOKE_TOKEN_SECRET))) {
      return new Response("Not found", { status: 404 });
    }
    return handleBackfillActivation(request, env as ClassroomEnv & RosterEnv);
  }

  if (path === "/v1/admin/mint-smoke-solo" && method === "POST") {
    if (!(await secretMatches(request.headers.get("X-Smoke-Secret"), env.SMOKE_TOKEN_SECRET))) {
      return new Response("Not found", { status: 404 });
    }
    return handleMintSmokeSolo(request, env as ClassroomEnv & RosterEnv);
  }

  // Learner-facing, authenticated by license key rather than a session.
  if (path === "/v1/progress" && method === "POST") {
    return handleProgress(request, env as ClassroomEnv & ProgressEnv);
  }

  if (path === "/v1/auth/magic-link" && method === "POST") return handleMagicLink(request, env);
  if (path === "/v1/auth/verify" && method === "GET") return handleVerify(request, env);
  if (path === "/v1/auth/logout" && method === "POST") return handleLogout(request, env);

  // Everything below needs a session, and is scoped to that session's classroom.
  if (path === "/v1/classroom" || path.startsWith("/v1/classroom/")) {
    const session = await getSession(request, env);
    if (!session) return json(request, { error: "Not signed in" }, 401);

    if (path === "/v1/classroom" && method === "GET") return handleClassroomSummary(request, env, session);

    const roster = await routeRoster(request, env as ClassroomEnv & RosterEnv, session, path);
    if (roster) return roster;
  }

  return null; // not a classroom route
}
