# Phase 4 adapter intake and privacy reconnaissance

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

## Scope and main result

Read-only inspection of current adapters, core dispatch, hook definitions,
installer source, connected metadata consumers and test source under:

`/Users/cs/local/code/apps/terminal-agent-visual-signals/`

No hook, installer, native request, session transcript or personal config was
executed/read. No project file changed. Official OpenAI documentation was fetched
only to resolve the notify transport contradiction in local references.

The smallest connected change is one strict allowlisted intake/parser shared by
Claude and Codex, consumed before core dispatch; a typed once-per-delivery identity
carried into background rendering; and removal of raw/identifying diagnostic
sinks in the touched paths. Preserve existing permission, context, session and
directory variables, rather than blanking them to satisfy privacy tests.

## Allowed metadata and existing consumers

### Claude stdin payload

`src/agents/claude/trigger.sh:19` reads all stdin into `_tavs_stdin`; four sed
extractions at lines 27-44 currently populate these required variables:

| Top-level field | Preserve as | Existing behavior |
|---|---|---|
| `permission_mode` | `TAVS_PERMISSION_MODE` | Mode-aware processing colors in theme-config-loader.sh:367 |
| `transcript_path` | `TAVS_TRANSCRIPT_PATH` | Existing context fallback selector in context-data.sh:105 |
| `session_id` | `TAVS_SESSION_ID` | Session icon registry; session-icon.sh:61 shortens it internally |
| `cwd` | `TAVS_CWD` | Directory/worktree identity; dir-icon.sh:244 |

Parse actual top-level JSON keys with string type checks and input/field bounds.
Do not keep the greedy sed patterns: they do not decode JSON escapes and can
select a later nested same-name field. Shell fragments in a JSON string are data,
never a command or generated assignment to eval/source.

Existing known permission values are default, plan, acceptEdits, dontAsk and
bypassPermissions. The consumer treats dontAsk as acceptEdits; unknown values
currently make no mode color adjustment. Keep a fixed allowed enum for new
classification and make unrecognized coverage explicit. Do not map arbitrary
strings into variable names.

Additional useful body-free fields for the new typed observation are
`hook_event_name` and `notification_type`, limited to supported event names/types.
They distinguish PermissionRequest from its permission_prompt companion and
meaningful hook idle from generated idle gradients. The current adapter does
not extract them. Do not invent a Claude turn/request ID: the inspected hook
contracts do not establish one for every event. Use a local delivery identity
without labeling it a provider request ID.

The transcript path is a legacy context selector, not new organizer authority.
The new intake/parser should not follow it, retain transcript content or put
the path in diagnostics/new observation records merely because the old context
consumer accepts it. Keep existing context/identity behavior and the separate
StatusLine bridge; no actual transcript was inspected during this task.

### Codex completion argv payload

Current adapter `src/agents/codex/trigger.sh:14` sets the agent then execs core
with every supplied argument. It performs no JSON parsing.

