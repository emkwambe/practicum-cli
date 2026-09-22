#!/bin/bash
# Practicum CLI — License Management
#
# Keys are minted server-side by the practicum-api Worker when Dodo Payments
# reports a successful payment, and validated against it here. The local cache
# in ~/.practicum/license.json is only ever written from a server response.
#
# Pure bash + coreutils + curl. No jq.

PRACTICUM_API="${PRACTICUM_API:-https://api.practicum-cli.dev}"
LICENSE_FILE="$HOME/.practicum/license.json"
LICENSE_EXPIRED_FILE="$HOME/.practicum/license.expired"   # date of last expiry, for messaging
LICENSE_DENY_REASON="unlicensed"   # set by validate_license / can_access_course
LICENSE_CACHE_TTL=86400        # 24h — trust cache without a server call
LICENSE_OFFLINE_GRACE=604800   # 7d  — keep working offline if server unreachable
FREE_COURSES="00-cli-immersion"

init_license() {
    mkdir -p "$HOME/.practicum"
}

check_curl() {
    if ! command -v curl &>/dev/null; then
        echo -e "  ${C_RED}Error: curl is required for license activation.${C_RESET}"
        echo -e "  ${C_DIM}Install with: sudo apt install curl${C_RESET}"
        return 1
    fi
}

# --- tiny JSON helpers (flat objects only) ----------------------------------

# _json_str '<json>' field  → string value of "field"
_json_str() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" | head -1
}

# _json_num '<json>' field  → numeric/bool value of "field"
_json_num() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\([0-9a-z.]*\).*/\1/p" | head -1
}

# _json_arr '<json>' field  → array of strings as space-separated words
_json_arr() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\[\([^]]*\)\].*/\1/p" | head -1 | tr -d '"' | tr ',' ' '
}

# _license_field field → value from the local cache file
_license_field() {
    [ -f "$LICENSE_FILE" ] || return 1
    sed -n "s/^ *\"$1\": *\"\{0,1\}\([^\",]*\)\"\{0,1\},\{0,1\}$/\1/p" "$LICENSE_FILE" | head -1
}

# --- server ------------------------------------------------------------------

# _license_fetch <key> → prints server JSON; exit 0 = reachable, 1 = network error
_license_fetch() {
    curl -s --connect-timeout 5 --max-time 15 \
        "$PRACTICUM_API/license/validate?key=$1" 2>/dev/null
}

# _license_write <server-json>  — cache a validated response
_license_write() {
    local body="$1"
    local role
    role=$(_json_str "$body" role)
    role="${role:-learner}"   # default for records that predate the field
    cat > "$LICENSE_FILE" << LJSON
{
    "key": "$(_json_str "$body" key)",
    "email": "$(_json_str "$body" email)",
    "product_id": "$(_json_str "$body" product_id)",
    "entitlements": "$(_json_arr "$body" entitlements)",
    "seats": "$(_json_num "$body" seats)",
    "role": "${role}",
    "activated_at": "$(_json_str "$body" activated_at)",
    "expires_at": "$(_json_str "$body" expires_at)",
    "expires_epoch": "$(_json_num "$body" expires_epoch)",
    "cached_epoch": "$(date +%s)",
    "valid": "true"
}
LJSON
    chmod 600 "$LICENSE_FILE"
    _cache_seal
}

# --- cache integrity -----------------------------------------------------
#
# The cache is signed with HMAC-SHA256 keyed on the license key itself, so a
# hand-written file (forged entitlements, re-dated cached_epoch) fails
# verification and is discarded. This raises the cost of a local bypass; it
# is not a hard DRM boundary — someone with the file also has the key.
# Where openssl is missing the check degrades to the epoch window alone.

_has_openssl() { command -v openssl >/dev/null 2>&1; }

# _cache_sign <license-key> <content> → hex HMAC
_cache_sign() {
    printf '%s' "$2" | openssl dgst -sha256 -hmac "$1" 2>/dev/null | awk '{print $NF}'
}

