#!/usr/bin/env bats
# ==============================================================================
# Unit tests for src/core/mute-gate.sh
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    [[ -n "${TAVS_TEST_ROOT:-}" ]] || return 1
    TEST_HOME=$(mktemp -d "$TAVS_TEST_ROOT/mute-home.XXXXXX")
    TEST_RUNTIME=$(mktemp -d "$TAVS_TEST_ROOT/mute-runtime.XXXXXX")
    mkdir -p "$TEST_HOME/.tavs"

    export HOME="$TEST_HOME"
    export TAVS_RUNTIME_DIR="$TEST_RUNTIME"
    export TTY_DEVICE="/dev/null"
    export TTY_SAFE="_dev_null"
    export _TAVS_SUPPRESS_OUTPUT=0

    source "$REPO_ROOT/src/core/mute-gate.sh"
    _tavs_resolve_runtime_dir
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

@test "clean_active_tty_registry retains old entries without owner-exit evidence" {
    touch "$TAVS_RUNTIME_DIR/active-ttys/old_entry"
    # Make it look old (25 hours ago)
    touch -t "$(date -v-25H +%Y%m%d%H%M 2>/dev/null || date -d '25 hours ago' +%Y%m%d%H%M)" \
        "$TAVS_RUNTIME_DIR/active-ttys/old_entry" 2>/dev/null || skip "date manipulation not available"
    clean_active_tty_registry
    [ -f "$TAVS_RUNTIME_DIR/active-ttys/old_entry" ]
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
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$$"
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
APP_PID="$$"
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
APP_PID="$$"
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
APP_PID="$$"
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
APP_PID="$$"
SCHEMA_VERSION="99"
EOF
    _TAVS_SUPPRESS_OUTPUT=0
    run _tavs_check_mute_state
    [ "$status" -eq 1 ]
}

# --- Pending Buffer Lifecycle ---

@test "legacy absent schema matches Swift while explicit invalid schemas are rejected" {
    local schema now
    now=$(date +%s)
    for schema in absent '' 99; do
        cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$$"
EOF
        if [[ "$schema" != absent ]]; then
            printf 'SCHEMA_VERSION="%s"\n' "$schema" >> "$TEST_HOME/.tavs/mute.state"
        fi
        run _tavs_check_mute_state
        if [[ "$schema" == absent ]]; then
            [ "$status" -eq 0 ]
        else
            [ "$status" -eq 1 ]
        fi
    done
}

@test "soft mute rejects missing pid or heartbeat and future heartbeat" {
    local now=$(date +%s) bad
    for bad in missing_pid missing_written future_written zero_written invalid_until; do
        cat > "$TEST_HOME/.tavs/mute.state" <<STATE
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$$"
SCHEMA_VERSION="1"
STATE
        case "$bad" in
            missing_pid) sed -i '' '/APP_PID=/d' "$TEST_HOME/.tavs/mute.state" ;;
            missing_written) sed -i '' '/WRITTEN_EPOCH=/d' "$TEST_HOME/.tavs/mute.state" ;;
            future_written) sed -i '' "s/WRITTEN_EPOCH=.*/WRITTEN_EPOCH=\"$((now+100))\"/" "$TEST_HOME/.tavs/mute.state" ;;
            zero_written) sed -i '' 's/WRITTEN_EPOCH=.*/WRITTEN_EPOCH="0"/' "$TEST_HOME/.tavs/mute.state" ;;
            invalid_until) sed -i '' 's/UNTIL_EPOCH=.*/UNTIL_EPOCH="INVALID"/' "$TEST_HOME/.tavs/mute.state" ;;
        esac
        run _tavs_check_mute_state
        [ "$status" -eq 1 ] || { printf 'invalid case accepted: %s\n' "$bad" >&2; return 1; }
    done
}

@test "buffer_open cannot create opaque cache while suppressed" {
    _TAVS_SUPPRESS_OUTPUT=1
    TTY_SAFE="_dev_ttys001"
    _tavs_mute_buffer_open
    [ -z "${_TAVS_PENDING_BUFFER:-}" ]
    [ -z "$(find "$TAVS_RUNTIME_DIR/pending" -type f -print)" ]
}

@test "buffer_open is no-op when not suppressed" {
    _TAVS_SUPPRESS_OUTPUT=0
    _tavs_mute_buffer_open
    [ -z "${_TAVS_PENDING_BUFFER:-}" ]
}

@test "buffer_close cannot republish an inherited opaque buffer" {
    _TAVS_SUPPRESS_OUTPUT=1
    TTY_SAFE="_dev_ttys001"
    _TAVS_PENDING_BUFFER="$TEST_RUNTIME/old-buffer"
    printf OLD_TITLE > "$_TAVS_PENDING_BUFFER"
    _tavs_mute_buffer_close
    [ ! -f "$TAVS_RUNTIME_DIR/pending/_dev_ttys001.osc" ]
    [ -z "${_TAVS_PENDING_BUFFER:-}" ]
}

@test "buffer_close cannot create a pending file from an empty buffer" {
    _TAVS_SUPPRESS_OUTPUT=1
    TTY_SAFE="_dev_ttys001"
    _tavs_mute_buffer_open
    _tavs_mute_buffer_close
    [ -z "${_TAVS_PENDING_BUFFER:-}" ]
    [ ! -f "$TAVS_RUNTIME_DIR/pending/_dev_ttys001.osc" ]
}

@test "buffer_close is no-op when no buffer open" {
    unset _TAVS_PENDING_BUFFER
    _tavs_mute_buffer_close
    # Should not error
}
