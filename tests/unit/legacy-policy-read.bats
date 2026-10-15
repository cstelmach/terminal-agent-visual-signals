#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    [[ -n "${TAVS_TEST_ROOT:-}" ]] || return 1
    TEST_DIR=$(mktemp -d "$TAVS_TEST_ROOT/legacy-policy.XXXXXX")
    export HOME="$TEST_DIR/home" TAVS_RUNTIME_DIR="$TEST_DIR/runtime"
    export TAVS_ROOT="$REPO_ROOT" CLI_DIR="$REPO_ROOT/src/cli"
    export TAVS_USER_CONFIG_DIR="$HOME/.tavs"
    mkdir -p "$TAVS_USER_CONFIG_DIR" "$TAVS_RUNTIME_DIR"
    source "$CLI_DIR/cmd-lock.sh"
    source "$CLI_DIR/cmd-schedule.sh"
    source "$REPO_ROOT/src/core/mute-gate.sh"
    NOW=$(date +%s)
}

write_lock() {
    printf 'LOCKED="true"\nSCHEMA_VERSION="1"\nLOCK_UNTIL_EPOCH="%s"' \
        "$((NOW + 3600))" > "$TAVS_RUNTIME_DIR/lock.state"
}

write_mute() {
    printf 'MUTED="true"\nREASON="quiet_period"\nUNTIL_EPOCH="0"\nWRITTEN_EPOCH="%s"\nAPP_PID="%s"\nSCHEMA_VERSION="1"\n' \
        "$NOW" "$$" > "$HOME/.tavs/mute.state"
}

@test "lock read distinguishes trusted absence and includes an unterminated final field" {
    if _tavs_lock_read; then return 1; else [ "$?" -eq 1 ]; fi
    [ "$_LS_READ_STATUS" = absent ]
    write_lock
    _tavs_lock_read
    [ "$_LS_READ_STATUS" = present ]
    [ "$_LS_LOCK_UNTIL" = "$((NOW + 3600))" ]
    _tavs_lock_effective "$NOW"
}

@test "unsafe lock reads clear previously accepted fields without exposing their body" {
    write_lock
    _tavs_lock_read
    printf 'PRIVATE_POLICY_SENTINEL\n' > "$TEST_DIR/other"
    mv "$TAVS_RUNTIME_DIR/lock.state" "$TEST_DIR/original-lock"
    ln -s "$TEST_DIR/other" "$TAVS_RUNTIME_DIR/lock.state"
    if _tavs_lock_read; then return 1; else [ "$?" -eq 2 ]; fi
    [ "$_LS_READ_STATUS" = unavailable ]
    [ -z "$_LS_LOCKED$_LS_LOCK_UNTIL$_TAVS_POLICY_DATA" ]
}

@test "lock reads reject writable parents and leaves but retain read-only group access" {
    write_lock
    chmod 640 "$TAVS_RUNTIME_DIR/lock.state"
    _tavs_lock_read
    chmod 660 "$TAVS_RUNTIME_DIR/lock.state"
    if _tavs_lock_read; then return 1; else [ "$?" -eq 2 ]; fi
    chmod 600 "$TAVS_RUNTIME_DIR/lock.state"
    chmod 770 "$TAVS_RUNTIME_DIR"
    if _tavs_lock_read; then return 1; else [ "$?" -eq 2 ]; fi
    chmod 700 "$TAVS_RUNTIME_DIR"
    _tavs_lock_read
}

@test "lock and mute FIFOs return unavailable without waiting for a writer" {
    mkfifo "$TAVS_RUNTIME_DIR/lock.state" "$HOME/.tavs/mute.state"
    python3 - "$REPO_ROOT" <<'PY'
import subprocess, sys
root = sys.argv[1]
scripts = [
    'source "$1/src/core/lock-state-lib.sh"; _tavs_lock_read; rc=$?; '
    '[[ $rc == 2 && $_LS_READ_STATUS == unavailable ]]',
    'source "$1/src/core/mute-gate.sh"; _tavs_check_mute_state; rc=$?; '
    '[[ $rc == 1 && $_TAVS_SUPPRESS_OUTPUT == 0 ]]',
]
for script in scripts:
    result = subprocess.run(['/bin/bash', '-c', script, 'policy-test', root],
                            capture_output=True, timeout=3)
    assert result.returncode == 0, result.stderr.decode()
PY
}

@test "policy reads cap content at 8 KiB and reject NUL without publishing partial fields" {
    python3 - "$TAVS_RUNTIME_DIR/lock.state" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_bytes(b'LOCKED="true"\n' + b'X' * (8192 - 14))
PY
    _tavs_lock_read
    [ "$_LS_LOCKED" = true ]
    printf X >> "$TAVS_RUNTIME_DIR/lock.state"
    if _tavs_lock_read; then return 1; else [ "$?" -eq 2 ]; fi
    [ -z "$_LS_LOCKED$_TAVS_POLICY_DATA" ]
    printf 'LOCKED="true"\n\0PRIVATE_POLICY_SENTINEL\n' > "$TAVS_RUNTIME_DIR/lock.state"
    if _tavs_lock_read; then return 1; else [ "$?" -eq 2 ]; fi
    [ -z "$_LS_LOCKED$_TAVS_POLICY_DATA" ]
}

