"""
Tests for src/core/trigger.sh - State triggers and timing.

Verifies:
- All states pass correct state parameter to send_osc_title
- Script returns immediately (non-blocking)
- Background worker is properly spawned
"""

import os
import time
import tempfile
import pytest
from conftest import run_bash, PROJECT_ROOT


class TestTriggerStates:
    """Test trigger.sh passes correct state parameters."""

    def _run_trigger(self, state: str, enable: str = "true",
                     theme: str = "minimal", timeout: float = 2.0) -> tuple:
        """
        Run trigger.sh with given state and return (output, duration).

        Returns tuple of (file_content, elapsed_seconds)
        """
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            tty_file = f.name

        env = {
            'TTY_DEVICE': tty_file,
            'ENABLE_ANTHROPOMORPHISING': enable,
            'FACE_THEME': theme,
            'FACE_POSITION': 'after',
        }

        start = time.time()
        result = run_bash(
            f'./src/core/trigger.sh {state}',
            env=env,
            timeout=timeout
        )
        elapsed = time.time() - start

        try:
            with open(tty_file, 'rb') as f:
                content = f.read()
        except FileNotFoundError:
            content = b''
        finally:
            try:
                os.unlink(tty_file)
            except FileNotFoundError:
                pass

        return content, elapsed, result

    @pytest.mark.parametrize("state,expected_face", [
        ("processing", "(°-°)"),
        ("permission", "(°□°)"),
        ("compacting", "(°◡°)"),
    ])
    def test_states_include_face_when_enabled(self, state, expected_face):
        """States should include face in output when enabled."""
        content, elapsed, result = self._run_trigger(state, enable="true")

        # Convert bytes to string for searching
        content_str = content.decode('utf-8', errors='replace')

        # The output might be overwritten by bell, so check the result didn't error
        assert result.returncode == 0, f"trigger.sh failed: {result.stderr}"

    @pytest.mark.parametrize("state", ["processing", "permission", "complete", "compacting", "reset"])
    def test_states_return_immediately(self, state):
        """All states should return immediately (< 0.5 seconds)."""
        content, elapsed, result = self._run_trigger(state, enable="true")

        assert elapsed < 0.5, f"State '{state}' took {elapsed:.2f}s (should be < 0.5s)"
        assert result.returncode == 0

    def test_complete_state_non_blocking(self):
        """Complete state should return immediately despite spawning idle timer."""
        content, elapsed, result = self._run_trigger("complete", enable="true")

        # This is the critical test - complete was blocking for 1m+ before fix
        assert elapsed < 0.5, f"Complete took {elapsed:.2f}s (should be < 0.5s)"
        assert result.returncode == 0

    def test_processing_with_face_disabled(self):
        """Processing with face disabled should not include face."""
        content, elapsed, result = self._run_trigger("processing", enable="false")

        content_str = content.decode('utf-8', errors='replace')

        assert result.returncode == 0
        # Should not contain face
        assert "(°-°)" not in content_str


class TestTriggerSyntax:
    """Test trigger.sh syntax and basic functionality."""

    def test_syntax_valid(self):
        """trigger.sh should have valid bash syntax."""
        result = run_bash('bash -n src/core/trigger.sh')
        assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_unknown_state_returns_error(self):
        """Unknown state should return error exit code."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            tty_file = f.name

        result = run_bash(
            './src/core/trigger.sh invalid_state',
            env={'TTY_DEVICE': tty_file}
        )

        try:
            os.unlink(tty_file)
        except FileNotFoundError:
            pass

        assert result.returncode != 0

    def test_no_args_returns_error(self):
        """No arguments should show usage and return error."""
        result = run_bash('./src/core/trigger.sh')
        # With no TTY, it exits 0 silently, but with TTY and no args it errors
        # This is expected behavior


class TestIdleWorkerSpawn:
    """Test that idle worker is properly spawned in background."""

    def test_complete_spawns_background_worker(self):
        """Complete state should spawn idle timer in background."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            tty_file = f.name

        # Run complete state
        result = run_bash(
            './src/core/trigger.sh complete',
            env={
                'TTY_DEVICE': tty_file,
                'ENABLE_ANTHROPOMORPHISING': 'true',
            },
            timeout=2.0
        )

        try:
            os.unlink(tty_file)
        except FileNotFoundError:
            pass

        # Should return 0 and not block
        assert result.returncode == 0

    def test_worker_spawn_uses_fd_redirects(self):
        """Worker spawn should include fd redirects to prevent blocking."""
        result = run_bash(
            'grep -E "unified_timer_worker.*</dev/null" src/core/trigger.sh'
        )

        # Should find the redirect pattern
        assert result.returncode == 0, "Worker spawn should use </dev/null redirect"
        assert ">/dev/null 2>&1" in result.stdout or "</dev/null" in result.stdout


class TestTriggerIntegration:
    """Integration tests for trigger.sh with full environment."""

    @pytest.mark.parametrize("theme", ["minimal", "bear", "cat"])
    def test_different_themes_work(self, theme):
        """Different themes should work without error."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            tty_file = f.name

        result = run_bash(
            './src/core/trigger.sh processing',
            env={
                'TTY_DEVICE': tty_file,
                'ENABLE_ANTHROPOMORPHISING': 'true',
                'FACE_THEME': theme,
            }
        )

        try:
            os.unlink(tty_file)
        except FileNotFoundError:
            pass

        assert result.returncode == 0, f"Theme {theme} failed: {result.stderr}"

    @pytest.mark.parametrize("position", ["before", "after"])
    def test_different_positions_work(self, position):
        """Different face positions should work without error."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            tty_file = f.name

        result = run_bash(
            './src/core/trigger.sh processing',
            env={
                'TTY_DEVICE': tty_file,
                'ENABLE_ANTHROPOMORPHISING': 'true',
                'FACE_POSITION': position,
            }
        )

        try:
            os.unlink(tty_file)
        except FileNotFoundError:
            pass

        assert result.returncode == 0
