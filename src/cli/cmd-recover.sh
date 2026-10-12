#!/bin/bash

source "$CLI_DIR/cli-utils.sh"
source "$TAVS_ROOT/src/core/visual-restrictions-state.sh"

cmd_recover() {
    local mode=recover suspended=true
    if [[ $# -eq 1 && ( "$1" == --help || "$1" == -h ) ]]; then
        cat <<'HELP'
tavs recover - Suspend visual restrictions and restore visibility

Usage:
  tavs recover
  tavs recover --resume

Suspension is saved before the separate native recovery process runs.
Recovery needs no challenge and preserves sessions, saved rules and grants.
Resume permits current rules again and leaves selective focus Off.
A nonzero result means persistence failed or native recovery is incomplete.
HELP
        return 0
    fi
    if [[ $# -eq 1 && "$1" == --resume ]]; then
        mode=resume
        suspended=false
    elif [[ $# -ne 0 ]]; then
        cli_error 'Usage: tavs recover [--resume]'
        return 1
    fi

    if ! _tavs_visual_restrictions_write "$suspended"; then
        cli_error 'Could not save visual restriction state. Recovery was not started.'
        return 1
    fi

    local helper support=""
    if [[ "${TAVS_TEST_HELPER_BIN+x}" == x ]]; then
        helper="$TAVS_TEST_HELPER_BIN"
    else
        helper=/Applications/TAVS.app/Contents/MacOS/TAVSApp
    fi
    if [[ -x "$helper" ]]; then
        support=$(env -u TAVS_SESSIONS_TEST_ROOT -u TAVS_SESSIONS_TEST_FIXTURE \
            -u TAVS_SESSIONS_TEST_TARGETS "$helper" --validate-config --managed-output-capabilities \
            2>/dev/null) || support=""
    fi
    if [[ "$support" != tavs-managed-output-schema=1 ]]; then
        cli_error 'State saved; native recovery helper unavailable or unsupported.'
        return 1
    fi

    # Preserve dedicated-target test settings for recovery discovery, not only private paths.
    "$helper" --visual-recover "$HOME/.tavs/visual-restrictions.state" \
        "${TAVS_RUNTIME_DIR:-/tmp/tavs-$UID}" "$mode"
}
