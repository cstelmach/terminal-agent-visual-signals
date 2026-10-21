#!/usr/bin/env bats
# ==============================================================================
# Integration: fail-closed lock gate through the full trigger.sh dispatch
# ==============================================================================
# The defining property (spec D3): an unexpired lock suppresses ordinary paint
# even when every mute-side liveness check fails (dead APP_PID, stale
# heartbeat, absent mute.state). Expiry always wins; a grant suspends.
# Runs the real trigger and helper on an owned PTY: managed output paints only
# real terminal devices and never buffers suppressed bytes in pending/*.osc.
# ==============================================================================

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" && "${TAVS_TEST_HELPER_BIN:-}" == /* \
        && -x "$TAVS_TEST_HELPER_BIN" ]] || return 1
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export CASE_DIR="$TAVS_TEST_ROOT/lock-gate-$BATS_TEST_NUMBER"
    export HOME="$CASE_DIR/home" CFFIXED_USER_HOME="$CASE_DIR/home" ZDOTDIR="$CASE_DIR/home"
    export TAVS_RUNTIME_DIR="$CASE_DIR/runtime" TAVS_TMP_DIR="$CASE_DIR/state"
    export _TAVS_TMP_DIR="$TAVS_TMP_DIR" TMPDIR="$CASE_DIR/tmp" TAVS_AGENT=claude
    mkdir -p "$HOME/.tavs" "$TAVS_RUNTIME_DIR" "$TAVS_TMP_DIR" "$TMPDIR"
    cat > "$HOME/.tavs/user.conf" <<'EOF'
THEME_MODE="static"
FORCE_MODE="dark"
ENABLE_MODE_AWARE_PROCESSING="false"
CLAUDE_DARK_PROCESSING="#112233"
TAVS_TITLE_MODE="off"
ENABLE_STYLISH_BACKGROUNDS="false"
EOF
    NOW=$(date +%s)
}

write_lock() {
    # write_lock <lock_until> <unlock_until>
    cat > "$TAVS_RUNTIME_DIR/lock.state" <<EOF
LOCKED="true"
REASON="manual"
LOCK_UNTIL_EPOCH="$1"
UNLOCK_UNTIL_EPOCH="$2"
WRITTEN_EPOCH="$NOW"
LOCK_BG="#3A3A3A"
LOCK_FG=""
SCHEMA_VERSION="1"
EOF
}

write_mute() {
    # write_mute <written_epoch> <app_pid>
    cat > "$HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$1"
APP_PID="$2"
SCHEMA_VERSION="1"
EOF
}

# Run the real processing trigger on an owned PTY and print everything it wrote there.
run_trigger() {
    run python3 - "$REPO_ROOT" <<'PY'
import errno,os,pty,select,signal,sys,time
pid,fd=pty.fork()
if pid==0:
    os.environ['TTY_DEVICE']=os.ttyname(0)
    os.execv('/bin/bash',['bash','-p',sys.argv[1]+'/src/core/trigger.sh','processing'])
status=None; output=bytearray(); deadline=time.monotonic()+15
try:
    while time.monotonic()<deadline:
        if select.select([fd],[],[],.05)[0]:
            try:output.extend(os.read(fd,4096))
            except OSError as error:
                if error.errno!=errno.EIO:raise
        got,code=os.waitpid(pid,os.WNOHANG)
        if got:status=code;break
    assert status is not None,'Owned trigger exceeded deadline'
    print(output.decode(errors='replace'),end='')
    sys.exit(os.waitstatus_to_exitcode(status))
finally:
    if status is None:os.kill(pid,signal.SIGKILL);os.waitpid(pid,0)
    os.close(fd)
PY
    [ "$status" -eq 0 ]
    [ -z "$(find "$TAVS_RUNTIME_DIR/pending" -type f -name '*.osc' 2>/dev/null)" ]
}

# A suppressed dispatch shows the lock's own background instead of the ordinary style.
assert_suppressed() { [[ "$output" != *'#112233'* && "$output" == *']11;#3A3A3A'* ]]; }
assert_painted() { [[ "$output" == *$'\033]11;#112233'* ]]; }

@test "unexpired lock suppresses with NO mute.state at all" {
    write_lock $(( NOW + 300 )) 0
    run_trigger
    assert_suppressed
}

@test "unexpired lock suppresses despite dead APP_PID (fail-closed core)" {
    write_lock $(( NOW + 300 )) 0
    write_mute "$NOW" 999999
    run_trigger
    assert_suppressed
}

@test "unexpired lock suppresses despite stale heartbeat" {
    write_lock $(( NOW + 300 )) 0
    write_mute $(( NOW - 600 )) $$
    run_trigger
    assert_suppressed
}

@test "expired lock releases (bytes reach the TTY)" {
    write_lock $(( NOW - 10 )) 0
    run_trigger
    assert_painted
}

@test "active grant releases the lock" {
    write_lock $(( NOW + 300 )) $(( NOW + 120 ))
    run_trigger
    assert_painted
}

@test "expired grant re-locks" {
    write_lock $(( NOW + 300 )) $(( NOW - 5 ))
    run_trigger
    assert_suppressed
}

@test "malformed LOCK_UNTIL releases (no indefinite locks, D3)" {
    cat > "$TAVS_RUNTIME_DIR/lock.state" <<EOF
LOCKED="true"
LOCK_UNTIL_EPOCH="whenever"
SCHEMA_VERSION="1"
EOF
    run_trigger
    assert_painted
}

@test "dead-PID mute WITHOUT a lock stays fail-open (regression guard)" {
    write_mute "$NOW" 999999
    run_trigger
    assert_painted
}

@test "TAVS_STATUS=false wins over an unexpired lock for agent signals" {
    write_lock $(( NOW + 300 )) 0
    TAVS_STATUS=false run_trigger
    [ -z "$output" ]
}

@test "idle-worker check honors the lock (_tavs_check_mute_state)" {
    write_lock $(( NOW + 300 )) 0
    source "$REPO_ROOT/src/core/mute-gate.sh"
    _tavs_check_mute_state
    [ "$_TAVS_SUPPRESS_OUTPUT" = "1" ]
}

@test "idle-worker check releases on expired lock without mute.state" {
    write_lock $(( NOW - 10 )) 0
    source "$REPO_ROOT/src/core/mute-gate.sh"
    if _tavs_check_mute_state; then
        false
    fi
    [ "$_TAVS_SUPPRESS_OUTPUT" = "0" ]
}

@test "no lock paints ordinary processing (control)" {
    run_trigger
    assert_painted
}

@test "ordinary dispatch caches its terminal target for later broadcasts" {
    run_trigger
    assert_painted
    [ -n "$(find "$TAVS_RUNTIME_DIR/organizer/targets" -name target.json 2>/dev/null)" ]
    [ ! -e "$TAVS_RUNTIME_DIR/active-ttys" ]
}
