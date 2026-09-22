# Practicum CLI — Access Gating Audit
**Date:** 2026-09-21
**Version:** v3.1.0 (`practicum` header still reads 3.0.0)

Scope: every code path in `practicum` and `lib/` that decides whether a learner can
see or run content, compared against what practicum-cli.dev sells.

## Free Tier Gates

| Claim (landing page) | Implemented? | Where |
|---|---|---|
| Days 1–3 of every course free | Yes | `practicum:230`, `practicum:238` — `[ "$day_num" -le 3 ] \|\| can_access_day "day${day_num}"`; `lib/license.sh:218` `is_premium_content` returns free for `day1\|day2\|day3` |
| CLI Immersion fully free (4 days) | **No — Day 4 is gated** | Same check: `day4` of `00-cli-immersion` hits `can_access_day` → `validate_license` → `show_upgrade_prompt`. No course-level exemption exists anywhere. |
| No credit card at install | Yes | `install.sh` / `git clone` — no account, no key required. `init_license` (`lib/license.sh:11`) only runs `mkdir -p ~/.practicum`. |

**Day 4 attempt without a license:** from `practicum start`, choosing `4`+ calls
`can_access_day` → `validate_license` finds no `~/.practicum/license.json`, returns 1 →
`show_upgrade_prompt` (`lib/license.sh:239`) prints the upgrade box and returns to the
menu. Same behaviour for both the hardcoded Linux Foundations menu and the generic menu.

## Paid Tier Gates

| Product | Price | Sold as | Enforced as (since `practicum-api`) |
|---|---|---|---|
| Single Course | $49 | one course | that course only |
| Data Engineering Track | $99 | Linux + Shell + Data Forging | `linux-foundations shell-mastery data-forging` |
| Platform Engineering Track | $129 | Linux + Git + Docker + CI/CD + Terraform + K8s | `linux-foundations git-essentials docker-essentials cicd-pipelines terraform-iac kubernetes` |
| Full Catalog v3 | $199 | all 8 courses | all 8 |
| Team 5 Seats | $899 | full catalog × 5 learners | all 8; `seats: 5` recorded, **not enforced** |
| Team 10 Seats | $1,599 | full catalog × 10 learners | all 8; `seats: 10` recorded, **not enforced** |

Entitlements are decided server-side: `workers/practicum-api/src/index.ts`
`PRODUCT_ENTITLEMENTS` maps each Dodo `product_id` to course slugs (matching
`courses/<slug>/`). The CLI never sees a product→course map; it stores the
`entitlements` array the server returns and `can_access_course` checks membership.
Team seats are still only a number on the record — there is no learner identity,
dashboard, or completion tracking despite the landing-page copy (item 7).

*(Before `practicum-api`: no entitlement concept; any valid key unlocked all 8 courses.)*

## Gate Mechanism

- **License check location:** `lib/license.sh:213` `can_access_day <dayN> [course]` → `lib/license.sh:201` `can_access_course <slug>` → `lib/license.sh:158` `validate_license`. Call sites: `practicum:230` / `:238` (day menus) and `:714` (quiz select).
- **Key issuance:** `workers/practicum-api` (Cloudflare Worker, `api.practicum-cli.dev`). Dodo `payment.succeeded` webhook → Standard-Webhooks HMAC signature check (5-min tolerance) → key = `PRAC-XXXX-XXXX-XXXX-XXXX` (first 16 hex of `HMAC-SHA256(HMAC_SECRET, payment_id)`) → KV `LICENSES[key] = {email, product_id, entitlements, seats, activated, revoked…}`, `ORDERS[payment_id] = key` for idempotency → key emailed via Resend. `refund.succeeded` / `dispute.*` set `revoked: true`.
- **License format:** `PRAC-` + 4×4 upper-hex. The client normalises case/whitespace and otherwise treats it as opaque; only the server can say whether it exists.
- **Local storage:** `~/.practicum/license.json` (`lib/license.sh:11`, mode 600), written **only** from a server response: `key`, `email`, `product_id`, `entitlements` (space-separated slugs), `seats`, `activated_at`, `cached_epoch`, `valid`. `PRACTICUM_API` env var overrides the server URL (used by tests).
- **Validation commands:** `practicum activate <key>` (`GET /license/validate`, writes cache), `practicum deactivate` (deletes the local cache only), `practicum license` (status: masked key, email, course list). Revalidation runs lazily inside `can_access_course` when the cache is older than 24 h.
- **Gate enforcement level:** **course × day** — day ≥ 4 of a course requires that course's slug in `entitlements`. Days 1–3 and all of `00-cli-immersion` (`FREE_COURSES`) bypass the check.
- **Error message on block:** the `show_upgrade_prompt` box, headed `🔒 Premium Content — License Required`, then either `Days 1-3 are free. Days 4+ require a license.` (no license) or `Your license does not include <Course Name>.` (licensed, wrong product). On failed activation: `❌ Activation failed.` + the server's `error` (`License not found`, `License revoked`) or `❌ Could not reach the license server.`
- **Trial/grace period:** No trial beyond Days 1–3. **Cache TTL 24 h** (`LICENSE_CACHE_TTL`) — no network call while fresh. Past TTL the client revalidates; if the server answers `valid:false` the cache is deleted immediately; if the server is unreachable the cache is honoured up to **7 days** after the last successful validation (`LICENSE_OFFLINE_GRACE`), then blocked. Epochs are stored as integers, so no `date -d` (portable to macOS/BSD).

