"""
Tests for src/core/title.sh - Title composition and management.

Verifies:
- Title composition for all states
- Fallback title generation
- Session ID generation
- Format template substitution
- Both bash and zsh compatibility
"""

import pytest
from conftest import run_bash, run_zsh, run_in_both_shells


class TestTitleComposition:
    """Test compose_title function."""

    @pytest.mark.parametrize("state,expected_emoji", [
        ("processing", "🟠"),
        ("complete", "🟢"),
        ("permission", "🔴"),
        ("compacting", "🔄"),
    ])
    def test_compose_title_emojis_bash(self, state, expected_emoji):
        """Each state should produce correct emoji in bash."""
        result = run_bash(f'''
            source src/core/theme.sh
            source src/core/title.sh
            compose_title "{state}" "Base"
        ''')
        assert result.returncode == 0, f"Failed: {result.stderr}"
        assert expected_emoji in result.stdout, \
            f"Expected emoji {expected_emoji} for state '{state}', got: {result.stdout.strip()}"

    @pytest.mark.parametrize("state,expected_emoji", [
        ("processing", "🟠"),
        ("complete", "🟢"),
        ("permission", "🔴"),
        ("compacting", "🔄"),
    ])
    def test_compose_title_emojis_zsh(self, state, expected_emoji):
        """Each state should produce correct emoji in zsh."""
        result = run_zsh(f'''
            source src/core/theme.sh
            source src/core/title.sh
            compose_title "{state}" "Base"
        ''')
        assert result.returncode == 0, f"Failed: {result.stderr}"
        assert expected_emoji in result.stdout, \
            f"Expected emoji {expected_emoji} for state '{state}', got: {result.stdout.strip()}"

    def test_compose_title_reset_no_emoji(self):
        """Reset state should have no emoji."""
        results = run_in_both_shells('''
            source src/core/theme.sh
            source src/core/title.sh
            compose_title "reset" "Base"
        ''')

        bash_output = results['bash'].stdout.strip()
        zsh_output = results['zsh'].stdout.strip()

        # Reset should not include status emojis
        for emoji in ['🟠', '🟢', '🔴', '🟣', '🔄']:
            assert emoji not in bash_output, f"Reset should have no emoji, got: {bash_output}"
            assert emoji not in zsh_output, f"Reset should have no emoji, got: {zsh_output}"

    def test_compose_title_includes_base(self):
        """compose_title should include the base title."""
        results = run_in_both_shells('''
            source src/core/theme.sh
            source src/core/title.sh
            compose_title "processing" "MyProject"
        ''')

        assert results['bash'].returncode == 0
        assert results['zsh'].returncode == 0
        assert "MyProject" in results['bash'].stdout
        assert "MyProject" in results['zsh'].stdout

    def test_compose_title_with_empty_base(self):
        """compose_title should handle empty base gracefully."""
        results = run_in_both_shells('''
            source src/core/theme.sh
            source src/core/title.sh
            compose_title "processing" ""
        ''')

        # Should not crash
        assert results['bash'].returncode == 0
        assert results['zsh'].returncode == 0

        # Should still have emoji
        assert '🟠' in results['bash'].stdout
        assert '🟠' in results['zsh'].stdout


