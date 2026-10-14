## part04: persistent recovery and suspension

> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# Claude Review Report

**Mode**: code-session
**Date**: 2026-10-14
**Focus**: all (five default code dimensions)

> NOTE: Execution path claude-cli-explicit. Real native Claude CLI under Hub controls, chosen by the caller. It is not an automatic fallback and is not evidence that the applied model or effort were observed.

> Report persistence: this session had no tools, so no file was written under /tmp. The full report is this reply. The parent should save it under a timestamped name such as `/tmp/claude-review-code-terminal-agent-visual-signals-main-<timestamp>.md`.

---

===DIMENSION_RATIONALE===
### Metadata
- Target: commit 7ecfba2, Partition 2 subscope 04-recovery. Reviewed visual-recovery, terminal-visual-state, renderer/render, ProcessRunner, process-identity, restriction policy/state, organizer-intake, managed-output-entry, TAVSApp wiring, Scheduler, Broadcaster, supporting state types, and the connected tests and mocks listed in the inventory.
- I used the five defaults (Correctness, Security, Maintainability, Test Coverage, Performance) without change. This scope is concurrency- and I/O-heavy recovery code, so those five dimensions cover the risk surface. Compatibility with ordinary signaling is scored under Correctness. Privacy is scored under Security.
- I scored each dimension independently before choosing the verdict.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
Overall grade: 6.6/10
Risk level: Medium

### Summary
The core ordering contract holds in source:
- Suspension persists before any repaint.
- Restrictive policy is recomputed inside the per-TTY serialized write.
- Queued renders are rejected by marker-inode revision.
- Emergency resets get an independent admission slot.
- Healthy fanout is independent of failed, busy or unverified targets.

I found two concrete defects:
- **R1:** A failed pause-release clear is never retried. The retry path only issues `.currentRestriction`, and it only runs while muted.
- **R2:** An unavailable (malformed or unknown-schema) suspension marker makes every full hook render and forced reset fail. Background-only writes still succeed in the same state.

`performWrite` is a roughly 300-line multiplexer, which raises the regression risk for future changes. Native, Spaces, readability and Linux runtime acceptance remain unverified. Passing tests are not treated as physical acceptance.

### Verdict
CONCERN. All dimensions score at least 5, and Correctness and Maintainability are below 7.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

### Hypothesis falsification

1. **H1: A queued restrictive write can repaint after recovery.** Dismissed.
   - `visual-recovery.swift:315` recomputes `policy.current` inside `prepare`, under the device flock, after open.
   - `visual-restriction-policy.swift:29,48` reads the marker twice.
   - Renders and forced resets also require the captured marker inode to still match (`visual-recovery.swift:215-218`).
   - Recovery's `.emergencyReset` uses a separate admission key (`ProcessRunner.swift:246-249`).
   - Tests at `visual-recovery-tests.swift:524`, `:1172` and `:1399` pause between publication and the device budget without altering production budgets.
2. **H2: A generic `deviceNotWritable` is reported as vanished.** Dismissed.
   - `fanout` maps any non-classified error to `.failed` (`visual-recovery.swift:583`).
   - `.vanished` comes only from `validateTarget` (`terminal-visual-state.swift:151-174`). That requires an ESRCH owner, a changed generation, or ENOENT/ENXIO on the node.
3. **H3: A failed persistence step still discovers or paints.** Dismissed.
   - `recover()` returns before `apply` (`visual-recovery.swift:427-431`).
   - The headless client writes before the probe (`:78-79`).
   - The entry persists before isolation decoding (`managed-output-entry.swift:47-49`).
   - Tested at `visual-recovery-tests.swift:1102`.
4. **H4: A failed release clear stays painted with no automatic retry.** Confirmed (R1).
5. **H5: A non-active marker state suppresses ordinary, non-restrictive output.** Confirmed for full renders and forced resets (R2). Background-only `.ordinary` writes are unaffected.

### Findings

### CRITICAL
None substantiated.

### IMPORTANT

**R1. `Broadcaster.swift:49-56,125-127`, `Scheduler.swift:492-497`, `Broadcaster.swift:136`: failed release clears are never retried**

- **Source lines:**
  - `retryFailedRestrictions` always replays `.currentRestriction` on stored failures.
  - `heartbeatTick` only calls it when `isMuted && !disablesRestrictions`.
  - `record` removes a failure only on `.restored` or `.vanished`.
- **Trigger:**
  1. A pause or lock ends.
  2. Scheduler enqueues `broadcastPausedClear()` + `broadcast()`, coalesced into one `.reconcile` (`Scheduler.swift:430-431`, `Broadcaster.swift:78-79`).
  3. That reconcile fails transiently for one target, for example open EIO, admission EBUSY or the 100 ms timeout.
- **Behavior:**
  - The heartbeat never retries because `isMuted` is now false.
  - A manual or explicit retry would run `.currentRestriction`. With no rule, that returns nil (`visual-recovery.swift:316`), so the result is `.unaffected` and the failure persists.
  - The terminal keeps the lock or pause foreground, background and palette. This lasts until the next scheduler transition, an ordinary hook on that TTY, or a manual Restore Visibility.
  - A plain shell with no hooks stays grey indefinitely.
  - `terminalUpdateIssue` stays set even if a later hook self-heals the TTY in another process.
- **Impact:** This violates "Failed targets remain retryable" (SPEC 186, 278) and the PLAN phase 6 rule "no failure pruning defeats retry". It is a regression from the muted case, where retry works.
- **Smallest remedy:**
  - Retry stored failures with `.reconcile(resetLegacy: false, clearSelective: false)`. That operation already paints the current rule when one exists (`visual-recovery.swift:320-338`) and otherwise restores intent and resets legacy colors from the still-active global effect.
  - Call the retry on every heartbeat when failures exist, not only while muted. Suspension is still enforced in-lock.
