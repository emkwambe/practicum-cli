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
    cat > "$LICENSE_FILE" << LJSON
{
    "key": "$(_json_str "$body" key)",
    "email": "$(_json_str "$body" email)",
    "product_id": "$(_json_str "$body" product_id)",
    "entitlements": "$(_json_arr "$body" entitlements)",
    "seats": "$(_json_num "$body" seats)",
    "activated_at": "$(_json_str "$body" activated_at)",
    "cached_epoch": "$(date +%s)",
    "valid": "true"
}
LJSON
    chmod 600 "$LICENSE_FILE"
}

# --- commands ----------------------------------------------------------------

activate_license() {
    local key
    key=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')

    if [ -z "$key" ]; then
        echo -e "  ${C_RED}Usage: practicum activate <license_key>${C_RESET}"
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
        echo -e "  ${C_YELLOW}  $(_json_str "$body" error)${C_RESET}"
        echo -e "  ${C_DIM}  Check the key in your purchase email, or contact practicum@mpingo.ai${C_RESET}"
        echo ""
        return 1
    fi

    _license_write "$body"

    echo ""
    echo -e "  ${C_GREEN}✅ License activated for $(_json_str "$body" email)${C_RESET}"
    echo -e "  ${C_WHITE}  Courses unlocked:${C_RESET}"
    local c
    for c in $(_json_arr "$body" entitlements); do
        echo -e "  ${C_DIM}    • $(get_course_name "$c")${C_RESET}"
    done
    echo ""
    return 0
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
        echo -e "  ${C_GREEN}License: ACTIVE${C_RESET}"
        echo -e "  ${C_DIM}  Key:   ${key:0:9}...${key: -4}${C_RESET}"
        echo -e "  ${C_DIM}  Email: $(_license_field email)${C_RESET}"
        echo -e "  ${C_DIM}  Courses:${C_RESET}"
        local c
        for c in $(_license_field entitlements); do
            echo -e "  ${C_DIM}    • $(get_course_name "$c")${C_RESET}"
        done
    else
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
    [ -f "$LICENSE_FILE" ] || return 1
    [ "$(_license_field valid)" = "true" ] || return 1

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
        # Server answered and said no (revoked / not found): drop the cache.
        rm -f "$LICENSE_FILE"
        return 1
    fi

    # Unreachable: offline grace.
    [ "$age" -lt "$LICENSE_OFFLINE_GRACE" ]
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

show_upgrade_prompt() {
    local course
    course=$(get_active_course)
    echo ""
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo -e "  ${C_YELLOW}  🔒 Premium Content — License Required${C_RESET}"
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo ""
    if [ -f "$LICENSE_FILE" ] && [ "$(_license_field valid)" = "true" ]; then
        echo -e "  ${C_WHITE}Your license does not include $(get_course_name "$course").${C_RESET}"
    else
        echo -e "  ${C_WHITE}Days 1-3 are free. Days 4+ require a license.${C_RESET}"
    fi
    echo ""
    echo -e "  ${C_WHITE}  Single Course${C_RESET}      ${C_GREEN}\$49${C_RESET}   ${C_DIM}One course + certificate${C_RESET}"
    echo -e "  ${C_WHITE}  Data Engineering${C_RESET}   ${C_GREEN}\$99${C_RESET}   ${C_DIM}3 courses · 26 days${C_RESET}"
    echo -e "  ${C_WHITE}  Platform Eng${C_RESET}      ${C_GREEN}\$129${C_RESET}   ${C_DIM}6 courses · 66 days${C_RESET}"
    echo -e "  ${C_WHITE}  Full Catalog${C_RESET}      ${C_GREEN}\$199${C_RESET}   ${C_DIM}All 8 courses + updates${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}Buy once. Yours forever.${C_RESET}"
    echo -e "  ${C_CYAN}  Purchase: https://practicum-cli.dev/#pricing${C_RESET}"
    echo -e "  ${C_CYAN}  Activate: practicum activate <your-key>${C_RESET}"
    echo ""
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo ""
}
