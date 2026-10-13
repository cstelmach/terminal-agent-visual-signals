> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# Claude Review Report

===DIMENSION_RATIONALE===
The five default code dimensions fit this partition. Pass C covers the scheduler, broadcaster, menu, application entry and mute-state seam. Requirements traced here are global pause and lock precedence, suspension projection, the no-replay pause release, menu reachability of recovery and focus controls, and headless dispatch ordering.

- **Correctness** carries most of the weight. It covers transition ordering, coalescing semantics and suspension projection.
- **Security** covers OSC injection through lock and mute files, isolated-launch root validation, and registry path handling.
- **Maintainability** covers API naming drift after the semantic rewrite.
- **Test coverage** covers PTY byte tests and scheduler suspension tests.
- **Performance** is retained as the fifth scored row, as the score card requires. It covers native enumeration cost per transition, coalescing and thread blocking.

Coverage table for this pass:

| PLAN phase | Primary file(s) in Pass C | Covered |
|---|---|---|
| 1-2 (catalogue, Sessions scene, menu entry) | TAVSApp.swift, MenuContent.swift | Yes, full read |
| 3 (isolation) | BroadcasterTests.swift (TAVS_TEST_ROOT), TAVSApp.swift isolated launch | Yes |
| 5 (suspension readers, scheduler projection) | Scheduler.swift, MuteState.swift, SchedulerTests.swift, SchedulerLockTests.swift, MuteStateTests.swift | Yes |
| 6 (managed writer routing, no replay) | Broadcaster.swift, BroadcasterTests.swift, MockBroadcaster.swift | Yes, with VisualRecovery/ProcessRunner as dependency context |
| 7 (merged Restore Visibility, pause release recomposition, PauseVisual reuse) | MenuContent.swift, Scheduler.swift, PauseVisual.swift | Yes |
| 8-9 (menu Focus Selected / Automatic / Focus Off reachability) | MenuContent.swift | Yes (wiring only; policy lives in other partitions) |

Failure hypotheses examined:

1. **Coalescing a queued `.currentRestriction` with a later `.reconcile` could drop a required pause clear, or vice versa.**
   - Dismissed. In `Broadcaster.swift:63-72` a pending reconcile is kept when a restriction arrives. A later reconcile replaces a pending restriction.
   - `VisualRecovery.performWrite` (`visual-recovery.swift:290-307`) paints the fresh rule for any operation except clearFocus, so reconcile strictly subsumes currentRestriction.
2. **The unmute clear could read the old MUTED projection and repaint the pause.**
   - Dismissed. `Scheduler.swift:417-423` now writes mute.state before enqueueing the clear.
   - `SchedulerLockTests.testUnmutedProjectionIsSavedBeforeVisualReconciliation` asserts that ordering.
3. **Suspension could leave `isHardLocked` gating, or project a lock into mute.state, causing shells to paint while suspended.**
   - Dismissed. `Scheduler.swift:392-397` and `:436` force projected unmute and `isHardLocked=false`.
   - The shell and Swift policy readers check the marker first (`mute-gate.sh:51`, `visual-restriction-policy.swift:29-31`).
4. **Emergency recovery, followed by the GUI scheduler's reaction to the marker change, reapplies ordinary themes despite the SPEC saying it does not.**
   - Confirmed as a low-severity contract divergence (Issue L1).
5. **Isolated-launch environment detection in `TAVSAppMain.main` could route legacy headless flags into a GUI.**
   - Confirmed for legacy flags (Issue L2).
   - Dismissed for the new managed, organizer and visual-restriction verbs, which are dispatched first at `TAVSApp.swift:43-45`.
===END_DIMENSION_RATIONALE===

===EXECUTIVE_SUMMARY===
Overall grade: 7.05
Risk level: Medium
Verdict: CONCERN

The Pass C seam no longer forwards caller-supplied pause visuals, lock titles or opaque pending bytes.

