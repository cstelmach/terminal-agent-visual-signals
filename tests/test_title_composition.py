"""
Tests for src/core/terminal.sh - Title composition with faces.

Verifies:
- send_osc_title() composes titles correctly
- Face position (before/after) works correctly
- Feature disabled shows no face
- Empty state parameter shows no face

Note: Tests use TAVS_AGENT=unknown to get fallback minimal faces.
The old FACE_THEME variable is deprecated; agent-specific faces are now used.
"""

import os
import pytest
from conftest import run_bash, PROJECT_ROOT


class TestTitleComposition:
    """Test send_osc_title() face composition logic.

    Uses TAVS_AGENT=unknown to get predictable fallback faces for testing.
    """

    def _run_send_osc_title(self, emoji: str, path: str, state: str = "",
                            enable: str = "false", theme: str = "minimal",
                            position: str = "after", tty_file: str = None,
                            agent: str = "unknown") -> str:
        """
        Helper to run send_osc_title and capture output.

        Args:
            agent: Agent type for face selection (default: "unknown" for fallback faces)

        Returns the title portion of the OSC sequence.
        """
        if tty_file is None:
            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
                tty_file = f.name

        env = {
            'TTY_DEVICE': tty_file,
            'TAVS_AGENT': agent,  # Use unknown agent for predictable fallback faces
        }

        # Build command with proper quoting
        # NOTE: We export ENABLE_ANTHROPOMORPHISING and FACE_POSITION AFTER sourcing
        # theme.sh because theme.sh loads defaults.conf which overwrites env vars
        state_arg = f' "{state}"' if state else ''
        cmd = f'''
            source src/core/theme.sh
            source src/core/terminal.sh
            # Override config variables after sourcing (defaults would overwrite env)
            export ENABLE_ANTHROPOMORPHISING="{enable}"
            export FACE_POSITION="{position}"
            send_osc_title "{emoji}" "{path}"{state_arg}
        '''

        result = run_bash(cmd, env=env)

        # Read the output file
        try:
            with open(tty_file, 'r') as f:
                content = f.read()
            # Extract title from OSC sequence: \033]0;TITLE\033\\
            if ']0;' in content and '\033\\' in content:
                start = content.index(']0;') + 3
                end = content.index('\033\\', start)
                return content[start:end]
            return content
        finally:
            try:
                os.unlink(tty_file)
            except FileNotFoundError:
                pass

    def test_feature_disabled_no_face(self):
        """When anthropomorphising is disabled, no face should appear."""
        title = self._run_send_osc_title(
            emoji="🟠",
            path="~/test",
            state="processing",
            enable="false"
        )

        assert "🟠" in title
        assert "~/test" in title
        assert "(°-°)" not in title  # No face

    def test_feature_enabled_position_after(self):
        """With position=after, face appears after emoji."""
        title = self._run_send_osc_title(
            emoji="🟠",
            path="~/test",
            state="processing",
            enable="true",
            position="after"
        )

        assert "🟠" in title
        assert "(°-°)" in title
        assert "~/test" in title
        # Check order: emoji before face
        emoji_pos = title.index("🟠")
        face_pos = title.index("(°-°)")
        assert emoji_pos < face_pos, f"Emoji should be before face in: {title}"

    def test_feature_enabled_position_before(self):
        """With position=before, face appears before emoji."""
        title = self._run_send_osc_title(
            emoji="🟠",
            path="~/test",
            state="processing",
            enable="true",
            position="before"
        )

        assert "🟠" in title
        assert "(°-°)" in title
        assert "~/test" in title
        # Check order: face before emoji
        face_pos = title.index("(°-°)")
        emoji_pos = title.index("🟠")
        assert face_pos < emoji_pos, f"Face should be before emoji in: {title}"

    def test_no_emoji_with_face(self):
        """When emoji is empty but face is enabled, only face shows."""
        title = self._run_send_osc_title(
            emoji="",
            path="~/test",
            state="processing",
            enable="true"
        )

        assert "(°-°)" in title
        assert "~/test" in title

    def test_no_state_parameter_no_face(self):
        """When state parameter is empty, no face should appear."""
        title = self._run_send_osc_title(
            emoji="🟠",
            path="~/test",
            state="",  # No state
            enable="true"
        )

        assert "🟠" in title
        assert "~/test" in title
        # No face should appear without state
        assert "(°-°)" not in title

    @pytest.mark.parametrize("agent,state,face_pattern", [
        # Unknown agent uses fallback minimal faces
        ("unknown", "processing", "(°-°)"),
        ("unknown", "permission", "(°□°)"),
        # Claude uses pincer faces - just verify it contains pincer markers
        ("claude", "processing", "Ǝ["),
        ("claude", "complete", "Ǝ["),
        # Gemini uses bear faces
        ("gemini", "processing", "ʕ"),
        ("gemini", "complete", "ʕ"),
    ])
    def test_different_agents(self, agent, state, face_pattern):
        """Different agents should show their respective face styles."""
        title = self._run_send_osc_title(
            emoji="🟠",
            path="~/test",
            state=state,
            enable="true",
            agent=agent
        )

        assert face_pattern in title, f"Expected '{face_pattern}' in title for {agent}: {title}"

    @pytest.mark.parametrize("state,expected_face", [
        ("processing", "(°-°)"),
        ("permission", "(°□°)"),
        ("complete", "(^‿^)"),
        ("compacting", "(@_@)"),  # Fixed: actual fallback is (@_@), not (°◡°)
        ("reset", "(-_-)"),
    ])
    def test_core_states(self, state, expected_face):
        """Core states should show correct fallback faces (unknown agent)."""
        title = self._run_send_osc_title(
            emoji="🟠",
            path="~/test",
            state=state,
            enable="true",
            agent="unknown"  # Use unknown agent for predictable fallback faces
        )

        assert expected_face in title, f"Expected '{expected_face}' for state '{state}'"


class TestSanitizeForTerminal:
    """Test the sanitize_for_terminal function."""

    def test_removes_control_characters(self):
        """Control characters should be stripped from input."""
        result = run_bash(
            '''
            source src/core/terminal.sh
            sanitize_for_terminal "hello$(printf '\\x00\\x01\\x1f')world"
            '''
        )

        assert result.returncode == 0
        output = result.stdout.strip()
        assert output == "helloworld"
        assert '\x00' not in output
        assert '\x01' not in output

    def test_preserves_unicode(self):
        """Unicode characters should be preserved."""
        result = run_bash(
            '''
            source src/core/terminal.sh
            sanitize_for_terminal "hello 🟠 world"
            '''
        )

        assert result.returncode == 0
        assert "🟠" in result.stdout


class TestGetShortCwd:
    """Test the get_short_cwd function."""

    def test_shortens_home_to_tilde(self):
        """Home directory should be shortened to ~."""
        result = run_bash(
            '''
            source src/core/terminal.sh
            cd ~
            get_short_cwd
            '''
        )

        assert result.returncode == 0
        output = result.stdout.strip()
        assert output.startswith("~") or output == "~"

    def test_deep_paths_are_shortened(self):
        """Deep paths should be shortened with ellipsis."""
        result = run_bash(
            '''
            source src/core/terminal.sh
            # Simulate a deep path
            export PWD="/Users/test/very/deep/nested/path"
            export HOME="/Users/test"
            get_short_cwd
            '''
        )

        assert result.returncode == 0
        output = result.stdout.strip()
        # Should contain ellipsis for deep paths
        assert "…" in output or len(output.split('/')) <= 3