- **Criterion:** SPEC Recovery Contract "Keep failed targets for retry"; Phase 2 "Schedule transitions ... do not leave uncancellable effects".
- **Discriminating test:**
  1. In BroadcasterTests, mute and paint a target.
  2. Make the runner fail that path, then unmute and run `broadcastPausedClear()` + `broadcast()`.
  3. Heal the runner and invoke the heartbeat-driven retry (`Scheduler.heartbeatTick` via `MockTimerScheduler.fireAll`, with a real Broadcaster).
  4. Expect `104/110` + background bytes and no remaining failed item.
  5. Current code produces no bytes, so this discriminates.

**R2. `visual-restrictions-state.swift:57`, `visual-recovery.swift:173-179`: an unavailable marker blocks full renders and forced resets**

- **Source lines:**
  - `captureRevision()` throws `storageUnavailable` when `read() == .unavailable`.
  - `performWrite` calls it in `beforeOpen` for every `.render` and `.forcedReset`.
- **Trigger:**
  - The marker contains an unknown schema (for example a newer CLI, plugin or shellrc copy writing schema 2), a malformed value, or is a non-regular file.
  - Then any `--managed-render` or `--managed-forced-reset` runs (`managed-output-entry.swift:114-133`).
- **Behavior:**
  - The write throws before open, and the entry returns exit 1, "Managed output unavailable".
  - Meanwhile `.ordinary` writes in the same state succeed, because `policy.current` returns nil and no revision is captured.
  - Titles, palette, image and bell for every hook are dropped. Idle max-runtime forced resets also fail.
- **Impact:**
  - The status text promises "Visual restrictions disabled until repaired" (`visual-restrictions-state.swift:13`), but ordinary non-restrictive signaling partially stops.
  - Under the stated rule that a failed selected operation must not switch backend or raw-write, nothing is painted.
  - This is a compatibility regression for existing ordinary signaling triggered by cross-copy schema skew.
- **Smallest remedy:**
  - Capture the inode identity regardless of status for the render and forced-reset path, for example `captureRevision(allowUnavailable: true)`.
  - `matches(identity)` already compares only device and inode.
  - The in-lock `policy.current` already returns nil for disabled states.
  - Preview keeps its explicit `.unavailable` rejection at `visual-recovery.swift:253`.
- **Criterion:** G8 (unavailable is a visible state, not inferred restriction); preservation of ordinary signaling; SPEC "failed selected operation must not ... raw-write" implies the selected operation must not fail spuriously.
- **Discriminating test:**
  1. Write `SCHEMA_VERSION="77"` to the marker.
  2. Call `recovery().render(render(), intent:..., synthetic: false, ...)`.
  3. Expect `.rendered` with the style bytes and no `10;`/restriction bytes.
  4. Current code throws, so this discriminates.
- **Caveat:** How the shell caller reacts to exit 1 belongs to partition 3 and is unverified here.

### MINOR

**R3. `terminal-visual-state.swift:223-235,414-478`, `visual-recovery.swift:445-447`: no retirement of target records**

- Target directories are never retired. Each owner generation and native alias adds `targets/<tty>/<owner>/...`, and nothing in scope deletes confirmed-vanished bindings.
- `cachedRecords()` walks the whole tree, and `apply`/`reconcilePriorEffects` validate every entry. This happens on every startup, broadcast and recovery.
- As a result, cost and report size grow linearly until reboot. Vanished items also accumulate in `Broadcaster.result`.
- Remedy: during recovery or reconcile, delete a binding directory once validation is `.vanished` and no active effect remains. SPEC 186 already allows this.
- Test: cache N targets, mark their owners ESRCH, recover twice, and expect the second report to contain zero items.

**R4. `visual-recovery.swift:129-424`: `performWrite` has grown too large**

- It is a single roughly 300-line closure that multiplexes 12 operation kinds through interleaved `if case` blocks and shared mutable flags (`effects`, `clearSelective`, `resetLegacy`, `restoreFocusBackground`).
- Ordering invariants are implicit. For example, the global rule branch at 320 must precede the reconcile branch at 343.
- Remedy: split into per-operation preparers sharing one in-lock context struct. Behavior stays the same, and the existing PTY tests act as the guard.

### Unresolved hypotheses (not findings)
- The shell-side handling of helper exit codes 1 and 3 belongs to partition 3. Whether R2 visibly drops titles depends on that code.
- `didRenew` (`visual-recovery.swift:290`) runs before the device write. It may report renewal when the write later fails. Its consumer is in focus-controller, outside this subscope, and no defect is shown.
- The actual 100 ms budget under real Ghostty load, the historical first-paint/EPERM failures and the fresh-render timeouts are not establishable from source.
===END_ISSUES===

---

===SCORE_CARD===
### Rubric Scores

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | 6/10 | Ordering and partial-failure honesty hold. R1 (unretried release) and R2 (unavailable marker blocks renders) are real gaps. |
| Security | 8/10 | O_NOFOLLOW, inode-checked reads, 0600 lock and record files, size caps, control-character filtering, scope allowlists. No input or argument logging. |
| Maintainability | 5/10 | `performWrite` is a ~300-line multiplexer with implicit ordering (R4). |
| Test Coverage | 7/10 | Strong owned-PTY race, alias, vanished and partial tests. R1 and R2 paths are untested. ProcessRunner and Scheduler tests are not in this inventory. |
| Performance | 7/10 | Bounded writers, independent fanout, coalesced broadcaster. Unbounded record retention (R3). |
| **Overall** | **6.6/10** | Weighted 25/25/20/15/15. Verdict CONCERN. |

===END_SCORE_CARD===

---

