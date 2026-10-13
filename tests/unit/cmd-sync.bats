#!/usr/bin/env bats

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" && -x "${TAVS_TEST_HELPER_BIN:-}" ]] || return 1
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d "$TAVS_TEST_ROOT/sync.XXXXXX")
    TEST_DIR=$(cd "$TEST_DIR" && pwd)
    export HOME="$TEST_DIR/home" CFFIXED_USER_HOME="$TEST_DIR/home" ZDOTDIR="$TEST_DIR/home"
    export TAVS_RUNTIME_DIR="$TEST_DIR/runtime" TAVS_TMP_DIR="$TEST_DIR/state" _TAVS_TMP_DIR="$TEST_DIR/state"
    export XDG_RUNTIME_DIR="$TEST_DIR/xdg" XDG_CONFIG_HOME="$TEST_DIR/config"
    CACHE="$HOME/.claude/plugins/cache/terminal-agent-visual-signals/tavs/3.0.0"
    MARKET="$HOME/.claude/plugins/marketplaces/terminal-agent-visual-signals"
    FILES=(tavs src/agents/claude/trigger.sh src/agents/codex/trigger.sh
        src/agents/claude/hooks.json hooks/hooks.json src/shell/tavs-shellrc.sh src/install/install-codex.sh)
    local target file
    for target in "$CACHE" "$MARKET"; do
        mkdir -p "$target/src/core" "$target/src/cli" "$target/src/themes"
        for file in "${FILES[@]}" src/core/trigger.sh; do
            mkdir -p "$(dirname "$target/$file")"
            printf 'stale\n' > "$target/$file"
            chmod 644 "$target/$file"
        done
    done
    mkdir -p "$HOME/.tavs" "$HOME/.codex" "$TAVS_RUNTIME_DIR" "$TAVS_TMP_DIR"
    printf 'user preferences 43\n' > "$HOME/.tavs/user.conf"
    printf 'saved schedule 43\n' > "$HOME/.tavs/schedule.json"
    printf 'saved lock 43\n' > "$TAVS_RUNTIME_DIR/lock.state"
    printf 'old installed shellrc\n' > "$HOME/.tavs/shellrc"
}

sync_fixture() {
    run bash "$REPO_ROOT/tavs" sync
    [ "$status" -eq 0 ]
}

@test "sync copies connected entry points into both existing installations" {
    sync_fixture
    local target file
    for target in "$CACHE" "$MARKET"; do
        for file in "${FILES[@]}" src/core/organizer-state.sh src/core/visual-restrictions-state.sh src/cli/cmd-recover.sh; do
            cmp "$REPO_ROOT/$file" "$target/$file"
        done
        for file in tavs src/agents/claude/trigger.sh src/agents/codex/trigger.sh src/core/trigger.sh; do
            [ -x "$target/$file" ]
        done
        run "$target/tavs" recover --help
        [ "$status" -eq 0 ]
        [[ "$output" == *'tavs recover --resume'* ]]
    done
    cmp "$REPO_ROOT/src/shell/tavs-shellrc.sh" "$HOME/.tavs/shellrc"
    [ "$(cat "$HOME/.tavs/user.conf")" = 'user preferences 43' ]
    [ "$(cat "$HOME/.tavs/schedule.json")" = 'saved schedule 43' ]
    [ "$(cat "$TAVS_RUNTIME_DIR/lock.state")" = 'saved lock 43' ]
}

@test "copied CLI recovery uses the explicit native helper and private fixture scope" {
    sync_fixture
    export TAVS_SESSIONS_TEST_ROOT="$TEST_DIR"
    export TAVS_SESSIONS_TEST_FIXTURE="$TEST_DIR/catalogue.json" TAVS_SESSIONS_TEST_TARGETS='[]'
    printf '{}\n' > "$TAVS_SESSIONS_TEST_FIXTURE"
    run "$CACHE/tavs" recover
    [ "$status" -eq 1 ]
    [[ "$output" == *'"stateSaved":true'* && "$output" == *'"status":"failed"'* ]]
    grep -q '^SUSPENDED="true"$' "$HOME/.tavs/visual-restrictions.state"
    run "$CACHE/tavs" recover --resume
    [ "$status" -eq 1 ]
    grep -q '^SUSPENDED="false"$' "$HOME/.tavs/visual-restrictions.state"
}

@test "copied shell installer keeps a standalone current shellrc and idempotent fences" {
    sync_fixture
    run "$CACHE/tavs" install shell-integration
    [ "$status" -eq 0 ]
    run "$CACHE/tavs" install shell-integration
    [ "$status" -eq 0 ]
    cmp "$REPO_ROOT/src/shell/tavs-shellrc.sh" "$HOME/.tavs/shellrc"
    [ "$(grep -cF '# >>> tavs shell integration >>>' "$HOME/.zshrc")" -eq 1 ]
    run bash --norc -c 'source "$1/src/core/visual-restrictions-state.sh"; _tavs_visual_restrictions_write true' _ "$CACHE"
    [ "$status" -eq 0 ]
    local shell
    for shell in bash zsh; do
        run "$shell" -fc 'source "$HOME/.tavs/shellrc"; _tavs_visual_restrictions_read; printf "%s" "$_TAVS_VISUAL_RESTRICTIONS_STATUS"'
        [ "$status" -eq 0 ]
        [ "$output" = suspended ]
    done
}

