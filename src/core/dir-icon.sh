#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Directory Icon Module
# ==============================================================================
# Deterministic directory→flag mapping with worktree awareness.
# Maps working directories to flag emoji using round-robin assignment
# via the shared identity registry.
#
# Public functions:
#   assign_dir_icon()   - Assign icon based on TAVS_CWD or $PWD (idempotent)
#   get_dir_icon()      - Return current directory icon(s) from per-TTY cache
#   release_dir_icon()  - Remove per-TTY cache on session end
#
# Internal functions:
#   _git_with_timeout()           - Platform-aware git command with 1s timeout
#   _detect_worktree(cwd)         - Detect git worktree → "main_path\twt_path"
#   _resolve_dir_identity(cwd)    - Resolve path via cwd or git-root mode
#   _select_dir_pool()            - Select icon pool by TAVS_DIR_ICON_TYPE
#   _get_worktree_pool(main_pool) - Get alternate pool for worktree dirs
#   _hash_path(path)              - Stable numeric hash via cksum
#   _assign_icon_for_path(path, pool_name) - Registry lookup → round-robin
#
# Per-TTY cache format (dir-icon.{TTY_SAFE}):
#   cwd=/original/path/used
#   dir_path=/resolved/or/main/repo/path
#   dir_hash=1234567890
#   primary=🇩🇪
#   worktree_path=/path/to/worktree        (optional)
#   worktree_hash=9876543210               (optional)
#   worktree_icon=🇯🇵                      (optional)
#
# Dependencies:
#   - identity-registry.sh (_round_robin_next_locked, _registry_lookup, _registry_store)
#   - get_spinner_state_dir() from spinner.sh (per-TTY cache directory)
#   - TTY_SAFE environment variable
#   - TAVS_DIR_ICON_POOL, TAVS_DIR_FALLBACK_POOL_A/B from defaults.conf
#   - TAVS_DIR_IDENTITY_SOURCE, TAVS_DIR_WORKTREE_DETECTION from defaults.conf
# ==============================================================================

# ==============================================================================
# GIT HELPERS
# ==============================================================================

# Platform-aware git command with 1-second timeout.
# macOS lacks `timeout` by default; tries timeout → gtimeout → bare git.
# All stderr suppressed to prevent hook output pollution.
_git_with_timeout() {
    if command -v timeout &>/dev/null; then
        timeout 1 git "$@" 2>/dev/null
    elif command -v gtimeout &>/dev/null; then
        gtimeout 1 git "$@" 2>/dev/null
    else
        git "$@" 2>/dev/null
    fi
}

