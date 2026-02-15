#!/bin/bash
# ==============================================================================
# TDD Test Script for context-data.sh
# ==============================================================================
# Run: bash tests/test-context-data.sh
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

# Source defaults first (provides arrays), then context-data
source src/config/defaults.conf
source src/core/context-data.sh

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_FOOD (21-stage, 5% steps) ===${NC}"
# ==============================================================================

# Every 5% step must match the spec exactly
EXPECTED_FOOD=(
    "💧"    # 0%
    "🥬"    # 5%
    "🥦"    # 10%
    "🥒"    # 15%
    "🥗"    # 20%
    "🥝"    # 25%
    "🥑"    # 30%
    "🍋"    # 35%
    "🍌"    # 40%
    "🌽"    # 45%
    "🧀"    # 50%
    "🥨"    # 55%
    "🍞"    # 60%
    "🥪"    # 65%
    "🌮"    # 70%
    "🍕"    # 75%
    "🌭"    # 80%
    "🍔"    # 85%
    "🍟"    # 90%
    "🍩"    # 95%
    "🍫"    # 100%
)
for i in $(seq 0 20); do
    pct=$((i * 5))
    result=$(resolve_context_token CONTEXT_FOOD "$pct")
    assert_eq "FOOD at ${pct}%" "${EXPECTED_FOOD[$i]}" "$result"
done

# Non-boundary values should floor to nearest 5% step
assert_eq "FOOD at 3% (floors to 0)" "💧" "$(resolve_context_token CONTEXT_FOOD 3)"
assert_eq "FOOD at 7% (floors to 5)" "🥬" "$(resolve_context_token CONTEXT_FOOD 7)"
assert_eq "FOOD at 49% (floors to 45)" "🌽" "$(resolve_context_token CONTEXT_FOOD 49)"
assert_eq "FOOD at 99% (floors to 95)" "🍩" "$(resolve_context_token CONTEXT_FOOD 99)"

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_FOOD_10 (11-stage, 10% steps) ===${NC}"
# ==============================================================================

EXPECTED_FOOD10=(
    "💧"    # 0%
    "🥬"    # 10%
    "🥦"    # 20%
    "🥑"    # 30%
    "🍌"    # 40%
    "🧀"    # 50%
    "🍞"    # 60%
    "🌮"    # 70%
    "🍔"    # 80%
    "🍟"    # 90%
    "🍫"    # 100%
)
for i in $(seq 0 10); do
    pct=$((i * 10))
    result=$(resolve_context_token CONTEXT_FOOD_10 "$pct")
    assert_eq "FOOD_10 at ${pct}%" "${EXPECTED_FOOD10[$i]}" "$result"
done

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_ICON (11-stage color circles) ===${NC}"
# ==============================================================================

EXPECTED_ICON=(
    "⚪"    # 0%
    "🔵"    # 10%
    "🔵"    # 20%
    "🟢"    # 30%
    "🟢"    # 40%
    "🟡"    # 50%
    "🟠"    # 60%
    "🟠"    # 70%
    "🔴"    # 80%
    "🔴"    # 90%
    "⚫"    # 100%
)
for i in $(seq 0 10); do
    pct=$((i * 10))
    result=$(resolve_context_token CONTEXT_ICON "$pct")
    assert_eq "ICON at ${pct}%" "${EXPECTED_ICON[$i]}" "$result"
done

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_NUMBER (11-stage number emoji) ===${NC}"
# ==============================================================================

EXPECTED_NUM=("0️⃣" "1️⃣" "2️⃣" "3️⃣" "4️⃣" "5️⃣" "6️⃣" "7️⃣" "8️⃣" "9️⃣" "🔟")
for i in $(seq 0 10); do
    pct=$((i * 10))
    result=$(resolve_context_token CONTEXT_NUMBER "$pct")
    assert_eq "NUMBER at ${pct}%" "${EXPECTED_NUM[$i]}" "$result"
done

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_PCT (percentage string) ===${NC}"
# ==============================================================================

assert_eq "PCT at 0%" "0%" "$(resolve_context_token CONTEXT_PCT 0)"
assert_eq "PCT at 50%" "50%" "$(resolve_context_token CONTEXT_PCT 50)"
assert_eq "PCT at 100%" "100%" "$(resolve_context_token CONTEXT_PCT 100)"
assert_eq "PCT at 85%" "85%" "$(resolve_context_token CONTEXT_PCT 85)"

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_BAR_H (5-char horizontal bar) ===${NC}"
# ==============================================================================

