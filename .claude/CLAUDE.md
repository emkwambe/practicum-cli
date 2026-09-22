# Practicum CLI

## Overview
CLI-native Linux courses. Intent → Context → Action → Result.
The foundation platform for all CLI:CE courses.

## Tech Stack
- Bash 4+ (POSIX compatible)
- Coreutils only (no jq, no Python, no Node, no Docker)
- State stored in ~/.practicum/ as plain text

## Architecture
- practicum — main entrypoint, sources all libs
- lib/state.sh — progress tracking, scores, unlocking
- lib/lessons.sh — lesson loader and listing
- lib/quiz_engine.sh — multiple-choice quiz grader
- lib/modes.sh — WIZARD/LAB/FIELD/LMS mode switching
- lib/sandbox.sh — sandbox init, snapshot, restore
- lib/wrappers.sh — ICAR display, command wrapping for LAB/WIZARD
- courses/linux-foundations/day1/ — lesson and quiz files

## Key Commands
./practicum --help
./practicum start
./practicum status
./practicum quiz
./practicum wizard
./practicum lab
./practicum field
./practicum snapshot save|restore|list

## Development
- Windows dev: use [System.IO.File]::WriteAllText() for BOM-free UTF-8
- Test with Git Bash or WSL: bash practicum status
- No cd required — use absolute paths
- In PowerShell, `bash` resolves to WSL and cannot reach a Windows-hosted
  127.0.0.1. Use "C:\Program Files\Git\bin\bash.exe" for local smoke runs.

## Standing rules

These hold until explicitly revoked. They encode decisions that are expensive
or embarrassing to get wrong, not preferences.

**1. The Classroom CTA stays a waitlist mailto.**
`lib/index.html`'s Classroom tile links to `mailto:practicum@mpingo.ai`. It must
not become a live Dodo checkout until audit item 7 is fully built and verified in
production against every promise the tile makes — instructor dashboard,
assignments, cohort progress, completion reporting, CSV export, Telegram group.
Selling the tier before those exist invites refund disputes. The Dodo product
(`pdt_0No8Kgf2Z4FOleEA96DEW`) and its entitlements already exist server-side;
that is not permission to link to it.

**2. `lib/*.sh` must never be publicly served.**
The site worker `blue-pine-8359` serves `./lib`, which also holds the CLI's
shell libraries. `lib/.assetsignore` denies everything and allows exactly
`index.html` and `dashboard/index.html`. `tests/lint_assets.sh` fails the build
if that allow-list gains anything else, and the production smoke asserts every
`lib/*.sh` returns 404 after each deploy. Adding a published page means adding
it to both the allow-list and the lint's expected set — never widening the
allow-list with a glob.

**3. All new Dodo products are recurring yearly. No one-time products.**
The site sells annual licences with no autorenewal, and `practicum-api` stamps
`expires_at = created_at + 365d` on every key. A one-time product would mint a
key the copy describes as annual, which the platform then expires.

**4. Content IDs are permanent.**
`content/ids.lock.json` maps id → path and is the source of truth;
`content/manifest.json` is generated from it. `npm run manifest` carries
existing IDs forward, mints only for unseen files, and fails hard on any
within-course collision. Never hand-edit or delete a lock entry: progress rows
in D1 key on these IDs. Renaming a lesson file changes its slug and therefore
its ID — treat that as a migration, not a rename.