#!/bin/bash
# ==============================================================================
# TAVS CLI — Setting Alias System
# ==============================================================================
# Maps friendly CLI names to actual config variable names.
# Provides validation, descriptions, and compound alias handling.
#
# Usage:
#   source aliases.sh
#   resolve_alias "theme"          # → "COMPOUND:THEME_PRESET+THEME_MODE"
#   resolve_alias "faces"          # → "ENABLE_ANTHROPOMORPHISING"
#   validate_value "THEME_MODE" "preset"  # → 0 (success)
# ==============================================================================

# Requires bash 4+ for associative arrays
if (( BASH_VERSINFO[0] < 4 )); then
    echo "Error: TAVS CLI requires bash 4.0 or later." >&2
    echo "Current version: ${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

# ==============================================================================
# ALIAS DEFINITIONS
# ==============================================================================
# Format: alias → variable name
# Compound aliases use "COMPOUND:VAR1+VAR2" format

declare -A SETTING_ALIASES=(
    # Core Settings
    ["theme"]="COMPOUND:THEME_PRESET+THEME_MODE"
    ["mode"]="THEME_MODE"
    ["light-dark"]="ENABLE_LIGHT_DARK_SWITCHING"
    ["force-mode"]="FORCE_MODE"

    # Visual Features
    ["faces"]="ENABLE_ANTHROPOMORPHISING"
    ["face-mode"]="TAVS_FACE_MODE"
    ["face-position"]="FACE_POSITION"
    ["compact-theme"]="TAVS_COMPACT_THEME"
    ["backgrounds"]="ENABLE_STYLISH_BACKGROUNDS"
    ["palette"]="ENABLE_PALETTE_THEMING"

    # Title System
    ["title-mode"]="TAVS_TITLE_MODE"
    ["title-fallback"]="TAVS_TITLE_FALLBACK"
    ["title-format"]="TAVS_TITLE_FORMAT"
    ["session-icons"]="ENABLE_SESSION_ICONS"
    ["agents-format"]="TAVS_AGENTS_FORMAT"

    # Spinner (when title-mode=full)
    ["spinner"]="TAVS_SPINNER_STYLE"
    ["eye-mode"]="TAVS_SPINNER_EYE_MODE"
    ["session-identity"]="TAVS_SESSION_IDENTITY"

    # Advanced
    ["mode-aware"]="ENABLE_MODE_AWARE_PROCESSING"
    ["truecolor-override"]="TRUECOLOR_MODE_OVERRIDE"
    ["bell-permission"]="ENABLE_BELL_PERMISSION"
    ["bell-complete"]="ENABLE_BELL_COMPLETE"
    ["debug"]="DEBUG_ALL"
)

# ==============================================================================
# VALID VALUES PER VARIABLE
# ==============================================================================
# Space-separated list of valid values. Empty = any value accepted.

declare -A SETTING_VALUES=(
    ["THEME_MODE"]="static dynamic preset"
    ["THEME_PRESET"]="catppuccin-frappe catppuccin-latte catppuccin-macchiato catppuccin-mocha nord dracula solarized-dark solarized-light tokyo-night"
    ["ENABLE_LIGHT_DARK_SWITCHING"]="true false"
    ["FORCE_MODE"]="auto dark light"
    ["ENABLE_ANTHROPOMORPHISING"]="true false"
    ["TAVS_FACE_MODE"]="standard compact"
    ["FACE_POSITION"]="before after"
    ["TAVS_COMPACT_THEME"]="semantic circles squares mixed"
    ["ENABLE_STYLISH_BACKGROUNDS"]="true false"
    ["ENABLE_PALETTE_THEMING"]="false auto true"
    ["TAVS_TITLE_MODE"]="skip-processing prefix-only full off"
    ["TAVS_TITLE_FALLBACK"]="path session-path path-session session"
    ["ENABLE_SESSION_ICONS"]="true false"
    ["TAVS_SPINNER_STYLE"]="braille circle block eye-animate none random"
    ["TAVS_SPINNER_EYE_MODE"]="sync opposite stagger clockwise counter mirror mirror_inv random"
    ["TAVS_SESSION_IDENTITY"]="true false"
    ["ENABLE_MODE_AWARE_PROCESSING"]="true false"
    ["TRUECOLOR_MODE_OVERRIDE"]="off muted full"
    ["ENABLE_BELL_PERMISSION"]="true false"
    ["ENABLE_BELL_COMPLETE"]="true false"
    ["DEBUG_ALL"]="0 1"
    # Free-form values (no validation): TAVS_TITLE_FORMAT, TAVS_AGENTS_FORMAT
)

