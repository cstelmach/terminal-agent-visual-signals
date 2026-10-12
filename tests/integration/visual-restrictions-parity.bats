#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.tavs"
    LIB="$REPO_ROOT/src/core/visual-restrictions-state.sh"
    MARKER="$HOME/.tavs/visual-restrictions.state"
    export CFFIXED_USER_HOME="$HOME" TAVS_RUNTIME_DIR="$BATS_TEST_TMPDIR/runtime"
    export TAVS_TMP_DIR="$BATS_TEST_TMPDIR/state" _TAVS_TMP_DIR="$BATS_TEST_TMPDIR/state"
    export TTY_DEVICE="$TAVS_TEST_ROOT/phase5-$BATS_TEST_NUMBER.tty"
    mkdir -p "$TAVS_RUNTIME_DIR" "$TAVS_TMP_DIR"
    : > "$TTY_DEVICE"
    run "$TAVS_TEST_HELPER_BIN" --validate-config --visual-restrictions-capabilities
    [ "$status" -eq 0 ]
    [ "$output" = tavs-visual-restrictions-schema=1 ]
}

_write_overlapping_rules() {
    local now until
    now=$(date +%s); until=$((now + 3600))
    cat > "$TAVS_RUNTIME_DIR/lock.state" <<RULES
LOCKED="true"
REASON="manual"
LOCK_UNTIL_EPOCH="$until"
UNLOCK_UNTIL_EPOCH="0"
LOCK_BG="#112233"
LOCK_FG=""
SCHEMA_VERSION="1"
RULES
    cat > "$HOME/.tavs/mute.state" <<RULES
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$now"
APP_PID="$$"
SCHEMA_VERSION="1"
RULES
}

@test "Swift and shell consume each other's persisted marker" {
    source "$LIB"
    _tavs_visual_restrictions_write true
    run "$TAVS_TEST_HELPER_BIN" --visual-restrictions-read "$MARKER"
    [ "$status" -eq 0 ]
    [ "$output" = suspended ]
    run "$TAVS_TEST_HELPER_BIN" --visual-restrictions-write "$MARKER" false
    [ "$status" -eq 0 ]
    _tavs_visual_restrictions_read
    [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = active ]
    run "$TAVS_TEST_HELPER_BIN" --visual-restrictions-write "$MARKER" true
    [ "$status" -eq 0 ]
    _tavs_visual_restrictions_read
    [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = suspended ]
}

@test "Swift classifications match the shared fixtures including malformed markers" {
    python3 - "$REPO_ROOT/tests/fixtures/visual-restrictions-state.json" "$BATS_TEST_TMPDIR" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[2])
for case in json.load(open(sys.argv[1]))['cases']:
    if case['text'] is not None:(root/case['name']).write_bytes(case['text'].encode())
    with (root/'expected.tsv').open('a') as out:out.write(case['name']+'\t'+case['expected']+'\n')
PY
    local name expected
    while IFS=$'\t' read -r name expected; do
        run "$TAVS_TEST_HELPER_BIN" --visual-restrictions-read "$BATS_TEST_TMPDIR/$name"
        [ "$output" = "$expected" ]
        if [[ "$expected" == unavailable ]]; then [ "$status" -eq 1 ]; else [ "$status" -eq 0 ]; fi
    done < "$BATS_TEST_TMPDIR/expected.tsv"
}

@test "headless state verbs precede invalid isolated UI launch settings" {
    run env TAVS_SESSIONS_TEST_ROOT=/invalid "$TAVS_TEST_HELPER_BIN" --visual-restrictions-write "$MARKER" true
    [ "$status" -eq 0 ]
    run env TAVS_SESSIONS_TEST_ROOT=/invalid "$TAVS_TEST_HELPER_BIN" --visual-restrictions-read "$MARKER"
    [ "$status" -eq 0 ]
    [ "$output" = suspended ]
}

@test "real trigger bypasses overlapping lock and mute while preserving definitions and intent" {
    _write_overlapping_rules
    cp "$TAVS_RUNTIME_DIR/lock.state" "$BATS_TEST_TMPDIR/lock.before"
    cp "$HOME/.tavs/mute.state" "$BATS_TEST_TMPDIR/mute.before"
    source "$LIB"
    _tavs_visual_restrictions_write true
    printf 'TAVS_TITLE_MODE="off"\nENABLE_STYLISH_BACKGROUNDS="false"\n' > "$HOME/.tavs/user.conf"
    run bash "$REPO_ROOT/src/core/trigger.sh" processing
    [ "$status" -eq 0 ]
    [ -s "$TTY_DEVICE" ]
    cmp "$TAVS_RUNTIME_DIR/lock.state" "$BATS_TEST_TMPDIR/lock.before"
    cmp "$HOME/.tavs/mute.state" "$BATS_TEST_TMPDIR/mute.before"
    python3 - "$TAVS_RUNTIME_DIR" "$TTY_DEVICE" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])
assert b'\x1b]11;' in pathlib.Path(sys.argv[2]).read_bytes()
assert not list((root/'pending').glob('*.osc'))
observations=list((root/'organizer').glob('observation-*.json'))
intents=list((root/'organizer').glob('intent-*.json'))
assert len(observations)==len(intents)==1
assert json.loads(observations[0].read_text())['state']=='processing'
assert json.loads(intents[0].read_text())['background'].startswith('#')
PY
}

@test "stage1 and worker checks reread suspension before inherited hard-lock flags" {
    _write_overlapping_rules
    cat > "$BATS_TEST_TMPDIR/check.sh" <<'SH'
set -e
source "$1/src/core/mute-gate.sh"
_tavs_check_mute_state
test "$_TAVS_SUPPRESS_OUTPUT" = 1
_TAVS_S0_LOCKED=true
_TAVS_S0_LOCK_UNTIL=$(( $(date +%s) + 3600 ))
_tavs_visual_restrictions_write true
_tavs_validate_mute_liveness
test "$_TAVS_SUPPRESS_OUTPUT" = 0
test -z "${_TAVS_S0_LOCKED:-}"
if _tavs_check_mute_state; then exit 1; fi
test "$_TAVS_SUPPRESS_OUTPUT" = 0
_tavs_visual_restrictions_write false
_tavs_check_mute_state
test "$_TAVS_SUPPRESS_OUTPUT" = 1
SH
    run bash "$BATS_TEST_TMPDIR/check.sh" "$REPO_ROOT"
    [ "$status" -eq 0 ]
}

@test "debug mute logging uses the injected runtime instead of a fixed shared tmp file" {
    run grep -F 'local log="/tmp/tavs-mute-trace.log"' "$REPO_ROOT/src/core/mute-gate.sh"
    [ "$status" -eq 1 ]
    run bash -c 'source "$1/src/core/mute-gate.sh"; DEBUG_ALL=1; _tavs_debug_mute "fixed-event"' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ -s "$TAVS_RUNTIME_DIR/mute-trace.log" ]
}
