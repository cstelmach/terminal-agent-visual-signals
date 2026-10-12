#!/usr/bin/env bats
# ==============================================================================
# Integration test: one current typed render, with no historical OSC cache.
# Safe fixture helpers capture regular files without weakening native fd validation.
# ==============================================================================

REPO_ROOT=""
TEST_HOME=""
RUNTIME_DIR=""

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" ]] || return 1
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_HOME=$(mktemp -d "$TAVS_TEST_ROOT/render-fixture.XXXXXX")
    RUNTIME_DIR="$TEST_HOME/runtime"
    export HOME="$TEST_HOME" CFFIXED_USER_HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME"
    export TAVS_RUNTIME_DIR="$RUNTIME_DIR" TAVS_TMP_DIR="$TEST_HOME/state"
    export _TAVS_TMP_DIR="$TAVS_TMP_DIR" TTY_DEVICE="$TEST_HOME/tty"
    export TAVS_TEST_HELPER_BIN="$TEST_HOME/helper" RENDER_TEST_CORE="$REPO_ROOT/src/core"
    export RENDER_TEST_CALLS="$TEST_HOME/calls" RENDER_TEST_FIELDS="$TEST_HOME/fields"
    mkdir -p "$TEST_HOME/.tavs" "$RUNTIME_DIR" "$TAVS_TMP_DIR"
    : > "$TTY_DEVICE"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
case "$1" in
    --validate-config)
        if [[ "$2" == --managed-output-capabilities ]]; then printf 'tavs-managed-output-schema=1\n'
        else printf 'tavs-organizer-schema=1\n'; fi ;;
    --organizer-context) printf 'fixture-context\n' ;;
    --organizer-observe) exit 0 ;;
    --managed-render)
        [[ "$4" == "$TAVS_TEST_ROOT/"* && "$5" == fixture-context ]] || exit 1
        fields=()
        while IFS= read -r -d '' value; do fields+=("$value"); done
        [[ "${#fields[@]}" == 23 ]] || exit 1
        printf 'render\n' >> "$RENDER_TEST_CALLS"
        printf '%s\0' "${fields[@]}" > "$RENDER_TEST_FIELDS"
        source "$RENDER_TEST_CORE/mute-gate.sh"
        if _tavs_check_mute_state; then printf 'restricted\n'; exit 0; fi
        if [[ "${fields[0]}" == reset ]]; then printf '\033]111\033\\' > "$4"
        elif [[ -n "${fields[0]}" ]]; then printf '\033]11;%s\033\\' "${fields[0]}" > "$4"; fi
        if [[ "${fields[18]}" == 1 ]]; then printf '\033]0;%s\033\\' "${fields[19]}" >> "$4"; fi
        printf 'rendered\n' ;;
    *) exit 1 ;;
esac
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
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
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$parent_pid"
SCHEMA_VERSION="1"
EOF
}

@test "processing: one managed render reaches the private fixture TTY" {
    run bash "$REPO_ROOT/src/core/trigger.sh" processing
    [ "$status" -eq 0 ]
    [ -s "$TTY_DEVICE" ]
    [ "$(wc -l < "$RENDER_TEST_CALLS" | tr -d ' ')" -eq 1 ]
}

@test "processing: current fixture mute suppresses ordinary bytes" {
    _create_mute_state "$TEST_HOME"
    run bash "$REPO_ROOT/src/core/trigger.sh" processing
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
    [ -s "$RENDER_TEST_FIELDS" ]
}

@test "processing: muted render cannot create an opaque pending cache" {
    _create_mute_state "$TEST_HOME"
    run bash "$REPO_ROOT/src/core/trigger.sh" processing
    [ "$status" -eq 0 ]
    [ -z "$(find "$RUNTIME_DIR/pending" -type f -print)" ]
    [ "$(wc -l < "$RENDER_TEST_CALLS" | tr -d ' ')" -eq 1 ]
}

@test "reset: muted current render has no raw output or pending history" {
    _create_mute_state "$TEST_HOME"
    run bash "$REPO_ROOT/src/core/trigger.sh" reset
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
    [ -z "$(find "$RUNTIME_DIR/pending" -type f -print)" ]
}

@test "active-tty remains a candidate on managed dispatch" {
    run bash "$REPO_ROOT/src/core/trigger.sh" reset
    [ "$status" -eq 0 ]
    [ -f "$RUNTIME_DIR/active-ttys/${TTY_DEVICE//\//_}" ]
}

@test "muted invocation retains current typed request without retaining OSC bytes" {
    _create_mute_state "$TEST_HOME"
    run bash "$REPO_ROOT/src/core/trigger.sh" compacting
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
    python3 - "$RENDER_TEST_FIELDS" <<'CHECK'
import sys
parts=open(sys.argv[1],'rb').read().split(b'\0')
assert len(parts)==24 and parts[-1]==b'' and parts[0].startswith(b'#')
assert all(b'\x1b' not in part and b'\x07' not in part for part in parts[:-1])
CHECK
    [ -z "$(find "$RUNTIME_DIR/pending" -type f -print)" ]
}