# Detect if a directory is inside a git worktree.
# Uses subshell to protect caller's cwd.
#
# Args: cwd - directory to check
# Output: "main_repo_path\tworktree_path" on stdout if worktree detected (tab-delimited)
# Returns: 0 if worktree, 1 if not (or git unavailable)
_detect_worktree() {
    local cwd="$1"

    # Guard: git must be installed
    command -v git &>/dev/null || return 1

    # Guard: worktree detection must be enabled
    [[ "${TAVS_DIR_WORKTREE_DETECTION:-true}" != "true" ]] && return 1

    # Subshell protects caller's working directory
    (
        cd "$cwd" || return 1

        # Fast-fail for non-git directories
        _git_with_timeout rev-parse --is-inside-work-tree &>/dev/null || return 1

        local toplevel common_dir main_repo
        toplevel=$(_git_with_timeout rev-parse --show-toplevel) || return 1
        common_dir=$(_git_with_timeout rev-parse --git-common-dir) || return 1

        # Normalize common_dir to absolute path
        [[ "$common_dir" != /* ]] && common_dir="${toplevel}/${common_dir}"
        common_dir=$(cd "$common_dir" 2>/dev/null && pwd) || return 1

        # Strip /.git suffix to get main repo path
        main_repo="${common_dir%/.git}"

        if [[ "$main_repo" != "$toplevel" ]]; then
            # We're in a worktree: toplevel is the worktree dir
            # Tab delimiter: can't appear in filesystem paths (unlike spaces)
            printf '%s\t%s' "$main_repo" "$toplevel"
            return 0
        fi

        return 1  # Not a worktree (or is the main repo itself)
    )
}

# ==============================================================================
# PATH RESOLUTION
# ==============================================================================

# Resolve directory identity based on TAVS_DIR_IDENTITY_SOURCE config.
#   "cwd" mode (default): return path as-is
#   "git-root" mode: normalize to git repository root
#
# Args: cwd - directory path to resolve
# Output: resolved path on stdout
_resolve_dir_identity() {
    local cwd="$1"

    # Zsh compat: intermediate var for brace default
    local _default_source="cwd"
    local source="${TAVS_DIR_IDENTITY_SOURCE:-$_default_source}"

    case "$source" in
        git-root)
            # Normalize to git repo root (groups subdirectories together)
            if command -v git &>/dev/null; then
                local git_root
                git_root=$(cd "$cwd" 2>/dev/null && _git_with_timeout rev-parse --show-toplevel)
                if [[ -n "$git_root" ]]; then
                    printf '%s' "$git_root"
                    return 0
                fi
            fi
            # Fallback to cwd if not in a git repo
            printf '%s' "$cwd"
            ;;
        cwd|*)
            printf '%s' "$cwd"
            ;;
    esac
}

# Generate a stable numeric hash for a path using cksum.
# Output: hash value (numeric string, no newline)
_hash_path() {
    printf '%s' "$1" | cksum | cut -d' ' -f1
}

# ==============================================================================
# POOL SELECTION
# ==============================================================================

# Select the main directory icon pool based on TAVS_DIR_ICON_TYPE config.
# Returns: pool array variable name (for use with eval in round-robin)
_select_dir_pool() {
    # Zsh compat: intermediate var for brace default
    local _default_type="flags"
    local icon_type="${DIR_ICON_TYPE:-${TAVS_DIR_ICON_TYPE:-$_default_type}}"

    case "$icon_type" in
        plants)    printf '%s' "TAVS_DIR_FALLBACK_POOL_A" ;;
        buildings) printf '%s' "TAVS_DIR_FALLBACK_POOL_B" ;;
        auto)
            # Future: auto-detect terminal flag rendering capability.
            # For now, default to flags.
            printf '%s' "TAVS_DIR_ICON_POOL"
            ;;
        flags|*)
            printf '%s' "TAVS_DIR_ICON_POOL"
            ;;
    esac
}

# Get the alternate pool for worktree directories.
# When using flags: both main and worktree use the same pool
#   (different flags assigned via round-robin's different hash keys)
# When using fallback pools: worktree gets the alternate pool
#   for visual distinction (Decision D07)
#
# Args: main_pool - the pool variable name used for the main directory
# Returns: pool variable name for the worktree
_get_worktree_pool() {
    local main_pool="$1"

    case "$main_pool" in
        TAVS_DIR_FALLBACK_POOL_A) printf '%s' "TAVS_DIR_FALLBACK_POOL_B" ;;
        TAVS_DIR_FALLBACK_POOL_B) printf '%s' "TAVS_DIR_FALLBACK_POOL_A" ;;
        # Flags: use same pool (round-robin ensures different icons)
        *) printf '%s' "$main_pool" ;;
    esac
}

# ==============================================================================
# ICON ASSIGNMENT HELPER
# ==============================================================================

# Assign an icon for a single path using the specified pool.
# Checks registry first (deterministic); round-robin if not found.
#
# Args: path - directory path, pool_name - pool array variable name
# Output: assigned icon on stdout
_assign_icon_for_path() {
    local path="$1"
    local pool_name="$2"

    local path_hash
    path_hash=$(_hash_path "$path")

    # Check registry for existing mapping
    local existing
    existing=$(_registry_lookup "dir" "$path_hash")

    if [[ -n "$existing" ]]; then
        # Extract primary icon (format: primary||timestamp or primary|secondary|timestamp)
        local primary="${existing%%|*}"
        printf '%s' "$primary"
        return 0
    fi

    # Not found: assign via round-robin
    local icon
    icon=$(_round_robin_next_locked "dir" "$pool_name")

    if [[ -z "$icon" ]]; then
        # Lock timeout fallback: deterministic hash-based selection
        local pool_size
        eval "pool_size=\${#${pool_name}[@]}"
        if [[ $pool_size -gt 0 ]]; then
            local idx=$((path_hash % pool_size))
            eval "icon=\${${pool_name}[$idx]}"
        fi
    fi

    if [[ -n "$icon" ]]; then
        _registry_store "dir" "$path_hash" "$icon"
        printf '%s' "$icon"
    fi
}

# ==============================================================================
# PUBLIC FUNCTIONS
# ==============================================================================

# Assign a directory icon based on TAVS_CWD or $PWD.
# Idempotent: returns immediately if cache already matches the current cwd.
# Handles worktree detection and fallback pool selection.
assign_dir_icon() {
    # Get current working directory
    local cwd="${TAVS_CWD:-$PWD}"
    [[ -z "$cwd" ]] && return 0

    local state_dir
    state_dir=$(get_spinner_state_dir)
    local cache_file="${state_dir}/dir-icon.${TTY_SAFE:-unknown}"

    # Idempotent: check if cache matches the same raw cwd
    if [[ -f "$cache_file" ]]; then
        local cached_cwd=""
        while IFS='=' read -r k v; do
            [[ "$k" == "cwd" ]] && cached_cwd="$v"
        done < "$cache_file"

        if [[ "$cached_cwd" == "$cwd" ]]; then
            [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Dir icon cache hit: $cwd" >&2
            return 0
        fi
    fi

    # TTL cleanup: remove expired dir registry entries (prevents unbounded growth)
    local _default_ttl=2592000
    local ttl="${TAVS_IDENTITY_REGISTRY_TTL:-$_default_ttl}"
    if type _registry_cleanup_expired &>/dev/null; then
        _registry_cleanup_expired "dir" "$ttl"
    fi

    # Resolve directory identity (cwd or git-root mode)
    local resolved_path
    resolved_path=$(_resolve_dir_identity "$cwd")
    [[ -z "$resolved_path" ]] && resolved_path="$cwd"

    # Select pool for main directory
    local main_pool
    main_pool=$(_select_dir_pool)

    # Check for worktree before assigning
    local worktree_info main_repo_path wt_toplevel
    local worktree_path="" worktree_hash="" worktree_icon=""
    local dir_path="" main_hash="" main_icon=""

    worktree_info=$(_detect_worktree "$cwd" 2>/dev/null)

    if [[ -n "$worktree_info" ]]; then
        # We're in a worktree — split on tab delimiter (safe for paths with spaces)
        main_repo_path="${worktree_info%%	*}"
        wt_toplevel="${worktree_info#*	}"

        # Main repo gets its icon from the main pool
        dir_path="$main_repo_path"
        main_hash=$(_hash_path "$main_repo_path")
        main_icon=$(_assign_icon_for_path "$main_repo_path" "$main_pool")

        # Worktree gets its icon from the worktree pool (alternate for fallbacks)
        local wt_pool
        wt_pool=$(_get_worktree_pool "$main_pool")
        worktree_path="$wt_toplevel"
        worktree_hash=$(_hash_path "$wt_toplevel")
        worktree_icon=$(_assign_icon_for_path "$wt_toplevel" "$wt_pool")
    else
        # Not a worktree: use resolved path directly
        dir_path="$resolved_path"
        main_hash=$(_hash_path "$resolved_path")
        main_icon=$(_assign_icon_for_path "$resolved_path" "$main_pool")
    fi

    [[ -z "$main_icon" ]] && return 1

    # Write per-TTY cache (atomic: mktemp + mv)
    local tmp_cache
    tmp_cache=$(mktemp "${cache_file}.XXXXXX" 2>/dev/null) || tmp_cache="${cache_file}.tmp.$$"
    {
        printf 'cwd=%s\n' "$cwd"
        printf 'dir_path=%s\n' "$dir_path"
        printf 'dir_hash=%s\n' "$main_hash"
        printf 'primary=%s\n' "$main_icon"
        if [[ -n "$worktree_path" ]]; then
            printf 'worktree_path=%s\n' "$worktree_path"
            printf 'worktree_hash=%s\n' "$worktree_hash"
            printf 'worktree_icon=%s\n' "$worktree_icon"
        fi
    } > "$tmp_cache"
    mv "$tmp_cache" "$cache_file" 2>/dev/null

    [[ "${DEBUG_ALL:-0}" == "1" ]] && \
        echo "[TAVS] Dir icon assigned: $main_icon (dir=$dir_path, cwd=$cwd, TTY=$TTY_SAFE)" >&2
}

# Get this session's directory icon (empty if none assigned).
# Returns: single flag, or "main_flag→worktree_flag" for worktrees (Decision D06)
get_dir_icon() {
    local state_dir
    state_dir=$(get_spinner_state_dir)
    local cache_file="${state_dir}/dir-icon.${TTY_SAFE:-unknown}"

    [[ ! -f "$cache_file" ]] && return 0

    local primary="" worktree_icon=""
    while IFS='=' read -r k v; do
        case "$k" in
            primary)       primary="$v" ;;
            worktree_icon) worktree_icon="$v" ;;
        esac
    done < "$cache_file"

    if [[ -n "$worktree_icon" && -n "$primary" ]]; then
        # Worktree: show main→worktree (Decision D06: arrow separator)
        printf '%s' "${primary}→${worktree_icon}"
    elif [[ -n "$primary" ]]; then
        printf '%s' "$primary"
    fi
}

# Release this session's directory icon cache.
# Called on SessionEnd to clean up per-TTY state.
# Does NOT remove from registry (mapping persists for determinism).
release_dir_icon() {
    local state_dir
    state_dir=$(get_spinner_state_dir)
    local cache_file="${state_dir}/dir-icon.${TTY_SAFE:-unknown}"

    rm -f "$cache_file" 2>/dev/null

    [[ "${DEBUG_ALL:-0}" == "1" ]] && echo "[TAVS] Dir icon released (TTY=$TTY_SAFE)" >&2
}
