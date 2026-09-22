// Creates (or refreshes) the is_test = 1 classroom the smoke suite signs into.
//
//   npm run seed:test-classroom              # local D1, for wrangler dev
//   npm run seed:test-classroom -- --remote  # production D1
//
// Test classrooms route all email to Resend's sink address and hand the magic
// token back in the API response, so smoke tests never need a mailbox.

import { execFileSync } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const API_DIR = join(ROOT, "workers", "practicum-api");
const remote = process.argv.includes("--remote");

const CLASSROOM_ID = "cls_smoketest0000000000000";
const INSTRUCTOR_ID = "mem_smoketest_instructor00";
const OTHER_CLASSROOM_ID = "cls_smoketest0000000000001"; // for session-scoping tests
const OTHER_INSTRUCTOR_ID = "mem_smoketest_instructor01";
const INSTRUCTOR_EMAIL = "smoke-instructor@practicum-cli.dev";
// Classroom C is for manual QA only: mail really is delivered, to QA_MAIL_TO.
// The smoke suite must never touch it — it signs in as classroom A's instructor
// and every instructor route is scoped to the session's own classroom.
const QA_CLASSROOM_ID = "cls_manualqa000000000000000";
const QA_INSTRUCTOR_ID = "mem_manualqa_instructor000";
const QA_MAIL_TO = "practicum@mpingo.ai";
const OTHER_EMAIL = "smoke-instructor-b@practicum-cli.dev";

const sql = `
DELETE FROM members WHERE classroom_id IN ('${CLASSROOM_ID}','${OTHER_CLASSROOM_ID}','${QA_CLASSROOM_ID}');
DELETE FROM classrooms WHERE id IN ('${CLASSROOM_ID}','${OTHER_CLASSROOM_ID}','${QA_CLASSROOM_ID}');
INSERT INTO classrooms (id, name, owner_email, status, learner_limit, instructor_limit, expires_at, is_test)
VALUES ('${CLASSROOM_ID}', 'Smoke Test Classroom', '${INSTRUCTOR_EMAIL}', 'active', 30, 2,
        datetime('now', '+365 days'), 1),
       ('${OTHER_CLASSROOM_ID}', 'Smoke Test Classroom B', '${OTHER_EMAIL}', 'active', 30, 2,
        datetime('now', '+365 days'), 1);
INSERT INTO classrooms (id, name, owner_email, status, learner_limit, instructor_limit, expires_at, is_test, qa_mail_to)
VALUES ('${QA_CLASSROOM_ID}', 'Manual QA Classroom', '${QA_MAIL_TO}', 'active', 30, 2,
        datetime('now', '+365 days'), 1, '${QA_MAIL_TO}');
INSERT INTO members (id, classroom_id, role, email, display_name, status, activated_at)
VALUES ('${INSTRUCTOR_ID}', '${CLASSROOM_ID}', 'instructor', '${INSTRUCTOR_EMAIL}', 'Smoke Instructor', 'active', datetime('now')),
       ('${OTHER_INSTRUCTOR_ID}', '${OTHER_CLASSROOM_ID}', 'instructor', '${OTHER_EMAIL}', 'Smoke Instructor B', 'active', datetime('now')),
       ('${QA_INSTRUCTOR_ID}', '${QA_CLASSROOM_ID}', 'instructor', '${QA_MAIL_TO}', 'QA Instructor', 'active', datetime('now'));
`.trim();

const tmp = join(ROOT, ".seed-test-classroom.sql");
writeFileSync(tmp, sql + "\n", "utf8");

try {
  const args = ["d1", "execute", "practicum-classroom", remote ? "--remote" : "--local", "--file", tmp, "-y"];
  execFileSync("wrangler", args, { cwd: API_DIR, stdio: "inherit", shell: true });
} finally {
  try {
    execFileSync(process.platform === "win32" ? "cmd" : "rm", process.platform === "win32" ? ["/c", "del", tmp] : [tmp], {
      stdio: "ignore",
      shell: true,
    });
  } catch { /* leftover temp file is harmless */ }
}

// Smoke scripts read these rather than hardcoding ids in bash.
mkdirSync(join(ROOT, "tests"), { recursive: true });
writeFileSync(
  join(ROOT, "tests", "smoke_fixture.env"),
  [
    `SMOKE_CLASSROOM_ID=${CLASSROOM_ID}`,
    `SMOKE_INSTRUCTOR_EMAIL=${INSTRUCTOR_EMAIL}`,
    `SMOKE_CLASSROOM_B_ID=${OTHER_CLASSROOM_ID}`,
    `SMOKE_INSTRUCTOR_B_EMAIL=${OTHER_EMAIL}`,
    "",
  ].join("\n"),
  "utf8",
);

console.log(`seeded ${remote ? "remote" : "local"}: A ${CLASSROOM_ID} (${INSTRUCTOR_EMAIL}), B (scoping), C ${QA_CLASSROOM_ID} manual QA -> ${QA_MAIL_TO}`);
