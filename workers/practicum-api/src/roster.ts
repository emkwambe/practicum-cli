// Sprint 7B — seats and roster.
//
//   GET    /v1/classroom/members
//   POST   /v1/classroom/members             { email, display_name?, role }
//   POST   /v1/classroom/members/import      text/csv
//   POST   /v1/classroom/members/:id/resend
//   DELETE /v1/classroom/members/:id
//
// D1 and KV are not transactional, so every operation is ordered to fail safe:
//
//   invite  D1 conditional insert (seat cap enforced in the statement) →
//           KV licence write (on failure, delete the D1 row) →
//           email (on failure, keep the seat, email_status = 'failed')
//   revoke  KV disable first → then mark revoked in D1
//           (a crash between the two leaves a dead key holding a seat, which an
//            instructor can see and clear; the reverse would leave a freed seat
//            with a key that still validates)
//   resend  write new KV key → update D1 hash/prefix → disable old KV key
//           (the learner is never without a working key)

import { FULL_CATALOG, licenseKeyFrom, sha256Hex, type LicenseRecord, type LicenseRole } from "./catalog";
import { TEST_LICENSE_TTL_HOURS, type ClassroomEnv, type Session, newId, readBody, corsHeaders } from "./classroom";

export interface RosterEnv extends ClassroomEnv {
  LICENSES: KVNamespace;
  HMAC_SECRET?: string;
}

const CSV_MAX_BYTES = 64 * 1024;
const CSV_MAX_ROWS = 100;
const RATE_LIMIT = { invite: 60, import: 5 }; // per session, per hour
const TEST_EMAIL_SINK = "delivered@resend.dev";
const CLASSROOM_PRODUCT = "pdt_0No8Kgf2Z4FOleEA96DEW";

const json = (request: Request, data: unknown, status = 200) =>
  Response.json(data, { status, headers: corsHeaders(request) });

export const normaliseEmail = (raw: string) => raw.trim().toLowerCase();
export const isEmail = (v: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);

async function audit(env: RosterEnv, classroom_id: string, actor: string, action: string, detail: string) {
  await env.CLASSROOM_DB.prepare(
    `INSERT INTO audit_log (classroom_id, actor, action, detail) VALUES (?, ?, ?, ?)`,
  ).bind(classroom_id, actor, action, detail).run();
}

// Per-session hourly window. Scoped to the session rather than the member so a
// compromised or runaway tab is contained without locking the instructor out of
// their own classroom from another device. The cost being controlled is
// outbound email, not compute.
function sessionId(request: Request): string {
  const header = request.headers.get("Cookie") ?? "";
  for (const part of header.split(";")) {
    const [k, ...rest] = part.trim().split("=");
    if (k === "practicum_session") return rest.join("=");
  }
  return "anon";
}

async function rateLimited(
  request: Request,
  env: RosterEnv,
  session: Session,
  bucket: keyof typeof RATE_LIMIT,
): Promise<boolean> {
  const sid = (await sha256Hex(sessionId(request))).slice(0, 24);
  const key = `rl:${bucket}:${sid}:${Math.floor(Date.now() / 3_600_000)}`;
  const used = Number((await env.SESSIONS.get(key)) ?? "0");
  if (used >= RATE_LIMIT[bucket]) return true;
  await env.SESSIONS.put(key, String(used + 1), { expirationTtl: 3600 });
  return false;
}

interface ClassroomRow {
  id: string;
  name: string;
  expires_at: string;
  telegram_invite_url: string | null;
  is_test: number;
  learner_limit: number;
  instructor_limit: number;
}

const loadClassroom = (env: RosterEnv, id: string) =>
  env.CLASSROOM_DB.prepare(
    `SELECT id, name, expires_at, telegram_invite_url, is_test, learner_limit, instructor_limit
       FROM classrooms WHERE id = ?`,
  ).bind(id).first<ClassroomRow>();

