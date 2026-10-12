#!/usr/bin/env bats
# ==============================================================================
# Integration test: pending-cache replay priority (SPEC D12 / G3)
# ==============================================================================
# Each TTY's pending cache holds the LATEST OSC bytes from the most recent
# hook firing. On unmute, the broadcaster replays those bytes verbatim. The
# contract this file pins:
#
#   1. Latest-hook-wins per TTY: a sequence of muted hooks against the same
#      TTY produces a single pending file containing the LAST hook's bytes.
#      Ordering is temporal after the existing state grace period; there is no merge,
#      no preference for "permission" over "processing", and no accumulation.
#
#   2. Per-TTY isolation: pending caches for distinct TTYs do not contaminate
#      each other. TTY A's processing-paint stays in TTY A's pending file
#      even when TTY B fires a different state.
#
#   3. Replay restores a precise observable state, not an aggregation.
# ==============================================================================

REPO_ROOT=""
TEST_HOME=""
RUNTIME_DIR=""

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_HOME=$(mktemp -d)
    RUNTIME_DIR="$TEST_HOME/runtime"
    export TAVS_TMP_DIR="$TEST_HOME/state"
    export XDG_RUNTIME_DIR="$TEST_HOME/xdg"
    mkdir -p "$TEST_HOME/.tavs"
    mkdir -p "$TAVS_TMP_DIR" "$XDG_RUNTIME_DIR"
    mkdir -p "$RUNTIME_DIR/active-ttys" "$RUNTIME_DIR/pending"

    # Pre-mute the trigger so emit_osc routes to pending/.
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
    cat > "$TEST_HOME/.tavs/user.conf" <<'EOF'
THEME_MODE="static"
FORCE_MODE="dark"
ENABLE_MODE_AWARE_PROCESSING="false"
CLAUDE_DARK_PROCESSING="#112233"
CLAUDE_DARK_PERMISSION="#445566"
EOF
}

teardown() {
    rm -rf "$TEST_HOME" "$RUNTIME_DIR"
}

# Run a single trigger.sh dispatch with the test environment wired up.
_dispatch() {
    local tty_dev="$1"
    local state="$2"
    env -i HOME="$TEST_HOME" PATH="$PATH" \
        TAVS_RUNTIME_DIR="$RUNTIME_DIR" \
        TAVS_TMP_DIR="$TAVS_TMP_DIR" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        TMPDIR="$TMPDIR" \
        TTY_DEVICE="$tty_dev" \
        bash "$REPO_ROOT/src/core/trigger.sh" "$state"
}

_pending_path_for() {
    local tty_dev="$1"
    local tty_safe="${tty_dev//\//_}"
    echo "$RUNTIME_DIR/pending/${tty_safe}.osc"
}

@test "priority: latest hook wins per TTY (no merge, no priority promotion)" {
    local tty="$TEST_HOME/tty1"
    : > "$tty"  # writable file stand-in for a TTY device

    _dispatch "$tty" processing
    _dispatch "$tty" permission
    sleep 0.5  # Existing permission protection lasts 400 ms.
    _dispatch "$tty" processing  # final state intentionally != permission

    local pending
    pending=$(_pending_path_for "$tty")
    [ -f "$pending" ]

    local expected_processing expected_permission bytes
    expected_processing=$'\033]11;#112233\033\\'
    expected_permission=$'\033]11;#445566\033\\'
    bytes=$(cat "$pending")
    [[ "$bytes" == *"$expected_processing"* ]]
    [[ "$bytes" != *"$expected_permission"* ]]
    [ ! -s "$tty" ]
}

@test "priority: distinct pending files do not contaminate" {
    local tty_a="$TEST_HOME/ttyA"
    local tty_b="$TEST_HOME/ttyB"
    : > "$tty_a"
    : > "$tty_b"

    _dispatch "$tty_a" processing
    _dispatch "$tty_b" permission

    local pending_a pending_b
    pending_a=$(_pending_path_for "$tty_a")
    pending_b=$(_pending_path_for "$tty_b")

    # Both pending files exist; they hold distinct bytes (different states).
    [ -f "$pending_a" ]
    [ -f "$pending_b" ]

    local processing=$'\033]11;#112233\033\\' permission=$'\033]11;#445566\033\\'
    local bytes_a bytes_b
    bytes_a=$(cat "$pending_a"); bytes_b=$(cat "$pending_b")
    [[ "$bytes_a" == *"$processing"* && "$bytes_a" != *"$permission"* ]]
    [[ "$bytes_b" == *"$permission"* && "$bytes_b" != *"$processing"* ]]
}

@test "priority: pending file is overwritten, not appended" {
    local tty="$TEST_HOME/tty3"
    : > "$tty"

    _dispatch "$tty" processing
    local pending
    pending=$(_pending_path_for "$tty")
    [ -f "$pending" ]
    local first_size
    first_size=$(wc -c < "$pending" | tr -d ' ')

    _dispatch "$tty" processing  # same state again — file should be overwritten
    local second_size
    second_size=$(wc -c < "$pending" | tr -d ' ')

    # Overwritten (not appended): two identical dispatches yield equal sizes.
    [ "$first_size" -eq "$second_size" ]
}

@test "priority fixture runtime and state paths stay private" {
    [[ "$RUNTIME_DIR" == "$TEST_HOME/"* ]]
    [[ "$TAVS_TMP_DIR" == "$TEST_HOME/"* ]]
    [[ "$XDG_RUNTIME_DIR" == "$TEST_HOME/"* ]]
}
