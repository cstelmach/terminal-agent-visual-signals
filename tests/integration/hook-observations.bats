#!/usr/bin/env bats

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" && -x "${TAVS_TEST_HELPER_BIN:-}" ]]
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    FIXTURE="$(cd "$BATS_TEST_TMPDIR" && pwd)/repo \"quoted\" \\path"
    export CAPTURE="$BATS_TEST_TMPDIR/core.json"
    mkdir -p "$FIXTURE/src/agents/claude" "$FIXTURE/src/agents/codex" \
        "$FIXTURE/src/core" "$FIXTURE/src/install"
    cp "$REPO_ROOT/src/agents/claude/trigger.sh" "$FIXTURE/src/agents/claude/trigger.sh"
    cp "$REPO_ROOT/src/agents/codex/trigger.sh" "$FIXTURE/src/agents/codex/trigger.sh"
    cp "$REPO_ROOT/src/core/organizer-state.sh" "$FIXTURE/src/core/organizer-state.sh"
    local file
    for file in helper-selection.sh portable_helper.py portable_context.py portable_metadata.py \
        portable_observation.py portable_intent.py portable_records.py portable_record_io.py \
        portable_render.py portable_renderer.py portable_ownership.py portable_policy.py \
        portable_device_writer.py portable_process_identity.py; do
        cp "$REPO_ROOT/src/core/$file" "$FIXTURE/src/core/$file"
    done
    cp "$REPO_ROOT/src/install/install-codex.sh" "$FIXTURE/src/install/install-codex.sh"
    cat > "$FIXTURE/src/core/trigger.sh" <<'SH'
#!/bin/bash
python3 -c 'import json,os,sys
keys=["TAVS_AGENT","TAVS_PERMISSION_MODE","TAVS_TRANSCRIPT_PATH","TAVS_SESSION_ID",
      "TAVS_CWD","TAVS_ORGANIZER_CONTEXT","TAVS_ORGANIZER_INTAKE","_TAVS_HOOK_PAYLOAD"]
with open(os.environ["CAPTURE"],"w") as f:
    json.dump({"args":sys.argv[1:],"env":{k:os.environ.get(k) for k in keys},
               "stdin":sys.stdin.read()},f)' "$@"
SH
    chmod +x "$FIXTURE/src/core/trigger.sh"
    CLAUDE="$FIXTURE/src/agents/claude/trigger.sh"
    CODEX="$FIXTURE/src/agents/codex/trigger.sh"
    export _TAVS_HOOK_PAYLOAD="INHERITED_BODY_SENTINEL"
    export DEBUG_ALL=1
}

_claude() { bash "$CLAUDE" "$@" < "$BATS_TEST_TMPDIR/payload.json"; }
_codex() { bash "$CODEX" "$@" < "$BATS_TEST_TMPDIR/payload.json"; }

_assert_private_dispatch() {
    python3 - "$CAPTURE" "$@" <<'PY'
import base64,json,sys
record=json.load(open(sys.argv[1]))
assert record["args"] == sys.argv[2:], record["args"]
assert record["stdin"] == "", record["stdin"]
assert record["env"]["_TAVS_HOOK_PAYLOAD"] is None
assert "BODY_SENTINEL" not in json.dumps(record)
context=record["env"]["TAVS_ORGANIZER_CONTEXT"]
if context:
    decoded=json.loads(base64.b64decode(context))
    assert set(decoded) <= {"schema","deliveryID","observedAt","provider","verifiedAgent",
                            "producer","device","event","responseID"}
    assert "BODY_SENTINEL" not in json.dumps(decoded)
PY
}

