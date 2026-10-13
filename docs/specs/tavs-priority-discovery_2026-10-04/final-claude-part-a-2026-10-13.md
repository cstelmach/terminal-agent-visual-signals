> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# Claude Review Report

===DIMENSION_RATIONALE===
The five default code dimensions fit this pass. Pass A is the Swift organizer core: native catalogue and identity, Sessions model and view, typed observation and intent records, the preview and focus controller, and the automatic attention reducer, together with their tests. Correctness and test coverage carry most of the risk. Security covers metadata privacy, identity spoofing and filesystem handling. Maintainability is relevant because state ownership is spread across a 1201-line store and a 381-line controller. Performance covers polling, retry growth and writer-lock contention. Recovery fanout, the managed writer and the shell hooks belong to other partitions. Where a Pass A finding depends on them, they were read only as callees.

Phase and file coverage for this pass (all primary targets read in full):

| PLAN phase | Primary sources reviewed | Primary tests reviewed | Adjacent callees read |
|---|---|---|---|
| 1 Native catalogue / exact navigation | ghostty-catalog.swift, process-identity.swift | ghostty-catalog-tests.swift, process-identity-tests.swift | ProcessRunner.swift (runBounded), MockProcessRunner.swift |
| 2 Sessions window / priorities | sessions-model.swift, sessions-view.swift | sessions-model-tests.swift | TAVSApp.swift (create, IsolatedSessionsLaunch), MenuContent.swift |
| 4 Observations / intent | organizer-intake.swift, terminal-visual-state.swift | organizer-intake-tests.swift, terminal-visual-state-tests.swift | organizer-state.sh, codex/trigger.sh, hooks.json |
| 6 Effect records / ownership (store side) | terminal-visual-state.swift (effects, leases, locks) | terminal-visual-state-tests.swift | visual-recovery.swift (performWrite, fanout), ProcessRunner.writeManagedToDevice |
| 7 Previews | focus-controller.swift (preview path) | focus-controller-tests.swift | terminal-renderer.swift, visual-recovery.swift |
| 8 Manual focus | focus-controller.swift (manual path) | focus-controller-tests.swift | visual-restrictions-state.swift |
| 9 Automatic focus | attention-state.swift, focus-controller.swift, sessions-model.swift | attention-state-tests.swift, focus-controller-tests.swift | terminal-visual-state.swift (isCurrentAttentionSource) |

Forced falsification hypotheses and dispositions:

1. Transient coverage unavailability is treated as cue resolution, so an unacknowledged cue is lost. CONFIRMED. A lock timeout or mapping gap yields `observation: nil` (terminal-visual-state.swift:749-751, 795-797). The reducer clears cues on any nil observation (attention-state.swift:37-42). The retained book then blocks reinstatement when the same delivery reappears (attention-state.swift:44-46).
2. A persistently failing outside target causes unbounded growth of focus cleanup work. CONFIRMED. The heartbeat advances only on full success (focus-controller.swift:293-296). An expired run is replaced and queued for cleanup roughly every eight seconds (focus-controller.swift:203-206). Failed cleanups re-append themselves (focus-controller.swift:350-351).
3. Go To acknowledges cues that arrive during navigation, or acknowledges a replacement producer's cue. DISMISSED. The snapshot is taken before dispatch (sessions-model.swift:255). Acknowledgement subtracts only that set (attention-state.swift:27-30). Occurrences carry producer, TTY and device (attention-state.swift:3-9). The behaviour is tested in attention-state-tests.swift:38-54 and 127-134, and in focus-controller-tests.swift:102-130.
4. The automatic producer check takes another TTY's lock inside the writer deadline. DISMISSED. `isCurrentAttentionSource` (terminal-visual-state.swift:171-179) checks the deadline and validates without `withLock`.
5. A preview or focus worker repaints after Clear, Focus Off or retirement. DISMISSED. Targets are attached only while `current === run` / `manual === run` under the controller lock (focus-controller.swift:66-70, 271-275). Device-side ordering then relies on the per-TTY writer lock plus the `isCurrent` re-check inside prepare (visual-recovery.swift:228, 255-267). Tests at focus-controller-tests.swift:210-228, 278-311 and 509-525 exercise this.
6. A priority transfers through TTY reuse or Ghostty restart. DISMISSED. Priorities are keyed by `GhosttySurfaceID` (application generation plus terminal ID) and pruned against fresh catalogues (sessions-model.swift:236). Tested at sessions-model-tests.swift:45-54 and 87-99.
===END_DIMENSION_RATIONALE===

