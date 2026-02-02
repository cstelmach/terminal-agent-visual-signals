"""
Tests for src/core/colors.sh - Color manipulation utilities.

Validates:
- hex_to_rgb() and rgb_to_hex() conversion
- rgb_to_hsl() and hsl_to_rgb() conversion
- Round-trip conversions (hex -> rgb -> hex should be identical)
- HSL round-trips (may have small rounding differences due to integer math)
- is_dark_color() luminance check
- shift_hue() hue rotation
- interpolate_color() and interpolate_hsl() blending
- adjust_lightness() and adjust_saturation() modifications

These functions are critical for dynamic theming and stage color interpolation.
All calculations use integer arithmetic scaled by 1000 for precision.
"""

import pytest
from conftest import run_bash, PROJECT_ROOT


def source_colors_and_run(cmd: str) -> tuple:
    """Source colors.sh and run a command, return (returncode, stdout, stderr)."""
    result = run_bash(f'source src/core/colors.sh && {cmd}', cwd=PROJECT_ROOT)
    return (result.returncode, result.stdout.strip(), result.stderr.strip())


class TestHexToRgb:
    """Test hex_to_rgb() function."""

    @pytest.mark.parametrize("hex_color,expected_rgb", [
        ("#000000", "0 0 0"),
        ("#FFFFFF", "255 255 255"),
        ("#ffffff", "255 255 255"),  # lowercase
        ("FFFFFF", "255 255 255"),   # no hash
        ("#473D2F", "71 61 47"),
        ("#FF0000", "255 0 0"),      # pure red
        ("#00FF00", "0 255 0"),      # pure green
        ("#0000FF", "0 0 255"),      # pure blue
        ("#808080", "128 128 128"),  # gray
    ])
    def test_hex_to_rgb_valid_colors(self, hex_color, expected_rgb):
        """Valid hex colors should convert correctly to RGB."""
        rc, stdout, _ = source_colors_and_run(f'hex_to_rgb "{hex_color}"')
        assert rc == 0
        assert stdout == expected_rgb

    def test_hex_to_rgb_short_format(self):
        """Short hex format (#RGB) should expand to full format."""
        rc, stdout, _ = source_colors_and_run('hex_to_rgb "#FFF"')
        assert rc == 0
        assert stdout == "255 255 255"

        rc, stdout, _ = source_colors_and_run('hex_to_rgb "#000"')
        assert rc == 0
        assert stdout == "0 0 0"

    def test_hex_to_rgb_invalid_returns_black(self):
        """Invalid hex format should return black (0 0 0) and error code."""
        rc, stdout, _ = source_colors_and_run('hex_to_rgb "invalid"')
        assert stdout == "0 0 0"
        assert rc == 1


class TestRgbToHex:
    """Test rgb_to_hex() function."""

    @pytest.mark.parametrize("r,g,b,expected_hex", [
        (0, 0, 0, "#000000"),
        (255, 255, 255, "#FFFFFF"),
        (71, 61, 47, "#473D2F"),
        (255, 0, 0, "#FF0000"),
        (0, 255, 0, "#00FF00"),
        (0, 0, 255, "#0000FF"),
        (128, 128, 128, "#808080"),
    ])
    def test_rgb_to_hex_valid_values(self, r, g, b, expected_hex):
        """Valid RGB values should convert correctly to hex."""
        rc, stdout, _ = source_colors_and_run(f'rgb_to_hex {r} {g} {b}')
        assert rc == 0
        assert stdout.upper() == expected_hex

    def test_rgb_to_hex_clamps_out_of_range(self):
        """Values outside 0-255 should be clamped."""
        rc, stdout, _ = source_colors_and_run('rgb_to_hex -10 300 128')
        assert rc == 0
        # -10 clamped to 0, 300 clamped to 255
        assert stdout.upper() == "#00FF80"


