#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.tavs"
    LIB="$REPO_ROOT/src/core/visual-restrictions-state.sh"
}

_check_readers() {
    local shell lib
    for shell in /bin/bash /bin/zsh; do
        for lib in "$LIB" "$REPO_ROOT/src/shell/tavs-shellrc.sh"; do
            run "$shell" -fc 'source "$1"; _tavs_visual_restrictions_read "$2"; printf "%s" "$_TAVS_VISUAL_RESTRICTIONS_STATUS"' _ "$lib" "$1"
            [ "$status" -eq 0 ]
            [ "$output" = "$2" ] || {
                printf 'reader=%s shell=%s actual=%s expected=%s\n' "$lib" "$shell" "$output" "$2" >&2
                return 1
            }
        done
    done
}

@test "unsafe marker and directory write permissions never authorize restrictions or replacement" {
    local shell object
    local file="$HOME/.tavs/visual-restrictions.state"
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="false"\n' > "$file"
    cp "$file" "$BATS_TEST_TMPDIR/before"
    for object in "$file" "$HOME/.tavs" "$HOME"; do
        chmod 777 "$object"
        _check_readers "$file" unavailable
        for shell in /bin/bash /bin/zsh; do
            run "$shell" -fc 'source "$1"; _tavs_visual_restrictions_write true "$2"' _ "$LIB" "$file"
            [ "$status" -ne 0 ]
            cmp "$file" "$BATS_TEST_TMPDIR/before"
        done
        chmod 700 "$object"
    done
}

@test "missing marker under an unsafe existing prefix is unavailable and creates nothing" {
    local prefix="$BATS_TEST_TMPDIR/unsafe-prefix" shell
    mkdir "$prefix"
    chmod 777 "$prefix"
    _check_readers "$prefix/missing/nested/state" unavailable
    for shell in /bin/bash /bin/zsh; do
        run "$shell" -fc 'source "$1"; _tavs_visual_restrictions_write true "$2"' _ "$LIB" "$prefix/missing/nested/state"
        [ "$status" -ne 0 ]
        [ ! -e "$prefix/missing" ]
    done
}

@test "arbitrary linked parents stay unavailable even when their target is owned and safe" {
    local actual="$BATS_TEST_TMPDIR/actual" shell
    mkdir "$actual"
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="false"\n' > "$actual/state"
    cp "$actual/state" "$BATS_TEST_TMPDIR/before"
    ln -s "$actual" "$BATS_TEST_TMPDIR/parent-link"
    ln -s "$BATS_TEST_TMPDIR/loop" "$BATS_TEST_TMPDIR/loop"
    _check_readers "$BATS_TEST_TMPDIR/parent-link/state" unavailable
    _check_readers "$BATS_TEST_TMPDIR/loop/state" unavailable
    for shell in /bin/bash /bin/zsh; do
        run "$shell" -fc 'source "$1"; _tavs_visual_restrictions_write true "$2"' _ "$LIB" "$BATS_TEST_TMPDIR/parent-link/state"
        [ "$status" -ne 0 ]
        cmp "$actual/state" "$BATS_TEST_TMPDIR/before"
    done
}

@test "foreign metadata on a marker or ancestor is unavailable before a read or write" {
    local file="$HOME/.tavs/visual-restrictions.state" shell lib object
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="false"\n' > "$file"
    cp "$file" "$BATS_TEST_TMPDIR/before"
    cat > "$BATS_TEST_TMPDIR/foreign-stat.sh" <<'SH'
stat() {
    local argument
    for argument in "$@"; do
        if [[ "$argument" == "$FOREIGN_OBJECT" ]]; then
            printf '%s:700\n' "$((EUID+1))"
            return 0
        fi
    done
    command stat "$@"
}
SH
    for object in "$file" "$HOME"; do
        export FOREIGN_OBJECT="$(python3 -c 'import pathlib,sys;print(pathlib.Path(sys.argv[1]).resolve())' "$object")"
        for shell in /bin/bash /bin/zsh; do
            for lib in "$LIB" "$REPO_ROOT/src/shell/tavs-shellrc.sh"; do
                run "$shell" -fc 'source "$1"; source "$2"; _tavs_visual_restrictions_read "$3"; printf "%s" "$_TAVS_VISUAL_RESTRICTIONS_STATUS"' _ "$lib" "$BATS_TEST_TMPDIR/foreign-stat.sh" "$file"
                [ "$status" -eq 0 ]
                [ "$output" = unavailable ]
            done
            run "$shell" -fc 'source "$1"; source "$2"; _tavs_visual_restrictions_write true "$3"' _ "$LIB" "$BATS_TEST_TMPDIR/foreign-stat.sh" "$file"
            [ "$status" -ne 0 ]
            cmp "$file" "$BATS_TEST_TMPDIR/before"
        done
    done
}

