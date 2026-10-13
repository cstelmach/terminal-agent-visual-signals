> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# Claude Review Report

===DIMENSION_RATIONALE===
The five default code dimensions fit Pass D. This partition is the shell, CLI, hook-adapter, installer, plist and shell/Python test layer of the organizer and reversible-focus branch, `e113fb8..71e0f60`. The fifth dimension is performance rather than completeness. Performance matters here because this pass changes per-hook and per-shell-start process fan-out. Completeness against SPEC/PLAN is assessed under correctness and test_coverage.

Weights: correctness 25%, security 25%, maintainability 20%, test_coverage 15%, performance 15%.

Phase and file coverage for this pass. All 42 primary targets were read in full.

| PLAN phase | Pass D primary targets reviewed | Adjacent context used |
|---|---|---|
| 1 Native catalogue | src/macos/TAVSApp/Resources/Info.plist | ghostty-catalog.swift |
| 2 Sessions/priorities | (no shell targets) | none |
| 3 Test isolation | tests/run-isolated.sh, tests/conftest.py, tests/unit/test-isolation.bats, tests/unit/mute-gate.bats, tests/integration/idle-worker-mute.bats, tests/integration/priority-pinning.bats, tests/integration/liveness.bats | session-state.sh, title-state-persistence.sh |
| 4 Observations/intent | src/agents/claude/trigger.sh, src/agents/codex/trigger.sh, src/agents/claude/hooks.json, src/core/organizer-state.sh, src/core/terminal-osc-sequences.sh, src/core/idle-worker-background.sh, src/core/trigger.sh, src/core/title-management.sh, src/core/backgrounds.sh, src/core/dir-icon.sh, src/install/install-codex.sh, tests/integration/hook-observations.bats, tests/integration/background-intent.bats, tests/integration/emit-osc.bats, tests/test_idle_worker.py, tests/test_title_composition.py | organizer-intake.swift, terminal-visual-state.swift, terminal-render.swift |
| 5 Suspension readers | src/core/visual-restrictions-state.sh, src/core/lock-state-lib.sh, src/core/mute-gate.sh, src/cli/cmd-status.sh, src/cli/cmd-lock.sh, src/shell/tavs-shellrc.sh, tests/fixtures/visual-restrictions-state.json, tests/unit/visual-restrictions-state.bats, tests/integration/visual-restrictions-parity.bats, tests/unit/cmd-lock.bats, tests/unit/shellrc.bats | visual-restrictions-state.swift, visual-restriction-policy.swift |
| 6 Independent recovery | src/cli/cmd-recover.sh, tavs, src/cli/cmd-help.sh, tests/unit/cmd-recover.bats, tests/integration/managed-background.bats | managed-output-entry.swift, visual-recovery.swift, ProcessRunner.swift |
| 7 Previews/packaging | src/cli/cmd-sync.sh, tests/unit/cmd-sync.bats | cmd-install-shell-integration.sh |
| 8-9 Manual/automatic focus | Shell side only: hook event and intake fidelity in the adapters and hook-observations.bats | attention eligibility in terminal-visual-state.swift |

Falsification hypotheses examined before scoring:

1. **A queued or delayed shell writer can still paint after recovery.** Dismissed for Ghostty paths.
   - Every ordinary style now enters `_tavs_render_queue`/`_tavs_render_flush` (src/core/organizer-state.sh:133-195).
   - The native writer validates revision and policy under the device lock (visual-recovery.swift:193-199).
   - `emit_osc` is removed, and the shellrc has no raw `printf` paint.
   - The one remaining direct path is the Kitty `kitten @` subprocess (src/core/backgrounds.sh:93-130). That is outside the Ghostty boundary.
2. **CLI recovery could launch native work before suspension is persisted.** Dismissed.
   - src/cli/cmd-recover.sh:31-34 writes the marker before any helper probe at lines 36-50.
   - tests/unit/cmd-recover.bats:15 makes the stub fail with 43 if the marker is absent.
