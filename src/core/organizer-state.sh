#!/bin/bash

# Import only a matching executable cache with the existing intake/context hint.
if [[ "$(declare -p _TAVS_ORGANIZER_HELPER_CHECKED 2>/dev/null)" == 'declare -x '* ]]; then
    if [[ "${TAVS_TEST_HELPER_BIN+x}" == x ]]; then
        _tavs_import_helper="$TAVS_TEST_HELPER_BIN"
    else
        _tavs_import_helper=/Applications/TAVS.app/Contents/MacOS/TAVSApp
    fi
    if [[ "${_TAVS_ORGANIZER_HELPER_CHECKED:-0}" != 1 || "${TAVS_ORGANIZER_INTAKE:-0}" != 1 \
        || -z "${TAVS_ORGANIZER_CONTEXT:-}" || "${_TAVS_ORGANIZER_HELPER:-}" != "$_tavs_import_helper" \
        || ! -x "$_tavs_import_helper" ]]; then
        unset _TAVS_ORGANIZER_HELPER_CHECKED _TAVS_ORGANIZER_HELPER
    fi
    unset _tavs_import_helper
fi
# A verified adapter cache is used in this shell, not inherited by later children.
export -n _TAVS_ORGANIZER_HELPER_CHECKED _TAVS_ORGANIZER_HELPER

_tavs_organizer_helper() {
    if [[ "${_TAVS_ORGANIZER_HELPER_CHECKED:-0}" != 1 ]]; then
        _TAVS_ORGANIZER_HELPER_CHECKED=1
        if [[ "${TAVS_TEST_HELPER_BIN+x}" == x ]]; then
            _TAVS_ORGANIZER_HELPER="$TAVS_TEST_HELPER_BIN"
        else
            _TAVS_ORGANIZER_HELPER=/Applications/TAVS.app/Contents/MacOS/TAVSApp
        fi
        local support=""
        if [[ -x "$_TAVS_ORGANIZER_HELPER" ]]; then
            support=$(env -u TAVS_SESSIONS_TEST_ROOT -u TAVS_SESSIONS_TEST_FIXTURE \
                -u TAVS_SESSIONS_TEST_TARGETS "$_TAVS_ORGANIZER_HELPER" \
                --validate-config --organizer-capabilities 2>/dev/null) || support=""
        fi
        [[ "$support" == "tavs-organizer-schema=1" ]] || _TAVS_ORGANIZER_HELPER=""
    fi
    [[ -n "$_TAVS_ORGANIZER_HELPER" ]]
}

_tavs_organizer_call() {
    env -u TAVS_SESSIONS_TEST_ROOT -u TAVS_SESSIONS_TEST_FIXTURE \
        -u TAVS_SESSIONS_TEST_TARGETS "$_TAVS_ORGANIZER_HELPER" "$@"
}

_tavs_organizer_intake() {
    local provider="$1" caller="$2" key value valid=0
    local mode="default" transcript="" session="" cwd="" context=""
    unset _TAVS_ORGANIZER_HELPER_CHECKED _TAVS_ORGANIZER_HELPER
    unset _TAVS_HOOK_PAYLOAD TAVS_ORGANIZER_INTAKE TAVS_ORGANIZER_CONTEXT
    if _tavs_organizer_helper; then
        while IFS= read -r -d '' key && IFS= read -r -d '' value; do
            case "$key" in
                TAVS_PERMISSION_MODE) mode="$value" ;;
                TAVS_TRANSCRIPT_PATH) transcript="$value" ;;
                TAVS_SESSION_ID) session="$value" ;;
                TAVS_CWD) cwd="$value" ;;
                TAVS_ORGANIZER_CONTEXT) context="$value" ;;
                TAVS_ORGANIZER_INTAKE) [[ "$value" == 1 ]] && valid=1 ;;
            esac
        done < <(_tavs_organizer_call --organizer-intake "$provider" "$caller")
    fi
    export TAVS_PERMISSION_MODE="$mode" TAVS_TRANSCRIPT_PATH="$transcript"
    export TAVS_SESSION_ID="$session" TAVS_CWD="$cwd"
    if [[ "$valid" == 1 && -n "$context" ]]; then
        export TAVS_ORGANIZER_CONTEXT="$context" TAVS_ORGANIZER_INTAKE=1
        export _TAVS_ORGANIZER_HELPER_CHECKED _TAVS_ORGANIZER_HELPER
        return 0
    fi
    printf 'tavs: organizer metadata unavailable\n' >&2
    return 1
}