===EXECUTIVE_SUMMARY===
Overall grade: 6.2
Risk level: Medium
Verdict: CONCERN

The Pass A organizer core follows most of the SPEC's identity and ordering contracts:

- exact native IDs with application generation
- foreground-family correlation instead of ancestor lookup alone
- adoption bound to a single surface
- baseline cutoff on Automatic enable
- coalesced permission episodes
- snapshot-only Go To acknowledgement
- revision-pinned preview and focus requests

Two defects remain:

1. The attention reducer cannot tell "records temporarily unavailable" from "binding invalid". A brief writer-lock timeout, or a missing native TTY read, permanently drops an unacknowledged High cue. This can release Automatic dimming without a resolving signal, which conflicts with G8's rule against inferring resolution from uncertainty.
2. Focus run replacement under a persistently failing outside target accumulates retained cleanup runs without bound. Those runs saturate the serial clear queue that previews also use, which degrades the one-second clear bound and multiplies blocked-open attempts.

Maintainability is weakened by a monolithic state store and by "manual" names reused for automatic state. Test coverage is broad and meaningful but misses both defect scenarios. Native salience, navigation across Spaces and minimized windows, active-cue UI and relaunch UI remain empirically unverified. This verdict covers only this partition, not the aggregate implementation.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
MEDIUM 1: Transient coverage unavailability permanently drops unacknowledged cues

- Location: src/macos/TAVSApp/Sources/TAVSApp/attention-state.swift:37-42 and :44-46. Contributing: terminal-visual-state.swift:749-751, :795-797 and :960; focus-controller.swift:213-217.
- Concrete trigger:
  1. A High Claude surface has an unacknowledged Stop cue.
  2. On one 2 s refresh, `coverage(for:)` cannot take the per-TTY writer lock within its default 100 ms. This happens when an idle-worker or hook managed write against a backpressured device holds the lock near its deadline.
  3. `withLock` throws `lockUnavailable`, and the outer catch returns `TerminalVisualCoverage(observation: nil, ...)`.
  4. The same loss occurs if Ghostty's optional `tty` read fails transiently. The JXA `optional()` returns null, the row becomes `missingTTY`, and coverage returns nil.
- Situation: `AttentionState.reconcile` treats any nil or unverified observation as invalid, sets `cues[surface] = nil` and continues, but keeps the `Book`.
- Behavior: The next refresh returns the same delivery from the same actor. The guard `record.observedAt > previous.latest.observedAt` fails and the loop continues, so the cue is never restored. If it was the last cue, `FocusController.acceptCatalogue` calls `retireFocus()` (focus-controller.swift:190-191) and Normal/Low dimming is released.
- Impact: A High attention occurrence disappears without processing, exit, reset, acknowledgement or a confirmed invalid destination. G8 says uncertainty must never become inferred resolution. The test at attention-state-tests.swift:118-125 encodes "nil clears and never replays" without distinguishing transient unavailability from confirmed invalidity.
- Suggestion: Give `TerminalVisualCoverage` an explicit tri-state (valid, confirmed invalid, temporarily unavailable). On "temporarily unavailable", retain existing cues and the book without creating new ones, as `catalogueUnavailable()` already does for whole-catalogue failure. Clear only on confirmed invalidity, such as a producer ended or a mismatched generation or device. No new control plane is needed.
- Confidence: High on the mechanism. Medium on frequency, which depends on device backpressure and native read stability.

MEDIUM 2: Persistent outside-target failure grows retained focus cleanup runs and starves the shared clear queue

- Location: src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:197-206, :293-296, :304-305, :340-356; shared queue at :23 (also used by preview clears at :104).
- Concrete trigger: Manual or Automatic focus is active, and one outside surface's device write keeps failing (hung open, busy writer lock, or `focusUnavailable`).
- Situation: `run.lastHeartbeat` advances only when every outside target is mapped and none failed. Each refresh with `now - lastHeartbeat > 6` therefore creates a new `Run` and appends the old one to `pendingFocusClear`.
- Behavior: On each successful update completion, every pending run is redispatched through `clearManual`. A clear that fails on the same dead target re-appends itself (lines 350-351). The pending set grows by about one run per eight seconds for as long as the failure persists. Each attempt costs up to the 100 ms device deadline. When the device open stalls, `completeDeviceWrite` also leaves a blocked worker thread per attempt (ProcessRunner.swift:199-210). After a few minutes the serial `clearQueue` is continuously busy, and preview clears queued behind it miss the one-second clear bound.
- Impact: Linear growth in memory, CPU and blocked threads during the hung-terminal scenario the SPEC targets. Clear/Escape latency degrades.
- Suggestion: Coalesce cleanup per physical target rather than per run. A focus clear on a target recomposes from current leases regardless of effect ID. When an expired run is replaced, merge its targets into one retained cleanup set, and drop a target once a clear reports restored, unaffected or vanished. Alternatively, give previews their own clear queue so focus retries cannot delay them.
- Confidence: High on the growth mechanism. Medium on the thread-exhaustion severity, which depends on how long a wedged open persists.

