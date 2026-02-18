#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Session Icon Module
# ==============================================================================
# Assigns a unique animal emoji per terminal session for visual identification.
#
# In identity system v2 (TAVS_IDENTITY_MODE = "dual" or "single"):
#   - Icons are deterministic per session_id (same session = same animal)
#   - Round-robin assignment cycles through ~77 animals before repeating
#   - 2-icon collision overflow when active sessions share a primary icon
#   - Registry persists mappings across session restarts
#
# In legacy mode (TAVS_IDENTITY_MODE = "off"):
#   - Random per-TTY assignment from 25 animals (exact v1 behavior preserved)
#   - Duplicate avoidance via cross-session registry
#
# Public functions (signatures preserved from v1):
#   assign_session_icon()   - Assign icon (idempotent, mode-aware)
#   get_session_icon()      - Return current session's icon(s)
#   release_session_icon()  - Release on session end
#
# Internal functions:
#   _get_session_key()           - Session key: TAVS_SESSION_ID[:8] or TTY_SAFE
#   _detect_legacy_icon_file()   - Detect v1 single-emoji cache format
#   _legacy_random_assign()      - Exact v1 random behavior (IDENTITY_MODE=off)
#   _legacy_cleanup_stale()      - v1 stale TTY cleanup
#   _legacy_register()           - v1 cross-session registry
#
# Per-TTY cache format (v2, structured KV):
#   session_key=abc123de
#   primary=🦊
#   secondary=🐙
#   collision_active=false
#
# v1 legacy cache format (single emoji, no delimiter):
#   🦊
#
# State files:
#   ~/.cache/tavs/session-icon.{TTY_SAFE}  - Per-TTY cache (v1 or v2 format)
#   ~/.cache/tavs/session-icon-registry     - Legacy cross-session registry (v1 only)
#   {registry_dir}/session-registry         - Identity registry (v2 only)
#   {registry_dir}/session-counter          - Round-robin counter (v2 only)
#   {registry_dir}/active-sessions          - Active collision index (v2 only)
#
# Dependencies:
#   - identity-registry.sh for _round_robin_next_locked, _registry_*,
#     _active_sessions_* (loaded by trigger.sh when identity mode is active)
#   - get_spinner_state_dir() from spinner.sh
#   - TTY_SAFE, TAVS_SESSION_ID, TAVS_IDENTITY_MODE
#   - TAVS_SESSION_ICON_POOL (77 animals), TAVS_SESSION_ICONS (25, legacy)
# ==============================================================================

# ==============================================================================
# SESSION KEY RESOLUTION
# ==============================================================================

# Get the session key used for identity registry lookups.
# Claude Code: first 8 chars of TAVS_SESSION_ID (from hook JSON)
# Non-Claude agents: TTY_SAFE as fallback (per Decision D11)
_get_session_key() {
    if [[ -n "${TAVS_SESSION_ID:-}" ]]; then
        printf '%s' "${TAVS_SESSION_ID:0:8}"
    else
        printf '%s' "${TTY_SAFE:-unknown}"
    fi
}

# ==============================================================================
# LEGACY FORMAT DETECTION
# ==============================================================================

# Detect v1 single-emoji cache files (no '=' delimiter).
# Returns: 0 if legacy format detected, 1 if v2 format or file doesn't exist
_detect_legacy_icon_file() {
    local icon_file="$1"
    [[ ! -f "$icon_file" ]] && return 1
    local first_line
    read -r first_line < "$icon_file" 2>/dev/null || return 1
    # Legacy v1 format: single emoji with no '=' delimiter
    [[ "$first_line" != *"="* ]] && return 0
    return 1
}

# ==============================================================================
# LEGACY MODE FUNCTIONS (exact v1 behavior for TAVS_IDENTITY_MODE=off)
# ==============================================================================

