#!/bin/bash
# Practicum CLI — classroom progress reporting.
#
# Events are written locally first and delivered later, so a learner on hotel
# wifi or in a lab with no network loses nothing. Each line in the outbox is
# one event; a flush removes only the lines the server accepted.
#
# Nothing is emitted unless all three hold:
#   - the license belongs to a classroom (solo licenses never report)
#   - the learner has acknowledged the sharing notice
#   - curl exists
#
# Pure bash + coreutils + curl. No jq.

PROGRESS_OUTBOX="$HOME/.practicum/outbox.log"
PROGRESS_CONSENT="$HOME/.practicum/classroom_consent"
PROGRESS_MAX_FLUSH=50        # per flush, so a large backlog never stalls a lesson

# --- consent -----------------------------------------------------------------

# Only classroom licenses report anything at all.
_progress_classroom_id() {
    [ -f "$LICENSE_FILE" ] || return 1
    local id
    id=$(_license_field classroom_id)
    [ -n "$id" ] && printf '%s' "$id"
}

progress_has_consent() { [ -f "$PROGRESS_CONSENT" ]; }

# Shown once, on the first activation of a classroom key. Nothing is recorded
# or sent before the learner answers.
progress_request_consent() {
    local course_note="$1"
    progress_has_consent && return 0
    _progress_classroom_id >/dev/null || return 0

    echo ""
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo -e "  ${C_WHITE}  Your instructor can see your progress${C_RESET}"
    echo -e "  ${C_PURPLE}=========================================${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}This license is part of a classroom${course_note}.${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}Shared with your instructor:${C_RESET}"
    echo -e "  ${C_DIM}    • which lessons and labs you start and finish${C_RESET}"
    echo -e "  ${C_DIM}    • when you last used Practicum${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE}Never collected:${C_RESET}"
    echo -e "  ${C_DIM}    • your commands, files, keystrokes or terminal output${C_RESET}"
    echo -e "  ${C_DIM}    • anything from outside Practicum${C_RESET}"
    echo ""
    printf "  %b" "${C_CYAN}Type yes to continue, anything else to decline: ${C_RESET}"
    local answer
    read -r answer
    case "$answer" in
        y|Y|yes|YES|Yes)
            printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PROGRESS_CONSENT"
            chmod 600 "$PROGRESS_CONSENT" 2>/dev/null
            echo ""
            echo -e "  ${C_GREEN}Thanks — progress sharing is on.${C_RESET}"
            echo -e "  ${C_DIM}  Your key still works if you decline; your instructor just sees nothing.${C_RESET}"
            echo ""
            return 0
            ;;
        *)
            echo ""
            echo -e "  ${C_YELLOW}Declined. Nothing will be shared.${C_RESET}"
            echo -e "  ${C_DIM}  Your course works normally. Run 'practicum sharing on' to change this.${C_RESET}"
            echo ""
            return 1
            ;;
    esac
}

# practicum sharing [on|off|status]
progress_sharing() {
    case "${1:-status}" in
        on)
            if ! _progress_classroom_id >/dev/null; then
                echo -e "  ${C_YELLOW}This license is not part of a classroom — there is nothing to share.${C_RESET}"
                return 1
            fi
            printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PROGRESS_CONSENT"
            chmod 600 "$PROGRESS_CONSENT" 2>/dev/null
            echo -e "  ${C_GREEN}Progress sharing is on.${C_RESET}"
            ;;
        off)
            rm -f "$PROGRESS_CONSENT" "$PROGRESS_OUTBOX"
            echo -e "  ${C_GREEN}Progress sharing is off. Queued events were discarded.${C_RESET}"
            ;;
        *)
            if ! _progress_classroom_id >/dev/null; then
                echo -e "  ${C_DIM}Sharing: not applicable — this is not a classroom license.${C_RESET}"
            elif progress_has_consent; then
                local queued=0
                [ -f "$PROGRESS_OUTBOX" ] && queued=$(grep -c . "$PROGRESS_OUTBOX" 2>/dev/null || echo 0)
                echo -e "  ${C_GREEN}Sharing: ON${C_RESET} ${C_DIM}(since $(cat "$PROGRESS_CONSENT" 2>/dev/null))${C_RESET}"
                echo -e "  ${C_DIM}  Queued events: ${queued}${C_RESET}"
            else
                echo -e "  ${C_YELLOW}Sharing: OFF${C_RESET} ${C_DIM}— your instructor sees nothing.${C_RESET}"
            fi
            ;;
    esac
}

# --- emitting ----------------------------------------------------------------

