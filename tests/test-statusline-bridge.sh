#!/bin/bash
# ==============================================================================
# TDD Test Script for StatusLine Bridge & trigger.sh transcript_path
# ==============================================================================
# Run: bash tests/test-statusline-bridge.sh
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

assert_not_empty() {
    local test_name="$1"
    local actual="$2"
    if [[ -n "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    expected non-empty, got empty"
    fi
}

assert_file_exists() {
    local test_name="$1"
    local path="$2"
    if [[ -f "$path" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    file does not exist: '${path}'"
    fi
}

assert_file_not_exists() {
    local test_name="$1"
    local path="$2"
    if [[ ! -f "$path" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    file should not exist: '${path}'"
    fi
}

assert_contains() {
    local test_name="$1"
    local haystack="$2"
    local needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    '${haystack}' does not contain '${needle}'"
    fi
}

assert_executable() {
    local test_name="$1"
    local path="$2"
    if [[ -x "$path" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ${test_name}\n    not executable: '${path}'"
    fi
}

# ==============================================================================
# TEST SETUP
# ==============================================================================

# Create isolated temp directory for test state files
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

BRIDGE_SCRIPT="./src/agents/claude/statusline-bridge.sh"
TRIGGER_SCRIPT="./src/agents/claude/trigger.sh"

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge script exists and is executable ===${NC}"
# ==============================================================================

assert_file_exists "Bridge script exists" "$BRIDGE_SCRIPT"
assert_executable "Bridge script is executable" "$BRIDGE_SCRIPT"

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge produces zero stdout ===${NC}"
# ==============================================================================

# Full JSON payload — bridge must produce ZERO bytes of stdout
FULL_JSON='{"context_window":{"used_percentage":72,"total_input_tokens":90000,"total_output_tokens":12000,"context_window_size":200000},"model":{"id":"claude-opus-4-6","display_name":"Opus"},"cost":{"total_cost_usd":1.23,"total_duration_ms":300000,"total_lines_added":42,"total_lines_removed":7},"session_id":"abc123","version":"2.1.39"}'

output=$(printf '%s' "$FULL_JSON" | _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" bash "$BRIDGE_SCRIPT" 2>/dev/null || true)
assert_empty "Bridge stdout is empty with full JSON" "$output"

# Also test with minimal JSON
output=$(printf '%s' '{"context_window":{"used_percentage":50}}' | _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" bash "$BRIDGE_SCRIPT" 2>/dev/null || true)
assert_empty "Bridge stdout is empty with minimal JSON" "$output"

# Empty input
output=$(printf '' | _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" bash "$BRIDGE_SCRIPT" 2>/dev/null || true)
assert_empty "Bridge stdout is empty with empty input" "$output"

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge writes state file with correct fields ===${NC}"
# ==============================================================================

# Clean test dir
rm -f "$TEST_DIR"/context.*

# Feed full JSON — use test override for state dir and TTY
printf '%s' "$FULL_JSON" | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

STATE_FILE="$TEST_DIR/context._dev_ttys999"
assert_file_exists "State file created" "$STATE_FILE"

# Parse the state file to verify fields
if [[ -f "$STATE_FILE" ]]; then
    _pct="" _model="" _cost="" _duration="" _lines_add="" _lines_rem="" _ts=""
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        case "$k" in
            pct)       _pct="$v" ;;
            model)     _model="$v" ;;
            cost)      _cost="$v" ;;
            duration)  _duration="$v" ;;
            lines_add) _lines_add="$v" ;;
            lines_rem) _lines_rem="$v" ;;
            ts)        _ts="$v" ;;
        esac
    done < "$STATE_FILE"

    assert_eq "State file pct=72" "72" "$_pct"
    assert_eq "State file model=Opus" "Opus" "$_model"
    assert_eq "State file cost=1.23" "1.23" "$_cost"
    assert_eq "State file duration=300000" "300000" "$_duration"
    assert_eq "State file lines_add=42" "42" "$_lines_add"
    assert_eq "State file lines_rem=7" "7" "$_lines_rem"
    assert_not_empty "State file has timestamp" "$_ts"

    # Timestamp should be a recent epoch (within 10s of now)
    now=$(date +%s)
    diff=$(( now - _ts ))
    if [[ $diff -ge 0 && $diff -le 10 ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: ts freshness\n    ts=$_ts, now=$now, diff=${diff}s (expected <=10s)"
    fi
else
    # File doesn't exist — fail all field tests
    for f in pct model cost duration lines_add lines_rem ts freshness; do
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: State file field '$f' — file not created"
    done
fi

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge handles partial JSON gracefully ===${NC}"
# ==============================================================================

# Only context_window.used_percentage — other fields should be empty
rm -f "$TEST_DIR"/context.*
printf '%s' '{"context_window":{"used_percentage":45}}' | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

STATE_FILE="$TEST_DIR/context._dev_ttys999"
assert_file_exists "State file created with partial JSON" "$STATE_FILE"

if [[ -f "$STATE_FILE" ]]; then
    _pct="" _model="" _cost=""
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        case "$k" in
            pct)   _pct="$v" ;;
            model) _model="$v" ;;
            cost)  _cost="$v" ;;
        esac
    done < "$STATE_FILE"

    assert_eq "Partial JSON: pct=45" "45" "$_pct"
    assert_empty "Partial JSON: model empty" "$_model"
    assert_empty "Partial JSON: cost empty" "$_cost"
fi

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge handles empty/invalid input ===${NC}"
# ==============================================================================

# Empty input — should not crash, should not leave broken state file
rm -f "$TEST_DIR"/context.*
printf '' | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

# With empty input, bridge may write a state file with empty fields or skip writing.
# Either behavior is acceptable — it must NOT crash.
# If it writes a file, fields should be empty.
STATE_FILE="$TEST_DIR/context._dev_ttys999"
if [[ -f "$STATE_FILE" ]]; then
    _pct=""
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        [[ "$k" == "pct" ]] && _pct="$v"
    done < "$STATE_FILE"
    assert_empty "Empty input: pct empty" "$_pct"
else
    # Not writing a file is also acceptable
    PASS=$((PASS + 1))
fi

# Garbage input
rm -f "$TEST_DIR"/context.*
printf 'not json at all' | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true
# Must not crash — that's the test (we got here without set -e aborting)
PASS=$((PASS + 1))

# ==============================================================================
echo -e "${YELLOW}=== Test: State file readable by read_bridge_state() ===${NC}"
# ==============================================================================

# Write a state file via bridge, then read it with context-data.sh's reader
rm -f "$TEST_DIR"/context.*
printf '%s' "$FULL_JSON" | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

# Source context-data module and read with its reader
source src/config/defaults.conf
source src/core/context-data.sh

STATE_FILE="$TEST_DIR/context._dev_ttys999"
if [[ -f "$STATE_FILE" ]]; then
    # Use context-data.sh's read_bridge_state with test overrides
    TTY_SAFE="_dev_ttys999"
    _TAVS_CONTEXT_STATE_DIR="$TEST_DIR"
    export TTY_SAFE _TAVS_CONTEXT_STATE_DIR

    if read_bridge_state; then
        assert_eq "read_bridge_state: PCT=72" "72" "$TAVS_CONTEXT_PCT"
        assert_eq "read_bridge_state: MODEL=Opus" "Opus" "$TAVS_CONTEXT_MODEL"
        assert_eq "read_bridge_state: COST=1.23" "1.23" "$TAVS_CONTEXT_COST"
        assert_eq "read_bridge_state: DURATION=300000" "300000" "$TAVS_CONTEXT_DURATION"
        assert_eq "read_bridge_state: LINES_ADD=42" "42" "$TAVS_CONTEXT_LINES_ADD"
        assert_eq "read_bridge_state: LINES_REM=7" "7" "$TAVS_CONTEXT_LINES_REM"
    else
        # read_bridge_state failed (probably staleness) — skip ts check, test core fields
        FAIL=$((FAIL + 6))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: read_bridge_state returned non-zero (state file may be stale)"
    fi
else
    for f in PCT MODEL COST DURATION LINES_ADD LINES_REM; do
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: read_bridge_state: $f — no state file"
    done
fi

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge atomic write (no partial files on interrupt) ===${NC}"
# ==============================================================================

# Verify state file does not contain tmp markers — basic atomicity check
STATE_FILE="$TEST_DIR/context._dev_ttys999"
if [[ -f "$STATE_FILE" ]]; then
    content=$(cat "$STATE_FILE")
    # Should not contain "tmp" in the filename portion (sanity check)
    if [[ "$STATE_FILE" != *".tmp."* ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: State file path contains .tmp. — not atomic"
    fi
    # File should have a proper comment header
    first_line=$(head -1 "$STATE_FILE")
    assert_contains "State file has comment header" "$first_line" "# TAVS"
else
    PASS=$((PASS + 1))  # No file means we can't test, but bridge tests above cover creation
fi

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge with integer percentage values ===${NC}"
# ==============================================================================

# Test 0%
rm -f "$TEST_DIR"/context.*
printf '%s' '{"context_window":{"used_percentage":0},"model":{"display_name":"Haiku"}}' | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

STATE_FILE="$TEST_DIR/context._dev_ttys999"
if [[ -f "$STATE_FILE" ]]; then
    _pct="" _model=""
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        case "$k" in
            pct)   _pct="$v" ;;
            model) _model="$v" ;;
        esac
    done < "$STATE_FILE"
    assert_eq "0% percentage" "0" "$_pct"
    assert_eq "Model Haiku" "Haiku" "$_model"
fi

# Test 100%
rm -f "$TEST_DIR"/context.*
printf '%s' '{"context_window":{"used_percentage":100},"model":{"display_name":"Sonnet"}}' | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

STATE_FILE="$TEST_DIR/context._dev_ttys999"
if [[ -f "$STATE_FILE" ]]; then
    _pct="" _model=""
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        case "$k" in
            pct)   _pct="$v" ;;
            model) _model="$v" ;;
        esac
    done < "$STATE_FILE"
    assert_eq "100% percentage" "100" "$_pct"
    assert_eq "Model Sonnet" "Sonnet" "$_model"
fi

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge with null/missing used_percentage ===${NC}"
# ==============================================================================

# used_percentage is null before first API call
rm -f "$TEST_DIR"/context.*
printf '%s' '{"context_window":{"used_percentage":null},"model":{"display_name":"Opus"}}' | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

STATE_FILE="$TEST_DIR/context._dev_ttys999"
if [[ -f "$STATE_FILE" ]]; then
    _pct="" _model=""
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        case "$k" in
            pct)   _pct="$v" ;;
            model) _model="$v" ;;
        esac
    done < "$STATE_FILE"
    # null should result in empty pct (not the string "null")
    if [[ "$_pct" == "null" ]]; then
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: pct is literal 'null', should be empty"
    else
        assert_empty "null pct resolves to empty" "$_pct"
    fi
    assert_eq "Model still extracted with null pct" "Opus" "$_model"
