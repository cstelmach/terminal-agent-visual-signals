#!/usr/bin/env bats
# ==============================================================================
# Contract test: CLI validator and Swift validator must agree on all fixtures.
# SPEC T4.2 — feeds valid + malformed JSONs to both, asserts exit codes match.
# ==============================================================================

setup_file() {
    export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export SWIFT_PKG="$REPO_ROOT/src/macos/TAVSApp"

    if ! command -v swift &>/dev/null; then
        skip "swift not available"
    fi

    swift build -c release --package-path "$SWIFT_PKG" 2>/dev/null
    export SWIFT_BIN="$SWIFT_PKG/.build/release/TAVSApp"

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
