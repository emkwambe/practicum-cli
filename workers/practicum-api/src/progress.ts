// Sprint 7C — progress ingestion.
//
//   POST /v1/progress   form: event_id, content_id, event, occurred_at, cli_version
//                       auth:  X-License-Key header (or `key` form field)
//
// Learner-facing, so the response is text/plain, pipe-delimited, with a leading
// record type — lib/progress.sh parses it with grep/cut and no jq.
//
//   OK|<event_id>|stored        accepted, or accepted-as-duplicate
//   ERR|<code>|<message>        rejected; the CLI decides whether to retry
//
// Retry policy is encoded in the status, not the body: 4xx means the event will
// never be accepted and the CLI drops it; 5xx and network failures mean keep it
// in the outbox and try later.

import manifest from "../../../content/manifest.json";
import { sha256Hex, type LicenseRecord } from "./catalog";
import type { ClassroomEnv } from "./classroom";

export interface ProgressEnv extends ClassroomEnv {
  LICENSES: KVNamespace;
}

// A learner working through a day emits a handful of events a minute at most.
const PROGRESS_LIMIT_PER_HOUR = 300;

const EVENTS = ["lesson_started", "lesson_completed", "lab_passed", "lab_failed"] as const;
type ProgressEvent = (typeof EVENTS)[number];

// Status never regresses: a later lab_failed must not undo a pass.
const RANK: Record<string, number> = { started: 1, completed: 2, passed: 3 };
const STATUS_FOR: Record<ProgressEvent, string> = {
  lesson_started: "started",
  lesson_completed: "completed",
  lab_passed: "passed",
  lab_failed: "started",
};

// Content ids are validated against the manifest, so a typo or a stale client
// cannot write rows that no report can ever join to.
const VALID_CONTENT_IDS: Set<string> = new Set(
  manifest.courses.flatMap((c: any) =>
    c.days.flatMap((d: any) => [...d.lessons, ...d.labs].map((i: any) => i.id)),
  ),
);

const text = (body: string, status = 200) =>
  new Response(body + "\n", {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
  });

const err = (code: string, message: string, status: number) => text(`ERR|${code}|${message}`, status);

// Same one-hour window 7C-0 uses for /license/validate: a learner completing a
// day emits many events, and each one must not become a D1 write to the roster.
const LAST_SEEN_STALE_AFTER = "-1 hour";

