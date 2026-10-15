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

@test "decimal parser matches nonnegative Int64 boundaries across supported shells" {
    python3 - "$REPO_ROOT/src/core/visual-restrictions-state.sh" <<'PY'
import os, random, subprocess, sys
rng = random.Random(43)
values = ['', '0', '000', '08', '0009', str(2**63-1), str(2**63), str(2**64+9),
          '+1', '-1', '1+1', '1 2', '١', '9'*80]
values += ['0'*rng.randrange(5) + str(rng.getrandbits(64)) for _ in range(20)]
script = 'source "$1"; shift; for value in "$@"; do result=$(_tavs_policy_decimal "$value"); printf "%s:%s\\n" "$?" "$result"; done'
expected = []
for value in values:
    valid = bool(value) and all('0' <= c <= '9' for c in value) and int(value) <= 2**63-1
    expected.append('0:'+str(int(value)) if valid else '1:')
for shell in ['/bin/bash', '/opt/homebrew/bin/bash', '/bin/zsh']:
    if not os.access(shell, os.X_OK):
        continue
    p = subprocess.run([shell, '-fc', script, 'decimal-test', sys.argv[1], *values],
                       capture_output=True, text=True, timeout=5)
    assert p.returncode == 0, (shell, p.returncode, p.stderr)
    assert p.stdout.splitlines() == expected, (shell, p.stdout)
PY
}

@test "hard-lock predicate treats zero-prefixed expiry and grants as decimal" {
    printf 'LOCKED="true"\nLOCK_UNTIL_EPOCH="0009"\nUNLOCK_UNTIL_EPOCH="0008"\n' > "$TAVS_RUNTIME_DIR/lock.state"
    if _tavs_lock_effective 7; then return 1; fi
    _tavs_lock_effective 8
    if _tavs_lock_effective 9; then return 1; fi
}

@test "overflowing hard-lock end is invalid and overflowing optional grant is ignored" {
    printf 'LOCKED="true"\nLOCK_UNTIL_EPOCH="18446744073709551625"\n' > "$TAVS_RUNTIME_DIR/lock.state"
    if _tavs_lock_effective 8; then return 1; fi
    printf 'LOCKED="true"\nLOCK_UNTIL_EPOCH="20"\nUNLOCK_UNTIL_EPOCH="18446744073709551625"\n' > "$TAVS_RUNTIME_DIR/lock.state"
    _tavs_lock_effective 8
}

@test "mute gate uses decimal hard-lock expiry and active or expired grants" {
    printf 'LOCKED="true"\nLOCK_UNTIL_EPOCH="0%s"\n' "$((NOW + 3600))" > "$TAVS_RUNTIME_DIR/lock.state"
    _tavs_check_mute_state
    [ "$_TAVS_SUPPRESS_OUTPUT" = 1 ]
    printf 'UNLOCK_UNTIL_EPOCH="0%s"\n' "$((NOW + 600))" >> "$TAVS_RUNTIME_DIR/lock.state"
    if _tavs_check_mute_state; then return 1; fi
    [ "$_TAVS_SUPPRESS_OUTPUT" = 0 ]
    printf 'UNLOCK_UNTIL_EPOCH="0008"\n' >> "$TAVS_RUNTIME_DIR/lock.state"
    _tavs_check_mute_state
    [ "$_TAVS_SUPPRESS_OUTPUT" = 1 ]
}

@test "duration parser accepts decimal units and rejects multiplication or addition overflow" {
    [ "$(_lock_parse_duration 09m)" = 540 ]
    [ "$(_lock_parse_duration 01h08m)" = 4080 ]
    [ "$(_lock_parse_duration 153722867280912930m)" = 9223372036854775800 ]
    local invalid
    for invalid in 18446744073709551617m 153722867280912931m 153722867280912930m1m; do
        if _lock_parse_duration "$invalid"; then return 1; fi
    done
}

@test "lock now rejects an overflowing duration or absolute end before writing state" {
    local duration
    for duration in 18446744073709551617m 153722867280912930m; do
        run cmd_lock now --for "$duration"
        [ "$status" -eq 1 ]
        [ ! -e "$TAVS_RUNTIME_DIR/lock.state" ]
    done
}

