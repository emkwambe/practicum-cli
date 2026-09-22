#!/bin/bash
# Fails if lib/.assetsignore allows anything beyond the two published files.
#
# The site worker serves ./lib, which also holds the CLI's shell libraries
# (license.sh, state.sh, …). The allow-list is the only thing keeping them off
# a public origin, so it is checked before every deploy and the prod smoke
# re-checks the result afterwards.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/lib/.assetsignore"
EXPECTED="index.html
dashboard/index.html"

if [ ! -f "$FILE" ]; then
    echo "  FAIL  lib/.assetsignore is missing — every lib/*.sh would be published"
    exit 1
fi

if ! grep -qx '\*' "$FILE"; then
    echo "  FAIL  lib/.assetsignore does not start from a deny-all '*' rule"
    exit 1
fi

allowed=$(grep '^!' "$FILE" | sed 's/^!//' | sed 's#/\*\*$##' | sort -u)
expected=$(printf '%s\n' "$EXPECTED" | sort -u)

if [ "$allowed" = "$expected" ]; then
    echo "  PASS  asset allow-list is exactly: $(printf '%s' "$expected" | tr '\n' ' ')"
    exit 0
fi

echo "  FAIL  asset allow-list has drifted"
echo "        allowed:  $(printf '%s' "$allowed" | tr '\n' ' ')"
echo "        expected: $(printf '%s' "$expected" | tr '\n' ' ')"
exit 1
