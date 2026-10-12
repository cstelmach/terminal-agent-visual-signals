# Phase 6 shell/CLI output and isolation map
Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Repository: /Users/cs/local/code/apps/terminal-agent-visual-signals
Inspected source: f067bef, initially clean
Authority: dated SPEC v1.1, PLAN Phase 6, PROGRESS Phase 5 completion
Method: source inspection only. No hooks, tests, device/GUI writes, installs, agent shutdown
or project-file changes were performed.

## Current state

Phase 4 already provides privacy-minimal intake, typed observations and normalized ordinary
intent. Phase 5 already provides persistent suspension/readers and visible statuses. Phase 6
is still required for output ordering, independent recovery, effect records and queued-work
rejection. Readers alone do not establish a repaint guarantee.

Existing reuse points:
- src/core/organizer-state.sh resolves an explicit test helper or installed app binary.
- Its safe query is --validate-config --organizer-capabilities with exact response
  tavs-organizer-schema=1. That proves Phase 4, not support for new Phase 6 output verbs.
- src/core/visual-restrictions-state.sh atomically writes canonical schema-1 state before
  any native executable is needed.
- TAVSAppMain.main handles native commands before isolated UI and production SwiftUI.
- ProcessRunner retains the 100 ms device caller bound and native nonblocking open/write.
- ProcessRunner now also has runBounded for subprocesses with drainage and a 2 s ceiling.
- TerminalVisualStateStore already has per-TTY records, native producer generations,
  adoption against a verified native lifetime, and stable record-writer locks.
- tests/run-isolated.sh supplies all private roots and an explicitly source-built helper.

## Remaining output map

### Semantic backgrounds

terminal-osc-sequences.sh:99-110:
send_osc_bg first calls _tavs_organizer_record_intent, skips stale result 3, then writes OSC
11/111 through emit_osc. _record_intent currently returns success on missing/old helper
and most metadata failures, deliberately preserving Phase 4 ordinary signaling.

Phase 6 must replace this managed-output behavior. Missing support and native managed failure
must be explicit, nonzero, and must not fall through to unbounded printf. Continue publishing
ordinary intent while a global or selective owner controls visible paint. A stale synthetic
delivery should remain a harmless skipped operation, not a new event.

Do not interpret arbitrary OSC inside emit_osc. It remains the nonbackground formatter.
Use a typed background command accepting color/reset intent and the retained context.

### Idle worker

idle-worker-background.sh:183 already uses send_osc_bg for all stage colors/resets. It sets
TAVS_ORGANIZER_SYNTHETIC=1 and inherits the intake context, so no new meaningful observation
is produced by gradients.

The max-runtime path at :133-145 still sets _TAVS_SUPPRESS_OUTPUT=0, launches palette,
background and title resets, sleeps a second and kills that reset child. This can bypass
current ownership/suspension. Replace it with typed ordinary expiry/reset handling, current
producer/delivery validation and the bounded writer. No forced-unmute variable is a permission
to defeat recovery. Invalid/expired workers should stop their own work.

Ordinary idle palette/title styling still uses emit_osc. Preserve legitimate nonbackground
updates on a current producer, but a stale worker must not continue titles/palette on a reused
TTY merely because send_osc_bg rejected its background.

### Trigger and delayed output

trigger.sh:237-262 debug replay reconstructs a device path from tty_safe and cat writes the
opaque pending file. This bypasses typed policy and can replay old title/BEL. Replace with
current-intent reconciliation on a validated target, or explicitly reject obsolete opaque
replay. Keeping no-cache diagnostics does not justify raw-cache painting.

tool_error :460-493 delayed return now marks TAVS_ORGANIZER_SYNTHETIC=1. It inherits delivery,
but Phase 6 must enforce current lifetime/ownership at actual write. A newer hook can supersede
it before the 1.5 s child wakes. Its failure is redirected to /dev/null in the existing
background branch; expose managed failure through existing minimal diagnostics if needed,
without reintroducing payload logs.

Normal processing/permission/complete/idle/compacting/reset/subagent branches all call
send_osc_bg. No branch-specific OSC parser or duplicate bridge is necessary.

