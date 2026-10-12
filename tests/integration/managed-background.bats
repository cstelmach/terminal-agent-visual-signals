#!/usr/bin/env bats

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" ]] || return 1
    REPO_ROOT="$BATS_TEST_DIRNAME/../.."
    TEST_DIR=$(mktemp -d "$TAVS_TEST_ROOT/managed-bridge.XXXXXX")
    export TTY_DEVICE="$TEST_DIR/tty" TAVS_RUNTIME_DIR="$TEST_DIR/runtime"
    export HOME="$TEST_DIR/home" TAVS_TEST_HELPER_BIN="$TEST_DIR/helper"
    export MANAGED_TEST_LOG="$TEST_DIR/calls" MANAGED_TEST_MODE=healthy
    mkdir -p "$HOME/.tavs" "$TAVS_RUNTIME_DIR"
    : > "$TTY_DEVICE"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
printf '%s\n' "$1" >> "$MANAGED_TEST_LOG"
if [[ "$1" == --validate-config ]]; then
    if [[ "$2" == --managed-output-capabilities ]]; then
        [[ "$MANAGED_TEST_MODE" != old ]] || exit 1
        printf 'tavs-managed-output-schema=1\n'
    else
        printf 'tavs-organizer-schema=1\n'
    fi
    exit 0
fi
case "$1" in
    --organizer-context) printf 'context-token\n'; exit 0 ;;
    --managed-register|--managed-current|--managed-reconcile)
        [[ "$2" == "$HOME/.tavs/visual-restrictions.state" && "$3" == "$TAVS_RUNTIME_DIR" ]] || exit 1
        [[ "$MANAGED_TEST_MODE" != failed ]] || exit 1
        exit 0 ;;
    --managed-forced-reset)
        [[ "$2" == "$HOME/.tavs/visual-restrictions.state" && "$3" == "$TAVS_RUNTIME_DIR" ]] || exit 1
        [[ "$4" == "$TTY_DEVICE" && "$5" == context-token ]] || exit 1
        [[ "$MANAGED_TEST_MODE" != stale ]] || exit 3
        [[ "$MANAGED_TEST_MODE" != failed ]] || exit 1
        printf 'title=%s\n' "$6" >> "$MANAGED_TEST_LOG"
        exit 0 ;;
    --managed-check-context)
        [[ "$5" == context-token ]] || exit 1
        [[ "$MANAGED_TEST_MODE" != stale ]] || exit 3
        [[ "$MANAGED_TEST_MODE" != failed ]] || exit 1
        exit 0 ;;
    --managed-background)
        [[ "$4" == "$TTY_DEVICE" && "$4" == "$TAVS_TEST_ROOT/"* ]] || exit 1
        [[ "$2" == "$HOME/.tavs/visual-restrictions.state" && "$3" == "$TAVS_RUNTIME_DIR" ]] || exit 1
        [[ "$5" == context-token ]] || exit 1
        [[ "$MANAGED_TEST_MODE" != stale ]] || exit 3
        [[ "$MANAGED_TEST_MODE" != failed ]] || exit 1
        if [[ "$6" == reset ]]; then printf '\033]111\033\\' > "$4"
        else printf '\033]11;%s\033\\' "$6" > "$4"
        fi
        printf '%s\n' "scope=${TAVS_SESSIONS_TEST_TARGETS:-}" >> "$MANAGED_TEST_LOG"
        exit 0 ;;
esac
exit 1
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
}

@test "forced idle reset never bypasses typed validation with palette or title writes" {
    export MANAGED_TEST_MODE=failed TAVS_ORGANIZER_CONTEXT=context-token
    run /bin/bash -p -c '
        source "$1/src/core/terminal-osc-sequences.sh"
        source "$1/src/core/idle-worker-background.sh"
        get_short_cwd() { printf fixture; }
        write_session_state() { :; }
        check_and_clear_skip_signal() { return 1; }
        should_send_bg_color() { return 0; }
        should_enable_palette_theming() { return 0; }
        UNIFIED_CHECK_INTERVAL=0.01 MAX_TIMER_RUNTIME=0
        UNIFIED_STAGE_DURATIONS=(60) UNIFIED_STAGE_COLORS=(reset)
        unified_timer_worker "$TTY_DEVICE"
    ' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
    [[ "$(cat "$MANAGED_TEST_LOG")" == *--managed-forced-reset* ]]
}

