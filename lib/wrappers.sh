#!/bin/bash
# Practicum CLI — Command Wrappers (Intent → Context → Action → Result)

SANDBOX_DIR="$HOME/.practicum/sandbox"

show_icar() {
    local intent="$1"
    local context="$2"
    local action="$3"
    local result="$4"
    local risk="${5:-read-only}"
    
    echo ""
    echo "========================================="
    echo "[INTENT]  $intent"
    echo "[CONTEXT] $context"
    echo "[ACTION]  $action"
    echo "[RESULT]  $result"
    echo "[RISK]    $risk"
    echo "========================================="
}

wrapped_rm() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        local target="$SANDBOX_DIR/$1"
        
        if [ "$PRACTICUM_MODE" = "WIZARD" ]; then
            show_icar \
                "Delete file or directory" \
                "Current dir: $PWD" \
                "rm $*" \
                "File will be permanently removed from sandbox" \
                "⚠️ DESTRUCTIVE (sandbox only)"
            
            printf "Execute? (y/n): "
            read -r confirm
            [ "$confirm" != "y" ] && echo "Cancelled." && return 0
        fi
        
        if [ -e "$target" ]; then
            command rm "$target"
            echo "  🔒 [SANDBOX] Removed: $target"
        else
            echo "  File not in sandbox. No action."
        fi
    else
        command rm "$@"
    fi
}

wrapped_mkdir() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        if [ "$PRACTICUM_MODE" = "WIZARD" ]; then
            show_icar \
                "Create a new directory" \
                "Current dir: $PWD" \
                "mkdir $*" \
                "New folder will be created in sandbox" \
                "Safe"
            
            printf "Execute? (y/n): "
            read -r confirm
            [ "$confirm" != "y" ] && echo "Cancelled." && return 0
        fi
        
        command mkdir -p "$SANDBOX_DIR/$1"
        echo "  📁 [SANDBOX] Created: $SANDBOX_DIR/$1"
    else
        command mkdir "$@"
    fi
}

wrapped_touch() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        if [ "$PRACTICUM_MODE" = "WIZARD" ]; then
            show_icar \
                "Create an empty file" \
                "Current dir: $PWD" \
                "touch $*" \
                "New empty file created in sandbox" \
                "Safe"
            
            printf "Execute? (y/n): "
            read -r confirm
            [ "$confirm" != "y" ] && echo "Cancelled." && return 0
        fi
        
        command touch "$SANDBOX_DIR/$1"
        echo "  📄 [SANDBOX] Created: $SANDBOX_DIR/$1"
    else
        command touch "$@"
    fi
}

wrapped_ls() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        if [ "$PRACTICUM_MODE" = "WIZARD" ]; then
            show_icar \
                "List directory contents" \
                "Current dir: ${PWD}" \
                "ls $*" \
                "Shows files and folders" \
                "Read-only (safe)"
        fi
        
        local target="${1:-.}"
        if [ "$target" = "." ] || [ "$target" = "-la" ] || [ "$target" = "-l" ] || [ "$target" = "-a" ]; then
            command ls "$@" "$SANDBOX_DIR" 2>/dev/null
        else
            command ls "$@" "$SANDBOX_DIR/$target" 2>/dev/null
        fi
    else
        command ls "$@"
    fi
}