#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Context Data Module
# ==============================================================================
# Provides context window data resolution for title tokens.
# Reads from StatusLine bridge state file or estimates from transcript size.
# All context tokens resolve to empty string when no data is available.
# ==============================================================================

# === GLOBAL STATE ===
# These are populated by load_context_data() and consumed by compose_title()
TAVS_CONTEXT_PCT=""
TAVS_CONTEXT_MODEL=""
TAVS_CONTEXT_COST=""
TAVS_CONTEXT_DURATION=""
TAVS_CONTEXT_LINES_ADD=""
TAVS_CONTEXT_LINES_REM=""

# ==============================================================================
# BRIDGE STATE FILE READING
# ==============================================================================

# Read context data from bridge state file.
# State file location: {state_dir}/context.{TTY_SAFE}
# Returns 0 on success, 1 if file missing/stale/unreadable.
read_bridge_state() {
    # Determine state directory (allow test override)
    local state_dir="${_TAVS_CONTEXT_STATE_DIR:-}"
    if [[ -z "$state_dir" ]]; then
        # Use get_spinner_state_dir if available (sourced from spinner.sh)
        if type get_spinner_state_dir &>/dev/null; then
            state_dir=$(get_spinner_state_dir)
        else
            # Inline fallback matching spinner.sh:16-24
            if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR:-}" ]]; then
                state_dir="$XDG_RUNTIME_DIR/tavs"
            else
                state_dir="${HOME}/.cache/tavs"
            fi
        fi
    fi

    local state_file="${state_dir}/context.${TTY_SAFE:-unknown}"
    [[ ! -f "$state_file" ]] && return 1

    # Safe key=value parsing — NEVER source state files
    # Pattern from title-state-persistence.sh:104-128
    local _pct="" _model="" _cost="" _duration="" _lines_add="" _lines_rem="" _ts=""
    while IFS='=' read -r k v; do
        # Skip comments and empty lines
        [[ "$k" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$k" ]] && continue
        # Strip quotes from value
        v="${v%\"}" ; v="${v#\"}"
        v="${v%\'}" ; v="${v#\'}"
        case "$k" in
            pct)       _pct="$v" ;;
            model)     _model="$v" ;;
            cost)      _cost="$v" ;;
            duration)  _duration="$v" ;;
            lines_add) _lines_add="$v" ;;
            lines_rem) _lines_rem="$v" ;;
            ts)        _ts="$v" ;;
        esac
    done < "$state_file"

    # Staleness check: reject if ts is too old
    if [[ -n "$_ts" ]]; then
        local _default_max_age=30
        local max_age="${TAVS_CONTEXT_BRIDGE_MAX_AGE:-$_default_max_age}"
        local now
        now=$(date +%s)
        local age=$(( now - _ts ))
        if [[ $age -gt $max_age ]]; then
            return 1
        fi
    else
        # No timestamp means we can't verify freshness — reject
        return 1
    fi

    # Populate globals
    TAVS_CONTEXT_PCT="$_pct"
    TAVS_CONTEXT_MODEL="$_model"
    TAVS_CONTEXT_COST="$_cost"
    TAVS_CONTEXT_DURATION="$_duration"
    TAVS_CONTEXT_LINES_ADD="$_lines_add"
    TAVS_CONTEXT_LINES_REM="$_lines_rem"
    return 0
}

# ==============================================================================
# TRANSCRIPT FALLBACK ESTIMATION
# ==============================================================================

# Estimate context usage from transcript JSONL file.
# Strategy 1 (primary): Parse actual token counts from last assistant entry.
# Strategy 2 (fallback): Conservative file-size estimation.
# Sets TAVS_CONTEXT_PCT (and optionally TAVS_CONTEXT_MODEL).
# Returns 0 on success, 1 if file missing/empty/unreadable.
_estimate_from_transcript() {
    local transcript_path="${1:-${TAVS_TRANSCRIPT_PATH:-}}"
    [[ -z "$transcript_path" || ! -f "$transcript_path" ]] && return 1

    # Strategy 1: Parse actual token counts from Claude Code JSONL.
    # Each assistant message has message.usage with exact token counts.
    if _parse_jsonl_usage "$transcript_path"; then
        return 0
    fi

    # Strategy 2: Conservative file-size fallback.
    # Only reached when JSONL parsing fails (non-Claude format, no assistant entries).
    # JSONL overhead makes this inherently imprecise — use very conservative multiplier
    # (~50 chars/token) to underestimate rather than overestimate. Showing 30% when
    # actual is 60% is far less disruptive than showing 100% when actual is 60%.
    _estimate_from_file_size "$transcript_path"
}

