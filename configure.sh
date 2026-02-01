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
# Creates user configuration in ~/.terminal-visual-signals/user.conf
# ==============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="$HOME/.terminal-visual-signals"
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
SELECTED_LIGHT_DARK_SWITCHING="false"
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
SELECTED_SPINNER_STYLE="random"
SELECTED_SPINNER_EYE_MODE="random"
SELECTED_SESSION_IDENTITY="true"

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
    if [[ "$SELECTED_MODE" != "preset" ]]; then
        echo ""
        echo -e "  ${DIM}Step 2: Theme Preset - Skipped (not using preset mode)${NC}"
        return
    fi

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
            1) SELECTED_LIGHT_DARK_SWITCHING="false"; SELECTED_FORCE_MODE="auto"; valid=true ;;
            2) SELECTED_LIGHT_DARK_SWITCHING="true"; SELECTED_FORCE_MODE="auto"; valid=true ;;
            3) SELECTED_LIGHT_DARK_SWITCHING="false"; SELECTED_FORCE_MODE="light"; valid=true ;;
            4) SELECTED_LIGHT_DARK_SWITCHING="false"; SELECTED_FORCE_MODE="dark"; valid=true ;;
            *) echo -e "${RED}Invalid choice.${NC}" ;;
        esac
    done

    echo ""
    if [[ "$SELECTED_LIGHT_DARK_SWITCHING" == "true" ]]; then
        echo -e "  ${GREEN}Light/dark switching: ${BOLD}Enabled${NC}"
    elif [[ "$SELECTED_FORCE_MODE" != "auto" ]]; then
        echo -e "  ${GREEN}Forced mode: ${BOLD}$SELECTED_FORCE_MODE${NC}"
    else
        echo -e "  ${GREEN}Light/dark switching: ${BOLD}Disabled${NC}"
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

# === STEP 5: STYLISH BACKGROUNDS ===

select_stylish_backgrounds() {
    print_section "Step 5: Stylish Backgrounds (Images)"

    echo "  Enable background images for visual states?"
    echo ""
    print_info "This feature replaces solid background colors with images."
    print_info "Each state can have its own image (processing.png, complete.png, etc.)"
    echo ""
    echo -e "  ${BOLD}Supported terminals:${NC} iTerm2, Kitty"
    echo -e "  ${BOLD}Unsupported terminals:${NC} Will automatically fall back to solid colors"
    echo ""
    print_info "This is a global setting. When enabled, supported terminals show"
    print_info "images while unsupported terminals gracefully use color-only mode."
    echo ""

    # Detect terminal
    local terminal_type="unknown"
    if [[ -n "$ITERM_SESSION_ID" ]]; then
        terminal_type="iterm2"
    elif [[ -n "$KITTY_PID" ]] || [[ -n "$KITTY_WINDOW_ID" ]]; then
        terminal_type="kitty"
    elif [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        terminal_type="terminal.app"
    elif [[ -n "$TERM_PROGRAM" ]]; then
        terminal_type="${TERM_PROGRAM,,}"
    fi

    # Show compatibility info for current terminal
    echo -e "  ${DIM}Current terminal:${NC}"
    case "$terminal_type" in
        iterm2)
            echo -e "  ${GREEN}✓${NC} ${BOLD}iTerm2${NC} - Background images will work"
            ;;
        kitty)
            echo -e "  ${GREEN}✓${NC} ${BOLD}Kitty${NC} - Background images will work (requires allow_remote_control=yes)"
            ;;
        terminal.app)
            echo -e "  ${YELLOW}○${NC} ${BOLD}Apple Terminal${NC} - Will use solid colors (images not supported)"
            ;;
        *)
            echo -e "  ${YELLOW}○${NC} ${BOLD}$terminal_type${NC} - Will use solid colors (images not supported)"
            ;;
    esac
    echo ""

    if confirm "Enable stylish background images?"; then
        SELECTED_STYLISH_ENABLED="true"

        echo ""
        echo "  Where should background images be stored?"
        echo ""
        print_info "Default: ~/.terminal-visual-signals/backgrounds/"
        print_info "Create processing.png, complete.png, etc. in this directory."
        print_info "Or organize by mode: dark/processing.png, light/processing.png"
        echo ""

        local default_dir="$HOME/.terminal-visual-signals/backgrounds"
        local custom_dir
        custom_dir=$(read_choice "Directory path" "$default_dir")
        SELECTED_STYLISH_DIR="${custom_dir:-$default_dir}"

        # Check if directory exists
        if [[ ! -d "$SELECTED_STYLISH_DIR" ]]; then
            echo ""
            if confirm "Directory doesn't exist. Create it now?"; then
                mkdir -p "$SELECTED_STYLISH_DIR"
                mkdir -p "$SELECTED_STYLISH_DIR/dark"
                mkdir -p "$SELECTED_STYLISH_DIR/light"
                echo -e "  ${GREEN}Created:${NC} $SELECTED_STYLISH_DIR"
                echo -e "  ${DIM}Add your images to the dark/ and light/ subdirectories${NC}"
            fi
        fi

        echo ""
        echo -e "  ${GREEN}Stylish backgrounds: ${BOLD}Enabled${NC}"
        echo -e "  ${GREEN}Directory: ${BOLD}$SELECTED_STYLISH_DIR${NC}"
        print_info "Images in iTerm2/Kitty, solid colors elsewhere"
    else
        SELECTED_STYLISH_ENABLED="false"
        echo ""
        echo -e "  ${GREEN}Stylish backgrounds: ${BOLD}Disabled${NC}"
        print_info "Using solid colors in all terminals"
    fi
}

