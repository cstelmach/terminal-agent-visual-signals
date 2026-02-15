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

# Estimate context usage from transcript file size.
# ~3.5 chars/token heuristic. Sets TAVS_CONTEXT_PCT only.
# Returns 0 on success, 1 if file missing/empty.
_estimate_from_transcript() {
    local transcript_path="${1:-${TAVS_TRANSCRIPT_PATH:-}}"
    [[ -z "$transcript_path" || ! -f "$transcript_path" ]] && return 1

    local file_size
    # macOS stat vs Linux stat
    file_size=$(stat -f%z "$transcript_path" 2>/dev/null \
        || stat -c%s "$transcript_path" 2>/dev/null)
    [[ -z "$file_size" || "$file_size" -eq 0 ]] 2>/dev/null && return 1

    # ~3.5 chars/token: file_size / 3.5 = file_size * 10 / 35
    local _default_ctx=200000
    local ctx_size="${TAVS_CONTEXT_WINDOW_SIZE:-$_default_ctx}"
    local estimated_tokens=$(( file_size * 10 / 35 ))
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
    # Reset globals
    TAVS_CONTEXT_PCT=""
    TAVS_CONTEXT_MODEL=""
    TAVS_CONTEXT_COST=""
    TAVS_CONTEXT_DURATION=""
    TAVS_CONTEXT_LINES_ADD=""
    TAVS_CONTEXT_LINES_REM=""

    # Try bridge state file first (accurate, real-time)
    if read_bridge_state; then
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

    # Determine array length via nameref-safe approach
    local -n _arr="$array_name" 2>/dev/null
    if [[ ${#_arr[@]} -eq 0 ]]; then
        # Fallback for shells without nameref
        echo ""
        return
    fi

    local max_index=$(( ${#_arr[@]} - 1 ))
    [[ $index -gt $max_index ]] && index=$max_index
    [[ $index -lt 0 ]] && index=0

    echo "${_arr[$index]}"
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
