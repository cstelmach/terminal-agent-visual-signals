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

_owned_pty() {
    python3 - "$@" <<'PY'
import errno,os,pty,select,signal,sys,time
pid,fd=pty.fork()
if pid==0:
    os.environ['TTY_DEVICE']=os.ttyname(0)
    os.execvp(sys.argv[1],sys.argv[1:])
status=None; output=bytearray(); deadline=time.monotonic()+15
try:
    while time.monotonic()<deadline:
        if select.select([fd],[],[],.05)[0]:
            try:
                output.extend(os.read(fd,4096))
            except OSError as error:
                if error.errno!=errno.EIO: raise
        got,code=os.waitpid(pid,os.WNOHANG)
        if got: status=code; break
    assert status is not None, 'owned child exceeded deadline'
    print(output.decode(errors='replace'),end='')
    sys.exit(os.waitstatus_to_exitcode(status))
finally:
    if status is None:
        os.kill(pid,signal.SIGKILL); os.waitpid(pid,0)
    os.close(fd)
PY
}

@test "background helper records colors and resets even while muted" {
    cat > "$CASE_DIR/check.sh" <<'SCRIPT'
set -e
source "$1/src/core/terminal-osc-sequences.sh"
capture="$2"
_tavs_render_flush() {
    printf '%s\n' "$_TAVS_RENDER_BG" >> "$capture"
    _TAVS_RENDER_ACTIVE=0 _TAVS_RENDER_PENDING=0
}
_TAVS_SUPPRESS_OUTPUT=1
_TAVS_PENDING_BUFFER="$capture.pending"
send_osc_bg '#112233'
send_osc_bg reset
test "$(cat "$capture")" = $'#112233\nreset'
test ! -e "$capture.pending"
SCRIPT
    run bash "$CASE_DIR/check.sh" "$REPO_ROOT" "$CASE_DIR/intents"
    [ "$status" -eq 0 ]
}

@test "stale synthetic intent does not write background bytes" {
    cat > "$CASE_DIR/check.sh" <<'SCRIPT'
set -e
source "$1/src/core/terminal-osc-sequences.sh"
_tavs_render_flush() { _TAVS_MANAGED_STALE=1; return 3; }
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
    run _owned_pty bash -c '
        bash "$1/src/agents/claude/trigger.sh" permission ARG_BODY_SENTINEL < "$2/payload.json"
        bash "$1/src/core/trigger.sh" processing ARG_BODY_SENTINEL < "$2/payload.json"
    ' _ "$REPO_ROOT" "$CASE_DIR"
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
    cat > "$HOME/.tavs/mute.state" <<STATE
MUTED="true"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
APP_PID="$$"
REASON="quiet_period"
PAUSE_BG="#314159"
SCHEMA_VERSION="1"
STATE
    run _owned_pty bash -c 'source "$1/src/core/terminal-osc-sequences.sh"; send_osc_bg reset' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *']11;#314159'* && "$output" != *$'\033]111'* ]]
    python3 - "$TAVS_RUNTIME_DIR/organizer" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])
assert not list(root.glob('observation-*.json'))
files=list(root.glob('intent-*.json')); assert len(files)==1
assert json.loads(files[0].read_text())['background']=='reset'
PY
}

@test "core replay rejects an invalid target without publishing an observation" {
    run bash "$REPO_ROOT/src/core/trigger.sh" replay missing-cache
    [ "$status" -ne 0 ]
    [[ "$output" == *Usage:* ]]
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
    run _owned_pty bash -c 'bash "$1/src/agents/claude/trigger.sh" permission < "$2/unsafe-id.json"' _ "$REPO_ROOT" "$CASE_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" != *$'\033[2J'* ]]
    python3 - "$TAVS_TMP_DIR" "$TAVS_RUNTIME_DIR" <<'PY'
import pathlib,sys
for directory in sys.argv[1:]:
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
test ! -e "$2/pending"
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

