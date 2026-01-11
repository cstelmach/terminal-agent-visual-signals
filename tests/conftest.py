"""
Pytest configuration and shared fixtures for terminal-agent-visual-signals tests.

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
    env = os.environ.copy()
    # Ensure we're using a clean environment
    env['SHELL'] = '/bin/bash'
    return env


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
    if env is None:
        env = os.environ.copy()
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
