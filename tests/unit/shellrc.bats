#!/usr/bin/env bats
# ==============================================================================
# Unit tests for src/shell/tavs-shellrc.sh + cmd-install-shell-integration.sh
# ==============================================================================
# The shellrc is exercised through REAL interactive zsh and bash (-i) with a
# fake TTY name: zsh resets an inherited $TTY when stdin is not a terminal, so
# the zsh path assigns TTY inside the shell; bash inherits it from the env.
# Safe fixture helpers record typed dispatch; native policy semantics use owned PTYs.
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SHELLRC="$REPO_ROOT/src/shell/tavs-shellrc.sh"
    [[ -n "${TAVS_TEST_ROOT:-}" ]] || return 1
    TEST_DIR=$(mktemp -d "$TAVS_TEST_ROOT/shellrc.XXXXXX")
    TEST_HOME="$TEST_DIR/home"
    TEST_RUNTIME="$TEST_DIR/runtime"
    mkdir -p "$TEST_HOME/.tavs" "$TEST_RUNTIME/active-ttys"

    export HOME="$TEST_HOME"
    export ZDOTDIR="$TEST_HOME"
    export TAVS_RUNTIME_DIR="$TEST_RUNTIME"
    export CLI_DIR="$REPO_ROOT/src/cli"
    export TAVS_ROOT="$REPO_ROOT"
    NOW=$(date +%s)
    export TAVS_TEST_HELPER_BIN="$TEST_DIR/helper" SHELLRC_TEST_LOG="$TEST_DIR/calls"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
if [[ "$1" == --validate-config ]]; then
    case "$2" in
        --managed-output-capabilities) printf 'tavs-managed-output-schema=1\n' ;;
        --organizer-capabilities) printf 'tavs-organizer-schema=1\n' ;;
        *) exit 1 ;;
    esac
    exit 0
fi
[[ "$2" == "$HOME/.tavs/visual-restrictions.state" && "$3" == "$TAVS_RUNTIME_DIR" ]] || exit 1
case "$1" in --managed-register|--managed-current) printf '%s\n' "$1" >> "$SHELLRC_TEST_LOG" ;; *) exit 1 ;; esac
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
}

write_lock_state() {
    # write_lock_state <locked> <lock_until> <unlock_until> [bg]
    cat > "$TEST_RUNTIME/lock.state" <<EOF
LOCKED="$1"
REASON="manual"
LOCK_UNTIL_EPOCH="$2"
UNLOCK_UNTIL_EPOCH="$3"
WRITTEN_EPOCH="$NOW"
LOCK_BG="${4:-#112233}"
LOCK_FG=""
SCHEMA_VERSION="1"
EOF
}

write_mute_state() {
    # write_mute_state <muted> <written_epoch> <app_pid> [pause_bg]
    cat > "$TEST_HOME/.tavs/mute.state" <<EOF
MUTED="$1"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$2"
APP_PID="$3"
PAUSE_BG="${4:-#445566}"
PAUSE_FG=""
SCHEMA_VERSION="1"
EOF
}

run_shellrc_zsh() {
    run zsh -fic "TTY=/dev/ttys901; source '$SHELLRC'"
}

run_shellrc_bash() {
    TTY=/dev/ttys902 run bash --norc -ic "source '$SHELLRC'"
}

# --- Installer: fence idempotency ---

@test "install: copies shellrc and adds fence to zshrc exactly once" {
    touch "$TEST_HOME/.zshrc"
    source "$CLI_DIR/cmd-install-shell-integration.sh"
    run cmd_install_shell_integration
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.tavs/shellrc" ]
    run cmd_install_shell_integration
    [ "$status" -eq 0 ]
    local count
    count=$(grep -cF '# >>> tavs shell integration >>>' "$TEST_HOME/.zshrc")
    [ "$count" -eq 1 ]
}

@test "install: adds fence to existing bashrc as well" {
    touch "$TEST_HOME/.zshrc" "$TEST_HOME/.bashrc"
    source "$CLI_DIR/cmd-install-shell-integration.sh"
    run cmd_install_shell_integration
    [ "$status" -eq 0 ]
    grep -qF '# >>> tavs shell integration >>>' "$TEST_HOME/.bashrc"
}

@test "install --remove: strips fence, keeps other content, deletes shellrc" {
    printf '# my prompt setup\nexport FOO=bar\n' > "$TEST_HOME/.zshrc"
    source "$CLI_DIR/cmd-install-shell-integration.sh"
    run cmd_install_shell_integration
    [ "$status" -eq 0 ]
    run cmd_install_shell_integration --remove
    [ "$status" -eq 0 ]
    ! grep -qF 'tavs shell integration' "$TEST_HOME/.zshrc"
    grep -qF 'export FOO=bar' "$TEST_HOME/.zshrc"
    [ ! -f "$TEST_HOME/.tavs/shellrc" ]
}