@test "copied Codex installer generates direct argv for the copied adapter" {
    sync_fixture
    printf 'model = "fixture"\n' > "$HOME/.codex/config.toml"
    run bash -c 'printf "y\n" | "$1/tavs" install codex' _ "$CACHE"
    [ "$status" -eq 0 ]
    grep -F "notify = [\"bash\", \"$CACHE/src/agents/codex/trigger.sh\", \"complete\"]" "$HOME/.codex/config.toml"
    grep -q '^model = "fixture"$' "$HOME/.codex/config.toml"
}

@test "copied adapters forward allowlisted intake with the visual kill switch" {
    sync_fixture
    export TAVS_STATUS=false TAVS_TEST_HELPER_BIN="$TEST_DIR/helper" INTAKE_LOG="$TEST_DIR/intake"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
if [[ "$1:$2" == --validate-config:--organizer-capabilities ]]; then
    printf 'tavs-organizer-schema=1\n'; exit 0
fi
[[ "$1" == --organizer-intake ]] || exit 1
session=$(jq -r '.session_id // .["thread-id"]' < /dev/stdin) || exit 1
[[ "$session" == fixture-43 ]] || exit 1
printf '%s:%s\n' "$2" "$session" >> "$INTAKE_LOG"
printf 'TAVS_ORGANIZER_INTAKE\0%s\0TAVS_ORGANIZER_CONTEXT\0%s\0' 1 fixture-context
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
    run bash -c 'printf "%s" "{\"session_id\":\"fixture-43\"}" | "$1/src/agents/claude/trigger.sh" processing new-prompt' _ "$CACHE"
    [ "$status" -eq 0 ]
    run "$CACHE/src/agents/codex/trigger.sh" complete '{"type":"agent-turn-complete","thread-id":"fixture-43"}'
    [ "$status" -eq 0 ]
    [ "$(cat "$INTAKE_LOG")" = $'claude:fixture-43\ncodex:fixture-43' ]
}

@test "sync propagates a required copy failure instead of reporting success" {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/cp" <<'COPY'
#!/bin/bash
case "$1" in */src/agents/codex/trigger.sh) exit 43 ;; esac
exec /bin/cp "$@"
COPY
    chmod +x "$TEST_DIR/bin/cp"
    export CLI_DIR="$REPO_ROOT/src/cli" TAVS_ROOT="$REPO_ROOT" TAVS_VERSION=3.0.0
    run env PATH="$TEST_DIR/bin:$PATH" bash -c 'source "$CLI_DIR/cmd-sync.sh"; cmd_sync'
    [ "$status" -ne 0 ]
    [[ "$output" != *'Plugin cache synced'* ]]
}

@test "sync reports a missing helper without claiming hooks are ready" {
    export TAVS_TEST_HELPER_BIN="$TEST_DIR/missing-helper"
    sync_fixture
    [[ "$output" == *'native render/metadata helper unavailable or unsupported'* ]]
    [[ "$output" != *'Submit a prompt to test'* ]]
    cmp "$REPO_ROOT/src/core/organizer-state.sh" "$CACHE/src/core/organizer-state.sh"
    [ "$(cat "$HOME/.tavs/user.conf")" = 'user preferences 43' ]
}

@test "sync reports unsupported helper output without echoing its contents" {
    export TAVS_TEST_HELPER_BIN="$TEST_DIR/old-helper"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
printf 'PROBE_OUTPUT_SENTINEL\n'
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
    sync_fixture
    [[ "$output" == *'native render/metadata helper unavailable or unsupported'* ]]
    [[ "$output" != *PROBE_OUTPUT_SENTINEL* && "$output" != *'Submit a prompt to test'* ]]
}

@test "sync also checks organizer metadata capability and excludes fixture launch keys" {
    export TAVS_TEST_HELPER_BIN="$TEST_DIR/render-only-helper" PROBE_LOG="$TEST_DIR/probes"
    export TAVS_SESSIONS_TEST_ROOT="$TEST_DIR" TAVS_SESSIONS_TEST_FIXTURE="$TEST_DIR/catalogue.json"
    export TAVS_SESSIONS_TEST_TARGETS='[]'
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
[[ -z "${TAVS_SESSIONS_TEST_ROOT+x}${TAVS_SESSIONS_TEST_FIXTURE+x}${TAVS_SESSIONS_TEST_TARGETS+x}" ]] || exit 43
printf '%s\n' "$2" >> "$PROBE_LOG"
[[ "$1:$2" == --validate-config:--managed-output-capabilities ]] || exit 1
printf 'tavs-managed-output-schema=1\n'
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
    sync_fixture
    [[ "$output" == *'native render/metadata helper unavailable or unsupported'* ]]
    [[ "$(cat "$PROBE_LOG")" == *--organizer-capabilities* ]]
}

@test "copied readers refuse an explicitly missing helper after saving suspension" {
    sync_fixture
    export TAVS_TEST_HELPER_BIN="$TEST_DIR/missing-helper"
    run "$CACHE/tavs" recover
    [ "$status" -eq 1 ]
    [[ "$output" == *'State saved; native recovery helper unavailable'* ]]
    grep -q '^SUSPENDED="true"$' "$HOME/.tavs/visual-restrictions.state"
    run bash -c 'source "$1/src/core/organizer-state.sh"; _tavs_managed_helper' _ "$CACHE"
    [ "$status" -eq 1 ]
    run bash -c 'source "$HOME/.tavs/shellrc"; _tavs_shellrc_managed_helper'
    [ "$status" -eq 1 ]
}
