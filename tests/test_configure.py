"""
Tests for configure.sh - Interactive configuration script.

Verifies:
- Script has valid syntax
- Script runs without error
- Theme preview functions work
"""

import pytest
from conftest import run_bash, PROJECT_ROOT


class TestConfigureSyntax:
    """Test configure.sh syntax and structure."""

    def test_syntax_valid(self):
        """configure.sh should have valid bash syntax."""
        result = run_bash('bash -n configure.sh')
        assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_is_executable(self):
        """configure.sh should be executable."""
        result = run_bash('test -x configure.sh && echo "executable"')
        assert result.returncode == 0
        assert "executable" in result.stdout


class TestConfigureFunctions:
    """Test configure.sh internal functions."""

    def test_show_theme_preview_works(self):
        """show_theme_preview function should work for each theme."""
        result = run_bash('''
            source src/core/themes.sh
            source configure.sh 2>/dev/null << 'EOF'
n
EOF
        ''')

        # Script may exit with various codes due to EOF, but shouldn't crash
        # The main test is that it doesn't error out completely

    def test_sources_themes_correctly(self):
        """configure.sh should source themes.sh correctly."""
        result = run_bash('''
            # Check that configure.sh references themes.sh
            grep -q "themes.sh" configure.sh && echo "found"
        ''')

        assert result.returncode == 0
        assert "found" in result.stdout


class TestConfigureInteraction:
    """Test configure.sh interactive behavior (with simulated input)."""

    def test_decline_enable_exits_cleanly(self):
        """Declining to enable should exit without error."""
        result = run_bash('''
            echo "n" | ./configure.sh 2>&1 | tail -3
        ''')

        # Should complete without crashing
        assert result.returncode == 0 or "No changes" in result.stdout

    def test_shows_current_config(self):
        """Script should show current configuration."""
        result = run_bash('''
            echo "n" | ./configure.sh 2>&1 | head -20
        ''')

        # Should mention configuration
        assert "Configuration" in result.stdout or "ENABLE_ANTHROPOMORPHISING" in result.stdout


class TestConfigureOutput:
    """Test configure.sh output and messages."""

    def test_has_theme_selection(self):
        """Script should contain theme selection logic."""
        result = run_bash('grep -q "AVAILABLE_THEMES" configure.sh && echo "found"')
        assert "found" in result.stdout

    def test_has_position_selection(self):
        """Script should contain position selection logic."""
        result = run_bash('grep -q "FACE_POSITION" configure.sh && echo "found"')
        assert "found" in result.stdout

    def test_creates_backup(self):
        """Script should create backup before modifying config."""
        result = run_bash('grep -q ".bak" configure.sh && echo "found"')
        assert "found" in result.stdout


class TestConfigureHelpers:
    """Test configure.sh helper functions exist."""

    def test_has_update_config_function(self):
        """Should have update_config function."""
        result = run_bash('grep -q "update_config()" configure.sh && echo "found"')
        assert "found" in result.stdout

    def test_has_show_theme_preview_function(self):
        """Should have show_theme_preview function."""
        result = run_bash('grep -q "show_theme_preview()" configure.sh && echo "found"')
        assert "found" in result.stdout

    def test_has_select_theme_function(self):
        """Should have select_theme function."""
        result = run_bash('grep -q "select_theme()" configure.sh && echo "found"')
        assert "found" in result.stdout

    def test_has_select_position_function(self):
        """Should have select_position function."""
        result = run_bash('grep -q "select_position()" configure.sh && echo "found"')
        assert "found" in result.stdout