@test "a delayed tool-error restore cannot cancel a newer completion timer" {
    printf 'ENABLE_TITLE_PREFIX=false\nIDLE_CHECK_INTERVAL=0.1\n' > "$HOME/.tavs/user.conf"
    cat > "$CASE_DIR/tool-error-check.sh" <<'SH'
set -e
repo="$1"; case_dir="$2"
export TAVS_AGENT=claude
source "$repo/src/core/session-state.sh"
TTY_SAFE="${TTY_DEVICE//\//_}"
timer=""
trap 'if [[ -n "$timer" ]]; then kill "$timer" 2>/dev/null || :; fi' EXIT
printf '%s' '{"hook_event_name":"PostToolUseFailure"}' |
    bash "$repo/src/agents/claude/trigger.sh" tool_error
sleep 0.5
printf '%s' '{"hook_event_name":"Stop"}' |
    bash "$repo/src/agents/claude/trigger.sh" complete
for ((attempt=0; attempt<40; attempt++)); do
    read_session_state || true
    [[ "$SESSION_STATE" == complete && -n "$SESSION_TIMER_PID" ]] && break
    sleep 0.05
done
test "$SESSION_STATE" = complete
timer="$SESSION_TIMER_PID"
test -n "$timer"
cp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$case_dir/completion.json"
sleep 2
read_session_state
[[ "$SESSION_STATE" == complete ]] || { printf 'Unexpected state: %s\n' "$SESSION_STATE"; exit 1; }
test "$SESSION_TIMER_PID" = "$timer"
kill -0 "$timer"
cmp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$case_dir/completion.json"
SH
    run _owned_pty bash "$CASE_DIR/tool-error-check.sh" "$REPO_ROOT" "$CASE_DIR"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
}

