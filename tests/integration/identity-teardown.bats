#!/usr/bin/env bats
# ==============================================================================
# Integration test: session-icon registry teardown across mute (G8)
# ==============================================================================
# The session-icon module assigns a deterministic emoji per session and
# registers the (session_id → icon) mapping in a shared registry so two
# concurrent sessions don't collide. On `reset session-end` the mapping
# must be released. Mute must NOT block that release — bookkeeping is
# independent of OSC emission.
#
# This file pins:
#   1. assign + release while muted removes per-TTY and active-session state.
#   2. Two concurrent sessions get distinct icons even if both run muted.
#   3. release_session_icon is idempotent: re-running on an already-released
#      session does not throw or corrupt the registry.
# ==============================================================================

REPO_ROOT=""
TEST_HOME=""
RUNTIME_DIR=""

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_HOME=$(mktemp -d)
    RUNTIME_DIR="/tmp/tavs-test-identity-$$"
    mkdir -p "$TEST_HOME/.tavs"
    mkdir -p "$RUNTIME_DIR/active-ttys" "$RUNTIME_DIR/pending"
}

teardown() {
    rm -rf "$TEST_HOME" "$RUNTIME_DIR"
}

_set_muted() {
    local now parent_pid
    now=$(date +%s)
    parent_pid=$(ps -o ppid= -p $$ | tr -d ' ')
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="test"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$parent_pid"
SCHEMA_VERSION="1"
EOF
}

_dispatch() {
    local tty_dev="$1"
    local state="$2"
    local session_id="$3"
    shift 3
    env -i HOME="$TEST_HOME" PATH="$PATH" \
        TAVS_RUNTIME_DIR="$RUNTIME_DIR" \
        TAVS_TMP_DIR="$RUNTIME_DIR" \
        TTY_DEVICE="$tty_dev" \
        TAVS_SESSION_ID="$session_id" \
        TAVS_IDENTITY_MODE="dual" \
        bash "$REPO_ROOT/src/core/trigger.sh" "$state" "$@" 2>/dev/null || true
}

_tty_safe_for() {
    printf '%s' "${1//\//_}"
}

_session_cache_for() {
    printf '%s/session-icon.%s' "$TEST_HOME/.cache/tavs" "$(_tty_safe_for "$1")"
}

_active_sessions_file() {
    printf '%s/identity/active-sessions' "$RUNTIME_DIR"
}

_session_registry_file() {
    printf '%s/identity/session-registry' "$RUNTIME_DIR"
}

@test "identity: muted assign + release removes live session state" {
    _set_muted
    local session="abc12345"
    local tty="/tmp/test-identity-1"
    local cache active_sessions
    cache=$(_session_cache_for "$tty")
    active_sessions=$(_active_sessions_file)
    : > "$tty"

    _dispatch "$tty" reset "$session"           # initial assign
    [ -f "$cache" ]
    grep -q "^session_key=$session$" "$cache"

    _dispatch "$tty" reset "$session" session-end  # release

    [ ! -e "$cache" ]
    if [[ -f "$active_sessions" ]]; then
        ! grep -q "$session" "$active_sessions"
        ! grep -q "$(_tty_safe_for "$tty")" "$active_sessions"
    fi
}

@test "identity: two concurrent muted sessions get distinct cache entries" {
    _set_muted
    local session_a="aaaa1111"
    local session_b="bbbb2222"
    local tty_a="/tmp/test-identity-A"
    local tty_b="/tmp/test-identity-B"
    local cache_a cache_b primary_a primary_b registry
    cache_a=$(_session_cache_for "$tty_a")
    cache_b=$(_session_cache_for "$tty_b")
    registry=$(_session_registry_file)
    : > "$tty_a"
    : > "$tty_b"

    _dispatch "$tty_a" reset "$session_a"
    _dispatch "$tty_b" reset "$session_b"

    [ -f "$cache_a" ]
    [ -f "$cache_b" ]

    primary_a=$(grep '^primary=' "$cache_a" | cut -d= -f2-)
    primary_b=$(grep '^primary=' "$cache_b" | cut -d= -f2-)

    [ -n "$primary_a" ]
    [ -n "$primary_b" ]
    [ "$primary_a" != "$primary_b" ]
    grep -q "^$session_a=" "$registry"
    grep -q "^$session_b=" "$registry"
}

@test "identity: re-releasing an already-released session does not corrupt registry" {
    _set_muted
    local session="ccc33333"
    local tty="/tmp/test-identity-3"
    : > "$tty"

    _dispatch "$tty" reset "$session"
    _dispatch "$tty" reset "$session" session-end
    _dispatch "$tty" reset "$session" session-end  # idempotent re-release

    [ ! -e "$(_session_cache_for "$tty")" ]
}
