#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Identity Registry Module
# ==============================================================================
# Shared registry foundation for deterministic icon assignment.
# Used by both session-icon.sh and dir-icon.sh.
#
# Features:
#   - Round-robin counter with mkdir-based locking (TOCTOU-safe)
#   - Key->icon registry with TTL-based cleanup
#   - Active-sessions index for O(1) collision detection
#   - Persistence routing (ephemeral /tmp vs persistent ~/.cache)
#
# Functions (underscore-prefixed — internal module API):
#   _get_registry_dir()               - Storage path based on persistence mode
#   _acquire_lock(lock_dir)           - Acquire mkdir-based filesystem lock
#   _release_lock(lock_dir)           - Release filesystem lock
#   _round_robin_next_locked(type, pool_array_name) - Next icon from pool
#   _registry_lookup(type, key)       - Look up key in registry
#   _registry_store(type, key, primary, [secondary]) - Store mapping
#   _registry_remove(type, key)       - Remove mapping
#   _active_sessions_update(tty_safe, session_key, primary_icon) - Update index
#   _active_sessions_remove(tty_safe) - Remove from index
#   _active_sessions_check_collision(primary_icon, session_key) - Check collision
#   _active_sessions_cleanup_stale()  - Remove dead TTY entries
#   _registry_cleanup_expired(type, ttl_seconds) - TTL-based cleanup
#
# Registry file formats:
#   {type}-registry:  key=primary|secondary|timestamp
#   {type}-counter:   single integer (next pool index)
#   active-sessions:  tty_safe=session_key|primary_icon
#
# Locking strategy:
#   .lock-{type}    - Protects counter and registry read-modify-write
#   .lock-active    - Protects active-sessions index modifications
#
# Dependencies:
#   - get_spinner_state_dir() from spinner.sh (for persistent mode)
#   - TAVS_IDENTITY_PERSISTENCE from defaults.conf
#   - TTY_SAFE for stale TTY detection
# ==============================================================================

# ==============================================================================
# PERSISTENCE ROUTING
# ==============================================================================

# Get the registry storage directory based on persistence mode.
# Ephemeral: /tmp/tavs-identity/ (cleared on reboot)
# Persistent: ~/.cache/tavs/ (survives reboots)
_get_registry_dir() {
    local dir
    # Zsh compat: intermediate var for brace default
    local _default_persistence="ephemeral"
    local persistence="${TAVS_IDENTITY_PERSISTENCE:-$_default_persistence}"

    case "$persistence" in
        persistent)
            # Use secure cache dir (same as spinner state)
            dir=$(get_spinner_state_dir)
            ;;
        ephemeral|*)
            dir="/tmp/tavs-identity"
            ;;
    esac

    # Guard: never operate on empty/root paths
    [[ -z "$dir" ]] && dir="/tmp/tavs-identity"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null
        chmod 700 "$dir" 2>/dev/null
    fi

    printf '%s' "$dir"
}

# ==============================================================================
# FILESYSTEM LOCKING
# ==============================================================================
# mkdir is atomic on POSIX — used as a cross-process lock.
# No external dependencies (no flock, no lockfile).

