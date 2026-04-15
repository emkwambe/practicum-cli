#!/bin/bash
# Practicum CLI — Terminal Colors
# Purple headings, neon green highlights, clean dark terminal aesthetic
# Falls back gracefully if terminal doesn't support colors (G8 compliance)

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null)" -ge 8 ]; then
    # Colors available
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    
    # Purple for headings and borders
    C_PURPLE='\033[1;35m'
    
    # Neon green for success, highlights, encouragement
    C_GREEN='\033[1;32m'
    
    # Cyan for info, context, navigation
    C_CYAN='\033[1;36m'
    
    # Yellow for warnings, locked items
    C_YELLOW='\033[1;33m'
    
    # Red for errors, destructive actions
    C_RED='\033[1;31m'
    
    # White bold for regular emphasis
    C_WHITE='\033[1;37m'
    
    # Dim for secondary text
    C_DIM='\033[2m'
else
    # No color support — empty strings (G8: works over serial)
    C_RESET=''
    C_BOLD=''
    C_PURPLE=''
    C_GREEN=''
    C_CYAN=''
    C_YELLOW=''
    C_RED=''
    C_WHITE=''
    C_DIM=''
fi

# Helper functions for colored output
print_header() {
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "${C_PURPLE}  $1${C_RESET}"
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo ""
}

print_success() {
    echo -e "  ${C_GREEN}✅ $1${C_RESET}"
}

print_error() {
    echo -e "  ${C_RED}❌ $1${C_RESET}"
}

print_warning() {
    echo -e "  ${C_YELLOW}⚠️  $1${C_RESET}"
}

print_info() {
    echo -e "  ${C_CYAN}$1${C_RESET}"
}

print_locked() {
    echo -e "  ${C_YELLOW}🔒 $1${C_RESET}"
}

print_unlocked() {
    echo -e "  ${C_CYAN}🔓 $1${C_RESET}"
}

print_completed() {
    echo -e "  ${C_GREEN}✅ $1${C_RESET}"
}

print_menu_item() {
    local num="$1"
    local text="$2"
    echo -e "  ${C_WHITE}[$num]${C_RESET} $text"
}

print_prompt() {
    echo ""
    printf "  ${C_CYAN}Your choice: ${C_RESET}"
}

print_icar() {
    local intent="$1"
    local context="$2"
    local action="$3"
    local result="$4"
    local risk="${5:-read-only}"
    
    echo ""
    echo -e "${C_PURPLE}=========================================${C_RESET}"
    echo -e "${C_WHITE}[INTENT]${C_RESET}  ${C_GREEN}$intent${C_RESET}"
    echo -e "${C_WHITE}[CONTEXT]${C_RESET} ${C_CYAN}$context${C_RESET}"
    echo -e "${C_WHITE}[ACTION]${C_RESET}  ${C_WHITE}$action${C_RESET}"
    echo -e "${C_WHITE}[RESULT]${C_RESET}  ${C_GREEN}$result${C_RESET}"
    echo -e "${C_WHITE}[RISK]${C_RESET}    ${C_YELLOW}$risk${C_RESET}"
    echo -e "${C_PURPLE}=========================================${C_RESET}"
}
