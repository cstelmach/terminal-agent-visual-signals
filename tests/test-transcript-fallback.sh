#!/bin/bash
# ==============================================================================
# TDD Test Script for Transcript Fallback & JSONL Parsing
# ==============================================================================
# Tests _estimate_from_transcript(), _parse_jsonl_usage(), _model_context_size(),
# _estimate_from_file_size(), and the load_context_data fallback chain.
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
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — correct token parsing ===${NC}"
# ==============================================================================

# Create mock Claude Code JSONL with known token counts
# input_tokens=5, cache_creation=1000, cache_read=99000 → total=100005 → 50%
cat > "$TEST_TMP/mock_transcript.jsonl" << 'EOF'
{"type":"user","messageId":"msg1","snapshot":{"messageId":"msg1"}}
{"type":"progress","data":{"message":{"message":{"usage":{"input_tokens":3}}}}}
{"type":"assistant","messageId":"msg2","message":{"model":"claude-opus-4-6","usage":{"input_tokens":5,"cache_creation_input_tokens":1000,"cache_read_input_tokens":99000,"output_tokens":500}}}
EOF

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_parse_jsonl_usage "$TEST_TMP/mock_transcript.jsonl"
assert_eq "JSONL parse: 100005/200000 = 50%" "50" "$TAVS_CONTEXT_PCT"
assert_eq "JSONL parse: model extracted" "claude-opus-4-6" "$TAVS_CONTEXT_MODEL"

# ==============================================================================
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — 65% (real-world scenario) ===${NC}"
# ==============================================================================

# Simulate real-world: input=1, cache_create=1105, cache_read=129974 → 131080 → 65%
cat > "$TEST_TMP/real_transcript.jsonl" << 'EOF'
{"type":"user","messageId":"msg1","snapshot":{"messageId":"msg1"}}
{"type":"assistant","messageId":"msg2","message":{"model":"claude-opus-4-6","usage":{"input_tokens":1,"cache_creation_input_tokens":1105,"cache_read_input_tokens":129974,"output_tokens":13,"service_tier":"standard"}}}
EOF

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_parse_jsonl_usage "$TEST_TMP/real_transcript.jsonl"
assert_eq "Real-world: 131080/200000 = 65%" "65" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — uses LAST assistant entry ===${NC}"
# ==============================================================================

# Two assistant entries — should use the LAST one
cat > "$TEST_TMP/multi_assistant.jsonl" << 'EOF'
{"type":"assistant","messageId":"msg1","message":{"model":"claude-opus-4-6","usage":{"input_tokens":2,"cache_creation_input_tokens":5000,"cache_read_input_tokens":15000,"output_tokens":100}}}
{"type":"user","messageId":"msg2","snapshot":{"messageId":"msg2"}}
{"type":"assistant","messageId":"msg3","message":{"model":"claude-opus-4-6","usage":{"input_tokens":3,"cache_creation_input_tokens":10000,"cache_read_input_tokens":90000,"output_tokens":200}}}
EOF

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_parse_jsonl_usage "$TEST_TMP/multi_assistant.jsonl"
# Last: 3 + 10000 + 90000 = 100003 → 50%
assert_eq "Uses last assistant: 100003/200000 = 50%" "50" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — no assistant entries ===${NC}"
# ==============================================================================

cat > "$TEST_TMP/no_assistant.jsonl" << 'EOF'
{"type":"user","messageId":"msg1","snapshot":{}}
{"type":"progress","data":{}}
EOF

TAVS_CONTEXT_PCT=""
_parse_jsonl_usage "$TEST_TMP/no_assistant.jsonl" && exit_code=0 || exit_code=$?
assert_eq "No assistant entries returns 1" "1" "$exit_code"
assert_empty "No assistant: PCT empty" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — zero token counts ===${NC}"
# ==============================================================================

