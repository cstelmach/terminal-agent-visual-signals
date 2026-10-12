#!/usr/bin/env bats
# ==============================================================================
# Unit tests for src/core/mute-gate.sh
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_HOME=$(mktemp -d)
    TEST_RUNTIME=$(mktemp -d)
    mkdir -p "$TEST_HOME/.tavs"

    export HOME="$TEST_HOME"
    export TAVS_RUNTIME_DIR="$TEST_RUNTIME"
    export TTY_DEVICE="/dev/null"
    export TTY_SAFE="_dev_null"
    export _TAVS_SUPPRESS_OUTPUT=0

    source "$REPO_ROOT/src/core/mute-gate.sh"
    _tavs_resolve_runtime_dir
}

teardown() {
    rm -rf "$TEST_HOME" "$TEST_RUNTIME"
}

# --- Runtime Dir ---

@test "default runtime path is observed without creating the live directory" {
    unset TAVS_RUNTIME_DIR
    id() { printf '%s\n' "${TEST_RUNTIME##*/}"; }
    mkdir() { printf '%s\n' "$*" >> "$TEST_HOME/mkdir-calls"; }
    _tavs_resolve_runtime_dir
    [ "$TAVS_RUNTIME_DIR" = "/tmp/tavs-$(id -u)" ]
    [ -s "$TEST_HOME/mkdir-calls" ]
}

@test "runtime dir respects TAVS_RUNTIME_DIR if already set" {
    export TAVS_RUNTIME_DIR="$TEST_RUNTIME"
    _tavs_resolve_runtime_dir
    [ "$TAVS_RUNTIME_DIR" = "$TEST_RUNTIME" ]
}

# --- Active TTY Registry ---

@test "register_active_tty creates touch file" {
    register_active_tty
    [ -f "$TAVS_RUNTIME_DIR/active-ttys/$TTY_SAFE" ]
}

@test "register_active_tty is no-op when TTY_SAFE is empty" {
    TTY_SAFE=""
    register_active_tty
    local count
    count=$(find "$TAVS_RUNTIME_DIR/active-ttys" -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" = "0" ]
}

@test "clean_active_tty_registry removes old entries" {
    touch "$TAVS_RUNTIME_DIR/active-ttys/old_entry"
    # Make it look old (25 hours ago)
    touch -t "$(date -v-25H +%Y%m%d%H%M 2>/dev/null || date -d '25 hours ago' +%Y%m%d%H%M)" \
        "$TAVS_RUNTIME_DIR/active-ttys/old_entry" 2>/dev/null || skip "date manipulation not available"
    clean_active_tty_registry
    [ ! -f "$TAVS_RUNTIME_DIR/active-ttys/old_entry" ]
}

@test "clean_active_tty_registry keeps recent entries" {
    touch "$TAVS_RUNTIME_DIR/active-ttys/recent_entry"
    clean_active_tty_registry
    [ -f "$TAVS_RUNTIME_DIR/active-ttys/recent_entry" ]
}

# --- Mute State Check (full, for idle worker) ---

@test "check_mute_state returns 1 when mute.state missing" {
    _TAVS_SUPPRESS_OUTPUT=0
    run _tavs_check_mute_state
    [ "$status" -eq 1 ]
    [ "$_TAVS_SUPPRESS_OUTPUT" = "0" ]
}

@test "check_mute_state returns 0 and sets flag when valid mute" {
    local now
    now=$(date +%s)
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="test"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID=""
SCHEMA_VERSION="1"
EOF
    _tavs_check_mute_state
    [ "$_TAVS_SUPPRESS_OUTPUT" = "1" ]
}

@test "check_mute_state returns 1 when MUTED=false" {
    local now
    now=$(date +%s)
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="false"
WRITTEN_EPOCH="$now"
APP_PID=""
SCHEMA_VERSION="1"
EOF
    _TAVS_SUPPRESS_OUTPUT=0
    run _tavs_check_mute_state
    [ "$status" -eq 1 ]
}

@test "check_mute_state returns 1 when heartbeat is stale (>120s)" {
    local stale
    stale=$(( $(date +%s) - 200 ))
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$stale"
APP_PID=""
SCHEMA_VERSION="1"
EOF
    _TAVS_SUPPRESS_OUTPUT=0
    run _tavs_check_mute_state
    [ "$status" -eq 1 ]
}

@test "check_mute_state returns 1 when UNTIL_EPOCH is in the past" {
    local now past
    now=$(date +%s)
    past=$(( now - 60 ))
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
UNTIL_EPOCH="$past"
WRITTEN_EPOCH="$now"
APP_PID=""
SCHEMA_VERSION="1"
EOF
    _TAVS_SUPPRESS_OUTPUT=0
    run _tavs_check_mute_state
    [ "$status" -eq 1 ]
}

@test "check_mute_state returns 1 when APP_PID is dead" {
    local now
    now=$(date +%s)
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="99999"
SCHEMA_VERSION="1"
EOF
    _TAVS_SUPPRESS_OUTPUT=0
    run _tavs_check_mute_state
    [ "$status" -eq 1 ]
}

@test "check_mute_state returns 1 when SCHEMA_VERSION is unknown" {
    local now
    now=$(date +%s)
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID=""
SCHEMA_VERSION="99"
EOF
    _TAVS_SUPPRESS_OUTPUT=0
    run _tavs_check_mute_state
    [ "$status" -eq 1 ]
}

# --- Pending Buffer Lifecycle ---

@test "buffer_open creates temp file when suppressed" {
    _TAVS_SUPPRESS_OUTPUT=1
    TTY_SAFE="_dev_ttys001"
    _tavs_mute_buffer_open
    [ -n "$_TAVS_PENDING_BUFFER" ]
    [ -f "$_TAVS_PENDING_BUFFER" ]
    rm -f "$_TAVS_PENDING_BUFFER"
}

@test "buffer_open is no-op when not suppressed" {
    _TAVS_SUPPRESS_OUTPUT=0
    _tavs_mute_buffer_open
    [ -z "${_TAVS_PENDING_BUFFER:-}" ]
}

@test "buffer_close atomic-renames to pending cache" {
    _TAVS_SUPPRESS_OUTPUT=1
    TTY_SAFE="_dev_ttys001"
    _tavs_mute_buffer_open
    echo -n "test-bytes" >> "$_TAVS_PENDING_BUFFER"
    _tavs_mute_buffer_close
    [ -f "$TAVS_RUNTIME_DIR/pending/_dev_ttys001.osc" ]
    local content
    content=$(cat "$TAVS_RUNTIME_DIR/pending/_dev_ttys001.osc")
    [ "$content" = "test-bytes" ]
    [ -z "${_TAVS_PENDING_BUFFER:-}" ]
}

@test "buffer_close removes empty buffer (no rename)" {
    _TAVS_SUPPRESS_OUTPUT=1
    TTY_SAFE="_dev_ttys001"
    _tavs_mute_buffer_open
    local buf="$_TAVS_PENDING_BUFFER"
    _tavs_mute_buffer_close
    [ ! -f "$buf" ]
    [ ! -f "$TAVS_RUNTIME_DIR/pending/_dev_ttys001.osc" ]
}

@test "buffer_close is no-op when no buffer open" {
    unset _TAVS_PENDING_BUFFER
    _tavs_mute_buffer_close
    # Should not error
}
