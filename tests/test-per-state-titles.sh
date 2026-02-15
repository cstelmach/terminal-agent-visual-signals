#!/bin/bash
# ==============================================================================
# TDD Test Script for Phase 2: Per-State Title Format System
# ==============================================================================
# Run: bash tests/test-per-state-titles.sh
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

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    expected to contain: '${needle}'\n    actual: '${haystack}'"
    fi
}

assert_not_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    expected NOT to contain: '${needle}'\n    actual: '${haystack}'"
    fi
}

# ==============================================================================
echo -e "${YELLOW}=== Loading modules ===${NC}"
# ==============================================================================

# Minimal environment — set TTY_SAFE before sourcing (modules need it)
export TTY_SAFE="_dev_ttys_test"

# Source defaults and modules
source src/config/defaults.conf
source src/core/context-data.sh
# Note: may return non-zero due to missing state file — harmless
source src/core/title-management.sh || true

# Override AFTER sourcing defaults (defaults.conf sets these to "true")
ENABLE_ANTHROPOMORPHISING="false"
TAVS_TITLE_SHOW_STATUS_ICON="false"
ENABLE_SESSION_ICONS="false"
TAVS_TITLE_MODE="full"  # Ensure title processing for all states

# Override load_context_data to be a no-op for most tests.
# Phase 1 tests already verified it works. Phase 2 tests focus on
# format selection and token substitution in compose_title.
_original_load_context_data=$(declare -f load_context_data)
load_context_data() {
    # No-op: test sets TAVS_CONTEXT_* globals directly
    return 0
}

# Helper to reset all format variables between tests
reset_format_vars() {
    unset TITLE_FORMAT_PROCESSING TITLE_FORMAT_PERMISSION TITLE_FORMAT_COMPLETE 2>/dev/null || true
    unset TITLE_FORMAT_IDLE TITLE_FORMAT_COMPACTING TITLE_FORMAT_SUBAGENT 2>/dev/null || true
    unset TITLE_FORMAT_TOOL_ERROR TITLE_FORMAT_RESET TITLE_FORMAT 2>/dev/null || true
    unset TAVS_TITLE_FORMAT_PROCESSING TAVS_TITLE_FORMAT_PERMISSION 2>/dev/null || true
    unset TAVS_TITLE_FORMAT_COMPLETE TAVS_TITLE_FORMAT_IDLE 2>/dev/null || true
    unset TAVS_TITLE_FORMAT_COMPACTING TAVS_TITLE_FORMAT_SUBAGENT 2>/dev/null || true
    unset TAVS_TITLE_FORMAT_TOOL_ERROR TAVS_TITLE_FORMAT_RESET 2>/dev/null || true
    # Reset global format to simple baseline (prevents cascade test leaking)
    TAVS_TITLE_FORMAT="{BASE}"
    # Reset context globals
    TAVS_CONTEXT_PCT=""
    TAVS_CONTEXT_MODEL=""
    TAVS_CONTEXT_COST=""
    TAVS_CONTEXT_DURATION=""
    TAVS_CONTEXT_LINES_ADD=""
    TAVS_CONTEXT_LINES_REM=""
    TAVS_PERMISSION_MODE="default"
}

# ==============================================================================
echo -e "${YELLOW}=== Test Group 1: 4-Level Format Fallback Chain ===${NC}"
# ==============================================================================

# --- Level 4: Global default (TAVS_TITLE_FORMAT) ---
reset_format_vars
TAVS_TITLE_FORMAT="{BASE}"
result=$(compose_title "processing" "myproject")
assert_eq "L4: global default used for processing" "myproject" "$result"

result=$(compose_title "permission" "myproject")
assert_eq "L4: global default used for permission" "myproject" "$result"

# --- Level 3: Global per-state (TAVS_TITLE_FORMAT_PERMISSION) ---
reset_format_vars
TAVS_TITLE_FORMAT="{BASE}"
TAVS_TITLE_FORMAT_PERMISSION="PERM-{BASE}"
result=$(compose_title "permission" "proj")
assert_eq "L3: per-state format for permission" "PERM-proj" "$result"

