#!/bin/bash
# ==============================================================================
# TAVS CLI — Shared Utilities
# ==============================================================================
# Common functions used by all tavs subcommands.
# Sourced by each cmd-*.sh file.
# ==============================================================================

# Resolve TAVS_ROOT if not already set (for direct sourcing)
_cli_utils_default_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TAVS_ROOT="${TAVS_ROOT:-$_cli_utils_default_root}"

# User config paths
TAVS_USER_CONFIG_DIR="$HOME/.tavs"
TAVS_USER_CONFIG="$TAVS_USER_CONFIG_DIR/user.conf"

# ==============================================================================
# OUTPUT HELPERS
# ==============================================================================

# ANSI color codes
_CLR_RED='\033[0;31m'
_CLR_GREEN='\033[0;32m'
_CLR_YELLOW='\033[0;33m'
_CLR_BLUE='\033[0;34m'
_CLR_CYAN='\033[0;36m'
_CLR_MAGENTA='\033[0;35m'
_CLR_BOLD='\033[1m'
_CLR_DIM='\033[2m'
_CLR_RESET='\033[0m'

cli_error() {
    echo -e "${_CLR_RED}Error: $*${_CLR_RESET}" >&2
}

cli_success() {
    echo -e "${_CLR_GREEN}$*${_CLR_RESET}"
}

cli_info() {
    echo -e "${_CLR_DIM}$*${_CLR_RESET}"
}

cli_warn() {
    echo -e "${_CLR_YELLOW}Warning: $*${_CLR_RESET}"
}

cli_bold() {
    echo -e "${_CLR_BOLD}$*${_CLR_RESET}"
}

# Print a section header
cli_section() {
    echo ""
    echo -e "${_CLR_BOLD}${_CLR_CYAN}$*${_CLR_RESET}"
    echo -e "${_CLR_DIM}$(printf '─%.0s' $(seq 1 50))${_CLR_RESET}"
}

# ==============================================================================
# CONFIGURATION MANAGEMENT
# ==============================================================================

# Load current user configuration (sources user.conf if it exists)
load_user_config() {
    if [[ -f "$TAVS_USER_CONFIG" ]]; then
        # shellcheck source=/dev/null
        source "$TAVS_USER_CONFIG"
        return 0
    fi
    return 1
}

# Load full config chain (defaults + user + theme)
load_full_config() {
    local _agent_default="claude"
    local agent="${1:-$_agent_default}"
    if [[ -f "$TAVS_ROOT/src/core/theme-config-loader.sh" ]]; then
        export TAVS_AGENT="$agent"
        source "$TAVS_ROOT/src/core/theme-config-loader.sh"
        load_agent_config "$agent"
    fi
}

# Get current value of a config variable
get_config_value() {
    local var="$1"
    # Load defaults first, then user overrides
    if [[ -f "$TAVS_ROOT/src/config/defaults.conf" ]]; then
        source "$TAVS_ROOT/src/config/defaults.conf"
    fi
    load_user_config 2>/dev/null || true
    eval echo "\${${var}:-}"
}

