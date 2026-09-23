#!/bin/bash
# Type-checks workers/practicum-api. Part of `npm run smoke`, run before any
# network suite: it needs nothing but node, and a type error is cheaper to find
# here than after a deploy.
#
# Standing rule 7 in .claude/CLAUDE.md explains why this is a gate and not a
# convenience: the check could not install at all until 78f3208.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/workers/practicum-api"

if ! command -v node >/dev/null 2>&1; then
    echo "  FAIL  node is not on PATH — cannot type-check the worker"
    exit 1
fi

# The check is worthless if it silently skips, so a missing tree is installed,
# not shrugged at.
if [ ! -x "$API_DIR/node_modules/.bin/tsc" ]; then
    echo "  installing worker dev dependencies (npm ci)…"
    ( cd "$API_DIR" && npm ci --silent ) || {
        echo "  FAIL  npm ci failed — the worker cannot be type-checked"
        exit 1
    }
fi

out=$( cd "$API_DIR" && ./node_modules/.bin/tsc --noEmit 2>&1 )
if [ -n "$out" ]; then
    echo "$out"
    echo "  FAIL  tsc reported $(printf '%s\n' "$out" | grep -c '^src/.*error TS') error(s)"
    exit 1
fi

echo "  PASS  practicum-api type-checks clean"
