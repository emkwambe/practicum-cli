-- Per-member hourly cap for POST /v1/progress, moved out of KV.
--
-- The cap used to be a KV counter: read the current value, compare, write
-- value+1. That is a read-modify-write across an eventually consistent store,
-- so two events arriving together both read the same number and both write the
-- same increment — one of them is lost and the cap leaks. It was also the
-- single largest source of KV writes on the platform: one write per progress
-- event, roughly 750 of the ~760 KV writes a 30-seat classroom made in a day.
--
-- D1 is strongly consistent and the handler is already writing to it for every
-- event, so the counter belongs here. A single UPSERT ... RETURNING both
-- increments and reports the new value atomically, which makes the cap exact
-- rather than approximate.
--
-- Windows are fixed hour buckets, not a sliding hour: window_start holds
-- strftime('%Y-%m-%dT%H','now') (UTC), evaluated by SQLite inside the same
-- statement as the increment so every worker agrees on the boundary regardless
-- of edge clock skew. When the stored bucket is older than the current one the
-- same statement resets the count to 1.
--
-- One row per member, so the table is bounded by roster size and needs no
-- sweeping.

CREATE TABLE IF NOT EXISTS progress_rate (
  member_id    TEXT PRIMARY KEY,
  classroom_id TEXT NOT NULL,
  window_start TEXT NOT NULL,
  used         INTEGER NOT NULL DEFAULT 0,
  updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
