# Sprint 7 — Classroom Tier: Instructor Dashboard, End to End

**Product:** practicum-cli.dev · **Repo:** github.com/emkwambe/practicum-cli · **API:** api.practicum-cli.dev (Cloudflare Worker `practicum-api`)
**Audit item:** #7 (team + instructor dashboards)
**Ship gate:** the Classroom CTA stays a waitlist mailto until every promise in §1 has passing evidence in production.

---

## 1. What we are actually shipping

The site sells six things for $3,499/yr. Each one becomes a concrete, testable capability. This table is the sprint's final acceptance contract; nothing else counts as done.

| Site promise | Capability that satisfies it | Evidence in prod |
|---|---|---|
| 30 learner + 2 instructor seats | Seat provisioning with hard caps, invite / CSV import / resend / revoke | Smoke: 31st learner invite returns 409; 3rd instructor returns 409 |
| Full catalog + all Labs | Learner license keys issued into existing `LICENSES` KV with full entitlements | Smoke: learner key validates via `lib/license.sh` with full entitlements |
| Instructor dashboard + assignments | Web dashboard at `practicum-cli.dev/dashboard`; assignment CRUD; `practicum assignments` in CLI | Smoke: create assignment → learner endpoint lists it |
| Cohort progress + completion reporting | CLI progress events → D1 → cohort matrix + per-assignment completion % | Smoke: posted event appears in progress report |
| CSV export | `GET /v1/classroom/export.csv` (roster, progress, assignments) | Smoke: CSV has header + expected row |
| Private Telegram group managed by instructor | Instructor sets invite link; delivered in learner invite email and via `practicum community` | Smoke: link round-trips; learner endpoint returns it |

Telegram bot automation remains Phase 2 (future sprint). Phase 1 honors the promise because the instructor genuinely manages the group and the platform distributes access only to seated learners.

---

## 2. Architecture decisions

**Licenses stay in KV; classroom data goes to D1.** The license path works today and `lib/license.sh` depends on it, so learner and instructor keys are written into the existing `LICENSES` namespace with two added fields (`classroom_id`, `member_id`). Everything relational — rosters, assignments, progress, reporting, CSV — lives in a new Cloudflare D1 database, `practicum-classroom`. KV's eventual consistency and lack of aggregation make it the wrong store for cohort reporting and write-heavy progress events; D1 gives us joins, uniqueness constraints (idempotent progress ingestion), and straightforward CSV generation.

**Instructor auth is magic-link email, not license-key login.** License keys get pasted into terminals, screenshares, and Slack. The dashboard handles student PII, so instructors authenticate by email: `POST /v1/auth/magic-link` stores a single-use token in a `SESSIONS` KV namespace (15-minute TTL) and sends it via Resend; `GET /v1/auth/verify` exchanges it for a session cookie (`HttpOnly; Secure; SameSite=Lax; Domain=.practicum-cli.dev`, 7-day TTL, stored in `SESSIONS`). Only members with `role = 'instructor'` and `status = 'active'` on a non-expired classroom can request a link. Unknown emails get the same 200 response (no account enumeration).

**The CLI speaks plain text, not JSON.** No `jq` in bash, so every learner-facing endpoint the CLI consumes returns `text/plain`, one record per line, pipe-delimited, with a leading record type. Parsing is `grep`/`cut` only. CLI writes to the API use `application/x-www-form-urlencoded` so bash never builds JSON. The Worker accepts both form and JSON bodies on these routes.

**Progress is emitted locally first, delivered later.** The CLI appends events to `~/.practicum/outbox.log` and flushes opportunistically (on lesson/lab completion and on every license check). Each event carries a client-generated `event_id`; D1 enforces uniqueness, so retries are harmless. Learners in a lab environment with flaky network lose nothing.

**Consent is explicit.** The first time a classroom learner key activates, the CLI prints a one-time notice that lesson and lab progress is shared with their instructor, records acknowledgement in `~/.practicum/classroom_consent`, and sends nothing before that. Solo licenses never emit progress.

**Stable content IDs come from a generated manifest.** A build script walks the course and lab directories and writes `content/manifest.json` (course → lessons → labs, each with a stable ID and title). The Worker imports it at build time; the dashboard uses it for the assignment picker and completion denominators; the CLI uses the same IDs when emitting events. If IDs don't exist in the content today, this script defines them and they become permanent.