@test "stale idle cycle validates before its palette and title" {
    export MANAGED_TEST_MODE=stale TAVS_ORGANIZER_CONTEXT=context-token
    run /bin/bash -p -c '
        source "$1/src/core/terminal-osc-sequences.sh"
        source "$1/src/core/idle-worker-background.sh"
        get_short_cwd() { printf fixture; }
        write_session_state() { :; }
        check_and_clear_skip_signal() { return 1; }
        should_send_bg_color() { return 0; }
        should_enable_palette_theming() { return 0; }
        _build_osc_palette_seq() { printf "\\033]104\\033\\\\"; }
        _get_palette_mode() { printf dark; }
        compose_title() { printf OLD_TITLE; }
        ENABLE_TITLE_PREFIX=true UNIFIED_CHECK_INTERVAL=0.01 MAX_TIMER_RUNTIME=1
        UNIFIED_STAGE_DURATIONS=(60) UNIFIED_STAGE_COLORS=(reset)
        unified_timer_worker "$TTY_DEVICE"
    ' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
    [[ "$(cat "$MANAGED_TEST_LOG")" == *--managed-background* ]]
}

@test "background-disabled synthetic signals validate context without requesting a paint" {
    export MANAGED_TEST_MODE=stale TAVS_ORGANIZER_CONTEXT=context-token TAVS_ORGANIZER_SYNTHETIC=1
    printf 'TAVS_BACKGROUND_MODE="off"\nENABLE_PALETTE_THEMING=true\nTAVS_TITLE_MODE="full"\n' > "$HOME/.tavs/user.conf"
    run /bin/bash -p "$REPO_ROOT/src/core/trigger.sh" processing
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
    [[ "$(cat "$MANAGED_TEST_LOG")" == *--managed-check-context* ]]
    [[ "$(cat "$MANAGED_TEST_LOG")" != *--managed-background* ]]
}

@test "recovery cannot resurrect an open opaque pending buffer" {
    run /bin/bash -p -c '
        source "$1/src/core/mute-gate.sh"
        source "$1/src/core/terminal-osc-sequences.sh"
        _TAVS_SUPPRESS_OUTPUT=1
        _TAVS_REPLAY_BYPASS_MUTE=1
        _tavs_mute_buffer_open
        emit_osc "\\033]0;OLD_TITLE\\033\\\\"
        printf "SCHEMA_VERSION=\"1\"\nSUSPENDED=\"true\"\n" > "$HOME/.tavs/visual-restrictions.state"
        _tavs_mute_buffer_close
        test -z "${_TAVS_PENDING_BUFFER:-}"
        test ! -s "$TTY_DEVICE"
        test -z "$(find "$TAVS_RUNTIME_DIR/pending" -type f -print 2>/dev/null)"
    ' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
}

@test "debug replay requests typed reconciliation without reading historical bytes" {
    mkdir -p "$TAVS_RUNTIME_DIR/pending"
    printf '\033]0;OLD_TITLE\007\007' > "$TAVS_RUNTIME_DIR/pending/_dev_ttys901.osc"
    run /bin/bash -p "$REPO_ROOT/src/core/trigger.sh" replay _dev_ttys901
    [ "$status" -eq 0 ]
    [[ "$(cat "$MANAGED_TEST_LOG")" == *--managed-reconcile* ]]
    [[ "$output" != *OLD_TITLE* ]]
    [ ! -s "$TTY_DEVICE" ]
}

@test "requested soft pause suppresses only while persistent policy is active" {
    cat > "$HOME/.tavs/mute.state" <<STATE
MUTED="false"
REQUESTED_MUTED="true"
MUTE_LEVEL="soft"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
APP_PID="$$"
SCHEMA_VERSION="1"
STATE
    run /bin/bash -p -c '
        source "$1/src/core/mute-gate.sh"
        _tavs_check_mute_state
        test "$_TAVS_SUPPRESS_OUTPUT" = 1
        printf "SCHEMA_VERSION=\"1\"\nSUSPENDED=\"true\"\n" > "$HOME/.tavs/visual-restrictions.state"
        _tavs_check_mute_state && exit 1
        test "$_TAVS_SUPPRESS_OUTPUT" = 0
    ' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
}

@test "hard mute mirror cannot survive an unlock grant or finite expiry" {
    cat > "$HOME/.tavs/mute.state" <<STATE
MUTED="true"
REQUESTED_MUTED="true"
MUTE_LEVEL="hard"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
APP_PID="$$"
SCHEMA_VERSION="1"
STATE
    cat > "$TAVS_RUNTIME_DIR/lock.state" <<STATE
LOCKED="true"
LOCK_UNTIL_EPOCH="$(( $(date +%s) + 300 ))"
UNLOCK_UNTIL_EPOCH="$(( $(date +%s) + 120 ))"
SCHEMA_VERSION="1"
STATE
    run /bin/bash -p -c '
        source "$1/src/core/mute-gate.sh"
        _tavs_check_mute_state && exit 1
        test "$_TAVS_SUPPRESS_OUTPUT" = 0
        printf "LOCKED=\"true\"\nLOCK_UNTIL_EPOCH=\"1\"\nSCHEMA_VERSION=\"1\"\n" > "$TAVS_RUNTIME_DIR/lock.state"
        _tavs_check_mute_state && exit 1
        test "$_TAVS_SUPPRESS_OUTPUT" = 0
    ' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
}