- **Broadcaster.** It is a coalescing queue over `VisualRecovery.apply`. Restriction paint is recomputed from current lock/mute/marker files inside the managed writer. `broadcast()` no longer replays pending output.
- **Scheduler.** It projects suspension as an effective unmute. It preserves requested cause (`REQUESTED_MUTED`, `MUTE_LEVEL`) and lock/grant timers. It now writes mute.state before release reconciliation.
- **Menu.** It merges the legacy Restore Terminal Colors action into Restore Visibility and exposes focus and recovery controls without opening Sessions.

No critical or high defect was found in this partition. The remaining findings are:

- Scheduler-driven paint failures are silently discarded, with no logging or user-visible report.
- The GUI's own reaction to a recovery marker change reapplies ordinary background intent, which diverges from the stated emergency-recovery contract.
- The isolated-launch environment takes precedence over legacy headless flags.
- The lock title clock format ignores the scheduler calendar and locale.
- Naming and comment drift is substantial after the semantic rewrite.
- The re-enable warning is unconditional rather than computed.

Native, menu and relaunch acceptance remain empirically unverified. This pass is complete within its primary scope; it is not an aggregate implementation sign-off.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
CRITICAL: none found.

HIGH: none found.

**MEDIUM M1: Scheduler-driven restriction and release outcomes are discarded without logging or user-visible reporting**
- **Location:** `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift:98-107`, `:110-114`, `:17-21`; `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift:458-473`
- **Trigger:** A lock begins (or a pause is released) while one cached terminal is busy, for example its advisory writer lock is held or the device is backpressured past the 100 ms deadline.
- **Situation:**
  - `drain()` stores the `VisualRecovery.apply` result only in the private `result`.
  - `result` is exposed only as `lastResult`, which no production code reads.
  - `Broadcaster` emits no `TAVSLog` entries for failed items. Scheduler status only reflects rule state.
- **Behavior:**
  - The failed target keeps its cached binding, so it is retryable in principle.
  - The scheduler re-issues paint only on a projection or visual change (`Scheduler.swift:425-434`). A busy target therefore stays unpainted for the whole lock, or unreleased after a pause ends, until the next transition.
  - The operator gets no indication. Unverified registry-only targets (`visual-recovery.swift:424-426`) are dropped the same way.
- **Impact:**
  - The SPEC requires busy and unverified targets to be reported as partial failures, and failed targets to remain retryable.
  - Recovery satisfies this through its report. The scheduler path, which is the normal lock and pause-release path, does not.
  - A lock that silently misses a terminal weakens the commitment-device signal. A missed release leaves a paused color until a hook repaints.
- **Suggestion:**
  - Log failed items through the existing `TAVSLog.broadcaster` category, without titles or paths beyond the TTY.
  - Optionally reissue `.currentRestriction` or `.reconcile` on the existing 60 s heartbeat when the last result contained failures.
  - This needs no new control plane.
- **Confidence:** Medium. The no-retry behavior predates this branch, but the branch replaced the writer and added explicit partial-failure semantics without wiring them here.

**LOW L1: GUI reaction to a recovery marker change reapplies ordinary background intent right after emergency reset**
- **Location:** `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift:392-397`, `:421-423`, `:469-473`; dependency `visual-recovery.swift:337-340`
- **Trigger:**
  1. TAVS is under a soft pause or lock.
  2. The operator runs `tavs recover` from another terminal, or uses menu Restore Visibility.
  3. The helper writes the marker and sends OSC 104/110/111.
  4. The Scheduler's watcher on `~/.tavs` (`Scheduler.swift:505-512`) re-evaluates. It sees `wasMuted && !projectedMuted` and enqueues `.reconcile(resetLegacy: true)`.
