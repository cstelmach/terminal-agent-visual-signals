#!/bin/bash
# ==============================================================================
# TAVS Subagent Counter Module
# ==============================================================================
# Tracks the number of active subagents for visual state management.
# Uses session-specific state files to avoid conflicts between sessions.
#
# When subagents spawn (SubagentStart), counter increments.
# When subagents complete (SubagentStop), counter decrements.
# When complete fires, counter resets to 0.
#
# This enables:
#   1. Distinct subagent visual state (when count > 0)
#   2. Title display showing "+N subagents"
#   3. Proper state transitions back to processing when all subagents complete
# ==============================================================================

# Use TTY-safe path for session isolation (set by trigger.sh)
SUBAGENT_COUNT_FILE="/tmp/tavs-subagent-count-${TTY_SAFE:-$$}"

# ==============================================================================
# increment_subagent_count
# ==============================================================================
# Atomically increment the subagent counter.
# Called when SubagentStart hook fires.
# ==============================================================================
increment_subagent_count() {
    local count
    count=$(cat "$SUBAGENT_COUNT_FILE" 2>/dev/null || echo 0)
    echo $((count + 1)) > "$SUBAGENT_COUNT_FILE"

    [[ "$DEBUG_ALL" == "1" ]] && echo "[TAVS] Subagent count incremented: $((count + 1))" >&2
}

# ==============================================================================
# decrement_subagent_count
# ==============================================================================
# Atomically decrement the subagent counter.
# Called when SubagentStop hook fires.
# Returns the new count (useful for state transition decisions).
# ==============================================================================
decrement_subagent_count() {
    local count
    count=$(cat "$SUBAGENT_COUNT_FILE" 2>/dev/null || echo 0)

    if [[ $count -gt 0 ]]; then
        echo $((count - 1)) > "$SUBAGENT_COUNT_FILE"
        [[ "$DEBUG_ALL" == "1" ]] && echo "[TAVS] Subagent count decremented: $((count - 1))" >&2
        echo $((count - 1))
    else
        [[ "$DEBUG_ALL" == "1" ]] && echo "[TAVS] Subagent count already at 0" >&2
        echo 0
    fi
}

# ==============================================================================
# get_subagent_count
# ==============================================================================
# Get the current subagent counter value.
# Returns 0 if no counter file exists.
# ==============================================================================
get_subagent_count() {
    cat "$SUBAGENT_COUNT_FILE" 2>/dev/null || echo 0
}

# ==============================================================================
# reset_subagent_count
# ==============================================================================
# Reset the subagent counter to 0 and remove the state file.
# Called when complete hook fires or session ends.
# ==============================================================================
reset_subagent_count() {
    rm -f "$SUBAGENT_COUNT_FILE"

    [[ "$DEBUG_ALL" == "1" ]] && echo "[TAVS] Subagent count reset" >&2
}

# ==============================================================================
# has_active_subagents
# ==============================================================================
# Check if there are any active subagents.
# Returns 0 (true) if count > 0, 1 (false) otherwise.
# ==============================================================================
has_active_subagents() {
    local count
    count=$(get_subagent_count)
    [[ $count -gt 0 ]]
}

# ==============================================================================
# get_subagent_title_suffix
# ==============================================================================
# Get the title suffix for active subagents.
# Returns empty string if no subagents, or "+N subagents" if count > 0.
# ==============================================================================
get_subagent_title_suffix() {
    local count
    count=$(get_subagent_count)

    if [[ $count -gt 0 ]]; then
        local _default_fmt='+{N}'
        local fmt="${TAVS_AGENTS_FORMAT:-$_default_fmt}"
        echo "${fmt//\{N\}/$count}"
    fi
}