// Licence expiry for a seat: the classroom's own date, or a short TTL in a test
// classroom so a key that escapes a smoke run dies on its own.
function seatExpiry(room: ClassroomRow): string {
  if (room.is_test === 1) return new Date(Date.now() + TEST_LICENSE_TTL_HOURS * 3600_000).toISOString();
  return room.expires_at.includes("T") ? room.expires_at : room.expires_at.replace(" ", "T") + "Z";
}

async function writeLicense(
  env: RosterEnv,
  opts: { key: string; email: string; role: LicenseRole; room: ClassroomRow; member_id: string },
): Promise<void> {
  const expires_at = seatExpiry(opts.room);
  const record: LicenseRecord = {
    key: opts.key,
    email: opts.email,
    product_id: CLASSROOM_PRODUCT,
    entitlements: FULL_CATALOG,
    order_id: `classroom:${opts.room.id}:${opts.member_id}`,
    seats: 1,
    role: opts.role,
    created_at: new Date().toISOString(),
    expires_at,
    activated: false,
    activated_at: null,
    revoked: false,
    revoked_at: null,
    revoked_reason: null,
    classroom_id: opts.room.id,
    member_id: opts.member_id,
  };
  await env.LICENSES.put(opts.key, JSON.stringify(record));
}

async function disableLicense(env: RosterEnv, key: string, reason: string): Promise<void> {
  const rec = await env.LICENSES.get<LicenseRecord>(key, "json");
  if (!rec) return;
  rec.revoked = true;
  rec.revoked_at = new Date().toISOString();
  rec.revoked_reason = reason;
  await env.LICENSES.put(key, JSON.stringify(rec));
}

async function sendInviteEmail(
  env: RosterEnv,
  opts: { to: string; key: string; role: LicenseRole; room: ClassroomRow },
): Promise<boolean> {
  const recipient = opts.room.is_test === 1 ? TEST_EMAIL_SINK : opts.to;
  if (!env.RESEND_API_KEY) {
    console.error(`RESEND_API_KEY not set — invite for ${recipient} NOT emailed`);
    return false;
  }
  const telegram = opts.room.telegram_invite_url
    ? `\nYour class group:\n  ${opts.room.telegram_invite_url}\n`
    : "";
  const dashboard = opts.role === "instructor-admin"
    ? `\nYou also have dashboard access. Sign in at https://practicum-cli.dev/dashboard/ with this address.\n`
    : "";

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: "Practicum CLI <practicum@mpingo.ai>",
      to: recipient,
      subject: `Your seat in ${opts.room.name}`,
      text:
        `You have a seat in ${opts.room.name}.\n\n` +
        `Install and activate in one line:\n` +
        `  curl -sL https://practicum-cli.dev/install.sh | bash && practicum activate ${opts.key}\n\n` +
        `Your licence key:\n  ${opts.key}\n` +
        telegram +
        dashboard +
        `\nYour lesson and lab progress in this classroom is shared with your instructor.\n` +
        `Practicum CLI\nhttps://practicum-cli.dev\n`,
    }),
  });
  if (!res.ok) console.error(`Resend failed (${res.status}) for ${recipient}: ${await res.text()}`);
  return res.ok;
}

// --- invite ------------------------------------------------------------------

type InviteOutcome =
  | { ok: true; member_id: string; key: string; email: string; email_status: string }
  | { ok: false; status: number; error: string };

