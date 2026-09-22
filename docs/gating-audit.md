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

| Product | Price | Sold as | Enforced as |
|---|---|---|---|
| Single Course | $49 | one course | **all 8 courses** (any valid key unlocks everything) |
| Data Engineering Track | $99 | Linux + Shell + Data Forging | all 8 courses |
| Platform Engineering Track | $129 | Linux + Git + Docker + CI/CD + Terraform + K8s | all 8 courses |
| Full Catalog v3 | $199 | all 8 courses | all 8 courses |
| Team 5 Seats | $899 | full catalog × 5 learners | all 8 courses; seat count = Dodo activation limit only |
| Team 10 Seats | $1,599 | full catalog × 10 learners | all 8 courses; seat count = Dodo activation limit only |

There is no product/entitlement concept in the client. `activate_license` stores the key
and prints "All premium content is now unlocked." (`lib/license.sh:73`). The only
per-product differentiation available today is the activation limit configured on each
Dodo license-key product (server side). Team seats therefore work as "N device
activations on one key" — there is no learner identity, dashboard, or completion
tracking despite the landing-page copy.

## Gate Mechanism

- **License check location:** `lib/license.sh:227` `can_access_day` → `lib/license.sh:98` `validate_license`. Call sites: `practicum:230` (Linux Foundations day menu) and `practicum:238` (generic day menu). Those are the **only two** call sites.
- **License format:** opaque Dodo Payments license key string (whatever Dodo issues; the client does not parse or checksum it). Validated via public endpoints `POST https://api.dodopayments.com/licenses/activate|validate|deactivate` (`lib/license.sh:6`).
- **Local storage:** `~/.practicum/license.json` (`lib/license.sh:7`), plain text: `license_key`, `instance_id`, `device`, `activated_at`, `last_validated`, `valid`. No env-var override exists.
- **Validation commands:** `practicum activate <key>` (`practicum:1506`), `practicum deactivate` (`:1509`), `practicum license` (`:1511`, status only — prints ACTIVE / FREE). There is no `practicum license verify`; validation runs lazily inside `can_access_day` when a premium day is opened.
- **Gate enforcement level:** **day** (day ≥ 4 of any course). Not per-course, not per-lesson, not per-product.
- **Error message on block:** the `show_upgrade_prompt` box, headed
  `🔒 Premium Content — License Required` / `Days 1-3 are free. Days 4-10 require a license.`
  On failed activation: `❌ Activation failed.` followed by one of
  `This key has reached its activation limit.`, `This license key has expired.`,
  `Invalid license key. Check for typos.`, or `Error: <raw body>`.
- **Trial/grace period:** No trial beyond Days 1–3. **Offline grace: 7 days** (`LICENSE_CACHE_DAYS=7`, `lib/license.sh:8`) — if `last_validated` is < 7 days old and the file says `"valid": true`, no network call is made. If curl is missing, the cache is trusted indefinitely. If online validation fails but the cache is inside the 7-day window, access is still granted.

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
4. **Quizzes for premium days are ungated.** `cmd_quiz_select` (`practicum:666`) → `cmd_quiz_day4..10` / `cmd_generic_quiz_day` (`practicum:390`) never call `can_access_day`. An unlicensed learner can take and pass every quiz.
5. **Certificates are ungated.** `cmd_certificate` (`practicum:748`) only requires the free Day 1 quiz. Combined with (4), a free learner can produce a full-course certificate.
6. **CLI Immersion Day 4 is wrongly gated** — contradicts the "all 4 days free" promise on the landing page. One-line fix: exempt `00-cli-immersion` in `is_premium_content` (needs a course argument).
7. **Team products have no team semantics.** No learner identity, no dashboard, no completion tracking — a seat is just an activation slot. Landing-page copy ("Team dashboard · Completion tracking") over-promises relative to v3.1.0.
8. **`show_upgrade_prompt` prices are stale.** It advertises "Practicum Silver $129/year", "Gold $199/year", "Early bird $79/yr" — subscription tiers that no longer exist. The site sells one-time Tracks/Catalog. Update `lib/license.sh:239`–`262` to match live pricing.
9. **Scores are not namespaced per course.** `scores.txt` keys collide across courses, so passing the Day 4 quiz in Linux Foundations marks it passed in Kubernetes. Affects the Labs gate and certificate accuracy.
10. **Grace-period edge cases.** `date -d` is GNU-only; on macOS/BSD it fails, `last_epoch` becomes 0, `diff_days` is huge, so the offline cache is *never* trusted — licensed macOS users are hard-blocked when offline. Conversely, no-curl systems trust the cache forever.
11. **Version drift.** `practicum` reports 3.0.0; git history is at v3.1.0.

### Minimal hardening order
1. Gate quizzes and certificates with `can_access_day` (closes 4, 5).
2. Exempt CLI Immersion (closes 6). Refresh `show_upgrade_prompt` copy (closes 8).
3. Read `product_id` from the Dodo `validate` response and scope `can_access_day` by course (closes 3).
4. Move premium course content out of the public repo (fetch on activation, or ship encrypted and decrypt with a server-issued key) — the only real fix for 1 and 2.
