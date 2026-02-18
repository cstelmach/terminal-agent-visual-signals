#!/bin/bash
# ==============================================================================
# TAVS CLI — Setting Alias System
# ==============================================================================
# Maps friendly CLI names to actual config variable names.
# Provides validation, descriptions, and compound alias handling.
#
# Bash 3.2+ compatible — uses case statements instead of associative arrays.
#
# Usage:
#   source aliases.sh
#   resolve_alias "theme"          # → "COMPOUND:THEME_PRESET+THEME_MODE"
#   resolve_alias "faces"          # → "ENABLE_ANTHROPOMORPHISING"
#   validate_value "THEME_MODE" "preset"  # → 0 (success)
# ==============================================================================

# ==============================================================================
# ALIAS RESOLUTION
# ==============================================================================

# Resolve an alias or variable name to its target variable(s)
# Returns: variable name, or "COMPOUND:VAR1+VAR2" for compound aliases
# Exit code: 0 on success, 1 if unknown
resolve_alias() {
    local key="$1"

    case "$key" in
        # Core Settings
        theme)              echo "COMPOUND:THEME_PRESET+THEME_MODE"; return 0 ;;
        mode)               echo "THEME_MODE"; return 0 ;;
        light-dark)         echo "ENABLE_LIGHT_DARK_SWITCHING"; return 0 ;;
        force-mode)         echo "FORCE_MODE"; return 0 ;;

        # Visual Features
        faces)              echo "ENABLE_ANTHROPOMORPHISING"; return 0 ;;
        face-mode)          echo "TAVS_FACE_MODE"; return 0 ;;
        face-position)      echo "FACE_POSITION"; return 0 ;;
        compact-theme)      echo "TAVS_COMPACT_THEME"; return 0 ;;
        backgrounds)        echo "ENABLE_STYLISH_BACKGROUNDS"; return 0 ;;
        palette)            echo "ENABLE_PALETTE_THEMING"; return 0 ;;

        # Title System
        title-mode)         echo "TAVS_TITLE_MODE"; return 0 ;;
        title-fallback)     echo "TAVS_TITLE_FALLBACK"; return 0 ;;
        title-format)       echo "TAVS_TITLE_FORMAT"; return 0 ;;
        session-icons)      echo "ENABLE_SESSION_ICONS"; return 0 ;;
        agents-format)      echo "TAVS_AGENTS_FORMAT"; return 0 ;;

        # Identity System
        identity-mode)      echo "TAVS_IDENTITY_MODE"; return 0 ;;
        identity-persistence) echo "TAVS_IDENTITY_PERSISTENCE"; return 0 ;;
        dir-icon-type)      echo "TAVS_DIR_ICON_TYPE"; return 0 ;;

        # Spinner (when title-mode=full)
        spinner)            echo "TAVS_SPINNER_STYLE"; return 0 ;;
        eye-mode)           echo "TAVS_SPINNER_EYE_MODE"; return 0 ;;
        session-identity)   echo "TAVS_SESSION_IDENTITY"; return 0 ;;

        # Advanced
        mode-aware)         echo "ENABLE_MODE_AWARE_PROCESSING"; return 0 ;;
        truecolor-override) echo "TRUECOLOR_MODE_OVERRIDE"; return 0 ;;
        bell-permission)    echo "ENABLE_BELL_PERMISSION"; return 0 ;;
        bell-complete)      echo "ENABLE_BELL_COMPLETE"; return 0 ;;
        debug)              echo "DEBUG_ALL"; return 0 ;;
    esac

    # Check if it's a raw variable name we know about
    case "$key" in
        THEME_MODE|THEME_PRESET|ENABLE_LIGHT_DARK_SWITCHING|FORCE_MODE|\
        ENABLE_ANTHROPOMORPHISING|TAVS_FACE_MODE|FACE_POSITION|\
        TAVS_COMPACT_THEME|ENABLE_STYLISH_BACKGROUNDS|ENABLE_PALETTE_THEMING|\
        TAVS_TITLE_MODE|TAVS_TITLE_FALLBACK|TAVS_TITLE_FORMAT|\
        ENABLE_SESSION_ICONS|TAVS_AGENTS_FORMAT|\
        TAVS_IDENTITY_MODE|TAVS_IDENTITY_PERSISTENCE|TAVS_DIR_ICON_TYPE|\
        TAVS_SPINNER_STYLE|TAVS_SPINNER_EYE_MODE|TAVS_SESSION_IDENTITY|\
        ENABLE_MODE_AWARE_PROCESSING|TRUECOLOR_MODE_OVERRIDE|\
        ENABLE_BELL_PERMISSION|ENABLE_BELL_COMPLETE|DEBUG_ALL)
            echo "$key"
            return 0
            ;;
    esac

    # Accept raw variable names: must be valid shell identifiers starting with
    # a letter or underscore, containing only uppercase letters, digits, and
    # underscores. Rejects names like "1BAD" and shell metacharacters.
    if [[ -n "$key" && "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "$key"
        return 0
    fi

    return 1
}

# Check if an alias is a compound alias
is_compound_alias() {
    local resolved="$1"
    case "$resolved" in
        COMPOUND:*) return 0 ;;
        *)          return 1 ;;
    esac
}

# ==============================================================================
# VALID VALUES
# ==============================================================================

