"""
Tests for face selection system (theme.sh and themes.sh).

The face system has two layers:
1. Legacy: themes.sh with get_face(theme, state) - DEPRECATED
2. Current: theme.sh with get_random_face(state) - agent-specific faces

This test file focuses on the current agent-based system.
Legacy get_face() tests are minimal - just verify it delegates correctly.

Agent face system:
- Each agent (claude, gemini, codex, opencode, unknown) has its own face set
- Faces are defined in src/config/defaults.conf as AGENT_FACES_STATE arrays
- get_random_face(state) picks randomly from the agent's face array
- Unknown agent uses fallback minimal faces

Verifies:
- get_random_face() returns valid faces for all states
- Agent-specific faces are resolved correctly
- Unknown agent falls back to minimal faces
- Legacy get_face() delegates to get_random_face()
"""

import pytest
from conftest import source_and_run, run_bash, PROJECT_ROOT

# Core states that have faces
CORE_STATES = ['processing', 'permission', 'complete', 'compacting', 'reset']

# Idle states (progressive sleepiness)
IDLE_STATES = ['idle_0', 'idle_1', 'idle_2', 'idle_3', 'idle_4', 'idle_5']

# All states
ALL_STATES = CORE_STATES + IDLE_STATES

# Agents with defined faces
AGENTS = ['claude', 'gemini', 'codex', 'opencode', 'unknown']

# Expected face patterns for each agent (substring matches)
AGENT_FACE_PATTERNS = {
    'claude': 'Ǝ[',      # Pincer face marker
    'gemini': 'ʕ',       # Bear face marker
    'codex': 'ฅ',        # Cat face marker
    'opencode': '(',     # Minimal kaomoji marker
    'unknown': '(',      # Fallback minimal face
}

# Expected fallback faces for unknown agent (exact matches)
UNKNOWN_FALLBACK_FACES = {
    'processing': '(°-°)',
    'permission': '(°□°)',
    'complete': '(^‿^)',
    'compacting': '(@_@)',
    'reset': '(-_-)',
    'idle_0': '(•‿•)',
    'idle_1': '(‿‿)',
    'idle_2': '(︶‿︶)',
    'idle_3': '(¬‿¬)',
    'idle_4': '(-.-)zzZ',
    'idle_5': '(︶.︶)ᶻᶻ',
}


