#!/bin/bash
# Sprint 7A smoke — manifest, magic-link auth, sessions, session scoping.
#
#   API=http://127.0.0.1:8787 bash tests/smoke_classroom.sh   # local wrangler dev
#   bash tests/smoke_classroom.sh                             # production
#
# Requires the test classroom: npm run seed:test-classroom [-- --remote]
# grep/sed/cut only — no jq anywhere.
set -u

API="${API:-https://api.practicum-cli.dev}"
SITE="${SITE:-https://practicum-cli.dev}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAR="$(mktemp)"; JAR_B="$(mktemp)"; BODY="$(mktemp)"
trap 'rm -f "$JAR" "$JAR_B" "$BODY"' EXIT

# Fixture ids are written by scripts/seed-test-classroom.mjs.
if [ -f "$HERE/smoke_fixture.env" ]; then
    # shellcheck disable=SC1090
    . "$HERE/smoke_fixture.env"
fi
EMAIL="${SMOKE_INSTRUCTOR_EMAIL:-smoke-instructor@practicum-cli.dev}"
EMAIL_B="${SMOKE_INSTRUCTOR_B_EMAIL:-smoke-instructor-b@practicum-cli.dev}"
ROOM="${SMOKE_CLASSROOM_ID:-cls_smoketest0000000000000}"
ROOM_B="${SMOKE_CLASSROOM_B_ID:-cls_smoketest0000000000001}"

pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1"; fail=$((fail+1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

