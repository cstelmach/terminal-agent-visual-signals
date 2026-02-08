#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — iTerm2 Title Detection
# ==============================================================================
# Provides enhanced title management for iTerm2 using OSC 1337 ReportVariable.
# This module is sourced conditionally when TERM_PROGRAM=iTerm.app
#
# Key capability: Detect user-renamed tabs by comparing:
#   session.termTitle (what app requested) vs session.presentationName (what's shown)
# ==============================================================================

# Query timeout in seconds
ITERM2_QUERY_TIMEOUT="${ITERM2_QUERY_TIMEOUT:-1}"

# Debug mode
ITERM2_TITLE_DEBUG="${ITERM2_TITLE_DEBUG:-0}"

# ==============================================================================
# OSC 1337 REPORTVARIABLE PROTOCOL
# ==============================================================================
# Request:  \033]1337;ReportVariable=[base64_name]\007
# Response: \033]1337;ReportVariable=[base64_value]\007 (typed to stdin)
# ==============================================================================

# Query an iTerm2 session variable via OSC 1337
# Usage: iterm2_get_var "session.presentationName"
# Returns: decoded variable value or empty on failure
iterm2_get_var() {
    local var_name="$1"
    local timeout="${2:-$ITERM2_QUERY_TIMEOUT}"

    # Validate iTerm2
    [[ "$TERM_PROGRAM" != "iTerm.app" ]] && return 1

    # Ensure we have TTY
    [[ -z "$TTY_DEVICE" ]] && return 1

    # Base64 encode variable name
    local b64_name
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS base64 (no -w option)
        b64_name=$(echo -n "$var_name" | base64)
    else
        # Linux base64 (use -w0 to avoid line wrapping)
        b64_name=$(echo -n "$var_name" | base64 -w0 2>/dev/null || echo -n "$var_name" | base64)
    fi

    if [[ -z "$b64_name" ]]; then
        [[ "$ITERM2_TITLE_DEBUG" == "1" ]] && echo "[iTerm2] Base64 encoding failed for: $var_name" >&2
        return 1
    fi

    # Send request to terminal
    printf "\033]1337;ReportVariable=%s\007" "$b64_name" > "$TTY_DEVICE" 2>/dev/null || {
        [[ "$ITERM2_TITLE_DEBUG" == "1" ]] && echo "[iTerm2] Failed to write to TTY" >&2
        return 1
    }

    # Read response with timeout
    # Response format: ...ReportVariable=[base64_value]\007
    local response
    if ! read -r -t "$timeout" -d $'\a' response < "$TTY_DEVICE" 2>/dev/null; then
        [[ "$ITERM2_TITLE_DEBUG" == "1" ]] && echo "[iTerm2] Read timeout for: $var_name" >&2
        return 1
    fi

    # Extract payload (remove everything before ReportVariable=)
    local payload="${response##*ReportVariable=}"

    # Decode Base64 (use -d for macOS/BSD compatibility, --decode is GNU-only)
    if [[ -n "$payload" ]]; then
        echo "$payload" | base64 -d 2>/dev/null
    else
        [[ "$ITERM2_TITLE_DEBUG" == "1" ]] && echo "[iTerm2] Empty payload for: $var_name" >&2
        return 1
    fi
}

# ==============================================================================
# TITLE DETECTION
# ==============================================================================

# Get the currently displayed title (what user sees)
iterm2_get_current_title() {
    iterm2_get_var "session.presentationName"
}

# Get the title that the application requested (via OSC 0/1/2)
iterm2_get_app_title() {
    iterm2_get_var "session.termTitle"
}

# Get the auto-generated title (based on running command/directory)
iterm2_get_auto_title() {
    iterm2_get_var "session.autoName"
}

# Get the session name
iterm2_get_session_name() {
    iterm2_get_var "session.name"
}

# Get the profile name (static, never changes)
iterm2_get_profile_name() {
    iterm2_get_var "session.profileName"
}

# ==============================================================================
# USER OVERRIDE DETECTION
# ==============================================================================

# Detect if user has manually renamed the tab
# Returns: 0 if user override detected, 1 if not
# Logic: If termTitle != presentationName, user renamed the tab
iterm2_detect_user_override() {
    local term_title
    local presentation

    # Query both variables
    term_title=$(iterm2_get_app_title)
    presentation=$(iterm2_get_current_title)

    [[ "$ITERM2_TITLE_DEBUG" == "1" ]] && {
        echo "[iTerm2] termTitle: '$term_title'" >&2
        echo "[iTerm2] presentationName: '$presentation'" >&2
    }

    # If we can't query, assume no override
    [[ -z "$presentation" ]] && return 1

    # Primary detection: app title differs from displayed title
    if [[ -n "$term_title" && "$term_title" != "$presentation" ]]; then
        [[ "$ITERM2_TITLE_DEBUG" == "1" ]] && echo "[iTerm2] User override detected" >&2
        return 0
    fi

    # Not overridden
    return 1
}