@test "Claude intake preserves decoded top-level metadata without body or nested keys" {
    cat > "$BATS_TEST_TMPDIR/payload.json" <<'JSON'
{"permission_mode":"plan","session_id":"session\"\\escaped","cwd":"/fixture/space and\nnewline","transcript_path":"/fixture/transcript\"\\path.jsonl","hook_event_name":"UserPromptSubmit","prompt":"PROMPT_BODY_SENTINEL","tool_input":{"permission_mode":"bypassPermissions","session_id":"TOOL_BODY_SENTINEL","cwd":"NESTED_BODY_SENTINEL"}}
JSON
    run _claude processing new-prompt
    [ "$status" -eq 0 ]
    _assert_private_dispatch processing new-prompt
    python3 - "$CAPTURE" <<'PY'
import base64,json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_AGENT"] == "claude"
assert e["TAVS_PERMISSION_MODE"] == "plan"
assert e["TAVS_SESSION_ID"] == 'session"\\escaped'
assert e["TAVS_CWD"] == "/fixture/space and\nnewline"
assert e["TAVS_TRANSCRIPT_PATH"] == '/fixture/transcript"\\path.jsonl'
c=json.loads(base64.b64decode(e["TAVS_ORGANIZER_CONTEXT"]))
assert c["provider"] == "claude" and c["event"] == "UserPromptSubmit"
assert c["deliveryID"] and c["observedAt"] > 0
assert not {"cwd","session_id","transcript_path","prompt","tool_input"} & c.keys()
PY
}

@test "Claude reset keeps session-end and discards free-form arguments" {
    printf '%s' '{"session_id":"ending","hook_event_name":"SessionEnd"}' \
        > "$BATS_TEST_TMPDIR/payload.json"
    run _claude reset session-end ARG_BODY_SENTINEL
    [ "$status" -eq 0 ]
    _assert_private_dispatch reset session-end
}

@test "Existing Claude lifecycle events preserve reducer authority and fresh intake IDs" {
    local state hook subtype expected
    : > "$BATS_TEST_TMPDIR/delivery-ids"
    while IFS='|' read -r state hook subtype expected; do
        printf '{"hook_event_name":"%s","notification_type":"%s","prompt":"BODY_SENTINEL"}' \
            "$hook" "$subtype" > "$BATS_TEST_TMPDIR/payload.json"
        run _claude "$state"
        [ "$status" -eq 0 ]
        _assert_private_dispatch "$state"
        python3 - "$CAPTURE" "$expected" "$BATS_TEST_TMPDIR/delivery-ids" <<'PY'
import base64,json,sys
c=json.loads(base64.b64decode(json.load(open(sys.argv[1]))["env"]["TAVS_ORGANIZER_CONTEXT"]))
assert c.get("event", "") == sys.argv[2]
with open(sys.argv[3]) as f:
    assert c["deliveryID"] not in f.read().splitlines()
with open(sys.argv[3],"a") as f:
    f.write(c["deliveryID"]+"\n")
PY
    done <<'CASES'
permission|PermissionRequest||PermissionRequest
permission|Notification|permission_prompt|permission_prompt
idle|Notification|idle_prompt|idle_prompt
permission|Notification|unknown|
complete|Stop||Stop
processing|UserPromptSubmit||UserPromptSubmit
processing|PostToolUse||PostToolUse
reset|SessionStart||SessionStart
reset|SessionEnd||SessionEnd
CASES
}

@test "Adapters reject unknown states without passing free-form state to core" {
    printf '%s' '{}' > "$BATS_TEST_TMPDIR/payload.json"
    run _claude STATE_BODY_SENTINEL
    [ "$status" -ne 0 ]
    [[ "$output" != *BODY_SENTINEL* ]]
    [ ! -e "$CAPTURE" ]
    run _codex STATE_BODY_SENTINEL '{}'
    [ "$status" -ne 0 ]
    [[ "$output" != *BODY_SENTINEL* ]]
    [ ! -e "$CAPTURE" ]
}

@test "Manual Codex fixed-state flags still reach core" {
    : > "$BATS_TEST_TMPDIR/payload.json"
    run _codex processing new-prompt
    [ "$status" -eq 0 ]
    _assert_private_dispatch processing new-prompt
    run _codex reset session-end
    [ "$status" -eq 0 ]
    _assert_private_dispatch reset session-end
}