async function inviteOne(
  env: RosterEnv,
  session: Session,
  room: ClassroomRow,
  rawEmail: string,
  displayName: string | null,
  role: LicenseRole,
): Promise<InviteOutcome> {
  const email = normaliseEmail(rawEmail);
  if (!isEmail(email)) return { ok: false, status: 400, error: "invalid email" };
  if (!env.HMAC_SECRET) return { ok: false, status: 503, error: "key issuance unavailable" };

  const memberId = newId("mem");
  const dbRole = role === "instructor-admin" ? "instructor" : "learner";
  const limitColumn = dbRole === "learner" ? "learner_limit" : "instructor_limit";

  // Seat cap is enforced inside the INSERT: two simultaneous invites cannot
  // both take the last seat, because the count is evaluated by the same
  // statement that writes the row. 0 changes means the cap was already met.
  let inserted;
  try {
    inserted = await env.CLASSROOM_DB.prepare(
      `INSERT INTO members (id, classroom_id, role, email, display_name, status, email_status)
       SELECT ?, ?, ?, ?, ?, 'invited', 'pending'
        WHERE (SELECT COUNT(*) FROM members
                WHERE classroom_id = ? AND role = ? AND status IN ('invited','active'))
            < (SELECT ${limitColumn} FROM classrooms WHERE id = ?)`,
    ).bind(memberId, room.id, dbRole, email, displayName, room.id, dbRole, room.id).run();
  } catch (e) {
    // UNIQUE (classroom_id, email)
    if (String(e).includes("UNIQUE")) return { ok: false, status: 409, error: "already on this roster" };
    throw e;
  }

  if ((inserted.meta?.changes ?? 0) === 0) {
    const limit = dbRole === "learner" ? room.learner_limit : room.instructor_limit;
    return { ok: false, status: 409, error: `no ${dbRole} seats left (${limit} of ${limit} used)` };
  }

  const key = await licenseKeyFrom(`${memberId}:0`, env.HMAC_SECRET);

  // KV write next. If it fails the seat must not stay taken, so the D1 row goes.
  try {
    await writeLicense(env, { key, email, role, room, member_id: memberId });
  } catch (e) {
    await env.CLASSROOM_DB.prepare(`DELETE FROM members WHERE id = ?`).bind(memberId).run();
    console.error(`KV write failed for ${memberId}, seat released: ${e}`);
    return { ok: false, status: 502, error: "could not issue a licence key — seat released, try again" };
  }

  await env.CLASSROOM_DB.prepare(
    `UPDATE members SET license_key_prefix = ?, license_key_hash = ? WHERE id = ?`,
  ).bind(key.slice(0, 8), await sha256Hex(key), memberId).run();

  // Email last: a failure here costs the invite, not the seat.
  const sent = await sendInviteEmail(env, { to: email, key, role, room });
  await env.CLASSROOM_DB.prepare(`UPDATE members SET email_status = ? WHERE id = ?`)
    .bind(sent ? "sent" : "failed", memberId).run();

  await audit(env, room.id, session.member_id, "member.invited", `${email} (${dbRole}, email ${sent ? "sent" : "failed"})`);
  return { ok: true, member_id: memberId, key, email, email_status: sent ? "sent" : "failed" };
}

// --- routes ------------------------------------------------------------------

async function listMembers(request: Request, env: RosterEnv, session: Session): Promise<Response> {
  const rows = await env.CLASSROOM_DB.prepare(
    `SELECT id, role, email, display_name, status, email_status, license_key_prefix,
            invited_at, activated_at, last_seen_at, revoked_at, rotations
       FROM members WHERE classroom_id = ?
      ORDER BY role DESC, CASE status WHEN 'revoked' THEN 1 ELSE 0 END, email`,
  ).bind(session.classroom_id).all();
  return json(request, { members: rows.results ?? [] });
}

