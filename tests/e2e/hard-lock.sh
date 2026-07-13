#!/bin/bash
# ==============================================================================
# TAVS E2E Test — Hard Lock lifecycle
# ==============================================================================
# Linear scenario through the REAL CLI + trigger + shellrc, fully isolated
# (temp HOME + temp runtime dir): engaging, fail-closed suppression with a
# dead app PID, shellrc paint, challenge-gated unlock, grant expiry re-lock,
# and lock expiry release. Safe to run anytime; touches no live state.
#
# App-integrated visuals (broadcast paint, menu dialogs) are user-gated
# checks V1-V10 in PROGRESS.md.
#
# Usage: bash tests/e2e/hard-lock.sh
# ==============================================================================

set -euo pipefail

TAVS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="/tmp/tavs-e2e-hardlock-$(date +%Y%m%d-%H%M%S).log"
PASSED=0
FAILED=0

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
pass() { PASSED=$((PASSED + 1)); log "  PASS: $1"; }
fail() { FAILED=$((FAILED + 1)); log "  FAIL: $1"; }

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/tavs-e2e-hardlock.XXXXXX")
export HOME="$SANDBOX/home"
export TAVS_RUNTIME_DIR="$SANDBOX/runtime"
mkdir -p "$HOME/.tavs" "$TAVS_RUNTIME_DIR"

cleanup() {
    rm -rf "$SANDBOX"
}
trap cleanup EXIT

TAVS="$TAVS_ROOT/tavs"
TRIGGER="$TAVS_ROOT/src/core/trigger.sh"
SHELLRC="$TAVS_ROOT/src/shell/tavs-shellrc.sh"
LOCK_STATE="$TAVS_RUNTIME_DIR/lock.state"

# Deterministic puzzle: single-sentence pool.
echo "the quick brown fox" > "$SANDBOX/pool.txt"
cat > "$HOME/.tavs/challenge.conf" <<EOF
CHALLENGE_TYPE="puzzle"
PUZZLE_SENTENCES_FILE="$SANDBOX/pool.txt"
SCHEMA_VERSION="1"
EOF
PUZZLE_ANSWER="het uickq rownb oxf"

trigger_bytes() {
    # Runs one processing dispatch; echoes the byte count that reached the TTY.
    local cap
    cap=$(mktemp "$SANDBOX/cap.XXXXXX")
    TTY_DEVICE="$cap" bash "$TRIGGER" processing 2>/dev/null || true
    wc -c < "$cap" | tr -d ' '
}

log "E2E hard-lock scenario (sandbox: $SANDBOX)"

# --- 1. Engage ---------------------------------------------------------------
"$TAVS" lock now --for 1h >>"$LOG_FILE" 2>&1
if [[ -f "$LOCK_STATE" ]] && grep -q 'LOCKED="true"' "$LOCK_STATE"; then
    pass "lock now writes lock.state"
else
    fail "lock now did not write lock.state"
fi
if "$TAVS" lock status 2>&1 | grep -q "Effective: LOCKED"; then
    pass "lock status reports effective lock"
else
    fail "lock status wrong"
fi

# --- 2. Suppression, including fail-closed against a dead app ----------------
if [[ "$(trigger_bytes)" -eq 0 ]]; then
    pass "trigger suppressed under lock"
else
    fail "trigger NOT suppressed under lock"
fi

cat > "$HOME/.tavs/mute.state" <<EOF
MUTED="true"
REASON="quiet_period"
UNTIL_EPOCH="0"
WRITTEN_EPOCH="$(date +%s)"
APP_PID="999999"
SCHEMA_VERSION="1"
EOF
if [[ "$(trigger_bytes)" -eq 0 ]]; then
    pass "still suppressed with dead APP_PID mute.state (fail-closed)"
else
    fail "dead APP_PID broke lock suppression"
fi
rm -f "$HOME/.tavs/mute.state"

# --- 3. Shellrc paints the lock in a fresh terminal --------------------------
SHELLRC_OUT=$(zsh -fic "TTY=/dev/ttys999; source '$SHELLRC'" </dev/null 2>/dev/null || true)
if [[ "$SHELLRC_OUT" == *"locked until"* ]]; then
    pass "shellrc paints 🔒 title at shell open"
else
    fail "shellrc did not paint lock"
fi
if [[ -f "$TAVS_RUNTIME_DIR/active-ttys/_dev_ttys999" ]]; then
    pass "shellrc registered the TTY"
else
    fail "shellrc did not register TTY"
fi

# --- 4. Wrong challenge is refused --------------------------------------------
if printf 'wrong\nwrong\nwrong\n' | "$TAVS" unlock --for 15m >>"$LOG_FILE" 2>&1; then
    fail "unlock succeeded with wrong answers"
else
    pass "unlock refused after 3 wrong answers"
fi
if grep -q 'UNLOCK_UNTIL_EPOCH="0"' "$LOCK_STATE"; then
    pass "failed challenge left the lock untouched"
else
    fail "failed challenge modified the grant"
fi

# --- 5. Correct challenge grants time-boxed access ----------------------------
if printf '%s\n' "$PUZZLE_ANSWER" | "$TAVS" unlock --for 15m >>"$LOG_FILE" 2>&1; then
    pass "unlock succeeded with correct puzzle answer"
else
    fail "unlock failed with correct answer"
fi
if [[ "$(trigger_bytes)" -gt 0 ]]; then
    pass "signals flow during the grant"
else
    fail "still suppressed during grant"
fi

# --- 6. Grant expiry re-locks --------------------------------------------------
source "$TAVS_ROOT/src/core/lock-state-lib.sh"
_tavs_lock_read
_tavs_lock_write "true" "$_LS_REASON" "$_LS_LOCK_UNTIL" "$(( $(date +%s) + 2 ))" "$_LS_BG" "$_LS_FG"
sleep 3
if [[ "$(trigger_bytes)" -eq 0 ]]; then
    pass "lock re-engages after grant expiry"
else
    fail "lock did not re-engage after grant expiry"
fi

# --- 7. Lock expiry releases ----------------------------------------------------
_tavs_lock_write "true" "manual" "$(( $(date +%s) + 2 ))" "0" "" ""
sleep 3
if [[ "$(trigger_bytes)" -gt 0 ]]; then
    pass "lock releases at its end time (expiry always wins)"
else
    fail "lock did not release at expiry"
fi

# ==============================================================================
log ""
log "Results: $PASSED passed, $FAILED failed (log: $LOG_FILE)"
[[ $FAILED -eq 0 ]]