- **Behavior:** Reconcile composes `ordinaryBackgroundUnlocked` and writes OSC 11 with the latest TAVS intent, depending on interleaving with the helper's reset.
- **Impact:**
  - The SPEC says emergency recovery "does not immediately reapply ordinary themes; the next legitimate hook can restore those themes."
  - The outcome depends on whether the GUI was muted at the moment of recovery. Visibility is still restored, so this is a contract divergence rather than a safety failure.
  - `SchedulerTests.testSuspensionClearsPriorPaintAndSuppressesTicksThenResumeRepaintsCurrentPause` locks this behavior in at the mock level.
- **Suggestion:**
  - Either document that a running GUI recomposes ordinary intent after suspension, or skip the background recomposition when the transition cause is `restrictionsDisabled`.
  - In the second case, still send the legacy reset.
- **Confidence:** Medium-high on the code path; the native visual effect is unverified.

**LOW L2: Isolated-session environment overrides legacy headless flags and launches a GUI**
- **Location:** `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift:46-56` precedes `:57-105`
- **Trigger:** A process environment containing any `TAVS_SESSIONS_TEST_*` key invokes the executable with `--validate-config <schedule.json>`, `--verify-password-hash`, `--reported-status`, `--unregister-login-item` or `--dump-state`. An example is a CLI command run from a shell inherited from an isolated acceptance session.
- **Behavior:** The process starts `IsolatedSessionsApp.main()`, or exits 1 on invalid scope, instead of performing the headless action. A CLI caller waiting for validation output blocks on a GUI.
- **Impact:**
  - The PLAN rule is that known headless branches must not fall into SwiftUI.
  - The shell capability probes already strip these keys (`organizer-state.sh:13-15`, `:77-79`), so production exposure is limited to test-adjacent shells.
- **Suggestion:** Move the isolated-launch check after the legacy flag branches, or apply it only when no recognized flag is present.
- **Confidence:** High on ordering; low on real-world frequency.

**LOW L3: Lock title ignores the scheduler's calendar and locale, and the `untilText` argument is dead**
- **Location:** `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift:29-31`; `Scheduler.swift:459-461`; dependency `visual-recovery.swift:589-593`
- **Trigger:** A lock is painted on a host using a 12-hour locale or a non-`Calendar.current` scheduler calendar.
- **Behavior:**
  - The terminal title is fixed `%02d:%02d` from `Calendar.current`.
  - The menu status uses `DateFormatter` short style with the scheduler calendar (`Scheduler.swift:691-697`). The two disagree in format.
  - `formatTime` work in `paintMuted` is computed and discarded.
- **Impact:** Cosmetic inconsistency, plus a misleading API that suggests the caller controls the title.
- **Suggestion:** Pick one formatter shared by both paths. Drop the unused parameters from `BroadcasterProtocol`, or document them as ignored.
- **Confidence:** High.

**LOW L4: Naming and comment drift after the semantic rewrite**
- **Location:**
  - `Scheduler.swift:153-163`: the protocol comment still describes ps-based agent discovery.
  - `Scheduler.swift:469`: `clearPausedVisualAndReplayPending` no longer replays.
  - `Broadcaster.swift:37-39`: `broadcast()` is now a reconcile.
  - `SchedulerTests.swift:711`: `testMutedToActiveClearsBeforePendingReplay`.
  - `SchedulerTests.swift:1150-1182`: the test comments say "Unmute drains pending exactly once" and "writes its OSC bytes to pending/".
- **Trigger:** A maintainer reads the protocol or tests to understand release semantics.
- **Impact:** The names assert historical-replay semantics that the SPEC now forbids. That risks a future change reintroducing replay to "match" the name.
- **Suggestion:** Rename to `reconcile`, `reconcileAfterRestriction` and similar, and update the comments. No behavior change.
- **Confidence:** High.

**LOW L5: Re-enable warning is unconditional rather than describing an immediately applicable rule**
- **Location:** `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift:36-40`
- **Trigger:** The operator opens the menu while suspended and no schedule or lock would apply on resume.
- **Behavior:** The menu always shows "Saved schedules and locks may apply immediately."
- **Impact:**
  - The SPEC asks to "Explain when an existing schedule will apply immediately on resumption."
  - The Scheduler already computes `requestedMuted` and `hardCaused` (`Scheduler.swift:389-391`) but does not publish them, so the menu cannot be specific.
