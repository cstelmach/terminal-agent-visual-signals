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
# ==============================================================================

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASELINE_DIR="$REPO_ROOT/tests/bench/baseline-bytes"
STATES=(processing permission compacting subagent-start tool_error reset)

# Capture states that spawn background workers (complete, idle) is unreliable
# because fd-3 writes in the worker fork don't land in the TTY_DEVICE file.
# Those are covered by integration tests (idle-worker-mute.bats).

_capture_one() {
    local state="$1"
    local outfile="$2"
    local tmp
    tmp=$(mktemp)
    # Drop any mute state for baseline capture
    # Run with minimal env to keep determinism
    env -i HOME="$HOME" PATH="$PATH" TTY_DEVICE="$tmp" \
        bash "$REPO_ROOT/src/core/trigger.sh" "$state" 2>/dev/null || true
    cp "$tmp" "$outfile"
    rm -f "$tmp"
}

_capture_all() {
    mkdir -p "$BASELINE_DIR"
    # Ensure no mute.state exists during capture
    local mute_backup=""
    if [[ -f "$HOME/.tavs/mute.state" ]]; then
        mute_backup="$HOME/.tavs/mute.state.baseline-backup"
        mv "$HOME/.tavs/mute.state" "$mute_backup"
    fi

    for s in "${STATES[@]}"; do
        _capture_one "$s" "$BASELINE_DIR/${s}.bytes"
        echo "captured $s: $(wc -c < "$BASELINE_DIR/${s}.bytes" | tr -d ' ') bytes"
    done

    # Restore mute state if we backed it up
    [[ -n "$mute_backup" ]] && mv "$mute_backup" "$HOME/.tavs/mute.state"
    return 0
}

_diff_all() {
    local any_diff=0
    for s in "${STATES[@]}"; do
        local baseline="$BASELINE_DIR/${s}.bytes"
        local current
        current=$(mktemp)
        local mute_backup=""
        if [[ -f "$HOME/.tavs/mute.state" ]]; then
            mute_backup="$HOME/.tavs/mute.state.baseline-diff-backup"
            mv "$HOME/.tavs/mute.state" "$mute_backup"
        fi

        env -i HOME="$HOME" PATH="$PATH" TTY_DEVICE="$current" \
            bash "$REPO_ROOT/src/core/trigger.sh" "$s" 2>/dev/null || true

        [[ -n "$mute_backup" ]] && mv "$mute_backup" "$HOME/.tavs/mute.state"

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
    return "$any_diff"
}

case "${1:-capture}" in
    --diff|diff)  _diff_all ;;
    *)            _capture_all ;;
esac