===RECOMMENDATIONS===
1. **R1:** Retry stored failures with `.reconcile(resetLegacy: false, clearSelective: false)` on every heartbeat while failures exist. Add the unmute-failure retry test.
2. **R2:** Let render and forced-reset capture marker identity while the status is unavailable. Add the schema-77 render test.
3. **R3/R4:** Retire confirmed-vanished binding directories, and split `performWrite` into per-operation in-lock steps under the existing PTY suite.
===END_RECOMMENDATIONS===

---

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-session
Model requested: opus
Model observed: unknown
Effort requested: unspecified
Effort observed: unknown
NOTE: Real native Claude CLI under Hub controls, chosen by the caller. It is not an automatic fallback or evidence that the applied model or effort were observed.
Input scope: Partition 2, subscope 04-recovery, at commit 7ecfba2 (clean checkout). All 35 supplied files were reviewed: SPEC.md, PLAN.md, Package.swift, 24 Sources/TAVSApp files (visual-recovery, terminal-visual-state, terminal-renderer, terminal-render, ProcessRunner, process-identity, visual-restriction-policy, visual-restrictions-state, organizer-intake, managed-output-entry, TAVSApp, Clock, MuteState, LockState, PauseVisual, UserConfStore, Broadcaster, Scheduler, TimerScheduler, ScheduleStore, FileWatcher, TAVSLog, ChallengeGate, ChallengeVerifier), the tests visual-recovery-tests, BroadcasterTests, MuteStateTests and LockStateTests, and the mocks MockBroadcaster, MockFileWatcher, MockLoginItemService, MockProcessRunner and MockTimerScheduler. Completion: full refers to this supplied subscope only, not whole-goal acceptance.
Focus: all default
Limitations: Tool-free single-turn session. No files were read beyond the prompt, nothing was built or tested, and no report file was written under /tmp (the parent must persist this reply). Connected files not supplied (focus-controller, sessions model, ghostty-catalog, SchedulerTests, process-runner-tests, shell callers) were not inspected. Native catalogue, navigation, readability, Spaces and permission acceptance, and Linux runtime behavior, remain unverified. Historical first-paint/EPERM and fresh-render timeout causes remain unestablished. Passing tests are not treated as physical acceptance.
===END_REVIEW_META===


## part05: scheduler and broadcaster

> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# Claude Review: TAVS current implementation, Partition 2 subscope 05-scheduler-startup

> [!NOTE]
> **Explicit native route.** The caller selected the real native Claude CLI under Hub controls. This is not an automatic fallback. The requested model and effort were not observed.

**No report file was written.** This session had no tools, so nothing could be saved under /tmp. The full report is below, and the parent should save it.

- **Grade:** 6.7/10. **Verdict:** CONCERN. **Risk:** Medium.
- **Issues:** 0 critical, 1 important, 2 minor. One hypothesis is unresolved.
- **R1 (IMPORTANT):** A failed pause-release clear cancels the global effect record before the device write. While unmuted, no retry runs, so the pause foreground can persist.
- **Top recommendation:** Have the Broadcaster retry with `.reconcile(resetLegacy: true, clearSelective: false)`, and call it from the heartbeat whether or not the session is muted.

---

# Claude Review Report

**Mode**: code-session
**Date**: 2026-10-14
**Focus**: all default

---

===DIMENSION_RATIONALE===
I used the five default dimensions: correctness, security, maintainability, test coverage and performance. They fit this subscope, which covers the Scheduler lifecycle, Broadcaster queueing and retry, app and headless entry wiring, menu controls, and supporting stores. These files also connect to the managed writer and recovery paths.

I added no extra dimension. Accessibility and readability belong to native acceptance, which no source review can establish.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
Overall grade: 6.7/10
Risk level: Medium

**What works.** Scheduler and Broadcaster wiring follow the SPEC ordering:
- Suspension is read on every evaluation, at `Scheduler.swift:362`.
- `mute.state` and `lock.state` are persisted before the Broadcaster is asked to paint or reconcile, at `Scheduler.swift:411-435`.
- The Broadcaster discards caller visual snapshots and enqueues policy-free operations. Those operations recompute the current restriction under the per-TTY writer lock, at `visual-recovery.swift:315`.
- Queued restrictive paint therefore cannot defeat a later suspension.

**The defect.** The retry contract has a gap. A pause-release reconcile cancels the global-restriction effect record inside `prepare`, before the bytes reach the device. If the write then times out, nothing retries while the session is unmuted. Later ordinary renders no longer see an active global effect, so the legacy pause foreground can remain.

**Coverage.** The supplied Scheduler tests use a mock Broadcaster that records a visual parameter which production ignores. Broadcaster coalescing and retry have no test in the supplied inventory.

**Unverified.** Native, readability, Spaces and Linux acceptance remain unverified and are out of scope for source review.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

### Hypothesis falsification (performed before scoring)

1. **H1: A failed pause-release clear loses its legacy-reset obligation.**
   - **CONFIRMED (R1).**
   - In the reconcile path, effects are cancelled inside `prepare` at `visual-recovery.swift:404-406`. The bytes are written afterwards, at `ProcessRunner.swift:206-209`.
   - `resetLegacy` is derived only from an active `globalRestriction` record or the explicit `reset` flag, at `visual-recovery.swift:342` and `:365`.
   - Retry runs only while muted, at `Scheduler.swift:494-496`, and only as `.currentRestriction`, at `Broadcaster.swift:126`. That operation returns nil when no rule applies, at `visual-recovery.swift:316`.

2. **H2: A queued `broadcastPaused`/`broadcastLocked` can repaint after suspension.**
   - **DISMISSED.**
   - Both enqueue `.currentRestriction` without visual data, at `Broadcaster.swift:29-35`.
   - `prepare` calls `policy.current(deadline:)` inside the serialized write, at `visual-recovery.swift:315`. That call reads the marker before and after rule parsing, at `visual-restriction-policy.swift:29` and `:48`, and returns nil when restrictions are disabled.