# Parse actual token counts from Claude Code JSONL transcript.
# Reads the last assistant entry's message.usage for exact token counts:
#   input_tokens + cache_creation_input_tokens + cache_read_input_tokens
# Returns 0 on success, 1 if no usable data found.
_parse_jsonl_usage() {
    local transcript_path="$1"

    # Find the last assistant entry with usage data.
    # tail -500 handles large files efficiently (assistant entry always near end).
    local _last_assistant
    _last_assistant=$(tail -500 "$transcript_path" 2>/dev/null \
        | grep '"type":"assistant"' | tail -1)
    [[ -z "$_last_assistant" ]] && return 1

    # Extract token counts — field names are unique in Claude Code JSONL.
    # cache_read_input_tokens and cache_creation_input_tokens are the bulk of context.
    local _cache_read _cache_create _input_tokens
    _cache_read=$(printf '%s' "$_last_assistant" | \
        sed -n 's/.*"cache_read_input_tokens"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' \
        | head -1)
    _cache_create=$(printf '%s' "$_last_assistant" | \
        sed -n 's/.*"cache_creation_input_tokens"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' \
        | head -1)
    # input_tokens appears in multiple nested objects; greedy .* after "usage" matches
    # the last occurrence (which is the one in the usage block).
    _input_tokens=$(printf '%s' "$_last_assistant" | \
        sed -n 's/.*"usage"[^}]*"input_tokens"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' \
        | head -1)

    local total=$(( ${_cache_read:-0} + ${_cache_create:-0} + ${_input_tokens:-0} ))
    [[ $total -eq 0 ]] && return 1

    # Determine context window size (per-agent resolved or global default)
    local _default_ctx=200000
    local ctx_size="${CONTEXT_WINDOW_SIZE:-${TAVS_CONTEXT_WINDOW_SIZE:-$_default_ctx}}"

    # Auto-detect from model ID if no explicit override
    if [[ "$ctx_size" -eq "$_default_ctx" ]]; then
        local _model_id
        _model_id=$(printf '%s' "$_last_assistant" | \
            sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        if [[ -n "$_model_id" ]]; then
            ctx_size=$(_model_context_size "$_model_id" "$ctx_size")
        fi
    fi

    local pct=$(( total * 100 / ctx_size ))
    [[ $pct -gt 100 ]] && pct=100

    TAVS_CONTEXT_PCT="$pct"

    # Bonus: populate model name for {MODEL} token if not already set
    if [[ -z "${TAVS_CONTEXT_MODEL:-}" ]]; then
        local _model_name
        _model_name=$(printf '%s' "$_last_assistant" | \
            sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        [[ -n "$_model_name" ]] && TAVS_CONTEXT_MODEL="$_model_name"
    fi

    return 0
}

# Map model ID to context window size (tokens).
# Used for auto-detection when no explicit CONTEXT_WINDOW_SIZE is set.
_model_context_size() {
    local model_id="${1:-}"
    local default_size="${2:-200000}"

    case "$model_id" in
        # Standard Claude models — 200k context
        claude-opus-*|claude-sonnet-*|claude-haiku-*) echo "200000" ;;
        # Gemini models — 1M+ context
        gemini-*-pro*|gemini-*-flash*) echo "1000000" ;;
        # Unknown — use default
        *) echo "$default_size" ;;
    esac
}