### Mute and pending lifecycle

mute-gate's Stage 1, worker ticks and trigger Stage 0 already fresh-read suspension before
lock/mute. Registration and typed records continue during suspension.

_tavs_mute_buffer_close still atomically moves raw bytes into pending/<tty>.osc without
checking whether a recovery invalidated the output. A late close can recreate a cache after
recovery removed it. The simplest invariant is that controlled transitions never consume
opaque cache content as restoration authority. Recompose from typed latest background and
clear legacy pending output, with closure/replay unable to revive it.

Do not strip BEL bytes from raw OSC: BEL is also its terminator. Preserve existing normal
title, palette, image and bell writes from legitimate current hooks while unmuted. Historical
suppressed bytes are not new hooks and must not become alerts/titles on recovery or resume.

### Standalone shell integration

src/shell/tavs-shellrc.sh has an embedded identical suspension parser. It registers a TTY,
then its lock/pause branches still directly printf OSC 104/10/11/1337 and lock title to stdout
at :159-163 and :179-182.

Route restriction paint through a typed startup command. Pass TTY and caller identity; native
code validates the continuing owner and recomputes current policy inside serialization.
Do not pass a queued shell decision as authority or retain printf as helper failure behavior.
When no rule applies, registration remains cheap and no helper paint is needed.

Because installer/sync copy only this standalone file, either embed the concise capability
resolver/invocation or package its exact sibling bridge dependency. Do not source a
repository-relative core path from ~/.tavs/shellrc. Existing embedded-parser precedent supports
a concise self-contained shell invocation without another installed script hierarchy.

### CLI and remaining nonmanaged writes

cmd-lock and cmd-schedule write definitions, not terminal restrictions. Phase 5 already
reports saved/inert rules and bypasses challenges while suspended. Keep those semantics.
cmd-status prints config samples using ordinary ANSI stdout, not OSC background restrictions.

Nonbackground outputs needing distinction:
- title-management and terminal-osc send_osc_title: ordinary OSC 0.
- send_osc_palette/reset and idle palette helpers: ordinary palette styling.
- backgrounds.sh: iTerm2 image control, separate from selective background cues.
- existing iTerm2 title probes and terminal-detection OSC color queries: no new query/reply
  parser may be introduced for recovery or organizer.
- empty /dev/tty fallback probe in resolve_tty is pre-existing detection, not paint.

Global Broadcaster pause/lock/clear and Scheduler unmute must also use the native managed
writer. Existing raw Broadcaster.broadcast pending replay is not the Phase 6 recovery renderer.

## Proposed typed bridge contract

Suggested names only, to align with the parent's native implementation:

1. Safe query:
   --validate-config --managed-output-capabilities
   Exact response: tavs-managed-output-schema=1
   An older executable goes through its known validation path and exits, without SwiftUI.
   Do this query before any unknown managed verb; organizer schema 1 alone is insufficient.
2. --managed-background <absolute-tty> <context> <color-or-reset> <synthetic-0-or-1>
   Publish/validate latest intent and apply fresh composed background under serialization.
3. --managed-startup <absolute-tty> <caller-pid>
   Validate shell lifetime and current restriction state, then apply only the current rule.
4. --managed-expire <absolute-tty> <retained-context>
   Synthetic worker expiry with current binding/policy, not forced unmute.
5. --managed-reconcile <validated-target>
   Recompose current intent/default; never accepts opaque historical OSC.
6. --visual-recover <absolute-marker-path> <recover-or-resume>
   Uses explicit runtime roots and current validated candidate bindings. Headless only.

One native output capability may cover this narrowly defined Phase 6 family. This is not a
general feature-negotiation SDK. Strict argv counts/types, controlled enum operations, generic
errors, no raw user metadata in diagnostics, and no stdin/OSC parser are enough.

Reuse current helper selection and strip TAVS_SESSIONS_TEST_ROOT/FIXTURE/TARGETS on headless
invocation as current _organizer_call does. Keep explicit test helper/root injection available.
The new native handler must run before isolated or production app launch. Unknown operations
must return a failure rather than fall through to GUI.