3. **H3: Broadcaster coalescing drops a required pause clear when a later restriction request arrives.**
   - **DISMISSED.**
   - When a `.reconcile` is pending, a later `.currentRestriction` is ignored, at `Broadcaster.swift:80-83`.
   - Reconcile already paints a current rule when one exists, at `visual-recovery.swift:320-337`.
   - Two pending reconciles merge their `resetLegacy` and `clearSelective` flags with OR, at `:78-79`.

4. **H4: Unmute reconciliation reads the stale muted projection.**
   - **DISMISSED.**
   - `writeMuteState` runs at `Scheduler.swift:426`, before `clearPausedVisualAndReplayPending` at `:430-431`.
   - This ordering is pinned by `SchedulerLockTests.swift:239-253`.

5. **H5: The `~/.tavs` directory watcher re-triggers itself.**
   - **UNRESOLVED.** See the separate section below.
   - `writeMuteState` atomically rewrites `~/.tavs/mute.state` on every evaluation, at `Scheduler.swift:610-622`.
   - `startFileWatch` watches that same directory, at `:517-523`, with a 100 ms debounce, at `FileWatcher.swift:14`.
   - This is not verified at runtime, and it is not shown to be new.

### CRITICAL

None.

### IMPORTANT

1. **R1: `visual-recovery.swift:342,404-406` with `ProcessRunner.swift:206-209`, `Scheduler.swift:492-497` and `Broadcaster.swift:49-56,126`. A failed pause-release write is never retried while unmuted, and the legacy foreground reset is lost.**
   - **Trigger:**
     - A soft pause or lock ends, so `broadcastPausedClear` enqueues `.reconcile(resetLegacy: true, clearSelective: false)`.
     - One target is backpressured or slow, and `writeToDescriptor` or the post-prepare deadline check throws `deviceWriteTimedOut`.
   - **Behavior:**
     - `prepare` has already cancelled the active `globalRestriction` record (`cancelEffects(... effects)` at line 405) and unlinked the pending OSC.
     - The item is recorded as failed in `Broadcaster.failures`.
     - `heartbeatTick` only retries while `isMuted`. Even if it ran, `.currentRestriction` returns nil without a rule.
     - Later ordinary `--managed-render` and `--managed-background` writes compute `resetLegacy = false`, because no active global effect remains.
   - **Impact:**
     - The pause foreground (OSC 10) and the palette state persist on that terminal. Only the background follows later hooks.
     - Recovery requires a full Restore Visibility (suspension) or another mute/unmute cycle.
     - The menu meanwhile shows "Earlier terminal updates: 1 failed" indefinitely.
   - **Criterion:** SPEC:186 ("Timeouts/unverified live targets remain retryable"), SPEC:221 (release resets legacy foreground/palette), and PLAN phase 6 ("no failure pruning defeats retry").
   - **Smallest fix:**
     - Change the retry operation at `Broadcaster.swift:126` to `.reconcile(resetLegacy: true, clearSelective: false)`. This already paints the current rule when one applies.
     - Call `retryFailedRestrictions()` from `heartbeatTick` whenever `!visualRestrictionsStatus.disablesRestrictions`, not only while muted.
     - Update `SchedulerTests.swift:393-395`, which currently asserts the gap.
   - **Discriminating test:**
     - Build a real `Broadcaster` over `VisualRecovery` with `MockProcessRunner.managedHandler`. Have it invoke `prepare` and then throw `deviceWriteTimedOut` for the first reconcile only.
     - Seed an active `globalRestriction` effect on a fixture target with an unmuted policy.
     - Call `broadcastPausedClear()`, then `retryFailedRestrictions()`, and wait with `waitUntilIdle`.
     - Assert that the second write's bytes contain `ESC]110`.
     - Current code produces no second write: `.currentRestriction` returns nil, and the Scheduler never calls retry while unmuted. The test therefore discriminates.

### MINOR

1. **R2: `TAVSApp.swift:46-56`. The environment-selected isolated GUI launch pre-empts the remaining argument-driven CLI entries.**
   - **Trigger:** any process inheriting `TAVS_SESSIONS_TEST_ROOT`, `TAVS_SESSIONS_TEST_FIXTURE` or `TAVS_SESSIONS_TEST_TARGETS` invokes one of `--validate-config <path>`, `--verify-password-hash`, `--reported-status`, `--unregister-login-item` or `--dump-state`.
   - **Behavior:** these branches sit at lines 57-105, after the environment check. The invocation launches `IsolatedSessionsApp` instead (a blocking GUI) or exits 1.
   - `recoverHeadlessly` strips these keys only for its own probe (`visual-recovery.swift:81-83`), so callers elsewhere are unprotected.
   - **Impact:** an isolated test or CLI run can hang on a GUI, or misreport validation.
   - **Fix:** enter isolated mode only when `args.count == 1`, or move the environment check after all argument-handled branches.
   - **Test:** run `TAVSAppMain` dispatch with the test-root variable set and `--validate-config <valid file>`. Expect exit 0 without an app launch. Current ordering launches the app, so the test discriminates.

2. **R3: `Broadcaster.swift:29-35`, `Scheduler.swift:367,440,609` and `MockBroadcaster.swift:26-37`. Ignored visual parameters make the Scheduler visual tests non-discriminating.**
   - Production paints colors read from `mute.state` and `lock.state` by `VisualRestrictionPolicy`. Those values come from a second `pauseVisualProvider()` call at line 609, separate from the one at 367.
   - The mock instead asserts the discarded `visual` argument, for example in `SchedulerTests.swift:805-879` and `:918-969`.
   - **Impact:** tests can pass while the persisted `PAUSE_BG`/`PAUSE_FG` disagree with the repaint decision.
   - **Fix:** remove the unused parameters, or compute the visual once and pass it into `writeMuteState`. Assert on the `mute.state` `PAUSE_BG`/`PAUSE_FG` contents.

