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
# Every license key this run issues is recorded here and revoked on exit, so a
# failed or interrupted run never leaves a usable key behind. Keys issued in a
# test classroom also expire on their own after TEST_LICENSE_TTL_HOURS.
ISSUED_KEYS="$(mktemp)"

cleanup() {
    if [ -s "$ISSUED_KEYS" ]; then
        echo ""
        echo "== revoking keys issued by this run"
        # The suite signs out before exiting, so $JAR is spent by now. Mint a
        # fresh session rather than leaving keys live.
        if ! curl -s -b "$JAR" "$API/v1/classroom" 2>/dev/null | grep -q '"classroom"'; then
            ctok=$(magic_token "$EMAIL" 2>/dev/null)
            [ -n "$ctok" ] && curl -s -o /dev/null -c "$JAR" "$API/v1/auth/verify?token=$ctok" 2>/dev/null
        fi
        while IFS='|' read -r member_id key; do
            [ -n "$member_id" ] || continue
            code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -b "$JAR" \
                "$API/v1/classroom/members/$member_id" 2>/dev/null)
            case "$code" in
                2*) echo "  revoked ${key%%-*}-…" ;;
                *)  echo "  WARNING: could not revoke ${key%%-*}-… (HTTP $code) — it expires on its own within ${TEST_LICENSE_TTL_HOURS:-24}h" ;;
            esac
        done < "$ISSUED_KEYS"
    fi
    rm -f "$JAR" "$JAR_B" "$BODY" "$ISSUED_KEYS"
}
trap cleanup EXIT

# Fixture ids are written by scripts/seed-test-classroom.mjs. An explicit
# environment variable wins over the file, so a run can be pointed elsewhere
# without editing the fixture (and so the guard below can be exercised).
if [ -f "$HERE/smoke_fixture.env" ]; then
    while IFS='=' read -r fk fv; do
        case "$fk" in ''|\#*) continue ;; esac
        eval "[ -n \"\${$fk:-}\" ] || $fk=\"\$fv\""
    done < "$HERE/smoke_fixture.env"
fi
EMAIL="${SMOKE_INSTRUCTOR_EMAIL:-smoke-instructor@practicum-cli.dev}"
EMAIL_B="${SMOKE_INSTRUCTOR_B_EMAIL:-smoke-instructor-b@practicum-cli.dev}"
ROOM="${SMOKE_CLASSROOM_ID:-cls_smoketest0000000000000}"
ROOM_B="${SMOKE_CLASSROOM_B_ID:-cls_smoketest0000000000001}"

