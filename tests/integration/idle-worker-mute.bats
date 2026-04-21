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
    TEST_HOME=$(mktemp -d)
    RUNTIME_DIR="/tmp/tavs-$(id -u)"
    mkdir -p "$TEST_HOME/.tavs"
}

teardown() {
    rm -rf "$TEST_HOME"
    # Clean up worker processes and temp files
    [[ -n "${_WORKER_PID:-}" ]] && kill "$_WORKER_PID" 2>/dev/null || true
    wait "$_WORKER_PID" 2>/dev/null || true
}

_create_mute_state() {
    local home="$1"
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

_write_worker_script() {
    local script_path="$1"
    cat > "$script_path" <<'SCRIPT'
#!/bin/bash
export HOME="$1"
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

UNIFIED_CHECK_INTERVAL=0.3
MAX_TIMER_RUNTIME=30

unified_timer_worker "$TTY_DEVICE"
SCRIPT
    chmod +x "$script_path"
}

@test "idle worker uses emit_osc (not direct fd writes)" {
    local fd3_count
    fd3_count=$(grep -c '>&3' "$REPO_ROOT/src/core/idle-worker-background.sh" || true)
    [ "$fd3_count" -eq 0 ]
}

@test "idle worker calls _tavs_check_mute_state" {
    grep -q '_tavs_check_mute_state' "$REPO_ROOT/src/core/idle-worker-background.sh"
}

@test "idle worker opens/closes pending buffer per state transition" {
    grep -q '_tavs_mute_buffer_open' "$REPO_ROOT/src/core/idle-worker-background.sh"
    grep -q '_tavs_mute_buffer_close' "$REPO_ROOT/src/core/idle-worker-background.sh"
}

@test "idle worker muted: TTY gets no bytes during muted tick" {
    _create_mute_state "$TEST_HOME"
    local tty_file
    tty_file=$(mktemp)

    local worker_script
    worker_script=$(mktemp)
    _write_worker_script "$worker_script"

    # Run worker in background, wait for at least 2 ticks, then kill
    bash "$worker_script" "$TEST_HOME" "$tty_file" "$REPO_ROOT/src/core" 2>/dev/null &
    _WORKER_PID=$!

    sleep 2

    kill "$_WORKER_PID" 2>/dev/null || true
    wait "$_WORKER_PID" 2>/dev/null || true

    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    rm -f "$worker_script" "$tty_file"

    [ "$bytes" -eq 0 ]
}

@test "idle worker muted: pending cache contains captured bytes" {
    _create_mute_state "$TEST_HOME"
    local tty_file
    tty_file=$(mktemp)

    local worker_script
    worker_script=$(mktemp)
    _write_worker_script "$worker_script"

    bash "$worker_script" "$TEST_HOME" "$tty_file" "$REPO_ROOT/src/core" 2>/dev/null &
    _WORKER_PID=$!

    # Wait for worker to process at least 1 state transition
    sleep 3

    kill "$_WORKER_PID" 2>/dev/null || true
    wait "$_WORKER_PID" 2>/dev/null || true

    local tty_safe="${tty_file//\//_}"
    local cache="$RUNTIME_DIR/pending/${tty_safe}.osc"

    local result="false"
    [ -f "$cache" ] && result="true"

    # Clean up
    rm -f "$worker_script" "$tty_file" "$cache" "$RUNTIME_DIR/active-ttys/$tty_safe" 2>/dev/null

    [ "$result" = "true" ]
}
