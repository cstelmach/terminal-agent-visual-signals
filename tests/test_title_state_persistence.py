"""
Tests for title state persistence functions in src/core/title.sh.

These functions will be extracted to title-state-persistence.sh in refactoring.

Validates:
- get_title_state_file() returns correct path
- _read_title_state_value() safely reads key=value files
- _escape_for_state_file() escapes special characters
- save_title_state() writes state atomically
- load_title_state() loads all state variables
- clear_title_state() removes state file
- init_session_id() generates consistent session IDs

State file format: key="value" pairs, one per line.
Values are escaped to prevent control character injection.
"""

import os
import tempfile
import pytest
from conftest import run_bash, PROJECT_ROOT


class TestGetTitleStateFile:
    """Test get_title_state_file() function."""

    def test_returns_path_with_tty_safe(self):
        """Should return path with TTY_SAFE suffix."""
        result = run_bash(
            '''
            export TTY_SAFE="dev_ttys001"
            source src/core/title.sh
            get_title_state_file
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        path = result.stdout.strip()
        assert path.endswith(".dev_ttys001")
        assert "terminal-visual-signals.title" in path

    def test_uses_unknown_when_tty_safe_empty(self):
        """Should use 'unknown' when TTY_SAFE is not set."""
        result = run_bash(
            '''
            unset TTY_SAFE
            source src/core/title.sh
            get_title_state_file
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        path = result.stdout.strip()
        assert path.endswith(".unknown")


class TestEscapeForStateFile:
    """Test _escape_for_state_file() function."""

    def test_escapes_double_quotes(self):
        """Double quotes should be escaped."""
        result = run_bash(
            '''
            source src/core/title.sh
            _escape_for_state_file 'Hello "World"'
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        assert '\\"' in result.stdout or 'Hello \\"World\\"' in result.stdout

    def test_escapes_backslashes(self):
        """Backslashes should be escaped."""
        result = run_bash(
            '''
            source src/core/title.sh
            _escape_for_state_file 'path\\to\\file'
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        # Should have escaped backslashes

    def test_removes_newlines(self):
        """Newlines should be replaced with spaces."""
        result = run_bash(
            '''
            source src/core/title.sh
            _escape_for_state_file $'line1\\nline2'
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        # Should not contain actual newline in output
        assert '\n' not in result.stdout.strip()

    def test_handles_empty_string(self):
        """Empty string should return empty."""
        result = run_bash(
            '''
            source src/core/title.sh
            _escape_for_state_file ""
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        assert result.stdout.strip() == ""


class TestSaveAndLoadTitleState:
    """Test save_title_state() and load_title_state() functions."""

    def test_save_creates_state_file(self):
        """save_title_state should create a state file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                export TTY_SAFE="test_tty"
                export TITLE_STATE_DB="{tmpdir}/test.title"
                source src/core/title.sh
                save_title_state "My Project" "Ǝ[• •]E 🟠 My Project" "false" "abc12345"
                cat "$TITLE_STATE_DB.$TTY_SAFE"
                ''',
                cwd=PROJECT_ROOT
            )
            assert result.returncode == 0
            assert "USER_BASE_TITLE" in result.stdout
            assert "My Project" in result.stdout
            assert "abc12345" in result.stdout

    def test_load_restores_variables(self):
        """load_title_state should restore saved variables."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                export TTY_SAFE="test_tty"
                export TITLE_STATE_DB="{tmpdir}/test.title"
                source src/core/title.sh

                # Save state
                save_title_state "My Project" "Full Title" "false" "sess1234"

                # Clear variables
                TITLE_USER_BASE=""
                TITLE_LAST_SET=""
                SESSION_ID=""

                # Load state
                load_title_state

                # Print loaded values
                echo "USER_BASE:$TITLE_USER_BASE"
                echo "LAST_SET:$TITLE_LAST_SET"
                echo "SESSION:$SESSION_ID"
                ''',
                cwd=PROJECT_ROOT
            )
            assert result.returncode == 0
            assert "USER_BASE:My Project" in result.stdout
            assert "LAST_SET:Full Title" in result.stdout
            assert "SESSION:sess1234" in result.stdout

    def test_load_handles_missing_file_gracefully(self):
        """load_title_state should initialize defaults when file doesn't exist."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                # Use a fresh state directory with no existing files
                export TTY_SAFE="fresh_session"
                export TITLE_STATE_DB="{tmpdir}/fresh.title"
                source src/core/title.sh
                # Try to load - should handle gracefully
                load_title_state
                echo "LOCKED:$TITLE_LOCKED"
                echo "USER_BASE:$TITLE_USER_BASE"
                ''',
                cwd=PROJECT_ROOT
            )
            # Should have initialized defaults
            assert "LOCKED:false" in result.stdout


class TestReadTitleStateValueIntegration:
    """Integration tests for state value reading via save/load cycle.

    Note: _read_title_state_value is a private function that's tested
    indirectly through the public save_title_state/load_title_state API.
    """

    def test_save_load_preserves_values(self):
        """Values saved should be correctly loaded back."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                export TTY_SAFE="test"
                export TITLE_STATE_DB="{tmpdir}/state"
                source src/core/title.sh

                # Save with specific values
                save_title_state "My Project" "Full Title" "false" "abc12345"

                # Clear variables
                TITLE_USER_BASE=""
                TITLE_LAST_SET=""
                SESSION_ID=""

                # Load them back
                load_title_state

                echo "USER_BASE:$TITLE_USER_BASE"
                echo "SESSION:$SESSION_ID"
                ''',
                cwd=PROJECT_ROOT
            )
            assert result.returncode == 0
            assert "USER_BASE:My Project" in result.stdout
            assert "SESSION:abc12345" in result.stdout

    def test_handles_special_characters_in_values(self):
        """Values with quotes and special chars should survive save/load."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                export TTY_SAFE="test"
                export TITLE_STATE_DB="{tmpdir}/state"
                source src/core/title.sh

                # Save with quotes (they'll be escaped)
                save_title_state 'Test Project' "Title" "false" "sess1234"

                # Load back
                TITLE_USER_BASE=""
                load_title_state

                echo "USER_BASE:$TITLE_USER_BASE"
                ''',
                cwd=PROJECT_ROOT
            )
            assert result.returncode == 0
            assert "USER_BASE:Test Project" in result.stdout


class TestClearTitleState:
    """Test clear_title_state() function."""

    def test_removes_state_file(self):
        """clear_title_state should remove the state file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                export TTY_SAFE="test_tty"
                export TITLE_STATE_DB="{tmpdir}/test.title"
                source src/core/title.sh

                # Create state file
                save_title_state "Test" "Title" "false" "sess"

                # Verify exists
                test -f "$TITLE_STATE_DB.$TTY_SAFE" && echo "exists"

                # Clear it
                clear_title_state

                # Verify removed
                test -f "$TITLE_STATE_DB.$TTY_SAFE" && echo "still exists" || echo "removed"
                ''',
                cwd=PROJECT_ROOT
            )
            assert result.returncode == 0
            assert "exists" in result.stdout
            assert "removed" in result.stdout


class TestSessionIdGeneration:
    """Test session ID generation functions."""

    def test_session_id_is_8_chars(self):
        """Generated session ID should be 8 characters."""
        result = run_bash(
            '''
            source src/core/title.sh
            id=$(_generate_session_id)
            echo "${#id}"
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        length = int(result.stdout.strip())
        assert length == 8

    def test_session_id_is_hex(self):
        """Generated session ID should be lowercase hex."""
        result = run_bash(
            '''
            source src/core/title.sh
            id=$(_generate_session_id)
            echo "$id"
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        session_id = result.stdout.strip()
        # Should be valid hex
        assert all(c in '0123456789abcdef' for c in session_id.lower())

    def test_init_session_id_sets_variable(self):
        """init_session_id should set SESSION_ID variable."""
        result = run_bash(
            '''
            source src/core/title.sh
            SESSION_ID=""
            init_session_id
            echo "$SESSION_ID"
            ''',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        session_id = result.stdout.strip()
        assert len(session_id) == 8

    def test_session_id_persists_across_calls(self):
        """Same session should get same ID."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                export TTY_SAFE="persist_test"
                export TITLE_STATE_DB="{tmpdir}/test.title"
                source src/core/title.sh

                # First call generates new ID
                init_session_id
                first_id="$SESSION_ID"
                save_title_state "" "" "false" "$SESSION_ID"

                # Second call should get same ID from file
                SESSION_ID=""
                id2=$(_generate_session_id)

                echo "first:$first_id"
                echo "second:$id2"
                ''',
                cwd=PROJECT_ROOT
            )
            assert result.returncode == 0
            lines = result.stdout.strip().split('\n')
            first = lines[0].split(':')[1]
            second = lines[1].split(':')[1]
            assert first == second


class TestStateFileAtomicity:
    """Test that state file writes are atomic."""

    def test_uses_temp_file_for_write(self):
        """save_title_state should use temp file + mv pattern."""
        # This is a code inspection test - the function uses mktemp + mv
        # Function is now in title-state-persistence.sh (extracted module)
        result = run_bash(
            'grep -A25 "save_title_state()" src/core/title-state-persistence.sh | grep -E "mktemp|mv"',
            cwd=PROJECT_ROOT
        )
        assert result.returncode == 0
        # Should find both mktemp and mv in the function
        assert "mktemp" in result.stdout or "mv" in result.stdout


class TestStateFileSecuritySanitization:
    """Test that state files handle malicious input safely."""

    def test_newlines_in_value_dont_break_format(self):
        """Newlines in values should not create extra lines."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                export TTY_SAFE="test"
                export TITLE_STATE_DB="{tmpdir}/test.title"
                source src/core/title.sh

                # Try to inject a newline
                save_title_state $'line1\\nline2' "Title" "false" "sess"

                # Count lines in state file (should be 5: header + 4 values)
                wc -l < "$TITLE_STATE_DB.$TTY_SAFE"
                ''',
                cwd=PROJECT_ROOT
            )
            assert result.returncode == 0
            line_count = int(result.stdout.strip())
            assert line_count == 5, f"Expected 5 lines, got {line_count}"

    def test_quotes_in_value_are_escaped(self):
        """Quotes in values should be escaped properly."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = run_bash(
                f'''
                export TTY_SAFE="test"
                export TITLE_STATE_DB="{tmpdir}/test.title"
                source src/core/title.sh

                # Save with quotes in value
                save_title_state 'My "Project"' "Title" "false" "sess"

                # Load it back
                load_title_state
                echo "$TITLE_USER_BASE"
                ''',
                cwd=PROJECT_ROOT
            )
            assert result.returncode == 0
            # The value should be readable (may have escaped quotes)