# Remove stale legacy registry entries (TTY devices that no longer exist)
_legacy_cleanup_stale() {
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
            [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Cleaned stale legacy icon: $tty_key=$tty_icon" >&2
        fi
    done < "$registry_file"

    if [[ -f "$tmp_file" ]]; then
        mv "$tmp_file" "$registry_file" 2>/dev/null
    else
        # All entries were stale
        rm -f "$registry_file" 2>/dev/null
    fi
}

# Add entry to legacy cross-session registry (atomic)
_legacy_register() {
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

# Legacy random assignment — exact v1 behavior.
# Uses TAVS_SESSION_ICONS (25 animals), random selection, dedup via registry.
_legacy_random_assign() {
    local state_dir icon_file registry_file
    state_dir=$(get_spinner_state_dir)
    icon_file="${state_dir}/session-icon.${TTY_SAFE:-unknown}"
    registry_file="${state_dir}/session-icon-registry"

    # Idempotent: if icon already assigned for this TTY, keep it
    if [[ -f "$icon_file" ]]; then
        return 0
    fi

    # Clean up stale entries from dead TTYs
    _legacy_cleanup_stale

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

    # Persist per-TTY (atomic write) — v1 format: single emoji
    local tmp_file="${icon_file}.tmp.$$"
    printf '%s\n' "$selected" > "$tmp_file" 2>/dev/null
    mv "$tmp_file" "$icon_file" 2>/dev/null

    # Register in cross-session registry
    _legacy_register "$selected"

    [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Legacy session icon assigned: $selected (TTY=$TTY_SAFE)" >&2
}

# ==============================================================================
# PUBLIC FUNCTIONS
# ==============================================================================

# Assign a session icon (idempotent, mode-aware).
# In dual/single mode: deterministic per session_id via round-robin registry.
# In off mode: legacy random per-TTY behavior.
assign_session_icon() {
    local state_dir icon_file
    state_dir=$(get_spinner_state_dir)
    icon_file="${state_dir}/session-icon.${TTY_SAFE:-unknown}"

    # --- Legacy mode: exact v1 behavior ---
    # Zsh compat: intermediate var for brace default
    local _default_mode="dual"
    local identity_mode="${TAVS_IDENTITY_MODE:-$_default_mode}"

    if [[ "$identity_mode" == "off" ]]; then
        # Detect and remove v2 format files (user switched from v2 back to off)
        if [[ -f "$icon_file" ]] && ! _detect_legacy_icon_file "$icon_file"; then
            rm -f "$icon_file" 2>/dev/null
        fi
        _legacy_random_assign
        return $?
    fi

    # --- v2 Identity mode (dual or single) ---

    # Step 0: Detect and remove legacy v1 format files
    if _detect_legacy_icon_file "$icon_file"; then
        rm -f "$icon_file" 2>/dev/null
        [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Removed legacy session icon file" >&2
    fi

    # Step 1: Get session key
    local session_key
    session_key=$(_get_session_key)

    # Step 2: Check per-TTY cache for idempotency
    # If key matches, we still re-check collision status (may have cleared
    # since another session ended). Per spec: collision re-evaluated at
    # SessionStart and UserPromptSubmit.
    if [[ -f "$icon_file" ]]; then
        local cached_key="" cached_primary="" cached_secondary="" cached_collision=""
        while IFS='=' read -r k v; do
            [[ -z "$k" || "$k" =~ ^[#] ]] && continue
            case "$k" in
                session_key) cached_key="$v" ;;
                primary) cached_primary="$v" ;;
                secondary) cached_secondary="$v" ;;
                collision_active) cached_collision="$v" ;;
            esac
        done < "$icon_file"

        if [[ "$cached_key" == "$session_key" && -n "$cached_primary" ]]; then
            # Key matches — re-check collision status
            local collision_now=false
            if type _active_sessions_check_collision &>/dev/null && \
               _active_sessions_check_collision "$cached_primary" "$session_key"; then
                collision_now=true
            fi

            # If collision status changed, update cache
            if [[ "$collision_now" != "$cached_collision" ]]; then
                local secondary_now="$cached_secondary"
                # Need a new secondary for a newly detected collision
                if [[ "$collision_now" == "true" && -z "$secondary_now" ]]; then
                    if type _round_robin_next_locked &>/dev/null; then
                        secondary_now=$(_round_robin_next_locked "session" "TAVS_SESSION_ICON_POOL")
                    fi
                    # Update registry with secondary
                    if [[ -n "$secondary_now" ]] && type _registry_store &>/dev/null; then
                        _registry_store "session" "$session_key" "$cached_primary" "$secondary_now"
                    fi
                fi

                # Rewrite cache with updated collision status
                local tmp_file
                tmp_file=$(mktemp "${icon_file}.XXXXXX" 2>/dev/null) || tmp_file="${icon_file}.tmp.$$"
                {
                    printf 'session_key=%s\n' "$session_key"
                    printf 'primary=%s\n' "$cached_primary"
                    printf 'secondary=%s\n' "${secondary_now:-}"
                    printf 'collision_active=%s\n' "$collision_now"
                } > "$tmp_file"
                mv "$tmp_file" "$icon_file" 2>/dev/null
            fi

            # Ensure active-sessions index is current (may be stale after reboot)
            if type _active_sessions_update &>/dev/null; then
                _active_sessions_update "${TTY_SAFE:-unknown}" "$session_key" "$cached_primary"
            fi

            return 0
        fi

        # Key mismatch — session_id changed; remove stale cache
        rm -f "$icon_file" 2>/dev/null
    fi

    # Step 3: Clean up stale data
    if type _active_sessions_cleanup_stale &>/dev/null; then
        _active_sessions_cleanup_stale
    fi
    # TTL cleanup: remove expired registry entries (prevents unbounded growth)
    local _default_ttl=2592000
    local ttl="${TAVS_IDENTITY_REGISTRY_TTL:-$_default_ttl}"
    if type _registry_cleanup_expired &>/dev/null; then
        _registry_cleanup_expired "session" "$ttl"
    fi

    # Step 4: Registry lookup for this session key
    local primary="" secondary=""
    if type _registry_lookup &>/dev/null; then
        local reg_result
        reg_result=$(_registry_lookup "session" "$session_key")
        if [[ -n "$reg_result" ]]; then
            # Parse: primary|secondary|timestamp
            primary="${reg_result%%|*}"
            local rest="${reg_result#*|}"
            secondary="${rest%%|*}"
            # timestamp discarded (last field)
        fi
    fi

    # Step 5: If not in registry, assign via round-robin
    if [[ -z "$primary" ]]; then
        if type _round_robin_next_locked &>/dev/null; then
            primary=$(_round_robin_next_locked "session" "TAVS_SESSION_ICON_POOL")
        fi
        if [[ -z "$primary" ]]; then
            # Fallback: hash-based selection (lock timeout backstop)
            local hash_val
            hash_val=$(printf '%s' "$session_key" | cksum | cut -d' ' -f1)
            local pool_size="${#TAVS_SESSION_ICON_POOL[@]}"
            [[ $pool_size -eq 0 ]] && pool_size=1
            primary="${TAVS_SESSION_ICON_POOL[$((hash_val % pool_size))]}"
        fi
        # Store in registry (secondary empty for now)
        if type _registry_store &>/dev/null; then
            _registry_store "session" "$session_key" "$primary" ""
        fi
    fi

    # Step 6: Check for active collision
    local collision_active=false
    if type _active_sessions_check_collision &>/dev/null && \
       _active_sessions_check_collision "$primary" "$session_key"; then
        collision_active=true
        # Assign secondary if not already stored in registry
        if [[ -z "$secondary" ]]; then
            if type _round_robin_next_locked &>/dev/null; then
                secondary=$(_round_robin_next_locked "session" "TAVS_SESSION_ICON_POOL")
            fi
            # Update registry with secondary
            if [[ -n "$secondary" ]] && type _registry_store &>/dev/null; then
                _registry_store "session" "$session_key" "$primary" "$secondary"
            fi
        fi
    fi

    # Step 7: Write per-TTY cache (v2 structured KV format, atomic)
    local tmp_file
    tmp_file=$(mktemp "${icon_file}.XXXXXX" 2>/dev/null) || tmp_file="${icon_file}.tmp.$$"
    {
        printf 'session_key=%s\n' "$session_key"
        printf 'primary=%s\n' "$primary"
        printf 'secondary=%s\n' "${secondary:-}"
        printf 'collision_active=%s\n' "$collision_active"
    } > "$tmp_file"
    mv "$tmp_file" "$icon_file" 2>/dev/null

    # Step 8: Update active-sessions index
    if type _active_sessions_update &>/dev/null; then
        _active_sessions_update "${TTY_SAFE:-unknown}" "$session_key" "$primary"
    fi

    [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Session icon assigned: $primary (key=$session_key, collision=$collision_active)" >&2
}

# Get this session's icon(s). Empty if none assigned or disabled.
# Returns: single icon, or "primary secondary" pair if collision active.
get_session_icon() {
    local state_dir icon_file
    state_dir=$(get_spinner_state_dir)
    icon_file="${state_dir}/session-icon.${TTY_SAFE:-unknown}"

    [[ ! -f "$icon_file" ]] && return 0

    # Detect format: v1 (single emoji) vs v2 (structured KV)
    local first_line
    read -r first_line < "$icon_file" 2>/dev/null || return 0

    if [[ "$first_line" != *"="* ]]; then
        # v1 legacy format: single emoji on first line
        printf '%s' "$first_line"
        return 0
    fi

    # v2 format: parse structured KV
    local primary="" secondary="" collision_active=""
    while IFS='=' read -r k v; do
        [[ -z "$k" || "$k" =~ ^[#] ]] && continue
        case "$k" in
            primary) primary="$v" ;;
            secondary) secondary="$v" ;;
            collision_active) collision_active="$v" ;;
        esac
    done < "$icon_file"

    if [[ "$collision_active" == "true" && -n "$secondary" ]]; then
        printf '%s %s' "$primary" "$secondary"
    else
        printf '%s' "$primary"
    fi
}

# Release this session's icon. Removes per-TTY cache and active-sessions entry.
# Does NOT remove registry mapping (session keeps its assigned icon for reuse).
release_session_icon() {
    local state_dir icon_file
    state_dir=$(get_spinner_state_dir)
    icon_file="${state_dir}/session-icon.${TTY_SAFE:-unknown}"

    # If legacy format, also clean up the legacy registry
    if _detect_legacy_icon_file "$icon_file" 2>/dev/null; then
        local registry_file="${state_dir}/session-icon-registry"
        if [[ -f "$registry_file" ]]; then
            local tmp_file="${registry_file}.tmp.$$"
            grep -v "^${TTY_SAFE:-unknown}=" "$registry_file" > "$tmp_file" 2>/dev/null
            mv "$tmp_file" "$registry_file" 2>/dev/null
        fi
    fi

    rm -f "$icon_file" 2>/dev/null

    # Remove from active-sessions index (v2 mode)
    if type _active_sessions_remove &>/dev/null; then
        _active_sessions_remove "${TTY_SAFE:-unknown}"
    fi

    [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Session icon released (TTY=${TTY_SAFE:-unknown})" >&2
}
