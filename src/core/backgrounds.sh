#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Background Image Support
# ==============================================================================
# Provides stylish background images for supported terminals (iTerm2, Kitty).
# Falls back silently to solid colors on unsupported terminals.
#
# Usage:
#   source backgrounds.sh
#   set_state_background_image "processing"  # Sets state-specific image
#   clear_background_image                    # Clears background image
#
# Prerequisites:
#   - detect.sh must be sourced first (provides get_terminal_type)
#   - TTY_DEVICE must be set
# ==============================================================================

# ==============================================================================
# TERMINAL SUPPORT DETECTION
# ==============================================================================

# Check if terminal supports dynamic background images
# Returns 0 (true) if supported, 1 (false) if not
supports_background_images() {
    # Disabled by config
    [[ "$ENABLE_STYLISH_BACKGROUNDS" != "true" ]] && return 1

    # Disabled over SSH
    if [[ "$STYLISH_DISABLE_SSH" == "true" ]] && is_ssh_session; then
        return 1
    fi

    local terminal_type
    terminal_type=$(get_terminal_type)

    case "$terminal_type" in
        iterm2)
            # iTerm2 supports OSC 1337 SetBackgroundImageFile
            return 0
            ;;
        kitty)
            # Kitty requires allow_remote_control=yes in kitty.conf
            # Check if kitten command is available
            command -v kitten &>/dev/null && return 0
            return 1
            ;;
        *)
            # All other terminals: no support
            return 1
            ;;
    esac
}

# ==============================================================================
# ITERM2 BACKGROUND IMAGE SUPPORT
# ==============================================================================
# iTerm2 uses OSC 1337 proprietary escape sequence:
#   ESC ] 1337 ; SetBackgroundImageFile = <base64-encoded-path> BEL
#
# The path must be base64-encoded. To clear, send empty value.
# ==============================================================================

# Set background image in iTerm2
# Args: $1 = absolute path to image file
_set_bg_image_iterm2() {
    local image_path="$1"
    local tty="${TTY_DEVICE:-/dev/tty}"

    # Verify image exists
    if [[ ! -f "$image_path" ]]; then
        return 1
    fi

    # Base64 encode the path (iTerm2 requires this)
    local encoded_path
    encoded_path=$(printf "%s" "$image_path" | base64 | tr -d '\n')

    # Send OSC 1337 sequence
    # Format: ESC ] 1337 ; SetBackgroundImageFile = <base64> BEL
    printf '\033]1337;SetBackgroundImageFile=%s\007' "$encoded_path" > "$tty"

    return 0
}

# Clear background image in iTerm2
_clear_bg_image_iterm2() {
    local tty="${TTY_DEVICE:-/dev/tty}"

    # Send empty value to clear
    printf '\033]1337;SetBackgroundImageFile=\007' > "$tty"

    return 0
}

# ==============================================================================
# KITTY BACKGROUND IMAGE SUPPORT
# ==============================================================================
# Kitty uses remote control protocol via `kitten @` command:
#   kitten @ set-background-image [options] <path>
#   kitten @ set-background-image none  # Clear
#
# Requires allow_remote_control=yes in kitty.conf
# ==============================================================================

# Set background image in Kitty
# Args: $1 = absolute path to image file
_set_bg_image_kitty() {
    local image_path="$1"

    # Verify image exists
    if [[ ! -f "$image_path" ]]; then
        return 1
    fi

    # Verify kitten command is available
    if ! command -v kitten &>/dev/null; then
        return 1
    fi

    # Build kitten command with configured options
    local layout="${KITTY_IMAGE_LAYOUT:-scaled}"
    local tint="${KITTY_IMAGE_TINT:-}"

    local cmd="kitten @ set-background-image"

    # Add layout option
    cmd+=" --layout=$layout"

    # Add tint/opacity if specified (Kitty calls it tint)
    if [[ -n "$tint" ]] && [[ "$tint" != "0" ]]; then
        cmd+=" --tint=$tint"
    fi

    # Add image path
    cmd+=" '$image_path'"

    # Execute (suppress errors - may fail if remote control disabled)
    eval "$cmd" 2>/dev/null

    return $?
}

# Clear background image in Kitty
_clear_bg_image_kitty() {
    if ! command -v kitten &>/dev/null; then
        return 1
    fi

    kitten @ set-background-image none 2>/dev/null

    return $?
}

# ==============================================================================
# PUBLIC API
# ==============================================================================