# The smoke secret is the only thing that makes a magic token retrievable over
# the wire, so it is never echoed, never passed on a command line, and never
# included in failure output. Local runs use the separate value in .dev.vars.
SECRET_FILE="${SMOKE_TOKEN_SECRET_FILE:-/c/Users/HP/.practicum/smoke_token_secret}"
SOLO_KEY_FILE="${SMOKE_SOLO_KEY_FILE:-/c/Users/HP/.practicum/smoke_solo_key}"
if [ -z "${SMOKE_TOKEN_SECRET:-}" ]; then
    if [ -f "$SECRET_FILE" ]; then
        SMOKE_TOKEN_SECRET=$(tr -d '\r\n' < "$SECRET_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
fi
if [ -z "${SMOKE_TOKEN_SECRET:-}" ]; then
    echo "FATAL: no smoke secret." >&2
    echo "  Set SMOKE_TOKEN_SECRET, or write it to $SECRET_FILE" >&2
    echo "  It must match the SMOKE_TOKEN_SECRET set on the target worker." >&2
    exit 2
fi

pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1"; fail=$((fail+1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

# field <json> <key> → first string value for that key
field() { printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" | head -1; }

# magic_link_body <email> [secret-override] → raw response body
magic_link_body() {
    if [ "$#" -ge 2 ]; then
        curl -s -X POST "$API/v1/auth/magic-link" \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            -H "X-Smoke-Secret: $2" \
            --data-urlencode "email=$1" 2>/dev/null
    else
        curl -s -X POST "$API/v1/auth/magic-link" \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            --data-urlencode "email=$1" 2>/dev/null
    fi
}

# magic_token <email> → test_token, empty unless the smoke secret is accepted
magic_token() {
    magic_link_body "$1" "$SMOKE_TOKEN_SECRET" | sed -n 's/.*"test_token":"\([^"]*\)".*/\1/p' | head -1
}

echo "== content manifest"
code=$(curl -s -o "$BODY" -w '%{http_code}' "$API/v1/content/manifest")
check "manifest returns 200" "$code" "200"
grep -q '"version": *1' "$BODY" && ok "manifest has version" || bad "manifest missing version"
grep -q 'linux-foundations/lesson/pwd' "$BODY" && ok "stable lesson id present" || bad "lesson id missing"
grep -q 'linux-foundations/lab/capstone' "$BODY" && ok "stable lab id present" || bad "lab id missing"
grep -q 'generated_from.*ids.lock.json' "$BODY" && ok "manifest built from the id lock" || bad "manifest not lock-derived"

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

# The token is the whole of the auth factor, so the header that unlocks it is
# tested from every angle. Bodies are compared byte-for-byte against what an
# unknown address receives: anything else is an oracle.
echo "== test_token is gated by X-Smoke-Secret"
BASELINE=$(magic_link_body "nobody-baseline-$(date +%s)@example.com")
printf '%s' "$BASELINE" | grep -q 'test_token' && bad "baseline body leaks a token" || ok "baseline has no token"

no_header=$(magic_link_body "$EMAIL")
printf '%s' "$no_header" | grep -q 'test_token' && bad "no header → token leaked" || ok "no header → no token"
check "no header → body identical to unknown address" "$no_header" "$BASELINE"

wrong=$(magic_link_body "$EMAIL" "not-the-secret-$(date +%s)")
printf '%s' "$wrong" | grep -q 'test_token' && bad "wrong secret → token leaked" || ok "wrong secret → no token"
check "wrong secret → body identical to unknown address" "$wrong" "$BASELINE"

# A valid secret must still not mint a token for a classroom that is not is_test.
NON_TEST_EMAIL="${SMOKE_NON_TEST_EMAIL:-}"
if [ -n "$NON_TEST_EMAIL" ]; then
    real=$(magic_link_body "$NON_TEST_EMAIL" "$SMOKE_TOKEN_SECRET")
    printf '%s' "$real" | grep -q 'test_token' && bad "valid secret leaked a token for a real classroom" \
        || ok "valid secret + non-test classroom → no token"
    check "non-test classroom → body identical to unknown address" "$real" "$BASELINE"
else
    # No real classroom exists yet; assert the rule with an address that has no
    # classroom at all, which is the same branch of the check.
    real=$(magic_link_body "definitely-not-a-classroom-$(date +%s)@example.com" "$SMOKE_TOKEN_SECRET")
    printf '%s' "$real" | grep -q 'test_token' && bad "valid secret leaked a token for a non-test address" \
        || ok "valid secret + non-test address → no token"
    check "non-test address → body identical to unknown address" "$real" "$BASELINE"
fi

echo "== magic link → session → classroom summary"
TOKEN=$(magic_token "$EMAIL")
if [ -z "$TOKEN" ]; then
    bad "no test token returned — is the test classroom seeded?"
else
    ok "test token issued"

    # Follow the link the email actually carries, not one assembled here: a
    # link pointing at the static-asset host 404s for the instructor while a
    # self-built URL still passes. That is exactly how it reached production.
    LINK=$(printf '%s' "$(magic_link_body "$EMAIL" "$SMOKE_TOKEN_SECRET")" \
        | sed -n 's/.*"test_verify_url":"\([^"]*\)".*/\1/p' | head -1)
    if [ -z "$LINK" ]; then
        bad "no test_verify_url returned — cannot verify the emailed link"
    else
        case "$LINK" in
            "$API"/v1/auth/verify*) ok "emailed link targets the API host" ;;
            *) bad "emailed link targets the wrong host: ${LINK%%/v1/*}" ;;
        esac
        hdrs=$(curl -s -D - -o /dev/null -c "$JAR" "$LINK")
        printf '%s' "$hdrs" | grep -qi '^HTTP/[0-9.]* 302' && ok "emailed link redirects" || bad "emailed link did not redirect"
        # Relative Location would land on the API host, which serves no dashboard.
        loc=$(printf '%s' "$hdrs" | grep -i '^location:' | sed 's/^[Ll]ocation: //' | tr -d '\r')
        case "$loc" in
            https://*/dashboard/|http://*/dashboard/) ok "redirect is absolute to the dashboard: $loc" ;;
            *) bad "redirect Location is not an absolute dashboard URL: '$loc'" ;;
        esac
        # That landing page must actually exist.
        code=$(curl -s -o /dev/null -w '%{http_code}' "$loc")
        check "redirect target serves the dashboard" "$code" "200"
    fi

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
        # Hard refusal, not a soft failure: if a smoke classroom is not is_test
        # the fixture is pointing at something real and the run must stop.
        if ! printf '%s' "$b_body" | grep -q '"is_test":true'; then
            echo "  ABORT: classroom B ($b_id) is not flagged is_test." >&2
            exit 3
        fi
        ok "classroom B is is_test = 1"
        a_id=$(field "$(curl -s -b "$JAR" "$API/v1/classroom")" id)
        check "session A still sees only A" "$a_id" "$ROOM"
        [ "$a_id" != "$b_id" ] && ok "sessions are isolated" || bad "sessions cross classrooms"
    else
        bad "classroom B not seeded — scoping untested"
    fi

        # Production state persists between runs, so the suite starts by clearing
    # any seats a previous run left in classroom A. Instructors are left alone —
    # revoking them would lock the suite out of its own classroom.
    # Belt and braces before anything is revoked. The API already scopes every
    # member lookup to the session's own classroom — revokeMember's WHERE is
    # "id = ? AND classroom_id = ?" with the id taken from the session, never
    # the client, and it soft-revokes rather than deleting. This block refuses
    # to proceed unless the classroom on this session is one of the two smoke
    # classrooms AND is flagged is_test, so a misconfigured fixture can never
    # point the suite at real seats.
    echo "== reset guard"
    guard=$(curl -s -b "$JAR" "$API/v1/classroom")
    guard_id=$(field "$guard" id)
    guard_qa="cls_manualqa000000000000000"

    if [ "$guard_id" = "$guard_qa" ]; then
        echo "  ABORT: session is the manual QA classroom — it must never be reset." >&2
        exit 3
    fi
    if [ "$guard_id" != "$ROOM" ] && [ "$guard_id" != "$ROOM_B" ]; then
        echo "  ABORT: session classroom '$guard_id' is not a smoke classroom." >&2
        exit 3
    fi
    if ! printf '%s' "$guard" | grep -q '"is_test":true'; then
        echo "  ABORT: classroom '$guard_id' is not flagged is_test — refusing to touch its seats." >&2
        exit 3
    fi
    ok "reset guard: session is smoke classroom $guard_id, is_test"

    echo "== reset classroom A learner seats"
    stale=0
    for mid in $(curl -s -b "$JAR" "$API/v1/classroom/members" \
        | tr '}' '\n' | grep '"role":"learner"' | grep -v '"status":"revoked"' \
        | sed -n 's/.*"id":"\([^"]*\)".*/\1/p'); do
        curl -s -o /dev/null -X DELETE -b "$JAR" "$API/v1/classroom/members/$mid"
        stale=$((stale + 1))
    done
    echo "  cleared $stale learner seat(s) from a previous run"

    echo "== seats: invite, caps, revoke, rotation (7B)"
    RUN="smoke$(date +%s)"
    # Every key issued below is recorded for the EXIT trap immediately after the
    # call that creates it, so an interrupt mid-suite still cleans up.
    invite() {  # $1 = email, $2 = role → response body
        curl -s -X POST -b "$JAR" "$API/v1/classroom/members" \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            --data-urlencode "email=$1" --data-urlencode "role=${2:-learner}" \
            --data-urlencode "display_name=Smoke $RUN" 2>/dev/null
    }
    jfield() { printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" | head -1; }

    # KV is eventually consistent: a revoked or rotated key can still validate
    # from an edge cache for a short window. Locally the write is immediate, so
    # this only matters against production. The CLI caches licenses for 24h
    # anyway, which dwarfs this window — but the suite must not race it.
    validate_becomes() {  # $1 = key, $2 = expected HTTP code → 0 when reached
        local key="$1" want="$2" i code
        for i in 1 2 3 4 5 6 7 8; do
            code=$(curl -s -o "$BODY" -w '%{http_code}' "$API/license/validate?key=$key")
            [ "$code" = "$want" ] && return 0
            sleep 3
        done
        printf '%s' "$code"
        return 1
    }

    body=$(invite "learner-$RUN@example.com")
    MEM=$(jfield "$body" member_id); KEY=$(jfield "$body" test_key)
    [ -n "$MEM" ] && echo "$MEM|$KEY" >> "$ISSUED_KEYS"
    [ -n "$MEM" ] && ok "invite created a member" || bad "invite failed: $(printf '%s' "$body" | cut -c1-90)"
    [ -n "$KEY" ] && ok "invite issued a license key" || bad "no key issued"

    if [ -n "$KEY" ]; then
        vbody=$(curl -s "$API/license/validate?key=$KEY")
        printf '%s' "$vbody" | grep -q '"valid":true' && ok "learner key validates" || bad "learner key does not validate"
        printf '%s' "$vbody" | grep -q '"role":"learner"' && ok "key role is learner" || bad "wrong key role"
        printf '%s' "$vbody" | grep -q '"kubernetes"' && ok "key carries full catalog" || bad "key missing entitlements"
        printf '%s' "$vbody" | grep -q "\"classroom_id\"\|$ROOM" && ok "key is bound to the classroom" || bad "key not classroom-bound"
    fi

    # Every URL a learner is handed must resolve, including ones buried in shell
    # commands. The invite email shipped a 404 install URL for weeks because
    # nothing checked the links inside the commands it printed.
    echo "== every URL in the invite email resolves"
    # test_email_text is the last field in the object, so take everything after
    # the marker and drop the closing quote/brace, then unescape.
    EMAIL_TEXT=$(printf '%s' "$body" \
        | sed 's/.*"test_email_text":"//; s/"}[[:space:]]*$//' \
        | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g')
    if [ -z "$EMAIL_TEXT" ]; then
        bad "no test_email_text returned — email content unverified"
    else
        printf '%s' "$EMAIL_TEXT" | grep -q 'install\.sh' && bad "email references a non-existent installer" \
            || ok "email references no hosted installer"
        urls=$(printf '%s' "$EMAIL_TEXT" | grep -oE 'https?://[A-Za-z0-9._~:/?#@!$&*+,;=%-]+' \
            | sed 's/[.,)]*$//' | sort -u)
        [ -n "$urls" ] && ok "email contains $(printf '%s\n' "$urls" | wc -l | tr -d ' ') URL(s)" || bad "email contains no URLs"
        for u in $urls; do
            ucode=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 25 "$u")
            check "email URL 200: $(printf '%s' "$u" | cut -c1-58)" "$ucode" "200"
        done
    fi

    # 7C-0: activating a classroom key must promote the roster row, so an
    # instructor can see who has actually started. Before this, every learner
    # showed as invited with no last seen, forever.
    echo "== activation updates the roster (7C-0)"
    # member_row <member_id> → that member's JSON object from the roster
    member_row() {
        curl -s -b "$JAR" "$API/v1/classroom/members" | tr '}' '\n' | grep "\"id\":\"$1\""
    }
    # A dedicated member whose key nothing else has touched: the checks above
    # already validate $KEY, which would itself have promoted the row.
    lc_body=$(invite "lifecycle-$RUN@example.com")
    LC_MEM=$(jfield "$lc_body" member_id); LC_KEY=$(jfield "$lc_body" test_key)
    [ -n "$LC_MEM" ] && echo "$LC_MEM|$LC_KEY" >> "$ISSUED_KEYS"

    if [ -n "$LC_MEM" ] && [ -n "$LC_KEY" ]; then
        row=$(member_row "$LC_MEM")
        printf '%s' "$row" | grep -q '"status":"invited"' && ok "before activation: invited" || bad "not invited before activation"
        printf '%s' "$row" | grep -q '"last_seen_at":null' && ok "before activation: no last seen" || bad "last seen set before activation"

        curl -s -o /dev/null "$API/license/validate?key=$LC_KEY"
        sleep 2
        row=$(member_row "$LC_MEM")
        printf '%s' "$row" | grep -q '"status":"active"' && ok "after activation: active" || bad "status did not flip to active"
        printf '%s' "$row" | grep -q '"activated_at":null' && bad "activated_at not stamped" || ok "activated_at stamped"
        printf '%s' "$row" | grep -q '"last_seen_at":null' && bad "last_seen_at not stamped" || ok "last_seen_at stamped"

        # A cold CLI cache calls validate on every gate; that must not write each time.
        seen_before=$(printf '%s' "$row" | sed -n 's/.*"last_seen_at":"\([^"]*\)".*/\1/p')
        curl -s -o /dev/null "$API/license/validate?key=$LC_KEY"
        sleep 2
        seen_after=$(printf '%s' "$(member_row "$LC_MEM")" | sed -n 's/.*"last_seen_at":"\([^"]*\)".*/\1/p')
        check "second validate within the hour does not move last_seen_at" "$seen_after" "$seen_before"
    else
        bad "no lifecycle member/key — activation write untested"
    fi

    echo "== normalisation and duplicates"
    dup=$(invite "  LEARNER-$RUN@Example.COM  ")
    printf '%s' "$dup" | grep -q 'already on this roster' && ok "email normalised; duplicate rejected" || bad "duplicate not caught: $(printf '%s' "$dup" | cut -c1-70)"

    echo "== instructor cap (2)"
    b2=$(invite "instructor2-$RUN@example.com" instructor)
    M2=$(jfield "$b2" member_id); K2=$(jfield "$b2" test_key)
    [ -n "$M2" ] && echo "$M2|$K2" >> "$ISSUED_KEYS"
    [ -n "$M2" ] && ok "2nd instructor seat granted" || bad "2nd instructor rejected: $(printf '%s' "$b2" | cut -c1-70)"
    [ -n "$K2" ] && curl -s "$API/license/validate?key=$K2" | grep -q '"role":"instructor-admin"' \
        && ok "2nd instructor key is instructor-admin" || bad "2nd instructor key role wrong"
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -b "$JAR" "$API/v1/classroom/members" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "email=instructor3-$RUN@example.com" --data-urlencode "role=instructor")
    check "3rd instructor → 409" "$code" "409"

    echo "== learner cap (30) via CSV import"
    csv="email,display_name"$'\n'
    i=1
    while [ "$i" -le 31 ]; do csv="${csv}bulk${i}-$RUN@example.com,Bulk $i"$'\n'; i=$((i+1)); done
    imp=$(curl -s -X POST -b "$JAR" "$API/v1/classroom/members/import" -H 'Content-Type: text/csv' --data-binary "$csv")
    for m in $(printf '%s' "$imp" | grep -o '"member_id":"[^"]*"' | cut -d'"' -f4); do echo "$m|" >> "$ISSUED_KEYS"; done
    imported=$(printf '%s' "$imp" | grep -o '"member_id":"[^"]*"' | wc -l)
    [ "$imported" -gt 0 ] && ok "import registered $imported seat(s) for cleanup" || bad "import returned no member ids"
    # Locally the invite email always fails (dummy Resend key), so a created row
    # reports created_email_failed — the seat is kept either way, which is the
    # behaviour under test.
    printf '%s' "$imp" | grep -qE '"created(_email_failed)?"' && ok "import created rows" || bad "import created nothing"
    printf '%s' "$imp" | grep -q 'over_capacity' && ok "31st learner → over_capacity" || bad "learner cap not enforced"
    printf '%s' "$imp" | grep -q '"header"' && bad "header row was imported" || ok "header row skipped"
    # The roster fills the cap, so a further single invite must be refused too.
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -b "$JAR" "$API/v1/classroom/members" \
        -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode "email=over-$RUN@example.com")
    check "invite past the learner cap → 409" "$code" "409"

    echo "== bad rows never block good ones"
    mixed=$(curl -s -X POST -b "$JAR" "$API/v1/classroom/members/import" -H 'Content-Type: text/csv' \
        --data-binary "not-an-email,Bad"$'\n'"also bad,Worse")
    printf '%s' "$mixed" | grep -q '"invalid"' && ok "invalid rows reported per row" || bad "invalid rows not reported"

    echo "== rotation invalidates the old key"
    if [ -n "$MEM" ] && [ -n "$KEY" ]; then
        rot=$(curl -s -X POST -b "$JAR" "$API/v1/classroom/members/$MEM/resend")
        NEWKEY=$(jfield "$rot" test_key)
        [ -n "$NEWKEY" ] && echo "$MEM|$NEWKEY" >> "$ISSUED_KEYS"
        [ -n "$NEWKEY" ] && [ "$NEWKEY" != "$KEY" ] && ok "resend rotated the key" || bad "key did not rotate"
        curl -s "$API/license/validate?key=$NEWKEY" | grep -q '"valid":true' && ok "new key validates" || bad "new key invalid"
        validate_becomes "$KEY" 403 >/dev/null && ok "old key stops validating" || bad "old key still validates"
        KEY="$NEWKEY"
    fi

    # A classroom with no instructor cannot be administered at all, and removing
    # your own seat signs you out mid-action. Both are refused server-side.
    echo "== revoke guards"
    ME_ID=$(field "$(curl -s -b "$JAR" "$API/v1/classroom")" member_id)
    if [ -z "$ME_ID" ]; then
        bad "summary did not return the signed-in member_id"
    else
        # With the 2nd instructor still present, self-revoke is refused on its own terms.
        self=$(curl -s -o "$BODY" -w '%{http_code}' -X DELETE -b "$JAR" "$API/v1/classroom/members/$ME_ID")
        check "revoking your own seat → 409" "$self" "409"
        grep -q 'self_revoke' "$BODY" && ok "self-revoke reports code self_revoke" || bad "wrong self-revoke code"

        # Remove the 2nd instructor, leaving exactly one; the rule now changes.
        if [ -n "${M2:-}" ]; then
            code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -b "$JAR" "$API/v1/classroom/members/$M2")
            check "2nd instructor can be revoked" "$code" "200"
            last=$(curl -s -o "$BODY" -w '%{http_code}' -X DELETE -b "$JAR" "$API/v1/classroom/members/$ME_ID")
            check "revoking the last instructor → 409" "$last" "409"
            grep -q 'last_instructor' "$BODY" && ok "last instructor reports code last_instructor" || bad "wrong last-instructor code"
            # And the classroom still has a working instructor afterwards.
            curl -s -b "$JAR" "$API/v1/classroom" | grep -q '"instructors":{"used":1' \
                && ok "classroom still has its instructor" || bad "instructor seat lost"
        else
            bad "no 2nd instructor available — last-instructor rule untested"
        fi
    fi

    echo "== revoke"
    if [ -n "$MEM" ]; then
        code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -b "$JAR" "$API/v1/classroom/members/$MEM")
        check "revoke accepted" "$code" "200"
        validate_becomes "$KEY" 403 >/dev/null && ok "revoked key → 403" || bad "revoked key still validates"
        grep -q 'License revoked' "$BODY" && ok "revoked key reports 'License revoked'" || bad "wrong revoke error"
        # lib/license.sh turns exactly that string into the learner-facing line.
        grep -q 'Your classroom seat was removed' "$HERE/../lib/license.sh" \
            && ok "CLI has the revoked-seat message" || bad "CLI missing revoked-seat message"
        curl -s -b "$JAR" "$API/v1/classroom/members" | grep -q '"status":"revoked"' \
            && ok "roster shows revoked status" || bad "roster missing revoked status"

        # A validate attempt on a revoked key must not resurrect the roster row:
        # the UPDATE excludes revoked members outright.
        curl -s -o /dev/null "$API/license/validate?key=$KEY"
        sleep 2
        printf '%s' "$(member_row "$MEM")" | grep -q '"status":"revoked"' \
            && ok "revoked member stays revoked after a validate attempt" || bad "revoked member was resurrected"
        code=$(curl -s -o /dev/null -w '%{http_code}' "$API/license/validate?key=$KEY")
        check "revoked key still 403 after the attempt" "$code" "403"
    fi

    # A synthetic solo license (scripts/mint-smoke-solo.ts), never a customer key.
    echo "== solo licenses are unaffected"
    if [ -z "${SMOKE_SOLO_KEY:-}" ] && [ -f "$SOLO_KEY_FILE" ]; then
        SMOKE_SOLO_KEY=$(tr -d '\r\n' < "$SOLO_KEY_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    if [ -n "${SMOKE_SOLO_KEY:-}" ]; then
        solo=$(curl -s "$API/license/validate?key=$SMOKE_SOLO_KEY")
        printf '%s' "$solo" | grep -q '"valid":true' && ok "solo license still validates" || bad "solo license broke"
        printf '%s' "$solo" | grep -q '"entitlements":\["linux-foundations"\]' \
            && ok "solo license keeps its single-course entitlement" || bad "solo entitlements changed"
        printf '%s' "$solo" | grep -q 'classroom_id' && bad "solo license carries classroom fields" \
            || ok "solo license has no classroom fields"
    else
        bad "no solo key — run: node scripts/mint-smoke-solo.ts (writes $SOLO_KEY_FILE)"
    fi

    # Classroom C exists for manual QA and delivers real mail. Nothing here may
    # reach it: this session is scoped to classroom A, and that is asserted.
    echo "== manual QA classroom is untouched"
    qa_id="cls_manualqa000000000000000"
    [ "$(field "$(curl -s -b "$JAR" "$API/v1/classroom")" id)" != "$qa_id" ] \
        && ok "session is not classroom C" || bad "session leaked into the QA classroom"
    code=$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" -X DELETE "$API/v1/classroom/members/mem_manualqa_instructor000")
    check "cannot revoke a classroom C member from a classroom A session" "$code" "404"

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
# The homepage told every visitor to curl an installer that never existed.
# Check the live page's own install instructions, not a copy in the repo.
echo "== homepage install instructions resolve"
if curl -s -o "$BODY" --connect-timeout 10 "$SITE/"; then
    grep -q 'install\.sh' "$BODY" && bad "homepage still references a non-existent installer" \
        || ok "homepage references no hosted installer"
    # Every URL inside a copy-to-clipboard command or code block must resolve.
    site_urls=$(grep -oE 'https?://[A-Za-z0-9._~:/?#@!$&*+,;=%-]+' "$BODY" \
        | sed 's/[.,)<"'"'"']*$//' \
        | grep -vE 'fonts\.(googleapis|gstatic)\.com|checkout\.dodopayments\.com|^https?://practicum-cli\.dev/?$' \
        | sort -u)
    for u in $site_urls; do
        ucode=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 25 "$u")
        check "homepage URL 200: $(printf '%s' "$u" | cut -c1-54)" "$ucode" "200"
    done
    # The documented method must actually be the one that works.
    grep -q 'git clone https://github.com/emkwambe/practicum-cli.git' "$BODY" \
        && ok "homepage documents the clone install" || bad "homepage lost its install instructions"
else
    echo "  SKIP  homepage install check — $SITE not reachable"
fi

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