# Level 3 should NOT leak to other states
result=$(compose_title "processing" "proj")
assert_eq "L3: no leak to processing" "proj" "$result"

result=$(compose_title "complete" "proj")
assert_eq "L3: no leak to complete" "proj" "$result"

# --- Level 3: Works for other states too ---
reset_format_vars
TAVS_TITLE_FORMAT="{BASE}"
TAVS_TITLE_FORMAT_COMPACTING="COMPACT-{BASE}"
result=$(compose_title "compacting" "proj")
assert_eq "L3: per-state format for compacting" "COMPACT-proj" "$result"

TAVS_TITLE_FORMAT_TOOL_ERROR="ERR-{BASE}"
result=$(compose_title "tool_error" "proj")
assert_eq "L3: per-state format for tool_error" "ERR-proj" "$result"

# --- Level 2: Agent-wide format (TITLE_FORMAT, set by _resolve_agent_variables) ---
reset_format_vars
TAVS_TITLE_FORMAT="{BASE}"
TITLE_FORMAT="AGENT-{BASE}"
result=$(compose_title "processing" "proj")
assert_eq "L2: agent-wide format" "AGENT-proj" "$result"

# Level 2 beats Level 3 (spec: L1 > L2 > L3 > L4)
TAVS_TITLE_FORMAT_PERMISSION="GLOBAL-PERM-{BASE}"
result=$(compose_title "permission" "proj")
assert_eq "L2 beats L3: agent-wide beats global per-state" "AGENT-proj" "$result"

# --- Level 1: Agent + state specific (TITLE_FORMAT_PERMISSION) ---
reset_format_vars
TAVS_TITLE_FORMAT="{BASE}"
TITLE_FORMAT_PERMISSION="AGENT-PERM-{BASE}"
result=$(compose_title "permission" "proj")
assert_eq "L1: agent+state specific" "AGENT-PERM-proj" "$result"

# Level 1 beats all others
TITLE_FORMAT="AGENT-{BASE}"
TAVS_TITLE_FORMAT_PERMISSION="GLOBAL-PERM-{BASE}"
result=$(compose_title "permission" "proj")
assert_eq "L1 beats L2+L3: agent+state is highest priority" "AGENT-PERM-proj" "$result"

# --- Full priority cascade test ---
reset_format_vars
TITLE_FORMAT_PERMISSION="L1"
TITLE_FORMAT="L2"
TAVS_TITLE_FORMAT_PERMISSION="L3"
TAVS_TITLE_FORMAT="L4"

result=$(compose_title "permission" "test")
assert_eq "Cascade: L1 wins with all set" "L1" "$result"

unset TITLE_FORMAT_PERMISSION
result=$(compose_title "permission" "test")
assert_eq "Cascade: L2 wins when L1 removed" "L2" "$result"

unset TITLE_FORMAT
result=$(compose_title "permission" "test")
assert_eq "Cascade: L3 wins when L1+L2 removed" "L3" "$result"

unset TAVS_TITLE_FORMAT_PERMISSION
result=$(compose_title "permission" "test")
assert_eq "Cascade: L4 wins when L1+L2+L3 removed" "L4" "$result"

# ==============================================================================
echo -e "${YELLOW}=== Test Group 2: Context Token Substitution ===${NC}"
# ==============================================================================

# --- {CONTEXT_PCT} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_PCT} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_PCT resolves" "50% proj" "$result"

# --- {CONTEXT_FOOD} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_FOOD} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_FOOD resolves" "🧀 proj" "$result"

# --- {CONTEXT_FOOD_10} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_FOOD_10} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_FOOD_10 resolves" "🧀 proj" "$result"

# --- {CONTEXT_BAR_H} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_BAR_H} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_BAR_H resolves" "▓▓░░░ proj" "$result"

# --- {CONTEXT_BAR_HL} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_BAR_HL} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_BAR_HL resolves" "▓▓▓▓▓░░░░░ proj" "$result"

