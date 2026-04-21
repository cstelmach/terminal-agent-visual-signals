#!/usr/bin/env bats
# ==============================================================================
# Integration test: mute.state liveness validation
# Tests that stale heartbeat, expired epoch, and dead PID all result in
# unmuted behavior (SPEC D23: "Absence means not active").
# ==============================================================================

REPO_ROOT=""
TEST_HOME=""

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_HOME=$(mktemp -d)
    mkdir -p "$TEST_HOME/.tavs"
}

teardown() {
    rm -rf "$TEST_HOME"
    local runtime="/tmp/tavs-$(id -u)"
    rm -f "$runtime"/pending/_var_folders_*.osc 2>/dev/null
    rm -f "$runtime"/active-ttys/_var_folders_* 2>/dev/null
}

_run_trigger() {
    local tty_file
    tty_file=$(mktemp)
    TTY_DEVICE="$tty_file" HOME="$TEST_HOME" PATH="$PATH" \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null
    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    rm -f "$tty_file"
    echo "$bytes"
}

@test "stale heartbeat (>120s) treated as unmuted" {
    local stale
    stale=$(( $(date +%s) - 200 ))
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="test"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$stale"
APP_PID=""
SCHEMA_VERSION="1"
EOF
    local bytes
    bytes=$(_run_trigger)
    [ "$bytes" -gt 0 ]
}

@test "expired UNTIL_EPOCH treated as unmuted" {
    local now past
    now=$(date +%s)
    past=$(( now - 60 ))
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="test"
UNTIL_EPOCH="$past"
WRITTEN_EPOCH="$now"
APP_PID=""
SCHEMA_VERSION="1"
EOF
    local bytes
    bytes=$(_run_trigger)
    [ "$bytes" -gt 0 ]
}

@test "dead APP_PID treated as unmuted" {
    local now
    now=$(date +%s)
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="test"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="99999"
SCHEMA_VERSION="1"
EOF
    local bytes
    bytes=$(_run_trigger)
    [ "$bytes" -gt 0 ]
}

@test "MUTED=false treated as unmuted" {
    local now
    now=$(date +%s)
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="false"
REASON=""
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID=""
SCHEMA_VERSION="1"
EOF
    local bytes
    bytes=$(_run_trigger)
    [ "$bytes" -gt 0 ]
}

@test "missing mute.state treated as unmuted" {
    # No mute.state file at all
    local bytes
    bytes=$(_run_trigger)
    [ "$bytes" -gt 0 ]
}

@test "unknown SCHEMA_VERSION treated as unmuted" {
    local now
    now=$(date +%s)
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="test"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID=""
SCHEMA_VERSION="99"
EOF
    local bytes
    bytes=$(_run_trigger)
    [ "$bytes" -gt 0 ]
}

@test "valid mute.state with fresh heartbeat suppresses output" {
    local parent_pid now
    parent_pid=$(ps -o ppid= -p $$ | tr -d ' ')
    now=$(date +%s)
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="test"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$parent_pid"
SCHEMA_VERSION="1"
EOF
    local tty_file
    tty_file=$(mktemp)
    TTY_DEVICE="$tty_file" HOME="$TEST_HOME" PATH="$PATH" \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null
    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    rm -f "$tty_file"
    [ "$bytes" -eq 0 ]
}
