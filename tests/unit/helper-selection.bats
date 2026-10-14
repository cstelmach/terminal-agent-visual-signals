#!/usr/bin/env bats

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" ]] || return 1
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIXTURE="$BATS_TEST_TMPDIR/core with spaces"
    mkdir -p "$FIXTURE"
    FIXTURE="$(cd "$FIXTURE" && pwd -P)"
    cp "$REPO_ROOT/src/core/helper-selection.sh" "$FIXTURE/helper-selection.sh"
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/native" CALLS="$BATS_TEST_TMPDIR/calls"
    export NATIVE_MODE=both PORTABLE_MODE=healthy
    cat > "$TAVS_TEST_HELPER_BIN" <<'SH'
#!/bin/bash
printf 'native:%s:%s\n' "$1" "$2" >> "$CALLS"
[[ -z "${TAVS_SESSIONS_TEST_ROOT+x}${TAVS_SESSIONS_TEST_TARGETS+x}${TAVS_SESSIONS_TEST_FIXTURE+x}" ]] || exit 43
case "$1:$2:$NATIVE_MODE" in
    --validate-config:--organizer-capabilities:both|--validate-config:--organizer-capabilities:organizer)
        printf 'tavs-organizer-schema=1\n' ;;
    --validate-config:--managed-output-capabilities:both|--validate-config:--managed-output-capabilities:managed)
        printf 'tavs-managed-output-schema=1\n' ;;
    *) exit 1 ;;
esac
SH
    cat > "$FIXTURE/portable_helper.py" <<'SH'
#!/bin/bash
printf 'portable:%s:%s\n' "$1" "$2" >> "$CALLS"
[[ -z "${TAVS_SESSIONS_TEST_ROOT+x}${TAVS_SESSIONS_TEST_TARGETS+x}${TAVS_SESSIONS_TEST_FIXTURE+x}" ]] || exit 43
if [[ "$1:$2" == --validate-config:--portable-ordinary-capabilities ]]; then
    [[ "$PORTABLE_MODE" != unsupported ]] || exit 1
    printf 'tavs-portable-ordinary-schema=1\n'
else
    exit 3
fi
SH
    chmod +x "$TAVS_TEST_HELPER_BIN" "$FIXTURE/portable_helper.py"
}

_select() {
    "$1" -c 'source "$1/helper-selection.sh"; _tavs_helper_select || exit; printf "%s\n%s\n" "$_TAVS_HELPER_BACKEND" "$_TAVS_HELPER_BIN"' _ "$FIXTURE"
}

@test "Bash and zsh prefer one native helper with both exact capabilities" {
    local shell
    for shell in /bin/bash /bin/zsh; do
        : > "$CALLS"
        run _select "$shell"
        [ "$status" -eq 0 ]
        [ "$output" = "native"$'\n'"$TAVS_TEST_HELPER_BIN" ]
        [ "$(wc -l < "$CALLS")" -eq 2 ]
        [[ "$(cat "$CALLS")" != *portable* ]]
    done
}

@test "partial or unsupported native capability selects only the ordinary portable backend" {
    local mode shell
    for mode in organizer managed unsupported; do
        export NATIVE_MODE="$mode"
        for shell in /bin/bash /bin/zsh; do
            run _select "$shell"
            [ "$status" -eq 0 ]
            [ "$output" = "portable"$'\n'"$FIXTURE/portable_helper.py" ]
        done
    done
}

@test "explicit empty and missing native overrides still select the portable candidate" {
    local candidate
    for candidate in '' "$BATS_TEST_TMPDIR/missing"; do
        export TAVS_TEST_HELPER_BIN="$candidate"
        : > "$CALLS"
        run _select /bin/bash
        [ "$status" -eq 0 ]
        [ "$output" = "portable"$'\n'"$FIXTURE/portable_helper.py" ]
        [[ "$(cat "$CALLS")" != *native:* ]]
    done
}

@test "module sourced by a bare filename resolves its adjacent portable helper" {
    export NATIVE_MODE=unsupported
    local shell
    for shell in /bin/bash /bin/zsh; do
        run "$shell" -c 'cd "$1"; source helper-selection.sh; _tavs_helper_select || exit; printf "%s" "$_TAVS_HELPER_BIN"' _ "$FIXTURE"
        [ "$status" -eq 0 ]
        [ "$output" = "$FIXTURE/portable_helper.py" ]
    done
}

@test "selected operation failure is returned without changing backend or reprobe" {
    export NATIVE_MODE=unsupported
    local shell
    for shell in /bin/bash /bin/zsh; do
        : > "$CALLS"
        run "$shell" -c '
source "$1/helper-selection.sh"
_tavs_helper_select || exit 42
NATIVE_MODE=both
_tavs_helper_call --managed-current marker || result=$?
[[ "$result" == 3 && "$_TAVS_HELPER_BACKEND" == portable ]] || exit 43
_tavs_helper_select
' _ "$FIXTURE"
        [ "$status" -eq 0 ]
        [ "$(wc -l < "$CALLS")" -eq 4 ]
        [ "$(tail -1 "$CALLS")" = 'portable:--managed-current:marker' ]
    done
}