# field <json> <key> → first string value for that key
field() { printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" | head -1; }

magic_token() {  # $1 = email → test_token, empty when the address has no access
    curl -s -X POST "$API/v1/auth/magic-link" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "email=$1" 2>/dev/null | sed -n 's/.*"test_token":"\([^"]*\)".*/\1/p' | head -1
}

echo "== content manifest"
code=$(curl -s -o "$BODY" -w '%{http_code}' "$API/v1/content/manifest")
check "manifest returns 200" "$code" "200"
grep -q '"version": *1' "$BODY" && ok "manifest has version" || bad "manifest missing version"
grep -q 'linux-foundations/day1/lesson/pwd' "$BODY" && ok "stable lesson id present" || bad "lesson id missing"
grep -q 'linux-foundations/day5/lab/capstone' "$BODY" && ok "stable lab id present" || bad "lab id missing"

echo "== magic link: no account enumeration"
for addr in "nobody-$(date +%s)@example.com" "$EMAIL"; do
    code=$(curl -s -o "$BODY" -w '%{http_code}' -X POST "$API/v1/auth/magic-link" \
        -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode "email=$addr")
    check "magic-link 200 for $(printf '%s' "$addr" | cut -c1-14)…" "$code" "200"
done
grep -q 'sign-in link is on its way' "$BODY" && ok "identical body for both" || bad "body differs by account"

echo "== learner address cannot request a dashboard link"
tok=$(magic_token "learner-not-instructor@example.com")
[ -z "$tok" ] && ok "non-instructor gets no token" || bad "non-instructor received a token"

echo "== magic link → session → classroom summary"
TOKEN=$(magic_token "$EMAIL")
if [ -z "$TOKEN" ]; then
    bad "no test token returned — is the test classroom seeded?"
else
    ok "test token issued"
    code=$(curl -s -o /dev/null -w '%{http_code}' -c "$JAR" "$API/v1/auth/verify?token=$TOKEN")
    check "verify redirects" "$code" "302"
    grep -q practicum_session "$JAR" && ok "session cookie set" || bad "no session cookie"

    code=$(curl -s -o "$BODY" -w '%{http_code}' -b "$JAR" "$API/v1/classroom")
    check "classroom summary 200" "$code" "200"
    check "summary is the session's classroom" "$(field "$(cat "$BODY")" id)" "$ROOM"
    # is_test must be true or this suite would email real instructors.
    grep -q '"is_test":true' "$BODY" && ok "classroom A is is_test = 1" || bad "classroom A is NOT a test classroom"
    grep -q '"learners"' "$BODY" && ok "seat counts present" || bad "seat counts missing"
    grep -q "\"email\":\"$EMAIL\"" "$BODY" && ok "signed-in identity present" || bad "identity missing"

    echo "== token is single use"
    code=$(curl -s -o /dev/null -w '%{http_code}' "$API/v1/auth/verify?token=$TOKEN")
    check "replayed token rejected" "$code" "400"

    echo "== session scoping: A cannot read B"
    TOKEN_B=$(magic_token "$EMAIL_B")
    if [ -n "$TOKEN_B" ]; then
        curl -s -o /dev/null -c "$JAR_B" "$API/v1/auth/verify?token=$TOKEN_B"
        b_body=$(curl -s -b "$JAR_B" "$API/v1/classroom")
        b_id=$(field "$b_body" id)
        check "session B sees classroom B" "$b_id" "$ROOM_B"
        printf '%s' "$b_body" | grep -q '"is_test":true' && ok "classroom B is is_test = 1" || bad "classroom B is NOT a test classroom"
        a_id=$(field "$(curl -s -b "$JAR" "$API/v1/classroom")" id)
        check "session A still sees only A" "$a_id" "$ROOM"
        [ "$a_id" != "$b_id" ] && ok "sessions are isolated" || bad "sessions cross classrooms"
    else
        bad "classroom B not seeded — scoping untested"
    fi

    echo "== logout"
    curl -s -o /dev/null -X POST -b "$JAR" -c "$JAR" "$API/v1/auth/logout"
    code=$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" "$API/v1/classroom")
    check "after logout, summary is 401" "$code" "401"
fi

echo "== unauthenticated and malformed"
code=$(curl -s -o /dev/null -w '%{http_code}' "$API/v1/classroom")
check "no cookie → 401" "$code" "401"
code=$(curl -s -o /dev/null -w '%{http_code}' "$API/v1/auth/verify?token=not-a-real-token")
check "bogus token → 400" "$code" "400"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/v1/auth/magic-link" \
    -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'email=not-an-email')
check "invalid email → 200 (no enumeration)" "$code" "200"

# Always assert the production dashboard origin, whatever SITE points at —
# that is the origin the browser will actually send.
echo "== CORS for the dashboard origin"
PROD_ORIGIN="https://practicum-cli.dev"
hdr=$(curl -s -D - -o /dev/null -X OPTIONS "$API/v1/classroom" -H "Origin: $PROD_ORIGIN" \
    -H 'Access-Control-Request-Method: GET')
printf '%s' "$hdr" | grep -qi "access-control-allow-origin: $PROD_ORIGIN" && ok "origin echoed" || bad "origin not echoed"
printf '%s' "$hdr" | grep -qi 'access-control-allow-credentials: true' && ok "credentials allowed" || bad "credentials not allowed"
printf '%s' "$hdr" | grep -qi '^vary:.*origin' && ok "Vary: Origin set" || bad "Vary: Origin missing"

echo "== dashboard shell is served"
if curl -s -o /dev/null --connect-timeout 5 "$SITE/" 2>/dev/null; then
    code=$(curl -s -o "$BODY" -w '%{http_code}' "$SITE/dashboard/")
    check "dashboard 200" "$code" "200"
    grep -q 'Classroom dashboard' "$BODY" && ok "login view present" || bad "login view missing"
else
    echo "  SKIP  dashboard shell — $SITE not reachable (set SITE to a running site)"
fi

# The site worker serves ./lib, which also holds the CLI's shell libraries.
# .assetsignore must keep every one of them off the public origin.
echo "== CLI shell libraries are not published"
if printf '%s' "$SITE" | grep -q 'practicum-cli.dev'; then
    for leaked in license.sh state.sh lessons.sh .assetsignore; do
        code=$(curl -s -o /dev/null -w '%{http_code}' "$SITE/$leaked")
        check "$leaked not served" "$code" "404"
    done
else
    echo "  SKIP  asset leak check — only meaningful against the deployed site"
fi

# Production-only: the browser will reject a session cookie without these.
echo "== session cookie attributes (production)"
if printf '%s' "$API" | grep -q 'api.practicum-cli.dev'; then
    PROD_TOKEN=$(magic_token "$EMAIL")
    if [ -n "$PROD_TOKEN" ]; then
        setc=$(curl -s -D - -o /dev/null "$API/v1/auth/verify?token=$PROD_TOKEN" | grep -i '^set-cookie:')
        for attr in 'Secure' 'HttpOnly' 'SameSite=Lax' 'Domain=.practicum-cli.dev'; do
            printf '%s' "$setc" | grep -qi -- "$attr" && ok "cookie has $attr" || bad "cookie missing $attr"
        done
    else
        bad "no prod test token — cookie attributes untested"
    fi
else
    echo "  SKIP  cookie attributes — production only (API is $API)"
fi

echo ""
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