**The dashboard is served by the existing site Worker, not Cloudflare Pages.** practicum-cli.dev is the Worker `blue-pine-8359` serving `./lib` as static assets (`[assets]` in the root `wrangler.toml`, custom-domain route) — there is no Pages project, no framework and no build step. The dashboard is therefore hand-written static HTML at `lib/dashboard/index.html`, a single module-based page set under `/dashboard` using `fetch(..., { credentials: 'include' })`. Note that `./lib` also holds the CLI's shell libraries, so `lib/.assetsignore` allow-lists exactly the two published files (`index.html`, `dashboard/index.html`) and the smoke suite asserts that `lib/*.sh` returns 404 in production. CORS on the API Worker allows `https://practicum-cli.dev` with credentials. It must be responsive and usable on a tablet, since instructors often check progress from the front of a room.

---

## 3. Data model (D1)

```sql
-- migrations/0001_classroom.sql
CREATE TABLE classrooms (
  id TEXT PRIMARY KEY,                     -- cls_<ulid>
  name TEXT NOT NULL,
  owner_email TEXT NOT NULL,
  dodo_subscription_id TEXT UNIQUE,
  dodo_customer_id TEXT,
  status TEXT NOT NULL DEFAULT 'active',   -- active | grace | expired | cancelled
  learner_limit INTEGER NOT NULL DEFAULT 30,
  instructor_limit INTEGER NOT NULL DEFAULT 2,
  expires_at TEXT NOT NULL,
  grace_until TEXT,
  telegram_invite_url TEXT,
  is_test INTEGER NOT NULL DEFAULT 0,      -- smoke classrooms: suppress real email
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE members (
  id TEXT PRIMARY KEY,                     -- mem_<ulid>
  classroom_id TEXT NOT NULL REFERENCES classrooms(id),
  role TEXT NOT NULL,                      -- instructor | learner
  email TEXT NOT NULL,
  display_name TEXT,
  license_key_prefix TEXT,                 -- first 8 chars, for support lookups only
  license_key_hash TEXT,                   -- SHA-256; full key never stored in D1
  status TEXT NOT NULL DEFAULT 'invited',  -- invited | active | revoked
  invited_at TEXT NOT NULL DEFAULT (datetime('now')),
  activated_at TEXT,
  last_seen_at TEXT,
  revoked_at TEXT,
  UNIQUE (classroom_id, email)
);
CREATE INDEX idx_members_classroom ON members(classroom_id, role, status);

CREATE TABLE assignments (
  id TEXT PRIMARY KEY,                     -- asg_<ulid>
  classroom_id TEXT NOT NULL REFERENCES classrooms(id),
  content_type TEXT NOT NULL,              -- course | lesson | lab
  content_id TEXT NOT NULL,
  title TEXT NOT NULL,
  instructions TEXT,
  due_at TEXT,
  created_by TEXT NOT NULL REFERENCES members(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  archived_at TEXT
);

CREATE TABLE progress_events (
  event_id TEXT PRIMARY KEY,               -- client-generated, idempotency key
  classroom_id TEXT NOT NULL,
  member_id TEXT NOT NULL,
  content_id TEXT NOT NULL,
  event TEXT NOT NULL,                     -- lesson_started | lesson_completed | lab_passed | lab_failed
  occurred_at TEXT NOT NULL,
  received_at TEXT NOT NULL DEFAULT (datetime('now')),
  cli_version TEXT
);
CREATE INDEX idx_events_member ON progress_events(member_id, content_id);

CREATE TABLE progress_state (              -- upserted on ingest; what reports read
  member_id TEXT NOT NULL,
  content_id TEXT NOT NULL,
  classroom_id TEXT NOT NULL,
  status TEXT NOT NULL,                    -- started | completed | passed
  attempts INTEGER NOT NULL DEFAULT 0,
  first_completed_at TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (member_id, content_id)
);
CREATE INDEX idx_state_classroom ON progress_state(classroom_id);

CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  classroom_id TEXT NOT NULL,
  actor TEXT NOT NULL,                     -- member id | 'system' | 'dodo'
  action TEXT NOT NULL,
  detail TEXT,
  at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

Status transitions never regress (`passed` is not overwritten by a later `lab_failed`; failures only increment `attempts`).

---

## 4. API surface

Instructor routes require a session cookie and are always scoped to the session's `classroom_id` — never accept a classroom ID from the client.

```
POST   /v1/auth/magic-link                 { email }
GET    /v1/auth/verify?token=...           → sets cookie, 302 to /dashboard
POST   /v1/auth/logout