### Unresolved hypotheses (not findings)

- **H5: possible self-sustaining evaluation loop.**
  - **Mechanism:** an atomic rename into `~/.tavs` raises a directory write event, which triggers `loadAndEvaluate()` 100 ms later, which rewrites `mute.state`, which raises another event.
  - The runtime watcher explicitly guards against this pattern for `lock.state` (`Scheduler.swift:526-547`), but the `~/.tavs` watcher has no such guard.
  - **Status:** not verified at runtime. It may predate this feature.
  - **Discriminating test:** run a real `FileWatcher` on a temporary directory holding both `schedule.json` and `mute.state`, wrap the Scheduler, and count evaluations over 2 s with no external change. More than 2 evaluations confirms the loop.
  - **Fix if confirmed:** compare the schedule and marker content (or modification times) before re-evaluating, mirroring `lastReadLockState`.
- **Broadcaster coverage is unknown.** Its coalescing, retry and catalogue-flag behavior are not covered by any test in the supplied inventory. `BroadcasterTests.swift` was not supplied, so its coverage is unknown rather than absent.

===END_ISSUES===

---

===SCORE_CARD===

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | 6/10 | Policy is recomputed under the writer lock and persistence ordering is sound. R1 loses a pause-release reset after a write timeout with no unmuted retry. |
| Security | 8/10 | Test-root containment is validated (`ManagedOutputEntry.validateRoot`). Paths use O_NOFOLLOW reads, and no input is injected. R2 is robustness, not privilege. |
| Maintainability | 6/10 | Ignored `visual`/`untilText` parameters mislead readers. Policy, effect and lease logic is dense and long in the connected recovery code. |
| Test Coverage | 6/10 | Suspension, lock and grant Scheduler cases are strong. Visual assertions target the discarded mock parameter. No supplied Broadcaster retry or coalescing test exists, and one test pins the R1 gap. |
| Performance | 7/10 | The main thread never writes to a device, and Broadcaster work is serialized off-main. Each operation performs its own native snapshot (up to 2.2 s). H5 is an open loop risk. |
| **Overall** | **6.7/10** | Weighted 25/25/20/15/15. **Verdict: CONCERN** (all dimensions >= 5, some < 7). |

===END_SCORE_CARD===

---

===RECOMMENDATIONS===

1. **[Priority 1]** Fix R1:
   - Make the Broadcaster retry operation `.reconcile(resetLegacy: true, clearSelective: false)`.
   - Invoke the retry from the heartbeat whenever restrictions are active, not only while muted.
   - Add the described mock-runner test and update `SchedulerTests.swift:393-395`.
2. **[Priority 2]** Settle H5 with a real-watcher evaluation-count test. If it is confirmed, gate the `~/.tavs` watcher on schedule or marker content changes.
3. **[Priority 3]** Fix R2 by restricting isolated launch to the no-argument case. For R3, compute the pause visual once per evaluation and assert the persisted `mute.state` colors rather than the mock parameter.

===END_RECOMMENDATIONS===

---

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-session
Model requested: opus
Model observed: unknown
Effort requested: unspecified
Effort observed: unknown
NOTE: real native Claude CLI under Hub controls, chosen by caller; it is not an automatic fallback or evidence that applied model/effort were observed.
Input scope: Partition 2 (Scheduler/Broadcaster and app wiring), subscope 05-scheduler-startup, at commit 7ecfba2 (clean checkout). All supplied files were reviewed:
- Specification: SPEC.md and PLAN.md.
- Package and resources: Package.swift and Info.plist.
- App sources: Scheduler.swift, Broadcaster.swift, TAVSApp.swift, MenuContent.swift, PreferencesView.swift, UserConfStore.swift, FileWatcher.swift, Clock.swift, TimerScheduler.swift, MuteState.swift, LockState.swift, ScheduleStore.swift, TAVSLog.swift, ChallengeGate.swift and ChallengeVerifier.swift.
- Connected sources: terminal-visual-state.swift, terminal-renderer.swift, terminal-render.swift, ProcessRunner.swift, process-identity.swift, PauseVisual.swift, visual-restriction-policy.swift, visual-restrictions-state.swift, visual-recovery.swift, focus-controller.swift and managed-output-entry.swift.
- Tests: SchedulerTests, SchedulerLockTests, ScheduleStoreTests, FileWatcherTests, ChallengeVerifierTests, UserConfStoreTests, PreferencesPauseVisualPreferenceColorsTests and SmokeTests.
- Mocks: MockBroadcaster, MockFileWatcher, MockLoginItemService, MockProcessRunner and MockTimerScheduler.

"Full" refers to this supplied subscope only, not whole-goal acceptance.
Focus: all default
Limitations:
- **Tool-free, single-turn session.** No files were read beyond the supplied blocks. Nothing was built, tested or run, and no report file could be written under /tmp, so the parent must persist this output.
- **Files not supplied.** SessionsModel, GhosttyCatalog, OrganizerIntake, attention-state and BroadcasterTests were not available, so their behavior was inferred only from call sites.
- **Physical and runtime acceptance unverified.** Native catalogue, navigation, readability, Spaces and permission acceptance are unverified. So are Linux ordinary-backend and kernel runtime behavior.
- **Prior test results establish nothing here.** The historical first-paint/EPERM and fresh-render timeout causes remain unestablished. The 570 passing Swift tests are not treated as evidence.
- **H5 is open.** It requires runtime confirmation.
===END_REVIEW_META===


