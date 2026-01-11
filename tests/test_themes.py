"""
Tests for src/core/themes.sh - Face theme definitions.

Verifies:
- All 66 face combinations (6 themes × 11 states) return non-empty values
- Specific expected faces match their definitions
- get_face() function handles invalid inputs gracefully
"""

import pytest
from conftest import (
    source_and_run,
    THEMES,
    CORE_STATES,
    IDLE_STATES,
    ALL_STATES,
    EXPECTED_FACES,
)


class TestGetFace:
    """Test the get_face() function from themes.sh."""

    @pytest.mark.parametrize("theme", THEMES)
    @pytest.mark.parametrize("state", ALL_STATES)
    def test_all_theme_state_combinations_return_value(self, theme, state):
        """Every theme/state combination should return a non-empty face."""
        result = source_and_run(
            "src/core/themes.sh",
            f'get_face "{theme}" "{state}"'
        )

        assert result.returncode == 0, f"get_face failed: {result.stderr}"
        face = result.stdout.strip()
        assert face != "", f"Empty face for {theme}:{state}"
        assert len(face) > 0, f"No output for {theme}:{state}"

    @pytest.mark.parametrize("theme,state,expected", [
        ("minimal", "processing", "(°-°)"),
        ("minimal", "permission", "(°□°)"),
        ("minimal", "complete", "(^‿^)"),
        ("minimal", "compacting", "(°◡°)"),
        ("minimal", "reset", "(-_-)"),
        ("bear", "processing", "ʕ•ᴥ•ʔ"),
        ("bear", "complete", "ʕ♥ᴥ♥ʔ"),
        ("cat", "processing", "ฅ^•ﻌ•^ฅ"),
        ("lenny", "processing", "( ͡° ͜ʖ ͡°)"),
        ("shrug", "processing", "¯\\_(°‿°)_/¯"),
        ("plain", "processing", ":-|"),
        ("plain", "complete", ":-)"),
    ])
    def test_specific_faces_match_expected(self, theme, state, expected):
        """Specific faces should match their expected values."""
        result = source_and_run(
            "src/core/themes.sh",
            f'get_face "{theme}" "{state}"'
        )

        assert result.returncode == 0
        face = result.stdout.strip()
        assert face == expected, f"Expected '{expected}', got '{face}'"

    @pytest.mark.parametrize("theme,idle_faces", [
        ("minimal", [
            ("idle_0", "(•‿•)"),      # Alert
            ("idle_1", "(‿‿)"),       # Content
            ("idle_2", "(︶‿︶)"),     # Relaxed
            ("idle_3", "(¬‿¬)"),      # Drowsy
            ("idle_4", "(-.-)zzZ"),   # Sleepy
            ("idle_5", "(︶.︶)ᶻᶻ"),  # Deep Sleep
        ]),
        ("bear", [
            ("idle_0", "ʕ•ᴥ•ʔ"),
            ("idle_4", "ʕ-ᴥ-ʔzZ"),
            ("idle_5", "ʕ︶ᴥ︶ʔᶻᶻ"),
        ]),
    ])
    def test_idle_progression_faces(self, theme, idle_faces):
        """Idle states should show progressive sleepiness faces."""
        for state, expected in idle_faces:
            result = source_and_run(
                "src/core/themes.sh",
                f'get_face "{theme}" "{state}"'
            )

            assert result.returncode == 0
            face = result.stdout.strip()
            assert face == expected, f"{theme}:{state} - expected '{expected}', got '{face}'"

    def test_invalid_theme_returns_empty(self):
        """Invalid theme should return empty string."""
        result = source_and_run(
            "src/core/themes.sh",
            'get_face "nonexistent" "processing"'
        )

        assert result.returncode == 0
        assert result.stdout.strip() == ""

    def test_invalid_state_returns_empty(self):
        """Invalid state should return empty string."""
        result = source_and_run(
            "src/core/themes.sh",
            'get_face "minimal" "nonexistent"'
        )

        assert result.returncode == 0
        assert result.stdout.strip() == ""

    def test_available_themes_array_exists(self):
        """AVAILABLE_THEMES array should contain all themes."""
        result = source_and_run(
            "src/core/themes.sh",
            'echo "${AVAILABLE_THEMES[@]}"'
        )

        assert result.returncode == 0
        themes = result.stdout.strip().split()
        assert set(themes) == set(THEMES), f"Expected {THEMES}, got {themes}"


class TestThemeCount:
    """Verify the complete set of theme/state combinations."""

    def test_total_face_count(self):
        """Should have exactly 66 face definitions (6 themes × 11 states)."""
        count = 0
        for theme in THEMES:
            for state in ALL_STATES:
                result = source_and_run(
                    "src/core/themes.sh",
                    f'get_face "{theme}" "{state}"'
                )
                if result.stdout.strip():
                    count += 1

        assert count == 66, f"Expected 66 faces, got {count}"

    @pytest.mark.parametrize("theme", THEMES)
    def test_each_theme_has_11_states(self, theme):
        """Each theme should have all 11 states defined."""
        states_with_faces = 0
        for state in ALL_STATES:
            result = source_and_run(
                "src/core/themes.sh",
                f'get_face "{theme}" "{state}"'
            )
            if result.stdout.strip():
                states_with_faces += 1

        assert states_with_faces == 11, f"Theme {theme} has {states_with_faces} states, expected 11"
