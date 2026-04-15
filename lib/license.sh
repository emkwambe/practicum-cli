#!/bin/bash
# Practicum CLI — License Management (Dodo Payments)
# Public endpoints — no API key required in client code
# https://docs.dodopayments.com/features/license-keys

DODO_API="https://api.dodopayments.com"
LICENSE_FILE="$HOME/.practicum/license.json"
LICENSE_CACHE_DAYS=7  # offline grace period

init_license() {
    mkdir -p "$HOME/.practicum"
}

# Check if curl is available
check_curl() {
    if ! command -v curl &>/dev/null; then
        echo -e "  ${C_RED}Error: curl is required for license activation.${C_RESET}"
        echo -e "  ${C_DIM}Install with: sudo apt install curl${C_RESET}"
        return 1
    fi
}

# Activate a license key on this device
activate_license() {
    local license_key="$1"
    
    if [ -z "$license_key" ]; then
        echo -e "  ${C_RED}Usage: practicum activate <license_key>${C_RESET}"
        echo ""
        echo -e "  ${C_DIM}Get your key at: https://practicum-cli.dev${C_RESET}"
        return 1
    fi
    
    check_curl || return 1
    
    local device_name
    device_name="$(whoami)@$(hostname)"
    
    echo -e "  ${C_CYAN}Activating license...${C_RESET}"
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "${DODO_API}/licenses/activate" \
        -H "Content-Type: application/json" \
        -d "{\"license_key\": \"${license_key}\", \"name\": \"${device_name}\"}" \
        2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        # Extract instance_id from response
        local instance_id
        instance_id=$(echo "$body" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        # Store license locally
        cat > "$LICENSE_FILE" << LJSON
{
    "license_key": "${license_key}",
    "instance_id": "${instance_id}",
    "device": "${device_name}",
    "activated_at": "$(date -Iseconds)",
    "last_validated": "$(date -Iseconds)",
    "valid": true
}
LJSON
        
        echo ""
        echo -e "  ${C_GREEN}✅ License activated successfully!${C_RESET}"
        echo -e "  ${C_DIM}  Device: ${device_name}${C_RESET}"
        echo -e "  ${C_DIM}  All premium content is now unlocked.${C_RESET}"
        echo ""
        return 0
    else
        echo ""
        echo -e "  ${C_RED}❌ Activation failed.${C_RESET}"
        
        # Parse error
        if echo "$body" | grep -qi "activation.*limit\|max.*activation"; then
            echo -e "  ${C_YELLOW}  This key has reached its activation limit.${C_RESET}"
            echo -e "  ${C_DIM}  Deactivate another device first: practicum deactivate${C_RESET}"
        elif echo "$body" | grep -qi "expired"; then
            echo -e "  ${C_YELLOW}  This license key has expired.${C_RESET}"
            echo -e "  ${C_DIM}  Renew at: https://practicum-cli.dev${C_RESET}"
        elif echo "$body" | grep -qi "not found\|invalid"; then
            echo -e "  ${C_YELLOW}  Invalid license key. Check for typos.${C_RESET}"
        else
            echo -e "  ${C_YELLOW}  Error: ${body}${C_RESET}"
        fi
        echo ""
        return 1
    fi
}

# Validate the stored license (called on startup)
validate_license() {
    if [ ! -f "$LICENSE_FILE" ]; then
        return 1  # no license
    fi
    
    local license_key
    license_key=$(grep '"license_key"' "$LICENSE_FILE" | cut -d'"' -f4)
    
    if [ -z "$license_key" ]; then
        return 1
    fi
    
    # Check offline grace period
    local last_validated
    last_validated=$(grep '"last_validated"' "$LICENSE_FILE" | cut -d'"' -f4)
    if [ -n "$last_validated" ]; then
        local last_epoch
        last_epoch=$(date -d "$last_validated" +%s 2>/dev/null || echo 0)
        local now_epoch
        now_epoch=$(date +%s)
        local diff_days=$(( (now_epoch - last_epoch) / 86400 ))
        
        if [ "$diff_days" -lt "$LICENSE_CACHE_DAYS" ]; then
            # Within grace period, trust cached result
            grep -q '"valid": true' "$LICENSE_FILE" && return 0
        fi
    fi
    
    # Online validation
    if ! command -v curl &>/dev/null; then
        # No curl, trust cache
        grep -q '"valid": true' "$LICENSE_FILE" && return 0
        return 1
    fi
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "${DODO_API}/licenses/validate" \
        -H "Content-Type: application/json" \
        -d "{\"license_key\": \"${license_key}\"}" \
        --connect-timeout 5 \
        2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        if echo "$body" | grep -qi '"valid":\s*true\|"valid": true'; then
            # Update last_validated timestamp
            sed -i "s/\"last_validated\": \"[^\"]*\"/\"last_validated\": \"$(date -Iseconds)\"/" "$LICENSE_FILE" 2>/dev/null
            return 0
        fi
    fi
    
    # Validation failed — but allow offline grace
    if [ "$diff_days" -lt "$LICENSE_CACHE_DAYS" ] 2>/dev/null; then
        grep -q '"valid": true' "$LICENSE_FILE" && return 0
    fi
    
    return 1
}

# Deactivate license on this device
deactivate_license() {
    if [ ! -f "$LICENSE_FILE" ]; then
        echo -e "  ${C_YELLOW}No active license found.${C_RESET}"
        return 1
    fi
    
    check_curl || return 1
    
    local license_key instance_id
    license_key=$(grep '"license_key"' "$LICENSE_FILE" | cut -d'"' -f4)
    instance_id=$(grep '"instance_id"' "$LICENSE_FILE" | cut -d'"' -f4)
    
    echo -e "  ${C_CYAN}Deactivating license...${C_RESET}"
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "${DODO_API}/licenses/deactivate" \
        -H "Content-Type: application/json" \
        -d "{\"license_key\": \"${license_key}\", \"license_key_instance_id\": \"${instance_id}\"}" \
        2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -1)
    
    if [ "$http_code" = "200" ]; then
        rm -f "$LICENSE_FILE"
        echo -e "  ${C_GREEN}✅ License deactivated. You can activate on another device.${C_RESET}"
    else
        echo -e "  ${C_YELLOW}  Deactivation may have failed. Removing local license anyway.${C_RESET}"
        rm -f "$LICENSE_FILE"
    fi
    echo ""
}