## part06: portable backend and ordinary compatibility

> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

**Report path:** none written. This session had no tools, so the full report is inline below rather than saved under /tmp. The caller should persist this output under a timestamped name such as `/tmp/claude-review-code-terminal-agent-visual-signals-main-<timestamp>.md`.

- **Verdict:** VETO, grade 5.6/10, risk High. One dimension scored below 5 (Correctness 4).
- **Issue counts:** 1 critical, 2 important, 4 minor.
- **R1 (critical):** with no native helper, ordinary signaling produces no terminal output on Linux. The README promises macOS and Linux support, so this is a compatibility regression.
- **R2 (important):** on the portable backend, Gemini, OpenCode, unknown-provider and manual runs lose idle graduation and tool-error restoration. Their observations are rejected, and synthetic renders then fail as stale.
- **R3 (important):** per-TTY target buckets grow without limit and are never retired, so per-hook cost grows until the 100 ms writer deadline fails.

> [!NOTE]
> The caller chose the real native Claude CLI under Hub controls. This is not an automatic fallback and is not evidence of which model or effort was applied.

# Claude Review Report

**Mode**: code-session
**Date**: 2026-10-14
**Focus**: all

---

===DIMENSION_RATIONALE===
I used the five default dimensions without change: correctness, security, maintainability, test coverage and performance. They fit this artifact, which is a portable Python ordinary-output backend plus the shell selection and render routing that call it. No dimension was added.

Shell compatibility across macOS, Linux and different agents is judged under Correctness. The caller asked that an explicitly unsupported Linux backend not be accepted as an excuse for a compatibility regression.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
Overall grade: 5.6/10 (VETO, because Correctness scored 4)
Risk level: High

**Strengths.** The portable backend is a carefully bounded, data-only writer:
- strict schema parsing;
- held directory descriptors;
- a forked 100 ms device transaction that opens the device before taking the lock;
- fresh suspension-revision checks inside the lock;
- explicit stale versus unavailable categorisation.

**Why it still fails.** As wired today it causes concrete regressions in ordinary signaling:
- On Linux, or any non-Darwin host without the native helper, every background, title and palette write is now dropped (R1).
- For providers other than Claude and Codex, plus manual runs, idle graduation and tool-error restoration stop on the portable backend (R2).
- Per-TTY target caches grow without bound and eventually exceed the device deadline (R3).

**Out of scope for this review.** Native catalogue, navigation, readability and Spaces acceptance, plus Linux runtime acceptance, remain unverified and are not assessed here.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

### Hypothesis falsification

**H1. A failed selected operation switches backend or raw-writes.** Dismissed.
- `src/core/helper-selection.sh:47-74` caches a single choice. `_tavs_helper_call` (lines 76-79) never reprobes.
- `src/core/organizer-state.sh:160-189` reports failure without any printf fallback.
- `tests/unit/helper-selection.bats:88-105` discriminates this case.

**H2. A recovery queued during device open can still paint with the pre-recovery policy.** Dismissed.
- `src/core/portable_renderer.py:176` captures a pinned marker revision before open.
- Lines 191-192 and 208-210 return `None` or raise `ESTALE` under the lock if the marker inode changed.
- Reconcile captures after open (`portable_renderer.py:103`).
- Covered by `test_recovery_during_open_rejects_prepared_style` and `test_marker_change_queued_during_open_returns_unaffected_without_pixels`.

**H3. Existing standalone signaling on Linux is preserved.** Confirmed broken (see R1).
- `src/core/portable_helper.py:72-79` refuses every verb on non-Darwin.
- `src/core/portable_records.py:61` rejects `/dev/pts/N`.
- Nothing else writes output.

**H4. Non-Claude/Codex providers keep idle and tool-error restoration.** Confirmed broken (see R2).
- `src/core/portable_records.py:152` rejects their observations.
- `src/core/portable_intent.py:85-86` then makes every synthetic render stale.

**H5. An uncorrelated or interpreter process can be marked `verifiedAgent`.** Dismissed.
- `src/core/portable_context.py:60-70` rejects node, bun, shells and python.
- Lines 89-94 require foreground-family proof before the executable match.
- The foreground fallback stays `verifiedAgent: false`.
- Tests: `tests/unit/test_portable_context.py:35-74`.

### CRITICAL

**R1. [src/core/portable_helper.py:72-79, src/core/portable_records.py:61, src/core/helper-selection.sh:60-71, src/core/organizer-state.sh:160-189, src/core/terminal-osc-sequences.sh:84-91]**
Without the native helper, ordinary terminal output is lost entirely on Linux.

- **Trigger:** any hook or `./src/core/trigger.sh processing` on Linux. TAVSApp does not exist there, so the native probe fails.
- **Behaviour:**
  - The portable capability probe returns exit 1 because `sys.platform != "darwin"` (lines 72-79).
  - `_tavs_helper_select` therefore selects nothing.
  - `send_osc_bg`, palette and title calls only queue.
  - `_tavs_render_flush` sets `result=1` and prints `tavs: current render unavailable`.
  - No OSC bytes are written.
- **The Linux code paths are dead or contradictory:**
  - `_linux_inspect` exists (`portable_process_identity.py:147-194`) but is unreachable from the helper.
  - `device_number` accepts `/dev/pts/N` (line 200), but `_tty(concrete=True)` only accepts `/dev/tty[A-Za-z0-9]+`.
  - `executable_path` returns `None` off Darwin.
- **Impact:** a compatibility regression of the core product on a platform the README advertises (`README.md:1086`). The README disclaimer at line 1092 does not excuse it. The SPEC asks to "preserve direct ordinary signaling when no controller owns an effect" (SPEC:163).
- **Smallest remedy:** distinguish "no backend selectable" from "selected operation failed".
  - When selection yields no backend, keep the previous direct ordinary write path for background, title and palette only, never for restrictive paints.
  - This respects PLAN's rule against replacing a *failed* managed write with printf.
  - Alternatively, enable the portable backend on Linux: drop the Darwin gate, and accept `/dev/pts/[0-9]+` in `_tty(concrete)` and in `target_path` keys.
