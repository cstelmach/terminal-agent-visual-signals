#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Configuration Wizard
# ==============================================================================
# Interactive configuration for:
#   - Operating mode (static, dynamic, preset)
#   - Theme preset selection
#   - Light/dark mode auto-detection
#   - Agent-specific settings
#   - Anthropomorphising (ASCII faces)
#
# Creates user configuration in ~/.config/terminal-visual-signals/user.conf
# ==============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/terminal-visual-signals"
USER_CONFIG="$CONFIG_DIR/user.conf"

# Source required modules
source "$SCRIPT_DIR/src/core/themes.sh"
source "$SCRIPT_DIR/src/core/theme.sh"

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
SELECTED_MODE="static"
SELECTED_PRESET=""
SELECTED_AUTO_DARK="false"
SELECTED_AGENT=""
SELECTED_FACE_ENABLED="false"
SELECTED_FACE_THEME="minimal"
SELECTED_FACE_POSITION="before"

# === HELPER FUNCTIONS ===

print_header() {
    clear
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║         Terminal Agent Visual Signals - Configuration          ║${NC}"
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

    if [[ -n "$default" ]]; then
        echo -ne "${GREEN}$prompt [${default}]: ${NC}"
    else
        echo -ne "${GREEN}$prompt: ${NC}"
    fi
    read -r result
    echo "${result:-$default}"
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local result

    echo -ne "${GREEN}$prompt [Y/n]: ${NC}"
    read -r result
    [[ "${result:-$default}" =~ ^[Yy] ]]
}

# === STEP 1: OPERATING MODE ===

select_operating_mode() {
    print_section "Step 1: Operating Mode"

    echo "  How should terminal background colors be determined?"
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Static${NC} ${DIM}(Recommended)${NC}"
    print_info "Use preconfigured colors from agent defaults or theme preset."
    print_info "Fastest, most predictable. Works everywhere."
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Dynamic${NC}"
    print_info "Query your terminal's background color at session start."
    print_info "Calculate state colors by hue-shifting your base color."
    print_info "Colors adapt to your terminal aesthetic."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Theme Preset${NC}"
    print_info "Use a named color theme (Nord, Dracula, Solarized, etc.)."
    print_info "Consistent look with popular color schemes."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select mode [1-3]" "1")

        case "$choice" in
            1) SELECTED_MODE="static"; valid=true ;;
            2) SELECTED_MODE="dynamic"; valid=true ;;
            3) SELECTED_MODE="preset"; valid=true ;;
            *) echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}" ;;
        esac
    done

    echo ""
    echo -e "  ${GREEN}Selected: ${BOLD}$SELECTED_MODE${NC}"
}

# === STEP 2: THEME PRESET (if mode=preset) ===

select_theme_preset() {
    [[ "$SELECTED_MODE" != "preset" ]] && return

    print_section "Step 2: Theme Preset"

    echo "  Select a color theme:"
    echo ""

    # Get available themes
    local themes=()
    if [[ -d "$SCRIPT_DIR/src/themes" ]]; then
        while IFS= read -r theme; do
            themes+=("$theme")
        done < <(find "$SCRIPT_DIR/src/themes" -name "*.conf" -exec basename {} .conf \; | sort)
    fi

    if [[ ${#themes[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No theme presets found. Using static mode instead.${NC}"
        SELECTED_MODE="static"
        return
    fi

    local i=1
    for theme in "${themes[@]}"; do
        # Get description from theme file if available
        local desc
        desc=$(grep -m1 "^# Description:" "$SCRIPT_DIR/src/themes/${theme}.conf" 2>/dev/null | sed 's/# Description: //' || echo "")
        echo -e "  ${YELLOW}$i)${NC} ${BOLD}$theme${NC}"
        [[ -n "$desc" ]] && print_info "$desc"
        ((i++))
    done
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select theme [1-${#themes[@]}]" "1")

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#themes[@]} ]]; then
            SELECTED_PRESET="${themes[$((choice - 1))]}"
            valid=true
        else
            echo -e "${RED}Invalid choice.${NC}"
        fi
    done

    echo ""
    echo -e "  ${GREEN}Selected theme: ${BOLD}$SELECTED_PRESET${NC}"
}

# === STEP 3: LIGHT/DARK MODE ===

select_auto_dark_mode() {
    print_section "Step 3: Light/Dark Mode"

    echo "  Should the system automatically detect light/dark mode?"
    echo ""
    print_info "When enabled, colors adapt when your system theme changes."
    print_info "Checked at: session start, permission requests, completions."
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Disabled${NC} ${DIM}(Recommended)${NC}"
    print_info "Use dark colors always. Fastest, most predictable."
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Enabled${NC}"
    print_info "Detect system preference and switch between light/dark colors."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Force Light${NC}"
    print_info "Always use light mode colors."
    echo ""
    echo -e "  ${YELLOW}4)${NC} ${BOLD}Force Dark${NC}"
    print_info "Always use dark mode colors."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select option [1-4]" "1")

        case "$choice" in
            1) SELECTED_AUTO_DARK="false"; SELECTED_FORCE_MODE="auto"; valid=true ;;
            2) SELECTED_AUTO_DARK="true"; SELECTED_FORCE_MODE="auto"; valid=true ;;
            3) SELECTED_AUTO_DARK="false"; SELECTED_FORCE_MODE="light"; valid=true ;;
            4) SELECTED_AUTO_DARK="false"; SELECTED_FORCE_MODE="dark"; valid=true ;;
            *) echo -e "${RED}Invalid choice.${NC}" ;;
        esac
    done

    echo ""
    if [[ "$SELECTED_AUTO_DARK" == "true" ]]; then
        echo -e "  ${GREEN}Auto dark mode: ${BOLD}Enabled${NC}"
    elif [[ "$SELECTED_FORCE_MODE" != "auto" ]]; then
        echo -e "  ${GREEN}Forced mode: ${BOLD}$SELECTED_FORCE_MODE${NC}"
    else
        echo -e "  ${GREEN}Auto dark mode: ${BOLD}Disabled${NC}"
    fi
}

