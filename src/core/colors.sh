#!/bin/bash
# ==============================================================================
# TAVS - Terminal Agent Visual Signals — Color Manipulation Utilities
# ==============================================================================
# Provides HSL/RGB color conversion, hue shifting, luminance calculation,
# and color interpolation for dynamic theming.
#
# All calculations use integer arithmetic scaled by 1000 for precision.
# ==============================================================================

# Scale factor for integer arithmetic (1000 = 3 decimal places)
readonly COLOR_SCALE=1000

# ==============================================================================
# HEX <-> RGB Conversion
# ==============================================================================

# Convert hex color (#RRGGBB or RRGGBB) to space-separated RGB (0-255)
# Usage: hex_to_rgb "#473D2F" -> "71 61 47"
hex_to_rgb() {
    local hex="${1#\#}"  # Remove leading # if present

    # Handle short hex format (#RGB -> #RRGGBB)
    if [[ ${#hex} -eq 3 ]]; then
        hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
    fi

    # Validate length
    if [[ ${#hex} -ne 6 ]]; then
        echo "0 0 0"
        return 1
    fi

    # Convert hex to decimal
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    echo "$r $g $b"
}

# Convert RGB (0-255 each) to hex color (#RRGGBB)
# Usage: rgb_to_hex 71 61 47 -> "#473D2F"
rgb_to_hex() {
    local r=$1 g=$2 b=$3

    # Clamp values to 0-255
    (( r < 0 )) && r=0; (( r > 255 )) && r=255
    (( g < 0 )) && g=0; (( g > 255 )) && g=255
    (( b < 0 )) && b=0; (( b > 255 )) && b=255

    printf "#%02X%02X%02X" "$r" "$g" "$b"
}

# ==============================================================================
# RGB <-> HSL Conversion
# ==============================================================================
# HSL values are scaled by 1000 for integer arithmetic:
# - H: 0-360000 (degrees * 1000)
# - S: 0-1000 (percentage * 10, so 50% = 500)
# - L: 0-1000 (percentage * 10, so 50% = 500)

# Convert RGB (0-255 each) to HSL (scaled integers)
# Usage: rgb_to_hsl 71 61 47 -> "37500 203 231"  (H=37.5°, S=20.3%, L=23.1%)
rgb_to_hsl() {
    local r=$1 g=$2 b=$3

    # Normalize to 0-1000 scale
    local r_norm=$(( r * 1000 / 255 ))
    local g_norm=$(( g * 1000 / 255 ))
    local b_norm=$(( b * 1000 / 255 ))

    # Find min and max
    local max=$r_norm min=$r_norm
    (( g_norm > max )) && max=$g_norm
    (( b_norm > max )) && max=$b_norm
    (( g_norm < min )) && min=$g_norm
    (( b_norm < min )) && min=$b_norm

    local delta=$(( max - min ))

    # Calculate Lightness (0-1000)
    local l=$(( (max + min) / 2 ))

    # Calculate Saturation (0-1000)
    local s=0
    if (( delta != 0 )); then
        if (( l <= 500 )); then
            s=$(( delta * 1000 / (max + min) ))
        else
            s=$(( delta * 1000 / (2000 - max - min) ))
        fi
    fi

    # Calculate Hue (0-360000, i.e., degrees * 1000)
    local h=0
    if (( delta != 0 )); then
        if (( max == r_norm )); then
            h=$(( ((g_norm - b_norm) * 60000 / delta) ))
            (( h < 0 )) && h=$(( h + 360000 ))
        elif (( max == g_norm )); then
            h=$(( 120000 + (b_norm - r_norm) * 60000 / delta ))
        else
            h=$(( 240000 + (r_norm - g_norm) * 60000 / delta ))
        fi
    fi

    # Normalize hue to 0-360000
    (( h < 0 )) && h=$(( h + 360000 ))
    (( h >= 360000 )) && h=$(( h - 360000 ))

    echo "$h $s $l"
}

# Helper function for HSL to RGB conversion
_hue_to_rgb() {
    local p=$1 q=$2 t=$3

    # Normalize t to 0-1000
    (( t < 0 )) && t=$(( t + 1000 ))
    (( t > 1000 )) && t=$(( t - 1000 ))

    if (( t < 167 )); then  # t < 1/6
        echo $(( p + (q - p) * 6 * t / 1000 ))
    elif (( t < 500 )); then  # t < 1/2
        echo "$q"
    elif (( t < 667 )); then  # t < 2/3
        echo $(( p + (q - p) * (667 - t) * 6 / 1000 ))
    else
        echo "$p"
    fi
}

# Convert HSL (scaled integers) to RGB (0-255 each)
# Usage: hsl_to_rgb 37500 203 231 -> "71 61 47"
hsl_to_rgb() {
    local h=$1 s=$2 l=$3

    # Convert h from 0-360000 to 0-1000 for calculations
    local h_norm=$(( h * 1000 / 360000 ))

    local r g b

    if (( s == 0 )); then
        # Achromatic (gray)
        r=$(( l * 255 / 1000 ))
        g=$r
        b=$r
    else
        local q p
        if (( l < 500 )); then
            q=$(( l * (1000 + s) / 1000 ))
        else
            q=$(( l + s - l * s / 1000 ))
        fi
        p=$(( 2 * l - q ))

        r=$(_hue_to_rgb $p $q $(( h_norm + 333 )))
        g=$(_hue_to_rgb $p $q $h_norm)
        b=$(_hue_to_rgb $p $q $(( h_norm - 333 )))

        # Convert from 0-1000 to 0-255
        r=$(( r * 255 / 1000 ))
        g=$(( g * 255 / 1000 ))
        b=$(( b * 255 / 1000 ))
    fi

    # Clamp to valid range
    (( r < 0 )) && r=0; (( r > 255 )) && r=255
    (( g < 0 )) && g=0; (( g > 255 )) && g=255
    (( b < 0 )) && b=0; (( b > 255 )) && b=255

    echo "$r $g $b"
}

# ==============================================================================
# Hue Shifting
# ==============================================================================

# Shift hue of a hex color to a target hue while preserving saturation/lightness
# Usage: shift_hue "#473D2F" 30 -> "#4A3D2B" (shift to 30° orange)
# Target hue is in degrees (0-360)
shift_hue() {
    local hex="$1"
    local target_hue="$2"  # degrees (0-360)

    # Convert hex to RGB
    local rgb
    rgb=$(hex_to_rgb "$hex")
    read -r r g b <<< "$rgb"

    # Convert RGB to HSL
    local hsl
    hsl=$(rgb_to_hsl "$r" "$g" "$b")
    read -r h s l <<< "$hsl"

    # Replace hue with target (convert degrees to scaled value)
    local new_h=$(( target_hue * 1000 ))

    # Convert back to RGB
    local new_rgb
    new_rgb=$(hsl_to_rgb "$new_h" "$s" "$l")
    read -r nr ng nb <<< "$new_rgb"

    # Convert to hex
    rgb_to_hex "$nr" "$ng" "$nb"
}

# ==============================================================================
# Luminance Calculation
# ==============================================================================

# Calculate relative luminance using W3C formula
# L = 0.2126*R + 0.7152*G + 0.0722*B (with gamma correction)
# Returns value scaled by 1000 (0-1000 range)
# Usage: calculate_luminance "#473D2F" -> "185" (0.185 luminance)
calculate_luminance() {
    local hex="$1"

    # Convert hex to RGB
    local rgb
    rgb=$(hex_to_rgb "$hex")
    read -r r g b <<< "$rgb"

    # Normalize to 0-1000 scale
    local r_norm=$(( r * 1000 / 255 ))
    local g_norm=$(( g * 1000 / 255 ))
    local b_norm=$(( b * 1000 / 255 ))

    # Apply simplified gamma correction (linearize)
    # For values <= 0.03928, divide by 12.92
    # For values > 0.03928, ((value + 0.055) / 1.055) ^ 2.4
    # Using simplified linear approximation for bash integer math
    _linearize() {
        local v=$1
        if (( v <= 39 )); then  # 0.03928 * 1000 ≈ 39
            echo $(( v * 1000 / 12920 ))
        else
            # Simplified: approximate gamma with power function
            # Using lookup or polynomial approximation
            # For simplicity, using linear approximation scaled
            echo $(( (v + 55) * (v + 55) / 1110 ))
        fi
    }

    local r_lin=$(_linearize $r_norm)
    local g_lin=$(_linearize $g_norm)
    local b_lin=$(_linearize $b_norm)

    # Calculate luminance: 0.2126*R + 0.7152*G + 0.0722*B
    local luminance=$(( (2126 * r_lin + 7152 * g_lin + 722 * b_lin) / 10000 ))

    echo "$luminance"
}

# Check if a color is considered "dark" (luminance < 0.5)
# Returns 0 (true) for dark, 1 (false) for light
# Usage: is_dark_color "#473D2F" && echo "dark" || echo "light"
is_dark_color() {
    local hex="$1"
    local luminance
    luminance=$(calculate_luminance "$hex")

    # Threshold at 500 (0.5 * 1000)
    (( luminance < 500 ))
}

# ==============================================================================
# Color Interpolation
# ==============================================================================

# Interpolate between two colors
# t is the interpolation factor (0-1000, where 0=color1, 1000=color2)
# Usage: interpolate_color "#473D2F" "#2E3440" 500 -> midpoint color
interpolate_color() {
    local hex1="$1"
    local hex2="$2"
    local t="$3"  # 0-1000

    # Clamp t
    (( t < 0 )) && t=0
    (( t > 1000 )) && t=1000

    # Convert both to RGB
    local rgb1 rgb2
    rgb1=$(hex_to_rgb "$hex1")
    rgb2=$(hex_to_rgb "$hex2")
    read -r r1 g1 b1 <<< "$rgb1"
    read -r r2 g2 b2 <<< "$rgb2"

    # Linear interpolation
    local r=$(( r1 + (r2 - r1) * t / 1000 ))
    local g=$(( g1 + (g2 - g1) * t / 1000 ))
    local b=$(( b1 + (b2 - b1) * t / 1000 ))

    rgb_to_hex "$r" "$g" "$b"
}

# Interpolate in HSL space (better for hue transitions)
# Usage: interpolate_hsl "#473D2F" "#2E3440" 500 -> midpoint with hue interpolation
interpolate_hsl() {
    local hex1="$1"
    local hex2="$2"
    local t="$3"  # 0-1000

    # Clamp t
    (( t < 0 )) && t=0
    (( t > 1000 )) && t=1000

    # Convert both to HSL
    local rgb1 rgb2
    rgb1=$(hex_to_rgb "$hex1")
    rgb2=$(hex_to_rgb "$hex2")
    read -r r1 g1 b1 <<< "$rgb1"
    read -r r2 g2 b2 <<< "$rgb2"

    local hsl1 hsl2
    hsl1=$(rgb_to_hsl "$r1" "$g1" "$b1")
    hsl2=$(rgb_to_hsl "$r2" "$g2" "$b2")
    read -r h1 s1 l1 <<< "$hsl1"
    read -r h2 s2 l2 <<< "$hsl2"

    # Interpolate hue (shortest path around the circle)
    local h_diff=$(( h2 - h1 ))
    if (( h_diff > 180000 )); then
        h_diff=$(( h_diff - 360000 ))
    elif (( h_diff < -180000 )); then
        h_diff=$(( h_diff + 360000 ))
    fi
    local h=$(( h1 + h_diff * t / 1000 ))
    (( h < 0 )) && h=$(( h + 360000 ))
    (( h >= 360000 )) && h=$(( h - 360000 ))

    # Interpolate saturation and lightness linearly
    local s=$(( s1 + (s2 - s1) * t / 1000 ))
    local l=$(( l1 + (l2 - l1) * t / 1000 ))

    # Convert back to RGB then hex
    local rgb
    rgb=$(hsl_to_rgb "$h" "$s" "$l")
    read -r r g b <<< "$rgb"

    rgb_to_hex "$r" "$g" "$b"
}

# ==============================================================================
# Utility Functions
# ==============================================================================

# Adjust lightness of a color
# delta is in scaled units (-1000 to 1000)
# Usage: adjust_lightness "#473D2F" -100 -> slightly darker
adjust_lightness() {
    local hex="$1"
    local delta="$2"  # -1000 to 1000

    # Convert to HSL
    local rgb
    rgb=$(hex_to_rgb "$hex")
    read -r r g b <<< "$rgb"

    local hsl
    hsl=$(rgb_to_hsl "$r" "$g" "$b")
    read -r h s l <<< "$hsl"

    # Adjust lightness
    l=$(( l + delta ))
    (( l < 0 )) && l=0
    (( l > 1000 )) && l=1000

    # Convert back
    local new_rgb
    new_rgb=$(hsl_to_rgb "$h" "$s" "$l")
    read -r nr ng nb <<< "$new_rgb"

    rgb_to_hex "$nr" "$ng" "$nb"
}

# Adjust saturation of a color
# delta is in scaled units (-1000 to 1000)
# Usage: adjust_saturation "#473D2F" -100 -> less saturated
adjust_saturation() {
    local hex="$1"
    local delta="$2"  # -1000 to 1000

    # Convert to HSL
    local rgb
    rgb=$(hex_to_rgb "$hex")
    read -r r g b <<< "$rgb"

    local hsl
    hsl=$(rgb_to_hsl "$r" "$g" "$b")
    read -r h s l <<< "$hsl"

    # Adjust saturation
    s=$(( s + delta ))
    (( s < 0 )) && s=0
    (( s > 1000 )) && s=1000

    # Convert back
    local new_rgb
    new_rgb=$(hsl_to_rgb "$h" "$s" "$l")
    read -r nr ng nb <<< "$new_rgb"

    rgb_to_hex "$nr" "$ng" "$nb"
}

# Calculate all state colors from a base color using fixed target hues
# Returns space-separated hex colors: processing permission complete idle compacting
# Usage: calculate_state_colors "#2E3440" -> "#4A3D2B #4A2021 #2E4430 #3E2E44 #2E4443"
calculate_state_colors() {
    local base_hex="$1"

    # Target hues for each state (degrees)
    local HUE_PROCESSING=30    # Orange
    local HUE_PERMISSION=0     # Red
    local HUE_COMPLETE=120     # Green
    local HUE_IDLE=270         # Purple
    local HUE_COMPACTING=180   # Teal

    local proc=$(shift_hue "$base_hex" $HUE_PROCESSING)
    local perm=$(shift_hue "$base_hex" $HUE_PERMISSION)
    local comp=$(shift_hue "$base_hex" $HUE_COMPLETE)
    local idle=$(shift_hue "$base_hex" $HUE_IDLE)
    local compact=$(shift_hue "$base_hex" $HUE_COMPACTING)

    echo "$proc $perm $comp $idle $compact"
}

# ==============================================================================
# Self-Test (run with: bash colors.sh test)
# ==============================================================================

_test_colors() {
    local pass=0 fail=0

    echo "=== Color Utility Tests ==="
    echo

    # Test hex_to_rgb
    echo "Testing hex_to_rgb..."
    local result=$(hex_to_rgb "#473D2F")
    if [[ "$result" == "71 61 47" ]]; then
        echo "  PASS: #473D2F -> 71 61 47"
        ((pass++))
    else
        echo "  FAIL: #473D2F -> $result (expected 71 61 47)"
        ((fail++))
    fi

    result=$(hex_to_rgb "FFFFFF")
    if [[ "$result" == "255 255 255" ]]; then
        echo "  PASS: FFFFFF -> 255 255 255"
        ((pass++))
    else
        echo "  FAIL: FFFFFF -> $result (expected 255 255 255)"
        ((fail++))
    fi

    # Test rgb_to_hex
    echo "Testing rgb_to_hex..."
    result=$(rgb_to_hex 71 61 47)
    if [[ "$result" == "#473D2F" ]]; then
        echo "  PASS: 71 61 47 -> #473D2F"
        ((pass++))
    else
        echo "  FAIL: 71 61 47 -> $result (expected #473D2F)"
        ((fail++))
    fi

    # Test round-trip conversion
    echo "Testing round-trip hex->rgb->hex..."
    local orig="#A1B2C3"
    local rgb=$(hex_to_rgb "$orig")
    read -r r g b <<< "$rgb"
    result=$(rgb_to_hex "$r" "$g" "$b")
    if [[ "$result" == "$orig" ]]; then
        echo "  PASS: $orig round-trip preserved"
        ((pass++))
    else
        echo "  FAIL: $orig -> $result (should match)"
        ((fail++))
    fi

    # Test HSL conversion round-trip
    echo "Testing HSL round-trip..."
    orig="#473D2F"
    rgb=$(hex_to_rgb "$orig")
    read -r r g b <<< "$rgb"
    local hsl=$(rgb_to_hsl "$r" "$g" "$b")
    read -r h s l <<< "$hsl"
    local new_rgb=$(hsl_to_rgb "$h" "$s" "$l")
    read -r nr ng nb <<< "$new_rgb"
    result=$(rgb_to_hex "$nr" "$ng" "$nb")
    # Allow small rounding differences
    local orig_rgb=$(hex_to_rgb "$orig")
    local result_rgb=$(hex_to_rgb "$result")
    read -r or og ob <<< "$orig_rgb"
    read -r rr rg rb <<< "$result_rgb"
    local diff=$(( (or-rr)*(or-rr) + (og-rg)*(og-rg) + (ob-rb)*(ob-rb) ))
    if (( diff < 10 )); then
        echo "  PASS: HSL round-trip $orig -> $result (diff=$diff)"
        ((pass++))
    else
        echo "  FAIL: HSL round-trip $orig -> $result (diff=$diff too large)"
        ((fail++))
    fi

    # Test is_dark_color
    echo "Testing is_dark_color..."
    if is_dark_color "#000000"; then
        echo "  PASS: #000000 is dark"
        ((pass++))
    else
        echo "  FAIL: #000000 should be dark"
        ((fail++))
    fi

    if ! is_dark_color "#FFFFFF"; then
        echo "  PASS: #FFFFFF is light"
        ((pass++))
    else
        echo "  FAIL: #FFFFFF should be light"
        ((fail++))
    fi

    if is_dark_color "#473D2F"; then
        echo "  PASS: #473D2F is dark"
        ((pass++))
    else
        echo "  FAIL: #473D2F should be dark"
        ((fail++))
    fi

    # Test shift_hue
    echo "Testing shift_hue..."
    result=$(shift_hue "#808080" 0)  # Gray shifted to red hue
    echo "  INFO: Gray (#808080) shifted to hue 0: $result"

    result=$(shift_hue "#473D2F" 120)  # Original to green
    echo "  INFO: #473D2F shifted to hue 120 (green): $result"

    # Test calculate_state_colors
    echo "Testing calculate_state_colors..."
    result=$(calculate_state_colors "#2E3440")
    echo "  INFO: State colors from #2E3440: $result"

    echo
    echo "=== Results: $pass passed, $fail failed ==="

    return $fail
}

# Run tests if invoked with "test" argument
if [[ "${1:-}" == "test" ]]; then
    _test_colors
    exit $?
fi
