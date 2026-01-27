#!/bin/bash
# ==============================================================================
# Terminal Agent Visual Signals - Terminal Detection Module
# ==============================================================================
# Provides terminal background color query, system dark mode detection,
# SSH detection, and terminal type identification.
# ==============================================================================

# Timeout for OSC 11 query in seconds (use fractional for milliseconds)
readonly OSC_QUERY_TIMEOUT=0.1  # 100ms

# ==============================================================================
# Terminal Type Detection
# ==============================================================================

# Get the terminal emulator type
# Returns: iterm2, ghostty, kitty, wezterm, vscode, gnome-terminal, terminal.app, or unknown
get_terminal_type() {
    # Check specific terminal identifiers first
    if [[ -n "$ITERM_SESSION_ID" ]]; then
        echo "iterm2"
    elif [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
        echo "ghostty"
    elif [[ -n "$KITTY_PID" ]] || [[ -n "$KITTY_WINDOW_ID" ]]; then
        echo "kitty"
    elif [[ "$TERM_PROGRAM" == "WezTerm" ]]; then
        echo "wezterm"
    elif [[ "$TERM_PROGRAM" == "vscode" ]] || [[ -n "$VSCODE_GIT_ASKPASS_NODE" ]]; then
        echo "vscode"
    elif [[ -n "$VTE_VERSION" ]]; then
        echo "gnome-terminal"
    elif [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        echo "terminal.app"
    elif [[ -n "$TERM_PROGRAM" ]]; then
        echo "${TERM_PROGRAM,,}"  # lowercase
    else
        echo "unknown"
    fi
}

# Check if terminal supports OSC 11 background query
# Returns 0 (true) if supported, 1 (false) if not
supports_osc11_query() {
    local terminal_type
    terminal_type=$(get_terminal_type)

    case "$terminal_type" in
        iterm2|ghostty|kitty|wezterm|vscode|gnome-terminal|foot|alacritty)
            return 0
            ;;
        terminal.app)
            # macOS Terminal.app does NOT support OSC 11
            return 1
            ;;
        *)
            # Unknown terminals - try anyway but expect possible failure
            return 0
            ;;
    esac
}

# ==============================================================================
# SSH Detection
# ==============================================================================

# Check if running in an SSH session
# Returns 0 (true) if SSH, 1 (false) if local
is_ssh_session() {
    # Check for SSH environment variables
    [[ -n "$SSH_TTY" ]] && return 0
    [[ -n "$SSH_CLIENT" ]] && return 0
    [[ -n "$SSH_CONNECTION" ]] && return 0

    # Check for tmux/screen over SSH (check parent environment)
    if [[ -n "$TMUX" ]] || [[ "$TERM" == screen* ]]; then
        # Inside tmux/screen, harder to detect - check SSH_AUTH_SOCK pattern
        [[ "$SSH_AUTH_SOCK" == */agent.* ]] && return 0
    fi

    return 1
}

# ==============================================================================
# System Dark Mode Detection
# ==============================================================================

# Detect system dark/light mode
# Returns 0 (true) for dark mode, 1 (false) for light mode
# Returns 2 if detection fails (unknown)
detect_system_dark_mode() {
    case "$(uname -s)" in
        Darwin)
            # macOS: Use defaults read
            if defaults read -g AppleInterfaceStyle &>/dev/null; then
                # Dark mode returns "Dark", light mode errors out
                return 0
            else
                return 1
            fi
            ;;

        Linux)
            # Try multiple detection methods

            # Method 1: GNOME 42+ color-scheme (most reliable)
            if command -v gsettings &>/dev/null; then
                local color_scheme
                color_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
                if [[ "$color_scheme" == *"dark"* ]]; then
                    return 0
                elif [[ "$color_scheme" == *"light"* ]] || [[ "$color_scheme" == *"default"* ]]; then
                    return 1
                fi
            fi

            # Method 2: GTK prefer dark theme
            if command -v gsettings &>/dev/null; then
                local prefer_dark
                prefer_dark=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)
                if [[ "$prefer_dark" == *"dark"* ]] || [[ "$prefer_dark" == *"Dark"* ]]; then
                    return 0
                fi
            fi

            # Method 3: Check GTK_THEME environment variable
            if [[ "$GTK_THEME" == *"dark"* ]] || [[ "$GTK_THEME" == *"Dark"* ]]; then
                return 0
            fi

            # Method 4: KDE Plasma
            if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]]; then
                local kde_scheme
                kde_scheme=$(kreadconfig5 --group "General" --key "ColorScheme" 2>/dev/null)
                if [[ "$kde_scheme" == *"Dark"* ]] || [[ "$kde_scheme" == *"dark"* ]]; then
                    return 0
                elif [[ -n "$kde_scheme" ]]; then
                    return 1
                fi
            fi

            # Default to unknown
            return 2
            ;;

        MINGW*|CYGWIN*|MSYS*)
            # Windows (Git Bash, etc.) - check registry
            # Note: This is a simplified check
            if command -v reg &>/dev/null; then
                local apps_theme
                apps_theme=$(reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme 2>/dev/null | grep -o "0x[0-9]*")
                if [[ "$apps_theme" == "0x0" ]]; then
                    return 0  # Dark mode
                elif [[ "$apps_theme" == "0x1" ]]; then
                    return 1  # Light mode
                fi
            fi
            return 2
            ;;

        *)
            return 2  # Unknown
            ;;
    esac
}

# Get dark mode as string
# Returns "dark", "light", or "unknown"
get_system_mode() {
    detect_system_dark_mode
    case $? in
        0) echo "dark" ;;
        1) echo "light" ;;
        *) echo "unknown" ;;
    esac
}

