#!/bin/bash
# Ordinary hooks choose one backend before intake; operation failures never change it.
if [[ -n "${BASH_VERSION:-}" ]]; then
    _tavs_helper_source="${BASH_SOURCE[0]}"
else
    _tavs_helper_source="${(%):-%x}"
fi
[[ "$_tavs_helper_source" == */* ]] || _tavs_helper_source="./$_tavs_helper_source"
_TAVS_HELPER_DIR="$(cd "${_tavs_helper_source%/*}" && pwd -P)"
unset _tavs_helper_source

_tavs_helper_native_candidate() {
    if [[ "${TAVS_TEST_HELPER_BIN+x}" == x ]]; then
        printf '%s' "$TAVS_TEST_HELPER_BIN"
    else
        printf '%s' /Applications/TAVS.app/Contents/MacOS/TAVSApp
    fi
}

# Completed intake, including failure, carries the matching choice across exec.
case "$(typeset -p _TAVS_HELPER_CHECKED 2>/dev/null)" in
    'declare -x '*|'export '*)
        _tavs_import_candidate=""
        case "${_TAVS_HELPER_BACKEND:-}" in
            native) _tavs_import_candidate=$(_tavs_helper_native_candidate) ;;
            portable) _tavs_import_candidate="$_TAVS_HELPER_DIR/portable_helper.py" ;;
        esac
        _tavs_import_intake=0
        if [[ "${TAVS_ORGANIZER_INTAKE:-}" == 1 && -n "${TAVS_ORGANIZER_CONTEXT:-}" ]] \
            || [[ "${TAVS_ORGANIZER_INTAKE:-}" == 0 && -z "${TAVS_ORGANIZER_CONTEXT:-}" ]]; then
            _tavs_import_intake=1
        fi
        if [[ "${_TAVS_HELPER_CHECKED:-0}" != 1 || "$_tavs_import_intake" != 1 \
            || "${_TAVS_HELPER_BIN:-}" != "$_tavs_import_candidate" \
            || ! -x "$_tavs_import_candidate" ]]; then
            unset _TAVS_HELPER_CHECKED _TAVS_HELPER_BIN _TAVS_HELPER_BACKEND
        fi
        unset _tavs_import_candidate _tavs_import_intake ;;
esac
# Sourcing inside shell startup must not make the cache local to its loader function.
if [[ -n "${BASH_VERSION:-}" ]]; then
    export -n _TAVS_HELPER_CHECKED _TAVS_HELPER_BIN _TAVS_HELPER_BACKEND
else
    typeset -g +x _TAVS_HELPER_CHECKED _TAVS_HELPER_BIN _TAVS_HELPER_BACKEND
fi

_tavs_helper_select() {
    if [[ "${_TAVS_HELPER_CHECKED:-0}" != 1 ]]; then
        _TAVS_HELPER_CHECKED=1 _TAVS_HELPER_BIN="" _TAVS_HELPER_BACKEND=""
        local native portable organizer="" managed="" support=""
        native=$(_tavs_helper_native_candidate)
        if [[ -x "$native" ]]; then
            organizer=$(env -u TAVS_SESSIONS_TEST_ROOT -u TAVS_SESSIONS_TEST_FIXTURE \
                -u TAVS_SESSIONS_TEST_TARGETS "$native" --validate-config --organizer-capabilities \
                2>/dev/null) || organizer=""
            managed=$(env -u TAVS_SESSIONS_TEST_ROOT -u TAVS_SESSIONS_TEST_FIXTURE \
                -u TAVS_SESSIONS_TEST_TARGETS "$native" --validate-config --managed-output-capabilities \
                2>/dev/null) || managed=""
        fi
        if [[ "$organizer" == tavs-organizer-schema=1 && "$managed" == tavs-managed-output-schema=1 ]]; then
            _TAVS_HELPER_BIN="$native" _TAVS_HELPER_BACKEND=native
        else
            portable="$_TAVS_HELPER_DIR/portable_helper.py"
            if [[ -x "$portable" ]]; then
                # Portable scope rejection must remain visible to its own capability check.
                support=$("$portable" --validate-config --portable-ordinary-capabilities 2>/dev/null) || support=""
            fi
            if [[ "$support" == tavs-portable-ordinary-schema=1 ]]; then
                _TAVS_HELPER_BIN="$portable" _TAVS_HELPER_BACKEND=portable
            fi
        fi
    fi
    [[ -n "$_TAVS_HELPER_BIN" ]]
}

_tavs_helper_call() {
    _tavs_helper_select || return 1
    "$_TAVS_HELPER_BIN" "$@"
}
