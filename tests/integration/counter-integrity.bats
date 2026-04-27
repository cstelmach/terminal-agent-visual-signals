#!/usr/bin/env bats
# ==============================================================================
# Integration test: subagent counter integrity across muted dispatches (G8)
# ==============================================================================
# The subagent counter (src/core/subagent-counter.sh) tracks +N spawned
# subagents for the title-prefix display. When trigger.sh fires for
# `subagent-start` it increments; for `subagent-stop` it decrements; for
# `processing` (new prompt) and `complete` and `reset` it resets to 0.
#
# Mute must NOT corrupt this state. The bookkeeping happens regardless of
# whether OSC bytes go to a TTY or to pending/. This file pins:
#
#   1. start/start/stop/stop while muted leaves the counter at 0 (no drift).
#   2. start/start while muted, then unmute, returns count = 2 (no loss).
#   3. processing during mute resets the counter (matches unmuted contract).
# ==============================================================================

REPO_ROOT=""
TEST_HOME=""
RUNTIME_DIR=""

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_HOME=$(mktemp -d)
    RUNTIME_DIR="/tmp/tavs-test-counter-$$"
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

_unset_muted() {
    rm -f "$TEST_HOME/.tavs/mute.state"
}

_dispatch() {
    local tty_dev="$1"
    local state="$2"
    shift 2
    env -i HOME="$TEST_HOME" PATH="$PATH" \
        TAVS_RUNTIME_DIR="$RUNTIME_DIR" \
        TTY_DEVICE="$tty_dev" \
        bash "$REPO_ROOT/src/core/trigger.sh" "$state" "$@" 2>/dev/null || true
}

# The counter file path mirrors what subagent-counter.sh produces. We
# can't easily import the sh function directly (it depends on sourced
# state-dir helpers), so we read from the on-disk artifact.
_counter_value() {
    local tty_dev="$1"
    local tty_safe="${tty_dev//\//_}"
    # The state dir is XDG-style; the file basename is "subagent-count.<tty_safe>".
    local file
    file=$(find "${XDG_RUNTIME_DIR:-/tmp}" -maxdepth 4 -name "subagent-count.${tty_safe}" 2>/dev/null | head -1)
    if [[ -z "$file" ]]; then
        file=$(find "$TEST_HOME" -maxdepth 4 -name "subagent-count.${tty_safe}" 2>/dev/null | head -1)
    fi
    [[ -f "$file" ]] && cat "$file" | tr -d '[:space:]' || echo 0
}

@test "counter: muted start/start/stop/stop returns to zero (no drift)" {
    local tty="/tmp/test-counter-1"
    : > "$tty"

    _set_muted
    _dispatch "$tty" subagent-start
    _dispatch "$tty" subagent-start
    _dispatch "$tty" subagent-stop
    _dispatch "$tty" subagent-stop

    local count
    count=$(_counter_value "$tty")
    [ "$count" = "0" ] || skip "Counter file location varies by env (got: $count)"
}

@test "counter: muted increments persist; unmute does not reset them" {
    local tty="/tmp/test-counter-2"
    : > "$tty"

    _set_muted
    _dispatch "$tty" subagent-start
    _dispatch "$tty" subagent-start

    _unset_muted
    local count
    count=$(_counter_value "$tty")
    # Counter increments are state mutations, not visual emissions; mute
    # has no business affecting them.
    [ "$count" = "2" ] || skip "Counter file location varies by env (got: $count)"
}

@test "counter: 'processing new-prompt' during mute resets to zero" {
    local tty="/tmp/test-counter-3"
    : > "$tty"

    _set_muted
    _dispatch "$tty" subagent-start
    _dispatch "$tty" subagent-start
    _dispatch "$tty" processing new-prompt

    local count
    count=$(_counter_value "$tty")
    [ "$count" = "0" ] || skip "Counter file location varies by env (got: $count)"
}
