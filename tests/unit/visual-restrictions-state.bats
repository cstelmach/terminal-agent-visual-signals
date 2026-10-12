#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.tavs"
    LIB="$REPO_ROOT/src/core/visual-restrictions-state.sh"
}

@test "shared data fixtures agree in Bash and zsh without executing content" {
    python3 - "$REPO_ROOT/tests/fixtures/visual-restrictions-state.json" "$BATS_TEST_TMPDIR" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[2])
for case in json.load(open(sys.argv[1]))['cases']:
    if case['text'] is not None:(root/case['name']).write_bytes(case['text'].encode())
    with (root/'expected.tsv').open('a') as out:out.write(case['name']+'\t'+case['expected']+'\n')
PY
    local shell name expected
    for shell in /bin/bash /bin/zsh; do
        while IFS=$'\t' read -r name expected; do
            run "$shell" -c 'source "$1"; _tavs_visual_restrictions_read "$2"; printf "%s" "$_TAVS_VISUAL_RESTRICTIONS_STATUS"' _ "$LIB" "$BATS_TEST_TMPDIR/$name"
            [ "$status" -eq 0 ]
            [ "$output" = "$expected" ]
        done < "$BATS_TEST_TMPDIR/expected.tsv"
    done
    [ ! -e "$HOME/.tavs/MUST_NOT_RUN" ]
}

@test "atomic writer persists suspension and explicit resumption across processes" {
    run bash -c 'source "$1"; _tavs_visual_restrictions_write true' _ "$LIB"
    [ "$status" -eq 0 ]
    run zsh -fc 'source "$1"; _tavs_visual_restrictions_suspended' _ "$LIB"
    [ "$status" -eq 0 ]
    [ "$(stat -f %Lp "$HOME/.tavs/visual-restrictions.state")" = 600 ]
    run bash -c 'source "$1"; _tavs_visual_restrictions_write false' _ "$LIB"
    [ "$status" -eq 0 ]
    run zsh -fc 'source "$1"; _tavs_visual_restrictions_suspended' _ "$LIB"
    [ "$status" -eq 1 ]
}

@test "invalid write leaves the previous marker intact" {
    source "$LIB"
    _tavs_visual_restrictions_write true
    cp "$HOME/.tavs/visual-restrictions.state" "$BATS_TEST_TMPDIR/before"
    run _tavs_visual_restrictions_write '$(touch "$HOME/.tavs/MUST_NOT_RUN")'
    [ "$status" -ne 0 ]
    cmp "$HOME/.tavs/visual-restrictions.state" "$BATS_TEST_TMPDIR/before"
}

@test "special files disable restrictions without blocking and refuse replacement" {
    source "$LIB"
    mkfifo "$BATS_TEST_TMPDIR/fifo"
    ln -s "$BATS_TEST_TMPDIR/missing" "$BATS_TEST_TMPDIR/link"
    local file
    for file in "$BATS_TEST_TMPDIR/fifo" "$BATS_TEST_TMPDIR/link" "$BATS_TEST_TMPDIR"; do
        _tavs_visual_restrictions_read "$file"
        [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = unavailable ]
        run _tavs_visual_restrictions_write false "$file"
        [ "$status" -ne 0 ]
    done
}

@test "inaccessible parent is unavailable rather than a missing active marker" {
    local parent="$BATS_TEST_TMPDIR/inaccessible"
    mkdir -p "$parent"
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="true"\n' > "$parent/state"
    chmod 000 "$parent"
    run bash -c 'source "$1"; _tavs_visual_restrictions_read "$2"; printf "%s" "$_TAVS_VISUAL_RESTRICTIONS_STATUS"' _ "$LIB" "$parent/state"
    local actual="$output" result="$status"
    chmod 700 "$parent"
    [ "$result" -eq 0 ]
    [ "$actual" = unavailable ]
}

@test "invalid parents are unavailable while accessible missing directories remain active" {
    source "$LIB"
    ln -s "$BATS_TEST_TMPDIR/missing" "$BATS_TEST_TMPDIR/parent-link"
    printf data > "$BATS_TEST_TMPDIR/parent-file"
    _tavs_visual_restrictions_read "$BATS_TEST_TMPDIR/parent-link/state"
    [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = unavailable ]
    _tavs_visual_restrictions_read "$BATS_TEST_TMPDIR/parent-file/state"
    [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = unavailable ]
    _tavs_visual_restrictions_read "$BATS_TEST_TMPDIR/missing/nested/state"
    [ "$_TAVS_VISUAL_RESTRICTIONS_STATUS" = active ]
}