@test "Codex appended JSON preserves completion metadata and consumes argv and stdin" {
    printf '%s' 'STDIN_BODY_SENTINEL' > "$BATS_TEST_TMPDIR/payload.json"
    local payload='{"type":"agent-turn-complete","thread-id":"thread\"\\escaped","turn-id":"turn-7","cwd":"/fixture/codex dir","input-messages":["PROMPT_BODY_SENTINEL"],"last-assistant-message":"ANSWER_BODY_SENTINEL"}'
    run _codex complete "$payload" ARG_BODY_SENTINEL
    [ "$status" -eq 0 ]
    _assert_private_dispatch complete
    python3 - "$CAPTURE" <<'PY'
import base64,json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_AGENT"] == "codex"
assert e["TAVS_SESSION_ID"] == 'thread"\\escaped'
assert e["TAVS_CWD"] == "/fixture/codex dir"
c=json.loads(base64.b64decode(e["TAVS_ORGANIZER_CONTEXT"]))
assert c["event"] == "agent-turn-complete" and c["responseID"] == "turn-7"
assert c["provider"] == "codex"
assert not {"thread-id","cwd","input-messages","last-assistant-message"} & c.keys()
PY
}

@test "Missing Codex turn ID stays absent instead of inferring another event" {
    : > "$BATS_TEST_TMPDIR/payload.json"
    run _codex complete '{"type":"agent-turn-complete","thread-id":"known-thread"}'
    [ "$status" -eq 0 ]
    _assert_private_dispatch complete
    python3 - "$CAPTURE" <<'PY'
import base64,json,sys
c=json.loads(base64.b64decode(json.load(open(sys.argv[1]))["env"]["TAVS_ORGANIZER_CONTEXT"]))
assert c["event"] == "agent-turn-complete"
assert c.get("responseID") is None
PY
}

@test "Malformed and wrong-type hook payloads retain fixed signals without inherited metadata" {
    export TAVS_PERMISSION_MODE=bypassPermissions TAVS_SESSION_ID=stale \
        TAVS_CWD=/stale TAVS_TRANSCRIPT_PATH=/stale TAVS_ORGANIZER_CONTEXT=stale
    local payload
    for payload in '{"prompt":"BROKEN_BODY_SENTINEL"' '[]' \
        '{"permission_mode":{},"session_id":43,"cwd":[],"transcript_path":false}'; do
        printf '%s' "$payload" > "$BATS_TEST_TMPDIR/payload.json"
        run _claude permission
        [ "$status" -eq 0 ]
        [[ "$output" != *BODY_SENTINEL* ]]
        _assert_private_dispatch permission
        python3 - "$CAPTURE" <<'PY'
import json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_PERMISSION_MODE"] == "default"
assert not e["TAVS_SESSION_ID"] and not e["TAVS_CWD"] and not e["TAVS_TRANSCRIPT_PATH"]
assert e["TAVS_ORGANIZER_CONTEXT"] != "stale"
PY
    done
}

@test "Unknown event and mode do not become organizer authority" {
    printf '%s' '{"hook_event_name":"UNKNOWN_BODY_SENTINEL","permission_mode":"MODE_BODY_SENTINEL","nested":{"session_id":"NESTED_BODY_SENTINEL"}}' \
        > "$BATS_TEST_TMPDIR/payload.json"
    run _claude processing ARG_BODY_SENTINEL
    [ "$status" -eq 0 ]
    [[ "$output" != *BODY_SENTINEL* ]]
    _assert_private_dispatch processing
    python3 - "$CAPTURE" <<'PY'
import base64,json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_PERMISSION_MODE"] == "default" and not e["TAVS_SESSION_ID"]
if e["TAVS_ORGANIZER_CONTEXT"]:
    c=json.loads(base64.b64decode(e["TAVS_ORGANIZER_CONTEXT"]))
    assert c.get("event") is None
PY
}

@test "valid adapter intake reuses one private organizer probe after discarding raw argv" {
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/counting-helper" CALLS="$BATS_TEST_TMPDIR/calls"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
if [[ "$1" == --validate-config ]]; then
    printf '%s\n' "$2" >> "$CALLS"
    case "$2" in
        --organizer-capabilities) printf 'tavs-organizer-schema=1\n' ;;
        --managed-output-capabilities) printf 'tavs-managed-output-schema=1\n' ;;
        *) exit 1 ;;
    esac