3. **A delayed tool-error restore can disturb a newer completion.** Confirmed in a narrow window (MEDIUM-1 below). The existing test only covers a Stop that arrives before the delayed check.
4. **Hook bodies leak into debug or state files.** Dismissed.
   - Adapters pass only fixed states (src/agents/claude/trigger.sh:16-23).
   - `_TAVS_HOOK_PAYLOAD` is unset.
   - debug_log_invocation writes fixed fields only (src/core/trigger.sh:70-80).
   - Sentinel tests cover the exported-payload, stdin and argv paths.
   - A residual transient-tempfile note is recorded as LOW-4.
5. **Existing standalone or plugin-only behavior is preserved.** Not preserved (HIGH-1). Without a capable native helper, every ordinary hook signal and the shell lock self-paint disappear.
===END_DIMENSION_RATIONALE===

===EXECUTIVE_SUMMARY===
Overall grade: 6.35
Risk level: Medium
Verdict: CONCERN

**What holds.** Within Pass D the shell side enforces the core safety contracts:
- Ordinary styling routes into a single typed, native-validated render.
- Historical pending replay is removed.
- Persistent suspension is parsed as data with shared Bash, zsh and Swift fixtures.
- `tavs recover` persists suspension before resolving the helper.
- Adapter intake discards bodies and free-form arguments.

**What does not hold.**
- **Compatibility (HIGH-1):** every visual signal, titles and bells included, now depends on an installed, capable `/Applications/TAVS.app` helper. Plugin-only installs, older app builds and non-macOS hosts silently lose all signaling and the Claude permission-mode/session metadata. This contradicts the SPEC's "preserve direct ordinary signaling" and the PLAN's "nonbackground hook styling stays intact", unless root deliberately accepts it as a product boundary.
- **Timer race (MEDIUM-1):** a check-then-act race in the delayed tool-error restore can kill a newer completion idle timer.
- **Stale test (MEDIUM-2):** one integration test asserts the removed pending cache and invokes the real installed app outside isolation.
- **Process fan-out (MEDIUM-3):** about six helper launches per hook and three per interactive shell start. Header comments still claim <1 ms.

This pass is complete for its primary scope. It is not an aggregate implementation sign-off. Native salience, navigation and recovery acceptance remain unverified.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
**HIGH-1: Absent or older native helper silently disables all ordinary signaling and Claude metadata**

Locations:
- src/core/organizer-state.sh:164-177 and 190-194
- src/agents/claude/trigger.sh:25-31
- src/core/organizer-state.sh:27-50
- src/shell/tavs-shellrc.sh:103-106

Trigger: the Claude plugin is installed or synced, but `/Applications/TAVS.app/Contents/MacOS/TAVSApp` is missing, is an older build without `--managed-output-capabilities`, or the host is not macOS. Additional trigger: `resolve_tty` returns `/dev/tty`, which the native side rejects.

Situation: before this branch the hook path wrote OSC bytes directly, and `TAVS_PERMISSION_MODE`, session ID, transcript path and cwd were extracted in the adapter. Now:
- `_tavs_render_flush` sets `result=1` when `_tavs_managed_helper` fails. Background, palette, title, bell and the iTerm image are dropped together.
- `_tavs_organizer_intake` exports `TAVS_PERMISSION_MODE=default` and empty session/cwd when `_tavs_organizer_helper` fails.
- The shellrc no longer self-paints locks or pauses. It prints "managed output helper unavailable" on every interactive shell start.

Behavior: no visual output from any hook. Mode-aware processing colors and session-ID-keyed identity icons are lost. A `tavs lock now` hard lock no longer paints new shells without the app binary. The only symptom is a stderr line per hook or per shell start.

Impact:
- SPEC "Observations and ordinary background intent" says to "preserve direct ordinary signaling when no controller owns an effect".
- SPEC also says "Preserve existing legitimate metadata-dependent behavior".
- PLAN 6.2 says "Legitimate nonbackground hook styling stays intact".
- The brief lists "existing compatibility behavior".

The managed-background.bats tests at lines 226-238 and 370-386 deliberately pin "no raw fallback". This looks like an intentional design choice that was never reconciled with those requirements.

Suggestion: root should make an explicit product decision.
- If helper-required is the accepted boundary, state it in the SPEC/API, the shell-integration help and the plugin docs. Emit the unavailability notice once rather than per hook or shell.
- Independently, keep the four allowlisted metadata fields available without the helper. They were previously extracted without retaining bodies. Mode colors and identity keys should not depend on app presence.

