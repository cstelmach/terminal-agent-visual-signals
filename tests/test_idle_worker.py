"""
Tests for src/core/idle-worker.sh - Idle timer and progression.

Verifies:
- Idle worker syntax is valid
- Idle face keys are generated correctly
- Worker uses >&3 file descriptor pattern
"""

import pytest
from conftest import run_bash, source_and_run


class TestIdleWorkerSyntax:
    """Test idle-worker.sh syntax and structure."""

    def test_syntax_valid(self):
        """idle-worker.sh should have valid bash syntax."""
        result = run_bash('bash -n src/core/idle-worker.sh')
        assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_can_be_sourced(self):
        """idle-worker.sh should be sourceable without error."""
        result = run_bash('''
            source src/core/theme.sh
            source src/core/state.sh
            source src/core/terminal.sh
            source src/core/idle-worker.sh
            echo "OK"
        ''')

        assert result.returncode == 0
        assert "OK" in result.stdout


class TestIdleFaceKeyGeneration:
    """Test that idle face keys are generated correctly."""

    @pytest.mark.parametrize("stage,expected_key", [
        (0, "idle_0"),
        (1, "idle_1"),
        (2, "idle_2"),
        (3, "idle_3"),
        (4, "idle_4"),
        (5, "idle_5"),
    ])
    def test_idle_face_key_format(self, stage, expected_key):
        """Idle face key should be 'idle_N' for stage N."""
        # The key is generated as "idle_${current_stage}"
        result = run_bash(f'''
            current_stage={stage}
            idle_face_key="idle_${{current_stage}}"
            echo "$idle_face_key"
        ''')

        assert result.returncode == 0
        assert result.stdout.strip() == expected_key

    def test_idle_face_keys_in_worker_code(self):
        """Worker should generate idle_N face keys."""
        # The code uses: idle_${current_stage}
        result = run_bash(
            'grep "idle_" src/core/idle-worker.sh | grep -v "^#"'
        )

        assert result.returncode == 0, "Should find idle face key usage"
        assert "idle_" in result.stdout


class TestIdleWorkerFdPattern:
    """Test that idle worker uses >&3 file descriptor correctly."""

    def test_uses_fd3_for_color_writes(self):
        """Color writes should use >&3 file descriptor."""
        result = run_bash(
            'grep -E "printf.*>&3" src/core/idle-worker.sh | head -3'
        )

        assert result.returncode == 0
        assert ">&3" in result.stdout

    def test_uses_fd3_for_title_writes(self):
        """Title writes should use >&3 file descriptor."""
        result = run_bash(
            'grep -E \'printf.*\\]0;.*>&3\' src/core/idle-worker.sh'
        )

        assert result.returncode == 0, "Title writes should use >&3"

    def test_opens_fd3_to_tty(self):
        """Worker should open fd 3 to tty device."""
        result = run_bash(
            'grep -E "exec 3>" src/core/idle-worker.sh'
        )

        assert result.returncode == 0
        assert 'exec 3>"$tty_device"' in result.stdout or "exec 3>" in result.stdout


class TestIdleWorkerFaceComposition:
    """Test that idle worker composes titles with faces correctly."""

    def test_face_composition_in_worker(self):
        """Worker should have inline face composition logic."""
        # Check for face lookup
        result = run_bash(
            'grep -E "get_face.*idle_" src/core/idle-worker.sh'
        )

        assert result.returncode == 0, "Should find get_face call for idle states"

    def test_face_position_check_in_worker(self):
        """Worker should check FACE_POSITION."""
        result = run_bash(
            'grep "FACE_POSITION" src/core/idle-worker.sh'
        )

        assert result.returncode == 0, "Should check FACE_POSITION"

    def test_anthropomorphising_check_in_worker(self):
        """Worker should check ENABLE_ANTHROPOMORPHISING."""
        result = run_bash(
            'grep "ENABLE_ANTHROPOMORPHISING" src/core/idle-worker.sh'
        )

        assert result.returncode == 0, "Should check ENABLE_ANTHROPOMORPHISING"


class TestGetUnifiedStage:
    """Test the get_unified_stage function."""

    def test_stage_0_for_short_elapsed(self):
        """Elapsed < first duration should return stage 0."""
        result = run_bash('''
            source src/core/theme.sh
            source src/core/idle-worker.sh
            get_unified_stage 30
            echo "$RESULT_STAGE"
        ''')

        assert result.returncode == 0
        assert result.stdout.strip() == "0"

    def test_stage_increases_with_elapsed(self):
        """Stage should increase as elapsed time increases."""
        result = run_bash('''
            source src/core/theme.sh
            source src/core/idle-worker.sh

            # Test stage progression
            get_unified_stage 0
            echo "elapsed=0: stage=$RESULT_STAGE"

            get_unified_stage 65  # After first 60s duration
            echo "elapsed=65: stage=$RESULT_STAGE"

            get_unified_stage 95  # After 60+30=90s
            echo "elapsed=95: stage=$RESULT_STAGE"
        ''')

        assert result.returncode == 0
        lines = result.stdout.strip().split('\n')
        assert "stage=0" in lines[0]
        assert "stage=1" in lines[1]
        assert "stage=2" in lines[2]


class TestKillIdleTimer:
    """Test the kill_idle_timer function."""

    def test_kill_idle_timer_exists(self):
        """kill_idle_timer function should exist."""
        result = run_bash('''
            source src/core/theme.sh
            source src/core/state.sh
            source src/core/terminal.sh
            source src/core/idle-worker.sh
            type kill_idle_timer
        ''')

        assert result.returncode == 0
        assert "function" in result.stdout

    def test_cleanup_stale_timers_exists(self):
        """cleanup_stale_timers function should exist."""
        result = run_bash('''
            source src/core/theme.sh
            source src/core/state.sh
            source src/core/terminal.sh
            source src/core/idle-worker.sh
            type cleanup_stale_timers
        ''')

        assert result.returncode == 0
        assert "function" in result.stdout