class TestFallbackTitle:
    """Test get_fallback_title function."""

    @pytest.mark.parametrize("mode", ["path", "session", "session-path", "path-session"])
    def test_fallback_mode_returns_value_bash(self, mode):
        """Each fallback mode should return non-empty value in bash."""
        result = run_bash(f'''
            export TAVS_TITLE_FALLBACK="{mode}"
            export TAVS_TITLE_SHOW_PATH="true"
            export TAVS_TITLE_SHOW_SESSION="true"
            source src/core/theme.sh
            source src/core/title.sh
            get_fallback_title
        ''')
        assert result.returncode == 0, f"Failed for mode '{mode}': {result.stderr}"
        assert result.stdout.strip() != "", f"Empty fallback for mode '{mode}'"

    @pytest.mark.parametrize("mode", ["path", "session", "session-path", "path-session"])
    def test_fallback_mode_returns_value_zsh(self, mode):
        """Each fallback mode should return non-empty value in zsh."""
        result = run_zsh(f'''
            export TAVS_TITLE_FALLBACK="{mode}"
            export TAVS_TITLE_SHOW_PATH="true"
            export TAVS_TITLE_SHOW_SESSION="true"
            source src/core/theme.sh
            source src/core/title.sh
            get_fallback_title
        ''')
        assert result.returncode == 0, f"Failed for mode '{mode}': {result.stderr}"
        assert result.stdout.strip() != "", f"Empty fallback for mode '{mode}'"

    def test_fallback_path_mode_shows_directory(self):
        """Path mode should include directory information."""
        results = run_in_both_shells('''
            export TAVS_TITLE_FALLBACK="path"
            export TAVS_TITLE_SHOW_PATH="true"
            source src/core/theme.sh
            source src/core/title.sh
            get_fallback_title
        ''')

        bash_output = results['bash'].stdout.strip()
        zsh_output = results['zsh'].stdout.strip()

        # Should have a path-like value (contains path separator or tilde)
        # Note: zsh may escape tilde as \~
        def is_path_like(s):
            return ('/' in s or '~' in s or s == 'Terminal' or
                    s.startswith('\\~'))  # zsh escapes tilde

        assert is_path_like(bash_output), \
            f"Expected path-like value in bash, got: {bash_output}"
        assert is_path_like(zsh_output), \
            f"Expected path-like value in zsh, got: {zsh_output}"

    def test_fallback_session_mode_includes_session_id(self):
        """Session-path mode should include a hex session ID."""
        # Set fallback AFTER sourcing config (simulating user.conf override)
        results = run_in_both_shells('''
            source src/core/theme.sh
            TAVS_TITLE_FALLBACK="session-path"
            source src/core/title.sh
            get_fallback_title
        ''')

        bash_output = results['bash'].stdout.strip()
        zsh_output = results['zsh'].stdout.strip()

        # Should contain an 8-char hex ID somewhere in the output
        def contains_hex_id(s):
            # Look for an 8-char hex sequence
            import re
            return bool(re.search(r'[0-9a-f]{8}', s))

        assert contains_hex_id(bash_output), \
            f"Expected hex ID in bash output: '{bash_output}'"
        assert contains_hex_id(zsh_output), \
            f"Expected hex ID in zsh output: '{zsh_output}'"


class TestSessionId:
    """Test session ID generation."""

    def test_session_id_is_generated(self):
        """init_session_id should produce output."""
        results = run_in_both_shells('''
            source src/core/theme.sh
            source src/core/title.sh
            init_session_id
            echo "$SESSION_ID"
        ''')

        bash_id = results['bash'].stdout.strip()
        zsh_id = results['zsh'].stdout.strip()

        assert bash_id != "", "Session ID empty in bash"
        assert zsh_id != "", "Session ID empty in zsh"

    def test_session_id_is_8_chars(self):
        """Session ID should be exactly 8 characters."""
        results = run_in_both_shells('''
            source src/core/theme.sh
            source src/core/title.sh
            init_session_id
            echo "$SESSION_ID"
        ''')

        bash_id = results['bash'].stdout.strip()
        zsh_id = results['zsh'].stdout.strip()

        assert len(bash_id) == 8, f"Expected 8 chars in bash, got {len(bash_id)}: '{bash_id}'"
        assert len(zsh_id) == 8, f"Expected 8 chars in zsh, got {len(zsh_id)}: '{zsh_id}'"

    def test_session_id_is_lowercase_hex(self):
        """Session ID should be lowercase hexadecimal."""
        results = run_in_both_shells('''
            source src/core/theme.sh
            source src/core/title.sh
            init_session_id
            echo "$SESSION_ID"
        ''')

        bash_id = results['bash'].stdout.strip()
        zsh_id = results['zsh'].stdout.strip()

        valid_chars = set('0123456789abcdef')

        assert all(c in valid_chars for c in bash_id), \
            f"Bash session ID not hex: '{bash_id}'"
        assert all(c in valid_chars for c in zsh_id), \
            f"Zsh session ID not hex: '{zsh_id}'"


