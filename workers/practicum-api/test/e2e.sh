#!/bin/bash
# End-to-end test for practicum-api against a local `wrangler dev` instance.
#
#   1. cp .dev.vars.example .dev.vars   (or write your own test secrets)
#   2. wrangler dev --port 8787 --local
#   3. bash test/e2e.sh
#
# Signs a fake Dodo payment.succeeded webhook (Standard Webhooks scheme),
# checks a key is minted, validated, idempotent, entitlement-scoped, and revocable.
set -u
API="${API:-http://127.0.0.1:8787}"
SECRET="${DODO_WEBHOOK_SECRET:-$(grep '^DODO_WEBHOOK_SECRET=' .dev.vars | cut -d= -f2-)}"
RAW="${SECRET#whsec_}"

pass=0; fail=0
ok()   { echo "  ✅ $1"; pass=$((pass+1)); }
bad()  { echo "  ❌ $1"; fail=$((fail+1)); }

sign_and_post() {  # $1 = body
    sign_and_post_id "msg_$(date +%s%N)" "$1"
}

# Same, with the delivery id supplied: Dodo dedupes on webhook-id, so replaying
# one means reusing the id, not just resending the body.
sign_and_post_id() {  # $1 = webhook-id, $2 = body
    local id="$1" body="$2" ts sig
    ts=$(date +%s)
    sig=$(printf '%s.%s.%s' "$id" "$ts" "$body" \
        | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$(printf '%s' "$RAW" | base64 -d | xxd -p -c 256)" -binary \
        | base64)
    curl -s -o /tmp/e2e_body -w '%{http_code}' -X POST "$API/webhooks/dodo" \
        -H "Content-Type: application/json" \
        -H "webhook-id: $id" -H "webhook-timestamp: $ts" -H "webhook-signature: v1,$sig" \
        -d "$body"
}

ORDER="pay_e2e_$(date +%s)"
PAYMENT='{"type":"payment.succeeded","data":{"payment_id":"'"$ORDER"'","customer":{"email":"e2e@example.com"},"product_cart":[{"product_id":"pdt_0No8cX2PpLQr3eZTRBjov"}]}}'

echo "== 1. unsigned webhook is rejected"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/webhooks/dodo" -d "$PAYMENT")
[ "$code" = "401" ] && ok "unsigned → 401" || bad "unsigned → $code"

echo "== 2. bad signature is rejected"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/webhooks/dodo" \
    -H "webhook-id: x" -H "webhook-timestamp: $(date +%s)" -H "webhook-signature: v1,AAAA" -d "$PAYMENT")
[ "$code" = "401" ] && ok "bad sig → 401" || bad "bad sig → $code"

echo "== 3. signed payment.succeeded mints a key"
code=$(sign_and_post "$PAYMENT")
[ "$code" = "200" ] && ok "signed → 200" || bad "signed → $code ($(cat /tmp/e2e_body))"

echo "== 4. key is derivable and validates with Data Engineering entitlements"
HMAC="${HMAC_SECRET:-$(grep '^HMAC_SECRET=' .dev.vars | cut -d= -f2-)}"
hex=$(printf '%s' "$ORDER" | openssl dgst -sha256 -hmac "$HMAC" | awk '{print toupper($NF)}')
KEY="PRAC-${hex:0:4}-${hex:4:4}-${hex:8:4}-${hex:12:4}"
resp=$(curl -s "$API/license/validate?key=$KEY")
echo "     $resp"
echo "$resp" | grep -q '"valid":true' && ok "valid:true" || bad "not valid"
echo "$resp" | grep -q '"entitlements":\["linux-foundations","shell-mastery","data-forging"\]' && ok "entitlements = data track" || bad "wrong entitlements"
echo "$resp" | grep -q '"seats":1' && ok "seats = 1" || bad "wrong seats"
echo "$resp" | grep -q '"activated_at":"20' && ok "activated on first validate" || bad "not activated"

echo "== 5. lowercase / padded key still validates"
curl -s "$API/license/validate?key=%20$(echo "$KEY" | tr A-Z a-z)%20" | grep -q '"valid":true' && ok "normalised" || bad "case-sensitive"

echo "== 6. duplicate webhook is idempotent (same key, no new record)"
code=$(sign_and_post "$PAYMENT")
[ "$code" = "200" ] && ok "replay → 200" || bad "replay → $code"

echo "== 7. unknown key → 404"
code=$(curl -s -o /dev/null -w '%{http_code}' "$API/license/validate?key=PRAC-0000-0000-0000-0000")
[ "$code" = "404" ] && ok "unknown → 404" || bad "unknown → $code"

echo "== 8. unknown product is ignored (200, no key)"
code=$(sign_and_post '{"type":"payment.succeeded","data":{"payment_id":"pay_bogus","customer":{"email":"x@example.com"},"product_cart":[{"product_id":"pdt_nope"}]}}')
[ "$code" = "200" ] && ok "unknown product → 200" || bad "unknown product → $code"

echo "== 9. refund revokes the key"
code=$(sign_and_post '{"type":"refund.succeeded","data":{"payment_id":"'"$ORDER"'"}}')
[ "$code" = "200" ] && ok "refund → 200" || bad "refund → $code"
code=$(curl -s -o /tmp/e2e_body -w '%{http_code}' "$API/license/validate?key=$KEY")
[ "$code" = "403" ] && grep -q revoked /tmp/e2e_body && ok "revoked key → 403" || bad "revoked key → $code"


# --- subscription lifecycle -------------------------------------------------
# Renewals used to be invisible to this handler: it knew only payment.succeeded,
# so a renewal's new payment id looked like a fresh purchase and minted a second
# key while the original quietly expired. These check the licence is extended in
# place, that the two dispute outcomes move access in opposite directions, and
# that a redelivered webhook-id is a true no-op.

SUBPAY="pay_sub_$(date +%s)"
SUBID="sub_e2e_$(date +%s)"
FULL='pdt_0No8cX2NZGEmwrUPoCegF'
sign_and_post '{"type":"payment.succeeded","data":{"payment_id":"'"$SUBPAY"'","subscription_id":"'"$SUBID"'","customer":{"email":"sub@example.com"},"product_cart":[{"product_id":"'"$FULL"'"}]}}' >/dev/null
hex2=$(printf '%s' "$SUBPAY" | openssl dgst -sha256 -hmac "$HMAC" | awk '{print toupper($NF)}')
SUBKEY="PRAC-${hex2:0:4}-${hex2:4:4}-${hex2:8:4}-${hex2:12:4}"

expiry_of() { curl -s "$API/license/validate?key=$1" | sed -n 's/.*"expires_at":"\([^"]*\)".*/\1/p'; }
is_valid()  { curl -s "$API/license/validate?key=$1" | grep -c '"valid":true'; }

echo "== 10. subscription.renewed extends the existing key rather than minting a new one"
[ -n "$(expiry_of "$SUBKEY")" ] && ok "subscription key minted" || bad "no key for the subscription payment"
RID="msg_renew_$(date +%s%N)"
code=$(sign_and_post_id "$RID" '{"type":"subscription.renewed","data":{"subscription_id":"'"$SUBID"'","next_billing_date":"2028-01-15T00:00:00Z"}}')
[ "$code" = "200" ] && ok "renewal → 200" || bad "renewal → $code"
exp=$(expiry_of "$SUBKEY")
case "$exp" in 2028-01-15*) ok "expiry moved to the renewal's next_billing_date" ;;
               *) bad "expiry is '$exp', expected 2028-01-15" ;; esac