_validated_restore_race() {
    local next_state="$1"
    export TAVS_REAL_TEST_HELPER="$TAVS_TEST_HELPER_BIN"
    cat > "$CASE_DIR/restore-proxy" <<'PROXY'
#!/bin/bash
"$TAVS_REAL_TEST_HELPER" "$@"
result=$?
if [[ "$1" == --managed-check-context && "$result" == 0 && "${RESTORE_BARRIER:-0}" == 1 ]]; then
    : > "$RESTORE_CASE_DIR/validated"
    for ((attempt=0; attempt<150; attempt++)); do
        [[ -f "$RESTORE_CASE_DIR/release" ]] && break
        sleep .02
    done
    [[ -f "$RESTORE_CASE_DIR/release" ]] || exit 1
fi
if [[ "$1" == --managed-render && "${6:-}" == 1 ]]; then
    if [[ "${RESTORE_BARRIER:-0}" == 1 ]]; then
        printf '%s' "$result" > "$RESTORE_CASE_DIR/returned"
    else
        printf '%s' "$result" > "$RESTORE_CASE_DIR/stage-ready"
    fi
fi
exit "$result"
PROXY
    chmod +x "$CASE_DIR/restore-proxy"
    cat > "$CASE_DIR/restore-race.sh" <<'SH'
set -e
repo="$1"; export RESTORE_CASE_DIR="$2/race-$3"
export HOME="$RESTORE_CASE_DIR/home" CFFIXED_USER_HOME="$RESTORE_CASE_DIR/home"
export TAVS_RUNTIME_DIR="$RESTORE_CASE_DIR/runtime" TAVS_TMP_DIR="$RESTORE_CASE_DIR/state"
export _TAVS_TMP_DIR="$TAVS_TMP_DIR" TAVS_AGENT=claude
export TAVS_TEST_HELPER_BIN="$2/restore-proxy"
mkdir -p "$HOME/.tavs" "$TAVS_RUNTIME_DIR" "$TAVS_TMP_DIR"
printf 'ENABLE_TITLE_PREFIX=false\nIDLE_CHECK_INTERVAL=0.1\nSTAGE_DURATIONS=(2 60 60 60 60 60 60)\nIDLE_STAGE_1_COLOR="#44CC55"\nTHEME_MODE="static"\nFORCE_MODE="dark"\nCLAUDE_DARK_SUBAGENT="#44AA88"\n' > "$HOME/.tavs/user.conf"
source "$repo/src/core/session-state.sh"
source "$repo/src/core/spinner.sh"
TTY_SAFE="${TTY_DEVICE//\//_}"
source "$repo/src/core/subagent-counter.sh"
[[ "$3" != current ]] || printf '2\n' > "$SUBAGENT_COUNT_FILE"
timer=""
trap 'if [[ -n "$timer" ]]; then kill "$timer" 2>/dev/null || :; fi' EXIT
printf '%s' '{"hook_event_name":"PostToolUseFailure"}' |
    RESTORE_BARRIER=1 bash "$repo/src/agents/claude/trigger.sh" tool_error
for ((attempt=0; attempt<100; attempt++)); do
    [[ -f "$RESTORE_CASE_DIR/validated" ]] && break
    sleep .03
done
test -f "$RESTORE_CASE_DIR/validated"
if [[ "$3" == complete ]]; then
    printf '%s' '{"hook_event_name":"Stop"}' |
        bash "$repo/src/agents/claude/trigger.sh" complete
    for ((attempt=0; attempt<40; attempt++)); do
        read_session_state || :
        [[ "$SESSION_STATE" == complete && -n "$SESSION_TIMER_PID" ]] && break
        sleep .03
    done
    timer="$SESSION_TIMER_PID"
    test -n "$timer"
    for ((attempt=0; attempt<100; attempt++)); do
        [[ -f "$RESTORE_CASE_DIR/stage-ready" ]] && break
        sleep .03
    done
    test -f "$RESTORE_CASE_DIR/stage-ready"
    test "$(cat "$RESTORE_CASE_DIR/stage-ready")" = 0
elif [[ "$3" == subagent-start ]]; then
    printf '%s' '{"hook_event_name":"SubagentStart"}' |
        bash "$repo/src/agents/claude/trigger.sh" subagent-start
    test "$(get_subagent_count)" = 1
fi
cp "$STATE_DB" "$RESTORE_CASE_DIR/state-before"
cp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$RESTORE_CASE_DIR/observation-before.json"
count=$(get_subagent_count)
: > "$RESTORE_CASE_DIR/release"
for ((attempt=0; attempt<100; attempt++)); do
    [[ -f "$RESTORE_CASE_DIR/returned" ]] && break
    sleep .03
done
test -f "$RESTORE_CASE_DIR/returned"
expected_result=3
[[ "$3" != current ]] || expected_result=0
test "$(cat "$RESTORE_CASE_DIR/returned")" = "$expected_result"
actual_count=$(get_subagent_count)
test "$actual_count" = "$count" || { printf 'Counter changed: %s to %s\n' "$count" "$actual_count"; exit 1; }
cmp "$STATE_DB" "$RESTORE_CASE_DIR/state-before"
cmp "$TAVS_RUNTIME_DIR"/organizer/observation-*.json "$RESTORE_CASE_DIR/observation-before.json"
if [[ -n "$timer" ]]; then
    read_session_state
    test "$SESSION_TIMER_PID" = "$timer"
    kill -0 "$timer"
    for ((attempt=0; attempt<100; attempt++)); do
        grep -q '#44CC55' "$TAVS_RUNTIME_DIR"/organizer/intent-*.json && break
        sleep .03
    done
    grep -q '#44CC55' "$TAVS_RUNTIME_DIR"/organizer/intent-*.json
    test "$(cat "$RESTORE_CASE_DIR/stage-ready")" = 0
    read_session_state
    test "$SESSION_TIMER_PID" = "$timer"
    kill -0 "$timer"
fi
python3 - "$TAVS_RUNTIME_DIR/organizer" <<'CHECK'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])
observation=json.loads(next(root.glob('observation-*.json')).read_text())
intent=json.loads(next(root.glob('intent-*.json')).read_text())
assert intent['deliveryID']==observation['deliveryID']
CHECK
SH
    run _owned_pty bash "$CASE_DIR/restore-race.sh" "$REPO_ROOT" "$CASE_DIR" "$next_state"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
}

@test "a restore validated before Stop preserves the newer state and timer" {
    _validated_restore_race complete
    [[ "$output" == *$'\033]11;#44CC55\033\\'* ]]
}

@test "a restore validated before SubagentStart preserves the newer state and count" {
    _validated_restore_race subagent-start
}

