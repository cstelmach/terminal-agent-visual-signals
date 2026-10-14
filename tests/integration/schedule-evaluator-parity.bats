#!/usr/bin/env bats
# ==============================================================================
# Contract test: CLI validator and Swift validator must agree on all fixtures.
# SPEC T4.2 — feeds valid + malformed JSONs to both, asserts exit codes match.
# ==============================================================================

setup_file() {
    export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    [[ -n "${TAVS_TEST_ROOT:-}" && "${TAVS_TEST_HELPER_BIN:-}" == /* && -x "$TAVS_TEST_HELPER_BIN" ]]
    export SWIFT_BIN="$TAVS_TEST_HELPER_BIN"

    export FIXTURE_DIR="$(mktemp -d)"
    _create_fixtures
}

teardown_file() {
    rm -rf "$FIXTURE_DIR"
}

setup() {
    TEST_HOME=$(mktemp -d)
    mkdir -p "$TEST_HOME/.tavs"
    export HOME="$TEST_HOME"
    export TAVS_ROOT="$REPO_ROOT"
    export CLI_DIR="$REPO_ROOT/src/cli"
    # Isolated runtime dir: a real hard lock would challenge-gate the
    # schedule add-window calls in the atomicity test.
    export TAVS_RUNTIME_DIR="$TEST_HOME/runtime"
    mkdir -p "$TAVS_RUNTIME_DIR"
}

teardown() {
    rm -rf "$TEST_HOME"
}

_create_fixtures() {
    # --- VALID fixtures (both validators should exit 0) ---

    cat > "$FIXTURE_DIR/valid-canonical.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"wk","enabled":true,"days":["mon","tue","wed","thu","fri"],"start":"08:00","end":"20:00"}],"quiet_periods":[{"id":"hourly","enabled":true,"kind":"hourly","start_minute":50,"end_minute":59}]}
EOF

    cat > "$FIXTURE_DIR/valid-master-false-empty.json" << 'EOF'
{"version":1,"master_active":false,"allowed_windows":[],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/valid-disabled-window.json" << 'EOF'
{"version":1,"master_active":false,"allowed_windows":[{"id":"x","enabled":false,"days":[],"start":"99:99","end":"99:99"}],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/valid-overnight.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"night","enabled":true,"days":["fri"],"start":"22:00","end":"02:00"}],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/valid-fixed-daily.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"wk","enabled":true,"days":["mon"],"start":"08:00","end":"20:00"}],"quiet_periods":[{"id":"lunch","enabled":true,"kind":"fixed_daily","start":"12:00","end":"13:00"}]}
EOF

    cat > "$FIXTURE_DIR/valid-hard-flags.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"wk","enabled":true,"days":["mon"],"start":"08:00","end":"20:00","hard":true}],"quiet_periods":[{"id":"lunch","enabled":true,"kind":"fixed_daily","start":"12:00","end":"13:00","hard":true}]}
EOF

    cat > "$FIXTURE_DIR/valid-wrapping-minutes.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"wk","enabled":true,"days":["mon"],"start":"08:00","end":"20:00"}],"quiet_periods":[{"id":"wrap","enabled":true,"kind":"hourly","start_minute":55,"end_minute":5}]}
EOF

    # --- INVALID fixtures (both validators should exit non-zero) ---

    cat > "$FIXTURE_DIR/invalid-master-active-empty-windows.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/invalid-empty-id.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"","enabled":true,"days":["mon"],"start":"08:00","end":"20:00"}],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/invalid-empty-days.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"x","enabled":true,"days":[],"start":"08:00","end":"20:00"}],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/invalid-bad-hour.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"x","enabled":true,"days":["mon"],"start":"25:00","end":"20:00"}],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/invalid-bad-minute.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"x","enabled":true,"days":["mon"],"start":"08:60","end":"20:00"}],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/invalid-zero-length-window.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"x","enabled":true,"days":["mon"],"start":"08:00","end":"08:00"}],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/invalid-single-digit-time.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"x","enabled":true,"days":["mon"],"start":"8:00","end":"20:00"}],"quiet_periods":[]}
EOF

    cat > "$FIXTURE_DIR/invalid-minute-range.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"wk","enabled":true,"days":["mon"],"start":"08:00","end":"20:00"}],"quiet_periods":[{"id":"bad","enabled":true,"kind":"hourly","start_minute":60,"end_minute":59}]}
EOF

    cat > "$FIXTURE_DIR/invalid-zero-length-quiet.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"wk","enabled":true,"days":["mon"],"start":"08:00","end":"20:00"}],"quiet_periods":[{"id":"dup","enabled":true,"kind":"fixed_daily","start":"12:00","end":"12:00"}]}
EOF

    cat > "$FIXTURE_DIR/invalid-quiet-empty-id.json" << 'EOF'
{"version":1,"master_active":true,"allowed_windows":[{"id":"wk","enabled":true,"days":["mon"],"start":"08:00","end":"20:00"}],"quiet_periods":[{"id":"","enabled":true,"kind":"hourly","start_minute":0,"end_minute":5}]}
EOF
}

_run_swift_validator() {
    "$SWIFT_BIN" --validate-config "$1" 2>/dev/null
}

_run_cli_validator() {
    source "$CLI_DIR/cmd-schedule.sh"
    local json
    json=$(cat "$1")
    _schedule_validate "$json" 2>/dev/null
}

@test "parity: enabled quiet rows reject either or both missing selected bounds" {
    local kind field other json missing
    for kind in hourly fixed_daily; do
        if [[ "$kind" == hourly ]]; then
            json='{"id":"q","enabled":true,"kind":"hourly","start_minute":50,"end_minute":59,"start":"12:00","end":"13:00"}'
            field=start_minute; other=end_minute
        else
            json='{"id":"q","enabled":true,"kind":"fixed_daily","start":"12:00","end":"13:00","start_minute":50,"end_minute":59}'
            field=start; other=end
        fi
        for missing in "$field" "$other" both; do
            jq --arg field "$field" --arg other "$other" --arg missing "$missing" \
                'if $missing == "both" then del(.[$field], .[$other]) else del(.[$missing]) end
                | {version:1, master_active:false, allowed_windows:[], quiet_periods:[.]}' \
                <<< "$json" > "$FIXTURE_DIR/missing.json"
            run _run_swift_validator "$FIXTURE_DIR/missing.json"
            [ "$status" -ne 0 ]
            run _run_cli_validator "$FIXTURE_DIR/missing.json"
            [ "$status" -ne 0 ]
        done
    done
}

@test "parity: disabled incomplete quiet rows and complete edge bounds pass" {
    cat > "$FIXTURE_DIR/quiet-edges.json" <<'EOF'
{"version":1,"master_active":false,"allowed_windows":[],"quiet_periods":[{"id":"disabled-hourly","enabled":false,"kind":"hourly"},{"id":"disabled-daily","enabled":false,"kind":"fixed_daily"},{"id":"one-minute","enabled":true,"kind":"hourly","start_minute":0,"end_minute":0},{"id":"wrap","enabled":true,"kind":"hourly","start_minute":55,"end_minute":5},{"id":"night","enabled":true,"kind":"fixed_daily","start":"23:00","end":"01:00"}]}
EOF
    run _run_swift_validator "$FIXTURE_DIR/quiet-edges.json"
    [ "$status" -eq 0 ]
    run _run_cli_validator "$FIXTURE_DIR/quiet-edges.json"
    [ "$status" -eq 0 ]
}

@test "resume: incomplete quiet rule fails without changing saved configuration" {
    cat > "$HOME/.tavs/schedule.json" <<'EOF'
{"version":1,"master_active":false,"allowed_windows":[],"quiet_periods":[{"id":"incomplete","enabled":true,"kind":"hourly","start_minute":50}]}
EOF
    cp "$HOME/.tavs/schedule.json" "$BATS_TEST_TMPDIR/original.json"
    run "$REPO_ROOT/tavs" schedule resume
    [ "$status" -ne 0 ]
    run cmp "$BATS_TEST_TMPDIR/original.json" "$HOME/.tavs/schedule.json"
    [ "$status" -eq 0 ]
}

@test "resume: empty-window bootstrap retains its documented warning" {
    printf '%s\n' '{"version":1,"master_active":false,"allowed_windows":[],"quiet_periods":[]}' > "$HOME/.tavs/schedule.json"
    run "$REPO_ROOT/tavs" schedule resume
    [ "$status" -eq 0 ]
    [[ "$output" == *"no enabled windows"* ]]
    run jq -e '.master_active == true' "$HOME/.tavs/schedule.json"
    [ "$status" -eq 0 ]
}

# --- Valid fixtures: both must exit 0 ---

@test "parity: valid-canonical — both pass" {
    run _run_swift_validator "$FIXTURE_DIR/valid-canonical.json"
    [ "$status" -eq 0 ]
    run _run_cli_validator "$FIXTURE_DIR/valid-canonical.json"
    [ "$status" -eq 0 ]
}

@test "parity: valid-hard-flags — both pass" {
    run _run_swift_validator "$FIXTURE_DIR/valid-hard-flags.json"
    [ "$status" -eq 0 ]
    run _run_cli_validator "$FIXTURE_DIR/valid-hard-flags.json"
    [ "$status" -eq 0 ]
}

@test "parity: valid-master-false-empty — both pass" {
    run _run_swift_validator "$FIXTURE_DIR/valid-master-false-empty.json"
    [ "$status" -eq 0 ]
    run _run_cli_validator "$FIXTURE_DIR/valid-master-false-empty.json"
    [ "$status" -eq 0 ]
}

@test "parity: valid-disabled-window — both pass" {
    run _run_swift_validator "$FIXTURE_DIR/valid-disabled-window.json"
    [ "$status" -eq 0 ]
    run _run_cli_validator "$FIXTURE_DIR/valid-disabled-window.json"
    [ "$status" -eq 0 ]
}

@test "parity: valid-overnight — both pass" {
    run _run_swift_validator "$FIXTURE_DIR/valid-overnight.json"
    [ "$status" -eq 0 ]
    run _run_cli_validator "$FIXTURE_DIR/valid-overnight.json"
    [ "$status" -eq 0 ]
}

@test "parity: valid-fixed-daily — both pass" {
    run _run_swift_validator "$FIXTURE_DIR/valid-fixed-daily.json"
    [ "$status" -eq 0 ]
    run _run_cli_validator "$FIXTURE_DIR/valid-fixed-daily.json"
    [ "$status" -eq 0 ]
}

@test "parity: valid-wrapping-minutes — both pass" {
    run _run_swift_validator "$FIXTURE_DIR/valid-wrapping-minutes.json"
    [ "$status" -eq 0 ]
    run _run_cli_validator "$FIXTURE_DIR/valid-wrapping-minutes.json"
    [ "$status" -eq 0 ]
}

# --- Invalid fixtures: both must exit non-zero ---

@test "parity: invalid-master-active-empty-windows — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-master-active-empty-windows.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-master-active-empty-windows.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-empty-id — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-empty-id.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-empty-id.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-empty-days — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-empty-days.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-empty-days.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-bad-hour — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-bad-hour.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-bad-hour.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-bad-minute — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-bad-minute.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-bad-minute.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-zero-length-window — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-zero-length-window.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-zero-length-window.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-single-digit-time — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-single-digit-time.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-single-digit-time.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-minute-range — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-minute-range.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-minute-range.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-zero-length-quiet — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-zero-length-quiet.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-zero-length-quiet.json"
    [ "$status" -ne 0 ]
}

@test "parity: invalid-quiet-empty-id — both fail" {
    run _run_swift_validator "$FIXTURE_DIR/invalid-quiet-empty-id.json"
    [ "$status" -ne 0 ]
    run _run_cli_validator "$FIXTURE_DIR/invalid-quiet-empty-id.json"
    [ "$status" -ne 0 ]
}

# --- Atomic write concurrency test ---

@test "atomic: concurrent add-window leaves file always valid JSON" {
    run "$REPO_ROOT/tavs" schedule add-window --days mon --start 08:00 --end 20:00
    [ "$status" -eq 0 ]
    for i in 1 2 3 4 5; do
        "$REPO_ROOT/tavs" schedule add-window --days tue --start 09:00 --end "1${i}:00" --id "w${i}" &
    done
    wait
    run jq -e . "$HOME/.tavs/schedule.json"
    [ "$status" -eq 0 ]
}