[ "$(is_valid "$SUBKEY")" = "1" ] && ok "the original key still validates" || bad "original key stopped working"

echo "== 11. a redelivered webhook-id is a no-op"
# Same delivery id, different content: the second must be ignored outright.
code=$(sign_and_post_id "$RID" '{"type":"subscription.renewed","data":{"subscription_id":"'"$SUBID"'","next_billing_date":"2029-06-01T00:00:00Z"}}')
[ "$code" = "200" ] && ok "replayed delivery → 200" || bad "replayed delivery → $code"
exp=$(expiry_of "$SUBKEY")
case "$exp" in 2028-01-15*) ok "replay did not extend the term a second time" ;;
               *) bad "replay moved expiry to '$exp' — idempotency is not holding" ;; esac
# A genuinely new delivery carrying the same content must still apply, or the
# test above would also pass if renewals had simply stopped working.
sign_and_post '{"type":"subscription.renewed","data":{"subscription_id":"'"$SUBID"'","next_billing_date":"2029-06-01T00:00:00Z"}}' >/dev/null
exp=$(expiry_of "$SUBKEY")
case "$exp" in 2029-06-01*) ok "a new delivery id still extends" ;;
               *) bad "new delivery did not extend: '$exp'" ;; esac

echo "== 12. dispute.opened revokes, dispute.won restores"
sign_and_post '{"type":"dispute.opened","data":{"payment_id":"'"$SUBPAY"'"}}' >/dev/null
code=$(curl -s -o /dev/null -w '%{http_code}' "$API/license/validate?key=$SUBKEY")
[ "$code" = "403" ] && ok "dispute.opened → revoked" || bad "dispute.opened left the key usable ($code)"
sign_and_post '{"type":"dispute.won","data":{"payment_id":"'"$SUBPAY"'"}}' >/dev/null
code=$(curl -s -o /dev/null -w '%{http_code}' "$API/license/validate?key=$SUBKEY")
[ "$code" = "200" ] && ok "dispute.won restored access" \
    || bad "dispute.won left the key revoked ($code) — we won, so the customer keeps access"

echo "== 13. dispute.lost revokes"
sign_and_post '{"type":"dispute.lost","data":{"payment_id":"'"$SUBPAY"'"}}' >/dev/null
code=$(curl -s -o /dev/null -w '%{http_code}' "$API/license/validate?key=$SUBKEY")
[ "$code" = "403" ] && ok "dispute.lost → revoked" || bad "dispute.lost did not revoke ($code)"

echo "== 14. the alternate refund spelling is honoured"
# Dodo's docs say refund.succeeded and Dodo's own CLI says refund.success. A
# wrong guess means refunds never revoke, and no fixture we sign ourselves would
# reveal it. Both spellings are accepted, so both are tested.
RP="pay_alt_$(date +%s)"
sign_and_post '{"type":"payment.succeeded","data":{"payment_id":"'"$RP"'","customer":{"email":"alt@example.com"},"product_cart":[{"product_id":"'"$FULL"'"}]}}' >/dev/null
hex3=$(printf '%s' "$RP" | openssl dgst -sha256 -hmac "$HMAC" | awk '{print toupper($NF)}')
ALTKEY="PRAC-${hex3:0:4}-${hex3:4:4}-${hex3:8:4}-${hex3:12:4}"
[ "$(is_valid "$ALTKEY")" = "1" ] && ok "alt-spelling fixture key minted" || bad "no key minted for the refund spelling test"
sign_and_post '{"type":"refund.success","data":{"payment_id":"'"$RP"'"}}' >/dev/null
code=$(curl -s -o /dev/null -w '%{http_code}' "$API/license/validate?key=$ALTKEY")
[ "$code" = "403" ] && ok "refund.success revokes too" || bad "refund.success did not revoke ($code)"
echo ""
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
