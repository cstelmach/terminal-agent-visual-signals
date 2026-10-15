#!/usr/bin/env bats

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" && -x "${TAVS_TEST_HELPER_BIN:-}" ]] || return 1
    export TAVS_TEST_ROOT="$(cd "$TAVS_TEST_ROOT" && pwd -P)"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d "$TAVS_TEST_ROOT/install-agent.XXXXXX")
    export HOME="$TEST_DIR/home" CFFIXED_USER_HOME="$TEST_DIR/home" ZDOTDIR="$TEST_DIR/home"
    export TAVS_RUNTIME_DIR="$TEST_DIR/runtime" TAVS_TMP_DIR="$TEST_DIR/state" _TAVS_TMP_DIR="$TEST_DIR/state"
    export XDG_RUNTIME_DIR="$TEST_DIR/xdg" XDG_CONFIG_HOME="$TEST_DIR/config"
    export INSTALL_REAL_PYTHON="$(command -v python3)" INSTALL_FAILURE='' INSTALL_FAIL_AGENT=claude
    export INSTALL_CALLS="$TEST_DIR/python-calls"
    : > "$INSTALL_CALLS"
    local agent
    for agent in claude gemini codex; do
        mkdir -p "$HOME/.$agent"
        printf '{"theme":"fixture-43","hooks":{}}\n' > "$HOME/.$agent/settings.json"
        /bin/cp "$HOME/.$agent/settings.json" "$TEST_DIR/$agent-before.json"
    done
    mkdir "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/python3" <<'PYTHON'
#!/bin/bash
set -eu
if [[ $# == 7 && "$1" == -c ]]; then
    [[ "$3" == "$HOME/"* && "$HOME" == "$TAVS_TEST_ROOT/"* ]] || exit 90
    printf '%s:%s\n' "$3" "$7" >> "$INSTALL_CALLS"
    if [[ "$7" == "$INSTALL_FAILURE" && "$3" == "$HOME/.$INSTALL_FAIL_AGENT/settings.json" ]]; then
        printf 'fixture operation refused\n' >&2
        exit 43
    fi
fi
exec "$INSTALL_REAL_PYTHON" "$@"
PYTHON
    chmod +x "$TEST_DIR/bin/python3"
    export PATH="$TEST_DIR/bin:$PATH"
}

run_installer() {
    run /bin/bash -c 'printf "%s" "$2" | /bin/bash "$1"' _ "$REPO_ROOT/src/install/$1" "${2:-$'y\ny\ny\n'}"
}

assert_unchanged() {
    cmp "$TEST_DIR/$1-before.json" "$HOME/.$1/settings.json"
    [ ! -e "$HOME/.$1/settings.json.bak" ]
}

@test "Gemini refuses a nonzero preview without matching diagnostic text" {
    export INSTALL_FAILURE=preview INSTALL_FAIL_AGENT=gemini
    run_installer install-gemini.sh
    [ "$status" -ne 0 ]
    assert_unchanged gemini
    ! grep -q ':apply$' "$INSTALL_CALLS"
    [[ "$output" == *'fixture operation refused'* && "$output" != *'visual signals installed!'* ]]
}

@test "Gemini apply failure propagates through the public CLI without success" {
    export INSTALL_FAILURE=apply INSTALL_FAIL_AGENT=gemini
    run /bin/bash -c 'printf "y\n" | /bin/bash "$1/tavs" install gemini' _ "$REPO_ROOT"
    [ "$status" -ne 0 ]
    assert_unchanged gemini
    grep -q ':apply$' "$INSTALL_CALLS"
    [[ "$output" == *'fixture operation refused'* && "$output" != *'visual signals installed!'* ]]
}

@test "unified preview failure preserves failure status while processing other agents" {
    export INSTALL_FAILURE=preview
    run_installer install.sh
    [ "$status" -ne 0 ]
    assert_unchanged claude
    ! grep -qF "$HOME/.claude/settings.json:apply" "$INSTALL_CALLS"
    grep -qF "$HOME/.gemini/settings.json:apply" "$INSTALL_CALLS"
    [[ "$output" != *'Claude updated.'* && "$output" == *'Gemini updated.'* && "$output" != *'Done.'* ]]
}

@test "unified apply failure cannot be hidden by a later successful agent" {
    export INSTALL_FAILURE=apply
    run_installer install.sh
    [ "$status" -ne 0 ]
    assert_unchanged claude
    grep -qF "$HOME/.gemini/settings.json:apply" "$INSTALL_CALLS"
    [[ "$output" != *'Claude updated.'* && "$output" == *'Gemini updated.'* && "$output" != *'Done.'* ]]
}

@test "malformed settings fail preview without apply for either installer" {
    printf '{invalid\n' > "$HOME/.gemini/settings.json"
    /bin/cp "$HOME/.gemini/settings.json" "$TEST_DIR/gemini-before.json"
    run_installer install-gemini.sh
    [ "$status" -ne 0 ]
    assert_unchanged gemini
    ! grep -q ':apply$' "$INSTALL_CALLS"
    run_installer install.sh
    [ "$status" -ne 0 ]
    assert_unchanged gemini
    ! grep -qF "$HOME/.gemini/settings.json:apply" "$INSTALL_CALLS"
    [[ "$output" != *'Gemini updated.'* && "$output" != *'Done.'* ]]
}

@test "successful Gemini install preserves settings and backup and remains idempotent" {
    run_installer install-gemini.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *'visual signals installed!'* ]]
    cmp "$TEST_DIR/gemini-before.json" "$HOME/.gemini/settings.json.bak"
    "$INSTALL_REAL_PYTHON" -c '
