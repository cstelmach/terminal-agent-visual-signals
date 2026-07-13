#!/usr/bin/env bats
# ==============================================================================
# Unit tests for src/cli/cmd-uninstall-macos-app.sh + login-item-doctor.sh
# ==============================================================================
# Covers the 127e648 follow-up: uninstall must NOT early-return when the app
# bundle is missing (stale debug login items can outlive the bundle), and the
# doctor must clean .build entries while never touching unrecognized ones.
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)
    TEST_HOME="$TEST_DIR/home"
    STUB_BIN="$TEST_DIR/bin"
    mkdir -p "$TEST_HOME/.tavs" "$STUB_BIN"

    export HOME="$TEST_HOME"
    export CLI_DIR="$REPO_ROOT/src/cli"
    export OSA_LOG="$TEST_DIR/osascript.log"
    export TAVS_APP_DEST_OVERRIDE="$TEST_DIR/Applications/TAVS.app"

    # osascript stub: scan mode (heredoc on stdin) vs delete mode (-e).
    cat > "$STUB_BIN/osascript" <<'STUB'
#!/bin/bash
if [[ "$1" == "-e" ]]; then
    echo "delete:$2" >> "$OSA_LOG"
    exit "${OSA_DELETE_EXIT:-0}"
fi
echo "scan" >> "$OSA_LOG"
cat > /dev/null
[[ "${OSA_SCAN_EXIT:-0}" != "0" ]] && exit "$OSA_SCAN_EXIT"
printf '%b' "${OSA_SCAN_OUTPUT:-}"
exit 0
STUB
    # pgrep stub: no TAVSApp running by default (avoids killall + sleep).
    printf '#!/bin/bash\nexit "${PGREP_EXIT:-1}"\n' > "$STUB_BIN/pgrep"
    printf '#!/bin/bash\nexit 0\n' > "$STUB_BIN/killall"
    chmod +x "$STUB_BIN"/*
    export PATH="$STUB_BIN:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

load_cmd() {
    source "$CLI_DIR/cmd-uninstall-macos-app.sh"
}

# --- Bundle missing: no early return (regression) ---

@test "bundle absent: still sweeps login items and exits 0" {
    export OSA_SCAN_OUTPUT=""
    load_cmd
    run cmd_uninstall_macos_app
    [ "$status" -eq 0 ]
    [[ "$output" == *"not installed"* ]]
    [[ "$output" == *"Checking for leftover TAVS login items"* ]]
    [[ "$output" == *"No stale TAVS login items found"* ]]
}

@test "bundle absent: removes orphaned mute.state" {
    export OSA_SCAN_OUTPUT=""
    touch "$TEST_HOME/.tavs/mute.state"
    load_cmd
    run cmd_uninstall_macos_app
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_HOME/.tavs/mute.state" ]
    [[ "$output" == *"Removed mute.state"* ]]
}

# --- Doctor classification ---

@test "doctor: healthy /Applications entry is reported OK and untouched" {
    export OSA_SCAN_OUTPUT="TAVS|/Applications/TAVS.app\n"
    load_cmd
    run cmd_uninstall_macos_app
    [ "$status" -eq 0 ]
    [[ "$output" == *"Login item OK: /Applications/TAVS.app"* ]]
    [[ "$output" == *"No stale TAVS login items found"* ]]
    ! grep -q '^delete:' "$OSA_LOG"
}

@test "doctor: stale .build entry is removed via System Events when binary is gone" {
    export OSA_SCAN_OUTPUT="TAVSApp|$TEST_DIR/repo/.build/debug/TAVSApp\n"
    load_cmd
    run cmd_uninstall_macos_app
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stale debug login item"* ]]
    [[ "$output" == *"Removed via System Events"* ]]
    grep -q '^delete:' "$OSA_LOG"
}

@test "doctor: stale .build entry prefers self-unregistration when binary exists" {
    local dbg_dir="$TEST_DIR/repo/.build/debug"
    mkdir -p "$dbg_dir"
    cat > "$dbg_dir/TAVSApp" <<'STUB'
#!/bin/bash
[[ "$1" == "--unregister-login-item" ]] && exit 0
exit 1
STUB
    chmod +x "$dbg_dir/TAVSApp"
    export OSA_SCAN_OUTPUT="TAVSApp|$dbg_dir/TAVSApp\n"
    load_cmd
    run cmd_uninstall_macos_app
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unregistered via: $dbg_dir/TAVSApp --unregister-login-item"* ]]
    ! grep -q '^delete:' "$OSA_LOG"
}

@test "doctor: unexpected entry is surfaced but never deleted" {
    export OSA_SCAN_OUTPUT="TAVSApp|/opt/elsewhere/TAVSApp\n"
    load_cmd
    run cmd_uninstall_macos_app
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unexpected TAVS login item (not touched): /opt/elsewhere/TAVSApp"* ]]
    ! grep -q '^delete:' "$OSA_LOG"
}

@test "doctor: scan failure falls back to manual guidance" {
    export OSA_SCAN_EXIT=1
    load_cmd
    run cmd_uninstall_macos_app
    [ "$status" -eq 0 ]
    [[ "$output" == *"Could not inspect login items"* ]]
}

# --- Bundle present: full flow still works and ends with a sweep ---

@test "bundle present: removes bundle, unregisters, sweeps login items" {
    local app_bin_dir="$TAVS_APP_DEST_OVERRIDE/Contents/MacOS"
    mkdir -p "$app_bin_dir"
    cat > "$app_bin_dir/TAVSApp" <<'STUB'
#!/bin/bash
[[ "$1" == "--unregister-login-item" ]] && exit 0
exit 1
STUB
    chmod +x "$app_bin_dir/TAVSApp"
    export OSA_SCAN_OUTPUT=""
    load_cmd
    run cmd_uninstall_macos_app
    [ "$status" -eq 0 ]
    [ ! -d "$TAVS_APP_DEST_OVERRIDE" ]
    [[ "$output" == *"Unregistering login item"* ]]
    [[ "$output" == *"No stale TAVS login items found"* ]]
}
