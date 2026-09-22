-- Sprint 7 — Classroom tier relational store.
-- Licenses stay in the LICENSES KV namespace; everything relational lives here.

CREATE TABLE IF NOT EXISTS classrooms (
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

CREATE TABLE IF NOT EXISTS members (
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
CREATE INDEX IF NOT EXISTS idx_members_classroom ON members(classroom_id, role, status);

CREATE TABLE IF NOT EXISTS assignments (
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

CREATE TABLE IF NOT EXISTS progress_events (
  event_id TEXT PRIMARY KEY,               -- client-generated, idempotency key
  classroom_id TEXT NOT NULL,
  member_id TEXT NOT NULL,
  content_id TEXT NOT NULL,
  event TEXT NOT NULL,                     -- lesson_started | lesson_completed | lab_passed | lab_failed
  occurred_at TEXT NOT NULL,
  received_at TEXT NOT NULL DEFAULT (datetime('now')),
  cli_version TEXT
);
CREATE INDEX IF NOT EXISTS idx_events_member ON progress_events(member_id, content_id);

CREATE TABLE IF NOT EXISTS progress_state (  -- upserted on ingest; what reports read
  member_id TEXT NOT NULL,
  content_id TEXT NOT NULL,
  classroom_id TEXT NOT NULL,
  status TEXT NOT NULL,                    -- started | completed | passed
  attempts INTEGER NOT NULL DEFAULT 0,
  first_completed_at TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (member_id, content_id)
);
CREATE INDEX IF NOT EXISTS idx_state_classroom ON progress_state(classroom_id);

CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  classroom_id TEXT NOT NULL,
  actor TEXT NOT NULL,                     -- member id | 'system' | 'dodo'
  action TEXT NOT NULL,
  detail TEXT,
  at TEXT NOT NULL DEFAULT (datetime('now'))
);