## Planned: Labs Gate (v3.0.0 roadmap)

Not implemented. Nothing in `practicum`, `lib/apprentice.sh`, or `lib/` references labs
eligibility today. Planned design:

- **Eligibility rule:** all 5 core courses complete **and** Lab 001 passed with score ≥ 70 **and** at least one additional lab passed.
- **Where it will live:** a new `lib/labs.sh` with `can_access_lab <lab-id>` mirroring `can_access_day`, called from a `labs` case in the `practicum` dispatch (`practicum:1490`–`1555`) and from a `[l] Labs` item in the `cmd_start` menu.
- **State file:** `~/.practicum/labs/{lab-id}/state.json` carrying `{ "passed": bool, "score": int, "attempts": int, "completed_at": iso8601 }`. Course completion should be read from the existing `~/.practicum/scores.txt` (`final_capstone` = passed per course) rather than duplicated.
- **Dependency:** requires per-course score namespacing first — `scores.txt` keys (`day1_quiz`, `final_capstone`) are not prefixed by course slug today, so "all 5 courses complete" cannot be computed reliably (see Gaps, item 9).

## Gaps and Risks

Ordered by severity.

1. **All paid content ships in plain text in the public repo.** `courses/*/day4..day10/*.txt`, every quiz, and every capstone test are readable with `cat` or on GitHub without any license. The CLI gate only controls the *menu*, not the content. This is the fundamental weakness; every other gap is secondary to it.
2. **`~/.practicum/license.json` is self-asserted.** A hand-written file with any `license_key`, `"valid": true`, and a fresh `last_validated` passes `validate_license` for 7 days, and can be re-dated forever. No signature, no HMAC, no server-issued token is checked.
3. **No product entitlement — a $49 key unlocks $199 of content.** Single Course and both Tracks are enforced identically to Full Catalog. Fix requires the client to read the product ID from the Dodo `validate` response (or embed a product→course map keyed on `product_id`), then have `can_access_day` take the course slug.
4. ~~**Quizzes for premium days are ungated.**~~ **RESOLVED in `ce90d8a`.** `cmd_quiz_select` now calls `can_access_day "day${qchoice}" "$active_slug"` before dispatch and returns 1 with the upgrade prompt on block. *(Was: `practicum:666` → `cmd_quiz_day4..10` / `cmd_generic_quiz_day` never checked the license.)*
5. **Certificates are ungated.** `cmd_certificate` (`practicum:748`) only requires the free Day 1 quiz. Combined with (4), a free learner can produce a full-course certificate.
6. ~~**CLI Immersion Day 4 is wrongly gated**~~ **RESOLVED in `ce90d8a`.** `can_access_day` now takes an optional course arg (defaults to the active course) and returns 0 for `00-cli-immersion` on every day. *(Was: the `day_num -le 3` check had no course exemption.)*
7. **Team products have no team semantics.** No learner identity, no dashboard, no completion tracking — a seat is just an activation slot. Landing-page copy ("Team dashboard · Completion tracking") over-promises relative to v3.1.0.
8. ~~**`show_upgrade_prompt` prices are stale.**~~ **RESOLVED in `ce90d8a`.** Prompt now lists Single Course $49 / Data Engineering $99 / Platform Eng $129 / Full Catalog $199, one-time, linking to `practicum-cli.dev/#pricing`. `grep -r "Silver\|Gold\|/month\|/year\|subscription" lib/` → 0. *(Was: Silver/Gold yearly tiers and an early-bird offer.)*
9. **Scores are not namespaced per course.** `scores.txt` keys collide across courses, so passing the Day 4 quiz in Linux Foundations marks it passed in Kubernetes. Affects the Labs gate and certificate accuracy.
10. **Grace-period edge cases.** `date -d` is GNU-only; on macOS/BSD it fails, `last_epoch` becomes 0, `diff_days` is huge, so the offline cache is *never* trusted — licensed macOS users are hard-blocked when offline. Conversely, no-curl systems trust the cache forever.
11. **Version drift.** `practicum` reports 3.0.0; git history is at v3.1.0.

### Minimal hardening order
1. ~~Gate quizzes with `can_access_day` (closes 4).~~ Done `ce90d8a`. Certificates (5) still open.
2. ~~Exempt CLI Immersion (closes 6). Refresh `show_upgrade_prompt` copy (closes 8).~~ Done `ce90d8a`.
3. Read `product_id` from the Dodo `validate` response and scope `can_access_day` by course (closes 3).
4. Move premium course content out of the public repo (fetch on activation, or ship encrypted and decrypt with a server-issued key) — the only real fix for 1 and 2.

**Changelog:** 2026-09-22 — items 4, 6, 8 resolved in `ce90d8a`.
