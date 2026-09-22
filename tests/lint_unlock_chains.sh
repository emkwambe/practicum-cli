#!/bin/bash
# Fails if any course's unlock_chain.txt has a duplicate left-hand key.
#
# The CLI resolves a chain with `grep "^${cmd}|"` and takes the first hit, so a
# repeated key silently sends learners down the wrong branch — that is how
# docker-essentials once unlocked Day 1 content from a Day 4 lesson. Lesson
# keys are derived from filenames (basename minus the lessonN_ prefix), so a
# duplicate here usually means two lesson files share a slug within a course.
#
# grep/sed/cut/awk only — no jq.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

for chain in "$ROOT"/courses/*/unlock_chain.txt; do
    [ -f "$chain" ] || continue
    course=$(basename "$(dirname "$chain")")

    dupes=$(grep -v '^#' "$chain" | grep '|' | cut -d'|' -f1 | sed 's/[[:space:]]*$//' \
            | grep -v '^$' | sort | uniq -d)

    if [ -n "$dupes" ]; then
        echo "  FAIL  $course: duplicate unlock keys"
        while IFS= read -r key; do
            [ -n "$key" ] || continue
            echo "          $key"
            grep -n "^${key}|" "$chain" | sed 's/^/            /'
        done <<< "$dupes"
        fail=$((fail + 1))
    else
        echo "  PASS  $course: unlock keys unique"
    fi
done

echo ""
if [ "$fail" -eq 0 ]; then
    echo "  unlock chains OK"
else
    echo "  $fail course(s) with duplicate unlock keys"
fi
exit "$fail"