# _cache_seal — add a cache_sig field computed over the rest of the file
_cache_seal() {
    _has_openssl || return 0
    local key content sig
    key=$(_license_field key)
    [ -n "$key" ] || return 0
    content=$(grep -v '"cache_sig"' "$LICENSE_FILE")
    sig=$(_cache_sign "$key" "$content")
    [ -n "$sig" ] || return 0
    # Insert before the closing brace, keeping the JSON valid.
    printf '%s\n' "$content" | sed '$d' > "${LICENSE_FILE}.tmp"
    printf '    ,"cache_sig": "%s"\n}\n' "$sig" >> "${LICENSE_FILE}.tmp"
    mv "${LICENSE_FILE}.tmp" "$LICENSE_FILE"
    chmod 600 "$LICENSE_FILE"
}

# _cache_intact — 0 if the cache is unmodified since it was written,
# or if signing is unavailable (graceful degradation).
_cache_intact() {
    if ! _has_openssl; then
        [ -n "${LICENSE_SIG_WARNED:-}" ] || {
            LICENSE_SIG_WARNED=1
            echo -e "  ${C_DIM}Note: openssl not found — license cache signature unavailable, epoch check only.${C_RESET}" >&2
        }
        return 0
    fi
    local key content expected stored
    key=$(_license_field key)
    [ -n "$key" ] || return 1
    stored=$(sed -n 's/.*"cache_sig": *"\([^"]*\)".*/\1/p' "$LICENSE_FILE" | head -1)
    [ -n "$stored" ] || return 1
    # Content as it was at seal time: everything but the sig line, closing brace restored.
    content=$(grep -v '"cache_sig"' "$LICENSE_FILE" | sed '$d')$'\n''}'
    expected=$(_cache_sign "$key" "$content")
    [ -n "$expected" ] && [ "$stored" = "$expected" ]
}

# --- commands ----------------------------------------------------------------

activate_license() {
    # PRACTICUM_KEY keeps the key out of shell history and the process list,
    # which matters on the shared and lab machines classrooms often run on.
    local raw="${1:-${PRACTICUM_KEY:-}}"
    local key
    key=$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')

    if [ -z "$key" ]; then
        echo -e "  ${C_RED}Usage: practicum activate <license_key>${C_RESET}"
        echo -e "  ${C_DIM}   or: PRACTICUM_KEY=<license_key> practicum activate${C_RESET}"
        echo ""
        echo -e "  ${C_DIM}Get your key at: https://practicum-cli.dev/#pricing${C_RESET}"
        return 1
    fi

    check_curl || return 1

    echo -e "  ${C_CYAN}Validating license...${C_RESET}"
    local body
    if ! body=$(_license_fetch "$key") || [ -z "$body" ]; then
        echo -e "  ${C_RED}❌ Could not reach the license server. Check your connection.${C_RESET}"
        return 1
    fi

    if [ "$(_json_num "$body" valid)" != "true" ]; then
        echo ""
        echo -e "  ${C_RED}❌ Activation failed.${C_RESET}"
        if [ "$(_json_str "$body" error)" = "License revoked" ]; then
            echo -e "  ${C_YELLOW}  Your classroom seat was removed. Contact your instructor.${C_RESET}"
        else
            echo -e "  ${C_YELLOW}  $(_json_str "$body" error)${C_RESET}"
            echo -e "  ${C_DIM}  Check the key in your purchase email, or contact practicum@mpingo.ai${C_RESET}"
        fi
        echo ""
        return 1
    fi

    _license_write "$body"
    rm -f "$LICENSE_EXPIRED_FILE"

    echo ""
    echo -e "  ${C_GREEN}✅ License activated for $(_json_str "$body" email)${C_RESET}"
    echo -e "  ${C_WHITE}  Courses unlocked:${C_RESET}"
    local c
    for c in $(_json_arr "$body" entitlements); do
        echo -e "  ${C_DIM}    • $(get_course_name "$c")${C_RESET}"
    done
    echo -e "  ${C_WHITE}  Valid until: $(_license_expiry_date)${C_RESET}  ${C_DIM}(annual license, no autorenewal)${C_RESET}"
    echo ""
    return 0
}

# _license_expiry_date → YYYY-MM-DD from the cached expires_at
_license_expiry_date() {
    local iso
    iso=$(_license_field expires_at)
    printf '%s' "${iso:0:10}"
}

# _license_expired → 0 if the cached license is past its expiry
_license_expired() {
    local exp
    exp=$(_license_field expires_epoch)
    [ -n "$exp" ] && [ "$(date +%s)" -ge "$exp" ]
}