# ==============================================================================
# FRIENDLY DESCRIPTIONS
# ==============================================================================

declare -A SETTING_DESCRIPTIONS=(
    ["theme"]="Color theme preset (nord, dracula, catppuccin-*, etc.)"
    ["mode"]="Operating mode (static, dynamic, or preset)"
    ["light-dark"]="Auto-detect system light/dark mode"
    ["force-mode"]="Force light or dark mode (auto, dark, light)"
    ["faces"]="Enable ASCII faces in titles"
    ["face-mode"]="Face display mode (standard or compact emoji)"
    ["face-position"]="Face position in title (before or after)"
    ["compact-theme"]="Compact face theme (semantic, circles, squares, mixed)"
    ["backgrounds"]="Enable stylish background images (iTerm2/Kitty)"
    ["palette"]="Terminal palette theming (false, auto, true)"
    ["title-mode"]="Title control mode (skip-processing, prefix-only, full, off)"
    ["title-fallback"]="Fallback when no user title (path, session-path, etc.)"
    ["title-format"]="Title composition template ({FACE} {STATUS_ICON} etc.)"
    ["session-icons"]="Unique animal emoji per terminal tab"
    ["agents-format"]="Subagent count format in title ({N} = count)"
    ["spinner"]="Processing spinner style (braille, circle, random, etc.)"
    ["eye-mode"]="Spinner eye sync mode (sync, opposite, mirror, etc.)"
    ["session-identity"]="Consistent visual identity per session"
    ["mode-aware"]="Permission mode-aware processing colors"
    ["truecolor-override"]="TrueColor terminal behavior (off, muted, full)"
    ["bell-permission"]="Bell sound on permission requests"
    ["bell-complete"]="Bell sound on task completion"
    ["debug"]="Debug logging (0 or 1)"
)

# ==============================================================================
# ALIAS RESOLUTION
# ==============================================================================

# Resolve an alias or variable name to its target variable(s)
# Returns: variable name, or "COMPOUND:VAR1+VAR2" for compound aliases
# Exit code: 0 on success, 1 if unknown
resolve_alias() {
    local key="$1"

    # Check if it's a known alias
    if [[ -n "${SETTING_ALIASES[$key]+x}" ]]; then
        echo "${SETTING_ALIASES[$key]}"
        return 0
    fi

    # Check if it's already a raw variable name (in our validation set)
    if [[ -n "${SETTING_VALUES[$key]+x}" ]]; then
        echo "$key"
        return 0
    fi

    # Check if it looks like a valid config variable (UPPER_CASE with underscores)
    if [[ "$key" =~ ^[A-Z_]+$ ]]; then
        echo "$key"
        return 0
    fi

    return 1
}

# Check if an alias is a compound alias
is_compound_alias() {
    local resolved="$1"
    [[ "$resolved" == COMPOUND:* ]]
}

# ==============================================================================
# VALIDATION
# ==============================================================================

# Validate a value for a variable
# Returns: 0 if valid, 1 if invalid
validate_value() {
    local var="$1"
    local value="$2"

    # Get valid values for this variable
    local _valid_default=""
    local valid_values="${SETTING_VALUES[$var]:-$_valid_default}"

    # If no validation list, accept any value
    [[ -z "$valid_values" ]] && return 0

    # Check if value is in the valid list
    local v
    for v in $valid_values; do
        [[ "$value" == "$v" ]] && return 0
    done

    return 1
}

# Get valid values for a variable (space-separated string)
get_valid_values() {
    local var="$1"
    local _default=""
    echo "${SETTING_VALUES[$var]:-$_default}"
}

# ==============================================================================
# DESCRIPTION & LISTING
# ==============================================================================

# Get description for a setting alias
get_description() {
    local key="$1"
    local _default="No description available"
    echo "${SETTING_DESCRIPTIONS[$key]:-$_default}"
}

# List all available aliases (sorted)
list_aliases() {
    printf "%s\n" "${!SETTING_ALIASES[@]}" | sort
}

# List aliases with descriptions (for help output)
list_aliases_with_descriptions() {
    local alias
    for alias in $(list_aliases); do
        printf "  %-20s %s\n" "$alias" "$(get_description "$alias")"
    done
}
