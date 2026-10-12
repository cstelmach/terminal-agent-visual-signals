#!/usr/bin/env bats
# ==============================================================================
# Integration test: idle worker mute suppression (SPEC T1.6)
# Verifies the worker routes OSC through emit_osc and respects mute state.
# ==============================================================================

REPO_ROOT=""
TEST_HOME=""
RUNTIME_DIR=""

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    [[ -n "${TAVS_TEST_ROOT:-}" ]] || return 1
    TEST_HOME=$(mktemp -d "$TAVS_TEST_ROOT/idle-mute.XXXXXX")
    RUNTIME_DIR="$TEST_HOME/runtime"
    export TAVS_RUNTIME_DIR="$RUNTIME_DIR"
    export TAVS_TMP_DIR="$TEST_HOME/state"
    export XDG_RUNTIME_DIR="$TEST_HOME/xdg"
    mkdir -p "$TEST_HOME/.tavs" "$TAVS_TMP_DIR" "$XDG_RUNTIME_DIR"
    export TAVS_TEST_HELPER_BIN="$TEST_HOME/helper" IDLE_TEST_CORE="$REPO_ROOT/src/core"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
case "$1" in
    --validate-config)
        if [[ "$2" == --managed-output-capabilities ]]; then printf 'tavs-managed-output-schema=1\n'
        else printf 'tavs-organizer-schema=1\n'; fi ;;
    --organizer-context) printf 'fixture-context\n' ;;
    --organizer-observe|--managed-check-context) exit 0 ;;
    --managed-background)
        [[ "$4" == "$TAVS_TEST_ROOT/"* && "$5" == fixture-context ]] || exit 1
        printf '%s\n' "$6" > "$TAVS_RUNTIME_DIR/fixture-background"
        source "$IDLE_TEST_CORE/mute-gate.sh"
        _tavs_check_mute_state && exit 0
        printf '\033]11;%s\033\\' "$6" > "$4" ;;
    --managed-forced-reset) exit 0 ;;
    *) exit 1 ;;
esac
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
}

teardown() {
    # Clean up worker processes and temp files
    [[ -n "${_WORKER_PID:-}" ]] && kill "$_WORKER_PID" 2>/dev/null || true
    [[ -n "${_WORKER_PID:-}" ]] && wait "$_WORKER_PID" 2>/dev/null || true
}

_create_mute_state() {
    local home="$1"
    local parent_pid
    parent_pid=$(ps -o ppid= -p $$ | tr -d ' ')
    local now
    now=$(date +%s)
    cat > "$home/.tavs/mute.state" <<EOF
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$parent_pid"
SCHEMA_VERSION="1"
EOF
}

_write_worker_script() {
    local script_path="$1"
    cat > "$script_path" <<'SCRIPT'
#!/bin/bash
export HOME="$1" CFFIXED_USER_HOME="$1" ZDOTDIR="$1"
export TTY_DEVICE="$2"
CORE_DIR="$3"

source "$CORE_DIR/mute-gate.sh"
source "$CORE_DIR/theme-config-loader.sh"
source "$CORE_DIR/session-state.sh"
source "$CORE_DIR/terminal-osc-sequences.sh"
source "$CORE_DIR/spinner.sh"
source "$CORE_DIR/palette-mode-helpers.sh"
source "$CORE_DIR/idle-worker-background.sh"
source "$CORE_DIR/terminal-detection.sh"
source "$CORE_DIR/backgrounds.sh"
source "$CORE_DIR/title-management.sh"
source "$CORE_DIR/subagent-counter.sh"
source "$CORE_DIR/session-icon.sh"
source "$CORE_DIR/dir-icon.sh"
source "$CORE_DIR/context-data.sh"

_tavs_mute_gate_init
_tavs_organizer_begin complete

UNIFIED_CHECK_INTERVAL=0.3
MAX_TIMER_RUNTIME=30

unified_timer_worker "$TTY_DEVICE"
SCRIPT
    chmod +x "$script_path"
}

@test "idle worker fixture paths stay beneath its private home" {
    [[ "$RUNTIME_DIR" == "$TEST_HOME/"* ]]
    [[ "$TAVS_TMP_DIR" == "$TEST_HOME/"* ]]
    [[ "$XDG_RUNTIME_DIR" == "$TEST_HOME/"* ]]
}

@test "idle worker uses emit_osc (not direct fd writes)" {
    local fd3_count
    fd3_count=$(grep -c '>&3' "$REPO_ROOT/src/core/idle-worker-background.sh" || true)
    [ "$fd3_count" -eq 0 ]
}

@test "idle worker calls _tavs_check_mute_state" {
    grep -q '_tavs_check_mute_state' "$REPO_ROOT/src/core/idle-worker-background.sh"
}

@test "idle worker cannot open or republish historical pending buffers" {
    ! grep -q '_tavs_mute_buffer_open' "$REPO_ROOT/src/core/idle-worker-background.sh"
    ! grep -q '_tavs_mute_buffer_close' "$REPO_ROOT/src/core/idle-worker-background.sh"
}

@test "idle worker muted: TTY gets no bytes during muted tick" {
    _create_mute_state "$TEST_HOME"
    local tty_file
    tty_file=$(mktemp "$TEST_HOME/tty.XXXXXX")

    local worker_script
    worker_script=$(mktemp "$TEST_HOME/worker.XXXXXX")
    _write_worker_script "$worker_script"

    # Run worker in background, wait for at least 2 ticks, then kill
    bash "$worker_script" "$TEST_HOME" "$tty_file" "$REPO_ROOT/src/core" 2>/dev/null &
    _WORKER_PID=$!

    sleep 2

    kill "$_WORKER_PID" 2>/dev/null || true
    wait "$_WORKER_PID" 2>/dev/null || true
    unset _WORKER_PID

    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    [ "$bytes" -eq 0 ]
}

@test "idle worker muted: typed current intent persists without pending bytes" {
    _create_mute_state "$TEST_HOME"
    local tty_file
    tty_file=$(mktemp "$TEST_HOME/tty.XXXXXX")

    local worker_script
    worker_script=$(mktemp "$TEST_HOME/worker.XXXXXX")
    _write_worker_script "$worker_script"

    bash "$worker_script" "$TEST_HOME" "$tty_file" "$REPO_ROOT/src/core" 2>/dev/null &
    _WORKER_PID=$!

    # Wait for worker to process at least 1 state transition
    sleep 3

    kill "$_WORKER_PID" 2>/dev/null || true
    wait "$_WORKER_PID" 2>/dev/null || true
    unset _WORKER_PID

    local tty_safe="${tty_file//\//_}"
    local cache="$RUNTIME_DIR/pending/${tty_safe}.osc"

    [ ! -f "$cache" ]
    [ -s "$RUNTIME_DIR/fixture-background" ]
    [ ! -s "$tty_file" ]
}