@test "independent requested soft pause remains active during a hard unlock grant" {
    cat > "$HOME/.tavs/mute.state" <<STATE
MUTED="true"
REQUESTED_MUTED="true"
MUTE_LEVEL="soft"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
APP_PID="$$"
SCHEMA_VERSION="1"
STATE
    cat > "$TAVS_RUNTIME_DIR/lock.state" <<STATE
LOCKED="true"
LOCK_UNTIL_EPOCH="$(( $(date +%s) + 300 ))"
UNLOCK_UNTIL_EPOCH="$(( $(date +%s) + 120 ))"
SCHEMA_VERSION="1"
STATE
    run /bin/bash -p -c 'source "$1/src/core/mute-gate.sh"; _tavs_check_mute_state; test "$_TAVS_SUPPRESS_OUTPUT" = 1' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
}

@test "registry age cannot authorize pruning a possibly live owner" {
    mkdir -p "$TAVS_RUNTIME_DIR/active-ttys"
    touch -t 202001010000 "$TAVS_RUNTIME_DIR/active-ttys/_dev_ttys901"
    run /bin/bash -p -c 'source "$1/src/core/mute-gate.sh"; clean_active_tty_registry' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ -f "$TAVS_RUNTIME_DIR/active-ttys/_dev_ttys901" ]
}

@test "semantic background uses typed helper with private roots and current context" {
    run /bin/bash -p -c 'source "$1/src/core/terminal-osc-sequences.sh"; send_osc_bg "#123456"' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ "$(cat "$TTY_DEVICE")" = $'\033]11;#123456\033\\' ]
    [[ "$(cat "$MANAGED_TEST_LOG")" == *--managed-background* ]]
    [[ "$(cat "$MANAGED_TEST_LOG")" != *--organizer-intent* ]]
}

@test "unsupported or missing helper never falls through to raw background bytes" {
    for mode in old missing; do
        : > "$TTY_DEVICE"
        export MANAGED_TEST_MODE="$mode"
        if [[ "$mode" == missing ]]; then export TAVS_TEST_HELPER_BIN="$TEST_DIR/missing"; fi
        run /bin/bash -p -c 'source "$1/src/core/terminal-osc-sequences.sh"; send_osc_bg "#ABCDEF"' _ "$REPO_ROOT"
        [ "$status" -ne 0 ]
        [ ! -s "$TTY_DEVICE" ]
    done
}

@test "typed failure never emits a raw fallback" {
    export MANAGED_TEST_MODE=failed
    run /bin/bash -p -c 'source "$1/src/core/terminal-osc-sequences.sh"; send_osc_bg "#123456"' _ "$REPO_ROOT"
    [ "$status" -ne 0 ]
    [ ! -s "$TTY_DEVICE" ]
}

@test "stale synthetic background prevents following palette and title output" {
    export MANAGED_TEST_MODE=stale TAVS_ORGANIZER_SYNTHETIC=1 TAVS_ORGANIZER_CONTEXT=context-token
    run /bin/bash -p -c 'source "$1/src/core/terminal-osc-sequences.sh"; send_osc_bg reset; emit_osc "\033]104\033\\"; emit_osc "\033]0;OLD_TITLE\033\\"' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
}

@test "managed output preserves dedicated scope instead of clearing it" {
    export TAVS_SESSIONS_TEST_TARGETS=dedicated-scope
    run /bin/bash -p -c 'source "$1/src/core/terminal-osc-sequences.sh"; send_osc_bg reset' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ "$(cat "$TTY_DEVICE")" = $'\033]111\033\\' ]
    [[ "$(cat "$MANAGED_TEST_LOG")" == *scope=dedicated-scope* ]]
}

@test "standalone shell startup registers and requests current typed policy" {
    export TTY=/dev/ttys901
    run /bin/bash -pic 'source "$1/src/shell/tavs-shellrc.sh"' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [[ "$(cat "$MANAGED_TEST_LOG")" == *--managed-register*--managed-current* ]]
}

@test "standalone startup cannot raw-paint a lock when typed helper fails" {
    export TTY=/dev/ttys901 MANAGED_TEST_MODE=failed
    cat > "$TAVS_RUNTIME_DIR/lock.state" <<STATE
LOCKED="true"
LOCK_UNTIL_EPOCH="$(( $(date +%s) + 3600 ))"
UNLOCK_UNTIL_EPOCH="0"
LOCK_BG="#123456"
LOCK_FG="#EEEEEE"
SCHEMA_VERSION="1"
STATE
    run /bin/bash -pic 'source "$1/src/shell/tavs-shellrc.sh"' _ "$REPO_ROOT"
    [[ "$output" != *$'\033]11;'* ]]
    [[ "$output" != *$'\033]10;'* ]]
}
