#!/usr/bin/env bats
# ==============================================================================
# Unit tests for src/shell/tavs-shellrc.sh + cmd-install-shell-integration.sh
# ==============================================================================
# The shellrc is exercised through REAL interactive zsh and bash (-i) with a
# fake TTY name: zsh resets an inherited $TTY when stdin is not a terminal, so
# the zsh path assigns TTY inside the shell; bash inherits it from the env.
# Paint bytes go to stdout and are asserted as substrings.
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SHELLRC="$REPO_ROOT/src/shell/tavs-shellrc.sh"
    TEST_DIR=$(mktemp -d)
    TEST_HOME="$TEST_DIR/home"
    TEST_RUNTIME="$TEST_DIR/runtime"
    mkdir -p "$TEST_HOME/.tavs" "$TEST_RUNTIME/active-ttys"

    export HOME="$TEST_HOME"
    export TAVS_RUNTIME_DIR="$TEST_RUNTIME"
    export CLI_DIR="$REPO_ROOT/src/cli"
    export TAVS_ROOT="$REPO_ROOT"
    NOW=$(date +%s)
}

teardown() {
    rm -rf "$TEST_DIR"
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

@test "zsh: effective lock paints bg + lock title and registers TTY" {
    write_lock_state true $((NOW + 300)) 0
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" == *']11;#112233'* ]]
    [[ "$output" == *'locked until'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys901" ]
}

@test "bash: effective lock paints bg + lock title and registers TTY" {
    write_lock_state true $((NOW + 300)) 0
    run_shellrc_bash
    [ "$status" -eq 0 ]
    [[ "$output" == *']11;#112233'* ]]
    [[ "$output" == *'locked until'* ]]
    [ -f "$TEST_RUNTIME/active-ttys/_dev_ttys902" ]
}

@test "expired lock paints nothing but still registers" {
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

@test "valid soft mute paints pause colors without a title" {
    write_mute_state true "$NOW" "$$"
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" == *']11;#445566'* ]]
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

@test "lock wins over soft mute and uses the lock title" {
    write_lock_state true $((NOW + 300)) 0
    write_mute_state true "$NOW" "$$"
    run_shellrc_zsh
    [ "$status" -eq 0 ]
    [[ "$output" == *']11;#112233'* ]]
    [[ "$output" == *'locked until'* ]]
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
