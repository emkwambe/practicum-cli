#!/bin/bash
# Practicum CLI — Command Wrappers (Intent → Context → Action → Result)
# Handles flags correctly: separates -flags from file targets

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

_parse_args() {
    WRAPPER_FLAGS=()
    WRAPPER_TARGETS=()
    for arg in "$@"; do
        if [[ "$arg" == -* ]]; then
            WRAPPER_FLAGS+=("$arg")
        else
            WRAPPER_TARGETS+=("$arg")
        fi
    done
}

_wizard_confirm() {
    local intent="$1" action="$2" result="$3" risk="$4"
    if [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        show_icar "$intent" "Current dir: $PWD" "$action" "$result" "$risk"
        printf "Execute? (y/n): "
        read -r confirm
        [ "$confirm" != "y" ] && echo "Cancelled." && return 1
    fi
    return 0
}

wrapped_rm() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        _parse_args "$@"
        if [ ${#WRAPPER_TARGETS[@]} -eq 0 ]; then
            echo "  rm: missing operand"
            return 1
        fi
        _wizard_confirm \
            "Delete file or directory" \
            "rm $*" \
            "Will be permanently removed from sandbox" \
            "⚠️ DESTRUCTIVE (sandbox only)" || return 0
        for target in "${WRAPPER_TARGETS[@]}"; do
            local clean_target
            clean_target=$(echo "$target" | sed 's|^/||')
            local sandbox_path="$SANDBOX_DIR/$clean_target"
            if [ -e "$sandbox_path" ]; then
                command rm "${WRAPPER_FLAGS[@]}" "$sandbox_path" 2>/dev/null
                echo "  🔒 [SANDBOX] Removed: $sandbox_path"
            else
                echo "  File not in sandbox: $target. No action."
            fi
        done
    else
        command rm "$@"
    fi
}

wrapped_mkdir() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        _parse_args "$@"
        _wizard_confirm \
            "Create a new directory" \
            "mkdir $*" \
            "New folder will be created in sandbox" \
            "Safe" || return 0
        for target in "${WRAPPER_TARGETS[@]}"; do
            command mkdir -p "$SANDBOX_DIR/$target"
            echo "  📁 [SANDBOX] Created: $SANDBOX_DIR/$target"
        done
    else
        command mkdir "$@"
    fi
}

wrapped_touch() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        _parse_args "$@"
        _wizard_confirm \
            "Create an empty file" \
            "touch $*" \
            "New empty file created in sandbox" \
            "Safe" || return 0
        for target in "${WRAPPER_TARGETS[@]}"; do
            local dir
            dir=$(dirname "$SANDBOX_DIR/$target")
            command mkdir -p "$dir"
            command touch "$SANDBOX_DIR/$target"
            echo "  📄 [SANDBOX] Created: $SANDBOX_DIR/$target"
        done
    else
        command touch "$@"
    fi
}

wrapped_ls() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        _parse_args "$@"
        if [ "$PRACTICUM_MODE" = "WIZARD" ]; then
            show_icar \
                "List directory contents" \
                "Current dir: ${PWD}" \
                "ls $*" \
                "Shows files and folders" \
                "Read-only (safe)"
        fi
        if [ ${#WRAPPER_TARGETS[@]} -eq 0 ]; then
            command ls "${WRAPPER_FLAGS[@]}" "$SANDBOX_DIR" 2>/dev/null
        else
            for target in "${WRAPPER_TARGETS[@]}"; do
                command ls "${WRAPPER_FLAGS[@]}" "$SANDBOX_DIR/$target" 2>/dev/null
            done
        fi
    else
        command ls "$@"
    fi
}

wrapped_cp() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        _parse_args "$@"
        if [ ${#WRAPPER_TARGETS[@]} -lt 2 ]; then
            echo "  cp: missing destination"
            return 1
        fi
        _wizard_confirm \
            "Copy file or directory" \
            "cp $*" \
            "A copy will be created in sandbox" \
            "Safe" || return 0
        local src="${WRAPPER_TARGETS[0]}"
        local dst="${WRAPPER_TARGETS[1]}"
        local sandbox_src="$SANDBOX_DIR/$src"
        local sandbox_dst="$SANDBOX_DIR/$dst"
        if [ -e "$sandbox_src" ]; then
            command cp "${WRAPPER_FLAGS[@]}" "$sandbox_src" "$sandbox_dst"
            echo "  📋 [SANDBOX] Copied: $src → $dst"
        else
            echo "  Source not in sandbox: $src"
        fi
    else
        command cp "$@"
    fi
}

wrapped_mv() {
    if [ "$PRACTICUM_MODE" = "LAB" ] || [ "$PRACTICUM_MODE" = "WIZARD" ]; then
        _parse_args "$@"
        if [ ${#WRAPPER_TARGETS[@]} -lt 2 ]; then
            echo "  mv: missing destination"
            return 1
        fi
        _wizard_confirm \
            "Move or rename file" \
            "mv $*" \
            "File will be moved/renamed in sandbox" \
            "⚠️ Overwrites destination if exists" || return 0
        local src="${WRAPPER_TARGETS[0]}"
        local dst="${WRAPPER_TARGETS[1]}"
        local sandbox_src="$SANDBOX_DIR/$src"
        local sandbox_dst="$SANDBOX_DIR/$dst"
        if [ -e "$sandbox_src" ]; then
            command mv "${WRAPPER_FLAGS[@]}" "$sandbox_src" "$sandbox_dst"
            echo "  📦 [SANDBOX] Moved: $src → $dst"
        else
            echo "  Source not in sandbox: $src"
        fi
    else
        command mv "$@"
    fi
}