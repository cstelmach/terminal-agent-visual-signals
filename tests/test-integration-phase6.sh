#!/bin/bash
# ==============================================================================
# Phase 6 Integration Test — End-to-End Pipeline Verification
# ==============================================================================
# Verifies the DEPLOYED system works end-to-end:
#   1. All modules load together without errors
#   2. Bridge → state file → compose_title pipeline works
#   3. Graceful degradation when no data available
#   4. All new files have valid syntax
#   5. All 8 trigger states produce valid titles
#
# NOTE: 4-level fallback chain, individual token resolvers, and edge cases
# are covered by unit tests (235 tests in Phases 1-4). This test focuses on
# integration: do the pieces work together as a system?
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0
fail=0
assert() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        ((pass++))
    else
        ((fail++))
        echo "  FAIL: $label"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
    fi
}
assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        ((pass++))
    else
        ((fail++))
        echo "  FAIL: $label"
        echo "    expected to contain: '$needle'"
        echo "    actual:              '$haystack'"
    fi
}
assert_not_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        ((pass++))
    else
        ((fail++))
        echo "  FAIL: $label"
        echo "    expected NOT to contain: '$needle'"
        echo "    actual:                  '$haystack'"
    fi
}

# ==============================================================================
echo -e "\033[0;33m=== Test Group 1: All modules load without error ===\033[0m"
# ==============================================================================
export TAVS_AGENT="claude"
export TAVS_PERMISSION_MODE="default"

CORE_DIR="$REPO_DIR/src/core"
source "$CORE_DIR/theme-config-loader.sh"
source "$CORE_DIR/session-state.sh"
source "$CORE_DIR/terminal-osc-sequences.sh"
source "$CORE_DIR/spinner.sh"
source "$CORE_DIR/palette-mode-helpers.sh"
source "$CORE_DIR/terminal-detection.sh"
source "$CORE_DIR/backgrounds.sh"
source "$CORE_DIR/title-management.sh"
source "$CORE_DIR/subagent-counter.sh"
source "$CORE_DIR/session-icon.sh"
source "$CORE_DIR/context-data.sh"

# Verify key functions exist after loading
assert "function: compose_title exists" "true" "$(type compose_title &>/dev/null && echo true || echo false)"
assert "function: load_context_data exists" "true" "$(type load_context_data &>/dev/null && echo true || echo false)"
assert "function: read_bridge_state exists" "true" "$(type read_bridge_state &>/dev/null && echo true || echo false)"
assert "function: resolve_context_token exists" "true" "$(type resolve_context_token &>/dev/null && echo true || echo false)"
assert "function: _estimate_from_transcript exists" "true" "$(type _estimate_from_transcript &>/dev/null && echo true || echo false)"
assert "function: _resolve_agent_variables exists" "true" "$(type _resolve_agent_variables &>/dev/null && echo true || echo false)"

# Verify icon arrays are loaded
assert "array: TAVS_CONTEXT_FOOD_21 has 21 entries" "21" "${#TAVS_CONTEXT_FOOD_21[@]}"
assert "array: TAVS_CONTEXT_FOOD_11 has 11 entries" "11" "${#TAVS_CONTEXT_FOOD_11[@]}"
assert "array: TAVS_CONTEXT_CIRCLES_11 has 11 entries" "11" "${#TAVS_CONTEXT_CIRCLES_11[@]}"
assert "array: TAVS_CONTEXT_NUMBERS has 11 entries" "11" "${#TAVS_CONTEXT_NUMBERS[@]}"
assert "array: TAVS_CONTEXT_BLOCKS has 8 entries" "8" "${#TAVS_CONTEXT_BLOCKS[@]}"
assert "array: TAVS_CONTEXT_BRAILLE has 7 entries" "7" "${#TAVS_CONTEXT_BRAILLE[@]}"

