#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Configure Wizard Utilities
# ==============================================================================
# Shared utilities for the configuration wizard:
#   - Terminal color definitions
#   - Configuration state variables
#   - Input/output helper functions
#
# Sourced by configure.sh and all configure-step-*.sh modules.
# ==============================================================================

# === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# === CONFIGURATION STATE ===
# These variables are set by the step modules and read by save_configuration()
SELECTED_MODE="static"
SELECTED_PRESET=""
SELECTED_LIGHT_DARK_SWITCHING="false"
SELECTED_FORCE_MODE="auto"
SELECTED_AGENT=""
SELECTED_FACE_ENABLED="false"
SELECTED_FACE_THEME="minimal"
SELECTED_FACE_POSITION="before"
SELECTED_STYLISH_ENABLED="false"
SELECTED_STYLISH_DIR=""
SELECTED_PALETTE_MODE="false"
SELECTED_CREATE_ALIAS="false"
# Title Mode and Spinner
SELECTED_TITLE_MODE="skip-processing"
SELECTED_TITLE_FALLBACK="path"
SELECTED_SPINNER_STYLE="random"
SELECTED_SPINNER_EYE_MODE="random"
SELECTED_SESSION_IDENTITY="true"

# === HELPER FUNCTIONS ===

print_header() {
    clear
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║               TAVS - Configuration Wizard                      ║${NC}"
    echo -e "${BOLD}${CYAN}║                     Dynamic Theming System                     ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

print_info() {
    echo -e "  ${DIM}$1${NC}"
}

read_choice() {
    local prompt="$1"
    local default="$2"
    local result

    # Prompt goes to stderr so it's not captured by $()
    if [[ -n "$default" ]]; then
        echo -ne "${GREEN}$prompt [${default}]: ${NC}" >&2
    else
        echo -ne "${GREEN}$prompt: ${NC}" >&2
    fi
    read -r result
    # Sanitize input: remove control chars and trim whitespace
    result="${result//$'\r'/}"                        # Remove CR (CRLF terminals)
    result="${result//$'\t'/ }"                       # Tabs to spaces
    while [[ "$result" == " "* ]]; do result="${result# }"; done   # Trim leading
    while [[ "$result" == *" " ]]; do result="${result% }"; done   # Trim trailing
    echo "${result:-$default}"
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local result

    echo -ne "${GREEN}$prompt [Y/n]: ${NC}"
    read -r result
    # Sanitize input: remove control chars and trim whitespace
    result="${result//$'\r'/}"                        # Remove CR (CRLF terminals)
    result="${result//$'\t'/ }"                       # Tabs to spaces
    while [[ "$result" == " "* ]]; do result="${result# }"; done   # Trim leading
    while [[ "$result" == *" " ]]; do result="${result% }"; done   # Trim trailing
    [[ "${result:-$default}" =~ ^[Yy] ]]
}