# === STEP 6: TERMINAL TITLE MODE ===

select_title_mode() {
    print_section "Step 6: Terminal Title Mode (Claude Code Integration)"

    echo "  How should TAVS handle terminal tab titles?"
    echo ""
    print_info "Claude Code sets its own animated spinner title during processing."
    print_info "This setting controls whether TAVS also sets titles, which may conflict."
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Skip Processing${NC} ${DIM}(Recommended)${NC}"
    print_info "Let Claude Code handle processing titles with its spinner."
    print_info "TAVS shows titles for other states (complete, permission, etc.)."
    print_info "Safe default - no title conflicts."
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Full${NC}"
    print_info "TAVS owns all terminal titles, including processing."
    print_info "Shows animated spinner eyes in face: Ǝ[⠋ ⠙]E"
    print_info "Requires disabling Claude Code's terminal title (will be configured)."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Off${NC}"
    print_info "TAVS never sets terminal titles."
    print_info "Only background colors and images are used."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select title mode [1-3]" "1")

        case "$choice" in
            1) SELECTED_TITLE_MODE="skip-processing"; valid=true ;;
            2) SELECTED_TITLE_MODE="full"; valid=true ;;
            3) SELECTED_TITLE_MODE="off"; valid=true ;;
            *) echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}" ;;
        esac
    done

    echo ""
    echo -e "  ${GREEN}Selected: ${BOLD}$SELECTED_TITLE_MODE${NC}"

    # If full mode, configure spinner and disable Claude's title
    if [[ "$SELECTED_TITLE_MODE" == "full" ]]; then
        configure_full_title_mode
    fi
}