# Get valid values for a variable (space-separated string)
# Returns empty string for free-form variables (no validation)
get_valid_values() {
    local var="$1"

    case "$var" in
        THEME_MODE)
            echo "static dynamic preset" ;;
        THEME_PRESET)
            echo "catppuccin-frappe catppuccin-latte catppuccin-macchiato catppuccin-mocha nord dracula solarized-dark solarized-light tokyo-night" ;;
        ENABLE_LIGHT_DARK_SWITCHING|ENABLE_ANTHROPOMORPHISING|\
        ENABLE_STYLISH_BACKGROUNDS|ENABLE_SESSION_ICONS|\
        TAVS_SESSION_IDENTITY|ENABLE_MODE_AWARE_PROCESSING|\
        ENABLE_BELL_PERMISSION|ENABLE_BELL_COMPLETE)
            echo "true false" ;;
        FORCE_MODE)
            echo "auto dark light" ;;
        TAVS_FACE_MODE)
            echo "standard compact" ;;
        FACE_POSITION)
            echo "before after" ;;
        TAVS_COMPACT_THEME)
            echo "semantic circles squares mixed" ;;
        ENABLE_PALETTE_THEMING)
            echo "false auto true" ;;
        TAVS_TITLE_MODE)
            echo "skip-processing prefix-only full off" ;;
        TAVS_TITLE_FALLBACK)
            echo "path session-path path-session session" ;;
        TAVS_IDENTITY_MODE)
            echo "dual single off" ;;
        TAVS_IDENTITY_PERSISTENCE)
            echo "ephemeral persistent" ;;
        TAVS_DIR_ICON_TYPE)
            echo "flags plants buildings" ;;
        TAVS_SPINNER_STYLE)
            echo "braille circle block eye-animate none random" ;;
        TAVS_SPINNER_EYE_MODE)
            echo "sync opposite stagger clockwise counter mirror mirror_inv random" ;;
        TRUECOLOR_MODE_OVERRIDE)
            echo "off muted full" ;;
        DEBUG_ALL)
            echo "0 1" ;;
        *)
            # Free-form values (TAVS_TITLE_FORMAT, TAVS_AGENTS_FORMAT, etc.)
            echo "" ;;
    esac
}

# Validate a value for a variable
# Returns: 0 if valid, 1 if invalid
validate_value() {
    local var="$1"
    local value="$2"

    local valid_values
    valid_values=$(get_valid_values "$var")

    # If no validation list, accept any value
    [[ -z "$valid_values" ]] && return 0

    # Check if value is in the valid list
    local v
    for v in $valid_values; do
        [[ "$value" == "$v" ]] && return 0
    done

    return 1
}

# ==============================================================================
# DESCRIPTIONS
# ==============================================================================

# Get description for a setting alias
get_description() {
    local key="$1"

    case "$key" in
        theme)              echo "Color theme preset (nord, dracula, catppuccin-*, etc.)" ;;
        mode)               echo "Operating mode (static, dynamic, or preset)" ;;
        light-dark)         echo "Auto-detect system light/dark mode" ;;
        force-mode)         echo "Force light or dark mode (auto, dark, light)" ;;
        faces)              echo "Enable ASCII faces in titles" ;;
        face-mode)          echo "Face display mode (standard or compact emoji)" ;;
        face-position)      echo "Face position in title (before or after)" ;;
        compact-theme)      echo "Compact face theme (semantic, circles, squares, mixed)" ;;
        backgrounds)        echo "Enable stylish background images (iTerm2/Kitty)" ;;
        palette)            echo "Terminal palette theming (false, auto, true)" ;;
        title-mode)         echo "Title control mode (skip-processing, prefix-only, full, off)" ;;
        title-fallback)     echo "Fallback when no user title (path, session-path, etc.)" ;;
        title-format)       echo "Title composition template ({FACE} {STATUS_ICON} etc.)" ;;
        session-icons)      echo "Unique animal emoji per terminal tab" ;;
        agents-format)      echo "Subagent count format in title ({N} = count)" ;;
        identity-mode)      echo "Identity system mode (dual, single, off)" ;;
        identity-persistence) echo "Identity registry storage (ephemeral, persistent)" ;;
        dir-icon-type)      echo "Directory icon pool (flags, plants, buildings)" ;;
        spinner)            echo "Processing spinner style (braille, circle, random, etc.)" ;;
        eye-mode)           echo "Spinner eye sync mode (sync, opposite, mirror, etc.)" ;;
        session-identity)   echo "Consistent visual identity per session" ;;
        mode-aware)         echo "Permission mode-aware processing colors" ;;
        truecolor-override) echo "TrueColor terminal behavior (off, muted, full)" ;;
        bell-permission)    echo "Bell sound on permission requests" ;;
        bell-complete)      echo "Bell sound on task completion" ;;
        debug)              echo "Debug logging (0 or 1)" ;;
        *)                  echo "No description available" ;;
    esac
}

# ==============================================================================
# LISTING
# ==============================================================================

# List all available aliases (sorted)
list_aliases() {
    cat <<'EOF'
agents-format
backgrounds
bell-complete
bell-permission
compact-theme
debug
dir-icon-type
eye-mode
face-mode
face-position
faces
force-mode
identity-mode
identity-persistence
light-dark
mode
mode-aware
palette
session-icons
session-identity
spinner
theme
title-fallback
title-format
title-mode
truecolor-override
EOF
}

# List aliases with descriptions (for help output)
list_aliases_with_descriptions() {
    local alias_name
    while IFS= read -r alias_name; do
        printf "  %-20s %s\n" "$alias_name" "$(get_description "$alias_name")"
    done <<< "$(list_aliases)"
}