# ==============================================================================
echo -e "\033[0;33m=== Test Group 2: All 8 trigger states produce titles ===\033[0m"
# ==============================================================================
# Apply test isolation AFTER module loading (user.conf overrides happen during load)
export TAVS_FACE_MODE="standard"
export _TAVS_CONTEXT_STATE_DIR="$TEST_DIR"
export TTY_SAFE="_test_integration"

for state in processing permission complete idle compacting subagent tool_error reset; do
    result=$(compose_title "$state" 2>/dev/null) || true
    assert "state '$state' produces output" "true" "$([[ -n "$result" ]] && echo true || echo false)"
    assert_not_contains "state '$state' no unresolved {FACE}" "{FACE}" "$result"
    assert_not_contains "state '$state' no unresolved {STATUS_ICON}" "{STATUS_ICON}" "$result"
    assert_not_contains "state '$state' no unresolved {BASE}" "{BASE}" "$result"
done

# ==============================================================================
echo -e "\033[0;33m=== Test Group 3: Bridge → state file → compose_title pipeline ===\033[0m"
# ==============================================================================
# This is the PRIMARY Phase 6 test: the full data flow works end-to-end.

# Step 1: Run the ACTUAL bridge script with realistic Claude Code JSON
BRIDGE="$REPO_DIR/src/agents/claude/statusline-bridge.sh"
export _TAVS_BRIDGE_STATE_DIR="$TEST_DIR"
export _TAVS_BRIDGE_TTY_SAFE="_test_pipeline"

MOCK_JSON='{"session_id":"abc123","transcript_path":"/tmp/transcript.jsonl","cwd":"/Users/cs/project","model":{"id":"claude-opus-4-6","display_name":"Opus"},"workspace":{"current_dir":"/Users/cs/project","project_dir":"/Users/cs/project"},"cost":{"total_cost_usd":1.85,"total_duration_ms":420000,"total_lines_added":256,"total_lines_removed":34},"context_window":{"total_input_tokens":90000,"total_output_tokens":12000,"context_window_size":200000,"used_percentage":45,"remaining_percentage":55},"exceeds_200k_tokens":false,"version":"2.1.39"}'

bridge_output=$(echo "$MOCK_JSON" | "$BRIDGE" 2>/dev/null)

# Bridge MUST be silent
assert "bridge: zero stdout" "" "$bridge_output"

# State file MUST exist
assert "bridge: state file exists" "true" "$([[ -f "$TEST_DIR/context._test_pipeline" ]] && echo true || echo false)"

# Step 2: Read bridge state via load_context_data (set TTY_SAFE to match)
export TTY_SAFE="_test_pipeline"
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_CONTEXT_COST=""
TAVS_CONTEXT_DURATION=""
TAVS_CONTEXT_LINES_ADD=""

load_context_data

assert "pipeline: pct=45" "45" "${TAVS_CONTEXT_PCT:-}"
assert "pipeline: model=Opus" "Opus" "${TAVS_CONTEXT_MODEL:-}"
assert "pipeline: cost=1.85" "1.85" "${TAVS_CONTEXT_COST:-}"
assert "pipeline: duration=420000" "420000" "${TAVS_CONTEXT_DURATION:-}"
assert "pipeline: lines_add=256" "256" "${TAVS_CONTEXT_LINES_ADD:-}"

# Step 3: compose_title PERMISSION with context tokens
# Use a simple format to avoid state-leak complexity from agent resolution
export TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_FOOD} {CONTEXT_PCT} {MODEL}"
result=$(compose_title "permission" 2>/dev/null) || true

# 45% food = index 9 = 🌽
assert_contains "pipeline title: food 🌽" "🌽" "$result"
assert_contains "pipeline title: pct 45%" "45%" "$result"
assert_contains "pipeline title: model Opus" "Opus" "$result"
assert_not_contains "pipeline title: no unresolved" "{CONTEXT_" "$result"