else
    printf '%s\n' "$1" >> "$CALLS"
    case "$1" in
        --organizer-intake) cat >/dev/null; printf 'TAVS_ORGANIZER_INTAKE\0%s\0TAVS_ORGANIZER_CONTEXT\0%s\0' 1 fixture-context ;;
        --organizer-observe) ;;
        --managed-render) cat >/dev/null; printf 'rendered\n' ;;
        *) exit 1 ;;
    esac
fi
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
    cat > "$FIXTURE/src/core/trigger.sh" <<'CORE'
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/organizer-state.sh"
[[ -z "$(cat)" ]] || exit 43
case "$1:${2:-}" in processing:new-prompt|complete:) ;; *) exit 44 ;; esac
[[ "$(/bin/ps -o command= -p $$)" != *BODY_SENTINEL* ]] || exit 45
(sleep 0.3; :) & child=$!
[[ "$(/bin/ps -o command= -p "$child")" != *BODY_SENTINEL* ]] || exit 46
wait "$child"
_tavs_organizer_begin "$1"
_tavs_render_begin
_tavs_render_queue background '#123456'
_tavs_render_flush
env | /usr/bin/grep '^_TAVS_.*HELPER' > "$CAPTURE.private" || :
CORE
    printf '{"prompt":"BODY_SENTINEL"}' > "$BATS_TEST_TMPDIR/payload.json"
    local adapter
    for adapter in "$CLAUDE" "$CODEX"; do
        : > "$CALLS"
        if [[ "$adapter" == "$CODEX" ]]; then
            run bash "$adapter" complete '{"type":"agent-turn-complete","prompt":"BODY_SENTINEL"}' BODY_SENTINEL
        else
            run bash "$adapter" processing new-prompt BODY_SENTINEL < "$BATS_TEST_TMPDIR/payload.json"
        fi
        [ "$status" -eq 0 ]
        [ "$(grep -c '^--organizer-capabilities$' "$CALLS")" -eq 1 ]
        [ "$(wc -l < "$CALLS")" -eq 5 ]
        [ ! -s "$CAPTURE.private" ]
    done
}

@test "adapter intake ignores forged inherited organizer capability cache" {
    export _TAVS_ORGANIZER_HELPER_CHECKED=1 _TAVS_ORGANIZER_HELPER="$BATS_TEST_TMPDIR/forged-helper"
    export _TAVS_HELPER_CHECKED=1 _TAVS_HELPER_BACKEND=native _TAVS_HELPER_BIN="$_TAVS_ORGANIZER_HELPER"
    export FORGED_LOG="$BATS_TEST_TMPDIR/forged-calls"
    cat > "$_TAVS_ORGANIZER_HELPER" <<'HELPER'
#!/bin/bash
printf 'called\n' >> "$FORGED_LOG"
printf 'TAVS_ORGANIZER_INTAKE\0%s\0TAVS_ORGANIZER_CONTEXT\0%s\0' 1 forged-context
HELPER
    chmod +x "$_TAVS_ORGANIZER_HELPER"
    printf '{"session_id":"fixture-43"}' > "$BATS_TEST_TMPDIR/payload.json"
    run _claude processing
    [ "$status" -eq 0 ]
    [ ! -e "$FORGED_LOG" ]
    _assert_private_dispatch processing
}

@test "portable adapter choice crosses exec without another probe or leaked private cache" {
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/missing" CALLS="$BATS_TEST_TMPDIR/calls"
    cat > "$FIXTURE/src/core/portable_helper.py" <<'HELPER'
#!/bin/bash
printf '%s\n' "$1" >> "$CALLS"
case "$1" in
    --validate-config) printf 'tavs-portable-ordinary-schema=1\n' ;;
    --organizer-intake)
        cat >/dev/null
        printf 'TAVS_ORGANIZER_INTAKE\0%s\0TAVS_ORGANIZER_CONTEXT\0%s\0' 1 fixture-context ;;
    --organizer-observe) ;;
    --managed-render) cat >/dev/null; printf 'rendered\n' ;;
    *) exit 43 ;;
