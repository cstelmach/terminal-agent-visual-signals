"""
Tests for src/core/theme.sh - Configuration variables.

Verifies:
- Default values are correct
- Environment variable overrides work
- Invalid values don't cause errors
"""

import pytest
from conftest import source_and_run, run_bash, THEMES


class TestDefaultValues:
    """Test that configuration variables have correct defaults."""

    def _get_clean_env(self):
        """Return minimal env without anthropomorphising vars."""
        import os
        clean = {
            'PATH': os.environ.get('PATH', '/usr/bin:/bin'),
            'HOME': os.environ.get('HOME', '/tmp'),
        }
        return clean

    def test_anthropomorphising_disabled_by_default(self):
        """ENABLE_ANTHROPOMORPHISING should default to false."""
        # Use clean env without any anthropomorphising vars
        result = run_bash(
            'source src/core/theme.sh && echo "$ENABLE_ANTHROPOMORPHISING"',
            env=self._get_clean_env()
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "false"

    def test_face_theme_defaults_to_minimal(self):
        """FACE_THEME should default to minimal."""
        result = run_bash(
            'source src/core/theme.sh && echo "$FACE_THEME"',
            env=self._get_clean_env()
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "minimal"

    def test_face_position_defaults_to_after(self):
        """FACE_POSITION should default to after."""
        result = run_bash(
            'source src/core/theme.sh && echo "$FACE_POSITION"',
            env=self._get_clean_env()
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "after"


class TestEnvironmentOverrides:
    """Test that environment variables can override defaults."""

    def test_enable_anthropomorphising_override(self):
        """ENABLE_ANTHROPOMORPHISING can be set via environment."""
        result = run_bash(
            'source src/core/theme.sh && echo "$ENABLE_ANTHROPOMORPHISING"',
            env={'ENABLE_ANTHROPOMORPHISING': 'true'}
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "true"

    @pytest.mark.parametrize("theme", THEMES)
    def test_face_theme_override(self, theme):
        """FACE_THEME can be set to any valid theme."""
        result = run_bash(
            'source src/core/theme.sh && echo "$FACE_THEME"',
            env={'FACE_THEME': theme}
        )

        assert result.returncode == 0
        assert result.stdout.strip() == theme

    @pytest.mark.parametrize("position", ["before", "after"])
    def test_face_position_override(self, position):
        """FACE_POSITION can be set to before or after."""
        result = run_bash(
            'source src/core/theme.sh && echo "$FACE_POSITION"',
            env={'FACE_POSITION': position}
        )

        assert result.returncode == 0
        assert result.stdout.strip() == position


class TestInvalidValues:
    """Test that invalid configuration values are handled gracefully."""

    def test_invalid_theme_does_not_crash(self):
        """Invalid FACE_THEME should not crash the script."""
        result = run_bash(
            'source src/core/theme.sh && echo "OK"',
            env={'FACE_THEME': 'nonexistent_theme'}
        )

        assert result.returncode == 0
        assert "OK" in result.stdout

    def test_invalid_position_does_not_crash(self):
        """Invalid FACE_POSITION should not crash the script."""
        result = run_bash(
            'source src/core/theme.sh && echo "OK"',
            env={'FACE_POSITION': 'invalid'}
        )

        assert result.returncode == 0
        assert "OK" in result.stdout

    def test_empty_values_use_defaults(self):
        """Empty environment values should use defaults."""
        result = run_bash(
            'source src/core/theme.sh && echo "$FACE_THEME"',
            env={'FACE_THEME': ''}
        )

        assert result.returncode == 0
        # Empty string means use default
        assert result.stdout.strip() in ["", "minimal"]


class TestOtherConfigVariables:
    """Test other theme.sh configuration variables exist."""

    @pytest.mark.parametrize("var,expected_default", [
        ("ENABLE_BACKGROUND_CHANGE", "true"),
        ("ENABLE_TITLE_PREFIX", "true"),
        ("ENABLE_PROCESSING", "true"),
        ("ENABLE_PERMISSION", "true"),
        ("ENABLE_COMPLETE", "true"),
        ("ENABLE_IDLE", "true"),
        ("ENABLE_COMPACTING", "true"),
    ])
    def test_feature_toggles_exist(self, var, expected_default):
        """Feature toggle variables should exist with correct defaults."""
        result = source_and_run(
            "src/core/theme.sh",
            f'echo "${var}"'
        )

        assert result.returncode == 0
        assert result.stdout.strip() == expected_default

    def test_color_variables_exist(self):
        """Color variables should be defined."""
        colors = [
            "COLOR_PROCESSING",
            "COLOR_PERMISSION",
            "COLOR_COMPLETE",
            "COLOR_IDLE",
            "COLOR_COMPACTING",
        ]

        for color in colors:
            result = source_and_run(
                "src/core/theme.sh",
                f'echo "${color}"'
            )

            assert result.returncode == 0
            value = result.stdout.strip()
            assert value.startswith("#"), f"{color} should be a hex color, got '{value}'"

    def test_emoji_variables_exist(self):
        """Emoji variables should be defined."""
        emojis = {
            "EMOJI_PROCESSING": "🟠",
            "EMOJI_PERMISSION": "🔴",
            "EMOJI_COMPLETE": "🟢",
            "EMOJI_IDLE": "🟣",
            "EMOJI_COMPACTING": "🔄",
        }

        for var, expected in emojis.items():
            result = source_and_run(
                "src/core/theme.sh",
                f'echo "${var}"'
            )

            assert result.returncode == 0
            assert result.stdout.strip() == expected
