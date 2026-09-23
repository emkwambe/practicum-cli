// Sprint 7D — assignments, cohort reporting, CSV export, community link.
//
//   GET/POST   /v1/classroom/assignments
//   PATCH/DEL  /v1/classroom/assignments/:id      (soft archive)
//   GET        /v1/classroom/progress             learners x assignments matrix
//   GET        /v1/classroom/progress/:member_id  one learner's timeline
//   GET        /v1/classroom/export.csv?type=roster|progress|assignments
//   PATCH      /v1/classroom                      { name?, telegram_invite_url? }
//   GET        /v1/learner/assignments            text/plain, license-key auth
//   GET        /v1/learner/community              text/plain, license-key auth

import manifest from "../../../content/manifest.json";
import type { LicenseRecord } from "./catalog";
import { type ClassroomEnv, type Session, newId, readBody, corsHeaders } from "./classroom";

export interface ReportingEnv extends ClassroomEnv {
  LICENSES: KVNamespace;
}

const json = (request: Request, data: unknown, status = 200) =>
  Response.json(data, { status, headers: corsHeaders(request) });

const plain = (body: string, status = 200) =>
  new Response(body + "\n", {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
  });

// --- manifest lookup ---------------------------------------------------------

interface ContentItem { id: string; title: string; type: "lesson" | "lab"; course: string }

const CONTENT: Map<string, ContentItem> = new Map(
  manifest.courses.flatMap((c: any) =>
    c.days.flatMap((d: any) => [
      ...d.lessons.map((i: any) => [i.id, { id: i.id, title: i.title, type: "lesson" as const, course: c.title }] as const),
      ...d.labs.map((i: any) => [i.id, { id: i.id, title: i.title, type: "lab" as const, course: c.title }] as const),
    ]),
  ),
);

// --- assignments -------------------------------------------------------------

async function listAssignments(request: Request, env: ReportingEnv, session: Session): Promise<Response> {
  const rows = await env.CLASSROOM_DB.prepare(
    `SELECT id, content_type, content_id, title, instructions, due_at, created_at
       FROM assignments
      WHERE classroom_id = ? AND archived_at IS NULL
      ORDER BY COALESCE(due_at, '9999'), created_at`,
  ).bind(session.classroom_id).all();
  return json(request, { assignments: rows.results ?? [] });
}