# Collision-safe without uuidgen: UTC timestamp to the second, the PID, a
# monotonic counter within this process, and 8 bytes of /dev/urandom. Falls back
# to $RANDOM where /dev/urandom is unavailable.
_progress_event_id() {
    local rand=""
    if [ -r /dev/urandom ]; then
        rand=$(head -c 8 /dev/urandom 2>/dev/null | od -An -tx1 2>/dev/null | tr -d ' \n')
    fi
    [ -n "$rand" ] || rand=$(printf '%04x%04x%04x%04x' "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM")
    PROGRESS_SEQ=$(( ${PROGRESS_SEQ:-0} + 1 ))
    printf 'ev-%s-%s-%s-%s' "$(date -u +%Y%m%dT%H%M%SZ)" "$$" "$PROGRESS_SEQ" "$rand"
}

# progress_emit <event> <content_id>
# Appends one line and returns immediately — a lesson must never wait on a
# network call. Delivery happens on the next flush.
progress_emit() {
    local event="$1" content_id="$2"
    [ -n "$event" ] && [ -n "$content_id" ] || return 0
    _progress_classroom_id >/dev/null || return 0     # solo licenses never emit
    progress_has_consent || return 0                  # nothing before consent

    mkdir -p "$(dirname "$PROGRESS_OUTBOX")" 2>/dev/null
    printf '%s|%s|%s|%s|%s\n' \
        "$(_progress_event_id)" "$content_id" "$event" \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${PRACTICUM_VERSION:-unknown}" \
        >> "$PROGRESS_OUTBOX"
    chmod 600 "$PROGRESS_OUTBOX" 2>/dev/null
}

# content ids must match content/manifest.json exactly: <course>/<type>/<slug>
progress_lesson_id() { printf '%s/lesson/%s' "$(get_active_course)" "$1"; }
progress_lab_id()    { printf '%s/lab/%s' "$(get_active_course)" "$1"; }

# --- flushing ----------------------------------------------------------------

# Sends queued events oldest first. A line is removed only when the server
# accepted it (2xx) or told us it will never accept it (4xx). Anything else —
# 5xx, timeout, no network — leaves the line in place for next time.
progress_flush() {
    [ -f "$PROGRESS_OUTBOX" ] || return 0
    [ -s "$PROGRESS_OUTBOX" ] || return 0
    _progress_classroom_id >/dev/null || return 0
    progress_has_consent || return 0
    command -v curl >/dev/null 2>&1 || return 0

    local key
    key=$(_license_field key)
    [ -n "$key" ] || return 0

    local keep sent=0 dropped=0 line n=0 offline=0
    keep=$(mktemp 2>/dev/null) || return 0

    while IFS='|' read -r event_id content_id event occurred_at cli_version; do
        [ -n "$event_id" ] || continue
        n=$((n + 1))
        # Once the server is unreachable, stop trying. Every attempt costs a
        # connect timeout, so a learner with a backlog would otherwise wait
        # seconds per queued event after finishing a lesson — the flush is
        # meant to be invisible.
        if [ "$offline" -eq 1 ] || [ "$n" -gt "$PROGRESS_MAX_FLUSH" ]; then
            printf '%s|%s|%s|%s|%s\n' "$event_id" "$content_id" "$event" "$occurred_at" "$cli_version" >> "$keep"
            continue
        fi

        local code
        code=$(curl -s -o /dev/null -w '%{http_code}' \
            --connect-timeout 5 --max-time 15 \
            -X POST "$PRACTICUM_API/v1/progress" \
            -H "X-License-Key: $key" \
            --data-urlencode "event_id=$event_id" \
            --data-urlencode "content_id=$content_id" \
            --data-urlencode "event=$event" \
            --data-urlencode "occurred_at=$occurred_at" \
            --data-urlencode "cli_version=$cli_version" 2>/dev/null)

        case "$code" in
            2*)  sent=$((sent + 1)) ;;
            # The server will never accept this event — a revoked seat, an
            # expired license, an unknown content id. Retrying forever would
            # mean a revoked learner's terminal calling home indefinitely.
            4*)  if [ "$code" = "429" ]; then
                     printf '%s|%s|%s|%s|%s\n' "$event_id" "$content_id" "$event" "$occurred_at" "$cli_version" >> "$keep"
                 else
                     dropped=$((dropped + 1))
                 fi ;;
            # 000 is curl's "could not connect at all" — no network, DNS
            # failure, or the server is down. Keep this event and every one
            # after it, and stop making calls.
            000) offline=1
                 printf '%s|%s|%s|%s|%s\n' "$event_id" "$content_id" "$event" "$occurred_at" "$cli_version" >> "$keep" ;;
            *)   printf '%s|%s|%s|%s|%s\n' "$event_id" "$content_id" "$event" "$occurred_at" "$cli_version" >> "$keep" ;;
        esac
    done < "$PROGRESS_OUTBOX"

    if [ -s "$keep" ]; then
        mv "$keep" "$PROGRESS_OUTBOX"
        chmod 600 "$PROGRESS_OUTBOX" 2>/dev/null
    else
        rm -f "$keep" "$PROGRESS_OUTBOX"
    fi

    [ -n "${PRACTICUM_PROGRESS_DEBUG:-}" ] && echo "  progress: $sent sent, $dropped dropped" >&2
    return 0
}