@test "a current tool-error restore paints subagent styling without another spawn" {
    _validated_restore_race current
    [[ "$output" == *$'\033]11;#44AA88\033\\'* ]]
}

@test "an idle notification transfers the current delivery into graduated idle paints" {
    cat > "$HOME/.tavs/user.conf" <<'CONF'
ENABLE_TITLE_PREFIX=false
IDLE_CHECK_INTERVAL=0.1
STAGE_DURATIONS=(60 1 60 60 60 60 60)
IDLE_STAGE_0_COLOR="#112233"
IDLE_STAGE_1_COLOR="#AABBCC"
IDLE_STAGE_2_COLOR="#445566"
CONF
    cat > "$CASE_DIR/idle-handoff-check.sh" <<'SH'
set -e
repo="$1"; case_dir="$2"
export TAVS_AGENT=claude
source "$repo/src/core/session-state.sh"
TTY_SAFE="${TTY_DEVICE//\//_}"
trap 'read_session_state || :; if [[ -n "$SESSION_TIMER_PID" ]]; then kill "$SESSION_TIMER_PID" 2>/dev/null || :; fi' EXIT
printf '%s' '{"hook_event_name":"Stop"}' |
    bash "$repo/src/agents/claude/trigger.sh" complete
for ((attempt=0; attempt<40; attempt++)); do
    read_session_state || true
    [[ -n "$SESSION_TIMER_PID" ]] && break
    sleep 0.05
done
test -n "$SESSION_TIMER_PID"
printf '%s' '{"hook_event_name":"Notification","notification_type":"idle_prompt"}' |
    bash "$repo/src/agents/claude/trigger.sh" idle
for ((attempt=0; attempt<70; attempt++)); do
    grep -q '#445566' "$TAVS_RUNTIME_DIR"/organizer/intent-*.json && break
    sleep 0.05
done
python3 - "$TAVS_RUNTIME_DIR/organizer" <<'CHECK'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])
observation=json.loads(next(root.glob('observation-*.json')).read_text())
intent=json.loads(next(root.glob('intent-*.json')).read_text())
assert observation['state']=='idle' and observation['event']=='idle_prompt'
assert intent['deliveryID']==observation['deliveryID'], 'worker retained completion delivery'
assert intent['background']=='#445566', intent['background']
CHECK
SH
    run _owned_pty bash "$CASE_DIR/idle-handoff-check.sh" "$REPO_ROOT" "$CASE_DIR"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
}

