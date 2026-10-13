#!/usr/bin/env bats
# ==============================================================================
# Integration test: latest ordinary intent, pause precedence and no replay
# ==============================================================================
# Muted hooks retain one typed intent per owned PTY. Global pause owns the
# visible background, and resumption must never replay historical OSC bytes.
# ==============================================================================

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" && "${TAVS_TEST_HELPER_BIN:-}" == /* \
        && -x "$TAVS_TEST_HELPER_BIN" ]] || return 1
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export CASE_DIR="$TAVS_TEST_ROOT/priority-$BATS_TEST_NUMBER"
    export HOME="$CASE_DIR/home" CFFIXED_USER_HOME="$CASE_DIR/home" ZDOTDIR="$CASE_DIR/home"
    export TAVS_RUNTIME_DIR="$CASE_DIR/runtime" TAVS_TMP_DIR="$CASE_DIR/state"
    export _TAVS_TMP_DIR="$TAVS_TMP_DIR" TMPDIR="$CASE_DIR/tmp"
    export XDG_RUNTIME_DIR="$CASE_DIR/xdg" XDG_CACHE_HOME="$CASE_DIR/cache"
    export TAVS_AGENT=claude PRIORITY_EXPECTED_HELPER="$TAVS_TEST_HELPER_BIN"
    mkdir -p "$HOME/.tavs" "$TAVS_RUNTIME_DIR" "$TAVS_TMP_DIR" "$TMPDIR" \
        "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME"
    cat > "$HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="quiet_period"
PAUSE_BG="#314159"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
APP_PID="$$"
SCHEMA_VERSION="1"
EOF
    cat > "$HOME/.tavs/user.conf" <<'EOF'
THEME_MODE="static"
FORCE_MODE="dark"
ENABLE_MODE_AWARE_PROCESSING="false"
CLAUDE_DARK_PROCESSING="#112233"
CLAUDE_DARK_PERMISSION="#445566"
TAVS_TITLE_PRESET="none"
TAVS_TITLE_MODE="full"
TAVS_TITLE_FORMAT="MUTED_TITLE"
BELL_ON_PERMISSION="true"
EOF
}

# Keep distinct PTYs live together so the per-TTY case cannot accidentally reuse a device.
_owned_ptys() {
    python3 - "$REPO_ROOT" "$@" <<'PY'
import errno,os,pty,select,signal,sys,time
children={}; output={}; statuses={}; deadline=time.monotonic()+15
try:
    for index,script in enumerate(sys.argv[2:],1):
        pid,fd=pty.fork()
        if pid==0:
            os.environ['TTY_DEVICE']=os.ttyname(0)
            os.execvp('bash',['bash','-p',script,sys.argv[1],str(index)])
        children[pid]=fd; output[fd]=bytearray()
    while len(statuses)<len(children) and time.monotonic()<deadline:
        active=[fd for pid,fd in children.items() if pid not in statuses]
        for fd in select.select(active,[],[],.05)[0]:
            try: output[fd].extend(os.read(fd,4096))
            except OSError as error:
                if error.errno!=errno.EIO: raise
        for pid in children.keys()-statuses.keys():
            got,status=os.waitpid(pid,os.WNOHANG)
            if got: statuses[pid]=status
    assert len(statuses)==len(children), 'owned PTY exceeded deadline'
    for index,(fd,data) in enumerate(output.items(),1):
        os.set_blocking(fd,False)
        while True:
            try:
                remaining=os.read(fd,4096)
                if not remaining: break
                data.extend(remaining)
            except BlockingIOError: break
            except OSError as error:
                if error.errno!=errno.EIO: raise
                break
        with open(os.path.join(os.environ['CASE_DIR'],f'pty-{index}.out'),'wb') as capture:
            capture.write(data)
        print(data.decode(errors='replace'),end='')
    sys.exit(0 if all(os.waitstatus_to_exitcode(s)==0 for s in statuses.values()) else 1)
finally:
    for pid,fd in children.items():
        if pid not in statuses:
            os.kill(pid,signal.SIGKILL); os.waitpid(pid,0)
        os.close(fd)
PY
}

@test "priority: latest typed hook intent wins while pause owns visible output" {
    cat > "$CASE_DIR/check.sh" <<'SH'
set -e
bash "$1/src/core/trigger.sh" processing
cp "$TAVS_RUNTIME_DIR"/organizer/intent-*.json "$CASE_DIR/first.json"
bash "$1/src/core/trigger.sh" permission
cp "$TAVS_RUNTIME_DIR"/organizer/intent-*.json "$CASE_DIR/permission.json"
sleep .5 # Permission protection lasts 400 ms.
bash "$1/src/core/trigger.sh" processing
SH
    run _owned_ptys "$CASE_DIR/check.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *']11;#314159'* && "$output" != *'#112233'* \
        && "$output" != *'#445566'* && "$output" != *MUTED_TITLE* ]]
    python3 - "$TAVS_RUNTIME_DIR" "$CASE_DIR" <<'PY'
import json,pathlib,re,sys
root=pathlib.Path(sys.argv[1]); case=pathlib.Path(sys.argv[2])
intents=list(root.glob('organizer/intent-*.json')); assert len(intents)==1
observations=list(root.glob('organizer/observation-*.json')); assert len(observations)==1
latest=json.loads(intents[0].read_text()); observation=json.loads(observations[0].read_text())
earlier=[json.loads((case/name).read_text()) for name in ('first.json','permission.json')]
assert [r['background'] for r in earlier]+[latest['background']]==['#112233','#445566','#112233']
assert len({r['deliveryID'] for r in earlier+[latest]})==3
assert observation['state']=='processing' and observation['deliveryID']==latest['deliveryID']
assert not list(root.glob('pending/*.osc'))
# OSC's BEL terminators are not standalone alert bells.
data=(case/'pty-1.out').read_bytes()
assert b'\x07' not in re.sub(rb'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)',b'',data)
PY
}

