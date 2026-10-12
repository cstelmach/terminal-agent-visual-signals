#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CASE_DIR="$BATS_TEST_TMPDIR"
    export HOME="$CASE_DIR/home" CFFIXED_USER_HOME="$CASE_DIR/home"
    export TAVS_RUNTIME_DIR="$CASE_DIR/runtime" TAVS_TMP_DIR="$CASE_DIR/state"
    export _TAVS_TMP_DIR="$TAVS_TMP_DIR" TTY_DEVICE="$TAVS_TEST_ROOT/background-$BATS_TEST_NUMBER.tty"
    mkdir -p "$TAVS_RUNTIME_DIR" "$TAVS_TMP_DIR" "$HOME/.tavs"
    : > "$TTY_DEVICE"
}

@test "background helper records colors and resets even while muted" {
    cat > "$CASE_DIR/check.sh" <<'SCRIPT'
set -e
source "$1/src/core/terminal-osc-sequences.sh"
capture="$2"
_tavs_organizer_record_intent() { printf '%s\n' "$1" >> "$capture"; }
_TAVS_SUPPRESS_OUTPUT=1
_TAVS_PENDING_BUFFER="$capture.pending"
send_osc_bg '#112233'
send_osc_bg reset
test "$(cat "$capture")" = $'#112233\nreset'
test -s "$capture.pending"
SCRIPT
    run bash "$CASE_DIR/check.sh" "$REPO_ROOT" "$CASE_DIR/intents"
    [ "$status" -eq 0 ]
}

@test "stale synthetic intent does not write background bytes" {
    cat > "$CASE_DIR/check.sh" <<'SCRIPT'
set -e
source "$1/src/core/terminal-osc-sequences.sh"
_tavs_organizer_record_intent() { return 3; }
send_osc_bg '#445566'
test ! -s "$TTY_DEVICE"
SCRIPT
    run bash "$CASE_DIR/check.sh" "$REPO_ROOT"
    [ "$status" -eq 0 ]
}

@test "idle worker uses the semantic background helper for every reset and color" {
    run grep -E 'emit_osc.*(11;|111)' "$REPO_ROOT/src/core/idle-worker-background.sh"
    [ "$status" -eq 1 ]
}

@test "real core discards payload stdin and free-form debug arguments while preserving intent" {
    printf 'DEBUG_ALL=1\nTAVS_TITLE_MODE=full\n' > "$HOME/.tavs/user.conf"
    export DEBUG_ALL=1 TAVS_TITLE_MODE=off TAVS_AGENT=claude
    export _TAVS_HOOK_PAYLOAD=EXPORTED_BODY_SENTINEL
    printf '%s' '{"prompt":"PROMPT_BODY_SENTINEL","tool_input":{"x":"TOOL_BODY_SENTINEL"},"permission_mode":"plan","session_id":"fixture","cwd":"/fixture","hook_event_name":"PermissionRequest"}' > "$CASE_DIR/payload.json"
    run bash "$REPO_ROOT/src/agents/claude/trigger.sh" permission ARG_BODY_SENTINEL < "$CASE_DIR/payload.json"
    [ "$status" -eq 0 ]
    [[ "$output" != *BODY_SENTINEL* ]]
    run bash "$REPO_ROOT/src/core/trigger.sh" processing ARG_BODY_SENTINEL < "$CASE_DIR/payload.json"
    [ "$status" -eq 0 ]
    [[ "$output" != *BODY_SENTINEL* ]]
    python3 - "$TAVS_RUNTIME_DIR/organizer" "$TAVS_TMP_DIR/debug" <<'PY'
import json,pathlib,sys
records=pathlib.Path(sys.argv[1]); debug=pathlib.Path(sys.argv[2])
observations=[json.loads(p.read_text()) for p in records.glob('observation-*.json')]
intents=[json.loads(p.read_text()) for p in records.glob('intent-*.json')]
assert observations and intents
assert observations[0]['state']=='processing' and observations[0].get('event') is None
assert intents[0]['background'].startswith('#')
assert list(debug.glob('*.log'))
for root in (records,debug):
    for path in root.iterdir():
        if path.is_file():
            data=path.read_bytes()
            assert b'BODY_SENTINEL' not in data, path
            assert b'/fixture' not in data, path
PY
}

