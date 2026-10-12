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
    [[ -n "${TAVS_TEST_ROOT:-}" ]] || return 1
    TEST_HOME=$(mktemp -d "$TAVS_TEST_ROOT/liveness.XXXXXX")
    export TAVS_TMP_DIR="$TEST_HOME/state" _TAVS_TMP_DIR="$TEST_HOME/state"
    mkdir -p "$TEST_HOME/.tavs"
    # Isolated runtime dir: a real hard lock in the live /tmp/tavs-$UID would
    # suppress the fail-open cases this file asserts.
    export TAVS_RUNTIME_DIR="$TEST_HOME/runtime"
    mkdir -p "$TAVS_RUNTIME_DIR"
    export TAVS_TEST_HELPER_BIN="$TEST_HOME/helper" LIVENESS_CORE="$REPO_ROOT/src/core"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
case "$1" in
    --validate-config)
        if [[ "$2" == --managed-output-capabilities ]]; then printf 'tavs-managed-output-schema=1\n'
        else printf 'tavs-organizer-schema=1\n'; fi ;;
    --organizer-context) printf 'fixture-context\n' ;;
    --organizer-observe) exit 0 ;;
    --managed-render)
        [[ "$4" == "$TAVS_TEST_ROOT/"* ]] || exit 1
        fields=()
        while IFS= read -r -d '' value; do fields+=("$value"); done
        [[ "${#fields[@]}" == 23 ]] || exit 1
        source "$LIVENESS_CORE/mute-gate.sh"
        if _tavs_check_mute_state; then printf 'restricted\n'; exit 0; fi
        printf '\033]11;%s\033\\' "${fields[0]}" > "$4"
        printf 'rendered\n' ;;
    *) exit 1 ;;
esac
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
}

_run_trigger() {
    local tty_file
    tty_file=$(mktemp "$TEST_HOME/tty.XXXXXX")
    TTY_DEVICE="$tty_file" HOME="$TEST_HOME" CFFIXED_USER_HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null
    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    echo "$bytes"
}

@test "stale heartbeat (>120s) treated as unmuted" {
    local stale
    stale=$(( $(date +%s) - 200 ))
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$stale"
APP_PID="$$"
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
REASON="quiet_period"
UNTIL_EPOCH="$past"
WRITTEN_EPOCH="$now"
APP_PID="$$"
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
REASON="quiet_period"
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
APP_PID="$$"
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
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$$"
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
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$parent_pid"
SCHEMA_VERSION="1"
EOF
    local tty_file
    tty_file=$(mktemp "$TEST_HOME/tty.XXXXXX")
    TTY_DEVICE="$tty_file" HOME="$TEST_HOME" CFFIXED_USER_HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" \
        bash "$REPO_ROOT/src/core/trigger.sh" processing 2>/dev/null
    local bytes
    bytes=$(wc -c < "$tty_file" | tr -d ' ')
    [ "$bytes" -eq 0 ]
}