Return stale/ineligible as a typed skip where appropriate, but distinguish unsupported helper,
invalid target, storage failure and live timeout. Shell code should propagate managed failure.
If core dispatch needs to continue bookkeeping/nonbackground styling, accumulate a managed
error and return nonzero at end rather than silently making it success.

The store's current withLock starts its own 100 ms record deadline before device open.
Do not wrap it unchanged around a device write. The managed operation opens first, acquires
the stable per-TTY output lock within the ORIGINAL device deadline, then fresh-checks target,
suspension and ownership, persists effect before paint, composes and writes. Do not nest
record-lock acquisition on the same lock inode or reset the deadline partway through.

## Independent recover CLI and result rules

Add cmd-recover.sh plus tavs lazy dispatch/help. Source the shell state writer.
- recover: persist SUSPENDED=true first; then resolve/query native helper and repaint.
- --resume: persist SUSPENDED=false explicitly; then re-evaluate current rules with focus Off.
- Helper missing/old/nonzero never erases successful persistence and never claims repaint.
- No challenge, Automation requirement for safely cached bindings, agent shutdown or input.
- Keep schedule, lock/grant definitions, observations and latest intent unchanged.
- Recover invalidates temporary ownership/pending output before target resets.
- Recovery bytes are OSC 104/110/111 only, no OSC 0, alert replay or immediate ordinary theme.
- Later resume recomposes current rule/intent without resurrecting old cache titles/alerts.

Native output should report restored, confirmed vanished, skipped unaffected and failed/unverified
separately, with a small structured or stable human summary. CLI may forward that result and
native exit status; it does not need a second JSON result parser.

Exit zero requires persistence and no failed live target. Confirmed vanished is not failure.
deviceNotWritable alone does not prove vanished. Unknown/live-busy targets remain retryable.
Zero targets is successful suspension with zero restored. Resume reports saved result and any
immediate rule paint, without implicitly restoring Manual/Automatic mode.

## Packaging constraints