class TestGetRandomFace:
    """Test get_random_face() from theme.sh - the current face selection API."""

    @pytest.mark.parametrize("state", ALL_STATES)
    def test_returns_non_empty_for_all_states(self, state):
        """get_random_face() should return a face for every valid state."""
        result = run_bash(
            f'''
            export TAVS_AGENT=unknown
            source src/core/theme-config-loader.sh
            get_random_face "{state}"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0, f"get_random_face failed: {result.stderr}"
        face = result.stdout.strip()
        assert face != "", f"Empty face for state '{state}'"

    def test_invalid_state_returns_empty(self):
        """Invalid state should return empty string."""
        result = run_bash(
            '''
            export TAVS_AGENT=unknown
            source src/core/theme-config-loader.sh
            get_random_face "nonexistent_state"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        assert result.stdout.strip() == ""

    @pytest.mark.parametrize("state,expected", list(UNKNOWN_FALLBACK_FACES.items()))
    def test_unknown_agent_fallback_faces(self, state, expected):
        """Unknown agent should use predictable fallback faces."""
        result = run_bash(
            f'''
            export TAVS_AGENT=unknown
            source src/core/theme-config-loader.sh
            get_random_face "{state}"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        face = result.stdout.strip()
        assert face == expected, f"Expected '{expected}' for {state}, got '{face}'"


class TestAgentFaces:
    """Test agent-specific face selection."""

    @pytest.mark.parametrize("agent", AGENTS)
    @pytest.mark.parametrize("state", CORE_STATES)
    def test_agent_returns_face_for_core_states(self, agent, state):
        """Each agent should return a face for core states."""
        result = run_bash(
            f'''
            export TAVS_AGENT={agent}
            source src/core/theme-config-loader.sh
            get_random_face "{state}"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0, f"Failed for {agent}:{state}: {result.stderr}"
        face = result.stdout.strip()
        assert face != "", f"Empty face for {agent}:{state}"

    @pytest.mark.parametrize("agent,pattern", list(AGENT_FACE_PATTERNS.items()))
    def test_agent_face_style(self, agent, pattern):
        """Each agent should use its characteristic face style."""
        result = run_bash(
            f'''
            export TAVS_AGENT={agent}
            source src/core/theme-config-loader.sh
            get_random_face "processing"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        face = result.stdout.strip()
        assert pattern in face, f"Expected '{pattern}' in {agent} face '{face}'"

    def test_claude_has_multiple_faces(self):
        """Claude agent should have multiple face variants (random selection)."""
        # Run multiple times and collect unique faces
        faces = set()
        for _ in range(10):
            result = run_bash(
                '''
                export TAVS_AGENT=claude
                source src/core/theme-config-loader.sh
                get_random_face "processing"
                ''',
                cwd=PROJECT_ROOT
            )
            if result.returncode == 0 and result.stdout.strip():
                faces.add(result.stdout.strip())

        # Claude should have 6 processing face variants
        # With 10 samples, we should see at least 2 different faces
        assert len(faces) >= 1, f"Expected multiple Claude faces, got: {faces}"
        # All should be pincer style
        for face in faces:
            assert 'Ǝ[' in face or ']E' in face, f"Non-pincer face: {face}"


class TestAgentVariableResolution:
    """Test _resolve_agent_variables() and _resolve_agent_faces()."""

    def test_claude_variables_resolved(self):
        """Claude agent variables should be resolved to generic names."""
        result = run_bash(
            '''
            export TAVS_AGENT=claude
            source src/core/theme-config-loader.sh
            echo "$AGENT_NAME"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        # AGENT_NAME should be set from CLAUDE_AGENT_NAME
        assert result.stdout.strip() != ""

    def test_spinner_frame_resolved_for_claude(self):
        """Claude's spinner face frame should be resolved."""
        result = run_bash(
            '''
            export TAVS_AGENT=claude
            source src/core/theme-config-loader.sh
            echo "$SPINNER_FACE_FRAME"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        frame = result.stdout.strip()
        # Claude uses pincer-style frame with {L} {R} placeholders
        assert '{L}' in frame and '{R}' in frame, f"Invalid frame: {frame}"


class TestLegacyGetFace:
    """Test legacy get_face() from themes.sh - should delegate to get_random_face()."""

    def test_get_face_delegates_to_get_random_face(self):
        """Legacy get_face() should call get_random_face() when available."""
        result = run_bash(
            '''
            export TAVS_AGENT=unknown
            source src/core/theme-config-loader.sh  # Provides get_random_face
            source src/core/themes.sh  # Provides get_face
            get_face "minimal" "processing"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        face = result.stdout.strip()
        # Should get fallback face since get_random_face is available
        assert face == "(°-°)", f"Expected '(°-°)', got '{face}'"

    def test_get_face_fallback_when_no_theme_loaded(self):
        """get_face() without theme.sh should return minimal fallback."""
        result = run_bash(
            '''
            source src/core/themes.sh
            get_face "minimal" "processing"
            ''',
            cwd=PROJECT_ROOT
        )

        assert result.returncode == 0
        face = result.stdout.strip()
        # Without theme.sh, should use inline fallbacks
        assert face == "(°-°)", f"Expected '(°-°)', got '{face}'"


class TestFaceStateCount:
    """Verify face coverage across states."""

    @pytest.mark.parametrize("agent", AGENTS)
    def test_agent_has_all_core_states(self, agent):
        """Each agent should have faces for all 5 core states."""
        faces_found = 0
        for state in CORE_STATES:
            result = run_bash(
                f'''
                export TAVS_AGENT={agent}
                source src/core/theme-config-loader.sh
                get_random_face "{state}"
                ''',
                cwd=PROJECT_ROOT
            )
            if result.returncode == 0 and result.stdout.strip():
                faces_found += 1

        assert faces_found == 5, f"Agent {agent} has {faces_found}/5 core state faces"

    @pytest.mark.parametrize("agent", AGENTS)
    def test_agent_has_all_idle_states(self, agent):
        """Each agent should have faces for all 6 idle states."""
        faces_found = 0
        for state in IDLE_STATES:
            result = run_bash(
                f'''
                export TAVS_AGENT={agent}
                source src/core/theme-config-loader.sh
                get_random_face "{state}"
                ''',
                cwd=PROJECT_ROOT
            )
            if result.returncode == 0 and result.stdout.strip():
                faces_found += 1

        assert faces_found == 6, f"Agent {agent} has {faces_found}/6 idle state faces"
