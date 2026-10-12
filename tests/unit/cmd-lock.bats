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

    pgrep() { return 1; }

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

write_visual_suspension() {
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="%s"\n' "$1" \
        > "$TEST_HOME/.tavs/visual-restrictions.state"
}

@test "suspension: effective predicate reads fresh state without changing lock or grant" {
    _tavs_lock_write true manual "$((NOW + 3600))" "$((NOW + 60))" '#111111' ''
    cp "$TEST_RUNTIME/lock.state" "$TEST_DIR/lock.before"
    write_visual_suspension true
    if _tavs_lock_effective "$((NOW + 120))"; then return 1; fi
    [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = suspended ]
    cmp "$TEST_DIR/lock.before" "$TEST_RUNTIME/lock.state"
    write_visual_suspension false
    _tavs_lock_effective "$((NOW + 120))"
    [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = active ]
    cmp "$TEST_DIR/lock.before" "$TEST_RUNTIME/lock.state"
}

@test "suspension: newly requested locks are saved and explicitly inert" {
    write_visual_suspension true
    run cmd_lock now --for 30m
    [ "$status" -eq 0 ]
    [ "$(state_value LOCKED)" = true ]
    [[ "$output" == *'Lock saved until'* && "$output" == *'visual restrictions are suspended'* ]]
    [[ "$output" != *'engaged'* && "$output" != *'will paint'* && "$output" != *'challenge required'* ]]
    if _tavs_lock_effective "$NOW"; then return 1; fi
}

@test "suspension: lock status remains visible even without a saved lock" {
    write_visual_suspension true
    run cmd_lock status
    [ "$status" -eq 0 ]
    [[ "$output" == *'Visual restrictions: suspended'* && "$output" == *'Lock: none'* ]]
}

@test "suspension: lock status shows saved definition and inert effective state" {
    _tavs_lock_write true manual "$((NOW + 3600))" 0 '#111111' ''
    cp "$TEST_RUNTIME/lock.state" "$TEST_DIR/lock.before"
    write_visual_suspension true
    run cmd_lock status
    [ "$status" -eq 0 ]
    [[ "$output" == *'LOCKED:       true'* && "$output" == *'Effective: not locked'* ]]
    [[ "$output" == *'Visual restrictions: suspended'* ]]
    cmp "$TEST_DIR/lock.before" "$TEST_RUNTIME/lock.state"
}

@test "suspension: unlock bypasses challenge and preserves saved definitions" {
    _tavs_lock_write true manual "$((NOW + 3600))" 0 '#111111' ''
    cp "$TEST_RUNTIME/lock.state" "$TEST_DIR/lock.before"
    _tavs_challenge_verify() { : > "$TEST_DIR/challenge-called"; return 1; }
    write_visual_suspension true
    run _lock_unlock --for 15m
    [ "$status" -eq 0 ]
    [[ "$output" == *'suspended'* && "$output" == *'saved lock'* ]]
    [ ! -e "$TEST_DIR/challenge-called" ]
    cmp "$TEST_DIR/lock.before" "$TEST_RUNTIME/lock.state"
}

@test "suspension: schedule mutation predicate bypasses challenge without changing definitions" {
    source "$CLI_DIR/cmd-schedule.sh"
    _tavs_challenge_verify() { : > "$TEST_DIR/challenge-called"; return 1; }
    _tavs_lock_write true manual "$((NOW + 3600))" 0 '#111111' ''
    printf '%s\n' '{"version":1,"master_active":true,"quiet_periods":[]}' > "$SCHEDULE_FILE"
    cp "$SCHEDULE_FILE" "$TEST_DIR/schedule.before"
    cp "$TEST_RUNTIME/lock.state" "$TEST_DIR/lock.before"
    write_visual_suspension true
    run _schedule_challenge_gate
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_DIR/challenge-called" ]
    cmp "$TEST_DIR/lock.before" "$TEST_RUNTIME/lock.state"
    cmp "$TEST_DIR/schedule.before" "$SCHEDULE_FILE"
}

@test "unavailable: malformed persistent state disables locks without executing marker text" {
    _tavs_lock_write true manual "$((NOW + 3600))" 0 '#111111' ''
    cp "$TEST_RUNTIME/lock.state" "$TEST_DIR/lock.before"
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="$(touch "%s")"\n' \
        "$TEST_DIR/MARKER_BODY_SENTINEL" > "$TEST_HOME/.tavs/visual-restrictions.state"
    if _tavs_lock_effective "$NOW"; then return 1; fi
    [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = unavailable ]
    run cmd_lock status
    [ "$status" -eq 0 ]
    [[ "$output" == *'unavailable'* && "$output" == *'restrictive visuals disabled'* ]]
    [[ "$output" != *'MARKER_BODY_SENTINEL'* ]]
    [ ! -e "$TEST_DIR/MARKER_BODY_SENTINEL" ]
    cmp "$TEST_DIR/lock.before" "$TEST_RUNTIME/lock.state"
}

@test "unavailable: new lock remains saved without claiming paint" {
    printf 'SCHEMA_VERSION="9"\nSUSPENDED="false"\n' > "$TEST_HOME/.tavs/visual-restrictions.state"
    run cmd_lock now --for 30m
    [ "$status" -eq 0 ]
    [ "$(state_value LOCKED)" = true ]
    [[ "$output" == *'Lock saved until'* && "$output" == *'unavailable'* ]]
    [[ "$output" != *'engaged'* && "$output" != *'will paint'* ]]
}

@test "status: persistent restriction state is unfiltered and malformed content is private" {
    source "$CLI_DIR/cmd-status.sh"
    write_visual_suspension true
    run cmd_status --colors
    [ "$status" -eq 0 ]
    [[ "$output" == *'Visual restrictions: suspended'* && "$output" == *'explicit resumption'* ]]
    printf 'MALFORMED_BODY_SENTINEL\n' > "$TEST_HOME/.tavs/visual-restrictions.state"
    run cmd_status --faces
    [ "$status" -eq 0 ]
    [[ "$output" == *'unavailable'* && "$output" == *'restrictive visuals disabled'* ]]
    [[ "$output" != *'MALFORMED_BODY_SENTINEL'* ]]
}