The inspected official [Notifications documentation](https://learn.chatgpt.com/docs/config-file/config-advanced?translationFallback=de-DE)
states that notify receives a single JSON argument. Its common fields include
type, thread-id, turn-id and cwd, alongside body fields. This is argv transport,
not stdin. `src/agents/codex/HOOKS_REFERENCE.md:90` incorrectly claims stdin;
its copied examples are not current transport evidence.

Keep only these supplied metadata fields:

- `type`, validated as `agent-turn-complete` for this existing integration.
- `thread-id`, an opaque provider session/thread identifier.
- `turn-id`, a supplied completion-occurrence ID useful for deduplication.
- `cwd`, legitimate directory display/identity context.

Never retain input-messages or last-assistant-message. Missing supported IDs
remain missing; do not substitute an invented provider ID. A local intake UUID
can label receipt while automatic eligibility stays appropriately limited.
Existing completion-only coverage remains partial. This phase does not install
new Codex lifecycle hooks or infer processing from completion.

## Exact notify forwarding bug and minimal repair

`src/install/install-codex.sh:73` constructs:

```toml
notify = ["bash", "-lc", "/absolute/path/trigger.sh complete"]
```

With the provider's appended JSON argument, bash receives the command string
followed by that argument as its `$0`. The command string does not reference or
forward `$0`, so the adapter never receives the payload. This explains metadata
loss without executing the installer or provider.

The smallest cleaner template is a structured argv vector:

```toml
notify = ["bash", "/absolute/path/src/agents/codex/trigger.sh", "complete"]
```

The appended JSON then reaches the adapter as its second argument. The adapter
consumes it through the allowlisted parser and calls core with only the known
state and valid fixed flags. No raw JSON argument reaches core debug or a child
timer. This also avoids login-shell startup sourcing and an embedded shell
command whose path must be separately shell-quoted.

Quote/escape the script path correctly as a TOML string. Installation tests use
an owned temporary config and validate the resulting array, including a path
with spaces. Do not overwrite or inspect real ~/.codex/config.toml during tests.
Update the directly affected local notify documentation so it does not tell
operators to use the broken vector/stdin example.

## Raw diagnostic sinks that must be removed or narrowed

### Adapter payload export

- `src/agents/claude/trigger.sh:48-49` exports the ENTIRE raw input as
  `_TAVS_HOOK_PAYLOAD`. Delete that propagation after needed metadata is
  extracted. Oversized payloads in the environment can also break child exec.
  Clearing only the later log text while retaining this export is incomplete.
- Unset inherited `_TAVS_HOOK_PAYLOAD` at the sanitized core boundary too, so an
  older wrapper or direct caller cannot propagate raw input into idle/delayed
  children even after the current Claude wrapper stops exporting it.
- Codex's current `exec ... "$@"` would propagate raw JSON after forwarding is
  repaired unless the adapter explicitly consumes the payload first.

### Core invocation diagnostics

`src/core/trigger.sh:114`, `debug_log_invocation`, runs before the no-TTY exit.
It currently writes:

- all argv at line 129 and free-form first argument at line 130;
- PWD, pwd and formatted cwd at lines 133-135;
- parent process command arguments via `ps ... comm,args` at line 143;
- `_TAVS_HOOK_PAYLOAD` at lines 152-153;
- direct stdin lines as fallback at lines 156-160;
- source/config paths and an invocation summary containing cwd at line 189.

Replace those with fixed allowlisted state/event/agent, boolean availability,
bounded numeric PID/generation/timing and result codes. Do not read stdin for
debugging. Do not log full process arguments. Validate state before using it as
a log filename component. A generic JSON parse error should not echo the
offending payload or unknown fields.

### Title and directory diagnostics

- `debug_log_title_trace:194` logs full format and `title_output` at line 211;
  those can contain user titles/directory information. Preserve actual terminal
  title rendering/state, but log only fixed event/result metadata.
- `src/core/title-management.sh:529-533` calls that trace with the full composed
  title. Fixing the trace centrally avoids rewriting title composition.
- `src/core/dir-icon.sh:259` logs cwd on a cache hit; line 330 logs dir_path/cwd.
  These are connected DEBUG_ALL sinks reached by a new-prompt/reset. Narrow
  these diagnostics too or the whole-intake sentinel boundary remains false.
- Session icon debug keys are identifiers/icons rather than body content; keep
  only the useful bounded identifiers and avoid expanding diagnostic scope.

Directories/titles remain legitimate display metadata and existing identity
cache input. The privacy requirement is not a request to erase that behavior;
it specifically excludes these values from diagnostics and raw body retention.

## Hook definitions and fixed dispatch flags

Root marketplace `hooks/hooks.json` has `processing new-prompt` for
UserPromptSubmit and `reset session-end` for SessionEnd. Those flags are essential
to reset subagent counters/revalidate identity and release icons, respectively.
Other routes cover permission, completion, idle, compacting, subagent and tool
errors. Preserve their fixed arguments when introducing intake.

The duplicate `src/agents/claude/hooks.json` omits both flags. It is connected to
the manual installer: `src/install/install.sh:198` reads that file. This is real
route drift, not only an unused documentation copy. At minimum keep the canonical
root route behavior; verify/fix the two duplicate route commands if this phase's
manual-install path is included. Do not add unrelated lifecycle routes.

## Once-per-intake identity and synthetic callbacks

Create the local delivery ID once at actual adapter/direct-core intake, together
with observation time, supported provider IDs and verified producer metadata.
Provider session ID alone is not process/surface lifetime. Use existing
`process-identity.swift` generation/TTY/foreground-family checks; an uncorrelated
record is visible as unavailable/last-known and cannot drive automatic focus.

`src/core/trigger.sh:527` handles tool_error, then starts a detached 1.5 s callback
at lines 542-550. That callback invokes core again as subagent or processing.
Without an explicit carried intake identity/synthetic marker, a new helper at
every core invocation would invent a second meaningful event and could clear an
unacknowledged attention cue. Carry original delivery/producer identity and mark
that call as synthetic restoration; it changes intent/state rendering without
creating a new meaningful hook occurrence.

Similarly completion spawns unified_timer_worker at lines 394-396. The worker
records complete/idle in the legacy state file at `idle-worker-background.sh:159`
and updates gradients, but those are not new completion/idle hook deliveries.
Carry the original intake identity into the worker and publish only ordinary
background intent on its stage transitions. Timer polling must not regenerate
delivery IDs. Actual new completion hook deliveries may create new receipts even
when a provider offers no intervening processing hook.

Preserve producer validity for delayed work; do not let a late background callback
adopt itself as a new agent after that agent exited or the TTY was reused.

## Native parsers/helper compatibility

The existing Swift executable can use Foundation JSONSerialization or Codable
for a bounded allowlisted payload parser and integer ProcessGeneration. Prefer
that existing native helper over a new dependency/parser framework. Bash 3.2 can
consume a fixed typed field protocol without eval/source; avoid newline-only
export formats for cwd/session strings that JSON can legitimately escape.
Do not expose raw JSON through command-line diagnostics or write it to a temporary
file merely to pass it between parsers.

Host discovery confirmed `/opt/homebrew/bin/jq`, `/opt/homebrew/bin/python3` and
an executable `/usr/bin/python3`. They are available development/test tools,
not proof of a shipped cross-machine dependency. jq and Python's json module are
useful for owned test assertions. Do not add a second production fallback parser
that silently masks an absent/failed Swift helper.

For safe helper capability detection, use the existing known
`--validate-config` entry with a dedicated safe query qualifier before invoking
new verbs. Old helpers interpret the qualifier as a missing validation path and
exit nonzero instead of falling through to SwiftUI. An unsupported helper must
report unavailable coverage. No guessed new flag can be passed to an old binary.

Current TAVSAppMain checks isolated Sessions environment BEFORE headless flags.
Ensure capability/metadata calls do not inherit those UI-launch variables, or
move known safe headless dispatch ahead of that isolated UI selector. Otherwise
even a known validation query can launch IsolatedSessionsApp under that environment.

The current runner chooses one explicit source-built
`TAVS_TEST_HELPER_BIN` and supplies private HOME/CFFIXED_USER_HOME/runtime/tmp/
XDG roots plus a regular fake TTY. Reuse it. No helper/compatibility probe was
executed during this reconnaissance.

## Existing tests and minimum new safe tests

- `tests/test-statusline-bridge.sh:431-485` duplicates the old sed extraction
  algorithm, including a reconstructed adapter block. It does not actually
  verify the changed production adapter. Replace/add targeted tests that run
  the real adapter against an owned core capture stub/source fixture or exercise
  the shared actual parser, with exported metadata assertions.
- That script has existing statusline/context fixtures; keep them as focused
  regression coverage with private `_TAVS_BRIDGE_TTY_SAFE`/cache paths. Its
  bridge source can auto-resolve/open `/dev/tty` if that override is missing.
- `tests/test-integration-phase6.sh` has useful synthetic context/mode/title
  assertions, but lines 268-283 inspect the personal plugin cache. Its title
  composed checks do not execute hooks. Do not run the entire script as a
  source-only intake regression without separating/isolating that cache section.
- `tests/integration/identity-teardown.bats` checks session-end icon cleanup with
  fake TTY and private state/home. Its env -i child omits the new helper selection
  key, so propagate the selected helper when testing new observations.
- No current dedicated Claude/Codex metadata-intake test was found. Add the
  planned `tests/integration/hook-observations.bats` and focused Swift parser/
  typed-record tests, rather than relying on source-string matching.

Required cases: valid escaped strings, supported metadata exports, missing fields,
wrong types, invalid/oversized JSON, nested misleading keys, shell syntax as data,
unknown event values, missing/unsupported helper, real notify argv shape and
supplied versus missing turn IDs. With DEBUG_ALL=1, inject synthetic prompt/tool/
answer sentinels through Claude stdin, Codex argv, inherited raw-payload env and
direct core stdin. Assert absence from new records AND connected debug files,
while allowed metadata still reaches the intended consumers. Generic parser
errors must not contain the sentinels.

Completion smoke tests need owned worker cleanup before deleting fake TTY files:
the worker checks `[[ ! -w tty ]] && continue` before its max-runtime branch.
Deleting capture files immediately can strand a worker indefinitely. Do not
reuse whole `tests/test_trigger.py` as a safe adapter smoke suite until that
separate known cleanup issue is repaired. Use exact launched/captured worker
identities, not global process matching. Delayed tool-error tests likewise own
their callback lifetime and file until completion.

## Minimum connected edit set

1. Planned `src/core/organizer-state.sh`, Swift typed intake/record code and
   TAVSAppMain headless handling: bounded parser, safe support query, one delivery
   identity, verified producer binding and synthetic continuation metadata.
2. Claude/Codex wrappers: preserve allowed existing fields, consume payload
   before dispatch, remove raw export/argv/stdin forwarding.
3. `src/install/install-codex.sh` and directly affected notify docs: structured
   argv template and actual argv transport description.
4. `src/core/trigger.sh`, idle worker semantic background path and the connected
   dir-icon diagnostic lines: no raw/free-form debug retention; original intake
   identity in idle/tool-error restoration. Keep title composition intact.
5. Existing fixtures plus planned hook-observations tests: metadata correctness,
   privacy sentinels, malformed/unsupported paths and owned worker lifetime.

No provider SDK, protocol standardization, lifecycle expansion, server, ledger,
generic fallback hierarchy or personal configuration migration is required.