configure_full_title_mode() {
    echo ""
    print_info "Full title mode selected. Configuring spinner settings..."
    echo ""

    # Configure CLAUDE_CODE_DISABLE_TERMINAL_TITLE in settings.json
    local SETTINGS_FILE="$HOME/.claude/settings.json"
    if [[ -f "$SETTINGS_FILE" ]]; then
        # Check if already set
        if grep -q 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE' "$SETTINGS_FILE"; then
            echo -e "  ${GREEN}✓${NC} CLAUDE_CODE_DISABLE_TERMINAL_TITLE already configured"
        else
            echo -e "  ${YELLOW}!${NC} Need to configure CLAUDE_CODE_DISABLE_TERMINAL_TITLE"
            if confirm "  Add to ~/.claude/settings.json?"; then
                if command -v jq &>/dev/null; then
                    local backup_file="${SETTINGS_FILE}.bak"
                    local tmp_file="${SETTINGS_FILE}.tmp"

                    # Create backup before modifying
                    if ! cp "$SETTINGS_FILE" "$backup_file" 2>/dev/null; then
                        echo -e "  ${RED}✗${NC} Failed to create backup; aborting update."
                    else
                        local jq_success=false

                        # Check if env key exists and apply appropriate jq transformation
                        if jq -e '.env' "$SETTINGS_FILE" &>/dev/null; then
                            jq '.env["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"] = "1"' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null && jq_success=true
                        else
                            jq '. + {"env": {"CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"}}' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null && jq_success=true
                        fi

                        if [[ "$jq_success" == "true" ]] && jq -e '.' "$tmp_file" >/dev/null 2>&1; then
                            # Validate JSON is valid before replacing
                            if mv "$tmp_file" "$SETTINGS_FILE" 2>/dev/null; then
                                rm -f "$backup_file" 2>/dev/null
                                echo -e "  ${GREEN}✓${NC} Added to settings.json"
                                echo -e "  ${YELLOW}!${NC} Restart Claude Code for this to take effect"
                            else
                                echo -e "  ${RED}✗${NC} Failed to update settings.json; restoring backup."
                                mv "$backup_file" "$SETTINGS_FILE" 2>/dev/null || true
                                rm -f "$tmp_file" 2>/dev/null
                            fi
                        else
                            echo -e "  ${RED}✗${NC} jq failed to produce valid JSON; restoring backup."
                            mv "$backup_file" "$SETTINGS_FILE" 2>/dev/null || true
                            rm -f "$tmp_file" 2>/dev/null
                        fi
                    fi
                else
                    echo -e "  ${RED}✗${NC} jq not found. Please manually add to ~/.claude/settings.json:"
                    echo -e '     "env": { "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1" }'
                fi
            else
                echo -e "  ${DIM}Skipped. Remember to add manually for full mode to work.${NC}"
            fi
        fi
    else
        echo -e "  ${YELLOW}!${NC} ~/.claude/settings.json not found"
        print_info "Create it with: {\"env\": {\"CLAUDE_CODE_DISABLE_TERMINAL_TITLE\": \"1\"}}"
    fi

    # Spinner Style
    echo ""
    echo "  Select spinner style for processing state:"
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}braille${NC} - Rotating dots ⠋ ⠙ ⠹ ⠸ (Claude-style)"
    echo -e "  ${YELLOW}2)${NC} ${BOLD}circle${NC} - Filling circles ○ ◔ ◑ ◕ ●"
    echo -e "  ${YELLOW}3)${NC} ${BOLD}block${NC} - Pulsing bars ▁ ▂ ▃ ▄ ▅ ▆ ▇ █"
    echo -e "  ${YELLOW}4)${NC} ${BOLD}eye-animate${NC} - Random eye characters • ◦ · ° ○ ●"
    echo -e "  ${YELLOW}5)${NC} ${BOLD}none${NC} - Use existing face variants (no spinner)"
    echo -e "  ${YELLOW}6)${NC} ${BOLD}random${NC} - Random selection per session ${DIM}(Recommended)${NC}"
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select spinner style [1-6]" "6")

        case "$choice" in
            1) SELECTED_SPINNER_STYLE="braille"; valid=true ;;
            2) SELECTED_SPINNER_STYLE="circle"; valid=true ;;
            3) SELECTED_SPINNER_STYLE="block"; valid=true ;;
            4) SELECTED_SPINNER_STYLE="eye-animate"; valid=true ;;
            5) SELECTED_SPINNER_STYLE="none"; valid=true ;;
            6) SELECTED_SPINNER_STYLE="random"; valid=true ;;
            *) echo -e "${RED}Invalid choice.${NC}" ;;
        esac
    done

    echo ""
    echo -e "  ${GREEN}Spinner style: ${BOLD}$SELECTED_SPINNER_STYLE${NC}"

    # Eye Synchronization Mode (only if face enabled and not "none" style)
    if [[ "$SELECTED_FACE_ENABLED" == "true" && "$SELECTED_SPINNER_STYLE" != "none" ]]; then
        echo ""
        echo "  How should the two 'eyes' in the face animate?"
        echo ""
        echo -e "  ${YELLOW}1)${NC} ${BOLD}sync${NC} - Both eyes same frame: Ǝ[⠋ ⠋]E"
        echo -e "  ${YELLOW}2)${NC} ${BOLD}opposite${NC} - Eyes half-cycle apart: Ǝ[◐ ◑]E"
        echo -e "  ${YELLOW}3)${NC} ${BOLD}stagger${NC} - Left leads, right follows: Ǝ[⠹ ⠙]E"
        echo -e "  ${YELLOW}4)${NC} ${BOLD}mirror${NC} - Eyes move in opposite directions"
        echo -e "  ${YELLOW}5)${NC} ${BOLD}random${NC} - Random selection per session ${DIM}(Recommended)${NC}"
        echo ""

        local valid=false
        while [[ "$valid" == "false" ]]; do
            local choice
            choice=$(read_choice "Select eye mode [1-5]" "5")

            case "$choice" in
                1) SELECTED_SPINNER_EYE_MODE="sync"; valid=true ;;
                2) SELECTED_SPINNER_EYE_MODE="opposite"; valid=true ;;
                3) SELECTED_SPINNER_EYE_MODE="stagger"; valid=true ;;
                4) SELECTED_SPINNER_EYE_MODE="mirror"; valid=true ;;
                5) SELECTED_SPINNER_EYE_MODE="random"; valid=true ;;
                *) echo -e "${RED}Invalid choice.${NC}" ;;
            esac
        done

        echo ""
        echo -e "  ${GREEN}Eye mode: ${BOLD}$SELECTED_SPINNER_EYE_MODE${NC}"
    fi

    # Session Identity
    echo ""
    echo "  Should each Claude Code session have a unique visual identity?"
    print_info "When enabled, spinner style and eye mode are randomly selected once"
    print_info "at session start and maintained throughout for consistent appearance."
    echo ""

    if confirm "Enable session identity?"; then
        SELECTED_SESSION_IDENTITY="true"
    else
        SELECTED_SESSION_IDENTITY="false"
    fi

    echo ""
    echo -e "  ${GREEN}Session identity: ${BOLD}$SELECTED_SESSION_IDENTITY${NC}"
}