# Acquire a mkdir-based lock. Spin-waits up to 2 seconds.
# Writes PID to lock_dir/pid for stale lock detection.
# Returns: 0 on success, 1 on timeout
_acquire_lock() {
    local lock_dir="$1"
    local max_attempts=40  # 40 * 0.05s = 2 seconds
    local attempts=0

    while ! mkdir "$lock_dir" 2>/dev/null; do
        # Check for stale lock: if lock holder PID is dead, recover
        local lock_pid=""
        [[ -f "$lock_dir/pid" ]] && read -r lock_pid < "$lock_dir/pid" 2>/dev/null
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
            # Lock holder is dead — force remove and retry immediately
            rm -rf "$lock_dir" 2>/dev/null
            [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Recovered stale lock: $lock_dir (pid=$lock_pid)" >&2
            continue
        fi

        sleep 0.05
        attempts=$((attempts + 1))
        if [[ $attempts -ge $max_attempts ]]; then
            [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Lock timeout: $lock_dir" >&2
            return 1
        fi
    done
    # Record our PID for stale detection by others
    echo $$ > "$lock_dir/pid" 2>/dev/null
    return 0
}

# Release a mkdir-based lock (removes PID file and lock dir).
_release_lock() {
    rm -f "$1/pid" 2>/dev/null
    rmdir "$1" 2>/dev/null
}

# ==============================================================================
# ROUND-ROBIN COUNTER
# ==============================================================================

# Get the next icon from a pool using locked round-robin.
# Sequential assignment: cycles through entire pool before repeating.
#
# Args: type (e.g. "session", "dir"), pool_array_name (e.g. "TAVS_SESSION_ICON_POOL")
# Output: selected icon (printf, no newline), or empty on failure
# Returns: 0 on success, 1 on lock timeout or empty pool
_round_robin_next_locked() {
    local type="$1"
    local pool_array_name="$2"

    local reg_dir
    reg_dir=$(_get_registry_dir)
    local lock_dir="${reg_dir}/.lock-${type}"
    local counter_file="${reg_dir}/${type}-counter"

    # Get pool size via eval (works in both bash and zsh)
    local pool_size
    eval "pool_size=\${#${pool_array_name}[@]}"
    [[ $pool_size -eq 0 ]] && return 1

    # Acquire lock — serializes counter read-modify-write
    if ! _acquire_lock "$lock_dir"; then
        # Lock timeout: return empty. Collision overflow backstop handles this.
        return 1
    fi

    # Read current counter (default 0)
    local counter=0
    if [[ -f "$counter_file" ]]; then
        read -r counter < "$counter_file" 2>/dev/null || counter=0
        # Sanitize: must be non-negative integer
        [[ "$counter" =~ ^[0-9]+$ ]] || counter=0
    fi

    # Select icon: pool[counter % pool_size]
    local idx=$((counter % pool_size))
    local selected
    eval "selected=\${${pool_array_name}[$idx]}"

    # Increment counter with wrap
    local next_counter=$(( (counter + 1) % pool_size ))

    # Write counter atomically (mktemp + mv on same filesystem)
    local tmp_counter
    tmp_counter=$(mktemp "${counter_file}.XXXXXX" 2>/dev/null) || tmp_counter="${counter_file}.tmp.$$"
    printf '%s\n' "$next_counter" > "$tmp_counter"
    mv "$tmp_counter" "$counter_file" 2>/dev/null

    # Release lock
    _release_lock "$lock_dir"

    printf '%s' "$selected"
}

# ==============================================================================
# REGISTRY CRUD
# ==============================================================================
# Registry format: key=primary|secondary|timestamp
# Session registry: key is session_key (first 8 chars of session_id or TTY_SAFE)
# Dir registry: key is path_hash (cksum output)
# Locked via .lock-{type} to serialize concurrent read-modify-write

# Look up a key in the registry.
# Output: "primary|secondary|timestamp" or empty
_registry_lookup() {
    local type="$1"
    local key="$2"

    local reg_dir
    reg_dir=$(_get_registry_dir)
    local registry_file="${reg_dir}/${type}-registry"

    [[ ! -f "$registry_file" ]] && return 0

    # Safe KV parsing — never source state files
    local k v
    while IFS='=' read -r k v; do
        [[ -z "$k" || "$k" =~ ^[#] ]] && continue
        if [[ "$k" == "$key" ]]; then
            printf '%s' "$v"
            return 0
        fi
    done < "$registry_file"
}

# Store a key->icon mapping in the registry (atomic write).
# Preserves existing entries for other keys.
_registry_store() {
    local type="$1"
    local key="$2"
    local primary="$3"
    local secondary="${4:-}"

    local reg_dir
    reg_dir=$(_get_registry_dir)
    local registry_file="${reg_dir}/${type}-registry"
    local lock_dir="${reg_dir}/.lock-${type}"

    local timestamp
    timestamp=$(date +%s 2>/dev/null || printf '%s' "0")

    local entry="${primary}|${secondary}|${timestamp}"

    # Lock: serialize concurrent read-modify-write on same registry
    _acquire_lock "$lock_dir" || return 1

    # Atomic write: filter out old entry, append new
    local tmp_file
    tmp_file=$(mktemp "${registry_file}.XXXXXX" 2>/dev/null) || tmp_file="${registry_file}.tmp.$$"
    {
        # Preserve entries for other keys
        if [[ -f "$registry_file" ]]; then
            local k v
            while IFS='=' read -r k v; do
                [[ -z "$k" || "$k" =~ ^[#] ]] && continue
                [[ "$k" == "$key" ]] && continue
                printf '%s=%s\n' "$k" "$v"
            done < "$registry_file"
        fi
        # Add new/updated entry
        printf '%s=%s\n' "$key" "$entry"
    } > "$tmp_file"
    mv "$tmp_file" "$registry_file" 2>/dev/null

    _release_lock "$lock_dir"
}

# Remove a key from the registry (atomic write).
_registry_remove() {
    local type="$1"
    local key="$2"

    local reg_dir
    reg_dir=$(_get_registry_dir)
    local registry_file="${reg_dir}/${type}-registry"
    local lock_dir="${reg_dir}/.lock-${type}"

    [[ ! -f "$registry_file" ]] && return 0

    # Lock: serialize concurrent read-modify-write on same registry
    _acquire_lock "$lock_dir" || return 0

    local tmp_file
    tmp_file=$(mktemp "${registry_file}.XXXXXX" 2>/dev/null) || tmp_file="${registry_file}.tmp.$$"
    {
        local k v
        while IFS='=' read -r k v; do
            [[ -z "$k" || "$k" =~ ^[#] ]] && continue
            [[ "$k" == "$key" ]] && continue
            printf '%s=%s\n' "$k" "$v"
        done < "$registry_file"
    } > "$tmp_file"
    mv "$tmp_file" "$registry_file" 2>/dev/null

    _release_lock "$lock_dir"
}

# ==============================================================================
# ACTIVE-SESSIONS INDEX
# ==============================================================================
# Single file tracking all currently active sessions for O(1) collision check.
# Format: tty_safe=session_key|primary_icon
# Locked with .lock-active to protect concurrent modifications.

# Add or update an entry in the active-sessions index.
_active_sessions_update() {
    local tty_safe="$1"
    local session_key="$2"
    local primary_icon="$3"

    local reg_dir
    reg_dir=$(_get_registry_dir)
    local index_file="${reg_dir}/active-sessions"
    local lock_dir="${reg_dir}/.lock-active"

    _acquire_lock "$lock_dir" || return 1

    local entry="${session_key}|${primary_icon}"
    local tmp_file
    tmp_file=$(mktemp "${index_file}.XXXXXX" 2>/dev/null) || tmp_file="${index_file}.tmp.$$"
    {
        # Preserve entries for other TTYs
        if [[ -f "$index_file" ]]; then
            local k v
            while IFS='=' read -r k v; do
                [[ -z "$k" || "$k" =~ ^[#] ]] && continue
                [[ "$k" == "$tty_safe" ]] && continue
                printf '%s=%s\n' "$k" "$v"
            done < "$index_file"
        fi
        # Add/update our entry
        printf '%s=%s\n' "$tty_safe" "$entry"
    } > "$tmp_file"
    mv "$tmp_file" "$index_file" 2>/dev/null

    _release_lock "$lock_dir"
}

# Remove an entry from the active-sessions index.
_active_sessions_remove() {
    local tty_safe="$1"

    local reg_dir
    reg_dir=$(_get_registry_dir)
    local index_file="${reg_dir}/active-sessions"
    local lock_dir="${reg_dir}/.lock-active"

    [[ ! -f "$index_file" ]] && return 0

    _acquire_lock "$lock_dir" || return 0

    local tmp_file
    tmp_file=$(mktemp "${index_file}.XXXXXX" 2>/dev/null) || tmp_file="${index_file}.tmp.$$"
    {
        local k v
        while IFS='=' read -r k v; do
            [[ -z "$k" || "$k" =~ ^[#] ]] && continue
            [[ "$k" == "$tty_safe" ]] && continue
            printf '%s=%s\n' "$k" "$v"
        done < "$index_file"
    } > "$tmp_file"
    mv "$tmp_file" "$index_file" 2>/dev/null

    _release_lock "$lock_dir"
}

# Check if a primary icon collides with another ACTIVE session.
# Returns: 0 if collision found (same icon, different session_key), 1 if unique
# Read-only — no lock needed.
_active_sessions_check_collision() {
    local primary_icon="$1"
    local session_key="$2"

    local reg_dir
    reg_dir=$(_get_registry_dir)
    local index_file="${reg_dir}/active-sessions"

    [[ ! -f "$index_file" ]] && return 1  # No collision

    # Scan for same icon from a different session key
    local k v entry_key entry_icon
    while IFS='=' read -r k v; do
        [[ -z "$k" || "$k" =~ ^[#] ]] && continue
        # Parse value: session_key|primary_icon
        entry_key="${v%%|*}"
        entry_icon="${v#*|}"
        if [[ "$entry_icon" == "$primary_icon" && "$entry_key" != "$session_key" ]]; then
            return 0  # Collision found
        fi
    done < "$index_file"

    return 1  # No collision
}

# Remove entries for dead TTYs from the active-sessions index.
# Checks if TTY device still exists (same pattern as session-icon.sh).
_active_sessions_cleanup_stale() {
    local reg_dir
    reg_dir=$(_get_registry_dir)
    local index_file="${reg_dir}/active-sessions"
    local lock_dir="${reg_dir}/.lock-active"

    [[ ! -f "$index_file" ]] && return 0

    _acquire_lock "$lock_dir" || return 0

    local tmp_file
    tmp_file=$(mktemp "${index_file}.XXXXXX" 2>/dev/null) || tmp_file="${index_file}.tmp.$$"
    local has_entries=false

    local k v tty_dev
    {
        while IFS='=' read -r k v; do
            [[ -z "$k" || "$k" =~ ^[#] ]] && continue
            # Convert TTY_SAFE back to device path: _dev_ttys001 -> /dev/ttys001
            tty_dev="${k//_//}"
            if [[ -e "$tty_dev" ]]; then
                printf '%s=%s\n' "$k" "$v"
                has_entries=true
            else
                [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Cleaned stale active session: $k" >&2
            fi
        done < "$index_file"
    } > "$tmp_file"

    if [[ "$has_entries" == "true" ]]; then
        mv "$tmp_file" "$index_file" 2>/dev/null
    else
        rm -f "$tmp_file" "$index_file" 2>/dev/null
    fi

    _release_lock "$lock_dir"
}

# ==============================================================================
# TTL CLEANUP
# ==============================================================================

# Remove expired entries from a registry based on TTL.
# An entry is expired when (now - timestamp) > ttl_seconds.
_registry_cleanup_expired() {
    local type="$1"
    local ttl_seconds="$2"

    local reg_dir
    reg_dir=$(_get_registry_dir)
    local registry_file="${reg_dir}/${type}-registry"
    local lock_dir="${reg_dir}/.lock-${type}"

    [[ ! -f "$registry_file" ]] && return 0

    local now
    now=$(date +%s 2>/dev/null) || return 0

    # Lock: serialize with concurrent store/remove on same registry
    _acquire_lock "$lock_dir" || return 0

    local tmp_file
    tmp_file=$(mktemp "${registry_file}.XXXXXX" 2>/dev/null) || tmp_file="${registry_file}.tmp.$$"
    local has_entries=false

    local k v timestamp
    while IFS='=' read -r k v; do
        [[ -z "$k" || "$k" =~ ^[#] ]] && continue
        # Timestamp is the last field after |
        timestamp="${v##*|}"
        if [[ "$timestamp" =~ ^[0-9]+$ ]] && [[ $((now - timestamp)) -le $ttl_seconds ]]; then
            printf '%s=%s\n' "$k" "$v" >> "$tmp_file"
            has_entries=true
        else
            [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Expired registry entry: ${type}/${k}" >&2
        fi
    done < "$registry_file"

    if [[ "$has_entries" == "true" ]]; then
        mv "$tmp_file" "$registry_file" 2>/dev/null
    else
        rm -f "$tmp_file" "$registry_file" 2>/dev/null
    fi

    _release_lock "$lock_dir"
}
