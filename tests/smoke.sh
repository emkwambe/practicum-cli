#!/bin/bash
# npm run smoke — every suite, against production by default.
#
#   npm run smoke                                  # production
#   API=http://127.0.0.1:8787 SITE=http://127.0.0.1:8788 npm run smoke
#
# Each suite is self-contained and exits non-zero on failure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
API="${API:-https://api.practicum-cli.dev}"
SITE="${SITE:-https://practicum-cli.dev}"
export API SITE

failed=0
run() {  # $1 = label, $2 = script path
    echo ""
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
    if bash "$2"; then
        echo "  → $1 OK"
    else
        echo "  → $1 FAILED"
        failed=$((failed + 1))
    fi
}

echo "API:  $API"
echo "SITE: $SITE"

# Repo-level lints first: they need no network and catch the two classes of
# mistake that are expensive once deployed.
run "lint: unlock chains" "$HERE/lint_unlock_chains.sh"
run "lint: asset allow-list" "$HERE/lint_assets.sh"

run "progress CLI (7C, local mechanics)" "$HERE/test_progress_cli.sh"
run "classroom (sprint 7A/7B/7C)" "$HERE/smoke_classroom.sh"

# The license suite mints keys by signing fake Dodo webhooks, so it only runs
# against a local `wrangler dev` that has .dev.vars. Against production it is
# skipped rather than reported as a failure.
if [ -f "$ROOT/workers/practicum-api/.dev.vars" ] && printf '%s' "$API" | grep -q '127.0.0.1\|localhost'; then
    ( cd "$ROOT/workers/practicum-api" && API="$API" bash test/e2e.sh ) && \
        echo "  → license api OK" || { echo "  → license api FAILED"; failed=$((failed + 1)); }
else
    echo ""
    echo "  (skipped: license api — needs local wrangler dev + .dev.vars)"
fi

echo ""
if [ "$failed" -eq 0 ]; then
    echo "ALL SUITES PASSED"
else
    echo "$failed SUITE(S) FAILED"
fi
exit "$failed"