# === STEP 7: PALETTE THEMING ===

select_palette_theming() {
    print_section "Step 7: Palette Theming (OSC 4)"

    echo "  Modify the terminal's 16-color ANSI palette for cohesive theming?"
    echo ""
    print_info "This affects shell prompts, ls colors, git status, and other CLI tools."
    print_info "Colors from your selected theme will be applied to the entire terminal."
    echo ""
    echo -e "  ${YELLOW}Important:${NC} Only works when applications use 256-color mode."
    echo -e "  Claude Code uses ${BOLD}TrueColor${NC} by default, which bypasses the palette."
    echo ""
    echo -e "  ${YELLOW}1)${NC} ${BOLD}Disabled${NC} ${DIM}(Recommended)${NC}"
    print_info "Background colors only. Safest, works everywhere."
    echo ""
    echo -e "  ${YELLOW}2)${NC} ${BOLD}Auto${NC}"
    print_info "Enable when NOT in TrueColor mode."
    print_info "Automatically detects COLORTERM environment."
    echo ""
    echo -e "  ${YELLOW}3)${NC} ${BOLD}Enabled${NC}"
    print_info "Always apply palette (affects shell tools even in TrueColor)."
    print_info "Shell prompts, ls, git will use themed colors."
    echo ""

    local valid=false
    while [[ "$valid" == "false" ]]; do
        local choice
        choice=$(read_choice "Select palette theming mode [1-3]" "1")

        case "$choice" in
            1) SELECTED_PALETTE_MODE="false"; valid=true ;;
            2) SELECTED_PALETTE_MODE="auto"; valid=true ;;
            3) SELECTED_PALETTE_MODE="true"; valid=true ;;
            *) echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}" ;;
        esac
    done

    echo ""
    case "$SELECTED_PALETTE_MODE" in
        false) echo -e "  ${GREEN}Palette theming: ${BOLD}Disabled${NC}" ;;
        auto)  echo -e "  ${GREEN}Palette theming: ${BOLD}Auto (256-color only)${NC}" ;;
        true)  echo -e "  ${GREEN}Palette theming: ${BOLD}Always enabled${NC}" ;;
    esac

    # Offer to create Claude alias if palette theming is enabled
    if [[ "$SELECTED_PALETTE_MODE" != "false" ]]; then
        echo ""
        echo -e "  ${BOLD}To enable palette theming for Claude Code:${NC}"
        echo ""
        echo -e "  Launch with: ${CYAN}TERM=xterm-256color COLORTERM= claude${NC}"
        echo ""
        print_info "Or add an alias to your shell profile."
        echo ""

        if confirm "Create this alias in your shell profile?"; then
            SELECTED_CREATE_ALIAS="true"

            # Detect shell config
            local shell_rc=""
            if [[ -f "$HOME/.zshrc" ]]; then
                shell_rc="$HOME/.zshrc"
            elif [[ -f "$HOME/.bashrc" ]]; then
                shell_rc="$HOME/.bashrc"
            fi

            if [[ -n "$shell_rc" ]]; then
                echo ""
                echo -e "  ${GREEN}Will add alias to:${NC} $shell_rc"
            else
                echo ""
                echo -e "  ${YELLOW}No .zshrc or .bashrc found. You may need to add the alias manually.${NC}"
                SELECTED_CREATE_ALIAS="false"
            fi
        else
            SELECTED_CREATE_ALIAS="false"
        fi
    fi
}

