"""
Tests for src/core/detect.sh - Terminal detection module.

This file will be renamed to terminal-detection.sh in refactoring.

Validates:
- get_terminal_type() identifies terminal emulators
- is_truecolor_mode() detects 24-bit color support
- is_ssh_session() detects remote sessions
- detect_system_dark_mode() checks OS appearance
- get_color_mode() returns color capability string
- supports_osc10(), supports_osc11_query(), supports_osc1337() capability checks

Terminal detection relies on environment variables set by each terminal:
- ITERM_SESSION_ID for iTerm2
- GHOSTTY_RESOURCES_DIR or TERM_PROGRAM for Ghostty
- KITTY_PID or KITTY_WINDOW_ID for Kitty
- TERM_PROGRAM for others
"""

import os
import pytest
from conftest import run_bash, PROJECT_ROOT


def source_detect_and_run(cmd: str, env: dict = None) -> tuple:
    """Source detect.sh and run a command, return (returncode, stdout, stderr)."""
    result = run_bash(f'source src/core/detect.sh && {cmd}',
                      cwd=PROJECT_ROOT, env=env)
    return (result.returncode, result.stdout.strip(), result.stderr.strip())


class TestGetTerminalType:
    """Test get_terminal_type() function."""

    def test_detects_iterm2(self):
        """Should detect iTerm2 from ITERM_SESSION_ID."""
        env = os.environ.copy()
        env['ITERM_SESSION_ID'] = 'w0t0p0:12345678-1234-1234-1234-123456789012'
        rc, stdout, _ = source_detect_and_run('get_terminal_type', env=env)
        assert rc == 0
        assert stdout == "iterm2"

    def test_detects_ghostty_from_resources(self):
        """Should detect Ghostty from GHOSTTY_RESOURCES_DIR."""
        env = os.environ.copy()
        env.pop('ITERM_SESSION_ID', None)
        env['GHOSTTY_RESOURCES_DIR'] = '/Applications/Ghostty.app/Contents/Resources'
        rc, stdout, _ = source_detect_and_run('get_terminal_type', env=env)
        assert rc == 0
        assert stdout == "ghostty"

    def test_detects_ghostty_from_term_program(self):
        """Should detect Ghostty from TERM_PROGRAM."""
        env = os.environ.copy()
        env.pop('ITERM_SESSION_ID', None)
        env.pop('GHOSTTY_RESOURCES_DIR', None)
        env['TERM_PROGRAM'] = 'ghostty'
        rc, stdout, _ = source_detect_and_run('get_terminal_type', env=env)
        assert rc == 0
        assert stdout == "ghostty"

    def test_detects_kitty(self):
        """Should detect Kitty from KITTY_PID."""
        env = os.environ.copy()
        env.pop('ITERM_SESSION_ID', None)
        env.pop('GHOSTTY_RESOURCES_DIR', None)
        env.pop('TERM_PROGRAM', None)  # Clear TERM_PROGRAM too
        env['KITTY_PID'] = '12345'
        rc, stdout, _ = source_detect_and_run('get_terminal_type', env=env)
        assert rc == 0
        assert stdout == "kitty"

    def test_detects_wezterm(self):
        """Should detect WezTerm from TERM_PROGRAM."""
        env = os.environ.copy()
        env.pop('ITERM_SESSION_ID', None)
        env.pop('GHOSTTY_RESOURCES_DIR', None)
        env.pop('KITTY_PID', None)
        env['TERM_PROGRAM'] = 'WezTerm'
        rc, stdout, _ = source_detect_and_run('get_terminal_type', env=env)
        assert rc == 0
        assert stdout == "wezterm"

    def test_detects_vscode(self):
        """Should detect VS Code terminal."""
        env = os.environ.copy()
        env.pop('ITERM_SESSION_ID', None)
        env.pop('GHOSTTY_RESOURCES_DIR', None)
        env.pop('KITTY_PID', None)
        env['TERM_PROGRAM'] = 'vscode'
        rc, stdout, _ = source_detect_and_run('get_terminal_type', env=env)
        assert rc == 0
        assert stdout == "vscode"

    def test_detects_terminal_app(self):
        """Should detect macOS Terminal.app."""
        env = os.environ.copy()
        env.pop('ITERM_SESSION_ID', None)
        env.pop('GHOSTTY_RESOURCES_DIR', None)
        env.pop('KITTY_PID', None)
        env['TERM_PROGRAM'] = 'Apple_Terminal'
        rc, stdout, _ = source_detect_and_run('get_terminal_type', env=env)
        assert rc == 0
        assert stdout == "terminal.app"

    def test_returns_unknown_for_bare_env(self):
        """Should return 'unknown' when no terminal vars set."""
        # Create minimal env without terminal identifiers
        env = {
            'PATH': os.environ.get('PATH', '/usr/bin'),
            'HOME': os.environ.get('HOME', '/tmp'),
            'SHELL': '/bin/bash',
        }
        rc, stdout, _ = source_detect_and_run('get_terminal_type', env=env)
        assert rc == 0
        assert stdout == "unknown"


