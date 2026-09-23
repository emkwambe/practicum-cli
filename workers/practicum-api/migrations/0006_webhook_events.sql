-- Delivery-level idempotency for Dodo webhooks, keyed on the Standard Webhooks
-- `webhook-id` header.
--
-- The old scheme deduped on the payment id held in the ORDERS namespace, which
-- does not extend to subscription lifecycle events: subscription.renewed and
-- friends carry a subscription_id and no payment id at all, so a retried
-- delivery had nothing to dedupe against.
--
-- This is D1 rather than KV for the same reason consumed_tokens is (migration
-- 0004): KV is eventually consistent, so a duplicate delivery inside the
-- consistency window can read back "not yet seen" and be processed twice. For a
-- renewal that means extending a licence by 730 days instead of 365. An INSERT
-- reporting 0 changes is proof the delivery was already handled.
--
-- Rows are swept by the handler opportunistically; Dodo's retry window is hours,
-- so anything older than 30 days is noise.

CREATE TABLE IF NOT EXISTS webhook_events (
  webhook_id   TEXT PRIMARY KEY,
  event_type   TEXT NOT NULL,
  received_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_received ON webhook_events (received_at);