@test "standalone muted background writes retain intent without inventing an observation" {
    run bash -c 'source "$1/src/core/terminal-osc-sequences.sh"; _TAVS_SUPPRESS_OUTPUT=1; _TAVS_PENDING_BUFFER="$2/pending"; send_osc_bg reset' _ "$REPO_ROOT" "$CASE_DIR"
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
    python3 - "$TAVS_RUNTIME_DIR/organizer" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])
assert not list(root.glob('observation-*.json'))
files=list(root.glob('intent-*.json')); assert len(files)==1
assert json.loads(files[0].read_text())['background']=='reset'
PY
}

@test "core replay diagnostic remains available without publishing an observation" {
    run bash "$REPO_ROOT/src/core/trigger.sh" replay missing-cache
    [ "$status" -eq 0 ]
    [[ "$output" == *"No pending cache"* ]]
    [ ! -d "$TAVS_RUNTIME_DIR/organizer" ]
}

@test "control characters in decoded session IDs cannot reach the terminal or identity files" {
    cat > "$HOME/.tavs/user.conf" <<'CONF'
DEBUG_ALL=1
TAVS_TITLE_PRESET=""
TAVS_TITLE_MODE="full"
TAVS_TITLE_FORMAT="{SESSION_ID}"
TAVS_TITLE_FORMAT_PERMISSION=""
CONF
    cat > "$HOME/.tavs/mute.state" <<STATE
MUTED="true"
APP_PID="$$"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
SCHEMA_VERSION="1"
STATE
    printf '%s' '{"hook_event_name":"PermissionRequest","session_id":"q\u0007\u001b[2J\nINJECTED_ID"}' > "$CASE_DIR/unsafe-id.json"
    run bash "$REPO_ROOT/src/agents/claude/trigger.sh" permission < "$CASE_DIR/unsafe-id.json"
    [ "$status" -eq 0 ]
    [ ! -s "$TTY_DEVICE" ]
    local pending="$TAVS_RUNTIME_DIR/pending/${TTY_DEVICE//\//_}.osc"
    [ -s "$pending" ]
    python3 - "$pending" "$TAVS_TMP_DIR" "$TAVS_RUNTIME_DIR" <<'PY'
import pathlib,sys
assert b'\x1b[2J' not in pathlib.Path(sys.argv[1]).read_bytes()
for directory in sys.argv[2:]:
    for path in pathlib.Path(directory).rglob('*'):
        if path.is_file():assert b'INJECTED_ID' not in path.read_bytes(),path
PY
}