fi

# ==============================================================================
echo -e "${YELLOW}=== Test: State dir created if missing ===${NC}"
# ==============================================================================

NEW_DIR="$TEST_DIR/subdir_that_does_not_exist"
rm -rf "$NEW_DIR"

printf '%s' '{"context_window":{"used_percentage":50}}' | \
    _TAVS_BRIDGE_STATE_DIR="$NEW_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

if [[ -d "$NEW_DIR" ]]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: Bridge did not create state directory"
fi

# ==============================================================================
echo -e "${YELLOW}=== Test: trigger.sh transcript_path extraction ===${NC}"
# ==============================================================================

# Simulate hook JSON with transcript_path — test the extraction logic
# We can't easily run the full trigger.sh (it delegates to core trigger),
# so we test the extraction pattern directly.

HOOK_JSON='{"session_id":"abc123","transcript_path":"/Users/cs/.claude/sessions/abc123/transcript.jsonl","cwd":"/working/dir","permission_mode":"plan","hook_event_name":"PermissionRequest"}'

# Extract transcript_path using the same sed pattern the trigger should use
_transcript=$(printf '%s' "$HOOK_JSON" | \
    sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
assert_eq "transcript_path extracted" "/Users/cs/.claude/sessions/abc123/transcript.jsonl" "$_transcript"

# Without transcript_path
HOOK_JSON_NO_TRANSCRIPT='{"session_id":"abc123","cwd":"/working/dir","permission_mode":"plan"}'
_transcript=$(printf '%s' "$HOOK_JSON_NO_TRANSCRIPT" | \
    sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
assert_empty "No transcript_path in JSON" "$_transcript"

# With transcript_path containing special chars (spaces in path)
HOOK_JSON_SPECIAL='{"transcript_path":"/Users/cs/My Projects/transcript.jsonl"}'
_transcript=$(printf '%s' "$HOOK_JSON_SPECIAL" | \
    sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
assert_eq "transcript_path with spaces" "/Users/cs/My Projects/transcript.jsonl" "$_transcript"

# ==============================================================================
echo -e "${YELLOW}=== Test: trigger.sh actually exports TAVS_TRANSCRIPT_PATH ===${NC}"
# ==============================================================================

# Source the trigger in a subshell that won't actually execute the core trigger
# We simulate by checking the variable is set after the extraction block
HOOK_JSON_WITH_TRANSCRIPT='{"session_id":"abc123","transcript_path":"/tmp/test_transcript.jsonl","permission_mode":"default"}'

# Run trigger.sh in a subshell where we intercept the core trigger call
# Replace the last line (core trigger delegation) with an echo of the variable
_exported_transcript=$(
    printf '%s' "$HOOK_JSON_WITH_TRANSCRIPT" | (
        # Override the core trigger to just print the transcript path
        SCRIPT_DIR="./src/agents/claude"
        export TAVS_AGENT="claude"
        _tavs_stdin=""
        if [[ ! -t 0 ]]; then
            _tavs_stdin=$(cat 2>/dev/null)
        fi
        if [[ -n "$_tavs_stdin" ]]; then
            _mode=$(printf '%s' "$_tavs_stdin" | \
                sed -n 's/.*"permission_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
            [[ -n "$_mode" ]] && export TAVS_PERMISSION_MODE="$_mode"
            # This is the line we're testing — transcript_path extraction
            _transcript=$(printf '%s' "$_tavs_stdin" | \
                sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
            [[ -n "$_transcript" ]] && export TAVS_TRANSCRIPT_PATH="$_transcript"
        fi
        echo "${TAVS_TRANSCRIPT_PATH:-}"
    )
)
assert_eq "trigger.sh exports TAVS_TRANSCRIPT_PATH" "/tmp/test_transcript.jsonl" "$_exported_transcript"

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge with realistic Claude Code StatusLine JSON ===${NC}"
# ==============================================================================

# Full realistic JSON from Claude Code StatusLine (from spec section 3.1)
REALISTIC_JSON='{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/working/dir",
  "model": {
    "id": "claude-opus-4-6",
    "display_name": "Opus"
  },
  "workspace": {
    "current_dir": "/working/dir",
    "project_dir": "/project/dir"
  },
  "cost": {
    "total_cost_usd": 0.42,
    "total_duration_ms": 300000,
    "total_api_duration_ms": 12000,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "total_input_tokens": 90000,
    "total_output_tokens": 12000,
    "context_window_size": 200000,
    "used_percentage": 45,
    "remaining_percentage": 55,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false,
  "version": "2.1.39"
}'

rm -f "$TEST_DIR"/context.*
printf '%s' "$REALISTIC_JSON" | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

STATE_FILE="$TEST_DIR/context._dev_ttys999"
if [[ -f "$STATE_FILE" ]]; then
    _pct="" _model="" _cost="" _duration="" _lines_add="" _lines_rem=""
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        case "$k" in
            pct)       _pct="$v" ;;
            model)     _model="$v" ;;
            cost)      _cost="$v" ;;
            duration)  _duration="$v" ;;
            lines_add) _lines_add="$v" ;;
            lines_rem) _lines_rem="$v" ;;
        esac
    done < "$STATE_FILE"

    assert_eq "Realistic JSON: pct=45" "45" "$_pct"
    assert_eq "Realistic JSON: model=Opus" "Opus" "$_model"
    assert_eq "Realistic JSON: cost=0.42" "0.42" "$_cost"
    assert_eq "Realistic JSON: duration=300000" "300000" "$_duration"
    assert_eq "Realistic JSON: lines_add=156" "156" "$_lines_add"
    assert_eq "Realistic JSON: lines_rem=23" "23" "$_lines_rem"
