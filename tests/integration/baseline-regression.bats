#!/usr/bin/env bats
# ==============================================================================
# Integration test: baseline OSC byte regression
# Wraps tests/bench/baseline-capture.sh --diff
# ==============================================================================

@test "OSC bytes with absent mute.state match golden baseline" {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    run bash "$REPO_ROOT/tests/bench/baseline-capture.sh" --diff
    echo "$output"
    [ "$status" -eq 0 ]
    # Every line should start with "OK"
    local fail_count
    fail_count=$(echo "$output" | grep -c "^DIFF" || true)
    [ "$fail_count" -eq 0 ]
}