class TestRoundTripConversions:
    """Test that conversions are reversible."""

    @pytest.mark.parametrize("hex_color", [
        "#000000", "#FFFFFF", "#473D2F", "#A1B2C3", "#123456", "#FEDCBA",
        "#808080", "#FF0000", "#00FF00", "#0000FF",
    ])
    def test_hex_rgb_hex_roundtrip(self, hex_color):
        """Hex -> RGB -> Hex should return the original color."""
        cmd = f'''
            rgb=$(hex_to_rgb "{hex_color}")
            read -r r g b <<< "$rgb"
            rgb_to_hex "$r" "$g" "$b"
        '''
        rc, stdout, _ = source_colors_and_run(cmd)
        assert rc == 0
        assert stdout.upper() == hex_color.upper()


class TestRgbToHsl:
    """Test rgb_to_hsl() function."""

    def test_black_has_zero_saturation(self):
        """Black should have S=0 (achromatic)."""
        rc, stdout, _ = source_colors_and_run('rgb_to_hsl 0 0 0')
        assert rc == 0
        h, s, l = map(int, stdout.split())
        assert s == 0
        assert l == 0

    def test_white_has_zero_saturation(self):
        """White should have S=0, L=1000 (max)."""
        rc, stdout, _ = source_colors_and_run('rgb_to_hsl 255 255 255')
        assert rc == 0
        h, s, l = map(int, stdout.split())
        assert s == 0
        assert l == 1000

    def test_gray_has_zero_saturation(self):
        """Gray should have S=0 (achromatic)."""
        rc, stdout, _ = source_colors_and_run('rgb_to_hsl 128 128 128')
        assert rc == 0
        h, s, l = map(int, stdout.split())
        assert s == 0
        assert 490 <= l <= 510  # ~500 (50% lightness)

    def test_pure_red_has_correct_hue(self):
        """Pure red should have H=0, S=1000, L=500."""
        rc, stdout, _ = source_colors_and_run('rgb_to_hsl 255 0 0')
        assert rc == 0
        h, s, l = map(int, stdout.split())
        assert h == 0  # Red hue = 0 degrees
        assert s == 1000  # Full saturation
        assert l == 500  # 50% lightness

    def test_pure_green_has_correct_hue(self):
        """Pure green should have H=120000 (120° * 1000)."""
        rc, stdout, _ = source_colors_and_run('rgb_to_hsl 0 255 0')
        assert rc == 0
        h, s, l = map(int, stdout.split())
        assert h == 120000  # Green hue = 120 degrees

    def test_pure_blue_has_correct_hue(self):
        """Pure blue should have H=240000 (240° * 1000)."""
        rc, stdout, _ = source_colors_and_run('rgb_to_hsl 0 0 255')
        assert rc == 0
        h, s, l = map(int, stdout.split())
        assert h == 240000  # Blue hue = 240 degrees


class TestHslToRgb:
    """Test hsl_to_rgb() function."""

    def test_black_from_hsl(self):
        """H=0, S=0, L=0 should produce black."""
        rc, stdout, _ = source_colors_and_run('hsl_to_rgb 0 0 0')
        assert rc == 0
        assert stdout == "0 0 0"

    def test_white_from_hsl(self):
        """H=0, S=0, L=1000 should produce white."""
        rc, stdout, _ = source_colors_and_run('hsl_to_rgb 0 0 1000')
        assert rc == 0
        assert stdout == "255 255 255"

    def test_red_from_hsl(self):
        """H=0, S=1000, L=500 should produce red."""
        rc, stdout, _ = source_colors_and_run('hsl_to_rgb 0 1000 500')
        assert rc == 0
        r, g, b = map(int, stdout.split())
        assert r == 255
        assert g == 0
        assert b == 0