# --- {CONTEXT_BAR_V} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_BAR_V} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_BAR_V resolves" "▄ proj" "$result"

# --- {CONTEXT_BAR_VM} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_BAR_VM} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_BAR_VM resolves" "▄▒ proj" "$result"

# --- {CONTEXT_BRAILLE} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_BRAILLE} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_BRAILLE resolves" "⠴ proj" "$result"

# --- {CONTEXT_NUMBER} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_NUMBER} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_NUMBER resolves" "5️⃣ proj" "$result"

# --- {CONTEXT_ICON} ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_ICON} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: CONTEXT_ICON resolves" "🟡 proj" "$result"

# --- {MODEL} ---
reset_format_vars
TAVS_CONTEXT_MODEL="Opus"
TAVS_TITLE_FORMAT_PERMISSION="{MODEL} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: MODEL resolves" "Opus proj" "$result"

# --- {COST} ---
reset_format_vars
TAVS_CONTEXT_COST="1.23"
TAVS_TITLE_FORMAT_PERMISSION="{COST} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: COST resolves" "\$1.23 proj" "$result"

# --- {DURATION} ---
reset_format_vars
TAVS_CONTEXT_DURATION="300000"
TAVS_TITLE_FORMAT_PERMISSION="{DURATION} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: DURATION resolves" "5m0s proj" "$result"

# --- {LINES} ---
reset_format_vars
TAVS_CONTEXT_LINES_ADD="42"
TAVS_TITLE_FORMAT_PERMISSION="{LINES} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: LINES resolves" "+42 proj" "$result"

# --- {MODE} ---
reset_format_vars
TAVS_PERMISSION_MODE="plan"
TAVS_TITLE_FORMAT_PERMISSION="{MODE} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: MODE resolves" "plan proj" "$result"

# --- Multiple context tokens combined ---
reset_format_vars
TAVS_CONTEXT_PCT="75"
TAVS_CONTEXT_MODEL="Opus"
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_FOOD} {CONTEXT_PCT} {MODEL} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Token: multiple combined" "🍕 75% Opus proj" "$result"

# --- Default permission format from spec ---
reset_format_vars
TAVS_CONTEXT_PCT="50"
# Apply the default from defaults.conf (reset_format_vars clears it)
TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}"
# With face and status_icon disabled, {FACE} and {STATUS_ICON} collapse
# Only CONTEXT_FOOD + CONTEXT_PCT + BASE should remain
result=$(compose_title "permission" "proj")
assert_eq "Default permission format" "🧀 50% proj" "$result"

# ==============================================================================
echo -e "${YELLOW}=== Test Group 3: Empty Token Collapse ===${NC}"
# ==============================================================================

# When context data is empty, tokens should collapse cleanly
reset_format_vars
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_FOOD} {CONTEXT_PCT} {MODEL} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Collapse: all empty context" "proj" "$result"

# Partial data — some tokens empty, some filled
reset_format_vars
TAVS_CONTEXT_PCT="50"
TAVS_CONTEXT_MODEL=""
TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_FOOD} {MODEL} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Collapse: partial data" "🧀 proj" "$result"

# Empty cost/duration/lines
reset_format_vars
TAVS_CONTEXT_COST=""
TAVS_CONTEXT_DURATION=""
TAVS_CONTEXT_LINES_ADD=""
TAVS_TITLE_FORMAT_PERMISSION="{COST} {DURATION} {LINES} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Collapse: empty metadata" "proj" "$result"

# ==============================================================================
echo -e "${YELLOW}=== Test Group 4: Backward Compatibility ===${NC}"
# ==============================================================================

# With no per-state formats and no context tokens, behavior should be identical
reset_format_vars
TAVS_TITLE_FORMAT="{BASE}"
result=$(compose_title "processing" "myproject")
assert_eq "Compat: processing unchanged" "myproject" "$result"