# Check license status (for display)
license_status() {
    if [ -f "$LICENSE_FILE" ]; then
        local key device activated
        key=$(grep '"license_key"' "$LICENSE_FILE" | cut -d'"' -f4)
        device=$(grep '"device"' "$LICENSE_FILE" | cut -d'"' -f4)
        activated=$(grep '"activated_at"' "$LICENSE_FILE" | cut -d'"' -f4)
        local masked_key="${key:0:8}...${key: -4}"
        
        echo -e "  ${C_GREEN}License: ACTIVE${C_RESET}"
        echo -e "  ${C_DIM}  Key: ${masked_key}${C_RESET}"
        echo -e "  ${C_DIM}  Device: ${device}${C_RESET}"
        echo -e "  ${C_DIM}  Activated: ${activated}${C_RESET}"
    else
        echo -e "  ${C_YELLOW}License: FREE (Days 1-3 only)${C_RESET}"
        echo -e "  ${C_DIM}  Upgrade: https://practicum-cli.dev${C_RESET}"
        echo -e "  ${C_DIM}  Activate: practicum activate <key>${C_RESET}"
    fi
}

# Check if content is accessible (free vs paid)
is_premium_content() {
    local day="$1"
    # Days 1-3 are free, Days 4-10 require license
    case "$day" in
        day1|day2|day3) return 1 ;;  # NOT premium (free)
        *) return 0 ;;               # IS premium
    esac
}

can_access_day() {
    local day="$1"
    
    # Free days always accessible
    if ! is_premium_content "$day"; then
        return 0
    fi
    
    # Premium days require valid license
    validate_license
}

show_upgrade_prompt() {
    echo ""
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo -e "  ${C_YELLOW}  🔒 Premium Content — License Required${C_RESET}"
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}Days 1-3 are free. Days 4-10 require a license.${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}  🎓 Individual: \$79 one-time${C_RESET}"
    echo -e "  ${C_DIM}     Full course + certificate + challenges${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}  🏫 Classroom: \$299/semester (30 seats)${C_RESET}"
    echo -e "  ${C_DIM}     Group licenses for training programs${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}  🏢 Team: \$149/month (10 seats)${C_RESET}"
    echo -e "  ${C_DIM}     Corporate training + analytics${C_RESET}"
    echo ""
    echo -e "  ${C_CYAN}  Purchase: https://practicum-cli.dev${C_RESET}"
    echo -e "  ${C_CYAN}  Activate: practicum activate <your-key>${C_RESET}"
    echo ""
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo ""
}