@test "public recovery and resume use owned scoped PTY with current rules and no historical replay" {
    export RECOVERY_REAL_HELPER="$TAVS_TEST_HELPER_BIN"
    cat > "$CASE_DIR/recovery-helper" <<'HELPER'
#!/bin/bash
if [[ "$1" == --visual-recover ]]; then
    expected=true
    [[ "$4" == resume ]] && expected=false
    grep -q "^SUSPENDED=\"$expected\"$" "$2" || exit 1
    printf '%s\n' "$4:marker-saved" >> "$RECOVERY_CALLS"
fi
exec "$RECOVERY_REAL_HELPER" "$@"
HELPER
    chmod +x "$CASE_DIR/recovery-helper"
    export RECOVERY_CALLS="$CASE_DIR/recovery-calls"
    run _owned_pty bash --norc -ic '
        set -e
        set +m
        repo="$1"; case_dir="$2"
        marker="$HOME/.tavs/visual-restrictions.state"
        token=$("$RECOVERY_REAL_HELPER" --organizer-context unknown "$$")
        python3 - "$token" "$case_dir/catalogue.json" "$case_dir/allowed.json" "$TTY_DEVICE" <<'"'"'PY'"'"'
import base64,json,sys
generation=json.loads(base64.b64decode(sys.argv[1]))["producer"]
surface={"application":generation,"terminalID":"owned-recovery"}
json.dump([surface],open(sys.argv[3],"w"))
json.dump({"application":generation,"surfaces":[{"terminalID":"owned-recovery",
    "windowID":"owned-window","tabID":"owned-tab","tty":sys.argv[4],
    "pid":generation["pid"],"selected":True}]},open(sys.argv[2],"w"))
PY
        export TAVS_SESSIONS_TEST_ROOT="$TAVS_TEST_ROOT"
        export TAVS_SESSIONS_TEST_FIXTURE="$case_dir/catalogue.json"
        export TAVS_SESSIONS_TEST_TARGETS="$(cat "$case_dir/allowed.json")"
        cat > "$HOME/.tavs/mute.state" <<STATE
MUTED="false"
REQUESTED_MUTED="true"
MUTE_LEVEL="soft"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
APP_PID="$$"
PAUSE_BG="#314159"
PAUSE_FG="#EEEEEE"
SCHEMA_VERSION="1"
STATE
        TTY="$TTY_DEVICE"
        source "$repo/src/shell/tavs-shellrc.sh"
        export TAVS_ORGANIZER_CONTEXT="$token"
        export TAVS_AGENT=claude
        source "$repo/src/core/terminal-osc-sequences.sh"
        _tavs_organizer_begin complete
        send_osc_bg "#112233"
        _tavs_managed_forced_reset "fresh-title"
        mkdir -p "$TAVS_RUNTIME_DIR/pending"
        pending="$TAVS_RUNTIME_DIR/pending/${TTY_DEVICE//\//_}.osc"
        printf "\\033]0;OLD_TITLE\\007\\007" > "$pending"
        bash "$repo/src/core/trigger.sh" replay "${TTY_DEVICE//\//_}"
        export TAVS_TEST_HELPER_BIN="$case_dir/recovery-helper"
        printf "RECOVER_BEGIN\n"
        bash "$repo/tavs" recover > "$case_dir/recover.json"
        test ! -e "$pending"
        printf "RECOVER_DONE\nRESUME_BEGIN\n"
        sed -i "" "s/#314159/#271828/" "$HOME/.tavs/mute.state"
        bash "$repo/tavs" recover --resume > "$case_dir/resume.json"
        printf "RESUME_DONE\n"
        python3 - "$case_dir/recover.json" "$case_dir/resume.json" <<'"'"'PY'"'"'
import json,sys
for path in sys.argv[1:]:
    report=json.load(open(path))
    assert report["stateSaved"] and report["catalogueAvailable"],report
    assert report["items"] and all(item["status"] in ("restored","unaffected") for item in report["items"]),report
PY
    ' _ "$REPO_ROOT" "$CASE_DIR"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
    [[ "$(cat "$RECOVERY_CALLS")" == $'recover:marker-saved\nresume:marker-saved' ]]
    python3 - "$output" <<'PY'
import re,sys
output=sys.argv[1]
recover=output.split('RECOVER_BEGIN',1)[1].split('RECOVER_DONE',1)[0]
resume=output.split('RESUME_BEGIN',1)[1].split('RESUME_DONE',1)[0]
assert '\x1b]104\x07' in recover and '\x1b]110\x07' in recover and '\x1b]111\x07' in recover
assert ']11;#271828' in resume
assert 'OLD_TITLE' not in output and 'fresh-title' not in output and '\x1b]0;' not in output
without_osc=re.sub(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)','',output)
assert '\x07' not in without_osc
PY
}