# Remove the local license (frees this machine; the key itself stays valid).
deactivate_license() {
    if [ ! -f "$LICENSE_FILE" ]; then
        echo -e "  ${C_YELLOW}No active license found.${C_RESET}"
        return 1
    fi
    rm -f "$LICENSE_FILE"
    echo -e "  ${C_GREEN}✅ License removed from this machine.${C_RESET}"
    echo -e "  ${C_DIM}  Re-activate any time with: practicum activate <key>${C_RESET}"
    echo ""
}

license_status() {
    if [ -f "$LICENSE_FILE" ] && [ "$(_license_field valid)" = "true" ]; then
        local key
        key=$(_license_field key)
        if _license_expired; then
            echo -e "  ${C_YELLOW}License: EXPIRED on $(_license_expiry_date)${C_RESET}"
            echo -e "  ${C_DIM}  Renew: https://practicum-cli.dev/#pricing${C_RESET}"
            return 0
        fi
        echo -e "  ${C_GREEN}License: ACTIVE${C_RESET}"
        echo -e "  ${C_DIM}  Key:     ${key:0:9}...${key: -4}${C_RESET}"
        echo -e "  ${C_DIM}  Email:   $(_license_field email)${C_RESET}"
        local role
        role=$(_license_field role)
        echo -e "  ${C_DIM}  Role:    ${role:-learner}${C_RESET}"
        echo -e "  ${C_DIM}  Expires: $(_license_expiry_date) (annual license, no autorenewal)${C_RESET}"
        echo -e "  ${C_DIM}  Courses:${C_RESET}"
        local c
        for c in $(_license_field entitlements); do
            echo -e "  ${C_DIM}    • $(get_course_name "$c")${C_RESET}"
        done
    else
        if [ -f "$LICENSE_EXPIRED_FILE" ]; then
            echo -e "  ${C_YELLOW}License: EXPIRED on $(cat "$LICENSE_EXPIRED_FILE")${C_RESET}"
            echo -e "  ${C_DIM}  Renew: https://practicum-cli.dev/#pricing${C_RESET}"
            return 0
        fi
        echo -e "  ${C_YELLOW}License: FREE (CLI Immersion + Days 1-3 of every course)${C_RESET}"
        echo -e "  ${C_DIM}  Upgrade:  https://practicum-cli.dev/#pricing${C_RESET}"
        echo -e "  ${C_DIM}  Activate: practicum activate <key>${C_RESET}"
    fi
}

# --- validation --------------------------------------------------------------

# validate_license — 0 if a valid license is cached (refreshing it when stale).
#   fresh cache (< 24h)             → trust, no network
#   stale cache, server reachable   → refresh; revoked/unknown → drop cache
#   stale cache, server unreachable → trust up to 7d after last validation
validate_license() {
    LICENSE_DENY_REASON="unlicensed"
    if [ ! -f "$LICENSE_FILE" ]; then
        [ -f "$LICENSE_EXPIRED_FILE" ] && LICENSE_DENY_REASON="expired"
        return 1
    fi
    [ "$(_license_field valid)" = "true" ] || return 1

    # Tampered or unsigned cache: never trust its contents. Ask the server
    # with the stored key — a genuine key re-seals a correct cache, anything
    # else is discarded.
    if ! _cache_intact; then
        local tkey tbody
        tkey=$(_license_field key)
        if [ -n "$tkey" ] && command -v curl &>/dev/null && tbody=$(_license_fetch "$tkey") &&
           [ "$(_json_num "$tbody" valid)" = "true" ]; then
            _license_write "$tbody"
        else
            rm -f "$LICENSE_FILE"
            return 1
        fi
    fi

    # Annual term — checked from the cache first, no network needed.
    if _license_expired; then
        _license_expire_locally "$(_license_expiry_date)"
        return 1
    fi

    local key cached age
    key=$(_license_field key)
    [ -n "$key" ] || return 1
    cached=$(_license_field cached_epoch)
    age=$(( $(date +%s) - ${cached:-0} ))

    [ "$age" -lt "$LICENSE_CACHE_TTL" ] && return 0

    local body
    if command -v curl &>/dev/null && body=$(_license_fetch "$key") && [ -n "$body" ]; then
        if [ "$(_json_num "$body" valid)" = "true" ]; then
            _license_write "$body"
            return 0
        fi
        # Server answered and said no (expired / revoked / not found): drop the cache.
        case "$(_json_str "$body" error)" in
            "License expired")
                _license_expire_locally "$(_json_str "$body" expires_at | cut -c1-10)"
                ;;
            "License revoked")
                rm -f "$LICENSE_FILE"
                LICENSE_DENY_REASON="revoked"
                ;;
            *)
                rm -f "$LICENSE_FILE"
                ;;
        esac
        return 1
    fi

    # Unreachable: offline grace.
    [ "$age" -lt "$LICENSE_OFFLINE_GRACE" ]
}