# Get the user's custom title if they set one
# Returns: user's title or empty if using auto/app title
iterm2_get_user_title() {
    local term_title
    local presentation

    term_title=$(iterm2_get_app_title)
    presentation=$(iterm2_get_current_title)

    # If presentation differs from what app set, that's the user's title
    if [[ -n "$term_title" && "$term_title" != "$presentation" ]]; then
        echo "$presentation"
    fi
}

# ==============================================================================
# COMPREHENSIVE TITLE INFO (DEBUG)
# ==============================================================================

# Print all title-related information
iterm2_title_info() {
    echo "=== iTerm2 Title Information ==="
    echo ""

    if [[ "$TERM_PROGRAM" != "iTerm.app" ]]; then
        echo "ERROR: Not running in iTerm2 (TERM_PROGRAM=$TERM_PROGRAM)"
        return 1
    fi

    local term_title presentation auto_name session_name profile_name

    term_title=$(iterm2_get_app_title)
    presentation=$(iterm2_get_current_title)
    auto_name=$(iterm2_get_auto_title)
    session_name=$(iterm2_get_session_name)
    profile_name=$(iterm2_get_profile_name)

    echo "Variable Values:"
    echo "  termTitle (app intent):      '$term_title'"
    echo "  presentationName (display):  '$presentation'"
    echo "  autoName (dynamic):          '$auto_name'"
    echo "  name (session):              '$session_name'"
    echo "  profileName (static):        '$profile_name'"
    echo ""

    # Analysis
    echo "Analysis:"
    if iterm2_detect_user_override; then
        echo "  ⚠️  USER OVERRIDE ACTIVE"
        echo "      User renamed tab to: '$presentation'"
        echo "      App tried to set:    '$term_title'"
        echo "      Action: TAVS should preserve user's title as base"
    elif [[ "$presentation" == "$auto_name" ]]; then
        echo "  ✓  Auto Title Active"
        echo "      Title follows Auto Name format"
        echo "      Action: Safe to set title"
    elif [[ "$presentation" == "$session_name" ]]; then
        echo "  ✓  Session Name Active"
        echo "      Title matches session name"
        echo "      Action: Safe to set title"
    else
        echo "  ?  Ambiguous State"
        echo "      Action: Safe to set title (assume no override)"
    fi
    echo ""
}

# ==============================================================================
# INTEGRATION WITH TITLE.SH
# ==============================================================================
# These functions are called by title.sh when iTerm2 is detected
# ==============================================================================

# Enhanced user title change detection for iTerm2
# Called by detect_user_title_change() in title.sh
iterm2_enhanced_detect_change() {
    # If user override detected via OSC 1337
    if iterm2_detect_user_override; then
        # Get the user's custom title
        local user_title
        user_title=$(iterm2_get_user_title)
        if [[ -n "$user_title" ]]; then
            echo "$user_title"
        fi
        return 0
    fi
    return 1
}

# ==============================================================================
# SELF-TEST
# ==============================================================================

iterm2_title_test() {
    echo "=== iTerm2 Title Detection Self-Test ==="
    echo ""

    # Test 1: iTerm2 detection
    echo "Test 1: iTerm2 Detection"
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        echo "  ✓ Running in iTerm2"
    else
        echo "  ✗ Not iTerm2 - remaining tests will fail"
        return 1
    fi
    echo ""

    # Test 2: Variable query
    echo "Test 2: Variable Query"
    local presentation
    presentation=$(iterm2_get_current_title)
    if [[ -n "$presentation" ]]; then
        echo "  ✓ Can query presentationName: '$presentation'"
    else
        echo "  ✗ Failed to query presentationName"
        return 1
    fi
    echo ""

    # Test 3: Set title via OSC
    echo "Test 3: Title Setting"
    local test_title="TAVS-iTerm2-Test-$$"
    printf "\033]0;%s\007" "$test_title" > "$TTY_DEVICE"
    sleep 0.2

    local term_title
    term_title=$(iterm2_get_app_title)
    if [[ "$term_title" == "$test_title" ]]; then
        echo "  ✓ termTitle updated to: '$term_title'"
    else
        echo "  ✗ termTitle not updated (expected '$test_title', got '$term_title')"
        echo "     Possible cause: Profile setting 'Applications may change title' is disabled"
    fi
    echo ""

    # Test 4: Override detection (no override expected)
    echo "Test 4: Override Detection (No Override)"
    if iterm2_detect_user_override; then
        echo "  ✗ False positive - detected override when none exists"
    else
        echo "  ✓ Correctly detected no user override"
    fi
    echo ""

    echo "=== Manual Test Required ==="
    echo ""
    echo "To test user override detection:"
    echo "  1. Press Cmd+I (or Edit → Rename Tab)"
    echo "  2. Enter a custom name (e.g., 'My Custom Title')"
    echo "  3. Run: iterm2_detect_user_override && echo 'Override detected'"
    echo ""
}

# ==============================================================================
# CONDITIONAL INITIALIZATION
# ==============================================================================

# Export functions for use by title.sh
# Only enable if we're actually in iTerm2
if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
    [[ "$ITERM2_TITLE_DEBUG" == "1" ]] && echo "[iTerm2] Title detection module loaded" >&2
fi
