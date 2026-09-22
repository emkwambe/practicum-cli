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

# Entries ending in "/" are structural: gitignore semantics never look inside a
# directory that "*" excluded, so a directory must be re-included before a file
# in it can be. They publish nothing themselves, so they are not counted here —
# but a glob (dashboard/**) would publish everything and is not stripped.
allowed=$(grep '^!' "$FILE" | sed 's/^!//' | grep -v '/$' | sort -u)
expected=$(printf '%s\n' "$EXPECTED" | sort -u)

if grep -q '^!.*\*' "$FILE"; then
    echo "  FAIL  allow-list contains a glob — it must name each published file"
    grep '^!.*\*' "$FILE" | sed 's/^/        /'
    exit 1
fi

if [ "$allowed" != "$expected" ]; then
    echo "  FAIL  asset allow-list has drifted"
    echo "        allowed:  $(printf '%s' "$allowed" | tr '\n' ' ')"
    echo "        expected: $(printf '%s' "$expected" | tr '\n' ' ')"
    exit 1
fi
echo "  PASS  asset allow-list is exactly: $(printf '%s' "$expected" | tr '\n' ' ')"

# The allow-list names exactly one file in lib/dashboard/, so anything else
# dropped in there is dead weight at best — and an unreviewed published file the
# moment someone widens the list. Fail while it is cheap to notice.
extra=$(find "$ROOT/lib/dashboard" -type f ! -name 'index.html' 2>/dev/null)
if [ -n "$extra" ]; then
    echo "  FAIL  lib/dashboard/ must contain only index.html"
    printf '%s\n' "$extra" | sed "s#^$ROOT/#        #"
    exit 1
fi
echo "  PASS  lib/dashboard/ contains only index.html"
exit 0
