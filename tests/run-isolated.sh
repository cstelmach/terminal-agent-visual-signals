#!/bin/bash -p
set -eu

if [[ $# -eq 0 || "${TAVS_TEST_HELPER_BIN:-}" != /* || ! -x "${TAVS_TEST_HELPER_BIN:-}" ]]; then
    printf 'Usage: TAVS_TEST_HELPER_BIN=/absolute/source-built/TAVSApp %s command [args...]\n' "$0" >&2
    exit 2
fi

umask 077
test_root=$(mktemp -d "${TMPDIR:-/tmp}/tavs-isolated.XXXXXX")
mkdir -p "$test_root/home" "$test_root/tmp" "$test_root/runtime" "$test_root/state" \
    "$test_root/xdg" "$test_root/cache"
: > "$test_root/tty"
printf 'Isolated test log: %s/command.log\n' "$test_root"

# Run the command detached from this process tree. Producer discovery walks parent PIDs, so a
# caller inside an interactive terminal (e.g. an agent session on /dev/ttysNNN) would otherwise
# be found above the tests' owned PTYs and bind their context to the wrong device. The double
# fork re-parents the command to launchd; it leads its own process group so a timeout or
# interrupt here can still terminate the whole run instead of orphaning it.
(
    set -m
    (
        env -i PATH="$PATH" SHELL=/bin/bash TERM=xterm-256color PYTHONDONTWRITEBYTECODE=1 \
            HOME="$test_root/home" CFFIXED_USER_HOME="$test_root/home" ZDOTDIR="$test_root/home" \
            TMPDIR="$test_root/tmp" XDG_RUNTIME_DIR="$test_root/xdg" XDG_CACHE_HOME="$test_root/cache" \
            TAVS_RUNTIME_DIR="$test_root/runtime" TAVS_TMP_DIR="$test_root/state" \
            _TAVS_TMP_DIR="$test_root/state" TTY_DEVICE="$test_root/tty" \
            TAVS_TEST_ROOT="$test_root" TAVS_TEST_HELPER_BIN="$TAVS_TEST_HELPER_BIN" \
            "$@" </dev/null > "$test_root/command.log" 2>&1 && rc=0 || rc=$?
        printf '%s\n' "$rc" > "$test_root/status.tmp" && mv "$test_root/status.tmp" "$test_root/status"
    ) &
    printf '%s\n' "$!" > "$test_root/pgid"
) </dev/null >/dev/null 2>&1
detached_pgid=$(cat "$test_root/pgid")
trap 'kill -TERM -- "-$detached_pgid" 2>/dev/null; exit 130' INT TERM HUP ALRM
while [[ ! -f "$test_root/status" ]]; do sleep 0.2; done
trap - INT TERM HUP ALRM
status=$(cat "$test_root/status")

# Retain the owned directory so failures and background-worker evidence remain inspectable.
if [[ "$status" -eq 0 ]]; then tail -n 3 "$test_root/command.log"
else tail -n 20 "$test_root/command.log"
fi
exit "$status"