esac
HELPER
    cat > "$FIXTURE/src/core/trigger.sh" <<'CORE'
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/organizer-state.sh"
[[ "$_TAVS_HELPER_BACKEND" == portable ]] || exit 43
_tavs_organizer_begin "$1"
_tavs_render_begin
_tavs_render_queue background '#123456'
_tavs_render_flush || exit
env | /usr/bin/grep '^_TAVS_.*HELPER' > "$CAPTURE.private" || :
CORE
    printf '{"prompt":"BODY_SENTINEL"}' > "$BATS_TEST_TMPDIR/payload.json"
    run _claude processing
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$CALLS")" -eq 4 ]
    [ "$(grep -c '^--validate-config$' "$CALLS")" -eq 1 ]
    [ ! -s "$CAPTURE.private" ]
}

@test "core rejects an imported capability cache without a matching intake hint" {
    export _TAVS_ORGANIZER_HELPER_CHECKED=1 _TAVS_ORGANIZER_HELPER="$BATS_TEST_TMPDIR/forged-helper"
    unset TAVS_ORGANIZER_INTAKE TAVS_ORGANIZER_CONTEXT
    run bash -c 'source "$1/src/core/organizer-state.sh"; _tavs_organizer_helper; printf "%s" "$_TAVS_ORGANIZER_HELPER"' _ "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [ "$output" = "$TAVS_TEST_HELPER_BIN" ]
}