# === STEP 4: ANTHROPOMORPHISING ===

select_faces() {
    print_section "Step 4: ASCII Faces (Anthropomorphising)"

    echo "  Add expressive ASCII faces to terminal titles?"
    echo ""
    print_info "Examples: (°-°) ʕ•ᴥ•ʔ ฅ^•ﻌ•^ฅ ( ͡° ͜ʖ ͡°)"
    echo ""

    if confirm "Enable ASCII faces?"; then
        SELECTED_FACE_ENABLED="true"

        # Show face themes
        echo ""
        echo "  Select face theme:"
        echo ""

        local i=1
        for theme in "${AVAILABLE_THEMES[@]}"; do
            echo -e "  ${YELLOW}$i)${NC} ${BOLD}$theme${NC}"
            echo -e "     Processing: $(get_face "$theme" processing)  Complete: $(get_face "$theme" complete)  Idle: $(get_face "$theme" idle_4)"
            ((i++))
        done
        echo ""

        local valid=false
        while [[ "$valid" == "false" ]]; do
            local choice
            choice=$(read_choice "Select theme [1-${#AVAILABLE_THEMES[@]}]" "1")

            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#AVAILABLE_THEMES[@]} ]]; then
                SELECTED_FACE_THEME="${AVAILABLE_THEMES[$((choice - 1))]}"
                valid=true
            else
                echo -e "${RED}Invalid choice.${NC}"
            fi
        done

        # Position
        echo ""
        echo "  Face position:"
        echo -e "  ${YELLOW}1)${NC} Before emoji: $(get_face "$SELECTED_FACE_THEME" processing) 🟠 ~/path"
        echo -e "  ${YELLOW}2)${NC} After emoji:  🟠 $(get_face "$SELECTED_FACE_THEME" processing) ~/path"
        echo ""

        local pos_choice
        pos_choice=$(read_choice "Select position [1-2]" "1")
        [[ "$pos_choice" == "2" ]] && SELECTED_FACE_POSITION="after" || SELECTED_FACE_POSITION="before"

        echo ""
        echo -e "  ${GREEN}Face theme: ${BOLD}$SELECTED_FACE_THEME${NC}, Position: ${BOLD}$SELECTED_FACE_POSITION${NC}"
    else
        SELECTED_FACE_ENABLED="false"
        echo ""
        echo -e "  ${GREEN}ASCII faces: ${BOLD}Disabled${NC}"
    fi
}

# === PREVIEW ===

show_preview() {
    print_section "Configuration Preview"

    echo "  Settings to be saved:"
    echo ""
    echo -e "  ${BOLD}Operating Mode:${NC}      $SELECTED_MODE"
    [[ "$SELECTED_MODE" == "preset" ]] && echo -e "  ${BOLD}Theme Preset:${NC}        $SELECTED_PRESET"
    echo -e "  ${BOLD}Auto Dark Mode:${NC}      $SELECTED_AUTO_DARK"
    [[ "$SELECTED_FORCE_MODE" != "auto" ]] && echo -e "  ${BOLD}Force Mode:${NC}          $SELECTED_FORCE_MODE"
    echo -e "  ${BOLD}ASCII Faces:${NC}         $SELECTED_FACE_ENABLED"
    if [[ "$SELECTED_FACE_ENABLED" == "true" ]]; then
        echo -e "  ${BOLD}Face Theme:${NC}          $SELECTED_FACE_THEME"
        echo -e "  ${BOLD}Face Position:${NC}       $SELECTED_FACE_POSITION"
    fi
    echo ""

    # Color preview
    echo "  Color preview (current terminal may not show background changes):"
    echo ""

    # Load preview colors
    local preview_proc preview_perm preview_comp preview_idle
    if [[ "$SELECTED_MODE" == "preset" ]] && [[ -n "$SELECTED_PRESET" ]]; then
        source "$SCRIPT_DIR/src/themes/${SELECTED_PRESET}.conf" 2>/dev/null || true
        preview_proc="$DARK_PROCESSING"
        preview_perm="$DARK_PERMISSION"
        preview_comp="$DARK_COMPLETE"
        preview_idle="$DARK_IDLE"
    else
        preview_proc="$COLOR_PROCESSING"
        preview_perm="$COLOR_PERMISSION"
        preview_comp="$COLOR_COMPLETE"
        preview_idle="$COLOR_IDLE"
    fi

    echo -e "  Processing: ${YELLOW}$preview_proc${NC}"
    echo -e "  Permission: ${RED}$preview_perm${NC}"
    echo -e "  Complete:   ${GREEN}$preview_comp${NC}"
    echo -e "  Idle:       ${MAGENTA}$preview_idle${NC}"
    echo ""
}