Confidence: high on behavior; medium on whether it is intended.

**MEDIUM-1: Delayed tool-error restore can kill a newer completion idle timer**

Locations:
- src/core/trigger.sh:408-418 (`_tavs_managed_check_context` at 410, synthetic re-invocation at 413/415)
- src/core/trigger.sh:214-215 and 229 (`kill_idle_timer` and `record_state` in the processing case)
- src/core/trigger.sh:350-352 (subagent case)

Trigger:
1. A PostToolUseFailure hook runs.
2. 1.5 s later the subshell's `_tavs_managed_check_context` passes because the observation is still the tool-error delivery.
3. A Stop hook then runs completely: it publishes an observation, renders the completion and starts `unified_timer_worker` with its PID in the state DB.
4. Only then does the synthetic `trigger.sh processing` reach line 215.

The window spans re-sourcing about 14 core modules plus a helper capability probe, which is tens to hundreds of milliseconds.

Behavior:
- `should_change_state processing` passes because processing (30) outranks complete (20).
- `kill_idle_timer` kills the completion worker.
- `record_state processing` overwrites the session state.
- The synthetic render is then rejected as stale (exit 3), so nothing repaints.
- For the subagent branch, `increment_subagent_count` also runs. That increment is a pre-existing issue, not introduced here.

Impact: the terminal remains at the completion color with no idle graduation and no forced reset. The session state DB claims "processing". Observations and cues are unaffected. The visual and the state-file inconsistency persists until the next real hook. The existing test, background-intent.bats:261-294, sends Stop at 0.5 s, before the check, so this ordering is untested.

Suggestion: synthetic restore invocations should not kill timers or record state. The tool-error hook already killed any prior timer at line 395, so a live timer at restore time necessarily belongs to a newer delivery. In synthetic mode, abort when `SESSION_TIMER_PID` is alive, and skip `kill_idle_timer`, `record_state` and the subagent increment. Add a test that starts the completion between the check and the synthetic dispatch. A test-only delay hook is acceptable.

Confidence: medium. The window is narrow but real.

**MEDIUM-2: priority-pinning.bats asserts the removed pending-cache contract and escapes isolation**

Locations:
- tests/integration/priority-pinning.bats:1-19 (header)
- tests/integration/priority-pinning.bats:27 (`mktemp -d` outside `TAVS_TEST_ROOT`)
- tests/integration/priority-pinning.bats:61-70 (`env -i` drops `TAVS_TEST_HELPER_BIN`)
- tests/integration/priority-pinning.bats:87-97, 114-121, 132-141 (assert `pending/*.osc` contains OSC 11 bytes)

Trigger: running the file under tests/run-isolated.sh, or any other way.

Behavior:
- No production code path creates `pending/*.osc` any more. `_tavs_mute_buffer_*` are no-ops (mute-gate.sh:152-154), the flush never writes pending, and recovery deletes them.
- The `[ -f "$pending" ]` assertions, now without the former `skip`, must fail.
- `env -i` removes `TAVS_TEST_HELPER_BIN`, so `_tavs_organizer_helper`/`_tavs_managed_helper` execute the real installed `/Applications/TAVS.app` binary. This contradicts PLAN Phase 3's isolation rule.
- The header still documents verbatim pending replay, which the SPEC forbids.

Impact: either the reported 165 isolated shell tests excluded this file, or it fails. The test also exercises the live app binary.

Suggestion: delete it, or rewrite it to assert latest-wins typed intent per TTY using a stub helper, with `TAVS_TEST_HELPER_BIN` preserved and `TEST_HOME` under `TAVS_TEST_ROOT`.

Confidence: high on the contradiction; medium on whether it is in the executed set.

**MEDIUM-3: Per-hook and per-shell-start native process fan-out, with stale cost claims**

Locations:
- src/agents/claude/trigger.sh:26-31
- src/core/organizer-state.sh:3-20, 53-65, 67-84, 164-178
- src/shell/tavs-shellrc.sh:103-117 and header 17-18
- the cmd-install-shell-integration.sh help ("Cost: <1ms")

