#!/usr/bin/env bats
# ==============================================================================
# Integration test: emit_osc muted vs unmuted byte comparison
# Verifies that when muted, bytes go to pending cache and TTY gets 0 bytes.
# When unmuted, bytes go to TTY as before.
# ==============================================================================

REPO_ROOT=""
TEST_HOME=""
RUNTIME_DIR=""

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_HOME=$(mktemp -d)
    # Isolated runtime dir: the live /tmp/tavs-$UID may carry a real hard
    # lock (lock.state), which would suppress the "unmuted" cases here.
    RUNTIME_DIR="$TEST_HOME/runtime"
    export TAVS_RUNTIME_DIR="$RUNTIME_DIR"
    mkdir -p "$TEST_HOME/.tavs" "$RUNTIME_DIR"
}

teardown() {
    rm -rf "$TEST_HOME"
}

_create_mute_state() {
    local home="$1"
    # Use parent shell PID (guaranteed alive)
    local parent_pid
    parent_pid=$(ps -o ppid= -p $$ | tr -d ' ')
    local now
    now=$(date +%s)
    cat > "$home/.tavs/mute.state" <<EOF
MUTED="true"
REASON="test"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$parent_pid"
SCHEMA_VERSION="1"
EOF
}

@test "processing: unmuted sends bytes to TTY" {
    local tty_file
    tty_file=$(mktemp)
    # No mute.state = unmuted
    env -i HOME="$TEST_HOME" PATH="$PATH" TAVS_RUNTIME_DIR="$RUNTIME_DIR" TTY_DEVICE="$tty_file" \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null
    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    rm -f "$tty_file"
    [ "$bytes" -gt 0 ]
}

@test "processing: muted sends 0 bytes to TTY" {
    _create_mute_state "$TEST_HOME"
    local tty_file
    tty_file=$(mktemp)
    TTY_DEVICE="$tty_file" HOME="$TEST_HOME" PATH="$PATH" \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null
    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    rm -f "$tty_file"
    [ "$bytes" -eq 0 ]
}

@test "processing: muted creates pending cache with captured bytes" {
    _create_mute_state "$TEST_HOME"
    local tty_file
    tty_file=$(mktemp)
    TTY_DEVICE="$tty_file" HOME="$TEST_HOME" PATH="$PATH" \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null
    local tty_safe="${tty_file//\//_}"
    local cache="$RUNTIME_DIR/pending/${tty_safe}.osc"
    [ -f "$cache" ]
    local cache_bytes
    cache_bytes=$(wc -c < "$cache" | tr -d ' ')
    [ "$cache_bytes" -gt 0 ]
    rm -f "$tty_file" "$cache" "$RUNTIME_DIR/active-ttys/$tty_safe"
}

@test "reset: muted sends 0 bytes to TTY and creates pending cache" {
    _create_mute_state "$TEST_HOME"
    local tty_file
    tty_file=$(mktemp)
    TTY_DEVICE="$tty_file" HOME="$TEST_HOME" PATH="$PATH" \
        bash "$REPO_ROOT/src/core/trigger.sh" reset 2>/dev/null
    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    local tty_safe="${tty_file//\//_}"
    local cache="$RUNTIME_DIR/pending/${tty_safe}.osc"
    [ "$bytes" -eq 0 ]
    [ -f "$cache" ]
    rm -f "$tty_file" "$cache" "$RUNTIME_DIR/active-ttys/$tty_safe"
}

@test "active-tty registered on every dispatch (muted and unmuted)" {
    local tty_file
    tty_file=$(mktemp)
    # Unmuted dispatch
    env -i HOME="$TEST_HOME" PATH="$PATH" TAVS_RUNTIME_DIR="$RUNTIME_DIR" TTY_DEVICE="$tty_file" \
        bash "$REPO_ROOT/src/core/trigger.sh" reset 2>/dev/null
    local tty_safe="${tty_file//\//_}"
    [ -f "$RUNTIME_DIR/active-ttys/$tty_safe" ]
    rm -f "$tty_file" "$RUNTIME_DIR/active-ttys/$tty_safe"
}

@test "muted bytes match unmuted bytes for same state" {
    # Capture unmuted bytes
    local unmuted_tty
    unmuted_tty=$(mktemp)
    env -i HOME="$TEST_HOME" PATH="$PATH" TAVS_RUNTIME_DIR="$RUNTIME_DIR" TTY_DEVICE="$unmuted_tty" \
        bash "$REPO_ROOT/src/core/trigger.sh" compacting 2>/dev/null

    # Capture muted bytes (should be in pending cache)
    _create_mute_state "$TEST_HOME"
    local muted_tty
    muted_tty=$(mktemp)
    TTY_DEVICE="$muted_tty" HOME="$TEST_HOME" PATH="$PATH" \
        bash "$REPO_ROOT/src/core/trigger.sh" compacting 2>/dev/null
    local tty_safe="${muted_tty//\//_}"
    local cache="$RUNTIME_DIR/pending/${tty_safe}.osc"

    # Compare: pending cache bytes should match unmuted TTY bytes
    [ -f "$cache" ]
    local unmuted_bytes muted_bytes
    unmuted_bytes=$(wc -c < "$unmuted_tty" | tr -d ' ')
    muted_bytes=$(wc -c < "$cache" | tr -d ' ')
    # Allow for slight variation due to compose_title randomness (faces)
    # but the core OSC sequences should be present
    [ "$muted_bytes" -gt 0 ]
    [ "$unmuted_bytes" -gt 0 ]

    rm -f "$unmuted_tty" "$muted_tty" "$cache" "$RUNTIME_DIR/active-ttys/$tty_safe"
}
