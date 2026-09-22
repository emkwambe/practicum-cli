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
    local body="$1" id ts sig
    id="msg_$(date +%s%N)"
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

echo ""
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