Current cmd-sync copies core *.sh/*.txt, config *.conf, Claude wrapper, CLI *.sh, themes and
installed ~/.tavs/shellrc. It omits top-level tavs, hooks JSON, Codex wrapper and native binary.
A new recover subcommand can therefore exist in synced cmd-recover.sh but be unreachable from
the old top-level tavs. Add exact needed copies in Phase 7 packaging or make Phase 6 dependency
explicit before any deployed use. Do not claim source tests prove installed support.

The app installer packages the existing TAVSApp executable. New native headless branches
need no separate binary artifact. Source helper testing precedes rebuild/install.

Codex notify forwarding is already repaired in current Phase 4; retain direct argv delivery.
No richer hooks are needed. Keep active hooks/hooks.json distinct from the stale companion
src/agents/claude/hooks.json, which still differs in new-prompt/session-end arguments.

Existing worker processes have loaded old code. Sync does not update them. Later deployment
must refresh only owned old idle workers identified through their known fixture/current
binding, preserving agents and terminals. No broad pgrep/killall cleanup in tests or deployment.

## Test-isolation audit for Phase 6

The wrapper now supplies env -i, HOME/CFFIXED_USER_HOME/ZDOTDIR, TMPDIR,
TAVS_RUNTIME_DIR, TAVS_TMP_DIR/_TAVS_TMP_DIR, XDG_RUNTIME_DIR/XDG_CACHE_HOME,
fake regular-file TTY_DEVICE, TAVS_TEST_ROOT and explicit TAVS_TEST_HELPER_BIN.
It retains the owned tree/log and uses bash -p to avoid inherited BASH_ENV.

Inner env -i destroys those protections unless they are forwarded. Current callers:
- emit-osc.bats:47,101,112 forwards only HOME/PATH/runtime/TTY.
- lock-gate.bats:63,130 does the same, including its kill-switch case.
- counter-integrity.bats:56 omits helper and private tmp/XDG roots.
- identity-teardown.bats:53 forwards TAVS_TMP_DIR but drops helper/test root/XDG/CF home.
- priority-pinning.bats:64 forwards tmp/XDG/TMPDIR but drops helper/test root/CF home.
- baseline-capture.sh:52,86 forwards HOME/PATH/TTY/runtime but drops helper/tmp/XDG/test roots.

Those were sufficient for portions of legacy behavior or intentionally omitted helper
coverage; they become inappropriate once background output requires the native managed bridge.
Forward the full minimal private environment in each connected child, or keep inherited
wrapper isolation instead of recreating env -i. Ensure TAVS_TMP_DIR and _TAVS_TMP_DIR agree
after test overrides, and CFFIXED_USER_HOME matches a test's changed HOME.

The idle-worker fixture's former live runtime leak is repaired: HOME/runtime/state/XDG and
owned capture/worker files are private. Existing fake /dev/ttys901/902 shellrc tests assert
stdout paint; after native routing those tests must use a stub that records requests or owned
PTYs, never attempt to open arbitrary /dev names. Their unit installer branches only touch
private HOME, not production installation.

background-intent.bats owned PTY path already has strict byte collection and bounded parent
wait. Its worker trap stores an owned PID and waits. Extend cleanup to any explicitly launched
grandchildren on failure; a PTY child may otherwise die with tool-error or idle children alive.
Use an owned child process group only after verifying it belongs to the created test session.
Never invoke production cleanup_stale_timers or broad pgrep cleanup in a fixture.

New cmd-recover stubs must prove persistence existed before the FIRST capability query, record
only allowed invocations, and assert an unsupported helper never receives an unknown verb.
The no-helper Phase 4 test currently expects basic signals success. Split its observation
availability contract from the new explicit managed-background failure contract.

## Prospective focused tests

Bats:
- missing/legacy/query-failed helper persists suspension first, nonzero, no managed raw bytes;
- --resume saves false, focus Off, current rule summary, no stale cache replay;
- two cache sentinel files containing old title/alert bytes never reach private TTY after
  recover, debug reconcile, late buffer close, normal unmute or resume;
- semantic background updates intent while owned/muted, no new observation from idle/expiry;
- stale synthetic delivery and invalid target are skipped/rejected without title/palette spill;
- standalone startup uses typed request, registers even while suspended, never raw printf;
- legitimate new nonbackground title/palette/image/bell still work on supported current hooks;
- every inner child environment remains below TAVS_TEST_ROOT and carries the chosen helper.

Owned PTY/native:
- before-open and before-policy queued restrictive work released after recovery cannot repaint;
- busy lock and late open retain the one original 100 ms deadline; healthy target succeeds;
- existing write finishes before reset; no restriction occurs after reset;
- cached affected plain shell without native Automation; unknown versus confirmed-vanished;
- retryable failure retained; stale/dead owner stops deferring current ordinary hooks;
- device/process/native lifetime reuse rejects late intent and old recovery target;
- global clear resets foreground/palette then current background only, with no historical
  title/BEL; background-only reconciliation preserves foreground/palette/cursor/title.

Later commands, not executed here:
- TAVS_TEST_HELPER_BIN=/absolute/source-built/TAVSApp tests/run-isolated.sh
  bats tests/unit/test-isolation.bats
- Same runner for new cmd-recover.bats and managed-background.bats plus connected suites
  AFTER forwarding fixes.
- Same runner for swift test --package-path src/macos/TAVSApp with a private scratch path.

No full pytest, legacy scheduling E2E, live install, arbitrary terminal testing or GUI use is
needed to establish this Phase 6 shell contract. Keep failed traces in wrapper logs.

## Parent source correction, 2026-10-12

The paragraph claiming divergent Claude hook JSON is stale. At `c523a26`, `cmp` confirms
`hooks/hooks.json` and `src/agents/claude/hooks.json` are identical, including new-prompt and
session-end. Do not modify them on that report's assertion. Metadata-only capability calls may
clear isolated UI variables, but actual recovery discovery must preserve dedicated-target
restrictions. A private runtime path alone does not authorize broad native enumeration.