@test "owned PTY synthetic colors preserve the observation and reject a superseded delivery" {
    cat > "$CASE_DIR/pty-check.sh" <<'SH'
set -e
export TTY_DEVICE="$(tty)" TAVS_AGENT=claude
source "$1/src/core/terminal-osc-sequences.sh"
_tavs_organizer_begin complete
send_osc_bg '#112233'
old_context="$TAVS_ORGANIZER_CONTEXT"
cp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$2/before.json"
export TAVS_ORGANIZER_SYNTHETIC=1
_TAVS_SUPPRESS_OUTPUT=1
_TAVS_PENDING_BUFFER="$2/pending"
send_osc_bg '#445566'
cmp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$2/before.json"
test -s "$2/pending"
cp "$TAVS_RUNTIME_DIR"/organizer/intent-*.json "$2/idle-intent.json"
source "$1/src/core/theme-config-loader.sh"
source "$1/src/core/session-state.sh"
source "$1/src/core/palette-mode-helpers.sh"
source "$1/src/core/idle-worker-background.sh"
get_short_cwd() { printf fixture; }
ENABLE_TITLE_PREFIX=false
UNIFIED_CHECK_INTERVAL=0.05
UNIFIED_STAGE_DURATIONS=(0 60)
UNIFIED_STAGE_COLORS=('#112233' '#AABBCC')
# Match the production worker's shell flags; keep assertions in the set-e parent.
(set +e; unified_timer_worker "$TTY_DEVICE") > "$2/worker.log" 2>&1 &
worker_pid=$!
trap 'kill "$worker_pid" 2>/dev/null || :; wait "$worker_pid" 2>/dev/null || :; cat "$2/worker.log" >&2' EXIT
for ((attempt=0; attempt<40; attempt++)); do
    grep -q '#AABBCC' "$TAVS_RUNTIME_DIR"/organizer/intent-*.json && break
    sleep 0.05
done
grep -q '#AABBCC' "$TAVS_RUNTIME_DIR"/organizer/intent-*.json
cmp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$2/before.json"
kill "$worker_pid"
wait "$worker_pid"
trap - EXIT
unset TAVS_ORGANIZER_SYNTHETIC
_tavs_organizer_begin permission
send_osc_bg '#778899'
cp "$TAVS_RUNTIME_DIR"/organizer/intent-*.json "$2/latest.json"
export TAVS_ORGANIZER_CONTEXT="$old_context" TAVS_ORGANIZER_SYNTHETIC=1
: > "$2/pending"
send_osc_bg reset
cmp "$TAVS_RUNTIME_DIR"/organizer/intent-*.json "$2/latest.json"
test ! -s "$2/pending"
unset TAVS_ORGANIZER_SYNTHETIC
send_osc_bg reset
cmp "$TAVS_RUNTIME_DIR"/organizer/intent-*.json "$2/latest.json"
test ! -s "$2/pending"
unset TAVS_ORGANIZER_CONTEXT
printf '%s' '{"hook_event_name":"PostToolUseFailure","tool_input":{"x":"ERROR_BODY_SENTINEL"}}' |
    bash "$1/src/agents/claude/trigger.sh" tool_error
cp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$2/error-observation.json"
sleep 2.3
cmp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$2/error-observation.json"
python3 - "$TAVS_RUNTIME_DIR/organizer" "$2" <<'CHECK'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]); case=pathlib.Path(sys.argv[2])
observation=json.loads((case/'error-observation.json').read_text())
intent=json.loads(next(root.glob('intent-*.json')).read_text())
assert observation['state']=='tool_error' and observation['event']=='PostToolUseFailure'
assert intent['deliveryID']==observation['deliveryID']
assert intent['updatedAt']>observation['observedAt']+1
assert 'ERROR_BODY_SENTINEL' not in json.dumps(observation)
CHECK
SH
    run python3 - "$CASE_DIR/pty-check.sh" "$REPO_ROOT" "$CASE_DIR" <<'PY'
import errno,json,os,pty,select,signal,sys,time
pid,fd=pty.fork()
if pid==0:
    os.execv('/bin/bash',['bash',*sys.argv[1:]])
status=None; output=bytearray(); deadline=time.monotonic()+15
try:
    while time.monotonic()<deadline:
        if select.select([fd],[],[],.05)[0]:
            try:
                data=os.read(fd,4096)
                if data: output.extend(data)
            except OSError as error:
                if error.errno!=errno.EIO: raise
        got,code=os.waitpid(pid,os.WNOHANG)
        if got: status=code; break
    assert status is not None, 'owned child exceeded deadline'
    assert os.waitstatus_to_exitcode(status)==0, output.decode(errors='replace')
finally:
    if status is None:
        os.kill(pid,signal.SIGKILL); os.waitpid(pid,0)
    os.close(fd)
root=sys.argv[3]
before=json.load(open(root+'/before.json')); idle=json.load(open(root+'/idle-intent.json'))
assert before['producer']['pid']>0 and before['device']>0
assert not before['verifiedAgent']
assert idle['deliveryID']==before['deliveryID'] and idle['background']=='#445566'
assert json.load(open(root+'/latest.json'))['background']=='#778899'
PY
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
}