# Conservative file-size estimation (last-resort fallback).
# ~50 chars/token for JSONL (accounts for JSON overhead, tool results, metadata,
# and compacted history still present in the file).
# Returns 0 on success, 1 if file empty/unreadable.
_estimate_from_file_size() {
    local transcript_path="$1"

    local file_size
    # macOS stat vs Linux stat
    file_size=$(stat -f%z "$transcript_path" 2>/dev/null \
        || stat -c%s "$transcript_path" 2>/dev/null)
    [[ -z "$file_size" || "$file_size" -eq 0 ]] 2>/dev/null && return 1

    local _default_ctx=200000
    local ctx_size="${CONTEXT_WINDOW_SIZE:-${TAVS_CONTEXT_WINDOW_SIZE:-$_default_ctx}}"
    # ~50 chars/token for JSONL: file_size / 50 = file_size * 10 / 500
    local estimated_tokens=$(( file_size * 10 / 500 ))
    local pct=$(( estimated_tokens * 100 / ctx_size ))
    [[ $pct -gt 100 ]] && pct=100

    TAVS_CONTEXT_PCT="$pct"
    return 0
}

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

# Load context data from best available source.
# Fallback chain: bridge state → transcript estimate → empty (tokens collapse)
load_context_data() {
    # Prevent re-reading state file in same trigger invocation.
    # _TAVS_CONTEXT_LOADED is process-scoped (fresh per trigger.sh run).
    # Needed because compact context eye calls this from get_compact_face(),
    # and compose_title() may call it again for {CONTEXT_*} title tokens.
    [[ -n "${_TAVS_CONTEXT_LOADED:-}" ]] && return 0
    _TAVS_CONTEXT_LOADED=1

    # Reset globals
    TAVS_CONTEXT_PCT=""
    TAVS_CONTEXT_MODEL=""
    TAVS_CONTEXT_COST=""
    TAVS_CONTEXT_DURATION=""
    TAVS_CONTEXT_LINES_ADD=""
    TAVS_CONTEXT_LINES_REM=""

    # Try bridge state file first (accurate, real-time)
    if read_bridge_state && [[ -n "$TAVS_CONTEXT_PCT" ]]; then
        return 0
    fi

    # Fallback: transcript file size estimation (approximate)
    if _estimate_from_transcript; then
        return 0
    fi

    # Neither available — all tokens will resolve to empty
    return 1
}

# ==============================================================================
# TOKEN RESOLUTION
# ==============================================================================

# Resolve a context token name to its formatted display value.
# Usage: resolve_context_token "TOKEN_NAME" "percentage"
# Returns the formatted value on stdout, empty string if no data.
resolve_context_token() {
    local token="$1"
    local pct="${2:-}"

    # Empty percentage → empty string (tokens collapse via sed cleanup)
    [[ -z "$pct" ]] && echo "" && return 0

    # Clamp to 0-100
    [[ "$pct" -gt 100 ]] 2>/dev/null && pct=100
    [[ "$pct" -lt 0 ]] 2>/dev/null && pct=0

    case "$token" in
        CONTEXT_PCT)      _get_percentage "$pct" ;;
        CONTEXT_FOOD)     _get_icon_from_array "TAVS_CONTEXT_FOOD_21" "$pct" 5 ;;
        CONTEXT_FOOD_10)  _get_icon_from_array "TAVS_CONTEXT_FOOD_11" "$pct" 10 ;;
        CONTEXT_ICON)     _get_icon_from_array "TAVS_CONTEXT_CIRCLES_11" "$pct" 10 ;;
        CONTEXT_NUMBER)   _get_icon_from_array "TAVS_CONTEXT_NUMBERS" "$pct" 10 ;;
        CONTEXT_BAR_H)    _get_bar_horizontal "$pct" 5 ;;
        CONTEXT_BAR_HL)   _get_bar_horizontal "$pct" 10 ;;
        CONTEXT_BAR_V)    _get_bar_vertical "$pct" ;;
        CONTEXT_BAR_VM)   _get_bar_vertical_max "$pct" ;;
        CONTEXT_BRAILLE)  _get_braille "$pct" ;;
        *)                echo "" ;;
    esac
}

# ==============================================================================
# ICON / BAR HELPER FUNCTIONS
# ==============================================================================

# Lookup icon from named bash array by percentage.
# Usage: _get_icon_from_array "ARRAY_NAME" pct step
#   step = percentage increment per index (5 for 21-stage, 10 for 11-stage)
_get_icon_from_array() {
    local array_name="$1"
    local pct="$2"
    local step="$3"

    local index=$(( pct / step ))

    # Get array length via eval (Bash 3.2 compatible — no nameref)
    local arr_len
    eval "arr_len=\${#${array_name}[@]}" 2>/dev/null
    if [[ -z "$arr_len" || "$arr_len" -eq 0 ]]; then
        echo ""
        return
    fi

    local max_index=$(( arr_len - 1 ))
    [[ $index -gt $max_index ]] && index=$max_index
    [[ $index -lt 0 ]] && index=0

    eval "echo \"\${${array_name}[$index]}\""
}