# Set a config value in user.conf
# Uses sed for in-place update if variable exists, appends otherwise.
set_config_value() {
    local var="$1"
    local value="$2"

    # Ensure config directory exists
    mkdir -p "$TAVS_USER_CONFIG_DIR"

    # If user.conf doesn't exist, create from template
    if [[ ! -f "$TAVS_USER_CONFIG" ]]; then
        if [[ -f "$TAVS_ROOT/src/config/user.conf.template" ]]; then
            cp "$TAVS_ROOT/src/config/user.conf.template" "$TAVS_USER_CONFIG"
        else
            # Minimal fallback header
            cat > "$TAVS_USER_CONFIG" << 'HEADER'
#!/bin/bash
# ==============================================================================
# TAVS - User Configuration (v3)
# ==============================================================================
# Quick config: Run 'tavs set <key> <value>' to change settings
# Full wizard:  Run 'tavs wizard' for interactive setup
# See current:  Run 'tavs status' to see active configuration
# ==============================================================================

HEADER
        fi
    fi

    # Determine the value format (arrays need different handling)
    local value_str
    if [[ "$value" == "("* ]]; then
        # Array value — write as-is
        value_str="${var}=${value}"
    else
        # Scalar value — quote it
        value_str="${var}=\"${value}\""
    fi

    # Check if variable exists in file (commented or uncommented)
    if grep -q "^#\?[[:space:]]*${var}=" "$TAVS_USER_CONFIG" 2>/dev/null; then
        # Update existing line (first occurrence only)
        # Use temp file + mv for safety on macOS (no -i '' portability issues)
        local tmp
        tmp=$(mktemp)
        local found=false
        while IFS= read -r line; do
            if [[ "$found" == "false" ]] && [[ "$line" =~ ^#?[[:space:]]*${var}= ]]; then
                echo "$value_str"
                found=true
            else
                echo "$line"
            fi
        done < "$TAVS_USER_CONFIG" > "$tmp"
        mv "$tmp" "$TAVS_USER_CONFIG"
    else
        # Append to end of file
        echo "" >> "$TAVS_USER_CONFIG"
        echo "$value_str" >> "$TAVS_USER_CONFIG"
    fi
}

# Ensure user config exists (create from template if missing)
ensure_user_config() {
    if [[ ! -f "$TAVS_USER_CONFIG" ]]; then
        mkdir -p "$TAVS_USER_CONFIG_DIR"
        if [[ -f "$TAVS_ROOT/src/config/user.conf.template" ]]; then
            cp "$TAVS_ROOT/src/config/user.conf.template" "$TAVS_USER_CONFIG"
            cli_info "Created user configuration: $TAVS_USER_CONFIG"
        fi
    fi
}

# Count active (uncommented, non-empty) settings in user.conf
count_active_settings() {
    if [[ ! -f "$TAVS_USER_CONFIG" ]]; then
        echo "0"
        return
    fi
    grep -c '^[^#[:space:]].*=' "$TAVS_USER_CONFIG" 2>/dev/null || echo "0"
}

# ==============================================================================
# INTERACTIVE HELPERS
# ==============================================================================

# Interactive picker — uses fzf if available, falls back to select
interactive_pick() {
    local prompt="$1"
    shift
    local options=("$@")

    # Try fzf first (better UX)
    if command -v fzf &>/dev/null; then
        printf "%s\n" "${options[@]}" | fzf --prompt="$prompt> " --height=40% --reverse
        return $?
    fi

    # Fallback to numbered selection
    echo "$prompt" >&2
    echo "" >&2
    local i=1
    for opt in "${options[@]}"; do
        echo "  ${i}) ${opt}" >&2
        ((i++))
    done
    echo "" >&2

    local choice
    while true; do
        read -rp "  Select [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            echo "${options[$((choice - 1))]}"
            return 0
        fi
        echo "  Invalid choice. Please enter a number from 1 to ${#options[@]}." >&2
    done
}

# Simple yes/no confirmation
cli_confirm() {
    local prompt="${1:-Continue?}"
    local response
    read -rp "  $prompt [y/N] " response
    [[ "$response" =~ ^[yY] ]]
}

# ==============================================================================
# COLOR RENDERING HELPERS
# ==============================================================================

# Render a color swatch using 24-bit ANSI escape
# Usage: render_swatch "#3d3b42"
render_swatch() {
    local hex="$1"
    # Strip leading #
    hex="${hex#\#}"

    # Parse RGB
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    # Print colored block
    printf "\033[48;2;%d;%d;%dm    \033[0m" "$r" "$g" "$b"
}

# Render a color swatch with label
# Usage: render_color_line "Processing" "#3d3b42"
render_color_line() {
    local label="$1"
    local hex="$2"
    printf "    %-14s %s  %s\n" "$label" "$(render_swatch "$hex")" "$hex"
}