Trigger: every Claude hook (several per tool call) and every interactive shell start, with the app installed.

Behavior per hook:
- The adapter runs an organizer capability probe and an intake.
- After `exec`, the core trigger loses the unexported `_TAVS_ORGANIZER_HELPER_CHECKED` and probes again, then observes.
- The flush runs a separate managed-output probe, then the render.

That is about six launches of the full TAVSApp binary per hook, plus one for each delayed tool-error check. Shell start runs a probe, `--managed-register` and `--managed-current`. Nothing in the shell bounds binary launch time; only in-process work has native deadlines.

Impact:
- Hooks are async, so the agent is not blocked. Latency and CPU still scale with tool calls.
- Interactive shell start moves from "zero forks" to three binary launches.
- Header comments now state false performance guarantees.

Suggestion:
- Export the verified helper path and checked flag across the adapter-to-core `exec`.
- Fold the two capability probes into one query.
- Update the shellrc header and installer help to the real cost.

Confidence: high.

**LOW-1: Forced idle reset resets the palette unconditionally**

Locations: src/core/idle-worker-background.sh:129 -> native visual-recovery.swift:357.

Trigger: `MAX_TIMER_RUNTIME` is reached with `ENABLE_PALETTE_THEMING=false` or `ENABLE_BACKGROUND_CHANGE=false`.

Behavior: the native forced reset always prepends OSC 104 and emits OSC 111. Previously the palette reset was gated by `should_enable_palette_theming` and the background by `should_send_bg_color`.

Impact: a palette set by another tool is reset after about 450 s. This conflicts with the SPEC guidance not to use OSC 104 for background-only clears.

Suggestion: pass the gating decision to `--managed-forced-reset`, or skip 104 when palette theming is off.

Confidence: high.

**LOW-2: Shell mute predicate diverges from the authoritative Swift policy, and several tests validate the shell copy**

Locations:
- src/core/mute-gate.sh:108 accepts an empty `REASON`.
- visual-restriction-policy.swift:56 requires `MuteReason(rawValue:)`. The MuteReason cases are not visible to this reviewer.
- Swift `fields()` also requires every line to be quoted `KEY="value"`.

Trigger: a mute.state without `REASON`, or with unquoted lines.

Behavior: the shell gate now governs only Kitty image suppression. However, emit-osc.bats:23-46, liveness.bats:22-41 and idle-worker-mute.bats:21-41 implement their stub helpers with `_tavs_check_mute_state`. Those suites therefore prove the shell predicate, not the native policy that decides production output. mute-gate.bats:171-191 is named "matches Swift" for a REASON-less file.

Suggestion: align the shell predicate with Swift, or label it Kitty-only. Make those stubs policy-agnostic and rely on Swift policy tests for semantics.

Confidence: medium.

**LOW-3: Vacuous shellrc assertions**

Locations: tests/unit/shellrc.bats:129-149, 161-173, 186-199.

Behavior: assertions such as "expired lock", "active unlock grant", "non-numeric LOCK_UNTIL", "stale mute heartbeat" and "dead APP_PID" now check only that stdout has no `]11;`. The shellrc never emits OSC on any path, so these cannot fail. The stub helper also ignores policy.

Suggestion: assert the helper's typed decision (owned PTY via the real helper), or remove the duplicates.

Confidence: high.

**LOW-4: Codex notify JSON is written to a transient here-string temp file**

Location: src/agents/codex/trigger.sh:28.

Trigger: Bash 3.2 here-strings are backed by a temp file in `TMPDIR`.

Behavior: the full notify JSON, including `last-assistant-message` and `input-messages`, briefly exists on disk. It is unlinked after open.

Impact: transient only, and the argv is already visible to `ps` because of how Codex notify works. Still unnecessary against the "do not retain bodies" intent.

Suggestion: use `_tavs_organizer_intake codex "$PPID" < <(printf '%s' "${2:-}")`. This keeps the exports in the current shell and goes through a pipe.

Confidence: high on mechanism, low on impact.

**LOW-5: Gemini/OpenCode hooks log an observation failure on every invocation**

Locations: src/core/organizer-state.sh:63-64 vs terminal-visual-state.swift:860.