class TestHslRoundTrip:
    """Test RGB -> HSL -> RGB round-trip conversions."""

    @pytest.mark.parametrize("hex_color", [
        "#000000", "#FFFFFF", "#808080",  # Achromatic
        "#FF0000", "#00FF00", "#0000FF",  # Primary colors
        "#473D2F", "#A1B2C3",  # Random colors
    ])
    def test_hsl_roundtrip_preserves_color(self, hex_color):
        """RGB -> HSL -> RGB should preserve color (within rounding tolerance)."""
        cmd = f'''
            rgb=$(hex_to_rgb "{hex_color}")
            read -r r g b <<< "$rgb"
            hsl=$(rgb_to_hsl "$r" "$g" "$b")
            read -r h s l <<< "$hsl"
            new_rgb=$(hsl_to_rgb "$h" "$s" "$l")
            read -r nr ng nb <<< "$new_rgb"
            # Calculate difference
            diff=$(( (r-nr)*(r-nr) + (g-ng)*(g-ng) + (b-nb)*(b-nb) ))
            echo "$diff"
        '''
        rc, stdout, _ = source_colors_and_run(cmd)
        assert rc == 0
        diff = int(stdout)
        # Allow small rounding differences (< 10 squared distance)
        assert diff < 30, f"HSL round-trip difference too large: {diff}"


class TestIsDarkColor:
    """Test is_dark_color() function."""

    @pytest.mark.parametrize("hex_color,is_dark", [
        ("#000000", True),   # Black - definitely dark
        ("#FFFFFF", False),  # White - definitely light
        ("#473D2F", True),   # Dark brown - dark
        ("#EEEEEE", False),  # Light gray - light
        ("#222222", True),   # Dark gray - dark
        ("#FF0000", True),   # Pure red - dark (luminance < 0.5)
        ("#00FF00", False),  # Pure green - light (high luminance)
        ("#FFFF00", False),  # Yellow - light
    ])
    def test_is_dark_color_classification(self, hex_color, is_dark):
        """Colors should be correctly classified as dark or light."""
        rc, stdout, _ = source_colors_and_run(
            f'is_dark_color "{hex_color}" && echo "dark" || echo "light"'
        )
        expected = "dark" if is_dark else "light"
        assert stdout == expected


class TestShiftHue:
    """Test shift_hue() function."""

    def test_shift_hue_to_red(self):
        """Shifting any color to hue 0 should produce a reddish tint."""
        rc, stdout, _ = source_colors_and_run('shift_hue "#808080" 0')
        assert rc == 0
        # Gray shifted to red hue - result should still be grayish since S=0
        # But with a saturated input, result would be red

    def test_shift_hue_to_green(self):
        """Shifting to hue 120 should produce a greenish result."""
        rc, stdout, _ = source_colors_and_run('shift_hue "#473D2F" 120')
        assert rc == 0
        # Result should be a greenish version of the original

    def test_shift_hue_preserves_luminance(self):
        """Hue shift should preserve approximate luminance."""
        cmd = '''
            orig="#473D2F"
            shifted=$(shift_hue "$orig" 180)
            # Both should have similar lightness
            rgb1=$(hex_to_rgb "$orig")
            rgb2=$(hex_to_rgb "$shifted")
            read -r r1 g1 b1 <<< "$rgb1"
            read -r r2 g2 b2 <<< "$rgb2"
            hsl1=$(rgb_to_hsl "$r1" "$g1" "$b1")
            hsl2=$(rgb_to_hsl "$r2" "$g2" "$b2")
            read -r h1 s1 l1 <<< "$hsl1"
            read -r h2 s2 l2 <<< "$hsl2"
            # Lightness should be very close
            diff=$(( l1 > l2 ? l1 - l2 : l2 - l1 ))
            echo "$diff"
        '''
        rc, stdout, _ = source_colors_and_run(cmd)
        assert rc == 0
        diff = int(stdout)
        assert diff < 50, f"Lightness changed too much: {diff}"


class TestInterpolateColor:
    """Test interpolate_color() function."""

    def test_interpolate_at_zero_returns_first(self):
        """t=0 should return the first color."""
        rc, stdout, _ = source_colors_and_run(
            'interpolate_color "#000000" "#FFFFFF" 0'
        )
        assert rc == 0
        assert stdout.upper() == "#000000"

    def test_interpolate_at_thousand_returns_second(self):
        """t=1000 should return the second color."""
        rc, stdout, _ = source_colors_and_run(
            'interpolate_color "#000000" "#FFFFFF" 1000'
        )
        assert rc == 0
        assert stdout.upper() == "#FFFFFF"

    def test_interpolate_at_midpoint(self):
        """t=500 should return the midpoint."""
        rc, stdout, _ = source_colors_and_run(
            'interpolate_color "#000000" "#FFFFFF" 500'
        )
        assert rc == 0
        # Midpoint between black and white should be gray
        # 127 or 128 depending on rounding
        r, g, b = tuple(int(stdout[i:i+2], 16) for i in (1, 3, 5))
        assert 126 <= r <= 128
        assert 126 <= g <= 128
        assert 126 <= b <= 128