@test "safe physical paths aliases and readable marker permissions retain exact state" {
    local file="$HOME/.tavs/visual-restrictions.state" shell
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="false"\n' > "$file"
    chmod 644 "$file"
    _check_readers "$file" active
    file="$(python3 -c 'import pathlib,sys;print(pathlib.Path(sys.argv[1]).resolve())' "$file")"
    _check_readers "$file" active
    for shell in /bin/bash /bin/zsh; do
        run "$shell" -fc 'source "$1"; _tavs_visual_restrictions_write true "$2"' _ "$LIB" "$file"
        [ "$status" -eq 0 ]
        _check_readers "$file" suspended
    done
}

@test "writer creates only private missing directories and retains caller umask and traps" {
    local shell file
    for shell in /bin/bash /bin/zsh; do
        file="$HOME/new-${shell##*/}/nested/state"
        run "$shell" -fc '
source "$1"
trap : TERM
before=$(trap)
umask 027
_tavs_visual_restrictions_write true "$2" || exit 20
[[ "$(umask)" == *027 ]] || exit 21
[[ "$(trap)" == "$before" ]] || exit 22
' _ "$LIB" "$file"
        [ "$status" -eq 0 ]
        python3 - "$file" <<'PY'
import pathlib,stat,sys
p=pathlib.Path(sys.argv[1])
assert stat.S_IMODE(p.stat().st_mode)==0o600
assert stat.S_IMODE(p.parent.stat().st_mode)==0o700
assert stat.S_IMODE(p.parent.parent.stat().st_mode)==0o700
PY
        _check_readers "$file" suspended
    done
}

@test "invalid path components are rejected before creating a missing directory" {
    local shell file="$HOME/not-created/../state"
    _check_readers "$file" unavailable
    for shell in /bin/bash /bin/zsh; do
        run "$shell" -fc 'source "$1"; _tavs_visual_restrictions_write true "$2"' _ "$LIB" "$file"
        [ "$status" -ne 0 ]
        [ ! -e "$HOME/not-created" ]
        [ ! -e "$HOME/state" ]
    done
}

@test "failed staging validation and publication retain old bytes and remove only own temporary" {
    local file="$HOME/.tavs/visual-restrictions.state" shell failure
    printf 'SCHEMA_VERSION="1"\nSUSPENDED="true"\n' > "$file"
    cp "$file" "$BATS_TEST_TMPDIR/before"
    for shell in /bin/bash /bin/zsh; do
        for failure in rename revalidate; do
            run "$shell" -fc '
source "$1"
GUARD_DIR="$3"
if [[ "$4" == rename ]]; then
    mv() { return 23; }
else
    mktemp() { command mktemp "$@" || return 1; chmod 777 "$GUARD_DIR"; }
fi
_tavs_visual_restrictions_write false "$2"
' _ "$LIB" "$file" "$HOME/.tavs" "$failure"
            chmod 700 "$HOME/.tavs"
            [ "$status" -ne 0 ]
            cmp "$file" "$BATS_TEST_TMPDIR/before"
            local -a temporary
            shopt -s nullglob
            temporary=("$HOME/.tavs/".visual-restrictions.*)
            [ "${#temporary[@]}" -eq 0 ]
        done
    done
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
    run bash -xc '
printf "Bash=%s executable=%s\n" "$BASH_VERSION" "$BASH" >&2
type -P stat mktemp mv >&2
source "$1"
_tavs_visual_restrictions_write true
' _ "$LIB"
    printf '%s\n' "$output" > "$TAVS_TEST_ROOT/marker-writer-initial.log"
    [ "$status" -eq 0 ] || { tail -n 30 "$TAVS_TEST_ROOT/marker-writer-initial.log" >&2; return 1; }
    run zsh -fc 'source "$1"; _tavs_visual_restrictions_suspended' _ "$LIB"
    [ "$status" -eq 0 ]
    [ "$(stat -f %Lp "$HOME/.tavs/visual-restrictions.state")" = 600 ]
    run bash -xc '
printf "Bash=%s executable=%s\n" "$BASH_VERSION" "$BASH" >&2
type -P stat mktemp mv >&2
source "$1"
_tavs_visual_restrictions_write false
' _ "$LIB"
    printf '%s\n' "$output" > "$TAVS_TEST_ROOT/marker-writer-resume.log"
    [ "$status" -eq 0 ] || { tail -n 30 "$TAVS_TEST_ROOT/marker-writer-resume.log" >&2; return 1; }
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