cat > "$TEST_TMP/zero_tokens.jsonl" << 'EOF'
{"type":"assistant","messageId":"msg1","message":{"model":"claude-opus-4-6","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
EOF

TAVS_CONTEXT_PCT=""
_parse_jsonl_usage "$TEST_TMP/zero_tokens.jsonl" && exit_code=0 || exit_code=$?
assert_eq "Zero tokens returns 1" "1" "$exit_code"
assert_empty "Zero tokens: PCT empty" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — per-agent CONTEXT_WINDOW_SIZE ===${NC}"
# ==============================================================================

# Same tokens but with agent-resolved CONTEXT_WINDOW_SIZE=1000000
cat > "$TEST_TMP/gemini_transcript.jsonl" << 'EOF'
{"type":"assistant","messageId":"msg1","message":{"model":"gemini-2.5-pro","usage":{"input_tokens":5,"cache_creation_input_tokens":1000,"cache_read_input_tokens":99000,"output_tokens":500}}}
EOF

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
CONTEXT_WINDOW_SIZE=1000000  # Agent-resolved (e.g., GEMINI_CONTEXT_WINDOW_SIZE)
_parse_jsonl_usage "$TEST_TMP/gemini_transcript.jsonl"
# 100005 / 1000000 = 10%
assert_eq "Per-agent ctx size: 100005/1000000 = 10%" "10" "$TAVS_CONTEXT_PCT"
unset CONTEXT_WINDOW_SIZE

# ==============================================================================
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — model auto-detection ===${NC}"
# ==============================================================================

# Gemini model auto-detected → 1M context window
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_parse_jsonl_usage "$TEST_TMP/gemini_transcript.jsonl"
# 100005 / 1000000 (auto-detected from gemini-2.5-pro) = 10%
assert_eq "Gemini auto-detect: 100005/1000000 = 10%" "10" "$TAVS_CONTEXT_PCT"
assert_eq "Gemini model extracted" "gemini-2.5-pro" "$TAVS_CONTEXT_MODEL"

# ==============================================================================
echo -e "${YELLOW}=== Test: _model_context_size — model ID mapping ===${NC}"
# ==============================================================================

assert_eq "Claude Opus → 200k" "200000" "$(_model_context_size "claude-opus-4-6")"
assert_eq "Claude Sonnet → 200k" "200000" "$(_model_context_size "claude-sonnet-4-5-20250929")"
assert_eq "Claude Haiku → 200k" "200000" "$(_model_context_size "claude-haiku-4-5-20251001")"
assert_eq "Gemini Pro → 1M" "1000000" "$(_model_context_size "gemini-2.5-pro")"
assert_eq "Gemini Flash → 1M" "1000000" "$(_model_context_size "gemini-2.5-flash")"
assert_eq "Unknown model → default" "200000" "$(_model_context_size "unknown-model" "200000")"
assert_eq "Empty model → default" "200000" "$(_model_context_size "" "200000")"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_file_size — conservative multiplier ===${NC}"
# ==============================================================================

# 5000000 bytes (5MB) with 50 chars/token multiplier
# 5000000 / 50 = 100000 tokens → 100000 / 200000 = 50%
dd if=/dev/zero bs=1 count=5000000 of="$TEST_TMP/large_file.jsonl" 2>/dev/null
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_estimate_from_file_size "$TEST_TMP/large_file.jsonl"
assert_eq "5MB file-size fallback: 50%" "50" "$TAVS_CONTEXT_PCT"

# 350000 bytes → 350000/50 = 7000 tokens → 7000/200000 = 3%
dd if=/dev/zero bs=1 count=350000 of="$TEST_TMP/small_file.jsonl" 2>/dev/null
TAVS_CONTEXT_PCT=""
_estimate_from_file_size "$TEST_TMP/small_file.jsonl"
assert_eq "350KB file-size fallback: 3%" "3" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — prefers JSONL over file-size ===${NC}"
# ==============================================================================

# Create a large file with JSONL data near the end (realistic: assistant entry is recent).
# File-size fallback would give a very different result than JSONL parsing.
# Generate many user entries to bulk up the file, then append assistant entry at end.
: > "$TEST_TMP/prefer_jsonl.jsonl"
for i in $(seq 1 20000); do
    echo '{"type":"user","messageId":"pad'$i'","snapshot":{"messageId":"pad'$i'","data":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}}' >> "$TEST_TMP/prefer_jsonl.jsonl"
done
echo '{"type":"assistant","messageId":"msg1","message":{"model":"claude-opus-4-6","usage":{"input_tokens":2,"cache_creation_input_tokens":20000,"cache_read_input_tokens":80000,"output_tokens":500}}}' >> "$TEST_TMP/prefer_jsonl.jsonl"

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_estimate_from_transcript "$TEST_TMP/prefer_jsonl.jsonl"
# JSONL says: 2 + 20000 + 80000 = 100002 → 50%
# File-size would say: ~2MB / 50 = much higher
assert_eq "JSONL preferred over file-size: 50%" "50" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — falls to file-size when no JSONL ===${NC}"
# ==============================================================================

# File without assistant entries — forces file-size fallback
dd if=/dev/zero bs=1 count=5000000 of="$TEST_TMP/not_jsonl.dat" 2>/dev/null
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_estimate_from_transcript "$TEST_TMP/not_jsonl.dat"
# 5000000 / 50 = 100000 → 100000 / 200000 = 50%
assert_eq "Non-JSONL fallback to file-size: 50%" "50" "$TAVS_CONTEXT_PCT"

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

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_TRANSCRIPT_PATH="$TEST_TMP/real_transcript.jsonl"
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_estimate_from_transcript
assert_eq "uses TAVS_TRANSCRIPT_PATH env: 65%" "65" "$TAVS_CONTEXT_PCT"
unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — sets model from JSONL ===${NC}"
# ==============================================================================

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_estimate_from_transcript "$TEST_TMP/mock_transcript.jsonl"
assert_eq "JSONL sets model" "claude-opus-4-6" "$TAVS_CONTEXT_MODEL"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_transcript — doesn't overwrite existing model ===${NC}"
# ==============================================================================

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL="already-set"
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_estimate_from_transcript "$TEST_TMP/mock_transcript.jsonl"
assert_eq "Preserves existing model" "already-set" "$TAVS_CONTEXT_MODEL"

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_file_size — clamping at 100% ===${NC}"
# ==============================================================================

# 20MB file → 20000000 / 50 = 400000 tokens → 400000 / 200000 = 200% → clamped
dd if=/dev/zero bs=1 count=20000000 of="$TEST_TMP/huge_file.dat" 2>/dev/null
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_estimate_from_file_size "$TEST_TMP/huge_file.dat"
assert_eq "Huge file clamped to 100%" "100" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data — fallback to transcript JSONL ===${NC}"
# ==============================================================================

# No bridge data (point to empty state dir), but transcript exists with JSONL data
MOCK_STATE_DIR=$(mktemp -d)
TTY_SAFE="_dev_ttys999"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_TRANSCRIPT_PATH="$TEST_TMP/real_transcript.jsonl"
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true

load_context_data
assert_eq "fallback: pct from JSONL parsing" "65" "$TAVS_CONTEXT_PCT"
assert_eq "fallback: model from JSONL" "claude-opus-4-6" "$TAVS_CONTEXT_MODEL"
# JSONL doesn't provide cost — should be empty (reset by load_context_data)
assert_empty "fallback: cost empty" "$TAVS_CONTEXT_COST"

rm -rf "$MOCK_STATE_DIR"
unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data — no bridge, no transcript ===${NC}"
# ==============================================================================

MOCK_STATE_DIR=$(mktemp -d)
TTY_SAFE="_dev_ttys999"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
unset TAVS_TRANSCRIPT_PATH 2>/dev/null || true

load_context_data && exit_code=0 || exit_code=$?
assert_eq "no data returns 1" "1" "$exit_code"
assert_empty "no data: pct empty" "$TAVS_CONTEXT_PCT"
assert_empty "no data: model empty" "$TAVS_CONTEXT_MODEL"

rm -rf "$MOCK_STATE_DIR"

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data — bridge preferred over transcript ===${NC}"
# ==============================================================================

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
TAVS_TRANSCRIPT_PATH="$TEST_TMP/real_transcript.jsonl"
TAVS_CONTEXT_BRIDGE_MAX_AGE=30
TAVS_CONTEXT_WINDOW_SIZE=200000

load_context_data
assert_eq "bridge wins: pct=72 not 65" "72" "$TAVS_CONTEXT_PCT"
assert_eq "bridge wins: model=Opus" "Opus" "$TAVS_CONTEXT_MODEL"

rm -rf "$MOCK_STATE_DIR"
unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
echo -e "${YELLOW}=== Test: load_context_data — stale bridge falls to JSONL ===${NC}"
# ==============================================================================

MOCK_STATE_DIR=$(mktemp -d)
MOCK_STATE_FILE="${MOCK_STATE_DIR}/context._dev_ttys001"
cat > "$MOCK_STATE_FILE" << 'EOF'
pct=72
model=Opus
ts=1000000000
EOF

TTY_SAFE="_dev_ttys001"
_TAVS_CONTEXT_STATE_DIR="$MOCK_STATE_DIR"
TAVS_TRANSCRIPT_PATH="$TEST_TMP/real_transcript.jsonl"
TAVS_CONTEXT_BRIDGE_MAX_AGE=30
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true

load_context_data
assert_eq "stale bridge → JSONL: pct=65" "65" "$TAVS_CONTEXT_PCT"
assert_eq "stale bridge → JSONL: model from JSONL" "claude-opus-4-6" "$TAVS_CONTEXT_MODEL"

rm -rf "$MOCK_STATE_DIR"
unset TAVS_TRANSCRIPT_PATH

# ==============================================================================
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — clamping at 100% ===${NC}"
# ==============================================================================

# tokens > context window → should clamp
cat > "$TEST_TMP/overflow_tokens.jsonl" << 'EOF'
{"type":"assistant","messageId":"msg1","message":{"model":"claude-opus-4-6","usage":{"input_tokens":10,"cache_creation_input_tokens":100000,"cache_read_input_tokens":150000,"output_tokens":500}}}
EOF

TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=200000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_parse_jsonl_usage "$TEST_TMP/overflow_tokens.jsonl"
# 250010 / 200000 = 125% → clamped to 100%
assert_eq "Overflow tokens clamped to 100%" "100" "$TAVS_CONTEXT_PCT"

# ==============================================================================
echo -e "${YELLOW}=== Test: _parse_jsonl_usage — custom TAVS_CONTEXT_WINDOW_SIZE ===${NC}"
# ==============================================================================

# Extended context: 1M tokens
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_WINDOW_SIZE=1000000
unset CONTEXT_WINDOW_SIZE 2>/dev/null || true
_parse_jsonl_usage "$TEST_TMP/real_transcript.jsonl"
# 131080 / 1000000 = 13%
assert_eq "1M context: 131080/1000000 = 13%" "13" "$TAVS_CONTEXT_PCT"

# Restore default
TAVS_CONTEXT_WINDOW_SIZE=200000

# ==============================================================================
echo -e "${YELLOW}=== Test: _estimate_from_file_size — per-agent CONTEXT_WINDOW_SIZE ===${NC}"
# ==============================================================================

dd if=/dev/zero bs=1 count=5000000 of="$TEST_TMP/file_size_agent.dat" 2>/dev/null
TAVS_CONTEXT_PCT=""
CONTEXT_WINDOW_SIZE=1000000  # Agent-resolved
_estimate_from_file_size "$TEST_TMP/file_size_agent.dat"
# 5000000 / 50 = 100000 → 100000 / 1000000 = 10%
assert_eq "File-size with agent ctx: 10%" "10" "$TAVS_CONTEXT_PCT"
unset CONTEXT_WINDOW_SIZE

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