@test "bounded snapshot preserves newlines and rejects NUL on Bash 3, Bash 5 and zsh" {
    local shell
    printf 'MUTED="false"\n\n' > "$HOME/.tavs/mute.state"
    for shell in /bin/bash /opt/homebrew/bin/bash /bin/zsh; do
        [[ -x "$shell" ]] || continue
        run "$shell" -fc 'source "$1"; _tavs_policy_read_data "$2" || exit 20
[[ "$_TAVS_POLICY_DATA" == "$3" ]]' \
            _ "$REPO_ROOT/src/core/visual-restrictions-state.sh" "$HOME/.tavs/mute.state" $'MUTED="false"\n\n'
        [ "$status" -eq 0 ]
    done
    printf 'MUTED="false"\0\n' > "$HOME/.tavs/mute.state"
    for shell in /bin/bash /opt/homebrew/bin/bash /bin/zsh; do
        [[ -x "$shell" ]] || continue
        run "$shell" -fc 'source "$1"; _tavs_policy_read_data "$2"; rc=$?
[[ "$rc" == 2 && -z "$_TAVS_POLICY_DATA" && "$_TAVS_POLICY_READ_STATUS" == unavailable ]]' \
            _ "$REPO_ROOT/src/core/visual-restrictions-state.sh" "$HOME/.tavs/mute.state"
        [ "$status" -eq 0 ]
    done
}

@test "mute gate ignores unsafe lock and mute storage even with live mute fields" {
    write_mute
    _tavs_check_mute_state
    [ "$_TAVS_SUPPRESS_OUTPUT" = 1 ]
    chmod 660 "$HOME/.tavs/mute.state"
    if _tavs_check_mute_state; then return 1; fi
    [ "$_TAVS_SUPPRESS_OUTPUT" = 0 ]
    chmod 600 "$HOME/.tavs/mute.state"
    write_lock
    chmod 660 "$TAVS_RUNTIME_DIR/lock.state"
    if _tavs_check_mute_state; then return 1; fi
    [ "$_TAVS_SUPPRESS_OUTPUT" = 0 ]
}

@test "lock status and unlock report unsafe storage without claiming absence or challenging" {
    write_lock
    chmod 660 "$TAVS_RUNTIME_DIR/lock.state"
    _tavs_challenge_verify() { : > "$TEST_DIR/challenged"; return 1; }
    run cmd_lock status
    [ "$status" -eq 1 ]
    [[ "$output" == *'Lock state unavailable'* && "$output" != *'Lock: none'* ]]
    run _lock_unlock --for 15m
    [ "$status" -eq 1 ]
    [[ "$output" == *'Lock state unavailable'* && "$output" != *'Nothing to unlock'* ]]
    [ ! -e "$TEST_DIR/challenged" ]
}

@test "unsafe lock storage prevents a schedule edit without challenging or changing definitions" {
    write_lock
    chmod 660 "$TAVS_RUNTIME_DIR/lock.state"
    printf '%s\n' '{"version":1,"master_active":false,"allowed_windows":[],"quiet_periods":[]}' > "$SCHEDULE_FILE"
    cp "$SCHEDULE_FILE" "$TEST_DIR/schedule-before"
    _tavs_challenge_verify() { : > "$TEST_DIR/challenged"; return 1; }
    traced_resume() { set -x; cmd_schedule resume; }
    run traced_resume
    [ "$status" -eq 1 ] || { printf 'Unexpected schedule status: %s\n%s\n' "$status" "$output"; return 1; }
    [[ "$output" == *'Lock state unavailable'* ]]
    [ ! -e "$TEST_DIR/challenged" ]
    cmp "$TEST_DIR/schedule-before" "$SCHEDULE_FILE"
}

@test "portable lock now preserves an unavailable existing definition" {
    write_lock
    cp "$TAVS_RUNTIME_DIR/lock.state" "$TEST_DIR/lock-before"
    chmod 660 "$TAVS_RUNTIME_DIR/lock.state"
    uname() { printf 'Linux\n'; }
    run cmd_lock now --for 4h
    [ "$status" -eq 1 ]
    [[ "$output" == *'Lock state unavailable'* ]]
    cmp "$TEST_DIR/lock-before" "$TAVS_RUNTIME_DIR/lock.state"
}

@test "schedule show reports unsafe or invalid mute state without claiming Active" {
    printf '%s\n' '{"version":1,"master_active":false,"allowed_windows":[],"quiet_periods":[]}' > "$SCHEDULE_FILE"
    printf 'MUTED="PRIVATE_POLICY_SENTINEL"\n' > "$HOME/.tavs/mute.state"
    run cmd_schedule show
    [ "$status" -eq 1 ]
    [[ "$output" == *'Mute state unavailable'* && "$output" != *'Active'* && "$output" != *'PRIVATE_POLICY_SENTINEL'* ]]
    chmod 660 "$HOME/.tavs/mute.state"
    run cmd_schedule show
    [ "$status" -eq 1 ]
    [[ "$output" == *'Mute state unavailable'* && "$output" != *'Active'* ]]
}

@test "recovery suspension still bypasses challenges and preserves an unavailable saved lock" {
    mkfifo "$TAVS_RUNTIME_DIR/lock.state"
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="true"\n' > "$HOME/.tavs/visual-restrictions.state"
    _LS_READ_STATUS=unavailable
    _tavs_challenge_verify() { : > "$TEST_DIR/challenged"; return 1; }
    run _lock_unlock --for 15m
    [ "$status" -eq 0 ]
    [[ "$output" == *'suspended'* && "$output" == *'saved lock'* ]]
    run _schedule_challenge_gate
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_DIR/challenged" ]
    [ -p "$TAVS_RUNTIME_DIR/lock.state" ]
}

@test "static lock and schedule help do not inspect policy storage" {
    _tavs_lock_read() { : > "$TEST_DIR/read-called"; return 2; }
    run cmd_lock --help
    [ "$status" -eq 0 ]
    run cmd_schedule --help
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_DIR/read-called" ]
}
