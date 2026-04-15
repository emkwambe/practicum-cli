#!/bin/bash
# Practicum CLI — Sandbox Management

SANDBOX_DIR="$HOME/.practicum/sandbox"
SNAPSHOT_DIR="$HOME/.practicum/snapshots"

init_sandbox() {
    mkdir -p "$SANDBOX_DIR"/{home,tmp,var/log,etc,projects}
    # Create some starter files for exercises
    echo "Welcome to Practicum CLI sandbox!" > "$SANDBOX_DIR/home/welcome.txt"
    echo "ERROR: disk full at 2026-04-14 10:00:00" > "$SANDBOX_DIR/var/log/syslog"
    echo "INFO: service started" >> "$SANDBOX_DIR/var/log/syslog"
    echo "ERROR: connection refused" >> "$SANDBOX_DIR/var/log/syslog"
    echo "INFO: backup completed" >> "$SANDBOX_DIR/var/log/syslog"
}

snapshot_save() {
    local name="${1:-snapshot-$(date +%Y%m%d-%H%M%S)}"
    mkdir -p "$SNAPSHOT_DIR"
    cp -r "$SANDBOX_DIR" "$SNAPSHOT_DIR/$name"
    echo "💾 Snapshot saved: $name"
}

snapshot_restore() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Usage: practicum snapshot restore <name>"
        return 1
    fi
    if [ ! -d "$SNAPSHOT_DIR/$name" ]; then
        echo "Snapshot not found: $name"
        return 1
    fi
    rm -rf "$SANDBOX_DIR"
    cp -r "$SNAPSHOT_DIR/$name" "$SANDBOX_DIR"
    echo "🔄 Restored: $name"
}

snapshot_list() {
    echo ""
    echo "📸 Available snapshots:"
    if [ -d "$SNAPSHOT_DIR" ] && [ "$(ls -A "$SNAPSHOT_DIR" 2>/dev/null)" ]; then
        ls -1 "$SNAPSHOT_DIR/"
    else
        echo "  (none)"
    fi
    echo ""
}

sandbox_reset() {
    rm -rf "$SANDBOX_DIR"
    init_sandbox
    echo "🔄 Sandbox reset to default state."
}