async function createMember(request: Request, env: RosterEnv, session: Session): Promise<Response> {
  if (await rateLimited(request, env, session, "invite")) {
    return json(request, { error: "Too many invites this hour. Try again shortly." }, 429);
  }
  const room = await loadClassroom(env, session.classroom_id);
  if (!room) return json(request, { error: "Classroom not found" }, 404);

  const body = await readBody(request);
  const role: LicenseRole = body.role === "instructor" || body.role === "instructor-admin" ? "instructor-admin" : "learner";
  const result = await inviteOne(env, session, room, body.email ?? "", body.display_name?.trim() || null, role);

  if (!result.ok) return json(request, { error: result.error }, result.status);
  // The key itself is never returned to the browser — it goes to the learner by
  // email only. The prefix is enough for support lookups.
  return json(request, {
    member_id: result.member_id,
    email: result.email,
    role,
    key_prefix: result.key.slice(0, 8),
    email_status: result.email_status,
    // Smoke needs the key to prove the licence validates; test classrooms only.
    ...(room.is_test === 1 ? { test_key: result.key } : {}),
  }, 201);
}

// Accepts an optional header row; one record per line, "email,display_name".
function parseCsv(text: string): { rows: Array<{ email: string; name: string | null }>; skipped: number } {
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 0);
  if (lines.length && /^\s*e-?mail\b/i.test(lines[0])) lines.shift();
  const rows: Array<{ email: string; name: string | null }> = [];
  let skipped = 0;
  for (const line of lines) {
    if (rows.length >= CSV_MAX_ROWS) { skipped++; continue; }
    const [rawEmail, ...rest] = line.split(",");
    rows.push({ email: (rawEmail ?? "").trim(), name: rest.join(",").trim() || null });
  }
  return { rows, skipped };
}

async function importMembers(request: Request, env: RosterEnv, session: Session): Promise<Response> {
  if (await rateLimited(request, env, session, "import")) {
    return json(request, { error: "Too many imports this hour. Try again shortly." }, 429);
  }
  const room = await loadClassroom(env, session.classroom_id);
  if (!room) return json(request, { error: "Classroom not found" }, 404);

  const text = await request.text();
  if (new TextEncoder().encode(text).length > CSV_MAX_BYTES) {
    return json(request, { error: `CSV larger than ${CSV_MAX_BYTES / 1024} KB` }, 413);
  }

  const { rows, skipped } = parseCsv(text);
  const results: Array<{ row: number; email: string; outcome: string; detail?: string }> = [];

  // Bad rows never block good ones: each is invited on its own.
  for (const [i, row] of rows.entries()) {
    const email = normaliseEmail(row.email);
    if (!isEmail(email)) {
      results.push({ row: i + 1, email: row.email, outcome: "invalid" });
      continue;
    }
    const r = await inviteOne(env, session, room, email, row.name, "learner");
    if (r.ok) {
      results.push({ row: i + 1, email, outcome: r.email_status === "sent" ? "created" : "created_email_failed" });
    } else if (r.status === 409 && r.error.includes("already")) {
      results.push({ row: i + 1, email, outcome: "duplicate" });
    } else if (r.status === 409) {
      results.push({ row: i + 1, email, outcome: "over_capacity" });
    } else {
      results.push({ row: i + 1, email, outcome: "failed", detail: r.error });
    }
  }

  for (let i = 0; i < skipped; i++) {
    results.push({ row: CSV_MAX_ROWS + i + 1, email: "", outcome: "over_row_limit" });
  }

  const summary = results.reduce<Record<string, number>>((a, r) => ({ ...a, [r.outcome]: (a[r.outcome] ?? 0) + 1 }), {});
  await audit(env, room.id, session.member_id, "member.imported", JSON.stringify(summary));
  return json(request, { summary, results });
}

