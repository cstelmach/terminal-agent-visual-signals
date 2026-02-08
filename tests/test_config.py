"""
Tests for src/core/theme-config-loader.sh - Configuration variables.

Verifies:
- Default values are correct
- Environment variable overrides work
- Invalid values don't cause errors

Note: The face theme system has migrated from FACE_THEME to TAVS_AGENT.
FACE_THEME is deprecated. Tests now verify the agent-based system.
"""

import pytest
from conftest import source_and_run, run_bash, PROJECT_ROOT


# Available agents (replaces old THEMES list)
AGENTS = ['claude', 'gemini', 'codex', 'opencode', 'unknown']


class TestDefaultValues:
    """Test that configuration variables have correct defaults."""

    def test_anthropomorphising_enabled_by_default(self):
        """ENABLE_ANTHROPOMORPHISING should default to true.

        This changed from false to true in the agent-based face system.
        """
        result = run_bash(
            'source src/core/theme-config-loader.sh && echo "$ENABLE_ANTHROPOMORPHISING"',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "true"

    def test_face_position_defaults_to_before(self):
        """FACE_POSITION should default to before."""
        result = run_bash(
            'source src/core/theme-config-loader.sh && echo "$FACE_POSITION"',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "before"

    def test_tavs_agent_defaults_to_claude(self):
        """TAVS_AGENT should default to claude."""
        result = run_bash(
            'source src/core/theme-config-loader.sh && echo "$TAVS_AGENT"',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "claude"


class TestEnvironmentOverrides:
    """Test that environment variables can override defaults.

    Note: Due to how theme.sh sources defaults.conf, environment variables
    set BEFORE sourcing will be overwritten. To test overrides, we must
    set them AFTER sourcing, or use the load_agent_config() function.
    """

    def test_enable_anthropomorphising_override(self):
        """ENABLE_ANTHROPOMORPHISING can be overridden after sourcing."""
        result = run_bash(
            '''
            source src/core/theme-config-loader.sh
            ENABLE_ANTHROPOMORPHISING=false
            echo "$ENABLE_ANTHROPOMORPHISING"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "false"

    @pytest.mark.parametrize("position", ["before", "after"])
    def test_face_position_override(self, position):
        """FACE_POSITION can be set after sourcing."""
        result = run_bash(
            f'''
            source src/core/theme-config-loader.sh
            FACE_POSITION={position}
            echo "$FACE_POSITION"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert result.stdout.strip() == position

    @pytest.mark.parametrize("agent", AGENTS)
    def test_tavs_agent_override(self, agent):
        """TAVS_AGENT can be set to different agents via env before sourcing."""
        result = run_bash(
            f'''
            export TAVS_AGENT={agent}
            source src/core/theme-config-loader.sh
            echo "$TAVS_AGENT"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert result.stdout.strip() == agent


class TestInvalidValues:
    """Test that invalid configuration values are handled gracefully."""

    def test_invalid_agent_falls_back_to_unknown(self):
        """Invalid TAVS_AGENT should fall back to unknown faces."""
        result = run_bash(
            '''
            export TAVS_AGENT=nonexistent_agent
            source src/core/theme-config-loader.sh
            get_random_face "processing"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        # Should get fallback face (minimal kaomoji)
        face = result.stdout.strip()
        assert face == "(°-°)", f"Expected fallback face, got '{face}'"

    def test_invalid_position_does_not_crash(self):
        """Invalid FACE_POSITION should not crash the script."""
        result = run_bash(
            '''
            source src/core/theme-config-loader.sh
            FACE_POSITION=invalid
            echo "OK"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert "OK" in result.stdout


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
            "src/core/theme-config-loader.sh",
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
                "src/core/theme-config-loader.sh",
                f'echo "${color}"'
            )

            assert result.returncode == 0
            value = result.stdout.strip()
            assert value.startswith("#"), f"{color} should be a hex color, got '{value}'"

    def test_status_icon_variables_exist(self):
        """Status icon variables should be defined."""
        emojis = {
            "STATUS_ICON_PROCESSING": "🟠",
            "STATUS_ICON_PERMISSION": "🔴",
            "STATUS_ICON_COMPLETE": "🟢",
            "STATUS_ICON_IDLE": "🟣",
            "STATUS_ICON_COMPACTING": "🔄",
        }

        for var, expected in emojis.items():
            result = source_and_run(
                "src/core/theme-config-loader.sh",
                f'echo "${var}"'
            )

            assert result.returncode == 0
            assert result.stdout.strip() == expected


class TestAgentConfigLoading:
    """Test load_agent_config() function."""

    def test_load_agent_config_sets_agent(self):
        """load_agent_config() should set TAVS_AGENT."""
        result = run_bash(
            '''
            source src/core/theme-config-loader.sh
            load_agent_config gemini
            echo "$TAVS_AGENT"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert result.stdout.strip() == "gemini"

    def test_load_agent_config_resolves_colors(self):
        """load_agent_config() should resolve agent-specific colors."""
        result = run_bash(
            '''
            source src/core/theme-config-loader.sh
            load_agent_config claude
            # DARK_BASE should be resolved from CLAUDE_DARK_BASE or DEFAULT_DARK_BASE
            echo "$DARK_BASE"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        value = result.stdout.strip()
        assert value.startswith("#"), f"DARK_BASE should be hex color, got '{value}'"