_tavs_organizer_begin() {
    _tavs_organizer_helper || return 0
    if [[ "${TAVS_ORGANIZER_SYNTHETIC:-0}" == 1 ]]; then return 0; fi
    if [[ "${TAVS_ORGANIZER_INTAKE:-0}" != 1 ]]; then
        TAVS_ORGANIZER_CONTEXT=$(_tavs_organizer_call --organizer-context \
            "${TAVS_AGENT:-unknown}" "$$") || return 0
        export TAVS_ORGANIZER_CONTEXT
    fi
    unset TAVS_ORGANIZER_INTAKE
    [[ -n "${TAVS_ORGANIZER_CONTEXT:-}" ]] || return 0
    _tavs_organizer_call --organizer-observe "$TTY_DEVICE" "$TAVS_ORGANIZER_CONTEXT" "$1" \
        || printf 'tavs: organizer observation unavailable\n' >&2
}

_tavs_managed_helper() {
    if [[ "${_TAVS_MANAGED_HELPER_CHECKED:-0}" != 1 ]]; then
        _TAVS_MANAGED_HELPER_CHECKED=1
        if [[ "${TAVS_TEST_HELPER_BIN+x}" == x ]]; then
            _TAVS_MANAGED_HELPER="$TAVS_TEST_HELPER_BIN"
        else
            _TAVS_MANAGED_HELPER=/Applications/TAVS.app/Contents/MacOS/TAVSApp
        fi
        local support=""
        if [[ -x "$_TAVS_MANAGED_HELPER" ]]; then
            support=$(env -u TAVS_SESSIONS_TEST_ROOT -u TAVS_SESSIONS_TEST_FIXTURE \
                -u TAVS_SESSIONS_TEST_TARGETS "$_TAVS_MANAGED_HELPER" \
                --validate-config --managed-output-capabilities 2>/dev/null) || support=""
        fi
        [[ "$support" == tavs-managed-output-schema=1 ]] || _TAVS_MANAGED_HELPER=""
    fi
    [[ -n "$_TAVS_MANAGED_HELPER" ]]
}

_tavs_managed_context() {
    [[ -n "${TAVS_ORGANIZER_CONTEXT:-}" ]] && return 0
    [[ "${TAVS_ORGANIZER_SYNTHETIC:-0}" == 1 ]] && return 3
    _tavs_organizer_helper || return 1
    TAVS_ORGANIZER_CONTEXT=$(_tavs_organizer_call --organizer-context \
        "${TAVS_AGENT:-unknown}" "$$") || return 1
    export TAVS_ORGANIZER_CONTEXT
    [[ -n "$TAVS_ORGANIZER_CONTEXT" ]]
}

_tavs_managed_forced_reset() {
    _tavs_managed_helper && _tavs_managed_context || return 1
    "$_TAVS_MANAGED_HELPER" --managed-forced-reset "$HOME/.tavs/visual-restrictions.state" \
        "${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}" "$TTY_DEVICE" "$TAVS_ORGANIZER_CONTEXT" \
        "$1" >/dev/null
}

_tavs_managed_check_context() {
    _TAVS_MANAGED_STALE=0
    local result=0
    if _tavs_managed_helper && _tavs_managed_context; then
        "$_TAVS_MANAGED_HELPER" --managed-check-context "$HOME/.tavs/visual-restrictions.state" \
            "${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}" "$TTY_DEVICE" "$TAVS_ORGANIZER_CONTEXT" \
            >/dev/null || result=$?
    else
        result=1
    fi
    [[ "$result" == 0 ]] || _TAVS_MANAGED_STALE=1
    return "$result"
}