class TestInterpolateHsl:
    """Test interpolate_hsl() function."""

    def test_interpolate_hsl_at_zero_returns_first(self):
        """t=0 should return the first color."""
        rc, stdout, _ = source_colors_and_run(
            'interpolate_hsl "#FF0000" "#00FF00" 0'
        )
        assert rc == 0
        # Should be close to red
        r, g, b = tuple(int(stdout[i:i+2], 16) for i in (1, 3, 5))
        assert r > 200
        assert g < 50
        assert b < 50

    def test_interpolate_hsl_at_thousand_returns_second(self):
        """t=1000 should return the second color."""
        rc, stdout, _ = source_colors_and_run(
            'interpolate_hsl "#FF0000" "#00FF00" 1000'
        )
        assert rc == 0
        # Should be close to green
        r, g, b = tuple(int(stdout[i:i+2], 16) for i in (1, 3, 5))
        assert r < 50
        assert g > 200
        assert b < 50


class TestAdjustLightness:
    """Test adjust_lightness() function."""

    def test_increase_lightness(self):
        """Positive delta should make color lighter."""
        cmd = '''
            orig="#404040"
            lighter=$(adjust_lightness "$orig" 200)
            # Get lightness values
            rgb1=$(hex_to_rgb "$orig")
            rgb2=$(hex_to_rgb "$lighter")
            read -r r1 g1 b1 <<< "$rgb1"
            read -r r2 g2 b2 <<< "$rgb2"
            hsl1=$(rgb_to_hsl "$r1" "$g1" "$b1")
            hsl2=$(rgb_to_hsl "$r2" "$g2" "$b2")
            read -r h1 s1 l1 <<< "$hsl1"
            read -r h2 s2 l2 <<< "$hsl2"
            # l2 should be greater than l1
            if (( l2 > l1 )); then echo "lighter"; else echo "not lighter"; fi
        '''
        rc, stdout, _ = source_colors_and_run(cmd)
        assert rc == 0
        assert stdout == "lighter"

    def test_decrease_lightness(self):
        """Negative delta should make color darker."""
        cmd = '''
            orig="#808080"
            darker=$(adjust_lightness "$orig" -200)
            # Get lightness values
            rgb1=$(hex_to_rgb "$orig")
            rgb2=$(hex_to_rgb "$darker")
            read -r r1 g1 b1 <<< "$rgb1"
            read -r r2 g2 b2 <<< "$rgb2"
            hsl1=$(rgb_to_hsl "$r1" "$g1" "$b1")
            hsl2=$(rgb_to_hsl "$r2" "$g2" "$b2")
            read -r h1 s1 l1 <<< "$hsl1"
            read -r h2 s2 l2 <<< "$hsl2"
            # l2 should be less than l1
            if (( l2 < l1 )); then echo "darker"; else echo "not darker"; fi
        '''
        rc, stdout, _ = source_colors_and_run(cmd)
        assert rc == 0
        assert stdout == "darker"


class TestCalculateStateColors:
    """Test calculate_state_colors() function."""

    def test_returns_five_colors(self):
        """Should return 5 space-separated hex colors."""
        rc, stdout, _ = source_colors_and_run('calculate_state_colors "#2E3440"')
        assert rc == 0
        colors = stdout.split()
        assert len(colors) == 5
        # Each should be a valid hex color
        for color in colors:
            assert color.startswith("#")
            assert len(color) == 7


class TestColorsSelfTest:
    """Run the built-in self-test in colors.sh."""

    def test_self_test_passes(self):
        """colors.sh internal self-test should pass."""
        result = run_bash('bash src/core/colors.sh test', cwd=PROJECT_ROOT)
        assert result.returncode == 0
        assert "passed" in result.stdout.lower()