# === SAVE CONFIGURATION ===

save_configuration() {
    print_section "Saving Configuration"

    # Create config directory
    mkdir -p "$CONFIG_DIR"

    # Generate config file
    cat > "$USER_CONFIG" << EOF
#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - User Configuration
# ==============================================================================
# Generated by configure.sh on $(date)
# Edit this file to customize your settings.
#
# This file is loaded AFTER global and agent configs, so your settings
# here override everything else.
# ==============================================================================

# Operating Mode: static, dynamic, or preset
THEME_MODE="$SELECTED_MODE"
EOF

    if [[ "$SELECTED_MODE" == "preset" ]]; then
        cat >> "$USER_CONFIG" << EOF

# Theme preset (when THEME_MODE="preset")
THEME_PRESET="$SELECTED_PRESET"
EOF
    fi

    cat >> "$USER_CONFIG" << EOF

# Auto-detect system light/dark mode
ENABLE_AUTO_DARK_MODE="$SELECTED_AUTO_DARK"
EOF

    if [[ "$SELECTED_FORCE_MODE" != "auto" ]]; then
        cat >> "$USER_CONFIG" << EOF

# Force light or dark mode: auto, light, dark
FORCE_MODE="$SELECTED_FORCE_MODE"
EOF
    fi

    cat >> "$USER_CONFIG" << EOF

# ASCII Faces (Anthropomorphising)
ENABLE_ANTHROPOMORPHISING="$SELECTED_FACE_ENABLED"
FACE_THEME="$SELECTED_FACE_THEME"
FACE_POSITION="$SELECTED_FACE_POSITION"
EOF

    echo -e "  ${GREEN}Configuration saved to:${NC}"
    echo -e "  ${BOLD}$USER_CONFIG${NC}"
    echo ""
    echo -e "  ${DIM}Your settings will apply to all agents (Claude, Gemini, etc.)${NC}"
    echo -e "  ${DIM}Restart your terminal session to see the changes.${NC}"
}

# === MAIN FLOW ===

main() {
    print_header

    # Show current config if exists
    if [[ -f "$USER_CONFIG" ]]; then
        echo -e "  ${YELLOW}Existing configuration found.${NC}"
        echo -e "  ${DIM}$USER_CONFIG${NC}"
        echo ""
        if ! confirm "Reconfigure?"; then
            echo ""
            echo -e "  ${DIM}No changes made.${NC}"
            exit 0
        fi
    fi

    select_operating_mode
    select_theme_preset
    select_auto_dark_mode
    select_faces

    show_preview

    if confirm "Save this configuration?"; then
        save_configuration
        echo ""
        echo -e "${GREEN}${BOLD}Configuration complete!${NC}"
    else
        echo ""
        echo -e "${YELLOW}Configuration cancelled. No changes made.${NC}"
    fi

    echo ""
}

# === COMMAND LINE OPTIONS ===

show_help() {
    echo "Terminal Agent Visual Signals - Configuration Wizard"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -l, --list      List available theme presets"
    echo "  -c, --current   Show current configuration"
    echo "  -r, --reset     Reset to default configuration"
    echo ""
    echo "Run without options for interactive configuration."
}

list_presets() {
    echo "Available theme presets:"
    echo ""
    if [[ -d "$SCRIPT_DIR/src/themes" ]]; then
        for conf in "$SCRIPT_DIR/src/themes"/*.conf; do
            local name
            name=$(basename "$conf" .conf)
            local desc
            desc=$(grep -m1 "^# Description:" "$conf" 2>/dev/null | sed 's/# Description: //' || echo "")
            echo "  $name"
            [[ -n "$desc" ]] && echo "    $desc"
        done
    else
        echo "  No presets found."
    fi
}

show_current() {
    if [[ -f "$USER_CONFIG" ]]; then
        echo "Current user configuration:"
        echo "File: $USER_CONFIG"
        echo ""
        cat "$USER_CONFIG"
    else
        echo "No user configuration found."
        echo "Run $0 to create one."
    fi
}

reset_config() {
    if [[ -f "$USER_CONFIG" ]]; then
        if confirm "Delete user configuration and reset to defaults?"; then
            rm "$USER_CONFIG"
            echo "Configuration reset to defaults."
        fi
    else
        echo "No user configuration to reset."
    fi
}

case "${1:-}" in
    -h|--help)
        show_help
        ;;
    -l|--list)
        list_presets
        ;;
    -c|--current)
        show_current
        ;;
    -r|--reset)
        reset_config
        ;;
    *)
        main "$@"
        ;;
esac