Behavior: `--organizer-context` accepts `gemini`/`opencode`, but `publishObservation` validation rejects providers other than claude and codex. Every such hook prints "organizer observation unavailable". Rendering still proceeds.

Suggestion: skip the observe call for unsupported providers.

Confidence: medium. The unchanged Gemini adapter was not supplied.

**LOW-6: Codex installer rewrite loses metadata and over-deletes**

Location: src/install/install-codex.sh:121-129.

Behavior: the config is rebuilt into a new `config.toml.tmp` and renamed. This drops the original mode and ownership, replaces a symlinked config with a regular file, and deletes `notify =` lines under any table, not only the root. A backup is kept.

Suggestion: preserve mode and resolve symlinks before replacing; restrict deletion to root-level lines.

Confidence: medium.

**LOW-7: One unsafe title component rejects the whole render, including the background**

Locations: src/core/title-management.sh:526 and organizer-state.sh:147-149 -> terminal-render.swift:40-42.

Trigger: a title token containing a tab or another C0/C1 character, for example the context-bridge `{MODEL}` or a user base title.

Behavior: the native side rejects the entire 23-field payload with exit 1, so the background signal is lost as well. The shell does not sanitize the composed title.

Suggestion: sanitize the composed title in the shell with `sanitize_for_terminal` before queueing.

Confidence: medium.

**LOW-8: Decoded cwd can forge dir-icon cache lines**

Locations: src/core/organizer-state.sh:44 -> src/core/dir-icon.sh:316-326.

Trigger: the JSON-decoded `cwd` contains a newline. Swift intake allows control characters for cwd, and the old sed extraction kept `\n` literal.

Behavior: an injected `worktree_icon=...` line can display arbitrary printable text in the title. It is cosmetic; the native `safeText` blocks escapes.

Suggestion: reject control characters for cwd as is already done for `session_id`.

Confidence: medium.

**Test-environment notes (LOW)**
- tests/test_idle_worker.py:85-90 depends on `rg` being installed.
- tests/integration/baseline-regression.bats is unchanged, but the byte path it pins now requires the helper. Unverified whether it was updated or excluded.

**Dismissed hypotheses**
- Shell versus Swift marker parsing: consistent. Exact two-line content, the <128-byte bound and the missing-parent walk match visual-restrictions-state.swift:98-134. The shared fixture covers CRLF, NUL, reorder, oversize and shell syntax.
- Historical BEL/title replay: the replay verb is now `--managed-reconcile` (trigger.sh:183-196), synthetic renders cannot queue a bell (organizer-state.sh:134), and pending buffers are no-ops.
- Lock/unlock under suspension: inert locks are saved, the unlock bypass writes nothing, and status is shown in `tavs status` and `tavs lock status`.
- Sync packaging: the root dispatcher, both hooks.json files, both adapters, CLI, core, config, shellrc and Codex installer are copied, with required-failure propagation. Not restarting old workers is a documented deployment boundary.
- `TAVS_TEST_HELPER_BIN` honored in production paths: an attacker who controls the environment already controls execution. Not a security finding.

**Empirical acceptance gaps (not defects)**
- Native salience and preview visibility.
- Go To across Spaces.
- Active-cue and relaunch UI.
- Real-Ghostty recovery.
- Automation permission from the built bundle.

These remain unverified. No shell test in this pass can prove them.

**Supported boundaries**
- The Kitty `kitten @` direct path is outside the Ghostty scope.
- Codex completion-only coverage is unchanged by design.
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| correctness | 6/10 | The shell enforces typed, suspension-checked rendering and persist-first recovery. HIGH-1 (helper-absent loss of all signaling and metadata) and MEDIUM-1 (tool-error restore can kill a newer completion timer) are unresolved. |
| security | 8/10 | Bodies, argv and payload are discarded; markers are parsed as data; nothing is sourced; title/cwd go through native control-character validation. Only transient here-string exposure (LOW-4) and a cosmetic cwd cache injection (LOW-8) remain. |
| maintainability | 6/10 | Stale cost and paint comments in the shellrc and installer, and a stale priority-pinning header. Duplicated capability probes; the shell mute predicate is kept but is non-authoritative and diverges (LOW-2). |
| test_coverage | 6/10 | Strong owned-PTY, sentinel and recovery-order tests. However, priority-pinning.bats contradicts the architecture and escapes isolation, several shellrc assertions are vacuous, stub helpers re-implement policy in shell, and the MEDIUM-1 race is untested. |
| performance | 5/10 | About six full-binary helper launches per hook and three per interactive shell start, with duplicated probes across `exec`. Shell start moves from zero forks to three process launches. |
| Overall | 6.35/10 | 25%, 25%, 20%, 15%, 15% respectively |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. **Decide and document the helper-required boundary (HIGH-1).**
   - Keep the allowlisted permission-mode, session, transcript and cwd extraction available without the helper.
   - Emit helper unavailability once rather than per hook or per shell start.
   - If standalone signaling is a requirement, reconcile that with the "no raw fallback" tests explicitly.