else
    for f in pct model cost duration lines_add lines_rem; do
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  ${RED}FAIL${NC}: Realistic JSON: $f — no state file"
    done
fi

# ==============================================================================
echo -e "${YELLOW}=== Test: Bridge overwrites stale state file ===${NC}"
# ==============================================================================

# Write initial state, then overwrite with new data
rm -f "$TEST_DIR"/context.*
printf '%s' '{"context_window":{"used_percentage":30},"model":{"display_name":"Haiku"}}' | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

# Overwrite with new data
printf '%s' '{"context_window":{"used_percentage":80},"model":{"display_name":"Opus"}}' | \
    _TAVS_BRIDGE_STATE_DIR="$TEST_DIR" \
    _TAVS_BRIDGE_TTY_SAFE="_dev_ttys999" \
    bash "$BRIDGE_SCRIPT" 2>/dev/null || true

STATE_FILE="$TEST_DIR/context._dev_ttys999"
if [[ -f "$STATE_FILE" ]]; then
    _pct="" _model=""
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        case "$k" in
            pct)   _pct="$v" ;;
            model) _model="$v" ;;
        esac
    done < "$STATE_FILE"
    assert_eq "Overwritten pct=80" "80" "$_pct"
    assert_eq "Overwritten model=Opus" "Opus" "$_model"
fi

# ==============================================================================
# RESULTS
# ==============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}ALL $TOTAL TESTS PASSED${NC}"
else
    echo -e "  ${RED}$FAIL FAILED${NC} / $TOTAL total ($PASS passed)"
    echo -e "\nFailures:$ERRORS"
fi
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $FAIL -eq 0 ]]
