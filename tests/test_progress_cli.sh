#!/bin/bash
# CLI-side progress mechanics, run in a throwaway HOME. No network required
# except the flush test, which is pointed at $API.
#
#   bash tests/test_progress_cli.sh
#
# Covers what the server-side smoke cannot see: the outbox, the consent gate,
# solo silence, id collision-safety, and offline queueing.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="${API:-https://api.practicum-cli.dev}"

pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1"; fail=$((fail+1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK"
mkdir -p "$HOME/.practicum"

# shellcheck disable=SC1091
cd "$ROOT" || exit 1
. lib/colors.sh; . lib/state.sh; . lib/lessons.sh; . lib/license.sh; . lib/progress.sh
init_state; init_license

write_license() {  # $1 = classroom_id ("" for a solo license)
    cat > "$LICENSE_FILE" <<JSON
{
    "key": "PRAC-TEST-TEST-TEST-TEST",
    "email": "learner@example.com",
    "entitlements": "linux-foundations",
    "classroom_id": "$1",
    "member_id": "mem_test",
    "expires_epoch": "9999999999",
    "cached_epoch": "$(date +%s)",
    "valid": "true"
}
JSON
}

echo "== solo licenses never emit"
write_license ""
rm -f "$PROGRESS_CONSENT" "$PROGRESS_OUTBOX"
progress_emit "lesson_completed" "linux-foundations/lesson/pwd"
[ -f "$PROGRESS_OUTBOX" ] && bad "solo license wrote to the outbox" || ok "solo license wrote nothing"

echo "== nothing is emitted before consent"
write_license "cls_test"
rm -f "$PROGRESS_CONSENT" "$PROGRESS_OUTBOX"
progress_emit "lesson_completed" "linux-foundations/lesson/pwd"
[ -f "$PROGRESS_OUTBOX" ] && bad "emitted without consent" || ok "no consent, no events"

echo "== after consent, events queue"
progress_sharing on >/dev/null
progress_emit "lesson_started"   "linux-foundations/lesson/pwd"
progress_emit "lesson_completed" "linux-foundations/lesson/pwd"
if [ -f "$PROGRESS_OUTBOX" ]; then
    check "two events queued" "$(grep -c . "$PROGRESS_OUTBOX")" "2"
    grep -q '^ev-[0-9]\{8\}T[0-9]\{6\}Z-[0-9]*-[0-9]*-[0-9a-f]\{16\}|' "$PROGRESS_OUTBOX" \
        && ok "event ids are well formed" || bad "event id shape is wrong: $(head -1 "$PROGRESS_OUTBOX" | cut -c1-50)"
    head -1 "$PROGRESS_OUTBOX" | grep -q '|linux-foundations/lesson/pwd|lesson_started|' \
        && ok "line carries content id and event" || bad "line is malformed"
else
    bad "consent given but nothing queued"
fi

echo "== event ids do not collide"
rm -f "$PROGRESS_OUTBOX"
i=0
while [ "$i" -lt 200 ]; do progress_emit "lesson_completed" "linux-foundations/lesson/ls"; i=$((i+1)); done
total=$(cut -d'|' -f1 < "$PROGRESS_OUTBOX" | wc -l | tr -d ' ')
uniq_n=$(cut -d'|' -f1 < "$PROGRESS_OUTBOX" | sort -u | wc -l | tr -d ' ')
check "200 ids, all distinct" "$uniq_n" "$total"

echo "== offline: a failed flush keeps every event"
rm -f "$PROGRESS_OUTBOX"
progress_emit "lesson_completed" "linux-foundations/lesson/pwd"
before=$(grep -c . "$PROGRESS_OUTBOX")
PRACTICUM_API="http://127.0.0.1:9" progress_flush
if [ -f "$PROGRESS_OUTBOX" ]; then
    check "events survive an unreachable server" "$(grep -c . "$PROGRESS_OUTBOX")" "$before"
else
    bad "outbox was discarded when the server was unreachable"
fi

echo "== sharing off clears the queue and stops emission"
progress_sharing off >/dev/null
[ -f "$PROGRESS_OUTBOX" ] && bad "queue survived sharing off" || ok "queue discarded"
progress_emit "lesson_completed" "linux-foundations/lesson/pwd"
[ -f "$PROGRESS_OUTBOX" ] && bad "emitted after sharing off" || ok "no events after sharing off"

echo "== content ids match the manifest shape"
progress_sharing on >/dev/null
lid=$(progress_lesson_id pwd); labid=$(progress_lab_id capstone)
course=$(get_active_course)
check "lesson id" "$lid" "$course/lesson/pwd"
check "lab id"    "$labid" "$course/lab/capstone"
# and the ids the CLI builds must exist in the generated manifest
if [ -f "$ROOT/content/manifest.json" ]; then
    grep -q "\"$course/lesson/pwd\"" "$ROOT/content/manifest.json" \
        && ok "lesson id exists in the manifest" || bad "lesson id absent from the manifest"
else
    bad "content/manifest.json missing — cannot verify ids"
fi

echo "== classroom commands are discoverable"
# A learner who never types --help must still find their assignments, so the
# three classroom commands appear in the start menu — and only for a classroom
# license, so a solo buyer never sees options that do not apply to them.
help_out=$(cd "$ROOT" && bash practicum --help 2>/dev/null)
for c in assignments community sharing license activate; do
    printf '%s' "$help_out" | grep -qE "^  $c " && ok "help lists '$c'" || bad "help missing '$c'"
done

write_license "cls_test"
menu_classroom=$(cd "$ROOT" && printf '0\n' | bash practicum start 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
printf '%s' "$menu_classroom" | grep -q 'Your classroom:' && ok "menu shows the classroom section" || bad "classroom section missing"
for entry in 'Assignments' 'Class group' 'Progress sharing'; do
    printf '%s' "$menu_classroom" | grep -q "$entry" && ok "menu offers '$entry'" || bad "menu missing '$entry'"
done

write_license ""
menu_solo=$(cd "$ROOT" && printf '0\n' | bash practicum start 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
printf '%s' "$menu_solo" | grep -q 'Your classroom:' && bad "solo license sees classroom options" || ok "solo license sees no classroom options"

echo ""
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