class TestIsTruecolorMode:
    """Test is_truecolor_mode() function."""

    def test_truecolor_with_colorterm(self):
        """Should return true when COLORTERM=truecolor."""
        env = os.environ.copy()
        env['COLORTERM'] = 'truecolor'
        rc, stdout, _ = source_detect_and_run(
            'is_truecolor_mode && echo "yes" || echo "no"', env=env)
        assert rc == 0
        assert stdout == "yes"

    def test_truecolor_with_24bit(self):
        """Should return true when COLORTERM=24bit."""
        env = os.environ.copy()
        env['COLORTERM'] = '24bit'
        rc, stdout, _ = source_detect_and_run(
            'is_truecolor_mode && echo "yes" || echo "no"', env=env)
        assert rc == 0
        assert stdout == "yes"

    def test_not_truecolor_without_colorterm(self):
        """Should return false when COLORTERM not set."""
        env = os.environ.copy()
        env.pop('COLORTERM', None)
        rc, stdout, _ = source_detect_and_run(
            'is_truecolor_mode && echo "yes" || echo "no"', env=env)
        assert stdout == "no"


class TestIsSshSession:
    """Test is_ssh_session() function."""

    def test_detects_ssh_tty(self):
        """Should detect SSH from SSH_TTY."""
        env = os.environ.copy()
        env['SSH_TTY'] = '/dev/pts/0'
        rc, stdout, _ = source_detect_and_run(
            'is_ssh_session && echo "ssh" || echo "local"', env=env)
        assert rc == 0
        assert stdout == "ssh"

    def test_detects_ssh_client(self):
        """Should detect SSH from SSH_CLIENT."""
        env = os.environ.copy()
        env.pop('SSH_TTY', None)
        env['SSH_CLIENT'] = '192.168.1.100 12345 22'
        rc, stdout, _ = source_detect_and_run(
            'is_ssh_session && echo "ssh" || echo "local"', env=env)
        assert rc == 0
        assert stdout == "ssh"

    def test_detects_ssh_connection(self):
        """Should detect SSH from SSH_CONNECTION."""
        env = os.environ.copy()
        env.pop('SSH_TTY', None)
        env.pop('SSH_CLIENT', None)
        env['SSH_CONNECTION'] = '192.168.1.100 12345 192.168.1.1 22'
        rc, stdout, _ = source_detect_and_run(
            'is_ssh_session && echo "ssh" || echo "local"', env=env)
        assert rc == 0
        assert stdout == "ssh"

    def test_local_without_ssh_vars(self):
        """Should return false when no SSH vars set."""
        env = os.environ.copy()
        env.pop('SSH_TTY', None)
        env.pop('SSH_CLIENT', None)
        env.pop('SSH_CONNECTION', None)
        env.pop('TMUX', None)
        rc, stdout, _ = source_detect_and_run(
            'is_ssh_session && echo "ssh" || echo "local"', env=env)
        assert stdout == "local"


class TestGetColorMode:
    """Test get_color_mode() function."""

    def test_returns_truecolor_when_active(self):
        """Should return 'truecolor' when in TrueColor mode."""
        env = os.environ.copy()
        env['COLORTERM'] = 'truecolor'
        rc, stdout, _ = source_detect_and_run('get_color_mode', env=env)
        assert rc == 0
        assert stdout == "truecolor"

    def test_returns_256color_from_term(self):
        """Should return '256color' from TERM variable."""
        env = os.environ.copy()
        env.pop('COLORTERM', None)
        env['TERM'] = 'xterm-256color'
        rc, stdout, _ = source_detect_and_run('get_color_mode', env=env)
        assert rc == 0
        assert stdout == "256color"

    def test_returns_basic_when_minimal(self):
        """Should return 'basic' when no color indicators."""
        env = {
            'PATH': os.environ.get('PATH', '/usr/bin'),
            'HOME': os.environ.get('HOME', '/tmp'),
            'TERM': 'dumb',
        }
        rc, stdout, _ = source_detect_and_run('get_color_mode', env=env)
        assert rc == 0
        assert stdout == "basic"


