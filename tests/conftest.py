"""
Pytest configuration and shared fixtures for TAVS tests.

These tests verify the anthropomorphising feature (ASCII faces in terminal titles).
Uses subprocess to invoke bash scripts and verify their output.
"""

import os
import subprocess
import tempfile
from pathlib import Path

import pytest


# Project root directory
PROJECT_ROOT = Path(__file__).parent.parent

ISOLATION_KEYS = (
    'PATH', 'HOME', 'TMPDIR', 'CFFIXED_USER_HOME', 'ZDOTDIR',
    'TAVS_RUNTIME_DIR', 'TAVS_TMP_DIR', 'XDG_RUNTIME_DIR', 'XDG_CACHE_HOME',
    'TTY_DEVICE', 'TAVS_TEST_ROOT', 'TAVS_TEST_HELPER_BIN',
)


def _subprocess_env(overrides=None):
    if not os.environ.get('TAVS_TEST_ROOT'):
        raise RuntimeError('Run these tests through tests/run-isolated.sh.')
    env = os.environ.copy() if overrides is None else overrides.copy()
    for key in ISOLATION_KEYS:
        if key in os.environ:
            env.setdefault(key, os.environ[key])
    env['_TAVS_TMP_DIR'] = env['TAVS_TMP_DIR']
    return env


@pytest.fixture
def project_root():
    """Return the project root directory."""
    return PROJECT_ROOT


@pytest.fixture
def core_dir():
    """Return the src/core directory."""
    return PROJECT_ROOT / "src" / "core"


@pytest.fixture
def temp_tty_file():
    """Create a temporary file to capture TTY output."""
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
        yield f.name
    # Cleanup
    try:
        os.unlink(f.name)
    except FileNotFoundError:
        pass


@pytest.fixture
def bash_env():
    """Return base environment for bash subprocess calls."""
    env = _subprocess_env()
    # Ensure we're using a clean environment
    env['SHELL'] = '/bin/bash'
    return env


@pytest.fixture
def zsh_env():
    """Return base environment for zsh subprocess calls."""
    env = _subprocess_env()
    env['SHELL'] = '/bin/zsh'
    return env


@pytest.fixture
def clean_env():
    """Keep private paths while omitting feature and terminal-detection overrides."""
    return _subprocess_env({
        'PATH': os.environ.get('PATH', '/usr/bin:/bin'),
        'HOME': os.environ.get('HOME', '/tmp'),
        'SHELL': '/bin/bash',
    })


def run_bash(command: str, env: dict = None, cwd: Path = None, timeout: float = 5.0) -> subprocess.CompletedProcess:
    """
    Run a bash command and return the result.

    Args:
        command: Bash command to run
        env: Environment variables (defaults to current env)
        cwd: Working directory (defaults to project root)
        timeout: Command timeout in seconds

    Returns:
        CompletedProcess with stdout, stderr, returncode
    """
    env = _subprocess_env(env)
    if cwd is None:
        cwd = PROJECT_ROOT

    result = subprocess.run(
        ['bash', '-c', command],
        capture_output=True,
        text=True,
        env=env,
        cwd=cwd,
        timeout=timeout
    )
    return result


def run_zsh(command: str, env: dict = None, cwd: Path = None, timeout: float = 5.0) -> subprocess.CompletedProcess:
    """
    Run a command in zsh and return the result.

    This is critical for testing shell compatibility since Claude Code's
    Bash tool runs commands in zsh, not bash.

    Args:
        command: Zsh command to run
        env: Environment variables (defaults to current env)
        cwd: Working directory (defaults to project root)
        timeout: Command timeout in seconds

    Returns:
        CompletedProcess with stdout, stderr, returncode
    """
    env = _subprocess_env(env)
    if cwd is None:
        cwd = PROJECT_ROOT

    result = subprocess.run(
        ['zsh', '-c', command],
        capture_output=True,
        text=True,
        env=env,
        cwd=cwd,
        timeout=timeout
    )
    return result


def run_in_both_shells(command: str, env: dict = None, cwd: Path = None) -> dict:
    """
    Run command in both bash and zsh, return both results.

    Use this to verify shell compatibility - results should be identical
    for cross-shell compatible code.

    Args:
        command: Command to run in both shells
        env: Environment variables (defaults to current env)
        cwd: Working directory (defaults to project root)

    Returns:
        dict with 'bash' and 'zsh' keys containing CompletedProcess results
    """
    return {
        'bash': run_bash(command, env, cwd),
        'zsh': run_zsh(command, env, cwd)
    }


def source_and_run(script_path: str, command: str, env: dict = None) -> subprocess.CompletedProcess:
    """
    Source a bash script and run a command.

    Args:
        script_path: Path to script to source (relative to project root)
        command: Command to run after sourcing
        env: Environment variables

    Returns:
        CompletedProcess with stdout, stderr, returncode
    """
    full_command = f'source "{PROJECT_ROOT}/{script_path}" && {command}'
    return run_bash(full_command, env=env)


# All available themes
THEMES = ['minimal', 'bear', 'cat', 'lenny', 'shrug', 'plain']

# All core states
CORE_STATES = ['processing', 'permission', 'complete', 'compacting', 'reset']

# All idle states
IDLE_STATES = ['idle_0', 'idle_1', 'idle_2', 'idle_3', 'idle_4', 'idle_5']

# All states combined
ALL_STATES = CORE_STATES + IDLE_STATES


# Expected faces for verification (subset for quick validation)
EXPECTED_FACES = {
    ('minimal', 'processing'): '(°-°)',
    ('minimal', 'permission'): '(°□°)',
    ('minimal', 'complete'): '(^‿^)',
    ('minimal', 'idle_5'): '(︶.︶)ᶻᶻ',
    ('bear', 'processing'): 'ʕ•ᴥ•ʔ',
    ('bear', 'complete'): 'ʕ♥ᴥ♥ʔ',
    ('cat', 'processing'): 'ฅ^•ﻌ•^ฅ',
    ('plain', 'processing'): ':-|',
    ('plain', 'idle_5'): ':-(zzZ',
}