import json, sys
d=json.load(open(sys.argv[1]))
assert d["theme"] == "fixture-43" and d["tools"]["enableHooks"] is True
assert len(d["hooks"]["BeforeAgent"]) == 1
' "$HOME/.gemini/settings.json"
    /bin/cp "$HOME/.gemini/settings.json" "$TEST_DIR/gemini-installed.json"
    run_installer install-gemini.sh
    [ "$status" -eq 0 ]
    cmp "$TEST_DIR/gemini-installed.json" "$HOME/.gemini/settings.json"
}

@test "successful unified install and no-change rerun return success" {
    run_installer install.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *'Claude updated.'* && "$output" == *'Gemini updated.'* && "$output" == *'Done.'* ]]
    cmp "$TEST_DIR/claude-before.json" "$HOME/.claude/settings.json.bak"
    cmp "$TEST_DIR/gemini-before.json" "$HOME/.gemini/settings.json.bak"
    /bin/cp "$HOME/.claude/settings.json" "$TEST_DIR/claude-installed.json"
    /bin/cp "$HOME/.gemini/settings.json" "$TEST_DIR/gemini-installed.json"
    run_installer install.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *'All hooks already installed.'* ]]
    cmp "$TEST_DIR/claude-installed.json" "$HOME/.claude/settings.json"
    cmp "$TEST_DIR/gemini-installed.json" "$HOME/.gemini/settings.json"
}

@test "unified merge preserves distinct existing and template matcher entries" {
    "$INSTALL_REAL_PYTHON" - "$REPO_ROOT" "$HOME/.claude/settings.json" <<'PYTHON'
import json, pathlib, sys
root, target = sys.argv[1:]
source = pathlib.Path(root, 'src/agents/claude/hooks.json').read_text().replace('${CLAUDE_PLUGIN_ROOT}', root)
hooks = json.loads(source)['hooks']
existing = dict(hooks['PermissionRequest'][0], matcher='fixture-43', description='keep this entry')
pathlib.Path(target).write_text(json.dumps({'theme':'fixture-43', 'hooks':{'PermissionRequest':[existing]}}))
PYTHON
    run_installer install.sh
    [ "$status" -eq 0 ]
    "$INSTALL_REAL_PYTHON" - "$REPO_ROOT" "$HOME/.claude/settings.json" <<'PYTHON'
import json, pathlib, sys
root, target = sys.argv[1:]
source = pathlib.Path(root, 'src/agents/claude/hooks.json').read_text().replace('${CLAUDE_PLUGIN_ROOT}', root)
hooks = json.loads(source)['hooks']
existing = dict(hooks['PermissionRequest'][0], matcher='fixture-43', description='keep this entry')
hooks['PermissionRequest'].append(existing)
actual = json.loads(pathlib.Path(target).read_text())
assert actual['theme'] == 'fixture-43' and actual['hooks'] == hooks
PYTHON
    /bin/cp "$HOME/.claude/settings.json" "$TEST_DIR/claude-installed.json"
    run_installer install.sh
    [ "$status" -eq 0 ]
    cmp "$TEST_DIR/claude-installed.json" "$HOME/.claude/settings.json"
}

@test "declining either installer preserves files and performs no apply" {
    run_installer install-gemini.sh $'n\n'
    [ "$status" -eq 0 ]
    assert_unchanged gemini
    run_installer install.sh $'n\nn\nn\n'
    [ "$status" -eq 0 ]
    assert_unchanged claude
    assert_unchanged gemini
    assert_unchanged codex
    ! grep -q ':apply$' "$INSTALL_CALLS"
}
