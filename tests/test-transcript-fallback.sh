#!/bin/bash
# ==============================================================================
# TDD Test Script for Phase 4: Transcript Fallback
# ==============================================================================
# Tests _estimate_from_transcript() and the load_context_data fallback chain.
# Run: bash tests/test-transcript-fallback.sh
# Must be run from worktree root: /Users/cs/.claude/hooks/tavs-dynamic-titles
# ==============================================================================
set -euo pipefail

PASS=0
FAIL=0
ERRORS=""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    expected: '${expected}'\n    actual:   '${actual}'"
    fi
}

assert_empty() {
    local test_name="$1"
    local actual="$2"
    if [[ -z "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    expected empty, got: '${actual}'"
    fi
}

assert_exit_0() {
    local test_name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    command exited non-zero"
    fi
}

assert_exit_nonzero() {
    local test_name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    expected non-zero exit, got 0"
    else
        PASS=$((PASS + 1))
    fi
}

# ==============================================================================
echo -e "${YELLOW}=== Loading modules ===${NC}"
# ==============================================================================

source src/config/defaults.conf
source src/core/context-data.sh

# Create temp directory for test files
TEST_TMP=$(mktemp -d)
trap "rm -rf $TEST_TMP" EXIT

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — correct percentage ===${NC}"
# ==============================================================================

# 350000 bytes → 350000/3.5 = 100000 tokens → 100000/200000*100 = 50%
dd if=/dev/zero bs=1 count=350000 of="$TEST_TMP/transcript_50pct.jsonl" 2>/dev/null
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=200000
_estimate_from_transcript "$TEST_TMP/transcript_50pct.jsonl"
assert_eq "350000 bytes → 50%" "50" "$TAVS_CONTEXT_PCT"

# 700000 bytes → 700000/3.5 = 200000 tokens → 200000/200000*100 = 100%
dd if=/dev/zero bs=1 count=700000 of="$TEST_TMP/transcript_100pct.jsonl" 2>/dev/null
TAVS_CONTEXT_PCT=""
_estimate_from_transcript "$TEST_TMP/transcript_100pct.jsonl"
assert_eq "700000 bytes → 100%" "100" "$TAVS_CONTEXT_PCT"

# 35000 bytes → 35000/3.5 = 10000 tokens → 10000/200000*100 = 5%
dd if=/dev/zero bs=1 count=35000 of="$TEST_TMP/transcript_5pct.jsonl" 2>/dev/null
TAVS_CONTEXT_PCT=""
_estimate_from_transcript "$TEST_TMP/transcript_5pct.jsonl"
assert_eq "35000 bytes → 5%" "5" "$TAVS_CONTEXT_PCT"

# 35 bytes → 35/3.5 = 10 tokens → 10/200000*100 = 0%
dd if=/dev/zero bs=1 count=35 of="$TEST_TMP/transcript_tiny.jsonl" 2>/dev/null
TAVS_CONTEXT_PCT=""
_estimate_from_transcript "$TEST_TMP/transcript_tiny.jsonl"
assert_eq "35 bytes → 0% (tiny file)" "0" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — clamping at 100% ===${NC}"
# ==============================================================================

# 1400000 bytes → 1400000/3.5 = 400000 tokens → 400000/200000*100 = 200% → clamps to 100
dd if=/dev/zero bs=1 count=1400000 of="$TEST_TMP/transcript_overflow.jsonl" 2>/dev/null
TAVS_CONTEXT_PCT=""
_estimate_from_transcript "$TEST_TMP/transcript_overflow.jsonl"
assert_eq "1400000 bytes → clamped to 100%" "100" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — custom context window ===${NC}"
# ==============================================================================

# 350000 bytes with 1000000 context window (extended context)
# 350000/3.5 = 100000 tokens → 100000/1000000*100 = 10%
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=1000000
_estimate_from_transcript "$TEST_TMP/transcript_50pct.jsonl"
assert_eq "350000 bytes with 1M context → 10%" "10" "$TAVS_CONTEXT_PCT"

# Restore default
TAVS_CONTEXT_WINDOW_SIZE=200000

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — missing file ===${NC}"
# ==============================================================================

TAVS_CONTEXT_PCT=""
_estimate_from_transcript "/nonexistent/path/transcript.jsonl" && exit_code=0 || exit_code=$?
assert_eq "missing file returns 1" "1" "$exit_code"
assert_empty "missing file leaves PCT empty" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — empty file ===${NC}"
# ==============================================================================

touch "$TEST_TMP/empty_transcript.jsonl"
TAVS_CONTEXT_PCT=""
_estimate_from_transcript "$TEST_TMP/empty_transcript.jsonl" && exit_code=0 || exit_code=$?
assert_eq "empty file returns 1" "1" "$exit_code"
assert_empty "empty file leaves PCT empty" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — empty path ===${NC}"
# ==============================================================================

TAVS_CONTEXT_PCT=""
_estimate_from_transcript "" && exit_code=0 || exit_code=$?
assert_eq "empty path returns 1" "1" "$exit_code"
assert_empty "empty path leaves PCT empty" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — TAVS_TRANSCRIPT_PATH env ===${NC}"
# ==============================================================================

# When called without argument, should use TAVS_TRANSCRIPT_PATH
TAVS_CONTEXT_PCT=""
TAVS_TRANSCRIPT_PATH="$TEST_TMP/transcript_50pct.jsonl"
TAVS_CONTEXT_WINDOW_SIZE=200000
_estimate_from_transcript
assert_eq "uses TAVS_TRANSCRIPT_PATH env" "50" "$TAVS_CONTEXT_PCT"
unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — only sets PCT ===${NC}"
# ==============================================================================

# Transcript fallback should only set PCT, not model/cost/duration
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL="should_stay"
TAVS_CONTEXT_COST="should_stay"
TAVS_CONTEXT_DURATION="should_stay"
TAVS_CONTEXT_LINES_ADD="should_stay"
TAVS_CONTEXT_LINES_REM="should_stay"
_estimate_from_transcript "$TEST_TMP/transcript_50pct.jsonl"
assert_eq "PCT set by transcript" "50" "$TAVS_CONTEXT_PCT"
assert_eq "MODEL untouched by transcript" "should_stay" "$TAVS_CONTEXT_MODEL"
assert_eq "COST untouched by transcript" "should_stay" "$TAVS_CONTEXT_COST"
assert_eq "DURATION untouched by transcript" "should_stay" "$TAVS_CONTEXT_DURATION"
assert_eq "LINES_ADD untouched by transcript" "should_stay" "$TAVS_CONTEXT_LINES_ADD"
assert_eq "LINES_REM untouched by transcript" "should_stay" "$TAVS_CONTEXT_LINES_REM"

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data — fallback to transcript ===${NC}"
# ==============================================================================

# No bridge data (point to empty state dir), but transcript exists
MOCK_STATE_DIR=$(mktemp -d)
TTY_SAFE="_dev_ttys999"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_TRANSCRIPT_PATH="$TEST_TMP/transcript_50pct.jsonl"
TAVS_CONTEXT_WINDOW_SIZE=200000

load_context_data
assert_eq "fallback: pct from transcript" "50" "$TAVS_CONTEXT_PCT"
# Transcript doesn't provide model/cost — these should be empty (reset by load_context_data)
assert_empty "fallback: model empty" "$TAVS_CONTEXT_MODEL"
assert_empty "fallback: cost empty" "$TAVS_CONTEXT_COST"
assert_empty "fallback: duration empty" "$TAVS_CONTEXT_DURATION"

rm -rf "$MOCK_STATE_DIR"
unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data — no bridge, no transcript ===${NC}"
# ==============================================================================

# Neither bridge nor transcript available — all should be empty
MOCK_STATE_DIR=$(mktemp -d)
TTY_SAFE="_dev_ttys999"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
unset TAVS_TRANSCRIPT_PATH 2>/dev/null || true

load_context_data && exit_code=0 || exit_code=$?
assert_eq "no data returns 1" "1" "$exit_code"
assert_empty "no data: pct empty" "$TAVS_CONTEXT_PCT"
assert_empty "no data: model empty" "$TAVS_CONTEXT_MODEL"
assert_empty "no data: cost empty" "$TAVS_CONTEXT_COST"

rm -rf "$MOCK_STATE_DIR"

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data — bridge preferred over transcript ===${NC}"
# ==============================================================================

# When both bridge AND transcript exist, bridge should win
MOCK_STATE_DIR=$(mktemp -d)
MOCK_STATE_FILE="${MOCK_STATE_DIR}/context._dev_ttys001"
cat > "$MOCK_STATE_FILE" << EOF
pct=72
model=Opus
cost=1.23
duration=300000
lines_add=156
lines_rem=23
ts=$(date +%s)
EOF

TTY_SAFE="_dev_ttys001"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_TRANSCRIPT_PATH="$TEST_TMP/transcript_50pct.jsonl"
TAVS_CONTEXT_BRIDGE_MAX_AGE=30

load_context_data
assert_eq "bridge wins: pct=72 not 50" "72" "$TAVS_CONTEXT_PCT"
assert_eq "bridge wins: model=Opus" "Opus" "$TAVS_CONTEXT_MODEL"

rm -rf "$MOCK_STATE_DIR"
unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data — stale bridge falls to transcript ===${NC}"
# ==============================================================================

# Stale bridge should be skipped, transcript should be used as fallback
MOCK_STATE_DIR=$(mktemp -d)
MOCK_STATE_FILE="${MOCK_STATE_DIR}/context._dev_ttys001"
cat > "$MOCK_STATE_FILE" << 'EOF'
pct=72
model=Opus
ts=1000000000
EOF

TTY_SAFE="_dev_ttys001"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_TRANSCRIPT_PATH="$TEST_TMP/transcript_50pct.jsonl"
TAVS_CONTEXT_BRIDGE_MAX_AGE=30
TAVS_CONTEXT_WINDOW_SIZE=200000

load_context_data
assert_eq "stale bridge → transcript: pct=50" "50" "$TAVS_CONTEXT_PCT"
# Model should be empty (transcript doesn't provide it, and load_context_data resets globals)
assert_empty "stale bridge → transcript: model empty" "$TAVS_CONTEXT_MODEL"

rm -rf "$MOCK_STATE_DIR"
unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
# RESULTS
# ==============================================================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "  Tests: $((PASS + FAIL)) | ${GREEN}Pass: ${PASS}${NC} | ${RED}Fail: ${FAIL}${NC}"
echo -e "${YELLOW}========================================${NC}"

if [[ $FAIL -gt 0 ]]; then
    echo -e "\nFailures:${ERRORS}"
    echo ""
    exit 1
else
    echo -e "\n  ${GREEN}All tests passed!${NC}\n"
    exit 0
fi