- **Criterion:** the existing standalone macOS/Linux, companion-optional promise, plus SPEC:161-164.
- **Discriminating test:** a Bats test under `tests/run-isolated.sh` with both the native candidate and the portable capability unsupported, using an owned PTY.
  - Run `trigger.sh processing` and assert `ESC]11;` bytes arrive.
  - Current code yields zero bytes, so the test fails today and passes after the fix.
  - Linux kernel runtime itself remains unverified.

### IMPORTANT

**R2. [src/core/portable_records.py:152, src/core/portable_observation.py:22, src/core/organizer-state.sh:73-74, src/core/portable_intent.py:85-86, src/core/portable_helper.py:131-133, src/core/idle-worker-background.sh:179-181, src/core/trigger.sh:411-420]**
On the portable backend, synthetic idle and tool-error renders are always stale for Gemini, OpenCode and unknown providers.

- **Trigger (main path):** `TAVS_AGENT=gemini`, `opencode` or unset (`unknown`), followed by a `complete` or `tool_error` hook.
  - `--organizer-context` accepts these providers, because `PROVIDERS` includes them.
  - `--organizer-observe` then fails `decode`, which only allows the providers `claude` and `codex`.
  - So no observation is published for this delivery.
- **Effect on the idle worker:** its first synthetic `--managed-render` reaches `_check_observation`. A synthetic render with no matching observation raises `StaleRecordError`, giving exit 3, and `unified_timer_worker` returns at line 181. Idle graduation never paints.
- **Effect on tool-error restoration:** `_tavs_managed_check_context` returns 3, so the tool-error colour never returns to processing.
- **Second trigger, same symptom:** a manual run from an interactive shell, as the README "Manual State Testing" section documents.
  - The producer is the transient `trigger.sh` process itself.
  - That process exits before the worker ticks.
  - `portable_helper.py:131-133` therefore marks it stale.
- **Impact:** a regression of existing idle and tool-error behaviour for two of the four supported agents, and for the documented manual tests.
- **Native parity is unverified:** Swift sources were not supplied.
- **Smallest remedy:**
  - Accept all `PROVIDERS` values in observation records with `verifiedAgent` kept as is. Automatic focus already excludes uncorrelated or unsupported coverage, so this does not widen eligibility.
  - Keep Swift parity with this change.
  - For manual runs, bind the producer to the continuing TTY owner rather than the exiting script.
- **Criterion:** SPEC:134-137 (idle remains independent of meaningful observations) and existing behaviour preservation.
- **Discriminating test:** an owned PTY with the portable backend, `TAVS_AGENT=gemini` and `UNIFIED_STAGE_DURATIONS` of about 1s.
  - Run `trigger.sh complete` and assert stage-1 idle bytes arrive.
  - Today no bytes arrive and the worker exits, so the test discriminates.

**R3. [src/core/portable_renderer.py:55-59, src/core/portable_records.py:198-205, src/core/portable_ownership.py:156-237, 254-270]**
Per-TTY target buckets grow without bound and are never retired by the portable backend.

- **Trigger:** every interactive shell start runs `--managed-register`.
  - Each new TTY-owner generation writes `targets/<tty>/<owner-gen>/plain/target.json`.
  - macOS reuses `ttys000` to `ttysNNN`, so between reboots one bucket accumulates one directory per shell lifetime.
- **Behaviour:** every render, register, current and reconcile call walks the whole bucket (`cached`). It then calls `status()` on every candidate (`_current`, lines 227-234). Each call costs a record read, two libproc lookups, `kill(0)` and `lstat`.
- **Impact:**
  - Per-hook cost grows linearly with the bucket size.
  - Past an unmeasured threshold the shared 100 ms deadline (`portable_device_writer.py:114`) expires.
  - All ordinary output for that TTY then fails with `ETIMEDOUT` until `/tmp` is cleared.
  - On the portable backend there is no native controller to retire "confirmed closed bindings" (SPEC:186).
- **Smallest remedy:** under the per-TTY lock in register and current, unlink target directories whose `status()` is `vanished` and that hold no active effect.
- **Criterion:** the 100 ms caller deadline and performance.
- **Discriminating test:** seed 500 vanished `target.json` entries (missing PIDs) in one bucket, then run `Renderer.render`.
  - Assert success and that the bucket is pruned.
  - Today this either times out or leaves the bucket unpruned, so the test discriminates.

### MINOR

**R4. [src/shell/tavs-shellrc.sh:106-120, src/core/helper-selection.sh:52-66, src/core/organizer-state.sh:21-75, 160-172]**
Startup and per-hook interpreter launches.
- With the portable backend, every interactive shell start runs three synchronous Python launches (probe, register, current), each importing ctypes and libproc.
- Each hook runs intake, observe and render (plus a fork inside render).
- With the native app present but partial, two native probe launches are added.
- `README.md:1067-1078` ("bash builtins to minimize subprocess spawning") is now inaccurate.
- Latency was not measured.
- **Fix:** measure the cost. Consider merging register and current into one helper call, and caching the capability probe result per helper path and mtime.

**R5. [src/core/terminal-osc-sequences.sh:63-66, src/core/portable_process_identity.py:200, src/core/portable_records.py:59-61]**
The `/dev/tty` fallback from `resolve_tty` is now always rejected.
- `device_number` requires at least one character after `tty`, so `/dev/tty` fails.
- Agents nested deeper than five process levels previously painted via `/dev/tty` and now get `current render unavailable`.
- **Fix:** inside the helper, resolve `/dev/tty` to the concrete device with `os.ttyname` on an opened `/dev/tty` file descriptor before validation.
- **Test:** a ps stub that yields no TTY, with a PTY as the controlling terminal; assert bytes arrive.

