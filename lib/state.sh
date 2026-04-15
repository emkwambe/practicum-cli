#!/bin/bash
# Practicum CLI — State Management (pure bash, no jq)

PRACTICUM_HOME="$HOME/.practicum"
PROGRESS_FILE="$PRACTICUM_HOME/progress.json"
UNLOCKED_FILE="$PRACTICUM_HOME/unlocked.txt"
CONFIG_FILE="$PRACTICUM_HOME/config"
SCORES_FILE="$PRACTICUM_HOME/scores.txt"

init_state() {
    mkdir -p "$PRACTICUM_HOME/sandbox" "$PRACTICUM_HOME/snapshots"
    chmod 700 "$PRACTICUM_HOME"
    if [ ! -f "$UNLOCKED_FILE" ]; then
        printf "pwd\nls\ncd\n" > "$UNLOCKED_FILE"
    fi
    if [ ! -f "$PROGRESS_FILE" ]; then
        echo '{"completed":[],"current_day":1,"current_lesson":1}' > "$PROGRESS_FILE"
    fi
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "PRACTICUM_MODE=WIZARD" > "$CONFIG_FILE"
    fi
    if [ ! -f "$SCORES_FILE" ]; then
        touch "$SCORES_FILE"
    fi
}

add_completed() {
    local lesson="$1"
    if ! grep -qx "$lesson" "$PRACTICUM_HOME/completed.txt" 2>/dev/null; then
        echo "$lesson" >> "$PRACTICUM_HOME/completed.txt"
    fi
}

is_completed() {
    grep -qx "$1" "$PRACTICUM_HOME/completed.txt" 2>/dev/null
}

is_unlocked() {
    grep -qx "$1" "$UNLOCKED_FILE" 2>/dev/null
}

unlock_lesson() {
    local lesson="$1"
    if ! grep -qx "$lesson" "$UNLOCKED_FILE" 2>/dev/null; then
        echo "$lesson" >> "$UNLOCKED_FILE"
    fi
}

save_score() {
    local quiz="$1"
    local score="$2"
    # Remove old score if exists, then add new
    grep -v "^${quiz}=" "$SCORES_FILE" > "$SCORES_FILE.tmp" 2>/dev/null
    echo "${quiz}=${score}" >> "$SCORES_FILE.tmp"
    mv "$SCORES_FILE.tmp" "$SCORES_FILE"
}

get_score() {
    local quiz="$1"
    grep "^${quiz}=" "$SCORES_FILE" 2>/dev/null | cut -d= -f2
}

get_mode() {
    if [ -f "$CONFIG_FILE" ]; then
        grep "^PRACTICUM_MODE=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2
    else
        echo "WIZARD"
    fi
}

set_mode() {
    local mode="$1"
    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^PRACTICUM_MODE=" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" 2>/dev/null
        echo "PRACTICUM_MODE=$mode" >> "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        echo "PRACTICUM_MODE=$mode" > "$CONFIG_FILE"
    fi
}

count_completed() {
    if [ -f "$PRACTICUM_HOME/completed.txt" ]; then
        wc -l < "$PRACTICUM_HOME/completed.txt" | tr -d ' '
    else
        echo "0"
    fi
}

count_unlocked() {
    if [ -f "$UNLOCKED_FILE" ]; then
        wc -l < "$UNLOCKED_FILE" | tr -d ' '
    else
        echo "0"
    fi
}