async function resendMember(request: Request, env: RosterEnv, session: Session, memberId: string): Promise<Response> {
  if (await rateLimited(request, env, session, "invite")) {
    return json(request, { error: "Too many invites this hour. Try again shortly." }, 429);
  }
  const room = await loadClassroom(env, session.classroom_id);
  if (!room || !env.HMAC_SECRET) return json(request, { error: "Classroom not found" }, 404);

  const member = await env.CLASSROOM_DB.prepare(
    `SELECT id, email, role, status, rotations, license_key_prefix FROM members
      WHERE id = ? AND classroom_id = ?`,
  ).bind(memberId, session.classroom_id).first<{
    id: string; email: string; role: string; status: string; rotations: number; license_key_prefix: string | null;
  }>();
  if (!member) return json(request, { error: "Member not found" }, 404);
  if (member.status === "revoked") return json(request, { error: "That seat was revoked. Invite them again instead." }, 409);

  const role: LicenseRole = member.role === "instructor" ? "instructor-admin" : "learner";
  const oldKey = await licenseKeyFrom(`${member.id}:${member.rotations}`, env.HMAC_SECRET);
  const newRotation = member.rotations + 1;
  const newKey = await licenseKeyFrom(`${member.id}:${newRotation}`, env.HMAC_SECRET);

  // New key first, then D1, then disable the old one — the learner always has
  // at least one working key at every point in this sequence.
  await writeLicense(env, { key: newKey, email: member.email, role, room, member_id: member.id });
  await env.CLASSROOM_DB.prepare(
    `UPDATE members SET rotations = ?, license_key_prefix = ?, license_key_hash = ?, email_status = 'pending' WHERE id = ?`,
  ).bind(newRotation, newKey.slice(0, 8), await sha256Hex(newKey), member.id).run();
  await disableLicense(env, oldKey, "rotated");

  const sent = await sendInviteEmail(env, { to: member.email, key: newKey, role, room });
  await env.CLASSROOM_DB.prepare(`UPDATE members SET email_status = ? WHERE id = ?`)
    .bind(sent ? "sent" : "failed", member.id).run();

  await audit(env, room.id, session.member_id, "member.key_rotated", `${member.email} (rotation ${newRotation})`);
  return json(request, {
    member_id: member.id,
    key_prefix: newKey.slice(0, 8),
    email_status: sent ? "sent" : "failed",
    ...(room.is_test === 1 ? { test_key: newKey, previous_test_key: oldKey } : {}),
  });
}

async function revokeMember(request: Request, env: RosterEnv, session: Session, memberId: string): Promise<Response> {
  if (!env.HMAC_SECRET) return json(request, { error: "Key service unavailable" }, 503);
  const member = await env.CLASSROOM_DB.prepare(
    `SELECT id, email, rotations, status FROM members WHERE id = ? AND classroom_id = ?`,
  ).bind(memberId, session.classroom_id).first<{ id: string; email: string; rotations: number; status: string }>();
  if (!member) return json(request, { error: "Member not found" }, 404);
  if (member.status === "revoked") return json(request, { ok: true, already: true });

  // KV first: after this the key cannot be used, whatever happens next. The
  // reverse order could free a seat while the key still validated.
  const key = await licenseKeyFrom(`${member.id}:${member.rotations}`, env.HMAC_SECRET);
  await disableLicense(env, key, "seat revoked");

  await env.CLASSROOM_DB.prepare(
    `UPDATE members SET status = 'revoked', revoked_at = datetime('now') WHERE id = ?`,
  ).bind(member.id).run();

  await audit(env, session.classroom_id, session.member_id, "member.revoked", member.email);
  return json(request, { ok: true, member_id: member.id });
}

export async function routeRoster(
  request: Request,
  env: RosterEnv,
  session: Session,
  path: string,
): Promise<Response | null> {
  const method = request.method;

  if (path === "/v1/classroom/members") {
    if (method === "GET") return listMembers(request, env, session);
    if (method === "POST") return createMember(request, env, session);
  }
  if (path === "/v1/classroom/members/import" && method === "POST") return importMembers(request, env, session);

  const resend = path.match(/^\/v1\/classroom\/members\/([A-Za-z0-9_]+)\/resend$/);
  if (resend && method === "POST") return resendMember(request, env, session, resend[1]);

  const member = path.match(/^\/v1\/classroom\/members\/([A-Za-z0-9_]+)$/);
  if (member && method === "DELETE") return revokeMember(request, env, session, member[1]);

  return null;
}