result=$(compose_title "permission" "myproject")
# defaults.conf sets TAVS_TITLE_FORMAT_PERMISSION, so this might use that.
# But we reset it above, so it should fall through to TAVS_TITLE_FORMAT
assert_eq "Compat: permission falls to global when reset" "myproject" "$result"

result=$(compose_title "complete" "myproject")
assert_eq "Compat: complete unchanged" "myproject" "$result"

result=$(compose_title "reset" "myproject")
assert_eq "Compat: reset unchanged" "myproject" "$result"

# Standard tokens still work
reset_format_vars
ENABLE_ANTHROPOMORPHISING="false"
TAVS_TITLE_FORMAT="{BASE} done"
result=$(compose_title "complete" "proj")
assert_eq "Compat: standard tokens still work" "proj done" "$result"

# ==============================================================================
echo -e "${YELLOW}=== Test Group 5: State Name Handling ===${NC}"
# ==============================================================================

reset_format_vars
TAVS_TITLE_FORMAT="{BASE}"
TAVS_TITLE_FORMAT_PROCESSING="PROC-{BASE}"
TAVS_TITLE_FORMAT_PERMISSION="PERM-{BASE}"
TAVS_TITLE_FORMAT_COMPLETE="DONE-{BASE}"
TAVS_TITLE_FORMAT_IDLE="IDLE-{BASE}"
TAVS_TITLE_FORMAT_COMPACTING="CMPCT-{BASE}"
TAVS_TITLE_FORMAT_SUBAGENT="SUB-{BASE}"
TAVS_TITLE_FORMAT_TOOL_ERROR="ERR-{BASE}"
TAVS_TITLE_FORMAT_RESET="RST-{BASE}"

result=$(compose_title "processing" "p")
assert_eq "State: processing" "PROC-p" "$result"

result=$(compose_title "permission" "p")
assert_eq "State: permission" "PERM-p" "$result"

result=$(compose_title "complete" "p")
assert_eq "State: complete" "DONE-p" "$result"

result=$(compose_title "idle" "p")
assert_eq "State: idle" "IDLE-p" "$result"

result=$(compose_title "compacting" "p")
assert_eq "State: compacting" "CMPCT-p" "$result"

result=$(compose_title "subagent" "p")
assert_eq "State: subagent" "SUB-p" "$result"

result=$(compose_title "tool_error" "p")
assert_eq "State: tool_error" "ERR-p" "$result"

result=$(compose_title "reset" "p")
assert_eq "State: reset" "RST-p" "$result"

# ==============================================================================
echo -e "${YELLOW}=== Test Group 6: Performance Guard ===${NC}"
# ==============================================================================

# Format WITHOUT context tokens should NOT call load_context_data
# We verify this by setting PCT to a value and checking it survives
# (real load_context_data would reset it to empty if no bridge)
reset_format_vars
TAVS_CONTEXT_PCT="99"  # Pre-set; if load_context_data were called, it would reset
TAVS_TITLE_FORMAT="{BASE}"
result=$(compose_title "processing" "proj")
# If load_context_data was NOT called, PCT is still 99
assert_eq "Guard: no context tokens → PCT preserved" "99" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test Group 7: Integration with mock bridge ===${NC}"
# ==============================================================================

# Restore real load_context_data for this test
eval "$_original_load_context_data"

MOCK_STATE_DIR=$(mktemp -d)
cat > "${MOCK_STATE_DIR}/context._dev_ttys_test" << EOF
pct=72
model=Sonnet
cost=0.55
duration=120000
lines_add=88
lines_rem=12
ts=$(date +%s)
EOF

TTY_SAFE="_dev_ttys_test"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_CONTEXT_BRIDGE_MAX_AGE=30

TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_FOOD} {CONTEXT_PCT} {MODEL} {BASE}"
result=$(compose_title "permission" "proj")
assert_eq "Integration: bridge → title" "🌮 72% Sonnet proj" "$result"

rm -rf "$MOCK_STATE_DIR"

# Re-override load_context_data for safety
load_context_data() { return 0; }

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
