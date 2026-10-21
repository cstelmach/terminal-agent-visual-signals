#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CASE_DIR="$BATS_TEST_TMPDIR"
}

@test "runner gives its child private roots without changing the caller" {
    local before_home="$HOME"
    cat > "$CASE_DIR/check.sh" <<'SCRIPT'
set -eu
for path in "$HOME" "$TMPDIR" "$CFFIXED_USER_HOME" "$TAVS_RUNTIME_DIR" \
    "$TAVS_TMP_DIR" "$_TAVS_TMP_DIR" "$XDG_RUNTIME_DIR" "$ZDOTDIR" "$TTY_DEVICE"; do
    case "$path" in "$TAVS_TEST_ROOT"/*) ;; *) exit 9 ;; esac
done
test -f "$TTY_DEVICE"
test ! -c "$TTY_DEVICE"
test -x "$TAVS_TEST_HELPER_BIN"
test -z "${BASH_ENV:-}"
test -z "${DEBUG_ALL:-}"
printf 'private-child-ok\n'
SCRIPT
    run env DEBUG_ALL=1 TAVS_TEST_HELPER_BIN="$TAVS_TEST_HELPER_BIN" \
        bash "$REPO_ROOT/tests/run-isolated.sh" bash "$CASE_DIR/check.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"private-child-ok"* ]]
    [ "$HOME" = "$before_home" ]
}

@test "runner retains failure output and returns the child exit status" {
    run bash "$REPO_ROOT/tests/run-isolated.sh" bash -c 'printf "owned failure\n"; exit 7'
    [ "$status" -eq 7 ]
    [[ "$output" == *"owned failure"* ]]
    local log="${lines[0]#Isolated test log: }"
    [ -f "$log" ]
    [[ "$(cat "$log")" == *"owned failure"* ]]
}

@test "runner detaches its child from the caller's process ancestry" {
    # Producer discovery walks parent PIDs; the caller's terminal must not be reachable.
    run bash -c 'echo "caller=$$"; exec bash "$1/tests/run-isolated.sh" bash -c '"'"'
p=$PPID; chain=""
while [[ "$p" -gt 1 ]]; do chain+=" $p"; p=$(ps -o ppid= -p "$p" | tr -d " "); done
echo "chain=$chain"'"'" _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    local caller="${lines[0]#caller=}" chain_line
    chain_line=$(printf '%s\n' "${lines[@]}" | grep '^chain=')
    [[ -n "$chain_line" && " ${chain_line#chain=} " != *" $caller "* ]]
}

@test "runner terminates the detached child when it is interrupted" {
    run perl -e 'alarm 2; exec @ARGV' bash "$REPO_ROOT/tests/run-isolated.sh" sleep 43210
    [ "$status" -eq 130 ]
    sleep 0.5
    ! pgrep -f 'sleep 43210'
}

@test "Python clean environments and shell helpers retain the private roots" {
    cat > "$CASE_DIR/check.py" <<'PY'
import importlib.util
import os
from pathlib import Path

def test_private_environment():
    spec = importlib.util.spec_from_file_location("test_config", Path.cwd() / "tests/conftest.py")
    config = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(config)
    keys = ("TAVS_RUNTIME_DIR", "TAVS_TMP_DIR", "XDG_RUNTIME_DIR", "TTY_DEVICE", "TAVS_TEST_HELPER_BIN")
    clean = config.clean_env.__wrapped__()
    for key in keys:
        assert clean[key] == os.environ[key], key
    for shell in (config.run_bash, config.run_zsh):
        result = shell('test -d "$TAVS_RUNTIME_DIR" && test "$_TAVS_TMP_DIR" = "$TAVS_TMP_DIR"',
                       env={"PATH": os.environ["PATH"], "HOME": os.environ["HOME"]})
        assert result.returncode == 0, result.stderr
    title = config.run_bash('source src/core/title-management.sh; test "$TITLE_STATE_DB" = "$TAVS_TMP_DIR/title"',
                            env={"PATH": os.environ["PATH"], "HOME": os.environ["HOME"]})
    assert title.returncode == 0, title.stderr
PY
    run bash "$REPO_ROOT/tests/run-isolated.sh" pytest -q -p no:cacheprovider "$CASE_DIR/check.py"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output"; return 1; }
    [[ "$output" == *"1 passed"* ]]
}

@test "runner rejects a missing helper before running the child" {
    run env TAVS_TEST_HELPER_BIN= bash "$REPO_ROOT/tests/run-isolated.sh" touch "$CASE_DIR/not-run"
    [ "$status" -eq 2 ]
    [ ! -e "$CASE_DIR/not-run" ]
}

@test "runner does not execute an inherited Bash startup file" {
    printf 'touch "%s"\n' "$CASE_DIR/startup-ran" > "$CASE_DIR/startup.sh"
    run env BASH_ENV="$CASE_DIR/startup.sh" "$REPO_ROOT/tests/run-isolated.sh" true
    [ "$status" -eq 0 ]
    [ ! -e "$CASE_DIR/startup-ran" ]
}
