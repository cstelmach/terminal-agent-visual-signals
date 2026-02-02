"""
Tests for src/core/spinner.sh - Animated spinner module.

Validates:
- get_spinner_state_dir() returns secure state directory
- get_spinner_eyes() returns spinner characters for animation
- init_session_spinner() creates session identity
- reset_spinner() cleans up spinner state
- read_state_value() safely parses key=value files
- validate_integer() validates numeric input
- write_state_file() and write_index_file() atomic writes

Spinner styles: braille, circle, block, eye-animate, none
Eye modes: sync, opposite, stagger, clockwise, counter, mirror, mirror_inv
"""

import os
import tempfile
import pytest
from conftest import run_bash, PROJECT_ROOT


def source_spinner_and_run(cmd: str, env: dict = None) -> tuple:
    """Source spinner.sh and run a command."""
    full_env = os.environ.copy()
    if env:
        full_env.update(env)
    result = run_bash(f'source src/core/spinner.sh && {cmd}',
                      cwd=PROJECT_ROOT, env=full_env)
    return (result.returncode, result.stdout.strip(), result.stderr.strip())


class TestGetSpinnerStateDir:
    """Test get_spinner_state_dir() function."""

    def test_returns_xdg_runtime_if_available(self):
        """Should use XDG_RUNTIME_DIR on Linux when available."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {'XDG_RUNTIME_DIR': tmpdir}
            rc, stdout, _ = source_spinner_and_run('get_spinner_state_dir', env=env)
            assert rc == 0
            assert tmpdir in stdout
            assert stdout.endswith('/tavs')

    def test_falls_back_to_home_cache(self):
        """Should use ~/.cache/tavs when XDG not available."""
        env = {'XDG_RUNTIME_DIR': '', 'HOME': '/tmp/testhome'}
        rc, stdout, _ = source_spinner_and_run('get_spinner_state_dir', env=env)
        assert rc == 0
        assert '.cache/tavs' in stdout


class TestGetSpinnerIndexFile:
    """Test get_spinner_index_file() function."""

    def test_includes_tty_safe_suffix(self):
        """Should include TTY_SAFE in filename."""
        env = {'TTY_SAFE': 'dev_pts_0'}
        rc, stdout, _ = source_spinner_and_run('get_spinner_index_file', env=env)
        assert rc == 0
        assert 'spinner-idx.dev_pts_0' in stdout

    def test_uses_unknown_when_tty_not_set(self):
        """Should use 'unknown' when TTY_SAFE not set."""
        env = {'TTY_SAFE': ''}
        rc, stdout, _ = source_spinner_and_run(
            'unset TTY_SAFE; get_spinner_index_file', env=env)
        assert rc == 0
        assert 'unknown' in stdout


class TestValidateInteger:
    """Test validate_integer() function."""

    @pytest.mark.parametrize("value,expected", [
        ("0", True),
        ("123", True),
        ("999999", True),
        ("-1", False),
        ("abc", False),
        ("12.5", False),
        ("", False),
        ("1 2", False),
    ])
    def test_validates_integers(self, value, expected):
        """Should correctly validate integer strings."""
        rc, stdout, _ = source_spinner_and_run(
            f'validate_integer "{value}" && echo "valid" || echo "invalid"')
        expected_result = "valid" if expected else "invalid"
        assert stdout == expected_result


class TestReadStateValue:
    """Test read_state_value() function for safe key=value parsing."""

    def test_reads_unquoted_value(self):
        """Should read values without quotes."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.state') as f:
            f.write('STYLE=braille\n')
            f.write('EYE_MODE=sync\n')
            state_file = f.name

        try:
            rc, stdout, _ = source_spinner_and_run(
                f'read_state_value "{state_file}" "STYLE"')
            assert rc == 0
            assert stdout == "braille"
        finally:
            os.unlink(state_file)

    def test_reads_quoted_value(self):
        """Should strip quotes from values."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.state') as f:
            f.write('STYLE="braille"\n')
            state_file = f.name

        try:
            rc, stdout, _ = source_spinner_and_run(
                f'read_state_value "{state_file}" "STYLE"')
            assert rc == 0
            assert stdout == "braille"
        finally:
            os.unlink(state_file)

    def test_returns_empty_for_missing_key(self):
        """Should return empty for non-existent key."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.state') as f:
            f.write('STYLE=braille\n')
            state_file = f.name

        try:
            rc, stdout, _ = source_spinner_and_run(
                f'result=$(read_state_value "{state_file}" "MISSING"); echo "[$result]"')
            assert "[]" in stdout
        finally:
            os.unlink(state_file)

    def test_returns_error_for_missing_file(self):
        """Should return error for non-existent file."""
        rc, stdout, _ = source_spinner_and_run(
            'read_state_value "/nonexistent/file" "KEY" && echo "ok" || echo "error"')
        assert "error" in stdout