_tavs_managed_reconcile() {
    _tavs_managed_helper || return 1
    "$_TAVS_MANAGED_HELPER" --managed-reconcile "$HOME/.tavs/visual-restrictions.state" \
        "${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}" "$1" "$$" >/dev/null
}

_tavs_render_begin() {
    _TAVS_RENDER_ACTIVE=1 _TAVS_RENDER_PENDING=0
    _TAVS_RENDER_BG="" _TAVS_RENDER_PALETTE="" _TAVS_RENDER_TITLE=""
    _TAVS_RENDER_TITLE_FLAG=0 _TAVS_RENDER_TITLE_SAVE=0
    _TAVS_RENDER_IMAGE="" _TAVS_RENDER_IMAGE_PATH="" _TAVS_RENDER_BELL=0
    _TAVS_RENDER_COLORS=()
    local i
    for ((i=0; i<16; i++)); do _TAVS_RENDER_COLORS[i]=""; done
}

_tavs_render_queue() {
    [[ "$1" == bell && "${TAVS_ORGANIZER_SYNTHETIC:-0}" == 1 ]] && return 0
    local own_batch=0 i
    if [[ "${_TAVS_RENDER_ACTIVE:-0}" != 1 ]]; then
        _tavs_render_begin
        own_batch=1
    fi
    case "$1" in
        background) _TAVS_RENDER_BG="$2" ;;
        palette)
            _TAVS_RENDER_PALETTE="$2"
            shift 2
            _TAVS_RENDER_COLORS=("$@")
            for ((i=${#_TAVS_RENDER_COLORS[@]}; i<16; i++)); do _TAVS_RENDER_COLORS[i]=""; done ;;
        title)
            _TAVS_RENDER_TITLE_FLAG=1 _TAVS_RENDER_TITLE="$2"
            _TAVS_RENDER_TITLE_SAVE="${3:-0}" ;;
        image) _TAVS_RENDER_IMAGE="$2" _TAVS_RENDER_IMAGE_PATH="${3:-}" ;;
        bell) _TAVS_RENDER_BELL=1 ;;
        *) return 1 ;;
    esac
    _TAVS_RENDER_PENDING=1
    if [[ "$own_batch" == 1 ]]; then _tavs_render_flush; fi
}

_tavs_render_payload() {
    printf '%s\0' "$_TAVS_RENDER_BG" "$_TAVS_RENDER_PALETTE" "${_TAVS_RENDER_COLORS[@]}" \
        "$_TAVS_RENDER_TITLE_FLAG" "$_TAVS_RENDER_TITLE" "$_TAVS_RENDER_IMAGE" \
        "$_TAVS_RENDER_IMAGE_PATH" "$_TAVS_RENDER_BELL"
}

_tavs_render_flush() {
    _TAVS_RENDER_ACTIVE=0 _TAVS_MANAGED_STALE=0
    [[ "${_TAVS_RENDER_PENDING:-0}" == 1 ]] || return 0
    local result=0 outcome=""
    if _tavs_managed_helper; then
        _tavs_managed_context || result=$?
    else
        _TAVS_MANAGED_HELPER_CHECKED=0
        result=1
    fi
    if [[ "$result" == 0 ]]; then
        outcome=$(_tavs_render_payload | "$_TAVS_MANAGED_HELPER" --managed-render \
            "$HOME/.tavs/visual-restrictions.state" "${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}" \
            "$TTY_DEVICE" "$TAVS_ORGANIZER_CONTEXT" "${TAVS_ORGANIZER_SYNTHETIC:-0}") || result=$?
    fi
    _TAVS_RENDER_PENDING=0
    if [[ "$result" == 0 ]]; then
        case "$outcome" in
            rendered)
                if [[ "$_TAVS_RENDER_TITLE_SAVE" == 1 ]]; then
                    _tavs_render_title_delivered
                fi ;;
            restricted|unaffected) ;;
            *) result=1 ;;
        esac
    fi
    if [[ "$result" != 0 ]]; then
        [[ "$result" == 3 ]] && _TAVS_MANAGED_STALE=1
        printf 'tavs: current render unavailable\n' >&2
    fi
    return "$result"
}