- **Suggestion:** Publish the requested projection, already written to mute.state, and condition the caption on it.
- **Confidence:** Medium. "May apply" can be read as satisfying a weaker form of the requirement.

**LOW L6: Every pause, lock or release transition and every launch performs native Ghostty enumeration**
- **Location:** `Broadcaster.swift:98-106`; dependency `visual-recovery.swift:384-396`; `TAVSApp.swift:291`
- **Trigger:** App launch, or any scheduler transition.
- **Behavior:**
  - `apply` dispatches `GhosttyCatalog.shared.snapshot()` (osascript, bounded at 2 s) for each drained operation. Startup runs it twice: registration plus the operation.
  - On first launch after update this can surface a TCC Automation prompt at login, before the user has opened Sessions.
- **Impact:**
  - Modest latency per transition, mitigated by coalescing.
  - The surprise permission prompt is a UX consequence, not a correctness failure. Cached targets still restore when access is denied, which matches the SPEC.
- **Suggestion:** None required for correctness. Consider documenting the launch-time Automation query in the menubar reference.
- **Confidence:** Medium.

Dismissed hypotheses:

- **Unchallenged master resume while suspended bypasses a hard lock.**
  - `SchedulerLockTests.testConfiguredMasterCanResumeWithoutChallengeWhileVisualLockIsSuspended` permits toggling `master_active` without a challenge.
  - `masterPaused` is never hard (`Scheduler.swift:15-17`). The manual lock remains in lock.state and re-applies on resume (asserted by its unchanged `lockUntilEpoch`). No lock is defeated.
- **OSC injection through LOCK_BG/LOCK_FG or PAUSE_BG/PAUSE_FG.**
  - The policy constructs `PauseVisual`, which normalizes to `#RRGGBB` or the default (`PauseVisual.swift:16-26`, `visual-restriction-policy.swift:73-76`).
  - The title contains only digits.
- **Removal of the 24 h registry pruning and ps discovery loses targets.**
  - Registry-only TTYs are now reported unverified rather than painted, which matches the SPEC rule that uncertainty never authorizes painting a reused TTY.
  - Hook-touched TTYs are cached through the managed writer.
- **Startup flash of an existing pause.**
  - Prior-effect reconciliation under an active rule repaints the current restriction (`visual-recovery.swift:290-307`), and the following `paintMuted` coalesces. No unpainted interval is introduced.

Empirical acceptance gaps (not defects):
- Menu reachability under hard lock, relaunch-into-suspension UI and the eye.slash state are untested in native UI.
- Actual pause and lock salience on Ghostty, and the sequencing of recovery bytes against the GUI reconcile from L1, are not observed on a device.
- Ghostty TCC behavior for the launch-time enumeration is unverified.