2. **Make synthetic tool-error restores non-destructive (MEDIUM-1).**
   - In synthetic mode, abort when a live idle timer exists.
   - Skip `kill_idle_timer`, `record_state` and the subagent increment.
   - Add an ordering test where the completion lands between the check and the dispatch.
3. **Fix test integrity (MEDIUM-2, LOW-2, LOW-3).**
   - Delete or rewrite priority-pinning.bats against typed intent with `TAVS_TEST_HELPER_BIN` preserved.
   - Replace the vacuous shellrc assertions.
   - Stop using the shell mute predicate as the stub policy; rely on Swift policy tests.
4. **Reduce process fan-out (MEDIUM-3).**
   - Carry the verified helper path across `exec`.
   - Merge the two capability probes.
   - Correct the shellrc and installer cost claims.
5. **Low-cost cleanups.**
   - Gate OSC 104 in the forced reset (LOW-1).
   - Use process substitution for Codex intake (LOW-4).
   - Skip observe for unsupported providers (LOW-5).
   - Sanitize the composed title (LOW-7).
   - Reject control characters in cwd (LOW-8).
===END_RECOMMENDATIONS===

===PR_READINESS===
Status: NEEDS WORK
Blockers: The HIGH-1 product-boundary decision. MEDIUM-1 and MEDIUM-2 should be fixed or explicitly accepted. Native and UI acceptance (salience, active-cue UI, relaunch, navigation, real recovery) remains unverified and must stay recorded as such.
Scope: Pass D partition (shell, CLI, adapters, installer, plist, shell/Python tests) of the complete branch review; complete within this partition.
Commit quality: unknown; commit history was not supplied.
===END_PR_READINESS===

===SUGGESTED_PR_DESCRIPTION===
Not ready. Before the PR:
- Resolve or document the helper-required signaling boundary and restore helper-independent metadata extraction.
- Prevent synthetic tool-error restores from killing newer timers.
- Remove or rewrite the stale priority-pinning.bats.
- Replace the vacuous shellrc assertions.
- Cut duplicate helper probes and correct the shell-start cost comments.
- Record native/UI acceptance as unverified until observed on dedicated surfaces.
===END_SUGGESTED_PR_DESCRIPTION===

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-branch
Model requested: opus
Effort requested: high
Model observed: unknown
Effort observed: unknown
Input scope: target 71e0f60, base e113fb8, Pass D; all 42 primary targets (adapters, hooks.json, CLI help/lock/recover/status/sync, core backgrounds/dir-icon/idle-worker/lock-state-lib/mute-gate/organizer-state/terminal-osc-sequences/title-management/trigger/visual-restrictions-state, install-codex, Info.plist, tavs-shellrc, tavs dispatcher, conftest, fixture, and all listed bats/pytest files) plus supplied dependency sources (ProcessRunner, terminal-visual-state, visual-recovery, managed-output-entry, visual-restriction-policy, visual-restrictions-state, organizer-intake, process-identity, ghostty-catalog, terminal-render, terminal-renderer, PauseVisual, unchanged core/CLI context)
Focus: correctness, security, maintainability, test_coverage, performance
Limitations: tool-free external review; no executed tests/builds/native/UI; reported execution evidence is not independently rerun; this is a complete partition, not aggregate coverage; MuteReason cases, the Gemini adapter and tests/bench/baseline-capture.sh were not supplied
===END_REVIEW_META===