async function createAssignment(request: Request, env: ReportingEnv, session: Session): Promise<Response> {
  const body = await readBody(request);
  const contentId = (body.content_id ?? "").trim();
  const item = CONTENT.get(contentId);
  if (!item) return json(request, { error: `Unknown content_id '${contentId}'` }, 400);

  const dueAt = (body.due_at ?? "").trim() || null;
  if (dueAt && Number.isNaN(Date.parse(dueAt))) return json(request, { error: "due_at is not a date" }, 400);

  const id = newId("asg");
  try {
    await env.CLASSROOM_DB.prepare(
      `INSERT INTO assignments (id, classroom_id, content_type, content_id, title, instructions, due_at, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      id, session.classroom_id, item.type, contentId, item.title,
      (body.instructions ?? "").trim() || null, dueAt, session.member_id,
    ).run();
  } catch (e) {
    return json(request, { error: `Could not create the assignment: ${e}` }, 500);
  }

  await env.CLASSROOM_DB.prepare(
    `INSERT INTO audit_log (classroom_id, actor, action, detail) VALUES (?, ?, 'assignment.created', ?)`,
  ).bind(session.classroom_id, session.member_id, `${contentId}${dueAt ? ` due ${dueAt}` : ""}`).run();

  return json(request, { id, content_id: contentId, title: item.title, content_type: item.type, due_at: dueAt }, 201);
}

// Editing never touches created_at or created_by: a moved deadline must read as
// the same assignment with a new date, not as a fresh one. The old and new
// values both go to audit_log so "why did this date change?" is answerable.
async function updateAssignment(request: Request, env: ReportingEnv, session: Session, id: string): Promise<Response> {
  const body = await readBody(request);
  const dueAt = body.due_at !== undefined ? (body.due_at.trim() || null) : undefined;
  if (dueAt && Number.isNaN(Date.parse(dueAt))) return json(request, { error: "due_at is not a date" }, 400);

  const before = await env.CLASSROOM_DB.prepare(
    `SELECT title, due_at, created_at FROM assignments
      WHERE id = ? AND classroom_id = ? AND archived_at IS NULL`,
  ).bind(id, session.classroom_id).first<{ title: string; due_at: string | null; created_at: string }>();
  if (!before) return json(request, { error: "Assignment not found" }, 404);

  // COALESCE(?, col) leaves a column alone when the caller omitted it; clearing
  // a due date is done by sending an empty value, which arrives here as null.
  await env.CLASSROOM_DB.prepare(
    `UPDATE assignments
        SET due_at       = CASE WHEN ? THEN ? ELSE due_at END,
            instructions = COALESCE(?, instructions)
      WHERE id = ? AND classroom_id = ? AND archived_at IS NULL`,
  ).bind(
    dueAt !== undefined ? 1 : 0, dueAt ?? null,
    body.instructions?.trim() ?? null, id, session.classroom_id,
  ).run();

  const after = await env.CLASSROOM_DB.prepare(
    `SELECT due_at, created_at FROM assignments WHERE id = ? AND classroom_id = ?`,
  ).bind(id, session.classroom_id).first<{ due_at: string | null; created_at: string }>();

  if (dueAt !== undefined && before.due_at !== after?.due_at) {
    await env.CLASSROOM_DB.prepare(
      `INSERT INTO audit_log (classroom_id, actor, action, detail) VALUES (?, ?, 'assignment.due_changed', ?)`,
    ).bind(
      session.classroom_id, session.member_id,
      `${before.title}: ${before.due_at ?? "no due date"} -> ${after?.due_at ?? "no due date"}`,
    ).run();
  }

  return json(request, {
    ok: true,
    id,
    due_at: after?.due_at ?? null,
    // Proof to the caller that this is still the same assignment.
    created_at: after?.created_at ?? before.created_at,
    created_at_unchanged: before.created_at === after?.created_at,
  });
}

// Soft archive: learners stop seeing it, and progress rows keep their meaning.
async function archiveAssignment(request: Request, env: ReportingEnv, session: Session, id: string): Promise<Response> {
  const res = await env.CLASSROOM_DB.prepare(
    `UPDATE assignments SET archived_at = datetime('now')
      WHERE id = ? AND classroom_id = ? AND archived_at IS NULL`,
  ).bind(id, session.classroom_id).run();
  if ((res.meta?.changes ?? 0) === 0) return json(request, { error: "Assignment not found" }, 404);

  await env.CLASSROOM_DB.prepare(
    `INSERT INTO audit_log (classroom_id, actor, action, detail) VALUES (?, ?, 'assignment.archived', ?)`,
  ).bind(session.classroom_id, session.member_id, id).run();
  return json(request, { ok: true, id, archived: true });
}

// --- the matrix --------------------------------------------------------------

// ONE query for the whole grid. A per-learner loop would pass a smoke test with
// three learners and then issue 30 round trips for a real classroom, which is
// how reporting pages die. Every learner x assignment cell comes back in a
// single result set and the percentages are folded in memory.
const MATRIX_SQL = `
  SELECT m.id            AS member_id,
         m.display_name  AS display_name,
         m.email         AS email,
         m.status        AS member_status,
         m.last_seen_at  AS last_seen_at,
         a.id            AS assignment_id,
         a.content_id    AS content_id,
         a.title         AS title,
         a.due_at        AS due_at,
         ps.status       AS state,
         ps.attempts     AS attempts,
         ps.first_completed_at AS first_completed_at
    FROM members m
    JOIN assignments a
      ON a.classroom_id = m.classroom_id
     AND a.archived_at IS NULL
    LEFT JOIN progress_state ps
      ON ps.member_id = m.id
     AND ps.content_id = a.content_id
   WHERE m.classroom_id = ?
     AND m.role = 'learner'
     AND m.status != 'revoked'
   ORDER BY m.display_name, m.email, a.due_at, a.created_at`;

type Cell = "complete" | "in_progress" | "not_started";
const cellFor = (state: string | null): Cell =>
  state === "passed" || state === "completed" ? "complete" : state ? "in_progress" : "not_started";

interface MatrixRow {
  member_id: string; display_name: string | null; email: string; member_status: string;
  last_seen_at: string | null; assignment_id: string; content_id: string; title: string;
  due_at: string | null; state: string | null; attempts: number | null; first_completed_at: string | null;
}

async function progressMatrix(env: ReportingEnv, classroomId: string) {
  const started = Date.now();
  const res = await env.CLASSROOM_DB.prepare(MATRIX_SQL).bind(classroomId).all<MatrixRow>();
  const rows = res.results ?? [];

  const learners = new Map<string, any>();
  const assignments = new Map<string, any>();

  for (const r of rows) {
    if (!learners.has(r.member_id)) {
      learners.set(r.member_id, {
        member_id: r.member_id,
        name: r.display_name || r.email,
        email: r.email,
        last_seen_at: r.last_seen_at,
        complete: 0,
        cells: {} as Record<string, Cell>,
      });
    }
    if (!assignments.has(r.assignment_id)) {
      assignments.set(r.assignment_id, {
        assignment_id: r.assignment_id,
        content_id: r.content_id,
        title: r.title,
        due_at: r.due_at,
        complete: 0,
      });
    }
    const cell = cellFor(r.state);
    learners.get(r.member_id).cells[r.assignment_id] = cell;
    if (cell === "complete") {
      learners.get(r.member_id).complete++;
      assignments.get(r.assignment_id).complete++;
    }
  }

  const learnerCount = learners.size;
  const assignmentList = [...assignments.values()].map((a) => ({
    ...a,
    completion_pct: learnerCount ? Math.round((a.complete / learnerCount) * 100) : 0,
  }));

  return {
    learners: [...learners.values()],
    assignments: assignmentList,
    cohort: {
      learners: learnerCount,
      assignments: assignmentList.length,
      cells: rows.length,
      completion_pct: rows.length
        ? Math.round((rows.filter((r) => cellFor(r.state) === "complete").length / rows.length) * 100)
        : 0,
    },
    query_ms: Date.now() - started,
  };
}

async function handleProgressMatrix(request: Request, env: ReportingEnv, session: Session): Promise<Response> {
  return json(request, await progressMatrix(env, session.classroom_id));
}

async function handleLearnerTimeline(request: Request, env: ReportingEnv, session: Session, memberId: string): Promise<Response> {
  const member = await env.CLASSROOM_DB.prepare(
    `SELECT id, display_name, email, status, activated_at, last_seen_at
       FROM members WHERE id = ? AND classroom_id = ?`,
  ).bind(memberId, session.classroom_id).first();
  if (!member) return json(request, { error: "Member not found" }, 404);

  const events = await env.CLASSROOM_DB.prepare(
    `SELECT content_id, event, occurred_at FROM progress_events
      WHERE member_id = ? AND classroom_id = ?
      ORDER BY occurred_at DESC LIMIT 200`,
  ).bind(memberId, session.classroom_id).all();

  return json(request, {
    member,
    events: (events.results ?? []).map((e: any) => ({ ...e, title: CONTENT.get(e.content_id)?.title ?? e.content_id })),
  });
}

// --- CSV ---------------------------------------------------------------------

// RFC 4180: double quotes doubled, fields with comma/quote/newline quoted.
// Excel also *executes* a leading =, +, - or @, so those are neutralised with a
// leading apostrophe — the value is still readable, and no spreadsheet treats
// it as a formula.
function csvField(value: unknown): string {
  if (value === null || value === undefined) return "";
  let s = String(value);
  if (/^[=+\-@\t\r]/.test(s)) s = "'" + s;
  if (/[",\r\n]/.test(s)) s = '"' + s.replace(/"/g, '""') + '"';
  return s;
}

const csvRow = (fields: unknown[]) => fields.map(csvField).join(",") + "\r\n";

// Rows are paged out of D1 and written to the response as they are produced, so
// peak memory is one page rather than the whole export. The BOM goes on the
// file only — never on a JSON or text/plain response — because Excel needs it
// to read UTF-8 and everything else copes without it.
function streamCsv(
  filename: string,
  header: string[],
  page: (offset: number, limit: number) => Promise<unknown[][]>,
): Response {
  const PAGE = 500;
  const encoder = new TextEncoder();
  let offset = 0;
  let wroteHeader = false;

  const stream = new ReadableStream({
    async pull(controller) {
      if (!wroteHeader) {
        controller.enqueue(encoder.encode("﻿" + csvRow(header)));
        wroteHeader = true;
        return;
      }
      const rows = await page(offset, PAGE);
      if (rows.length === 0) {
        controller.close();
        return;
      }
      offset += rows.length;
      let chunk = "";
      for (const r of rows) chunk += csvRow(r);
      controller.enqueue(encoder.encode(chunk));
      if (rows.length < PAGE) controller.close();
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Cache-Control": "no-store",
    },
  });
}

const isoDate = (v: unknown) => {
  if (!v) return "";
  const s = String(v);
  const d = new Date(s.includes("T") ? s : s.replace(" ", "T") + "Z");
  return Number.isNaN(d.valueOf()) ? s : d.toISOString();
};

function exportCsv(env: ReportingEnv, session: Session, type: string): Response {
  const room = session.classroom_id;
  const stamp = new Date().toISOString().slice(0, 10);

  if (type === "assignments") {
    return streamCsv(`practicum-assignments-${stamp}.csv`,
      ["assignment_id", "content_id", "type", "title", "due_at", "created_at", "archived_at"],
      async (offset, limit) => {
        const r = await env.CLASSROOM_DB.prepare(
          `SELECT id, content_id, content_type, title, due_at, created_at, archived_at
             FROM assignments WHERE classroom_id = ?
            ORDER BY created_at LIMIT ? OFFSET ?`,
        ).bind(room, limit, offset).all<any>();
        return (r.results ?? []).map((a) => [
          a.id, a.content_id, a.content_type, a.title, isoDate(a.due_at), isoDate(a.created_at), isoDate(a.archived_at),
        ]);
      });
  }

  if (type === "progress") {
    // One row per learner x content item.
    return streamCsv(`practicum-progress-${stamp}.csv`,
      ["member_id", "name", "email", "content_id", "title", "status", "attempts", "first_completed_at", "due_at"],
      async (offset, limit) => {
        const r = await env.CLASSROOM_DB.prepare(
          `${MATRIX_SQL} LIMIT ? OFFSET ?`,
        ).bind(room, limit, offset).all<MatrixRow>();
        return (r.results ?? []).map((x) => [
          x.member_id, x.display_name || x.email, x.email, x.content_id, x.title,
          cellFor(x.state), x.attempts ?? 0, isoDate(x.first_completed_at), isoDate(x.due_at),
        ]);
      });
  }

  return streamCsv(`practicum-roster-${stamp}.csv`,
    ["member_id", "name", "email", "role", "status", "invited_at", "activated_at", "last_seen_at", "key_prefix"],
    async (offset, limit) => {
      const r = await env.CLASSROOM_DB.prepare(
        `SELECT id, display_name, email, role, status, invited_at, activated_at, last_seen_at, license_key_prefix
           FROM members WHERE classroom_id = ?
          ORDER BY role DESC, email LIMIT ? OFFSET ?`,
      ).bind(room, limit, offset).all<any>();
      return (r.results ?? []).map((m) => [
        m.id, m.display_name ?? "", m.email, m.role, m.status,
        isoDate(m.invited_at), isoDate(m.activated_at), isoDate(m.last_seen_at), m.license_key_prefix ?? "",
      ]);
    });
}

// --- classroom settings ------------------------------------------------------

async function patchClassroom(request: Request, env: ReportingEnv, session: Session): Promise<Response> {
  const body = await readBody(request);
  const name = body.name?.trim();
  const telegram = body.telegram_invite_url?.trim();

  // Only a real Telegram invite. Anything else would be mailed to every learner.
  if (telegram !== undefined && telegram !== "" && !/^https:\/\/t\.me\/[A-Za-z0-9_+/-]+$/.test(telegram)) {
    return json(request, { error: "Telegram link must look like https://t.me/..." }, 400);
  }

  await env.CLASSROOM_DB.prepare(
    `UPDATE classrooms
        SET name = COALESCE(NULLIF(?, ''), name),
            telegram_invite_url = CASE WHEN ? IS NULL THEN telegram_invite_url
                                       WHEN ? = '' THEN NULL ELSE ? END
      WHERE id = ?`,
  ).bind(name ?? "", telegram ?? null, telegram ?? null, telegram ?? null, session.classroom_id).run();

  await env.CLASSROOM_DB.prepare(
    `INSERT INTO audit_log (classroom_id, actor, action, detail) VALUES (?, ?, 'classroom.updated', ?)`,
  ).bind(session.classroom_id, session.member_id, telegram !== undefined ? "telegram" : "name").run();

  return json(request, { ok: true });
}

// --- learner routes (license-key auth, text/plain) ---------------------------

async function learnerFromKey(request: Request, env: ReportingEnv) {
  const key = (request.headers.get("X-License-Key") ?? "").trim().toUpperCase();
  if (!key) return null;
  const license = await env.LICENSES.get<LicenseRecord>(key, "json");
  if (!license || license.revoked || !license.classroom_id || !license.member_id) return null;
  return license;
}

async function learnerAssignments(request: Request, env: ReportingEnv): Promise<Response> {
  const license = await learnerFromKey(request, env);
  if (!license) return plain("ERR|no_access|No classroom for this license", 403);

  const rows = await env.CLASSROOM_DB.prepare(
    `SELECT a.id, a.content_id, a.title, a.due_at,
            COALESCE(ps.status, 'not_started') AS state
       FROM assignments a
       LEFT JOIN progress_state ps
         ON ps.content_id = a.content_id AND ps.member_id = ?
      WHERE a.classroom_id = ? AND a.archived_at IS NULL
      ORDER BY COALESCE(a.due_at, '9999'), a.created_at`,
  ).bind(license.member_id, license.classroom_id).all<any>();

  const lines = (rows.results ?? []).map((a) => {
    const done = a.state === "passed" || a.state === "completed";
    const overdue = !done && a.due_at && Date.parse(a.due_at) < Date.now() ? "overdue" : "";
    return `ASSIGN|${a.id}|${a.content_id}|${a.title}|${a.due_at ?? ""}|${done ? "complete" : a.state === "started" ? "in_progress" : "not_started"}|${overdue}`;
  });
  return plain(lines.length ? lines.join("\n") : "NONE|no assignments yet");
}

async function learnerCommunity(request: Request, env: ReportingEnv): Promise<Response> {
  const license = await learnerFromKey(request, env);
  if (!license) return plain("ERR|no_access|No classroom for this license", 403);
  const room = await env.CLASSROOM_DB.prepare(
    `SELECT telegram_invite_url FROM classrooms WHERE id = ?`,
  ).bind(license.classroom_id).first<{ telegram_invite_url: string | null }>();
  return plain(room?.telegram_invite_url ? `COMMUNITY|${room.telegram_invite_url}` : "NONE|your instructor has not set a group link");
}

// --- router ------------------------------------------------------------------

export async function routeLearner(request: Request, env: ReportingEnv, path: string): Promise<Response | null> {
  if (request.method !== "GET") return null;
  if (path === "/v1/learner/assignments") return learnerAssignments(request, env);
  if (path === "/v1/learner/community") return learnerCommunity(request, env);
  return null;
}

export async function routeReporting(
  request: Request, env: ReportingEnv, session: Session, path: string,
): Promise<Response | null> {
  const method = request.method;

  if (path === "/v1/classroom" && method === "PATCH") return patchClassroom(request, env, session);

  if (path === "/v1/classroom/assignments") {
    if (method === "GET") return listAssignments(request, env, session);
    if (method === "POST") return createAssignment(request, env, session);
  }
  const asg = path.match(/^\/v1\/classroom\/assignments\/([A-Za-z0-9_]+)$/);
  if (asg && method === "PATCH") return updateAssignment(request, env, session, asg[1]);
  if (asg && method === "DELETE") return archiveAssignment(request, env, session, asg[1]);

  if (path === "/v1/classroom/progress" && method === "GET") return handleProgressMatrix(request, env, session);
  const tl = path.match(/^\/v1\/classroom\/progress\/([A-Za-z0-9_]+)$/);
  if (tl && method === "GET") return handleLearnerTimeline(request, env, session, tl[1]);

  if (path === "/v1/classroom/export.csv" && method === "GET") {
    const type = new URL(request.url).searchParams.get("type") ?? "roster";
    if (!["roster", "progress", "assignments"].includes(type)) {
      return json(request, { error: "type must be roster, progress or assignments" }, 400);
    }
    return exportCsv(env, session, type);
  }

  return null;
}