LOW 3: Plain-shell rows are indistinguishable from agent rows with missing coverage

- Location: src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift:102-105; terminal-visual-state.swift:789-791.
- Trigger: Two rows have no observation. One is an idle zsh. The other is an npm-installed Claude whose hooks failed, or a Codex session before its first completion.
- Behavior: Both rows show "No agent observation / Not observed". The SPEC asks to "Distinguish shell/other-process rows from missing agent coverage."
- Impact: The operator cannot tell an uncovered agent from a shell.
- Suggestion: Show the foreground process role from the already-validated `foregroundPID`, for example "shell foreground" versus "other process; no hook coverage". Use bounded process inspection only, with no command lines.
- Confidence: Medium.

LOW 4: Suspended or blocked focus controls lack a specific explanation

- Location: sessions-view.swift:35-48; MenuContent.swift:13-17; focus-controller.swift:311.
- Trigger: Focus Selected or Automatic is disabled while suspended, or focus dimming is masked by a global pause.
- Behavior: Buttons are simply disabled, and the focus status is the generic "Preview/global rules may mask dimming". The SPEC says suspended activation is "disabled with an explanation", and asks to show why selective focus is unavailable under a global rule.
- Suggestion: Add a short reason string tied to `visualRestrictionsStatus` and to the focus op's "rule present" path.
- Confidence: Medium.

LOW 5: "manual" naming is reused for automatic state

- Location: focus-controller.swift:25-30, 243, 323, 340.
- Behavior: `manual`, `manualPending`, `manualUpdating`, `updateManual`, `matchesManual` and `clearManual` all also own the Automatic run.
- Impact: Hard to audit the mode exclusivity that the SPEC emphasises. Easy to regress if a later change touches only "manual" paths.
- Suggestion: Rename to `focusRun`, `focusPending` and similar names.
- Confidence: High.

LOW 6: The visual state store is monolithic

- Location: terminal-visual-state.swift (1201 lines).
- Behavior: One class owns record schemas, locking, adoption, effect leases, intent binding, alias enumeration and atomic IO.
- Impact: Ordering invariants, such as which helpers require the caller's held lock and deadline, are expressed only by comments and naming (`...Unlocked`).
- Suggestion: Split it into small files beside their consumers (records and decoding, effects and leases, intent binding) without changing behaviour.
- Confidence: High.

Test gaps (no product defect beyond those above):

- No test feeds a transient "Organizer records unavailable" or `missingTTY` sample between two identical eligible observations. Such a test would expose MEDIUM 1.
- No test keeps one outside target failing across several expired heartbeats while asserting a bounded `pendingFocusClear` and timely preview clears (MEDIUM 2).
- No static assertion that `GhosttyCatalog.script` contains no `perform action`, input, key, split, close or quit constructs. The SPEC verification asks for "Check constructed native commands against the allowlist". The JSContext tests exercise behaviour but not an allowlist.
- `OrganizerIntake.producer` has no lookup-injected test for the foreground-family ancestor walk. Only `matchesProviderExecutable` is unit-tested, yet this walk gates every automatic cue.

Supported product boundaries (not defects):

- npm/node-hosted Claude processes are rejected as unverified (organizer-intake.swift:206-208). Such surfaces show "Unverified Claude" and never create cues. This is honest partial coverage consistent with D17, but should be documented for operators.
- Latest-only records can miss intervening hook events between 2 s polls. This is documented in API_REFERENCE.

Empirical acceptance gaps (unverified, not proven by any test or declaration):

- Whether the JXA zero-argument `target.focus` invocation focuses the exact pane across Spaces, minimized or fullscreen windows and multiple displays.
- Whether `isFocused` (frontmost plus front window) reports true promptly after a Space switch. A false negative leaves the cue unacknowledged.
- Visible salience and readability of preview tint and focus dimming on dark and light, ANSI and TrueColor content.
- Active-cue Sessions UI and relaunch UI.

Dismissed hypotheses (evidence in DIMENSION_RATIONALE items 3-6), plus:

- Permission prompt-before-request reordering. Prompt-first sets `book.permission`, so the following PermissionRequest is coalesced (attention-state.swift:61). Tested at attention-state-tests.swift:70-79.
- Same-producer multi-cue source check. Only the first cue per surface is checked (focus-controller.swift:259-262). This is sufficient because every cue on a surface shares one actor: a new actor clears the surface's cues (attention-state.swift:49-51).
- Raw payload leakage. Intake retains only allowlisted fields and bounded IDs (organizer-intake.swift:32-69), and records reject unknown keys (terminal-visual-state.swift:1079-1082). Sentinel tests exist.
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| correctness | 6/10 | Identity, baseline, coalescing and snapshot acknowledgement are correct, but transient coverage loss permanently clears cues (attention-state.swift:37-46) |
| security | 7/10 | Data-only native requests, allowlisted metadata, strict record decoding, O_NOFOLLOW and private modes. Same-user provider spoofing by executable name is low impact |
| maintainability | 5/10 | 1201-line store; automatic state hidden behind "manual" names; dense multi-statement lines and nested closures in updateManual |
| test_coverage | 7/10 | Real-PTY controller races, reducer edge cases and identity reuse are well covered. Missing transient-unavailability, persistent-failure retry, allowlist and producer-walk tests |
| performance | 6/10 | Unbounded pendingFocusClear growth under a hung target starves the shared clear queue. Each preview re-runs two Ghostty CLI subprocesses |
| Overall | 6.2/10 | 25%, 25%, 20%, 15%, 15% respectively |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. Give coverage samples an explicit "temporarily unavailable" state, separate from confirmed invalid binding. Make `AttentionState` retain cues and books on transient unavailability, and clear only on confirmed exit, generation or device mismatch, resumption, reset, downgrade or closure. Add a reducer test with an unavailable sample between two identical eligible observations, and a store test for a lock timeout.
2. Coalesce focus cleanup per physical target instead of per expired run. Drop targets once a clear reports restored, unaffected or vanished, or give preview clears their own queue. Add a controller test with one persistently failing outside target across several heartbeats that asserts bounded retained cleanup and a timely preview clear.
3. Add a static allowlist assertion over `GhosttyCatalog.script` and an injected-lookup test for `OrganizerIntake.producer`. Then make the low-cost UI clarifications: shell versus uncovered-agent row text, and an explicit reason when focus activation is disabled or masked. Rename the "manual" controller members to mode-neutral names.
===END_RECOMMENDATIONS===

===PR_READINESS===
Status: NEEDS WORK
Blockers:
- MEDIUM 1, cue loss on transient coverage unavailability.
- MEDIUM 2, unbounded focus cleanup growth under persistent target failure.
- Native navigation, salience and readability, active-cue UI and relaunch UI acceptance remain unverified. They must stay recorded as unverified rather than passed.
Scope: Pass A of the complete branch review (organizer core: catalogue, identity, Sessions, records, preview, focus and attention controller, plus their tests). Recovery fanout, the managed writer and the shell hooks are covered by other partitions.
Commit quality: unknown; commit history was not supplied.
===END_PR_READINESS===

===SUGGESTED_PR_DESCRIPTION===
Not ready. Before a PR:

- Keep cues through transient coverage or mapping unavailability and clear them only on confirmed resolution, with a regression test.
- Bound focus cleanup retries per target, or isolate them from preview clears, with a persistent-failure test.
- Add the native-script allowlist assertion and the producer-walk test.
- Record native Go To across Spaces and minimized windows, dimming and preview readability, active-cue UI and relaunch UI as dedicated-surface acceptance outcomes, leaving any unobserved case explicitly unverified.
===END_SUGGESTED_PR_DESCRIPTION===

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-branch
Model requested: opus
Effort requested: high
Model observed: unknown
Effort observed: unknown
Input scope: target 71e0f60, base e113fb8, Pass A. All 15 primary targets read in full: attention-state.swift, focus-controller.swift, ghostty-catalog.swift, organizer-intake.swift, process-identity.swift, sessions-model.swift, sessions-view.swift, terminal-visual-state.swift, and the seven matching test files. Supplied dependency sources were read as callees: Broadcaster, MenuContent, ProcessRunner, Scheduler, TAVSApp, managed-output-entry, terminal-render, terminal-renderer, visual-recovery, visual-restriction-policy, visual-restrictions-state, the mocks, organizer-state.sh, hooks.json and codex/trigger.sh.
Focus: correctness, security, maintainability, test_coverage, performance
Limitations: tool-free external review; no executed tests/builds/native/UI; reported execution evidence is not independently rerun; this is a complete partition, not aggregate coverage
===END_REVIEW_META===