assert_eq "BAR_H at 0%" "░░░░░" "$(resolve_context_token CONTEXT_BAR_H 0)"
assert_eq "BAR_H at 20%" "▓░░░░" "$(resolve_context_token CONTEXT_BAR_H 20)"
assert_eq "BAR_H at 50%" "▓▓░░░" "$(resolve_context_token CONTEXT_BAR_H 50)"
assert_eq "BAR_H at 80%" "▓▓▓▓░" "$(resolve_context_token CONTEXT_BAR_H 80)"
assert_eq "BAR_H at 100%" "▓▓▓▓▓" "$(resolve_context_token CONTEXT_BAR_H 100)"

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_BAR_HL (10-char horizontal bar) ===${NC}"
# ==============================================================================

assert_eq "BAR_HL at 0%" "░░░░░░░░░░" "$(resolve_context_token CONTEXT_BAR_HL 0)"
assert_eq "BAR_HL at 50%" "▓▓▓▓▓░░░░░" "$(resolve_context_token CONTEXT_BAR_HL 50)"
assert_eq "BAR_HL at 100%" "▓▓▓▓▓▓▓▓▓▓" "$(resolve_context_token CONTEXT_BAR_HL 100)"

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_BAR_V (vertical block) ===${NC}"
# ==============================================================================

# Formula: index = pct * 7 / 100, array = ▁▂▃▄▅▆▇█
assert_eq "BAR_V at 0%" "▁" "$(resolve_context_token CONTEXT_BAR_V 0)"
assert_eq "BAR_V at 50%" "▄" "$(resolve_context_token CONTEXT_BAR_V 50)"
assert_eq "BAR_V at 100%" "█" "$(resolve_context_token CONTEXT_BAR_V 100)"

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_BAR_VM (vertical + max outline) ===${NC}"
# ==============================================================================

assert_eq "BAR_VM at 0%" "▁▒" "$(resolve_context_token CONTEXT_BAR_VM 0)"
assert_eq "BAR_VM at 50%" "▄▒" "$(resolve_context_token CONTEXT_BAR_VM 50)"
assert_eq "BAR_VM at 100%" "█▒" "$(resolve_context_token CONTEXT_BAR_VM 100)"

# ==============================================================================
echo -e "${YELLOW}=== Test: CONTEXT_BRAILLE ===${NC}"
# ==============================================================================

# Formula: index = pct * 6 / 100, array = ⠀⠄⠤⠴⠶⠷⠿
assert_eq "BRAILLE at 0%" "⠀" "$(resolve_context_token CONTEXT_BRAILLE 0)"
assert_eq "BRAILLE at 50%" "⠴" "$(resolve_context_token CONTEXT_BRAILLE 50)"
assert_eq "BRAILLE at 100%" "⠿" "$(resolve_context_token CONTEXT_BRAILLE 100)"

# ==============================================================================
echo -e "${YELLOW}=== Test: Edge cases — empty/missing percentage ===${NC}"
# ==============================================================================

# Empty percentage should return empty string (not crash)
assert_empty "FOOD with empty pct" "$(resolve_context_token CONTEXT_FOOD "")"
assert_empty "PCT with empty pct" "$(resolve_context_token CONTEXT_PCT "")"
assert_empty "BAR_H with empty pct" "$(resolve_context_token CONTEXT_BAR_H "")"

# ==============================================================================
echo -e "${YELLOW}=== Test: Clamping — values beyond 0-100 ===${NC}"
# ==============================================================================

# Values > 100 should clamp to 100
assert_eq "FOOD at 150% clamps to 100" "🍫" "$(resolve_context_token CONTEXT_FOOD 150)"
assert_eq "BAR_H at 200% clamps to 100" "▓▓▓▓▓" "$(resolve_context_token CONTEXT_BAR_H 200)"
assert_eq "PCT at 150% clamps to 100" "100%" "$(resolve_context_token CONTEXT_PCT 150)"

# ==============================================================================
echo -e "${YELLOW}=== Test: Format helpers ===${NC}"
# ==============================================================================

assert_eq "format_cost normal" "\$1.23" "$(_format_cost "1.23")"
assert_eq "format_cost zero" "\$0.00" "$(_format_cost "0")"
assert_eq "format_cost empty" "" "$(_format_cost "")"

