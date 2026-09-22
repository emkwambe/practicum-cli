-- Sprint 7B — seat provisioning.
-- email_status records whether the invite actually reached the learner: a seat
-- is kept even when Resend fails, so the instructor can retry rather than lose
-- it. rotations increments on every resend and feeds the licence key HMAC, so
-- a rotated key differs from the one it replaces.

ALTER TABLE members ADD COLUMN email_status TEXT NOT NULL DEFAULT 'pending';  -- pending | sent | failed
ALTER TABLE members ADD COLUMN rotations INTEGER NOT NULL DEFAULT 0;