class TestSupportsOsc10:
    """Test supports_osc10() function."""

    def test_iterm2_supports_osc10(self):
        """iTerm2 should support OSC 10."""
        env = os.environ.copy()
        env['ITERM_SESSION_ID'] = 'test'
        rc, stdout, _ = source_detect_and_run(
            'supports_osc10 && echo "yes" || echo "no"', env=env)
        assert stdout == "yes"

    def test_terminal_app_does_not_support_osc10(self):
        """Terminal.app should NOT support OSC 10."""
        # Use minimal env to avoid bleeding from current terminal
        env = {
            'PATH': os.environ.get('PATH', '/usr/bin'),
            'HOME': os.environ.get('HOME', '/tmp'),
            'TERM_PROGRAM': 'Apple_Terminal',
        }
        rc, stdout, _ = source_detect_and_run(
            'supports_osc10 && echo "yes" || echo "no"', env=env)
        assert stdout == "no"


class TestSupportsOsc1337:
    """Test supports_osc1337() function (iTerm2 extensions)."""

    def test_iterm2_supports_osc1337(self):
        """iTerm2 should support OSC 1337."""
        env = os.environ.copy()
        env['ITERM_SESSION_ID'] = 'test'
        rc, stdout, _ = source_detect_and_run(
            'supports_osc1337 && echo "yes" || echo "no"', env=env)
        assert stdout == "yes"

    def test_ghostty_does_not_support_osc1337(self):
        """Ghostty should NOT support OSC 1337."""
        env = os.environ.copy()
        env.pop('ITERM_SESSION_ID', None)
        env['GHOSTTY_RESOURCES_DIR'] = '/test'
        rc, stdout, _ = source_detect_and_run(
            'supports_osc1337 && echo "yes" || echo "no"', env=env)
        assert stdout == "no"

    def test_wezterm_supports_osc1337(self):
        """WezTerm should support OSC 1337 (partial)."""
        env = os.environ.copy()
        env.pop('ITERM_SESSION_ID', None)
        env.pop('GHOSTTY_RESOURCES_DIR', None)
        env['TERM_PROGRAM'] = 'WezTerm'
        rc, stdout, _ = source_detect_and_run(
            'supports_osc1337 && echo "yes" || echo "no"', env=env)
        assert stdout == "yes"


class TestShouldEnablePaletteTheming:
    """Test should_enable_palette_theming() function."""

    def test_disabled_when_false(self):
        """Should return false when explicitly disabled."""
        env = os.environ.copy()
        env['ENABLE_PALETTE_THEMING'] = 'false'
        rc, stdout, _ = source_detect_and_run(
            'should_enable_palette_theming && echo "yes" || echo "no"', env=env)
        assert stdout == "no"

    def test_enabled_when_true(self):
        """Should return true when explicitly enabled."""
        env = os.environ.copy()
        env['ENABLE_PALETTE_THEMING'] = 'true'
        rc, stdout, _ = source_detect_and_run(
            'should_enable_palette_theming && echo "yes" || echo "no"', env=env)
        assert stdout == "yes"

    def test_auto_disabled_in_truecolor(self):
        """Auto mode should disable in TrueColor."""
        env = os.environ.copy()
        env['ENABLE_PALETTE_THEMING'] = 'auto'
        env['COLORTERM'] = 'truecolor'
        rc, stdout, _ = source_detect_and_run(
            'should_enable_palette_theming && echo "yes" || echo "no"', env=env)
        assert stdout == "no"

    def test_auto_enabled_in_256color(self):
        """Auto mode should enable in 256-color mode."""
        env = os.environ.copy()
        env['ENABLE_PALETTE_THEMING'] = 'auto'
        env.pop('COLORTERM', None)
        env['TERM'] = 'xterm-256color'
        rc, stdout, _ = source_detect_and_run(
            'should_enable_palette_theming && echo "yes" || echo "no"', env=env)
        assert stdout == "yes"


class TestDetectSystemDarkMode:
    """Test detect_system_dark_mode() function."""

    def test_returns_code_not_string(self):
        """Should return exit code (0=dark, 1=light), not string."""
        # This function returns exit codes, not strings
        result = run_bash(
            '''
            source src/core/detect.sh
            detect_system_dark_mode
            echo $?
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        # Exit code should be 0, 1, or 2
        code = int(result.stdout.strip())
        assert code in [0, 1, 2]


class TestDetectShSyntax:
    """Test detect.sh syntax and structure."""

    def test_syntax_valid(self):
        """detect.sh should have valid bash syntax."""
        result = run_bash('bash -n src/core/detect.sh', cwd=PROJECT_ROOT)
        assert result.returncode == 0

    def test_can_be_sourced(self):
        """detect.sh should source without errors."""
        result = run_bash('source src/core/detect.sh && echo "OK"',
                         cwd=PROJECT_ROOT)
        assert result.returncode == 0
        assert "OK" in result.stdout
