#!/bin/bash

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

_tavs_managed_background() {
    _TAVS_MANAGED_STALE=0
    if ! _tavs_managed_helper; then
        printf 'tavs: managed output helper unavailable or unsupported\n' >&2
        [[ "${TAVS_ORGANIZER_SYNTHETIC:-0}" == 1 ]] && _TAVS_MANAGED_STALE=1
        return 1
    fi
    local result=0
    _tavs_managed_context || result=$?
    if [[ "$result" == 0 ]]; then
        # Actual output retains the dedicated native scope; only capability queries clear it.
        "$_TAVS_MANAGED_HELPER" --managed-background "$HOME/.tavs/visual-restrictions.state" \
            "${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}" "$TTY_DEVICE" "$TAVS_ORGANIZER_CONTEXT" \
            "$1" "${TAVS_ORGANIZER_SYNTHETIC:-0}" >/dev/null || result=$?
    fi
    if [[ "$result" != 0 ]]; then
        [[ "${TAVS_ORGANIZER_SYNTHETIC:-0}" == 1 ]] && _TAVS_MANAGED_STALE=1
        printf 'tavs: managed background unavailable\n' >&2
    fi
    return "$result"
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