@test "Shell syntax stays metadata data without execution" {
    python3 - "$BATS_TEST_TMPDIR" <<'PY' > "$BATS_TEST_TMPDIR/payload.json"
import json,sys
print(json.dumps({"session_id":"$(touch "+sys.argv[1]+"/executed)",
                  "cwd":"`touch "+sys.argv[1]+"/executed`","permission_mode":"plan"}))
PY
    run _claude processing
    [ "$status" -eq 0 ]
    _assert_private_dispatch processing
    [ ! -e "$BATS_TEST_TMPDIR/executed" ]
    python3 - "$CAPTURE" <<'PY'
import json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_SESSION_ID"].startswith("$(touch ") and e["TAVS_CWD"].startswith("`touch ")
PY
}

@test "Absent or legacy native helper uses portable intake without claiming verified correlation" {
    printf '%s' '{"prompt":"PROMPT_BODY_SENTINEL","permission_mode":"plan","session_id":"standalone-session","cwd":"/fixture/standalone","transcript_path":"/fixture/transcript.jsonl","tool_input":{"permission_mode":"bypassPermissions","session_id":"BODY_SENTINEL"}}' \
        > "$BATS_TEST_TMPDIR/payload.json"
    local selected="$TAVS_TEST_HELPER_BIN"
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/missing-helper"
    run _claude permission
    [ "$status" -eq 0 ]
    [[ "$output" != *unavailable* && "$output" != *BODY_SENTINEL* ]]
    _assert_private_dispatch permission
    python3 - "$CAPTURE" <<'PY'
import base64,json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_PERMISSION_MODE"] == "plan"
assert e["TAVS_SESSION_ID"] == "standalone-session"
assert e["TAVS_CWD"] == "/fixture/standalone"
assert e["TAVS_TRANSCRIPT_PATH"] == "/fixture/transcript.jsonl"
assert not json.loads(base64.b64decode(e["TAVS_ORGANIZER_CONTEXT"]))["verifiedAgent"]
assert e["TAVS_ORGANIZER_INTAKE"] == "1"
PY

    cat > "$BATS_TEST_TMPDIR/old-helper" <<'SH'
#!/bin/bash
[[ "$1" == "--validate-config" && "$2" == "--organizer-capabilities" ]] || exit 97
printf 'known-validation-only\n' > "$CAPTURE.legacy"
exit 2
SH
    chmod +x "$BATS_TEST_TMPDIR/old-helper"
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/old-helper"
    run _claude permission
    [ "$status" -eq 0 ]
    [[ "$output" != *unavailable* && "$output" != *BODY_SENTINEL* ]]
    _assert_private_dispatch permission
    [ "$(cat "$CAPTURE.legacy")" = "known-validation-only" ]
    python3 - "$CAPTURE" <<'PY'
import base64,json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_PERMISSION_MODE"] == "plan"
assert e["TAVS_SESSION_ID"] == "standalone-session"
assert e["TAVS_CWD"] == "/fixture/standalone"
assert e["TAVS_TRANSCRIPT_PATH"] == "/fixture/transcript.jsonl"
assert not json.loads(base64.b64decode(e["TAVS_ORGANIZER_CONTEXT"]))["verifiedAgent"]
assert e["TAVS_ORGANIZER_INTAKE"] == "1"
PY
    export TAVS_TEST_HELPER_BIN="$selected"
}

@test "Portable Codex metadata preserves decoded argv fields without claiming native correlation" {
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/missing-helper"
    run bash "$CODEX" complete '{"type":"agent-turn-complete","thread-id":"thread\"\\escaped","cwd":"/fixture/space and\nnewline","last-assistant-message":"BODY_SENTINEL","tool_input":{"thread-id":"BODY_SENTINEL"}}'
    [ "$status" -eq 0 ]
    _assert_private_dispatch complete
    python3 - "$CAPTURE" <<'PY'
import base64,json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_SESSION_ID"] == 'thread"\\escaped'
assert e["TAVS_CWD"] == "/fixture/space and\nnewline"
assert not e["TAVS_TRANSCRIPT_PATH"]
assert not json.loads(base64.b64decode(e["TAVS_ORGANIZER_CONTEXT"]))["verifiedAgent"]
assert e["TAVS_ORGANIZER_INTAKE"] == "1"
PY
}

@test "Failed native intake is not reparsed by the portable metadata helper" {
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/failing-helper"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
if [[ "$1" == --validate-config ]]; then
    case "$2" in
        --organizer-capabilities) printf 'tavs-organizer-schema=1\n' ;;
        --managed-output-capabilities) printf 'tavs-managed-output-schema=1\n' ;;
        *) exit 43 ;;
    esac
    exit 0
fi
[[ "$1" == --organizer-intake ]] || exit 43
cat >/dev/null
exit 1
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
    export TAVS_PERMISSION_MODE=plan TAVS_SESSION_ID=stale TAVS_CWD=/stale \
        TAVS_TRANSCRIPT_PATH=/stale TAVS_ORGANIZER_CONTEXT=stale TAVS_ORGANIZER_INTAKE=1
    printf '%s' '{"session_id":"must-not-reparse","permission_mode":"plan","cwd":"/fixture","prompt":"BODY_SENTINEL"}' \
        > "$BATS_TEST_TMPDIR/payload.json"
    run _claude processing
    [ "$status" -eq 0 ]
    [[ "$output" == *'organizer metadata unavailable'* ]]
    _assert_private_dispatch processing
    python3 - "$CAPTURE" <<'PY'
import json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_PERMISSION_MODE"] == "default"
assert not e["TAVS_SESSION_ID"] and not e["TAVS_CWD"] and not e["TAVS_TRANSCRIPT_PATH"]
assert e["TAVS_ORGANIZER_CONTEXT"] is None and e["TAVS_ORGANIZER_INTAKE"] == "0"
PY
}

@test "failed selected intake retains native choice when core runs after capability disappears" {
    export TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/failing-native" CALLS="$BATS_TEST_TMPDIR/calls"
    export FAILED_INTAKE="$BATS_TEST_TMPDIR/failed-intake"
    cat > "$TAVS_TEST_HELPER_BIN" <<'HELPER'
#!/bin/bash
printf 'native:%s\n' "$1" >> "$CALLS"
case "$1" in
    --validate-config)
        [[ ! -e "$FAILED_INTAKE" ]] || exit 1
        case "$2" in
            --organizer-capabilities) printf 'tavs-organizer-schema=1\n' ;;
            --managed-output-capabilities) printf 'tavs-managed-output-schema=1\n' ;;
        esac ;;
    --organizer-intake) cat >/dev/null; : > "$FAILED_INTAKE"; exit 1 ;;
    --organizer-context) printf 'fixture-context\n' ;;
    --organizer-observe) ;;
    --managed-render) cat >/dev/null; exit 1 ;;
esac
HELPER
    chmod +x "$TAVS_TEST_HELPER_BIN"
    cat > "$FIXTURE/src/core/portable_helper.py" <<'HELPER'
#!/bin/bash
printf 'portable:%s\n' "$1" >> "$CALLS"
exit 1
HELPER
    cat > "$FIXTURE/src/core/trigger.sh" <<'CORE'
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/organizer-state.sh"
_tavs_organizer_begin "$1"
[[ "$_TAVS_HELPER_BACKEND" == native ]] || exit 43
env | /usr/bin/grep '^_TAVS_.*HELPER' > "$CAPTURE.private" || :
_tavs_render_begin
_tavs_render_queue background '#123456'
_tavs_render_flush
CORE
    printf '{"prompt":"BODY_SENTINEL"}' > "$BATS_TEST_TMPDIR/payload.json"
    run _claude processing
    [ "$status" -eq 1 ]
    [ "$(grep -c '^native:--validate-config$' "$CALLS")" -eq 2 ]
    [[ "$(cat "$CALLS")" != *portable:* ]]
    [[ "$(cat "$CALLS")" == *native:--managed-render* ]]
    [ ! -s "$CAPTURE.private" ]
}

@test "Missing portable runtime clears inherited metadata and organizer authority" {
    mkdir -p "$BATS_TEST_TMPDIR/no-python"
    run /usr/bin/env PATH="$BATS_TEST_TMPDIR/no-python" \
        TAVS_TEST_HELPER_BIN="$BATS_TEST_TMPDIR/missing-helper" /bin/bash -c '
source "$1/src/core/organizer-state.sh"
export TAVS_PERMISSION_MODE=plan TAVS_SESSION_ID=stale TAVS_CWD=/stale \
       TAVS_TRANSCRIPT_PATH=/stale TAVS_ORGANIZER_CONTEXT=stale TAVS_ORGANIZER_INTAKE=1
_tavs_organizer_intake claude "$$" || result=$?
[[ "$result" == 1 && "$TAVS_PERMISSION_MODE" == default ]]
[[ -z "$TAVS_SESSION_ID$TAVS_CWD$TAVS_TRANSCRIPT_PATH" ]]
[[ -z "${TAVS_ORGANIZER_CONTEXT+x}${TAVS_ORGANIZER_INTAKE+x}" ]]
' _ "$REPO_ROOT" <<< '{"session_id":"BODY_SENTINEL"}'
    [ "$status" -eq 0 ]
    [ "$output" = 'tavs: organizer metadata unavailable' ]
}

@test "Portable intake rejects invalid oversized and controlled metadata without body diagnostics" {
    run python3 - "$REPO_ROOT/src/core/portable_metadata.py" <<'PY'
import json,subprocess,sys
command=[sys.executable,sys.argv[1],"--legacy-intake","claude"]
bad=[b"BODY_SENTINEL",b'{"permission_mode":42}',
     b'{"session_id":"a\\u0007"}',b'{"cwd":"a\\u0000"}',
     b'{"session_id":"a\\ud800"}',b'{"unused":NaN}',
     json.dumps({"prompt":"BODY_SENTINEL"+"x"*1048577}).encode()]
for data in bad:
    result=subprocess.run(command,input=data,capture_output=True,timeout=3)
    assert result.returncode == 1 and not result.stdout
    assert b"BODY_SENTINEL" not in result.stderr
    assert b"Traceback" not in result.stderr
PY
    [ "$status" -eq 0 ]
}

@test "Portable intake returns within its input deadline when a pipe withholds EOF" {
    run python3 - "$REPO_ROOT/src/core/portable_metadata.py" <<'PY'
import subprocess,sys,time
start=time.monotonic()
p=subprocess.Popen([sys.executable,sys.argv[1],"--legacy-intake","claude"],
                   stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
try:
    p.stdin.write(b'{"prompt":"BODY_SENTINEL');p.stdin.flush()
    assert p.wait(timeout=2.7) == 1
    assert time.monotonic()-start < 2.7
    assert not p.stdout.read() and b"BODY_SENTINEL" not in p.stderr.read()
finally:
    p.stdin.close();p.stdout.close();p.stderr.close()
    if p.poll() is None:p.kill();p.wait()
PY
    [ "$status" -eq 0 ]
}

@test "Oversized input is rejected without raw diagnostics or core propagation" {
    python3 - <<'PY' > "$BATS_TEST_TMPDIR/payload.json"
import json
print(json.dumps({"prompt":"OVERSIZED_BODY_SENTINEL" + "x" * 1048577}))
PY
    run _claude permission
    [ "$status" -eq 0 ]
    [[ "$output" == *unavailable* && "$output" != *BODY_SENTINEL* ]]
    _assert_private_dispatch permission
}

@test "Installer structured notify argv survives spaces quotes and backslashes" {
    local config_home="$BATS_TEST_TMPDIR/config-home"
    mkdir -p "$config_home/.codex"
    printf 'model = "fixture"\n' > "$config_home/.codex/config.toml"
    run env HOME="$config_home" bash "$FIXTURE/src/install/install-codex.sh" <<< y
    [ "$status" -eq 0 ]
    python3 - "$config_home/.codex/config.toml" "$CODEX" <<'PY'
import json,subprocess,sys,tomllib
with open(sys.argv[1],"rb") as f: config=tomllib.load(f)
assert config["model"] == "fixture"
assert config["notify"] == ["bash",sys.argv[2],"complete"]
payload=json.dumps({"type":"agent-turn-complete","thread-id":"notify-thread",
                    "turn-id":"notify-turn","last-assistant-message":"ANSWER_BODY_SENTINEL"})
result=subprocess.run(config["notify"]+[payload],input="",text=True,capture_output=True)
assert result.returncode == 0, result.stderr
assert "BODY_SENTINEL" not in result.stdout + result.stderr
PY
    _assert_private_dispatch complete
    python3 - "$CAPTURE" <<'PY'
import base64,json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["TAVS_SESSION_ID"] == "notify-thread"
assert json.loads(base64.b64decode(e["TAVS_ORGANIZER_CONTEXT"]))["responseID"] == "notify-turn"
PY
}

@test "Installer keeps notify at root above existing tables and preserves backup" {
    local config_home="$BATS_TEST_TMPDIR/config-home"
    mkdir -p "$config_home/.codex"
    cat > "$BATS_TEST_TMPDIR/original.toml" <<'TOML'
# retain this comment
notify = ["old-command"]
model = "fixture"

[tui]
notifications = ["agent-turn-complete"]
theme = "fixture"
TOML
    cp "$BATS_TEST_TMPDIR/original.toml" "$config_home/.codex/config.toml"
    run env HOME="$config_home" bash "$FIXTURE/src/install/install-codex.sh" <<< y
    [ "$status" -eq 0 ]
    cmp "$BATS_TEST_TMPDIR/original.toml" "$config_home/.codex/config.toml.bak"
    python3 - "$config_home/.codex/config.toml" "$CODEX" <<'PY'
import sys,tomllib
text=open(sys.argv[1]).read()
c=tomllib.loads(text)
assert c["notify"] == ["bash",sys.argv[2],"complete"]
assert c["model"] == "fixture"
assert c["tui"] == {"notifications":["agent-turn-complete"],"theme":"fixture"}
assert "# retain this comment" in text
assert text.index("notify =") < text.index("[tui]")
PY
}

@test "Installer refuses existing multiline notify without changing config" {
    local config_home="$BATS_TEST_TMPDIR/config-home"
    mkdir -p "$config_home/.codex"
    cat > "$BATS_TEST_TMPDIR/original.toml" <<'TOML'
notify = [
    "bash",
    "/fixture/old-command",
]

[tui]
notifications = ["agent-turn-complete"]
TOML
    cp "$BATS_TEST_TMPDIR/original.toml" "$config_home/.codex/config.toml"
    run env HOME="$config_home" bash "$FIXTURE/src/install/install-codex.sh" <<< y
    [ "$status" -ne 0 ]
    [[ "$output" == *multiline* ]]
    cmp "$BATS_TEST_TMPDIR/original.toml" "$config_home/.codex/config.toml"
    [ ! -e "$config_home/.codex/config.toml.bak" ]
}
