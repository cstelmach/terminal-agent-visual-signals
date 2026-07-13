#!/usr/bin/env bats
# ==============================================================================
# Unit tests for src/cli/cmd-lock.sh + src/core/lock-state-lib.sh
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)
    TEST_HOME="$TEST_DIR/home"
    TEST_RUNTIME="$TEST_DIR/runtime"
    mkdir -p "$TEST_HOME/.tavs" "$TEST_RUNTIME"

    export HOME="$TEST_HOME"
    export TAVS_RUNTIME_DIR="$TEST_RUNTIME"
    export CLI_DIR="$REPO_ROOT/src/cli"
    export TAVS_ROOT="$REPO_ROOT"

    source "$CLI_DIR/cmd-lock.sh"
    NOW=$(date +%s)
}

teardown() {
    rm -rf "$TEST_DIR"
}

state_value() {
    # state_value <KEY>
    grep "^$1=" "$TEST_RUNTIME/lock.state" | cut -d'"' -f2
}

# --- Duration parser ---

@test "duration: 15m, 2h, 2h30m, 1d, 90m parse to seconds" {
    [ "$(_lock_parse_duration 15m)" -eq 900 ]
    [ "$(_lock_parse_duration 2h)" -eq 7200 ]
    [ "$(_lock_parse_duration 2h30m)" -eq 9000 ]
    [ "$(_lock_parse_duration 1d)" -eq 86400 ]
    [ "$(_lock_parse_duration 90m)" -eq 5400 ]
}

@test "duration: garbage, empty, zero, unitless are rejected" {
    ! _lock_parse_duration "soon"
    ! _lock_parse_duration ""
    ! _lock_parse_duration "0m"
    ! _lock_parse_duration "90"
    ! _lock_parse_duration "2x"
    ! _lock_parse_duration "-5m"
}

# --- tavs lock now ---

@test "lock now writes manual lock with finite expiry (default 1h)" {
    run cmd_lock now
    [ "$status" -eq 0 ]
    [ "$(state_value LOCKED)" = "true" ]
    [ "$(state_value REASON)" = "manual" ]
    local until
    until=$(state_value LOCK_UNTIL_EPOCH)
    (( until >= NOW + 3590 && until <= NOW + 3610 ))
    [ "$(state_value UNLOCK_UNTIL_EPOCH)" = "0" ]
    [ "$(state_value SCHEMA_VERSION)" = "1" ]
}

@test "lock now --for 2h sets a two-hour expiry" {
    run cmd_lock now --for 2h
    [ "$status" -eq 0 ]
    local until
    until=$(state_value LOCK_UNTIL_EPOCH)
    (( until >= NOW + 7190 && until <= NOW + 7210 ))
}

@test "lock now rejects invalid duration" {
    run cmd_lock now --for banana
    [ "$status" -ne 0 ]
    [ ! -f "$TEST_RUNTIME/lock.state" ]
}

@test "lock now keeps the LATER end of an existing lock (merge max)" {
    run cmd_lock now --for 4h
    local first_until
    first_until=$(state_value LOCK_UNTIL_EPOCH)
    run cmd_lock now --for 1h
    [ "$status" -eq 0 ]
    [ "$(state_value LOCK_UNTIL_EPOCH)" = "$first_until" ]
}

@test "lock now extends a shorter existing lock" {
    run cmd_lock now --for 1h
    run cmd_lock now --for 4h
    local until
    until=$(state_value LOCK_UNTIL_EPOCH)
    (( until >= NOW + 14390 && until <= NOW + 14410 ))
}

@test "lock now cancels an active unlock grant" {
    source "$TAVS_ROOT/src/core/lock-state-lib.sh"
    _tavs_lock_write "true" "manual" "$(( NOW + 7200 ))" "$(( NOW + 600 ))" "#111111" ""
    run cmd_lock now --for 1h
    [ "$status" -eq 0 ]
    [ "$(state_value UNLOCK_UNTIL_EPOCH)" = "0" ]
}

@test "lock now resolves colors from user.conf pause keys" {
    printf 'TAVS_PAUSE_BG_DARK="#123456"\n' > "$TEST_HOME/.tavs/user.conf"
    run cmd_lock now
    [ "$(state_value LOCK_BG)" = "#123456" ]
}

@test "lock now falls back to #3A3A3A without user.conf" {
    run cmd_lock now
    [ "$(state_value LOCK_BG)" = "#3A3A3A" ]
}

# --- tavs lock status ---

@test "lock status reports effective lock and remaining time" {
    run cmd_lock now --for 30m
    run cmd_lock status
    [ "$status" -eq 0 ]
    [[ "$output" == *"LOCKED:       true"* ]]
    [[ "$output" == *"min remaining"* ]]
    [[ "$output" == *"Effective: LOCKED"* ]]
}

@test "lock status reports no lock cleanly" {
    run cmd_lock status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Lock: none"* ]]
}

@test "lock status treats expired lock as not effective" {
    source "$TAVS_ROOT/src/core/lock-state-lib.sh"
    _tavs_lock_write "true" "manual" "$(( NOW - 10 ))" "0" "#111111" ""
    run cmd_lock status
    [ "$status" -eq 0 ]
    [[ "$output" == *"expired"* ]]
    [[ "$output" == *"Effective: not locked"* ]]
}

# --- Predicate library ---

@test "predicate: grant suspends, grant expiry re-locks" {
    source "$TAVS_ROOT/src/core/lock-state-lib.sh"
    _tavs_lock_write "true" "manual" "$(( NOW + 3600 ))" "$(( NOW + 600 ))" "" ""
    ! _tavs_lock_effective "$NOW"
    _tavs_lock_effective "$(( NOW + 700 ))"
}

@test "predicate: malformed LOCK_UNTIL means not locked" {
    printf 'LOCKED="true"\nLOCK_UNTIL_EPOCH="soon"\nSCHEMA_VERSION="1"\n' > "$TEST_RUNTIME/lock.state"
    source "$TAVS_ROOT/src/core/lock-state-lib.sh"
    ! _tavs_lock_effective "$NOW"
}
