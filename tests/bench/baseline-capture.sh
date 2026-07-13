#!/bin/bash
# ==============================================================================
# TAVS Baseline OSC Byte Capture
# ==============================================================================
# Captures the raw OSC byte output of trigger.sh per state to
# tests/bench/baseline-bytes/<state>.bytes for regression comparison.
#
# Usage:
#   ./tests/bench/baseline-capture.sh           # Capture (overwrite existing)
#   ./tests/bench/baseline-capture.sh --diff    # Diff current output vs baseline
#
# Safety: every trigger run executes inside an isolated $HOME (mktemp -d).
# This was previously a `mv ~/.tavs/mute.state ...` dance, which raced the
# menu-bar app's heartbeat (re-creating the file mid-test) and could leave
# the user's live mute.state permanently displaced if the test process was
# interrupted. The isolated HOME removes both failure modes by construction:
# the user's `~/.tavs/` is never touched.
# ==============================================================================

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASELINE_DIR="$REPO_ROOT/tests/bench/baseline-bytes"
STATES=(processing permission compacting subagent-start tool_error reset)

# Capture states that spawn background workers (complete, idle) is unreliable
# because fd-3 writes in the worker fork don't land in the TTY_DEVICE file.
# Those are covered by integration tests (idle-worker-mute.bats).

# Build a minimal isolated HOME containing only the directory layout trigger.sh
# expects. Returns the path so the caller can cleanup. Caller MUST set a trap
# to remove the directory on EXIT/INT/TERM.
_make_isolated_home() {
    local iso
    iso=$(mktemp -d "${TMPDIR:-/tmp}/tavs-baseline-home.XXXXXX")
    mkdir -p "$iso/.tavs" "$iso/runtime"
    echo "$iso"
}

_capture_one() {
    local state="$1"
    local outfile="$2"
    local iso_home="$3"
    local tmp
    tmp=$(mktemp)
    # env -i wipes inherited variables; trigger.sh re-derives everything from
    # the few we forward. HOME points at the isolated dir so any read or
    # write to ~/.tavs/* lands there. TAVS_RUNTIME_DIR must be isolated too:
    # the identity registry lives there, and reset bytes embed the dir icon.
    # Without this, live-session registry churn drifts the golden (observed:
    # dir flag 🇧🇬 → 🇧🇪 made same-size byte diffs).
    env -i HOME="$iso_home" PATH="$PATH" TTY_DEVICE="$tmp" \
        TAVS_RUNTIME_DIR="$iso_home/runtime" \
        bash "$REPO_ROOT/src/core/trigger.sh" "$state" 2>/dev/null || true
    cp "$tmp" "$outfile"
    rm -f "$tmp"
}

_capture_all() {
    mkdir -p "$BASELINE_DIR"
    local iso_home
    iso_home=$(_make_isolated_home)
    trap 'rm -rf "$iso_home"' EXIT INT TERM

    for s in "${STATES[@]}"; do
        _capture_one "$s" "$BASELINE_DIR/${s}.bytes" "$iso_home"
        echo "captured $s: $(wc -c < "$BASELINE_DIR/${s}.bytes" | tr -d ' ') bytes"
    done

    rm -rf "$iso_home"
    trap - EXIT INT TERM
    return 0
}

_diff_all() {
    local any_diff=0
    local iso_home
    iso_home=$(_make_isolated_home)
    trap 'rm -rf "$iso_home"' EXIT INT TERM

    for s in "${STATES[@]}"; do
        local baseline="$BASELINE_DIR/${s}.bytes"
        local current
        current=$(mktemp)

        env -i HOME="$iso_home" PATH="$PATH" TTY_DEVICE="$current" \
            bash "$REPO_ROOT/src/core/trigger.sh" "$s" 2>/dev/null || true

        if [[ ! -f "$baseline" ]]; then
            echo "MISSING baseline for $s — run without --diff first"
            any_diff=1
            rm -f "$current"
            continue
        fi

        local baseline_size current_size
        baseline_size=$(wc -c < "$baseline" | tr -d ' ')
        current_size=$(wc -c < "$current" | tr -d ' ')
        if cmp -s "$baseline" "$current"; then
            echo "OK  $s ($baseline_size bytes)"
        else
            echo "DIFF $s: baseline=$baseline_size bytes, current=$current_size bytes"
            any_diff=1
        fi
        rm -f "$current"
    done

    rm -rf "$iso_home"
    trap - EXIT INT TERM
    return "$any_diff"
}

case "${1:-capture}" in
    --diff|diff)  _diff_all ;;
    *)            _capture_all ;;
esac