assert_eq "format_duration 5min" "5m0s" "$(_format_duration "300000")"
assert_eq "format_duration 1h5m" "65m0s" "$(_format_duration "3900000")"
assert_eq "format_duration 0s" "0m0s" "$(_format_duration "0")"
assert_eq "format_duration empty" "" "$(_format_duration "")"

assert_eq "format_lines positive" "+156" "$(_format_lines "156")"
assert_eq "format_lines zero" "+0" "$(_format_lines "0")"
assert_eq "format_lines empty" "" "$(_format_lines "")"

# ==============================================================================
echo -e "${YELLOW}=== Test: read_bridge_state with mock state file ===${NC}"
# ==============================================================================

# Create a mock state file
MOCK_STATE_DIR=$(mktemp -d)
MOCK_STATE_FILE="${MOCK_STATE_DIR}/context._dev_ttys001"
cat > "$MOCK_STATE_FILE" << 'EOF'
# TAVS Context Bridge - 2026-02-15T10:45:23+00:00
pct=72
model=Opus
cost=1.23
duration=300000
lines_add=156
lines_rem=23
ts=9999999999
EOF

# Override TTY_SAFE and state dir for testing
TTY_SAFE="_dev_ttys001"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_CONTEXT_BRIDGE_MAX_AGE=30

# Test: read_bridge_state should populate TAVS_CONTEXT_* globals
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_CONTEXT_COST=""
read_bridge_state
assert_eq "bridge pct" "72" "$TAVS_CONTEXT_PCT"
assert_eq "bridge model" "Opus" "$TAVS_CONTEXT_MODEL"
assert_eq "bridge cost" "1.23" "$TAVS_CONTEXT_COST"
assert_eq "bridge duration" "300000" "$TAVS_CONTEXT_DURATION"
assert_eq "bridge lines_add" "156" "$TAVS_CONTEXT_LINES_ADD"
assert_eq "bridge lines_rem" "23" "$TAVS_CONTEXT_LINES_REM"

# Cleanup
rm -rf "$MOCK_STATE_DIR"

# ==============================================================================
echo -e "${YELLOW}=== Test: read_bridge_state with stale data ===${NC}"
# ==============================================================================

MOCK_STATE_DIR=$(mktemp -d)
MOCK_STATE_FILE="${MOCK_STATE_DIR}/context._dev_ttys001"
cat > "$MOCK_STATE_FILE" << 'EOF'
pct=50
model=Sonnet
ts=1000000000
EOF

TTY_SAFE="_dev_ttys001"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_CONTEXT_BRIDGE_MAX_AGE=30

# Stale data (ts far in the past) should be rejected
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
read_bridge_state && exit_code=0 || exit_code=$?

# After stale rejection, vars should remain empty
assert_eq "stale bridge rejected (exit non-zero)" "1" "$exit_code"
assert_empty "stale bridge pct empty" "$TAVS_CONTEXT_PCT"

rm -rf "$MOCK_STATE_DIR"

# ==============================================================================
echo -e "${YELLOW}=== Test: read_bridge_state with missing file ===${NC}"
# ==============================================================================

MOCK_STATE_DIR=$(mktemp -d)
TTY_SAFE="_dev_ttys999"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"

TAVS_CONTEXT_PCT=""
read_bridge_state && exit_code=0 || exit_code=$?
assert_eq "missing file rejected" "1" "$exit_code"
assert_empty "missing file pct empty" "$TAVS_CONTEXT_PCT"

rm -rf "$MOCK_STATE_DIR"

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data integration ===${NC}"
# ==============================================================================

# With fresh bridge data, load_context_data should succeed
MOCK_STATE_DIR=$(mktemp -d)
MOCK_STATE_FILE="${MOCK_STATE_DIR}/context._dev_ttys001"
cat > "$MOCK_STATE_FILE" << EOF
pct=45
model=Opus
cost=0.42
duration=300000
lines_add=42
lines_rem=7
ts=$(date +%s)
EOF

TTY_SAFE="_dev_ttys001"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_CONTEXT_BRIDGE_MAX_AGE=30
TAVS_CONTEXT_PCT=""

load_context_data
assert_eq "load_context pct" "45" "$TAVS_CONTEXT_PCT"
assert_eq "load_context model" "Opus" "$TAVS_CONTEXT_MODEL"

rm -rf "$MOCK_STATE_DIR"

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