# Step 4: compose_title with ALL tokens at once
export TAVS_TITLE_FORMAT_PERMISSION="{CONTEXT_FOOD}|{CONTEXT_FOOD_10}|{CONTEXT_ICON}|{CONTEXT_NUMBER}|{CONTEXT_PCT}|{CONTEXT_BAR_H}|{CONTEXT_BAR_HL}|{CONTEXT_BAR_V}|{CONTEXT_BAR_VM}|{CONTEXT_BRAILLE}|{MODEL}|{COST}|{DURATION}|{LINES}|{MODE}"
export TAVS_PERMISSION_MODE="plan"
result=$(compose_title "permission" 2>/dev/null) || true

# 45% expected values
assert_contains "all tokens: FOOD 🌽" "🌽" "$result"
assert_contains "all tokens: FOOD_10 🍌" "🍌" "$result"
assert_contains "all tokens: ICON 🟢" "🟢" "$result"  # 45% → index 4 → 🟢 (not 🟡 which is index 5 = 50%)
assert_contains "all tokens: NUMBER 4️⃣" "4️⃣" "$result"
assert_contains "all tokens: PCT 45%" "45%" "$result"
assert_contains "all tokens: BAR_H ▓▓░░░" "▓▓░░░" "$result"
assert_contains "all tokens: BAR_HL" "▓▓▓▓░░░░░░" "$result"
assert_contains "all tokens: BAR_V ▄" "▄" "$result"
assert_contains "all tokens: BRAILLE ⠤" "⠤" "$result"
assert_contains "all tokens: MODEL Opus" "Opus" "$result"
assert_contains "all tokens: COST" '$1.85' "$result"
assert_contains "all tokens: LINES +256" "+256" "$result"
assert_contains "all tokens: MODE plan" "plan" "$result"
assert_not_contains "all tokens: no unresolved" "{CONTEXT_" "$result"
assert_not_contains "all tokens: no unresolved MODEL" "{MODEL}" "$result"

export TAVS_PERMISSION_MODE="default"

# ==============================================================================
echo -e "\033[0;33m=== Test Group 4: Per-state format override for compacting ===\033[0m"
# ==============================================================================
export TAVS_TITLE_FORMAT_COMPACTING="{FACE} {STATUS_ICON} {CONTEXT_PCT} {BASE}"
result=$(compose_title "compacting" 2>/dev/null) || true
assert_contains "compacting: has 45%" "45%" "$result"
assert_not_contains "compacting: no double spaces" "  " "$result"
assert_not_contains "compacting: no unresolved" "{CONTEXT_" "$result"

# ==============================================================================
echo -e "\033[0;33m=== Test Group 5: Graceful degradation — no data ===\033[0m"
# ==============================================================================
# Remove bridge state file AND transcript → all tokens collapse to empty
rm -f "$TEST_DIR/context._test_pipeline"
export TTY_SAFE="_test_no_data"
unset TAVS_TRANSCRIPT_PATH 2>/dev/null || true
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""

load_context_data
assert "no data: PCT empty" "" "${TAVS_CONTEXT_PCT:-}"
assert "no data: MODEL empty" "" "${TAVS_CONTEXT_MODEL:-}"

export TAVS_TITLE_FORMAT_PERMISSION="{FACE} {STATUS_ICON} {CONTEXT_FOOD} {CONTEXT_PCT} {BASE}"
result=$(compose_title "permission" 2>/dev/null) || true
assert_not_contains "no data: no double spaces" "  " "$result"
assert "no data: title non-empty" "true" "$([[ -n "$result" ]] && echo true || echo false)"
assert_not_contains "no data: no unresolved tokens" "{CONTEXT_" "$result"

# ==============================================================================
echo -e "\033[0;33m=== Test Group 6: Stale bridge → transcript fallback ===\033[0m"
# ==============================================================================
_old_ts=$(( $(date +%s) - 60 ))
export TTY_SAFE="_test_stale"
cat > "$TEST_DIR/context._test_stale" << EOF
pct=90
model=OldModel
ts=$_old_ts
EOF