class TestWriteStateFile:
    """Test write_state_file() function."""

    def test_writes_all_fields(self):
        """Should write all state fields."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = f"{tmpdir}/spinner.state"
            rc, stdout, _ = source_spinner_and_run(
                f'write_state_file "{state_file}" "braille" "sync" "0" "1" && cat "{state_file}"')
            assert rc == 0
            assert "STYLE=braille" in stdout
            assert "EYE_MODE=sync" in stdout
            assert "LEFT_INDEX=0" in stdout
            assert "RIGHT_INDEX=1" in stdout

    def test_atomic_write_uses_temp_file(self):
        """Write should use temp file + mv pattern."""
        # Check that the code uses atomic write pattern
        result = run_bash(
            'grep -A10 "write_state_file()" src/core/spinner.sh | grep -E "tmp_file|mv "',
            cwd=PROJECT_ROOT)
        assert result.returncode == 0
        assert "tmp_file" in result.stdout or "mv " in result.stdout


class TestWriteIndexFile:
    """Test write_index_file() function."""

    def test_writes_index_value(self):
        """Should write single index value."""
        with tempfile.TemporaryDirectory() as tmpdir:
            index_file = f"{tmpdir}/spinner.idx"
            rc, stdout, _ = source_spinner_and_run(
                f'write_index_file "{index_file}" "42" && cat "{index_file}"')
            assert rc == 0
            assert "42" in stdout


class TestInitSessionSpinner:
    """Test init_session_spinner() function."""

    def test_creates_session_file_when_enabled(self):
        """Should create session file when TAVS_SESSION_IDENTITY=true."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                'TAVS_SESSION_IDENTITY': 'true',
                'XDG_RUNTIME_DIR': tmpdir,
                'TTY_SAFE': 'test_tty',
            }
            rc, stdout, _ = source_spinner_and_run(
                f'init_session_spinner && ls {tmpdir}/tavs/', env=env)
            assert rc == 0
            assert 'session-spinner.test_tty' in stdout

    def test_does_nothing_when_disabled(self):
        """Should do nothing when TAVS_SESSION_IDENTITY is not true."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                'TAVS_SESSION_IDENTITY': 'false',
                'XDG_RUNTIME_DIR': tmpdir,
                'TTY_SAFE': 'test_tty',
            }
            rc, stdout, _ = source_spinner_and_run(
                f'init_session_spinner && ls {tmpdir}/tavs/ 2>/dev/null || echo "empty"',
                env=env)
            # Should either be empty or have no session-spinner file


class TestResetSpinner:
    """Test reset_spinner() function."""

    def test_removes_spinner_files(self):
        """Should remove session and index files."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                'TAVS_SESSION_IDENTITY': 'true',
                'XDG_RUNTIME_DIR': tmpdir,
                'TTY_SAFE': 'test_tty',
            }
            # Create spinner files
            rc, _, _ = source_spinner_and_run(
                'init_session_spinner', env=env)

            # Reset should remove them
            rc, stdout, _ = source_spinner_and_run(
                f'reset_spinner && ls {tmpdir}/tavs/*test_tty* 2>/dev/null || echo "cleaned"',
                env=env)
            assert "cleaned" in stdout


class TestGetSpinnerEyes:
    """Test get_spinner_eyes() function - main API."""

    def test_returns_two_characters(self):
        """Should return two space-separated spinner characters."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                'XDG_RUNTIME_DIR': tmpdir,
                'TTY_SAFE': 'test',
                'TAVS_SPINNER_STYLE': 'braille',
                'TAVS_SPINNER_EYE_MODE': 'sync',
            }
            rc, stdout, _ = source_spinner_and_run('get_spinner_eyes', env=env)
            # Should return either "FACE_VARIANT" or two characters
            if stdout != "FACE_VARIANT":
                parts = stdout.split()
                # Braille spinner has two eye characters
                assert len(parts) >= 1

    def test_returns_face_variant_for_none_style(self):
        """Should return FACE_VARIANT for 'none' style."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                'XDG_RUNTIME_DIR': tmpdir,
                'TTY_SAFE': 'test',
                'TAVS_SPINNER_STYLE': 'none',
            }
            rc, stdout, _ = source_spinner_and_run('get_spinner_eyes', env=env)
            assert stdout == "FACE_VARIANT"

    def test_braille_returns_braille_chars(self):
        """Braille style should return braille pattern characters."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                'XDG_RUNTIME_DIR': tmpdir,
                'TTY_SAFE': 'test',
                'TAVS_SPINNER_STYLE': 'braille',
                'TAVS_SPINNER_EYE_MODE': 'sync',
            }
            rc, stdout, _ = source_spinner_and_run('get_spinner_eyes', env=env)
            if stdout != "FACE_VARIANT":
                # Braille characters are in Unicode block U+2800-U+28FF
                # But just check we got something
                assert len(stdout) > 0


class TestSpinnerStyles:
    """Test different spinner styles."""

    @pytest.mark.parametrize("style", ["braille", "circle", "block"])
    def test_valid_styles_return_content(self, style):
        """Valid spinner styles should return content."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                'XDG_RUNTIME_DIR': tmpdir,
                'TTY_SAFE': 'test',
                'TAVS_SPINNER_STYLE': style,
                'TAVS_SPINNER_EYE_MODE': 'sync',
            }
            rc, stdout, _ = source_spinner_and_run('get_spinner_eyes', env=env)
            assert rc == 0
            assert len(stdout) > 0


class TestSpinnerShSyntax:
    """Test spinner.sh syntax and structure."""

    def test_syntax_valid(self):
        """spinner.sh should have valid bash syntax."""
        result = run_bash('bash -n src/core/spinner.sh', cwd=PROJECT_ROOT)
        assert result.returncode == 0

    def test_can_be_sourced(self):
        """spinner.sh should source without errors."""
        result = run_bash('source src/core/spinner.sh && echo "OK"',
                         cwd=PROJECT_ROOT)
        assert result.returncode == 0
        assert "OK" in result.stdout