@test "status handles zero prefixes and Int64 maximum without negative remaining minutes" {
    printf 'LOCKED="true"\nLOCK_UNTIL_EPOCH="0%s"\n' "$((NOW + 3600))" > "$TAVS_RUNTIME_DIR/lock.state"
    run cmd_lock status
    [ "$status" -eq 0 ]
    [[ "$output" == *'Effective: LOCKED'* && "$output" != *'value too great'* ]]
    printf 'LOCKED="true"\nLOCK_UNTIL_EPOCH="9223372036854775807"\n' > "$TAVS_RUNTIME_DIR/lock.state"
    date() { printf '0\n'; }
    _lock_format_until() { printf 'finite\n'; }
    run cmd_lock status
    [ "$status" -eq 0 ]
    [[ "$output" == *'153722867280912931 min remaining'* ]]
}

@test "portable lock merge and unlock compare normalized decimal ends" {
    printf 'LOCKED="true"\nREASON="manual"\nLOCK_UNTIL_EPOCH="0%s"\n' "$((NOW + 14400))" > "$TAVS_RUNTIME_DIR/lock.state"
    uname() { printf 'Linux\n'; }
    pgrep() { return 1; }
    _tavs_challenge_verify() { return 0; }
    run cmd_lock now --for 1h
    [ "$status" -eq 0 ]
    _tavs_lock_read
    [ "$_LS_LOCK_UNTIL" = "$((NOW + 14400))" ]
    run _lock_unlock --for 09m
    [ "$status" -eq 0 ]
    [[ "$output" == *'re-engages automatically'* && "$output" != *'value too great'* ]]
}

@test "interactive unlock choices retain their finite durations" {
    uname() { printf 'Linux\n'; }
    pgrep() { return 1; }
    date() { if [[ "$1" == +%s ]]; then printf '%s\n' "$NOW"; else command date "$@"; fi; }
    _tavs_challenge_verify() { return 0; }
    _lock_next_midnight() { printf '%s' "$((NOW + 86400))"; }
    local choice seconds
    for choice in 1 2 3 4; do
        _tavs_lock_write true manual "$((NOW + 259200))" 0 '' ''
        case "$choice" in 1) seconds=900 ;; 2) seconds=3600 ;; 3) seconds=14400 ;; 4) seconds=86400 ;; esac
        run _lock_unlock <<< "$choice"
        [ "$status" -eq 0 ]
        _tavs_lock_read
        [ "$_LS_UNLOCK_UNTIL" = "$((NOW + seconds))" ]
    done
}

@test "overflowing unlock duration preserves the existing definition and grant" {
    _tavs_lock_write true manual "$((NOW + 3600))" 0 '' ''
    cp "$TAVS_RUNTIME_DIR/lock.state" "$TEST_DIR/before-unlock"
    _tavs_challenge_verify() { return 0; }
    run _lock_unlock --for 18446744073709551617m
    [ "$status" -eq 1 ]
    cmp "$TEST_DIR/before-unlock" "$TAVS_RUNTIME_DIR/lock.state"
}

@test "unavailable clock blocks schedule edits while suspension still bypasses the gate" {
    write_lock
    printf '%s\n' '{"version":1,"master_active":false,"allowed_windows":[],"quiet_periods":[]}' > "$SCHEDULE_FILE"
    cp "$SCHEDULE_FILE" "$TEST_DIR/schedule-before"
    date() { return 1; }
    _tavs_challenge_verify() { : > "$TEST_DIR/challenged"; return 1; }
    run cmd_schedule resume
    [ "$status" -eq 1 ]
    [[ "$output" == *'Lock state unavailable'* ]]
    cmp "$TEST_DIR/schedule-before" "$SCHEDULE_FILE"
    [ ! -e "$TEST_DIR/challenged" ]
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="true"\n' > "$HOME/.tavs/visual-restrictions.state"
    run _schedule_challenge_gate
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_DIR/challenged" ]
}