# Use JSONL with actual token data (JSONL parsing preferred over file-size estimation)
cat > "$TEST_DIR/fake_transcript.jsonl" << 'JSONL_EOF'
{"type":"user","messageId":"msg1","snapshot":{"messageId":"msg1"}}
{"type":"assistant","messageId":"msg2","message":{"model":"claude-opus-4-6","usage":{"input_tokens":5,"cache_creation_input_tokens":10000,"cache_read_input_tokens":90000,"output_tokens":200}}}
JSONL_EOF
export TAVS_TRANSCRIPT_PATH="$TEST_DIR/fake_transcript.jsonl"
export TAVS_CONTEXT_BRIDGE_MAX_AGE=30
export TAVS_CONTEXT_WINDOW_SIZE=200000
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""

load_context_data

# 5 + 10000 + 90000 = 100005 → 100005/200000 = 50%
assert "stale bridge: pct=50 (from JSONL)" "50" "${TAVS_CONTEXT_PCT:-}"
# JSONL parsing also extracts model name
assert "stale bridge: model from JSONL" "claude-opus-4-6" "${TAVS_CONTEXT_MODEL:-}"

unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
echo -e "\033[0;33m=== Test Group 7: Syntax validation — all new/modified files ===\033[0m"
# ==============================================================================
syntax_check=$(bash -n "$REPO_DIR/src/core/trigger.sh" 2>&1)
assert "syntax: core/trigger.sh" "" "$syntax_check"

syntax_check=$(bash -n "$REPO_DIR/src/core/context-data.sh" 2>&1)
assert "syntax: context-data.sh" "" "$syntax_check"

syntax_check=$(bash -n "$REPO_DIR/src/core/title-management.sh" 2>&1)
assert "syntax: title-management.sh" "" "$syntax_check"

syntax_check=$(bash -n "$REPO_DIR/src/core/theme-config-loader.sh" 2>&1)
assert "syntax: theme-config-loader.sh" "" "$syntax_check"

syntax_check=$(bash -n "$REPO_DIR/src/agents/claude/trigger.sh" 2>&1)
assert "syntax: claude/trigger.sh" "" "$syntax_check"

syntax_check=$(bash -n "$REPO_DIR/src/agents/claude/statusline-bridge.sh" 2>&1)
assert "syntax: statusline-bridge.sh" "" "$syntax_check"

# ==============================================================================
echo -e "\033[0;33m=== Test Group 8: Plugin cache deployment verification ===\033[0m"
# ==============================================================================
CACHE=$(ls -d "$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/"* 2>/dev/null | tail -1)

# New file exists in cache
assert "cache: context-data.sh exists" "true" "$([[ -f "$CACHE/src/core/context-data.sh" ]] && echo true || echo false)"
assert "cache: statusline-bridge.sh exists" "true" "$([[ -f "$CACHE/src/agents/claude/statusline-bridge.sh" ]] && echo true || echo false)"
assert "cache: statusline-bridge.sh executable" "true" "$([[ -x "$CACHE/src/agents/claude/statusline-bridge.sh" ]] && echo true || echo false)"

# Modified files match worktree
for f in src/core/trigger.sh src/core/title-management.sh src/core/theme-config-loader.sh src/config/defaults.conf src/agents/claude/trigger.sh; do
    if diff -q "$REPO_DIR/$f" "$CACHE/$f" &>/dev/null; then
        ((pass++))
    else
        ((fail++))
        echo "  FAIL: cache mismatch: $f"
    fi
done

# ==============================================================================
# RESULTS
# ==============================================================================
total=$((pass + fail))
echo ""
echo -e "\033[0;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "  \033[0;32mALL $total INTEGRATION TESTS: Pass: $pass | Fail: $fail\033[0m"
echo -e "\033[0;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
if [[ $fail -eq 0 ]]; then
    echo -e "\n  \033[0;32mAll integration tests passed!\033[0m"
else
    echo -e "\n  \033[0;31m$fail test(s) failed!\033[0m"
    exit 1
fi
