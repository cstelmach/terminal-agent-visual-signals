#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Session Icon Module
# ==============================================================================
# Assigns a unique animal emoji per terminal tab for visual identification.
# Icons persist across /clear (tied to TTY device, not session ID).
# Uses a registry to avoid duplicate icons across concurrent sessions.
#
# Public functions:
#   assign_session_icon()   - Assign unique icon (idempotent)
#   get_session_icon()      - Return current session's icon
#   release_session_icon()  - Unregister on session end
#
# Internal functions:
#   _cleanup_stale_icons()  - Remove entries for dead TTYs
#   _register_icon()        - Add entry to cross-session registry
#
# State files (in ~/.cache/tavs/):
#   session-icon.{TTY_SAFE}    - Per-TTY icon (single emoji)
#   session-icon-registry      - Cross-session tty=emoji pairs
#
# Dependencies:
#   - get_spinner_state_dir() from spinner.sh (secure dir helper)
#   - TTY_SAFE environment variable
#   - TAVS_SESSION_ICONS array from defaults.conf
# ==============================================================================

# ==============================================================================
# PUBLIC FUNCTIONS
# ==============================================================================

# Assign a unique icon to this TTY (idempotent - keeps existing icon)
# Called on every reset/SessionStart, but only assigns if no icon exists yet.
assign_session_icon() {
    local state_dir icon_file registry_file
    state_dir=$(get_spinner_state_dir)
    icon_file="${state_dir}/session-icon.${TTY_SAFE:-unknown}"
    registry_file="${state_dir}/session-icon-registry"

    # Idempotent: if icon already assigned for this TTY, keep it
    if [[ -f "$icon_file" ]]; then
        return 0
    fi

    # Clean up stale entries from dead TTYs
    _cleanup_stale_icons

    # Read currently taken icons from registry
    local taken=()
    if [[ -f "$registry_file" ]]; then
        while IFS='=' read -r k v; do
            [[ -z "$k" || "$k" =~ ^[#] ]] && continue
            taken+=("$v")
        done < "$registry_file"
    fi

    # Find available icons (not in taken list)
    local pool=("${TAVS_SESSION_ICONS[@]}")
    local available=()
    local icon found
    for icon in "${pool[@]}"; do
        found=false
        for t in "${taken[@]}"; do
            [[ "$t" == "$icon" ]] && { found=true; break; }
        done
        $found || available+=("$icon")
    done

    # Pick random from available, or full pool if exhausted
    local selected
    if [[ ${#available[@]} -gt 0 ]]; then
        selected="${available[$RANDOM % ${#available[@]}]}"
    else
        selected="${pool[$RANDOM % ${#pool[@]}]}"
    fi

    # Persist per-TTY (atomic write)
    local tmp_file="${icon_file}.tmp.$$"
    printf '%s\n' "$selected" > "$tmp_file" 2>/dev/null
    mv "$tmp_file" "$icon_file" 2>/dev/null

    # Register in cross-session registry
    _register_icon "$selected"

    [[ "$DEBUG_ALL" == "1" ]] && echo "[TAVS] Session icon assigned: $selected (TTY=$TTY_SAFE)" >&2
}

# Get this session's icon (empty if none assigned or disabled)
get_session_icon() {
    local state_dir icon_file
    state_dir=$(get_spinner_state_dir)
    icon_file="${state_dir}/session-icon.${TTY_SAFE:-unknown}"
    if [[ -f "$icon_file" ]]; then
        cat "$icon_file" 2>/dev/null
    fi
}

# Release this session's icon and unregister from registry
release_session_icon() {
    local state_dir icon_file registry_file
    state_dir=$(get_spinner_state_dir)
    icon_file="${state_dir}/session-icon.${TTY_SAFE:-unknown}"
    registry_file="${state_dir}/session-icon-registry"

    rm -f "$icon_file" 2>/dev/null

    # Remove from registry (atomic)
    if [[ -f "$registry_file" ]]; then
        local tmp_file="${registry_file}.tmp.$$"
        grep -v "^${TTY_SAFE}=" "$registry_file" > "$tmp_file" 2>/dev/null
        mv "$tmp_file" "$registry_file" 2>/dev/null
    fi

    [[ "$DEBUG_ALL" == "1" ]] && echo "[TAVS] Session icon released (TTY=$TTY_SAFE)" >&2
}

# ==============================================================================
# INTERNAL FUNCTIONS
# ==============================================================================

# Remove stale registry entries (TTY devices that no longer exist)
_cleanup_stale_icons() {
    local state_dir registry_file
    state_dir=$(get_spinner_state_dir)
    registry_file="${state_dir}/session-icon-registry"

    [[ ! -f "$registry_file" ]] && return 0

    local tmp_file="${registry_file}.tmp.$$"
    local tty_key tty_icon tty_dev
    while IFS='=' read -r tty_key tty_icon; do
        [[ -z "$tty_key" || "$tty_key" =~ ^[#] ]] && continue
        # Convert TTY_SAFE back to device path: _dev_ttys001 -> /dev/ttys001
        tty_dev="${tty_key//_//}"
        if [[ -e "$tty_dev" ]]; then
            printf '%s=%s\n' "$tty_key" "$tty_icon" >> "$tmp_file"
        else
            # Also clean up per-TTY icon file for dead session
            rm -f "${state_dir}/session-icon.${tty_key}" 2>/dev/null
            [[ "$DEBUG_ALL" == "1" ]] && echo "[TAVS] Cleaned stale icon: $tty_key=$tty_icon" >&2
        fi
    done < "$registry_file"

    if [[ -f "$tmp_file" ]]; then
        mv "$tmp_file" "$registry_file" 2>/dev/null
    else
        # All entries were stale
        rm -f "$registry_file" 2>/dev/null
    fi
}

# Add entry to cross-session registry (atomic)
_register_icon() {
    local icon="$1"
    local state_dir registry_file
    state_dir=$(get_spinner_state_dir)
    registry_file="${state_dir}/session-icon-registry"

    local tmp_file="${registry_file}.tmp.$$"
    {
        # Keep existing entries (minus our TTY if already there)
        grep -v "^${TTY_SAFE}=" "$registry_file" 2>/dev/null
        printf '%s=%s\n' "$TTY_SAFE" "$icon"
    } > "$tmp_file" 2>/dev/null
    mv "$tmp_file" "$registry_file" 2>/dev/null
}