# _license_expire_locally <YYYY-MM-DD> — purge the cache, remember the date for messaging
_license_expire_locally() {
    rm -f "$LICENSE_FILE"
    printf '%s\n' "$1" > "$LICENSE_EXPIRED_FILE"
    LICENSE_DENY_REASON="expired"
}

# is_free_course <slug>
is_free_course() {
    local c
    for c in $FREE_COURSES; do [ "$1" = "$c" ] && return 0; done
    return 1
}

# is_premium_content <dayN> — days 1-3 are free, day 4+ premium
is_premium_content() {
    case "$1" in
        day1|day2|day3) return 1 ;;
        *) return 0 ;;
    esac
}

# can_access_course <slug> — free course, or licensed with that slug entitled
can_access_course() {
    local course="$1"
    is_free_course "$course" && return 0
    validate_license || return 1
    local c
    for c in $(_license_field entitlements); do
        [ "$c" = "$course" ] && return 0
    done
    LICENSE_DENY_REASON="entitlement"
    return 1
}

# can_access_day <dayN> [course-slug] — course defaults to the active course
can_access_day() {
    local day="$1"
    local course="${2:-$(get_active_course)}"
    is_free_course "$course" && return 0
    is_premium_content "$day" || return 0
    can_access_course "$course"
}

# show_upgrade_prompt [reason] — reason: unlicensed | expired | entitlement
# Defaults to whatever the last can_access_* call decided.
show_upgrade_prompt() {
    local reason="${1:-${LICENSE_DENY_REASON:-unlicensed}}"
    if [ "$reason" = "unlicensed" ] && [ ! -f "$LICENSE_FILE" ] && [ -f "$LICENSE_EXPIRED_FILE" ]; then
        reason="expired"
    fi
    local course
    course=$(get_active_course)
    echo ""
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo -e "  ${C_YELLOW}  🔒 Premium Content — License Required${C_RESET}"
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo ""
    case "$reason" in
        expired)
            local when
            when=$(cat "$LICENSE_EXPIRED_FILE" 2>/dev/null)
            echo -e "  ${C_WHITE}Your Practicum license expired${when:+ on $when}.${C_RESET}"
            echo -e "  ${C_WHITE}Renew your annual license to continue.${C_RESET}"
            ;;
        revoked)
            echo -e "  ${C_WHITE}Your classroom seat was removed. Contact your instructor.${C_RESET}"
            ;;
        entitlement)
            echo -e "  ${C_WHITE}$(get_course_name "$course") is not included in your license.${C_RESET}"
            ;;
        *)
            echo -e "  ${C_WHITE}Days 1-3 are free. Days 4+ require a license.${C_RESET}"
            ;;
    esac
    echo ""
    echo -e "  ${C_WHITE}  Single Course${C_RESET}      ${C_GREEN}\$49/yr${C_RESET}   ${C_DIM}One course + certificate${C_RESET}"
    echo -e "  ${C_WHITE}  Data Engineering${C_RESET}   ${C_GREEN}\$99/yr${C_RESET}   ${C_DIM}3 courses · 26 days${C_RESET}"
    echo -e "  ${C_WHITE}  Platform Eng${C_RESET}      ${C_GREEN}\$129/yr${C_RESET}   ${C_DIM}6 courses · 66 days${C_RESET}"
    echo -e "  ${C_WHITE}  Full Catalog${C_RESET}      ${C_GREEN}\$199/yr${C_RESET}   ${C_DIM}All 8 courses + Labs${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}Annual license. No autorenewal.${C_RESET}"
    echo -e "  ${C_CYAN}  Purchase: https://practicum-cli.dev/#pricing${C_RESET}"
    echo -e "  ${C_CYAN}  Activate: practicum activate <your-key>${C_RESET}"
    echo ""
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo ""
}