# Generate horizontal progress bar.
# Usage: _get_bar_horizontal pct width
_get_bar_horizontal() {
    local pct="$1"
    local width="$2"

    local _fill_char="${TAVS_CONTEXT_BAR_FILL:-▓}"
    local _empty_char="${TAVS_CONTEXT_BAR_EMPTY:-░}"

    local filled=$(( pct * width / 100 ))
    [[ $filled -gt $width ]] && filled=$width
    [[ $filled -lt 0 ]] && filled=0
    local empty=$(( width - filled ))

    local bar=""
    local i
    for (( i = 0; i < filled; i++ )); do
        bar="${bar}${_fill_char}"
    done
    for (( i = 0; i < empty; i++ )); do
        bar="${bar}${_empty_char}"
    done
    echo "$bar"
}

# Single vertical block character for percentage.
# Uses TAVS_CONTEXT_BLOCKS array (8-stage: ▁▂▃▄▅▆▇█)
# Formula: index = pct * 7 / 100 (clamped to 0-7)
_get_bar_vertical() {
    local pct="$1"

    local -n _blocks="TAVS_CONTEXT_BLOCKS" 2>/dev/null
    if [[ ${#_blocks[@]} -eq 0 ]]; then
        echo ""
        return
    fi

    local index=$(( pct * 7 / 100 ))
    local max_index=$(( ${#_blocks[@]} - 1 ))
    [[ $index -gt $max_index ]] && index=$max_index
    [[ $index -lt 0 ]] && index=0

    echo "${_blocks[$index]}"
}

# Vertical block + max outline character.
# Usage: _get_bar_vertical_max pct
_get_bar_vertical_max() {
    local pct="$1"
    local _max_char="${TAVS_CONTEXT_BAR_MAX:-▒}"
    local block
    block=$(_get_bar_vertical "$pct")
    echo "${block}${_max_char}"
}

# Single braille character for percentage.
# Uses TAVS_CONTEXT_BRAILLE array (7-stage: ⠀⠄⠤⠴⠶⠷⠿)
# Formula: index = pct * 6 / 100 (clamped to 0-6)
_get_braille() {
    local pct="$1"

    local -n _braille="TAVS_CONTEXT_BRAILLE" 2>/dev/null
    if [[ ${#_braille[@]} -eq 0 ]]; then
        echo ""
        return
    fi

    local index=$(( pct * 6 / 100 ))
    local max_index=$(( ${#_braille[@]} - 1 ))
    [[ $index -gt $max_index ]] && index=$max_index
    [[ $index -lt 0 ]] && index=0

    echo "${_braille[$index]}"
}

# Formatted percentage string: "N%"
_get_percentage() {
    local pct="$1"
    echo "${pct}%"
}

# ==============================================================================
# SESSION METADATA FORMAT HELPERS
# ==============================================================================

# Format cost as "$X.XX"
_format_cost() {
    local cost="${1:-}"
    [[ -z "$cost" ]] && echo "" && return
    # Handle "0" as "0.00"
    if [[ "$cost" == "0" ]]; then
        echo "\$0.00"
        return
    fi
    # Use printf for 2 decimal places if it's a number
    if printf '%f' "$cost" &>/dev/null; then
        printf '$%.2f' "$cost"
    else
        echo "\$$cost"
    fi
}

# Format duration from milliseconds to "NmNNs"
_format_duration() {
    local ms="${1:-}"
    [[ -z "$ms" ]] && echo "" && return
    local total_secs=$(( ms / 1000 ))
    local mins=$(( total_secs / 60 ))
    local secs=$(( total_secs % 60 ))
    echo "${mins}m${secs}s"
}

# Format lines added as "+N"
_format_lines() {
    local lines="${1:-}"
    [[ -z "$lines" ]] && echo "" && return
    echo "+${lines}"
}