Supported product boundaries:
- Arbitrary program colors and palette themes cleared by OSC 104 at release are not restored, which is consistent with the SPEC.
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| correctness | 7/10 | Transition ordering, coalescing and suspension projection are correct. Scheduler-path partial failures go unreported (M1). The GUI recomposes intent after emergency reset (L1). Isolated env overrides legacy flags (L2). |
| security | 8/10 | Restriction bytes come from re-parsed, normalized state under the writer lock. Registry names no longer become write paths. Isolated roots are confined to temp dirs. |
| maintainability | 6/10 | Broadcaster is now small and cohesive. Protocol and method names, the dead `visual`/`untilText` parameters and test comments still describe replay semantics (L3, L4). TAVSApp.swift absorbed SessionsModel factory and isolated-launch logic. |
| test_coverage | 7/10 | Exact-byte PTY tests cover pause, lock, clear without title/BEL replay, coalescing, queued suspension and healthy-beside-failed retry. Scheduler suspension, unavailable-marker and timer retention are well covered. Missing: currentRestriction-then-reconcile coalescing, multi-target pause, entry-point precedence and any result consumption. |
| performance | 7/10 | Coalescing prevents native backlog (asserted `calls == 2`). Each transition still pays an osascript enumeration of up to 2 s, and startup pays two (L6). |
| Overall | 7.05/10 | 25%, 25%, 20%, 15%, 15% respectively |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. **Fix M1.** Log failed and unverified items from `Broadcaster.drain` through `TAVSLog.broadcaster`. Optionally re-issue the current restriction or reconcile on the existing heartbeat when the last result had failures. This keeps the SPEC's partial-failure and retry semantics on the normal lock path with no new mechanism.
2. **Resolve L1.** Either suppress background recomposition when the release cause is suspension, while keeping the legacy 104/110 reset, or update the recovery contract and hard-lock reference to say a running GUI recomposes ordinary intent.
3. **Reorder `TAVSAppMain.main` (L2)** so legacy headless flags are handled before the isolated-launch environment check.
4. **Clean up L3 and L4.** Rename or document the reconcile-semantics APIs, remove or mark the ignored `visual`/`untilText` parameters, share one time formatter for lock title and status, and correct stale test comments.
5. **Optional (L5).** Publish the requested projection so the re-enable caption states whether a rule will apply immediately.
===END_RECOMMENDATIONS===

===PR_READINESS===
Status: NEEDS WORK

Blockers:
- **Code:** None strictly blocking. M1 should be addressed or explicitly accepted before sign-off.
- **Empirical acceptance, still unverified:**
  - native menu/relaunch/suspension UI
  - native pause and lock salience
  - recovery byte ordering against the GUI reconcile
  - launch-time Automation prompt behavior

Scope: Pass C partition of the complete branch review (scheduler, broadcaster, menu, entry point, mute state and their tests). Appropriate for its role.

Commit quality: unknown; commit history was not supplied for this pass.
===END_PR_READINESS===

===SUGGESTED_PR_DESCRIPTION===
Not ready for a final PR description from this partition. Remaining work:

- **M1:** surface or log scheduler-path partial failures, and decide on heartbeat retry.
- **L1:** decide and document whether a running GUI recomposes ordinary background after emergency recovery.
- **L2:** move the isolated-launch environment check after the legacy headless flags.
- **L3, L4:** remove the replay-era names, dead parameters and stale comments.
- **Native acceptance:** complete and record the menu, relaunch, suspension icon, and pause/lock salience cases on dedicated Ghostty surfaces.
===END_SUGGESTED_PR_DESCRIPTION===

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-branch
Model requested: opus
Effort requested: high
Model observed: unknown
Effort observed: unknown
Input scope: target 71e0f60, base e113fb8, Pass C. Primary targets: Broadcaster.swift, MenuContent.swift, MuteState.swift, PauseVisual.swift, Scheduler.swift, TAVSApp.swift, BroadcasterTests.swift, Mocks/MockBroadcaster.swift, MuteStateTests.swift, SchedulerLockTests.swift, SchedulerTests.swift. Dependency context read: visual-recovery.swift, visual-restriction-policy.swift, visual-restrictions-state.swift, terminal-visual-state.swift, ProcessRunner.swift, focus-controller.swift, sessions-model.swift, sessions-view.swift, attention-state.swift, ghostty-catalog.swift, managed-output-entry.swift, organizer-intake.swift, process-identity.swift, terminal-render(er).swift, LockState.swift, ScheduleStore.swift, FileWatcher.swift, TimerScheduler.swift, organizer-state.sh, visual-restrictions-state.sh, mute-gate.sh, terminal-osc-sequences.sh, MockProcessRunner/MockTimerScheduler; SPEC.md, PLAN.md and API_REFERENCE.md as requirements
Focus: correctness, security, maintainability, test_coverage, performance
Limitations: tool-free external review; no executed tests/builds/native/UI; reported execution evidence is not independently rerun; this is a complete partition, not aggregate coverage
===END_REVIEW_META===