**R6. [src/core/portable_renderer.py:81-84, src/core/portable_helper.py:137 vs src/core/portable_render.py:37-39]**
Forced-reset titles reject Unicode category Cf, but ordinary render titles accept it.
- A working directory containing a ZWJ emoji (for example `👩‍💻`) makes the max-runtime forced reset fail, leaving the final idle colour in place.
- **Fix:** apply `_safe_text` semantics to forced-reset titles, or strip Cf characters in `get_short_cwd`.

**R7. [src/core/portable_device_writer.py:38-42, src/core/portable_record_io.py:27-28, src/core/portable_ownership.py:47-66]**
The runtime root `/tmp/tavs-$UID` and its organizer directory are created with `exist_ok` but never checked for owner or mode.
- Another local user who pre-creates the directory can plant effect or target records. That causes denial of service (EBUSY or EINVAL) and limited colour influence.
- The lock file's uid check only produces denial of service.
- **Fix:** verify that the runtime root and `organizer/` are owned by the effective uid and are not group- or world-writable before use.

### Unresolved hypotheses (not counted)

- **CLT stub dialog.** On macOS without the Command Line Tools, `#!/usr/bin/env python3` resolves to the `/usr/bin/python3` stub. Each probe may raise the CLT install dialog. This depends on the environment and was not verified.
- **Partial OSC on timeout.** When the parent's deadline `select` (`portable_device_writer.py:147-151`) kills a child that is mid-write after a partial nonblocking PTY write, a truncated OSC may remain and `bytes_written` is reported as `None`. Terminal-side impact was not verified.
- **R2 on the native backend.** Whether R2 also occurs there is unknown, because the Swift observation decoder was not supplied.
- **Backwards wall-clock steps.** Records timestamped in the future become invalid. Ordinary paths self-repair through `recover_invalid`, but effect records with a future `heartbeatAt` could block output until the clock catches up. This was not reproduced.

===END_ISSUES===

---

===SCORE_CARD===

**Metadata:** Partition 1, subscope 06-portable-backend; commit 7ecfba2; tool-free.

**Rubric Scores:**

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | 4/10 | Linux ordinary output lost (R1); synthetic idle and tool-error lost for non-Claude/Codex providers (R2) |
| Security | 7/10 | Strict data-only parsing, no injection paths; runtime root ownership unchecked (R7) |
| Maintainability | 6/10 | Dense cross-module use of private members (`_lookup`, `_current`, `_binding`); long transactional closures |
| Test Coverage | 6/10 | Strong deadline and race tests; missing provider, Linux, bucket-growth and `/dev/tty` cases |
| Performance | 5/10 | Repeated interpreter launches; unbounded bucket walks per write (R3, R4) |
| **Overall** | **5.6/10** | Weighted 25/25/20/15/15 |

**Verdict:** VETO. The rule is mechanical: Correctness is below 5.

===END_SCORE_CARD===

---

===RECOMMENDATIONS===

**Findings:** R1 (CRITICAL); R2 and R3 (IMPORTANT); R4 to R7 (MINOR).

1. **Priority 1.** Restore ordinary output when no backend is selectable (R1), or make the portable backend Linux-capable, with `/dev/pts` support. Add an owned-PTY test for the no-helper case.
2. **Priority 2.** Accept all providers in observation records, with Swift parity, so synthetic idle and tool-error restoration work for Gemini, OpenCode and unknown providers. Bind manual-run producers to the continuing TTY owner (R2).
3. **Priority 3.** Retire vanished target bindings under the per-TTY lock and add a 500-entry deadline test (R3). Measure helper startup latency (R4).

**Summary:** The backend's locking, deadline and suspension ordering hold up under falsification. The verdict rests on regressions to existing ordinary signaling and on unbounded state growth.

===END_RECOMMENDATIONS===

---

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-session
Model requested: opus
Model observed: unknown
Effort requested: unspecified
Effort observed: unknown
NOTE: real native Claude CLI under Hub controls, chosen by caller; it is not an automatic fallback or evidence that applied model/effort were observed.
Input scope: Partition 1, subscope 06-portable-backend at commit 7ecfba2. Reviewed every supplied file:
- Specification and context: SPEC.md, PLAN.md, Package.swift, README.md.
- Portable sources: `src/core/portable_{context,device_writer,helper,intent,metadata,observation,ownership,policy,process_identity,record_io,records,render,renderer}.py`.
- Python tests: all `tests/unit/test_portable_*.py`.
- Connected shell callers: `helper-selection.sh`, `organizer-state.sh`, `visual-restrictions-state.sh`, `terminal-osc-sequences.sh`, `trigger.sh`, `idle-worker-background.sh`, `tavs-shellrc.sh`.
- Shell tests and harness: `helper-selection.bats`, `resolve-tty.bats`, `tests/conftest.py`, `tests/run-isolated.sh`.

"Completion: full" refers to this subscope only, not whole-goal acceptance.
Focus: all default
Limitations:
- **Session constraints:** tool-free single turn. Nothing was built, tested or executed, and no report file could be written to /tmp, so the report is returned inline.
- **Not supplied:** Swift native sources, so native parity for R2 is unverified.
- **Unverified acceptance:** native catalogue, navigation, readability, Spaces and permission acceptance, and Linux kernel runtime.
- **Unmeasured:** performance thresholds in R3 and R4.
- **Not established:** historical first-paint/EPERM and fresh-render timeout causes. Passing tests and documentation are not treated as physical acceptance.
===END_REVIEW_META===