GET    /v1/classroom                       summary: seats used/limit, status, expires_at, telegram url
PATCH  /v1/classroom                       { name?, telegram_invite_url? }  (https://t.me/ only)

GET    /v1/classroom/members
POST   /v1/classroom/members               { email, display_name?, role }  → issues key, sends invite
POST   /v1/classroom/members/import        text/csv (email,display_name) → per-row result report
POST   /v1/classroom/members/:id/resend    rotates key, re-sends invite, old key revoked in KV
DELETE /v1/classroom/members/:id           revoke: KV license disabled, seat freed

GET    /v1/classroom/assignments
POST   /v1/classroom/assignments           { content_type, content_id, due_at?, instructions? }
PATCH  /v1/classroom/assignments/:id
DELETE /v1/classroom/assignments/:id       soft archive

GET    /v1/classroom/progress              matrix: learners × assigned content, plus cohort %
GET    /v1/classroom/progress/:member_id   one learner's full timeline
GET    /v1/classroom/export.csv?type=roster|progress|assignments

GET    /v1/content/manifest                public, cached

# Learner (CLI) routes — auth by license key header, text/plain responses
POST   /v1/progress                        form: event_id, content_id, event, occurred_at, cli_version
GET    /v1/learner/assignments             ASSIGN|<id>|<content_id>|<title>|<due_at>|<status>
GET    /v1/learner/community               COMMUNITY|<telegram_url>

POST   /webhooks/dodo                      extend existing handler for the Classroom product
```

Seat caps are checked inside the same D1 batch as the insert so two simultaneous invites cannot both take seat 30. CSV import is all-or-report: it processes valid rows up to the remaining capacity and returns a per-row outcome table (created / duplicate / invalid email / over capacity).

---

## 5. Phased execution

Five phases, each shippable and each ending with `wrangler deploy`, the Pages deploy, and `npm run smoke` green against production. A phase is not done until its smoke tests are in the suite, not just run once by hand.

### Phase 7A — Foundation and auth

Create the D1 database and migration, bind it plus a `SESSIONS` KV namespace in `wrangler.toml`, write the manifest generator, and implement magic-link auth with session cookies and CORS. Ship the dashboard shell: login page, "check your email" state, and an authenticated home showing the classroom summary. Add `scripts/seed-test-classroom.ts` to create an `is_test = 1` classroom with one instructor for smoke use; test classrooms route all email to a Resend test address.

- [ ] D1 `practicum-classroom` created, migration applied in prod
- [ ] `content/manifest.json` generated from repo, every lesson and lab has a stable ID
- [ ] Magic link works end to end; token single-use; expired token shows a friendly retry page
- [ ] Unknown email and non-instructor email both return identical 200s
- [ ] Dashboard home renders summary for the seeded test classroom
- [ ] Smoke: auth flow, session scoping (session A cannot read classroom B)

### Phase 7B — Seats and roster

Implement invite, CSV import, resend, and revoke. Invites generate a learner key, write it to `LICENSES` KV with `role: "learner"`, full entitlements, `classroom_id`, `member_id`, and `expires_at` equal to the classroom's; the invite email contains the key, the one-line install/activate command, and the Telegram link if set. Roster UI shows name, email, status, activated/last seen, and actions; include CSV template download and a clear "27 of 30 seats used" indicator.

- [ ] Hard caps enforced atomically (30 learners, 2 instructors)
- [ ] Revoke disables the KV license immediately and frees the seat
- [ ] Resend rotates the key; the old key stops validating
- [ ] CSV import returns per-row results; bad rows never block good ones
- [ ] `lib/license.sh` validates a learner key unchanged (backward compatibility)
- [ ] Every seat action written to `audit_log`
- [ ] Smoke: invite, 31st-seat rejection, revoke, key rotation

### Phase 7C — Progress pipeline (CLI ↔ API)

Add `lib/progress.sh` with `progress_emit <event> <content_id>` (appends a pipe-delimited line with a generated `event_id` to the outbox) and `progress_flush` (curls each line as form data, removes lines on 2xx, keeps them on failure). Hook emission into lesson completion and lab verification. Add the consent notice on first classroom activation. The Worker's `POST /v1/progress` validates the key, confirms the member is active, validates `content_id` against the manifest, inserts the event (ignoring duplicates), upserts `progress_state`, and bumps `last_seen_at`.

- [ ] Events generated with collision-safe IDs using only bash builtins, `date`, and `/dev/urandom`
- [ ] Offline: events queue and flush on next connection; replays are no-ops
- [ ] No events sent before consent; solo licenses never emit
- [ ] Revoked or expired learners get 403 and the CLI stops retrying those events
- [ ] Rate limit on `/v1/progress` per key
- [ ] **Classroom keys re-validate hourly; solo keys keep the 24h cache.** 7B
  made revocation real, but a revoked learner can keep working for up to 24h
  because `LICENSE_CACHE_TTL` is a flat 86400s — on top of KV propagation. An
  instructor reasonably expects removing a seat to take effect the same lesson.
  Since 7C is already changing `lib/license.sh`, make the TTL depend on the
  licence: 3600s when the cached record carries a `classroom_id`, 86400s
  otherwise. Solo learners keep working offline for a day; classroom learners
  lose at most an hour of staleness. The 7-day offline grace stays as-is for
  both — a flaky lab network must not lock a class out mid-session. Update
  `docs/classroom.md` ("up to a day" becomes "within about an hour") in the
  same change.
- [ ] Smoke: bash script emits, flushes, and the event appears in `progress_state`

### Phase 7D — Assignments, reporting, CSV, community

Assignment CRUD in the dashboard with a manifest-driven picker (course → lesson/lab), optional due date and instructions. `practicum assignments` in the CLI lists them with each learner's own status and marks overdue items. The progress view is the centerpiece: a learners × assignments matrix (not started / in progress / complete, color plus text label for accessibility), cohort completion % per assignment, and a drill-in per learner. CSV export offers roster, progress (one row per learner × content item), and assignments. Instructors set the Telegram invite link; `practicum community` prints it.

- [ ] Assignment CRUD with soft archive; learners see changes on next CLI call
- [ ] Matrix loads under 1s for 30 learners × 50 items (single aggregated query)
- [ ] CSV opens cleanly in Excel and Google Sheets (UTF-8 with BOM for the CSV file only, RFC 4180 quoting, ISO dates)
- [ ] Telegram URL validated as `https://t.me/...`
- [ ] Empty states written for zero learners, zero assignments, zero progress
- [ ] Smoke: assignment round-trip, progress report, all three CSV exports, community link

### Phase 7E — Commerce, lifecycle, and go-live

Extend the Dodo webhook for the Classroom product (`pdt_0No8Kgf2Z4FOleEA96DEW`): on subscription activation, create the classroom, make the purchaser instructor #1, and send the welcome email with a dashboard magic link. Map renewal to extending `expires_at` on the classroom and every active member's KV license; payment failure / on-hold to a 14-day `grace` status with a dashboard banner; cancellation to access through the paid period; expiry to learner keys losing paid entitlements while the dashboard stays read-only with CSV export for 90 days. Verify event names and signature scheme against current Dodo docs before coding; enforce webhook idempotency via the existing `ORDERS` namespace. Run a complete purchase in Dodo test mode, then flip the site CTA from the waitlist mailto to the live checkout.

- [ ] Webhook signature verified; duplicate deliveries are no-ops
- [ ] Test-mode purchase → classroom created → magic link → invite learner → learner completes a lab → shows in report → CSV export
- [ ] Renewal, grace, cancellation, and expiry each simulated and verified
- [ ] Waitlist subscribers emailed that Classroom is open (separate send, after go-live)
- [ ] CTA flipped only after every row in §1 has passing prod evidence

---

## 6. Sprint Definition of Done

- [ ] All five phase checklists complete
- [ ] Every §1 promise backed by an automated smoke test in `npm run smoke`
- [ ] CLI changes pass existing tests plus `tests/smoke_classroom.sh`; no `jq`, only grep/sed/cut
- [ ] `wrangler deploy` and Pages deploy to production, smoke green afterward
- [ ] Dashboard verified on desktop and tablet widths, keyboard navigable
- [ ] No full license key stored in D1 or written to logs
- [ ] `docs/classroom.md` written: instructor quickstart, learner quickstart, privacy notice text
- [ ] Classroom CTA live on practicum-cli.dev

## 7. Out of scope

Telegram bot automation (Phase 2), paid-content-in-public-repo remediation (audit item 1), LMS integrations, multi-classroom organizations, per-seat add-on purchases, and SSO.

## 8. Decisions to confirm before 7E

Whether revoked seats can be reassigned without limit (a per-term reassignment cap, e.g. 30, prevents one classroom rotating access across hundreds of people), whether classroom learners keep read access to completed courses after expiry, and the retention window for progress data after cancellation (90 days proposed).
