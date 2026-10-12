#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home" CFFIXED_USER_HOME="$BATS_TEST_TMPDIR/home"
    export TAVS_RUNTIME_DIR="$BATS_TEST_TMPDIR/runtime"
    export TAVS_ROOT="$REPO_ROOT" CLI_DIR="$REPO_ROOT/src/cli"
    export CAPTURE="$BATS_TEST_TMPDIR/calls" QUERY_FAILED=0 RECOVERY_FAILED=0 SUPPORT=1
    mkdir -p "$HOME/.tavs" "$TAVS_RUNTIME_DIR"
    HELPER="$BATS_TEST_TMPDIR/helper"
    export TAVS_TEST_HELPER_BIN="$HELPER"
    cat > "$HELPER" <<'SH'
#!/bin/bash
set -eu
test -f "$HOME/.tavs/visual-restrictions.state" || exit 43
printf '%s\n' "$1" >> "$CAPTURE"
if [[ "$1" == --validate-config ]]; then
    [[ "$2" == --managed-output-capabilities ]] || exit 1
    [[ "$QUERY_FAILED" == 0 ]] || exit 1
    [[ "$SUPPORT" == 1 ]] && printf 'tavs-managed-output-schema=1\n'
    exit 0
fi
[[ "$1" == --visual-recover && "$#" == 4 ]] || exit 1
[[ "$2" == "$HOME/.tavs/visual-restrictions.state" && "$3" == "$TAVS_RUNTIME_DIR" ]] || exit 1
case "$4" in
    recover) grep -q '^SUSPENDED="true"$' "$2" ;;
    resume) grep -q '^SUSPENDED="false"$' "$2" ;;
    *) exit 1 ;;
esac
printf 'restored=2 vanished=1 unaffected=0 failed=%s\n' "$RECOVERY_FAILED"
[[ "$RECOVERY_FAILED" == 0 ]]
SH
    chmod +x "$HELPER"
}

@test "recover persists suspension before the first helper query and forwards its result" {
    run bash "$REPO_ROOT/tavs" recover
    [ "$status" -eq 0 ]
    [[ "$output" == *'restored=2 vanished=1 unaffected=0 failed=0'* ]]
    [ "$(cat "$CAPTURE")" = $'--validate-config\n--visual-recover' ]
    grep -q '^SUSPENDED="true"$' "$HOME/.tavs/visual-restrictions.state"
}

@test "missing explicitly selected helper leaves suspension saved and returns failure" {
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/missing"
    run bash "$REPO_ROOT/tavs" recover
    [ "$status" -ne 0 ]
    grep -q '^SUSPENDED="true"$' "$HOME/.tavs/visual-restrictions.state"
    [ ! -e "$CAPTURE" ]
}

@test "empty explicit override does not invoke an installed helper" {
    export TAVS_TEST_HELPER_BIN=""
    run bash "$REPO_ROOT/tavs" recover
    [ "$status" -ne 0 ]
    grep -q '^SUSPENDED="true"$' "$HOME/.tavs/visual-restrictions.state"
    [ ! -e "$CAPTURE" ]
}

@test "old or query-failed helper receives only the known validation branch" {
    export SUPPORT=0
    run bash "$REPO_ROOT/tavs" recover
    [ "$status" -ne 0 ]
    [ "$(cat "$CAPTURE")" = --validate-config ]
    : > "$CAPTURE"
    export SUPPORT=1 QUERY_FAILED=1
    run bash "$REPO_ROOT/tavs" recover
    [ "$status" -ne 0 ]
    [ "$(cat "$CAPTURE")" = --validate-config ]
    grep -q '^SUSPENDED="true"$' "$HOME/.tavs/visual-restrictions.state"
}

@test "partial recovery preserves suspension and propagates nonzero native status" {
    export RECOVERY_FAILED=1
    run bash "$REPO_ROOT/tavs" recover
    [ "$status" -ne 0 ]
    [[ "$output" == *'failed=1'* ]]
    grep -q '^SUSPENDED="true"$' "$HOME/.tavs/visual-restrictions.state"
}

@test "resume persists false before native invocation and keeps saved definitions intact" {
    printf schedule-data > "$HOME/.tavs/schedule.json"
    printf lock-data > "$TAVS_RUNTIME_DIR/lock.state"
    run bash "$REPO_ROOT/tavs" recover --resume
    [ "$status" -eq 0 ]
    grep -q '^SUSPENDED="false"$' "$HOME/.tavs/visual-restrictions.state"
    [ "$(cat "$HOME/.tavs/schedule.json")" = schedule-data ]
    [ "$(cat "$TAVS_RUNTIME_DIR/lock.state")" = lock-data ]
}

@test "failed persistence never invokes the helper" {
    mkdir "$HOME/.tavs/visual-restrictions.state"
    run bash "$REPO_ROOT/tavs" recover
    [ "$status" -ne 0 ]
    [ ! -e "$CAPTURE" ]
}

@test "help and invalid arguments do not change state or invoke a helper" {
    run bash "$REPO_ROOT/tavs" help recover
    [ "$status" -eq 0 ]
    [[ "$output" == *'recover --resume'* ]]
    run bash "$REPO_ROOT/tavs" recover --unknown
    [ "$status" -ne 0 ]
    [ ! -e "$HOME/.tavs/visual-restrictions.state" ]
    [ ! -e "$CAPTURE" ]
}
