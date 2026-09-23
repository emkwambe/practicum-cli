// Seeds a realistic worst-case classroom so the matrix query is measured
// against the size it will actually meet: 30 learners x 50 assigned items,
// with progress rows for roughly two thirds of the cells.
//
//   npm run seed:perf                 # local D1
//   npm run seed:perf -- --remote     # production D1
//
// The classroom is is_test = 1 and is seeded straight into D1: no license keys
// are minted, so it contributes nothing to LICENSES KV at all. The smoke suite
// refuses to reset or revoke anything in it — it is a fixture, not a workspace.

import { execFileSync } from "node:child_process";
import { writeFileSync, unlinkSync, readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const API_DIR = join(ROOT, "workers", "practicum-api");
const remote = process.argv.includes("--remote");

const ROOM = "cls_perftest00000000000000";
const INSTRUCTOR = "mem_perftest_instructor000";
const LEARNERS = 30;
const ASSIGNMENTS = 50;
const COVERAGE = 0.66;   // share of cells that have a progress row

// Real content ids, so the join behaves exactly as it will in production.
const manifest = JSON.parse(readFileSync(join(ROOT, "content", "manifest.json"), "utf8"));
const contentIds = manifest.courses
  .flatMap((c) => c.days.flatMap((d) => [...d.lessons, ...d.labs].map((i) => i.id)))
  .slice(0, ASSIGNMENTS);

if (contentIds.length < ASSIGNMENTS) {
  console.error(`Only ${contentIds.length} content ids available, need ${ASSIGNMENTS}`);
  process.exit(1);
}

const sql = [];
sql.push(`DELETE FROM progress_state WHERE classroom_id = '${ROOM}';`);
sql.push(`DELETE FROM progress_events WHERE classroom_id = '${ROOM}';`);
sql.push(`DELETE FROM assignments WHERE classroom_id = '${ROOM}';`);
sql.push(`DELETE FROM members WHERE classroom_id = '${ROOM}';`);
sql.push(`DELETE FROM classrooms WHERE id = '${ROOM}';`);
sql.push(
  `INSERT INTO classrooms (id, name, owner_email, status, learner_limit, instructor_limit, expires_at, is_test)
   VALUES ('${ROOM}', 'Perf Test Classroom', 'perf@practicum-cli.dev', 'active', ${LEARNERS}, 2,
           datetime('now', '+365 days'), 1);`,
);
sql.push(
  `INSERT INTO members (id, classroom_id, role, email, display_name, status, activated_at)
   VALUES ('${INSTRUCTOR}', '${ROOM}', 'instructor', 'perf@practicum-cli.dev', 'Perf Instructor', 'active', datetime('now'));`,
);

// Learner names deliberately include the characters that break naive CSV:
// a comma, a double quote, a non-ASCII letter, and a leading = that Excel
// would otherwise evaluate as a formula.
const awkward = [
  `O'Brien, Síle`,
  `Ada "Countess" Lovelace`,
  `=cmd|' /C calc'!A0`,
  `Zoë Washburne, PhD`,
  `+41 Jean-Luc`,
];

const learnerIds = [];
for (let i = 0; i < LEARNERS; i++) {
  const id = `mem_perf${String(i).padStart(18, "0")}`;
  learnerIds.push(id);
  const name = (awkward[i] ?? `Perf Learner ${i}`).replace(/'/g, "''");
  sql.push(
    `INSERT INTO members (id, classroom_id, role, email, display_name, status, activated_at, last_seen_at)
     VALUES ('${id}', '${ROOM}', 'learner', 'perf${i}@example.com', '${name}', 'active',
             datetime('now', '-${i} days'), datetime('now', '-${i} hours'));`,
  );
}

for (let a = 0; a < ASSIGNMENTS; a++) {
  const cid = contentIds[a];
  const title = (manifest.courses
    .flatMap((c) => c.days.flatMap((d) => [...d.lessons, ...d.labs]))
    .find((i) => i.id === cid)?.title ?? cid).replace(/'/g, "''");
  sql.push(
    `INSERT INTO assignments (id, classroom_id, content_type, content_id, title, due_at, created_by)
     VALUES ('asg_perf${String(a).padStart(18, "0")}', '${ROOM}', '${cid.includes("/lab/") ? "lab" : "lesson"}',
             '${cid}', '${title}', datetime('now', '+${a} days'), '${INSTRUCTOR}');`,
  );
}

// Progress rows: a deterministic spread so the numbers are reproducible.
let cells = 0;
for (let i = 0; i < LEARNERS; i++) {
  for (let a = 0; a < ASSIGNMENTS; a++) {
    if ((i * 7 + a * 3) % 100 >= COVERAGE * 100) continue;
    const status = (i + a) % 3 === 0 ? "passed" : (i + a) % 3 === 1 ? "completed" : "started";
    const done = status !== "started";
    cells++;
    sql.push(
      `INSERT INTO progress_state (member_id, content_id, classroom_id, status, attempts, first_completed_at, updated_at)
       VALUES ('${learnerIds[i]}', '${contentIds[a]}', '${ROOM}', '${status}', ${1 + (a % 3)},
               ${done ? `datetime('now', '-${a} hours')` : "NULL"}, datetime('now'));`,
    );
  }
}

const tmp = join(ROOT, ".seed-perf.sql");
writeFileSync(tmp, sql.join("\n") + "\n", "utf8");
try {
  execFileSync(
    "wrangler",
    ["d1", "execute", "practicum-classroom", remote ? "--remote" : "--local", "--file", tmp, "-y"],
    { cwd: API_DIR, stdio: ["ignore", "ignore", "inherit"], shell: true },
  );
} finally {
  try { unlinkSync(tmp); } catch { /* leftover temp file is harmless */ }
}

console.log(
  `seeded ${remote ? "remote" : "local"} perf classroom ${ROOM}: ` +
  `${LEARNERS} learners x ${ASSIGNMENTS} assignments = ${LEARNERS * ASSIGNMENTS} cells, ${cells} progress rows`,
);
// Smoke reads this to verify the fixture is still intact and correctly sized.
const fixture = join(ROOT, "tests", "smoke_fixture.env");
try {
  const existing = readFileSync(fixture, "utf8").split("\n").filter((l) => l && !l.startsWith("SMOKE_PERF_"));
  writeFileSync(fixture, [...existing, `SMOKE_PERF_EMAIL=perf@practicum-cli.dev`, `SMOKE_PERF_CLASSROOM_ID=${ROOM}`, ""].join("\n"), "utf8");
} catch { /* fixture file is written by seed-test-classroom; nothing to append to yet */ }

console.log(`  instructor: perf@practicum-cli.dev`);