@test "selection survives sourcing the module inside a function in Bash and zsh" {
    local shell
    for shell in /bin/bash /bin/zsh; do
        : > "$CALLS"
        run "$shell" -c '
load_selector() { source "$1/helper-selection.sh"; _tavs_helper_select; }
load_selector "$1" || exit 42
NATIVE_MODE=unsupported
_tavs_helper_call --managed-current marker || result=$?
[[ "$result" == 1 && "$_TAVS_HELPER_BACKEND" == native ]]
' _ "$FIXTURE"
        [ "$status" -eq 0 ]
        [ "$(wc -l < "$CALLS")" -eq 3 ]
        [[ "$(cat "$CALLS")" != *portable:* ]]
    done
}

@test "native probes remove dedicated scope while native operations retain it" {
    export TAVS_SESSIONS_TEST_TARGETS=dedicated
    run /bin/bash -c '
source "$1/helper-selection.sh"
_tavs_helper_select || exit 42
_tavs_helper_call --managed-current marker || result=$?
[[ "$result" == 43 && "$_TAVS_HELPER_BACKEND" == native ]]
' _ "$FIXTURE"
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$CALLS")" -eq 3 ]
}

@test "portable selection preserves every dedicated scope key including empty values" {
    export NATIVE_MODE=unsupported
    local key shell
    for key in TAVS_SESSIONS_TEST_ROOT TAVS_SESSIONS_TEST_TARGETS TAVS_SESSIONS_TEST_FIXTURE; do
        for shell in /bin/bash /bin/zsh; do
            run env "$key=" "$shell" -c 'source "$1/helper-selection.sh"; _tavs_helper_select' _ "$FIXTURE"
            [ "$status" -eq 1 ]
            [ "$output" = '' ]
        done
    done
}

@test "scope introduced after portable selection still reaches the selected operation" {
    export NATIVE_MODE=unsupported
    run /bin/bash -c '
source "$1/helper-selection.sh"
_tavs_helper_select || exit 42
export TAVS_SESSIONS_TEST_TARGETS=""
_tavs_helper_call --managed-current marker || result=$?
[[ "$result" == 43 && "$_TAVS_HELPER_BACKEND" == portable ]]
' _ "$FIXTURE"
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$CALLS")" -eq 4 ]
}

@test "unavailable selection is cached and does not expose probe output" {
    export NATIVE_MODE=unsupported PORTABLE_MODE=unsupported
    run /bin/bash -c '
source "$1/helper-selection.sh"
_tavs_helper_select || first=$?
PORTABLE_MODE=healthy
_tavs_helper_select || second=$?
[[ "$first" == 1 && "$second" == 1 && -z "$_TAVS_HELPER_BIN" ]]
' _ "$FIXTURE"
    [ "$status" -eq 0 ]
    [ "$output" = '' ]
    [ "$(wc -l < "$CALLS")" -eq 3 ]
}

@test "imported cache requires an intake hint and never leaks into later children" {
    local shell
    for shell in /bin/bash /bin/zsh; do
        : > "$CALLS"
        run env _TAVS_HELPER_CHECKED=1 _TAVS_HELPER_BACKEND=native _TAVS_HELPER_BIN="$TAVS_TEST_HELPER_BIN" \
            "$shell" -c '
source "$1/helper-selection.sh"
_tavs_helper_select || exit 42
[[ -z "$(env | /usr/bin/grep "^_TAVS_HELPER_")" ]]
' _ "$FIXTURE"
        [ "$status" -eq 0 ]
        [ "$(wc -l < "$CALLS")" -eq 2 ]
        : > "$CALLS"
        run env _TAVS_HELPER_CHECKED=1 _TAVS_HELPER_BACKEND=native _TAVS_HELPER_BIN="$TAVS_TEST_HELPER_BIN" \
            TAVS_ORGANIZER_INTAKE=1 TAVS_ORGANIZER_CONTEXT=context "$shell" -c '
source "$1/helper-selection.sh"
_tavs_helper_select || exit 42
[[ -z "$(env | /usr/bin/grep "^_TAVS_HELPER_")" ]]
' _ "$FIXTURE"
        [ "$status" -eq 0 ]
        [ ! -s "$CALLS" ]
        run env _TAVS_HELPER_CHECKED=1 _TAVS_HELPER_BACKEND=native _TAVS_HELPER_BIN="$TAVS_TEST_HELPER_BIN" \
            TAVS_ORGANIZER_INTAKE=0 "$shell" -c '
source "$1/helper-selection.sh"
_tavs_helper_select || exit 42
[[ -z "$(env | /usr/bin/grep "^_TAVS_HELPER_")" ]]
' _ "$FIXTURE"
        [ "$status" -eq 0 ]
        [ ! -s "$CALLS" ]
    done
}