# Set state-specific background image
# Args: $1 = state name (processing, permission, complete, idle, compacting, reset)
set_state_background_image() {
    local state="$1"

    # Quick exit if stylish backgrounds disabled
    [[ "$ENABLE_STYLISH_BACKGROUNDS" != "true" ]] && return 0

    # Check terminal support
    if ! supports_background_images; then
        return 0  # Silent fallback
    fi

    # Handle reset state
    if [[ "$state" == "reset" ]]; then
        clear_background_image
        return $?
    fi

    # Determine mode directory (dark/light based on settings)
    local mode_dir=""
    if [[ "$ENABLE_LIGHT_DARK_SWITCHING" == "true" ]]; then
        if detect_system_dark_mode; then
            mode_dir="dark"
        else
            mode_dir="light"
        fi
    elif [[ "$FORCE_MODE" == "light" ]]; then
        mode_dir="light"
    else
        mode_dir="dark"  # Default to dark
    fi

    # Map state to image filename (idle_* variants use idle.png)
    local filename
    case "$state" in
        idle_*) filename="idle.png" ;;
        *)      filename="${state}.png" ;;
    esac

    # Look for image with agent-specific priority
    local image_path=""
    local agent="${TAVS_AGENT:-claude}"

    # Get paths
    local user_agent_dir="$HOME/.tavs/agents/$agent/backgrounds"
    local src_agent_dir
    src_agent_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../agents/$agent/data/backgrounds" 2>/dev/null && pwd )" || true
    local global_dir="${STYLISH_BACKGROUNDS_DIR:-$HOME/.tavs/backgrounds}"

    # Priority 1: User agent override with mode
    if [[ -f "${user_agent_dir}/${mode_dir}/${filename}" ]]; then
        image_path="${user_agent_dir}/${mode_dir}/${filename}"
    # Priority 2: User agent override without mode
    elif [[ -f "${user_agent_dir}/${filename}" ]]; then
        image_path="${user_agent_dir}/${filename}"
    # Priority 3: Source agent data with mode
    elif [[ -n "$src_agent_dir" ]] && [[ -f "${src_agent_dir}/${mode_dir}/${filename}" ]]; then
        image_path="${src_agent_dir}/${mode_dir}/${filename}"
    # Priority 4: Source agent data without mode
    elif [[ -n "$src_agent_dir" ]] && [[ -f "${src_agent_dir}/${filename}" ]]; then
        image_path="${src_agent_dir}/${filename}"
    # Priority 5: Global user backgrounds with mode (legacy)
    elif [[ -f "${global_dir}/${mode_dir}/${filename}" ]]; then
        image_path="${global_dir}/${mode_dir}/${filename}"
    # Priority 6: Global user backgrounds without mode
    elif [[ -f "${global_dir}/${filename}" ]]; then
        image_path="${global_dir}/${filename}"
    # Priority 7: Single image fallback
    elif [[ -n "$STYLISH_SINGLE_IMAGE" ]] && [[ -f "$STYLISH_SINGLE_IMAGE" ]]; then
        image_path="$STYLISH_SINGLE_IMAGE"
    # Priority 8: Default image in global mode directory
    elif [[ -f "${global_dir}/${mode_dir}/default.png" ]]; then
        image_path="${global_dir}/${mode_dir}/default.png"
    # Priority 9: Default image in global root
    elif [[ -f "${global_dir}/default.png" ]]; then
        image_path="${global_dir}/default.png"
    fi

    # No image found - silent fallback
    if [[ -z "$image_path" ]]; then
        return 0
    fi

    # Set image based on terminal type
    local terminal_type
    terminal_type=$(get_terminal_type)

    case "$terminal_type" in
        iterm2)
            _set_bg_image_iterm2 "$image_path"
            ;;
        kitty)
            _set_bg_image_kitty "$image_path"
            ;;
    esac

    return $?
}

# Clear background image (restore terminal default)
clear_background_image() {
    # Quick exit if stylish backgrounds disabled
    [[ "$ENABLE_STYLISH_BACKGROUNDS" != "true" ]] && return 0

    # Check terminal support
    if ! supports_background_images; then
        return 0
    fi

    local terminal_type
    terminal_type=$(get_terminal_type)

    case "$terminal_type" in
        iterm2)
            _clear_bg_image_iterm2
            ;;
        kitty)
            _clear_bg_image_kitty
            ;;
    esac

    return $?
}

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Get comprehensive background image info (for debugging)
get_background_info() {
    echo "Stylish Backgrounds: ${ENABLE_STYLISH_BACKGROUNDS:-false}"
    echo "Backgrounds Directory: ${STYLISH_BACKGROUNDS_DIR:-<default>}"
    echo "Single Image: ${STYLISH_SINGLE_IMAGE:-<none>}"
    echo "Terminal Type: $(get_terminal_type)"
    echo "Supports Images: $(supports_background_images && echo "yes" || echo "no")"

    # List available images
    local dir="${STYLISH_BACKGROUNDS_DIR:-$HOME/.tavs/backgrounds}"
    if [[ -d "$dir" ]]; then
        echo "Available Images:"
        find "$dir" -name "*.png" -o -name "*.jpg" 2>/dev/null | while read -r img; do
            echo "  - $img"
        done
    else
        echo "Backgrounds directory not found: $dir"
    fi
}

# ==============================================================================
# SELF-TEST (run with: bash backgrounds.sh test)
# ==============================================================================

_test_backgrounds() {
    echo "=== Background Image Support Tests ==="
    echo

    get_background_info
    echo

    echo "Testing terminal detection..."
    local terminal_type
    terminal_type=$(get_terminal_type)
    echo "  Terminal: $terminal_type"

    echo
    echo "Testing support detection..."
    if supports_background_images; then
        echo "  Supported: YES"

        echo
        echo "Testing image setting (will set then clear in 2s)..."

        # Try to set a test image
        local test_dir="${STYLISH_BACKGROUNDS_DIR:-$HOME/.tavs/backgrounds}"
        if [[ -f "${test_dir}/processing.png" ]] || [[ -f "${test_dir}/dark/processing.png" ]]; then
            set_state_background_image "processing"
            echo "  Set processing image"
            sleep 2
            clear_background_image
            echo "  Cleared image"
        else
            echo "  No test images found in: $test_dir"
        fi
    else
        echo "  Supported: NO (this is expected for most terminals)"
    fi

    echo
    echo "=== Tests Complete ==="
}

# Run tests if invoked with "test" argument
if [[ "${1:-}" == "test" ]]; then
    # Need to source terminal-detection.sh for get_terminal_type
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$SCRIPT_DIR/terminal-detection.sh"
    _test_backgrounds
    exit 0
fi