@test "priority: simultaneously live TTYs retain separate typed intents" {
    cat > "$CASE_DIR/check.sh" <<'SH'
set -e
state=processing
test "$2" != 2 || state=permission
bash "$1/src/core/trigger.sh" "$state"
printf '%s' "$TTY_DEVICE" > "$CASE_DIR/tty-$2"
: > "$CASE_DIR/ready-$2"
until test -f "$CASE_DIR/ready-1" && test -f "$CASE_DIR/ready-2"; do sleep .05; done
SH
    run _owned_ptys "$CASE_DIR/check.sh" "$CASE_DIR/check.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *']11;#314159'* && "$output" != *'#112233'* && "$output" != *'#445566'* ]]
    python3 - "$TAVS_RUNTIME_DIR" "$CASE_DIR" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]); case=pathlib.Path(sys.argv[2])
ttys=[(case/f'tty-{i}').read_text() for i in (1,2)]; assert ttys[0]!=ttys[1]
intents={r['tty']:r for r in (json.loads(p.read_text()) for p in root.glob('organizer/intent-*.json'))}
observations={r['tty']:r for r in (json.loads(p.read_text()) for p in root.glob('organizer/observation-*.json'))}
assert set(intents)==set(observations)==set(ttys)
for tty,state,color in zip(ttys,('processing','permission'),('#112233','#445566')):
    assert intents[tty]['background']==color and observations[tty]['state']==state
    assert intents[tty]['deliveryID']==observations[tty]['deliveryID']
assert intents[ttys[0]]['deliveryID']!=intents[ttys[1]]['deliveryID']
assert not list(root.glob('pending/*.osc'))
PY
}

@test "priority: repeat hooks replace intent and resumption emits no historical styles" {
    cat > "$CASE_DIR/check.sh" <<'SH'
set -e
for i in 1 2 3; do bash "$1/src/core/trigger.sh" processing; done
cp "$TAVS_RUNTIME_DIR"/organizer/intent-*.json "$CASE_DIR/muted.json"
printf 'MUTED="false"\nSCHEMA_VERSION="1"\n' > "$HOME/.tavs/mute.state"
source "$1/src/core/terminal-osc-sequences.sh"
send_osc_bg '#778899'
SH
    run _owned_ptys "$CASE_DIR/check.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *']11;#314159'* && "$output" == *']11;#778899'* \
        && "$output" != *'#112233'* && "$output" != *MUTED_TITLE* ]]
    python3 - "$TAVS_RUNTIME_DIR" "$CASE_DIR/muted.json" <<'PY'
import json,pathlib,re,sys
root=pathlib.Path(sys.argv[1]); muted=json.loads(pathlib.Path(sys.argv[2]).read_text())
intents=list(root.glob('organizer/intent-*.json')); assert len(intents)==1
latest=json.loads(intents[0].read_text())
assert muted['background']=='#112233' and latest['background']=='#778899'
assert muted['deliveryID']!=latest['deliveryID']
assert len(list(root.glob('organizer/observation-*.json')))==1
assert not list(root.glob('pending/*.osc'))
data=(pathlib.Path(sys.argv[2]).parent/'pty-1.out').read_bytes()
assert b'\x07' not in re.sub(rb'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)',b'',data)
PY
}

@test "priority: PTY children retain the source helper and private environment" {
    cat > "$CASE_DIR/check.sh" <<'SH'
set -e
test "$TAVS_TEST_HELPER_BIN" = "$PRIORITY_EXPECTED_HELPER"
test -x "$TAVS_TEST_HELPER_BIN"
test "$CFFIXED_USER_HOME" = "$HOME" && test "$ZDOTDIR" = "$HOME"
for path in "$HOME" "$TAVS_RUNTIME_DIR" "$TAVS_TMP_DIR" "$TMPDIR" \
    "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME"; do
    case "$path" in "$TAVS_TEST_ROOT"/*) ;; *) exit 1 ;; esac
done
test "$_TAVS_TMP_DIR" = "$TAVS_TMP_DIR"
test "$TTY_DEVICE" = "$(tty)"
test "$("$TAVS_TEST_HELPER_BIN" --validate-config --organizer-capabilities)" = tavs-organizer-schema=1
SH
    run _owned_ptys "$CASE_DIR/check.sh"
    [ "$status" -eq 0 ]
}
