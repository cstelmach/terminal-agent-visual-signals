#!/usr/bin/env bats
# ==============================================================================
# Integration: fail-closed lock gate through the full trigger.sh dispatch
# ==============================================================================
# The defining property (spec D3): an unexpired lock suppresses OSC output
# even when every mute-side liveness check fails (dead APP_PID, stale
# heartbeat, absent mute.state). Expiry always wins; a grant suspends.
# Suppressed dispatches buffer their bytes into pending/<tty>.osc.
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)
    ISO_HOME="$TEST_DIR/home"
    RUNTIME="$TEST_DIR/runtime"
    TTY_FILE="$TEST_DIR/tty-capture"
    mkdir -p "$ISO_HOME/.tavs" "$RUNTIME"
    : > "$TTY_FILE"
    NOW=$(date +%s)
}

teardown() {
    rm -rf "$TEST_DIR"
}

write_lock() {
    # write_lock <lock_until> <unlock_until>
    cat > "$RUNTIME/lock.state" <<EOF
LOCKED="true"
REASON="manual"
LOCK_UNTIL_EPOCH="$1"
UNLOCK_UNTIL_EPOCH="$2"
WRITTEN_EPOCH="$NOW"
LOCK_BG="#3A3A3A"
LOCK_FG=""
SCHEMA_VERSION="1"
EOF
}

write_dead_pid_mute() {
    cat > "$ISO_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$NOW"
APP_PID="999999"
SCHEMA_VERSION="1"
EOF
}

write_stale_heartbeat_mute() {
    cat > "$ISO_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(( NOW - 600 ))"
APP_PID="$$"
SCHEMA_VERSION="1"
EOF
}

run_trigger() {
    env -i HOME="$ISO_HOME" PATH="$PATH" TTY_DEVICE="$TTY_FILE" \
        TAVS_RUNTIME_DIR="$RUNTIME" \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null || true
}

pending_file_count() {
    find "$RUNTIME/pending" -type f -name '*.osc' 2>/dev/null | wc -l | tr -d ' '
}

@test "unexpired lock suppresses with NO mute.state at all" {
    write_lock $(( NOW + 300 )) 0
    run_trigger
    [ ! -s "$TTY_FILE" ]
    [ "$(pending_file_count)" -ge 1 ]
}

@test "unexpired lock suppresses despite dead APP_PID (fail-closed core)" {
    write_lock $(( NOW + 300 )) 0
    write_dead_pid_mute
    run_trigger
    [ ! -s "$TTY_FILE" ]
    [ "$(pending_file_count)" -ge 1 ]
}

@test "unexpired lock suppresses despite stale heartbeat" {
    write_lock $(( NOW + 300 )) 0
    write_stale_heartbeat_mute
    run_trigger
    [ ! -s "$TTY_FILE" ]
}

@test "expired lock releases (bytes reach the TTY)" {
    write_lock $(( NOW - 10 )) 0
    run_trigger
    [ -s "$TTY_FILE" ]
}

@test "active grant releases the lock" {
    write_lock $(( NOW + 300 )) $(( NOW + 120 ))
    run_trigger
    [ -s "$TTY_FILE" ]
}

@test "expired grant re-locks" {
    write_lock $(( NOW + 300 )) $(( NOW - 5 ))
    run_trigger
    [ ! -s "$TTY_FILE" ]
}

@test "malformed LOCK_UNTIL releases (no indefinite locks, D3)" {
    cat > "$RUNTIME/lock.state" <<EOF
LOCKED="true"
LOCK_UNTIL_EPOCH="whenever"
SCHEMA_VERSION="1"
EOF
    run_trigger
    [ -s "$TTY_FILE" ]
}

@test "dead-PID mute WITHOUT a lock stays fail-open (regression guard)" {
    write_dead_pid_mute
    run_trigger
    [ -s "$TTY_FILE" ]
}

@test "TAVS_STATUS=false wins over an unexpired lock for agent signals" {
    write_lock $(( NOW + 300 )) 0
    env -i HOME="$ISO_HOME" PATH="$PATH" TTY_DEVICE="$TTY_FILE" \
        TAVS_RUNTIME_DIR="$RUNTIME" TAVS_STATUS=false \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null || true
    [ ! -s "$TTY_FILE" ]
    [ "$(pending_file_count)" -eq 0 ]
}

@test "idle-worker check honors the lock (_tavs_check_mute_state)" {
    write_lock $(( NOW + 300 )) 0
    export HOME="$ISO_HOME"
    export TAVS_RUNTIME_DIR="$RUNTIME"
    source "$REPO_ROOT/src/core/mute-gate.sh"
    _tavs_check_mute_state
    [ "$_TAVS_SUPPRESS_OUTPUT" = "1" ]
}

@test "idle-worker check releases on expired lock without mute.state" {
    write_lock $(( NOW - 10 )) 0
    export HOME="$ISO_HOME"
    export TAVS_RUNTIME_DIR="$RUNTIME"
    source "$REPO_ROOT/src/core/mute-gate.sh"
    if _tavs_check_mute_state; then
        false
    fi
    [ "$_TAVS_SUPPRESS_OUTPUT" = "0" ]
}
