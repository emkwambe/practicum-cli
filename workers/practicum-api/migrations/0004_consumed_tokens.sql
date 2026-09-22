-- Single-use enforcement for magic-link tokens.
--
-- Consumption was previously enforced by deleting the token from KV, but KV is
-- eventually consistent: production showed a token still redeeming from an edge
-- cache after its delete, which makes "single use" untrue for a short window.
-- D1 is strongly consistent, so an INSERT that reports 0 changes is proof the
-- token was already spent. The KV delete stays as best-effort cleanup.

CREATE TABLE IF NOT EXISTS consumed_tokens (
  token_hash TEXT PRIMARY KEY,
  consumed_at TEXT NOT NULL DEFAULT (datetime('now'))
);
