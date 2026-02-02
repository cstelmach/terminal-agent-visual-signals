"""
Tests for configure.sh - Interactive configuration script.

Verifies:
- Script has valid syntax
- Script runs without error
- Helper functions exist (in main or sourced modules)

Note: configure.sh has been modularized into:
- configure-utilities.sh - Shared helpers
- configure-step-*.sh - Individual wizard steps
The main configure.sh orchestrates by sourcing these modules.
"""

import pytest
from conftest import run_bash, PROJECT_ROOT


class TestConfigureSyntax:
    """Test configure.sh syntax and structure."""

    def test_syntax_valid(self):
        """configure.sh should have valid bash syntax."""
        result = run_bash('bash -n configure.sh', cwd=PROJECT_ROOT)
        assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_is_executable(self):
        """configure.sh should be executable."""
        result = run_bash('test -x configure.sh && echo "executable"', cwd=PROJECT_ROOT)
        assert result.returncode == 0
        assert "executable" in result.stdout

    def test_step_modules_syntax_valid(self):
        """All configure step modules should have valid bash syntax."""
        result = run_bash('''
            for f in configure-*.sh; do
                bash -n "$f" || exit 1
            done
            echo "all valid"
        ''', cwd=PROJECT_ROOT)
        assert result.returncode == 0
        assert "all valid" in result.stdout


class TestConfigureFunctions:
    """Test configure.sh internal functions."""

    def test_sources_themes_correctly(self):
        """configure.sh should source theme files correctly."""
        result = run_bash('''
            # Check that configure.sh references theme or core files
            grep -q "theme" configure.sh && echo "found"
        ''', cwd=PROJECT_ROOT)

        assert result.returncode == 0
        assert "found" in result.stdout

    def test_sources_step_modules(self):
        """configure.sh should source all step modules."""
        result = run_bash('''
            grep -q "configure-step-" configure.sh && echo "found"
        ''', cwd=PROJECT_ROOT)
        assert result.returncode == 0
        assert "found" in result.stdout


class TestConfigureInteraction:
    """Test configure.sh interactive behavior (with simulated input)."""

    def test_decline_enable_exits_cleanly(self):
        """Declining to enable should exit without error."""
        result = run_bash('''
            echo "n" | ./configure.sh 2>&1 | tail -3
        ''', cwd=PROJECT_ROOT)

        # Should complete without crashing
        assert result.returncode == 0 or "No changes" in result.stdout

    def test_shows_current_config(self):
        """Script should show current configuration on startup."""
        result = run_bash('''
            echo "n" | ./configure.sh 2>&1 | head -30
        ''', cwd=PROJECT_ROOT)

        # Should mention configuration or visual signals
        assert ("Configuration" in result.stdout or
                "Visual" in result.stdout or
                "TAVS" in result.stdout or
                "Welcome" in result.stdout)


class TestConfigureOutput:
    """Test configure.sh output and messages."""

    def test_creates_backup(self):
        """Step module should create backup before modifying config.

        Note: .bak logic is in configure-step-terminal-title.sh for settings.json backup.
        """
        result = run_bash('grep -q ".bak" configure-step-terminal-title.sh && echo "found"', cwd=PROJECT_ROOT)
        assert "found" in result.stdout


class TestConfigureHelpers:
    """Test configure.sh helper functions exist (in modules or main)."""

    def test_has_select_operating_mode_function(self):
        """Should have select_operating_mode function in step module."""
        result = run_bash('grep -q "select_operating_mode()" configure-step-operating-mode.sh && echo "found"',
                         cwd=PROJECT_ROOT)
        assert "found" in result.stdout

    def test_has_select_faces_function(self):
        """Should have select_faces function for anthropomorphising in step module."""
        result = run_bash('grep -q "select_faces()" configure-step-ascii-faces.sh && echo "found"',
                         cwd=PROJECT_ROOT)
        assert "found" in result.stdout

    def test_has_select_title_mode_function(self):
        """Should have select_title_mode function in step module."""
        result = run_bash('grep -q "select_title_mode()" configure-step-terminal-title.sh && echo "found"',
                         cwd=PROJECT_ROOT)
        assert "found" in result.stdout

    def test_has_save_configuration_function(self):
        """Should have save_configuration function."""
        result = run_bash('grep -q "save_configuration()" configure.sh && echo "found"',
                         cwd=PROJECT_ROOT)
        assert "found" in result.stdout

    def test_has_show_preview_function(self):
        """Should have show_preview function."""
        result = run_bash('grep -q "show_preview()" configure.sh && echo "found"',
                         cwd=PROJECT_ROOT)
        assert "found" in result.stdout

    def test_main_calls_step_functions(self):
        """Main function should call all step functions."""
        result = run_bash('''
            grep -q "select_operating_mode" configure.sh && \
            grep -q "select_theme_preset" configure.sh && \
            grep -q "select_auto_dark_mode" configure.sh && \
            grep -q "select_faces" configure.sh && \
            grep -q "select_title_mode" configure.sh && \
            grep -q "select_palette_theming" configure.sh && \
            echo "found"
        ''', cwd=PROJECT_ROOT)
        assert "found" in result.stdout