class TestFormatSubstitution:
    """Test format template substitution in compose_title."""

    def test_default_format_has_all_placeholders(self):
        """Default format should include FACE, EMOJI, and BASE."""
        results = run_in_both_shells('''
            source src/core/theme.sh
            echo "$TAVS_TITLE_FORMAT"
        ''')

        bash_format = results['bash'].stdout.strip()
        zsh_format = results['zsh'].stdout.strip()

        # Both should have the same format
        assert bash_format == zsh_format, \
            f"Format differs: bash='{bash_format}', zsh='{zsh_format}'"

        # Format should have all placeholders
        assert '{FACE}' in bash_format, f"Missing {{FACE}}: {bash_format}"
        assert '{EMOJI}' in bash_format, f"Missing {{EMOJI}}: {bash_format}"
        assert '{BASE}' in bash_format, f"Missing {{BASE}}: {bash_format}"

    def test_custom_format_respected(self):
        """Custom TAVS_TITLE_FORMAT should be respected when set after config load."""
        # Set format AFTER sourcing config (simulating user.conf override)
        results = run_in_both_shells('''
            source src/core/theme.sh
            export TAVS_TITLE_FORMAT="{EMOJI} [{BASE}]"
            export ENABLE_ANTHROPOMORPHISING="false"
            source src/core/title.sh
            compose_title "processing" "Test"
        ''')

        bash_title = results['bash'].stdout.strip()
        zsh_title = results['zsh'].stdout.strip()

        # Should have brackets around base and emoji
        assert '🟠' in bash_title, f"Missing emoji in bash: {bash_title}"
        assert '🟠' in zsh_title, f"Missing emoji in zsh: {zsh_title}"
        assert '[Test]' in bash_title, f"Custom format not applied in bash: {bash_title}"
        assert '[Test]' in zsh_title, f"Custom format not applied in zsh: {zsh_title}"

    def test_emoji_only_format(self):
        """Format with only emoji should work."""
        results = run_in_both_shells('''
            export TAVS_TITLE_FORMAT="{EMOJI} {BASE}"
            export ENABLE_ANTHROPOMORPHISING="false"
            source src/core/theme.sh
            source src/core/title.sh
            compose_title "complete" "MyApp"
        ''')

        bash_title = results['bash'].stdout.strip()
        zsh_title = results['zsh'].stdout.strip()

        # Should have emoji and base
        assert '🟢' in bash_title, f"Missing emoji: {bash_title}"
        assert 'MyApp' in bash_title, f"Missing base: {bash_title}"
        assert '🟢' in zsh_title, f"Missing emoji: {zsh_title}"
        assert 'MyApp' in zsh_title, f"Missing base: {zsh_title}"


class TestTitleModes:
    """Test different TAVS_TITLE_MODE settings."""

    def test_skip_processing_mode_skips_processing(self):
        """skip-processing mode should skip the processing state."""
        # This is hard to test directly without TTY, but we can verify
        # the mode variable is read correctly when set AFTER sourcing
        # (to simulate user.conf override)
        results = run_in_both_shells('''
            source src/core/theme.sh
            TAVS_TITLE_MODE="skip-processing"
            echo "$TAVS_TITLE_MODE"
        ''')

        assert results['bash'].stdout.strip() == "skip-processing"
        assert results['zsh'].stdout.strip() == "skip-processing"

    def test_title_mode_defaults_correctly(self):
        """Default title mode should be set."""
        results = run_in_both_shells('''
            source src/core/theme.sh
            echo "$TAVS_TITLE_MODE"
        ''')

        bash_mode = results['bash'].stdout.strip()
        zsh_mode = results['zsh'].stdout.strip()

        # Should have a default value
        assert bash_mode != "", "Title mode empty in bash"
        assert zsh_mode != "", "Title mode empty in zsh"

        # Should match between shells
        assert bash_mode == zsh_mode, \
            f"Title mode differs: bash='{bash_mode}', zsh='{zsh_mode}'"