@test "owned nested producer validates synthetic context beneath continuing shell without output or intent" {
    cat > "$CASE_DIR/nested-check.sh" <<'SH'
set -e
export TAVS_AGENT=claude
source "$1/src/core/terminal-osc-sequences.sh"
_tavs_organizer_begin complete
python3 - "$TAVS_RUNTIME_DIR/organizer" "$TAVS_ORGANIZER_CONTEXT" "$OUTER_PTY_OWNER" "$$" "$2/binding-before.json" <<'PY'
import base64,json,pathlib,sys
root=pathlib.Path(sys.argv[1]); context=json.loads(base64.b64decode(sys.argv[2]))
targets=list(root.rglob('target.json')); assert len(targets)==1
target=json.loads(targets[0].read_text())['target']
assert target['ttyOwner']['pid']==int(sys.argv[3])
assert context['producer']['pid']==int(sys.argv[4])!=target['ttyOwner']['pid']
observation=json.loads(next(root.glob('observation-*.json')).read_text())
assert observation['producer']==context['producer'] and observation['device']==target['device']
json.dump({'path':str(targets[0]),'contents':targets[0].read_text()},open(sys.argv[5],'w'))
PY
export TAVS_ORGANIZER_SYNTHETIC=1
_tavs_managed_check_context
python3 - "$TAVS_RUNTIME_DIR/organizer" "$2/binding-before.json" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]); before=json.load(open(sys.argv[2]))
assert pathlib.Path(before['path']).read_text()==before['contents']
assert not list(root.glob('intent-*.json'))
assert not list(root.rglob('bound-intent.json')) and not list(root.rglob('effect.json'))
PY
SH
    run _owned_pty bash --norc -ic '
        set -e
        export OUTER_PTY_OWNER="$$"
        "$TAVS_TEST_HELPER_BIN" --managed-register "$HOME/.tavs/visual-restrictions.state" \
            "$TAVS_RUNTIME_DIR" "$TTY_DEVICE" "$$" >/dev/null
        bash "$2/nested-check.sh" "$1" "$2"
    ' _ "$REPO_ROOT" "$CASE_DIR"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
    [ -z "$output" ]
}

@test "owned PTY fresh hard rule replaces the complete queued ordinary style batch" {
    : > "$CASE_DIR/image.png"
    run _owned_pty bash -c '
        set -e
        export TAVS_AGENT=claude
        source "$1/src/core/terminal-osc-sequences.sh"
        source "$1/src/core/backgrounds.sh"
        _tavs_organizer_begin processing
        _TAVS_SUPPRESS_OUTPUT=0
        _tavs_render_begin
        PALETTE_DARK_0="#010203"
        send_osc_palette dark
        send_osc_bg "#112233"
        _tavs_render_queue title OLD_STYLE_TITLE
        _set_bg_image_iterm2 "$2/image.png"
        BELL_ON_PERMISSION=true
        send_bell_if_enabled permission
        cat > "$TAVS_RUNTIME_DIR/lock.state" <<STATE
LOCKED="true"
LOCK_UNTIL_EPOCH="$(( $(date +%s) + 300 ))"
UNLOCK_UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
LOCK_BG="#334455"
LOCK_FG="#EEEEEE"
SCHEMA_VERSION="1"
STATE
        _tavs_render_flush
        python3 - "$TAVS_RUNTIME_DIR/organizer" <<'"'"'PY'"'"'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]);intent=json.loads(next(root.glob("intent-*.json")).read_text())
assert intent["background"]=="#112233"
PY
    ' _ "$REPO_ROOT" "$CASE_DIR"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
    python3 - "$output" "$CASE_DIR/image.png" <<'PY'
import base64,re,sys
output=sys.argv[1]
assert ']11;#334455' in output and 'locked until' in output
assert 'OLD_STYLE_TITLE' not in output and '#112233' not in output and '\x1b]4;' not in output
assert base64.b64encode(sys.argv[2].encode()).decode() not in output
without_osc=re.sub(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)','',output)
assert '\x07' not in without_osc
PY
}

@test "owned PTY superseded synthetic batch emits no style or intent" {
    run _owned_pty bash -c '
        set -e
        export TAVS_AGENT=claude
        source "$1/src/core/terminal-osc-sequences.sh"
        _tavs_organizer_begin complete
        old_context="$TAVS_ORGANIZER_CONTEXT"
        _tavs_render_begin
        send_osc_bg "#445566"
        send_osc_palette_reset
        _tavs_render_queue title OLD_SYNTHETIC_TITLE
        _tavs_organizer_begin permission
        export TAVS_ORGANIZER_CONTEXT="$old_context" TAVS_ORGANIZER_SYNTHETIC=1
        result=0
        _tavs_render_flush || result=$?
        test "$result" = 3
        python3 - "$TAVS_RUNTIME_DIR/organizer" <<'"'"'PY'"'"'
import pathlib,sys
assert not list(pathlib.Path(sys.argv[1]).glob("intent-*.json"))
PY
    ' _ "$REPO_ROOT"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
    [[ "$output" != *$'\033]'* && "$output" != *OLD_SYNTHETIC_TITLE* ]]
}