# --- Lock paint (zsh + bash) ---

@test "zsh: effective lock requests managed policy and registers TTY" {
    write_lock_state true $((NOW + 300)) 0
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$(cat "$SHELLRC_TEST_LOG")" == *--managed-current* ]]
    [[ "$output" != *'locked until'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
}

@test "bash: effective lock requests managed policy and registers TTY" {
    write_lock_state true $((NOW + 300)) 0
    run_shellrc_bash
    [ "$status" -eq 0 ]
    [[ "$(cat "$SHELLRC_TEST_LOG")" == *--managed-current* ]]
    [[ "$output" != *'locked until'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys902" ]
}

@test "expired lock emits no raw paint and still registers" {
    write_lock_state true $((NOW - 10)) 0
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
}

@test "active unlock grant suspends the lock paint" {
    write_lock_state true $((NOW + 300)) $((NOW + 120))
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
}

@test "non-numeric LOCK_UNTIL_EPOCH means not locked (D3)" {
    write_lock_state true "garbage" 0
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
}

# --- Soft mute paint ---

@test "valid soft mute requests managed policy without raw title" {
    write_mute_state true "$NOW" "$$"
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$(cat "$SHELLRC_TEST_LOG")" == *--managed-current* ]]
    [[ "$output" != *'locked until'* ]]
}

@test "stale mute heartbeat paints nothing (fail-open preserved)" {
    write_mute_state true $((NOW - 300)) "$$"
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
}

@test "dead APP_PID paints nothing (fail-open preserved)" {
    write_mute_state true "$NOW" 999999
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
}

@test "overlapping lock and soft mute request one managed policy" {
    write_lock_state true $((NOW + 300)) 0
    write_mute_state true "$NOW" "$$"
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$(cat "$SHELLRC_TEST_LOG")" == *--managed-current* ]]
    [[ "$output" != *'locked until'* ]]
}

# --- Kill switch ---

@test "TAVS_STATUS=false: no registration, no paint" {
    write_lock_state true $((NOW + 300)) 0
    run zsh -fic "TAVS_STATUS=false; TTY=/dev/ttys901; source '$SHELLRC'"
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
    [ ! -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
}

@test "no state files: registers silently with no paint output" {
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
}

write_visual_suspension() {
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="%s"\n' "$1" \
        > "$TEST_HOME/.tavs/visual-restrictions.state"
}

@test "suspension: overlapping lock and mute stay inert in Bash and zsh" {
    write_lock_state true $((NOW + 300)) 0
    write_mute_state true "$NOW" "$$"
    write_visual_suspension true
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* && "$output" != *']10;'* && "$output" != *']104'* ]]
    [[ "$output" != *'locked until'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
    run_shellrc_bash
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* && "$output" != *']10;'* && "$output" != *']104'* ]]
    [[ "$output" != *'locked until'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys902" ]
}

@test "suspension: copied standalone shellrc has no repository dependency" {
    source "$CLI_DIR/cmd-install-shell-integration.sh"
    run cmd_install_shell_integration
    [ "$status" -eq 0 ]
    SHELLRC="$TEST_HOME/.tavs/shellrc"
    export TAVS_ROOT="$TEST_DIR/no-source-modules"
    write_lock_state true $((NOW + 300)) 0
    write_visual_suspension true
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* && "$output" != *'locked until'* ]]
    run_shellrc_bash
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* && "$output" != *'locked until'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys902" ]
}

@test "install: delivers complete adjacent helper resources and remains portable without checkout" {
    source "$CLI_DIR/cmd-install-shell-integration.sh"
    run cmd_install_shell_integration
    [ "$status" -eq 0 ]
    local file shell
    for file in helper-selection.sh portable_helper.py portable_context.py portable_metadata.py \
        portable_observation.py portable_intent.py portable_records.py portable_record_io.py \
        portable_render.py portable_renderer.py portable_ownership.py portable_policy.py \
        portable_device_writer.py portable_process_identity.py; do
        cmp "$REPO_ROOT/src/core/$file" "$TEST_HOME/.tavs/shell-helper/$file"
    done
    [ -x "$TEST_HOME/.tavs/shell-helper/portable_helper.py" ]
    export TAVS_ROOT="$TEST_DIR/missing-checkout" TAVS_TEST_HELPER_BIN="$TEST_DIR/missing-native"
    for shell in bash zsh; do
        run "$shell" -fc 'source "$HOME/.tavs/shellrc"; _tavs_shellrc_managed_helper; printf "%s" "$_TAVS_HELPER_BACKEND"'
        [ "$status" -eq 0 ]
        [ "$output" = portable ]
    done
}

@test "install: helper copy failure leaves the existing shellrc and fences untouched" {
    printf 'retained old shellrc\n' > "$TEST_HOME/.tavs/shellrc"
    printf 'existing shell setup\n' > "$TEST_HOME/.zshrc"
    printf 'blocking file\n' > "$TEST_HOME/.tavs/shell-helper"
    source "$CLI_DIR/cmd-install-shell-integration.sh"
    run cmd_install_shell_integration
    [ "$status" -eq 1 ]
    [ "$(cat "$TEST_HOME/.tavs/shellrc")" = 'retained old shellrc' ]
    [ "$(cat "$TEST_HOME/.zshrc")" = 'existing shell setup' ]
}

@test "install: linked helper destination cannot overwrite an unrelated file" {
    printf 'unrelated preferences 43\n' > "$TEST_HOME/preferences"
    mkdir -p "$TEST_HOME/.tavs/shell-helper"
    ln -s "$TEST_HOME/preferences" "$TEST_HOME/.tavs/shell-helper/helper-selection.sh"
    source "$CLI_DIR/cmd-install-shell-integration.sh"
    run cmd_install_shell_integration
    [ "$status" -eq 1 ]
    [ "$(cat "$TEST_HOME/preferences")" = 'unrelated preferences 43' ]
    [ ! -e "$TEST_HOME/.tavs/shellrc" ]
    [ ! -e "$TEST_HOME/.zshrc" ]
}

@test "startup: registration failure keeps the selected backend and never uses raw output" {
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
printf '%s\n' "$1" >> "$SHELLRC_TEST_LOG"
if [[ "$1" == --validate-config ]]; then
    case "$2" in
        --organizer-capabilities) printf 'tavs-organizer-schema=1\n' ;;
        --managed-output-capabilities) printf 'tavs-managed-output-schema=1\n' ;;
    esac
    exit 0
fi
exit 1
HELPER
    local shell
    for shell in bash zsh; do
        : > "$SHELLRC_TEST_LOG"
        run "$shell" -fic 'TTY=/dev/ttys901; source "$1"; [[ "$_TAVS_HELPER_BACKEND" == native ]]' _ "$SHELLRC"
        [ "$status" -eq 0 ]
        [ "$(grep -c '^--validate-config$' "$SHELLRC_TEST_LOG")" -eq 2 ]
        [[ "$(cat "$SHELLRC_TEST_LOG")" == *--managed-register*--managed-current* ]]
        [[ "$output" == *'terminal registration unavailable'* && "$output" != *$'\033]'* ]]
    done
}

@test "source shellrc can find the shared selector when sourced by a bare filename" {
    local shell
    for shell in bash zsh; do
        run "$shell" -fc 'cd "$1/src/shell"; source tavs-shellrc.sh; _tavs_shellrc_managed_helper; printf "%s" "$_TAVS_HELPER_BACKEND"' _ "$REPO_ROOT"
        [ "$status" -eq 0 ]
        [ "$output" = native ]
    done
}

@test "suspension: fresh shell and recreated runtime honor the persistent marker" {
    write_visual_suspension true
    TEST_RUNTIME="$TEST_DIR/new-runtime"
    export TAVS_RUNTIME_DIR="$TEST_RUNTIME"
    mkdir -p "$TEST_RUNTIME"
    write_lock_state true $((NOW + 300)) 0
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
    run_shellrc_bash
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys902" ]
}

@test "suspension: explicit false delegates the current saved lock in both shells" {
    write_lock_state true $((NOW + 300)) 0
    write_visual_suspension true
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* ]]
    write_visual_suspension false
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$(cat "$SHELLRC_TEST_LOG")" == *--managed-current* ]]
    run_shellrc_bash
    [ "$status" -eq 0 ]
    [[ "$(cat "$SHELLRC_TEST_LOG")" == *--managed-current* ]]
}

@test "unavailable: malformed marker registers but skips paint and raw content in both shells" {
    write_lock_state true $((NOW + 300)) 0
    write_mute_state true "$NOW" "$$"
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="MARKER_BODY_SENTINEL"\n' \
        > "$TEST_HOME/.tavs/visual-restrictions.state"
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* && "$output" != *'MARKER_BODY_SENTINEL'* ]]
    [[ "$output" == *'unavailable'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
    run_shellrc_bash
    [ "$status" -eq 0 ]
    [[ "$output" != *']11;'* && "$output" != *'MARKER_BODY_SENTINEL'* ]]
    [[ "$output" == *'unavailable'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys902" ]
}