# === PREVIEW ===

show_preview() {
    print_section "Configuration Preview"

    echo "  Settings to be saved:"
    echo ""
    echo -e "  ${BOLD}Operating Mode:${NC}      $SELECTED_MODE"
    [[ "$SELECTED_MODE" == "preset" ]] && echo -e "  ${BOLD}Theme Preset:${NC}        $SELECTED_PRESET"
    echo -e "  ${BOLD}Auto Dark Mode:${NC}      $SELECTED_LIGHT_DARK_SWITCHING"
    [[ "$SELECTED_FORCE_MODE" != "auto" ]] && echo -e "  ${BOLD}Force Mode:${NC}          $SELECTED_FORCE_MODE"
    echo -e "  ${BOLD}ASCII Faces:${NC}         $SELECTED_FACE_ENABLED"
    if [[ "$SELECTED_FACE_ENABLED" == "true" ]]; then
        echo -e "  ${BOLD}Face Theme:${NC}          $SELECTED_FACE_THEME"
        echo -e "  ${BOLD}Face Position:${NC}       $SELECTED_FACE_POSITION"
    fi
    echo -e "  ${BOLD}Stylish Backgrounds:${NC} $SELECTED_STYLISH_ENABLED"
    if [[ "$SELECTED_STYLISH_ENABLED" == "true" ]]; then
        echo -e "  ${BOLD}Backgrounds Dir:${NC}     $SELECTED_STYLISH_DIR"
    fi
    echo -e "  ${BOLD}Title Mode:${NC}          $SELECTED_TITLE_MODE"
    if [[ "$SELECTED_TITLE_MODE" == "full" ]]; then
        echo -e "  ${BOLD}Spinner Style:${NC}       $SELECTED_SPINNER_STYLE"
        echo -e "  ${BOLD}Eye Mode:${NC}            $SELECTED_SPINNER_EYE_MODE"
        echo -e "  ${BOLD}Session Identity:${NC}    $SELECTED_SESSION_IDENTITY"
    fi
    echo -e "  ${BOLD}Palette Theming:${NC}     $SELECTED_PALETTE_MODE"
    if [[ "$SELECTED_CREATE_ALIAS" == "true" ]]; then
        echo -e "  ${BOLD}Create Claude Alias:${NC} Yes (256-color mode)"
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

# Enable light/dark mode switching based on system appearance
ENABLE_LIGHT_DARK_SWITCHING="$SELECTED_LIGHT_DARK_SWITCHING"
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

# Stylish Backgrounds (Images)
ENABLE_STYLISH_BACKGROUNDS="$SELECTED_STYLISH_ENABLED"
EOF

    if [[ "$SELECTED_STYLISH_ENABLED" == "true" ]] && [[ -n "$SELECTED_STYLISH_DIR" ]]; then
        cat >> "$USER_CONFIG" << EOF
STYLISH_BACKGROUNDS_DIR="$SELECTED_STYLISH_DIR"
EOF
    fi

    cat >> "$USER_CONFIG" << EOF

# Terminal Title Mode
# Options: "full" (TAVS owns all), "skip-processing" (let Claude handle), "off" (no titles)
TAVS_TITLE_MODE="$SELECTED_TITLE_MODE"
EOF

    if [[ "$SELECTED_TITLE_MODE" == "full" ]]; then
        cat >> "$USER_CONFIG" << EOF

# Spinner Configuration (for TAVS_TITLE_MODE="full")
TAVS_SPINNER_STYLE="$SELECTED_SPINNER_STYLE"
TAVS_SPINNER_EYE_MODE="$SELECTED_SPINNER_EYE_MODE"
TAVS_SESSION_IDENTITY="$SELECTED_SESSION_IDENTITY"
EOF
    fi

    cat >> "$USER_CONFIG" << EOF

# Palette Theming (OSC 4)
# Options: "false" (disabled), "auto" (if not TrueColor), "true" (always)
ENABLE_PALETTE_THEMING="$SELECTED_PALETTE_MODE"
EOF

    # Create Claude alias if requested
    if [[ "$SELECTED_CREATE_ALIAS" == "true" ]]; then
        local shell_rc=""
        if [[ -f "$HOME/.zshrc" ]]; then
            shell_rc="$HOME/.zshrc"
        elif [[ -f "$HOME/.bashrc" ]]; then
            shell_rc="$HOME/.bashrc"
        fi

        if [[ -n "$shell_rc" ]]; then
            # Check if alias already exists
            if ! grep -q "alias claude=" "$shell_rc" 2>/dev/null; then
                cat >> "$shell_rc" << 'ALIAS_EOF'

# Claude Code with 256-color mode for TAVS palette theming
# Added by Terminal Agent Visual Signals configure.sh
alias claude='TERM=xterm-256color COLORTERM= claude'
ALIAS_EOF
                echo ""
                echo -e "  ${GREEN}Added Claude alias to:${NC} $shell_rc"
                print_info "Run 'source $shell_rc' or restart your terminal to use it."
            else
                echo ""
                echo -e "  ${YELLOW}Claude alias already exists in:${NC} $shell_rc"
            fi
        fi
    fi

    echo ""
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
    select_stylish_backgrounds
    select_title_mode
    select_palette_theming

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