export async function handleProgress(request: Request, env: ProgressEnv): Promise<Response> {
  const form = await request.formData().catch(() => null);
  if (!form) return err("bad_request", "Could not read the form body", 400);

  const rawKey = request.headers.get("X-License-Key") ?? String(form.get("key") ?? "");
  const key = rawKey.trim().toUpperCase();
  if (!key) return err("no_key", "No license key supplied", 401);

  const license = await env.LICENSES.get<LicenseRecord>(key, "json");
  // 403 for anything unusable: the CLI drops these events rather than retrying
  // forever for a learner who has left the classroom.
  if (!license) return err("unknown_key", "License not found", 403);
  if (license.revoked) return err("revoked", "Your classroom seat was removed", 403);
  if (!license.classroom_id || !license.member_id) {
    return err("not_classroom", "This license does not belong to a classroom", 403);
  }
  if (license.expires_at && Date.parse(license.expires_at) <= Date.now()) {
    return err("expired", "License expired", 403);
  }

  const eventId = String(form.get("event_id") ?? "").trim();
  const contentId = String(form.get("content_id") ?? "").trim();
  const event = String(form.get("event") ?? "").trim() as ProgressEvent;
  const occurredAt = String(form.get("occurred_at") ?? "").trim() || new Date().toISOString();
  const cliVersion = String(form.get("cli_version") ?? "").trim().slice(0, 32) || null;

  if (!/^[A-Za-z0-9._-]{8,128}$/.test(eventId)) return err("bad_event_id", "Malformed event_id", 400);
  if (!EVENTS.includes(event)) return err("bad_event", `Unknown event '${event}'`, 400);
  if (!VALID_CONTENT_IDS.has(contentId)) return err("bad_content", `Unknown content_id '${contentId}'`, 400);

  // Per-key hourly cap. Keyed on a hash so no license key is written to KV
  // under a guessable name.
  const bucket = `rlp:${(await sha256Hex(key)).slice(0, 24)}:${Math.floor(Date.now() / 3_600_000)}`;
  const used = Number((await env.SESSIONS.get(bucket)) ?? "0");
  if (used >= PROGRESS_LIMIT_PER_HOUR) {
    // 429 is retryable: the event stays in the outbox and goes out next hour.
    return err("rate_limited", `More than ${PROGRESS_LIMIT_PER_HOUR} events this hour`, 429);
  }
  await env.SESSIONS.put(bucket, String(used + 1), { expirationTtl: 3600 });

  // The member must still hold a seat. A revoked row means the KV record is
  // simply stale — treat it exactly like a revoked license.
  const member = await env.CLASSROOM_DB.prepare(
    `SELECT status FROM members WHERE id = ? AND classroom_id = ?`,
  ).bind(license.member_id, license.classroom_id).first<{ status: string }>();
  if (!member) return err("no_member", "No roster entry for this license", 403);
  if (member.status === "revoked") return err("revoked", "Your classroom seat was removed", 403);

  const status = STATUS_FOR[event];
  const completedNow = status === "completed" || status === "passed";

  // Claim the event first. 0 changes means this exact event has already been
  // recorded, so the flush is a retry — and a retry must be a true no-op. An
  // earlier version ran the state upsert unconditionally, which let a replayed
  // flush inflate `attempts` and make a learner look like they had failed a lab
  // repeatedly. Claiming first is also why this is not one batch.
  const claim = await env.CLASSROOM_DB.prepare(
    `INSERT OR IGNORE INTO progress_events
       (event_id, classroom_id, member_id, content_id, event, occurred_at, cli_version)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).bind(eventId, license.classroom_id, license.member_id, contentId, event, occurredAt, cliVersion).run();

  if ((claim.meta?.changes ?? 0) === 0) return text(`OK|${eventId}|duplicate`);

  await env.CLASSROOM_DB.batch([
    // attempts counts every event for this item; status only ever moves up.
    env.CLASSROOM_DB.prepare(
      `INSERT INTO progress_state
         (member_id, content_id, classroom_id, status, attempts, first_completed_at, updated_at)
       VALUES (?, ?, ?, ?, 1, ?, datetime('now'))
       ON CONFLICT(member_id, content_id) DO UPDATE SET
         status = CASE WHEN ? > ${rankCase("progress_state.status")} THEN ? ELSE progress_state.status END,
         attempts = progress_state.attempts + 1,
         first_completed_at = COALESCE(progress_state.first_completed_at, ?),
         updated_at = datetime('now')`,
    ).bind(
      license.member_id, contentId, license.classroom_id, status,
      completedNow ? occurredAt : null,
      RANK[status], status,
      completedNow ? occurredAt : null,
    ),

    // Same promotion as 7C-0's /license/validate: a member who is sending
    // progress has demonstrably started, and leaving them 'invited' would print
    // a row reading "seen just now" next to "never started". last_seen_at moves
    // on the same one-hour window, so a learner finishing a day's lessons
    // produces one roster write rather than one per event.
    env.CLASSROOM_DB.prepare(
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
    ).bind(license.member_id, license.classroom_id),
  ]);

  return text(`OK|${eventId}|stored`);
}

// SQLite has no map lookup, so the status ranking is inlined as a CASE.
function rankCase(column: string): string {
  return `(CASE ${column} WHEN 'passed' THEN 3 WHEN 'completed' THEN 2 WHEN 'started' THEN 1 ELSE 0 END)`;
}
