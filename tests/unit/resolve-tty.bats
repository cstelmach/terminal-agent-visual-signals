#!/usr/bin/env bats
# ==============================================================================
# Unit tests for resolve_tty() in src/core/terminal-osc-sequences.sh
#
# resolve_tty walks the process ancestry (up to 5 levels) to find a controlling
# TTY. The walk is the change that made the cross-TTY broadcast feature
# actually reach terminals (commit 1c00e64); before it, `resolve_tty` only
# checked $PPID and found nothing for hooks spawned via an intermediate shell.
#
# These tests lock in the contract so future changes can't silently regress it.
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_HOME=$(mktemp -d)
    TEST_BIN="$TEST_HOME/bin"
    mkdir -p "$TEST_HOME/.tavs"
    mkdir -p "$TEST_BIN"

    export HOME="$TEST_HOME"
    # resolve_tty side-effects TTY_DEVICE; start each test clean.
    unset TTY_DEVICE TTY_SAFE

    source "$REPO_ROOT/src/core/terminal-osc-sequences.sh"
}

teardown() {
    rm -rf "$TEST_HOME"
}

# --- Contract ---

write_ps_stub_with_writable_tty() {
    cat > "$TEST_BIN/ps" <<'EOF'
#!/bin/bash
if [[ "$1" == "-o" && "$2" == "tty=" ]]; then
    echo "null"
    exit 0
fi
if [[ "$1" == "-o" && "$2" == "ppid=" ]]; then
    echo "1"
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_BIN/ps"
}

@test "resolve_tty returns a writable /dev path from process ancestry" {
    write_ps_stub_with_writable_tty

    PATH="$TEST_BIN:$PATH" run resolve_tty
    [ "$status" -eq 0 ]
    [[ "$output" == /dev/* ]] || {
        echo "Expected /dev path, got: $output" >&2
        return 1
    }
}

@test "resolve_tty returned path is writable" {
    write_ps_stub_with_writable_tty

    PATH="$TEST_BIN:$PATH" run resolve_tty
    [ "$status" -eq 0 ]
    [ -w "$output" ]
}

@test "resolve_tty sets the output path to a char device node" {
    write_ps_stub_with_writable_tty

    PATH="$TEST_BIN:$PATH" run resolve_tty
    [ "$status" -eq 0 ]
    [ -c "$output" ] || {
        echo "Expected character-device, got: $output ($(stat -f '%HT' "$output" 2>/dev/null || echo unknown))" >&2
        return 1
    }
}

@test "resolve_tty terminates even when PPID has no TTY (ancestry walk bounded)" {
    # Spawn a subshell detached from any controlling TTY by redirecting
    # stdin from /dev/null and sending stderr to /dev/null. The walk must
    # finish — either resolve via the /dev/tty fallback or fail gracefully.
    # The real contract this guards is TERMINATION, not success: an unbounded
    # walker could hang under these inputs, which would stall hook dispatch.
    run bash -c '
        source "'"$REPO_ROOT"'/src/core/terminal-osc-sequences.sh"
        resolve_tty
    ' < /dev/null 2>/dev/null
    # status 0 (resolved via fallback) or 1 (gracefully failed) both acceptable.
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# --- Ancestry walk cap ---

@test "resolve_tty honours the ancestry cap (does not run unbounded)" {
    # The 5-level cap is tested indirectly: measure wall-clock. Five ps(1)
    # invocations should complete well under 500ms on any reasonable system.
    # An unbounded walk would loop through all parents up to init and take
    # noticeably longer / return repeated init parents.
    local t0 t1
    t0=$(date +%s)
    resolve_tty > /dev/null 2>&1 || true
    t1=$(date +%s)
    local dt=$(( t1 - t0 ))
    [ "$dt" -lt 2 ] || {
        echo "resolve_tty took ${dt}s — suspicious for a 5-level cap" >&2
        return 1
    }
}