# ==============================================================================
# Terminal Background Query (OSC 11)
# ==============================================================================

# Query terminal background color via OSC 11
# Returns hex color (#RRGGBB) or empty string on failure
# Requires a compatible terminal and TTY access
query_terminal_bg() {
    local tty_device="${1:-}"

    # Find TTY if not provided
    if [[ -z "$tty_device" ]]; then
        # Try to get TTY from parent process
        tty_device=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
        if [[ -z "$tty_device" ]] || [[ "$tty_device" == "??" ]] || [[ "$tty_device" == "-" ]]; then
            # Fallback to /dev/tty
            tty_device="/dev/tty"
        else
            [[ "$tty_device" != /dev/* ]] && tty_device="/dev/$tty_device"
        fi
    fi

    # Check TTY is writable
    if ! [[ -w "$tty_device" ]]; then
        return 1
    fi

    # Check if terminal supports OSC 11
    if ! supports_osc11_query; then
        return 1
    fi

    # Don't query over SSH by default (can cause issues)
    if is_ssh_session; then
        return 1
    fi

    # Save terminal settings
    local old_stty
    old_stty=$(stty -g < "$tty_device" 2>/dev/null) || return 1

    # Set terminal to raw mode for reading response
    stty raw -echo min 0 time 1 < "$tty_device" 2>/dev/null || {
        stty "$old_stty" < "$tty_device" 2>/dev/null
        return 1
    }

    # Send OSC 11 query (request background color)
    # Format: ESC ] 11 ; ? BEL
    printf '\033]11;?\007' > "$tty_device"

    # Read response with timeout
    # Expected format: ESC ] 11 ; rgb:RRRR/GGGG/BBBB BEL (or ST)
    local response=""
    local char
    local timeout_count=0
    local max_iterations=100  # Safety limit

    while (( timeout_count < max_iterations )); do
        char=$(dd bs=1 count=1 2>/dev/null < "$tty_device")
        if [[ -z "$char" ]]; then
            ((timeout_count++))
            continue
        fi

        response+="$char"

        # Check for response terminator (BEL or ST)
        if [[ "$char" == $'\007' ]] || [[ "$response" == *$'\033\\' ]]; then
            break
        fi

        # Safety: if we have enough characters, stop
        if (( ${#response} > 50 )); then
            break
        fi
    done

    # Restore terminal settings
    stty "$old_stty" < "$tty_device" 2>/dev/null

    # Parse response
    # Expected: ]11;rgb:RRRR/GGGG/BBBB (values are 16-bit hex)
    if [[ "$response" =~ rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+) ]]; then
        local r_hex="${BASH_REMATCH[1]}"
        local g_hex="${BASH_REMATCH[2]}"
        local b_hex="${BASH_REMATCH[3]}"

        # Convert from 16-bit (0000-FFFF) to 8-bit (00-FF)
        # Take first two characters of each component
        local r="${r_hex:0:2}"
        local g="${g_hex:0:2}"
        local b="${b_hex:0:2}"

        # Return uppercase hex
        echo "#${r^^}${g^^}${b^^}"
        return 0
    fi

    return 1
}

# Query terminal background with timeout wrapper
# Usage: query_terminal_bg_with_timeout [tty_device] [timeout_seconds]
query_terminal_bg_with_timeout() {
    local tty_device="${1:-}"
    local timeout="${2:-$OSC_QUERY_TIMEOUT}"

    # Use timeout command if available
    if command -v timeout &>/dev/null; then
        timeout "$timeout" bash -c "$(declare -f query_terminal_bg supports_osc11_query is_ssh_session get_terminal_type); query_terminal_bg '$tty_device'" 2>/dev/null
    elif command -v gtimeout &>/dev/null; then
        # macOS with coreutils
        gtimeout "$timeout" bash -c "$(declare -f query_terminal_bg supports_osc11_query is_ssh_session get_terminal_type); query_terminal_bg '$tty_device'" 2>/dev/null
    else
        # Fallback: just run directly (might hang on unsupported terminals)
        query_terminal_bg "$tty_device"
    fi
}

# ==============================================================================
# Utility Functions
# ==============================================================================

# Get comprehensive terminal info (for debugging)
get_terminal_info() {
    echo "Terminal Type: $(get_terminal_type)"
    echo "SSH Session: $(is_ssh_session && echo "yes" || echo "no")"
    echo "System Mode: $(get_system_mode)"
    echo "OSC 11 Support: $(supports_osc11_query && echo "yes" || echo "no")"
    echo "TERM: ${TERM:-unset}"
    echo "TERM_PROGRAM: ${TERM_PROGRAM:-unset}"
    echo "COLORTERM: ${COLORTERM:-unset}"
}

# ==============================================================================
# Self-Test (run with: bash detect.sh test)
# ==============================================================================

_test_detect() {
    echo "=== Terminal Detection Tests ==="
    echo

    echo "Terminal Info:"
    get_terminal_info
    echo

    echo "Testing dark mode detection..."
    local mode
    mode=$(get_system_mode)
    echo "  System mode: $mode"

    echo
    echo "Testing OSC 11 query (may not work in all terminals)..."
    if supports_osc11_query; then
        echo "  OSC 11 supported by this terminal"
        local bg
        bg=$(query_terminal_bg_with_timeout "" 0.5)
        if [[ -n "$bg" ]]; then
            echo "  Background color: $bg"
        else
            echo "  Could not query background (terminal may not respond)"
        fi
    else
        echo "  OSC 11 NOT supported by this terminal"
    fi

    echo
    echo "=== Tests Complete ==="
}

# Run tests if invoked with "test" argument
if [[ "${1:-}" == "test" ]]; then
    _test_detect
    exit 0
fi
