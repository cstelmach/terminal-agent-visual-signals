## Original actual Claude reports

All eight provider outputs follow verbatim, including their NOTE banners and scope limitations.

## part01: native catalogue, UI, priorities and startup

> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

Report file: not written. This session has no tools, so the full report is inline below. Intended path: `/tmp/claude-review-code-terminal-agent-visual-signals-main-20261014-p1-native-ui.md`. The parent should persist it.

- Verdict: **CONCERN**, 6.8/10. Correctness 7, Security 8, Maintainability 6, Test Coverage 6, Performance 6.
- **R1 (IMPORTANT, performance):** Manual focus, and Automatic focus with cues, launches two Ghostty CLI processes and rewrites OSC 11 to every dimmed terminal on each 2 s poll.
- **R2 (IMPORTANT, correctness):** Focus leases from before a recovery can never clear. Later cleanup then reports a false "could not be cleared" error.
- **R3 (MINOR):** A catalogue-driven change to the selection restarts previews without any user action.
- **R4 (MINOR):** Supplied tests do not exercise Go To acknowledgement through SessionsModel.
- Native catalogue, navigation, Spaces, Automation and readability remain unverified. Route: claude-cli-explicit.

> NOTE: real native Claude CLI under Hub controls, chosen by caller; it is not an automatic fallback or evidence that applied model/effort were observed.

# Claude Review Report

**Mode**: code-session
**Date**: 2026-10-14
**Focus**: all

---

===DIMENSION_RATIONALE===
Using defaults: correctness, security, maintainability, test coverage, performance. This partition is native UI plus pure policy (catalogue, model, reducer, focus controller), and the five defaults cover it.

Accessibility was not added as a scored dimension. The view supplies accessibility labels and nothing in it is clearly deficient.

Connected partition-2 sources (visual-recovery, terminal-visual-state, ProcessRunner) were read as callers and callees. They were not re-scored.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
Overall grade: 6.8/10
Risk level: Medium

## Metadata
Partition 1 (01-native-ui) at commit 7ecfba2, reviewed from the supplied source, tests and connected callers. The review was tool-free and static only.

## Rubric Scores
Correctness 7, Security 8, Maintainability 6, Test Coverage 6, Performance 6.

## Verdict
CONCERN. Every dimension scores at least 5, and three score below 7.

## Summary
Identity, priority and cue logic hold up against SPEC D09/D10/D13-D15:
- Surface IDs are bound to the Ghostty process generation.
- Priorities are pruned only on a successful catalogue.
- Go To snapshots cues before dispatch.
- The reducer creates cues only from verified, eligible High observations.

Two substantiated defects remain:
- The focus heartbeat path does real work on every 2 s poll (subprocesses plus a device repaint). See R1.
- Leases from before a recovery stay pinned to an obsolete revision and produce a false cleanup-failure message. See R2.

Native behavior is unverified, including frontmost confirmation after `focus`, Spaces and launch window behavior.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

## Hypothesis falsification (performed before scoring)

**H1: A cue arriving during Go To could be acknowledged.**
Dismissed.
- `sessions-model.swift:254` captures `cueSnapshot` before `navigate`.
- `:260` acknowledges only that captured set, and only on success.
- `attention-state.swift:27-30` subtracts exactly the captured set, so later occurrences survive.
- A failure (`:259`) acknowledges nothing.

**H2: Unchanged-poll coalescing could swallow changed cues or bindings.**
Dismissed.
- `focus-controller.swift:257-263` coalesces only while an update is in flight. It compares ids, TTY, foreground PID and mapping.
- `:265` bumps the version whenever `priorCues != attentionCues`.
- `:268-270` always queues `manualPending`, so a follow-up run happens.

**H3: Unknown or unverified observations could create cues or dimming.**
Dismissed.
- `attention-state.swift:37-38` requires `verifiedAgent` and provider claude/codex.
- `:53-54` requires `attentionEligible`, High priority and `observedAt > enabledAt`.
- `sessions-model.swift:245` marks stale coverage ineligible.
- `focus-controller.swift:326-330` and `:454-474` require at least one source that validates as `.valid` before any automatic paint.

**H4: A priority could transfer through TTY or directory reuse.**
Dismissed.
- `ghostty-catalog.swift:4-7`: the key is the Ghostty process generation plus the native terminal ID.
- The TTY is not part of the key.
- `sessions-model.swift:235` prunes closed IDs only after a successful catalogue.

**H5: Recovery could leave focus leases that never clear.**
Confirmed as R2.

## Unresolved hypotheses (not findings; need native or runtime evidence)

**U1: Go To may report a false focus failure.**
- `ghostty-catalog.swift:259-267` reads `frontmost` immediately after `target.focus`.
- macOS activation is asynchronous. A first Go To from the activated TAVS window could return `focusUnconfirmed` even though navigation happened, so no acknowledgement would occur.
- Needs native observation.

**U2: The Sessions window may open at launch.**
- SwiftUI on macOS 13 may auto-open the `Window("Sessions")` scene in `TAVSApp.swift:123`.
- If it does, `onAppear` starts native polling at login, which could raise an Automation prompt.
- Startup and Dock behavior are unverified.

**U3: The catalogue script may exceed its timeout on larger catalogues.**
- The script issues several AppleEvents per terminal (`ghostty-catalog.swift:227-232`), including one `objectWithID` lookup per row.
- With many surfaces, the 2 s bound could trip intermittently and make the catalogue unavailable.
- Not measured.

**U4: Dimming may persist after sources become unverifiable.**
- When cue sources are `.unavailable` rather than vanished (`focus-controller.swift:326-330`), the update throws before retiring leases.
- An existing dim stays painted until heartbeat expiry or recovery.
- This is arguably the SPEC's "existing valid effect records remain recoverable", so it is not counted as a defect.

### CRITICAL
None.

### IMPORTANT

**R1. `focus-controller.swift:351` and `:376-406`, with `TAVSApp.swift:215-219` and `visual-recovery.swift:273-293`, `:389-416`: focus heartbeat repeats configuration subprocesses and a device repaint on every poll.**
- **Situation:** Manual focus is active, or Automatic has at least one cue. `SessionsModel` polls every 2 s (`sessions-model.swift:152`).
- **Behavior:**
  - Each `acceptCatalogue` calls `updateManual`.
  - `updateManual` calls `colors(instance)` on every run.
  - With a configuration file present, `TerminalRenderer.configuredColors` runs `ghostty +validate-config` and then `+show-config`.
  - Each outside target then gets `.focus` with no unchanged short-circuit. `refreshEffectUnlocked` excludes `.focus` (`terminal-visual-state.swift:284`), so renewal goes through `saveEffectUnlocked` plus the composition tail. That tail returns OSC 11 bytes.
  - Result: two processes and N terminal writes every 2 s, indefinitely.
- **Impact:**
  - Steady CPU and process churn.
  - OSC writes injected into busy PTYs at 0.5 Hz, which raises the chance of interleaving with a program's own escape sequences. This touches the existing ordinary-signaling compatibility promise.
  - Heartbeat freshness (six-second coverage) needs only metadata renewal.
- **Smallest remedy:**
  - Cache `Colors` per Ghostty generation, keyed on configuration file mtime and size, and re-resolve only on change.
  - In the `.focus` prepare branch, when the existing record already has the same effectID, background and colors, renew the heartbeat metadata and return `nil` instead of repainting.
- **Criterion:** "actual performance risks"; preparation heartbeat and six-second coverage; preserve shell compatibility.
- **Discriminating test:**
  - Use a `MockProcessRunner` that counts `runBounded` calls and `writeManagedToDevice` payloads.
  - Run Manual focus over two identical `acceptCatalogue` polls.
  - Assert one configuration resolution and one OSC 11 write, with the heartbeat advanced in the effect record.
  - The current code yields 4 or 2 and 2 respectively, so the test discriminates.

**R2. `focus-controller.swift:171-183`, `:532-553`, `:555-578` with `visual-recovery.swift:295-302`: focus leases from before a recovery can never be retired, causing a false cleanup error.**
- **Situation:** Focus has painted at least one target (`mayHavePainted == true`). The user then runs Restore Visibility, or the recovery path calls `cancelForRecovery`. `cancelForRecovery` marks leases `retiring` but leaves them in `focusLeases`.
- **Behavior:**
  - The recovery rewrites the marker atomically, giving it a new inode.
  - A later `clearManual` call comes from Focus Off, Focus Selected, or an in-flight update completing. It runs `.clearFocus`. `restoreBackground` returns true.
  - The guard at `visual-recovery.swift:300-302` then fails `restrictions.matches(lease.revision)`, so prepare returns `nil` and the item is `.unaffected`.
  - In `clearFocusLease`, `restored == false` and `unpainted == false` because `mayHavePainted` is true. The lease is never removed.
  - `focusCleanupError` becomes "Some focus effects could not be cleared. Restore Visibility is available." and stays for every lease the user does not re-focus.
- **Impact:**
  - A false partial-failure report after a recovery that already reset those targets with OSC 104/110/111.
  - The message points to the action the user just took.
  - Leases leak for the process lifetime.
- **Smallest remedy:**
  - On a successful recovery report, mark the canceled leases resolved and unpainted.
  - Alternatively, in `clearFocusLease`, treat a revision mismatch caused by a newer marker as recovery-owned and remove the lease.
- **Criterion:** partial-failure honesty; "recovery itself clears current previews"; Focus Off always reachable without a false error.
- **Discriminating test:**
  - Create a FocusController with a mock writer that records one successful focus paint.
  - Call `cancelForRecovery()`, rewrite the marker, then call `focusOff()`.
  - Assert `focusCleanupError == nil` and that the lease map is empty.
  - The current code leaves the error set.

### MINOR

**R3. `sessions-model.swift:11-16` with `:234`: catalogue pruning re-triggers a preview without user action.**
- **Trigger:** Rows A and B are selected and their preview has long expired. B closes.
- **Behavior:** On the next successful refresh, `selection.formIntersection` changes `selection`. `didSet` then calls `focus.preview` for A, and A flashes again.
- **Criterion:** G3/D08, selection-driven highlighting.
- **Remedy:** Suppress the preview in `didSet` while `acceptCatalogue` prunes, using a flag. Alternatively, call `clearPreview` only when the pruned rows were part of an active preview.
- **Test:** Select A and B, expire the preview, refresh with only A, and assert no new preview run. The current code starts one.

**R4. `sessions-model-tests.swift:56-68` and `:198-204`: Go To acknowledgement is not covered by the supplied tests.**
- The supplied SessionsModel tests count `navigate` calls only.
- Untested through the model:
  - cue snapshot before dispatch,
  - a cue arriving during in-flight navigation surviving,
  - failure acknowledging nothing.
- `attention-state-tests.swift` and `focus-controller-tests.swift` are named in PLAN but were not in this input. They may cover this. It is unverified here.
- **Remedy:** Add a model test with a deferred `navigate` closure. Inject a second cue via `focus.acceptCatalogue` before completing with success, then with failure. Assert the remaining `cueCount` in each case.

===END_ISSUES===

---

===SCORE_CARD===

## Findings
2 important, 2 minor, 0 critical. 4 unresolved hypotheses are kept separate.

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | 7/10 | Identity, priority and cue semantics hold. Pre-recovery lease cleanup reports false failure (R2). |
| Security | 8/10 | Native request carries IDs as JSON data, command allowlist is focus-only, test roots are confined to tmp. No injection path found. |
| Maintainability | 6/10 | FocusController is a dense lock/version/lease protocol in one ~600-line class, hard to reason about (R2 arises from it). |
| Test Coverage | 6/10 | Strong catalogue and script tests. Go To acknowledgement and coalescing are untested in the supplied tests. Reducer and controller tests were not supplied. |
| Performance | 6/10 | Per-poll configuration subprocesses and OSC 11 repaint while focus is active (R1). |
| **Overall** | **6.8/10** | Mechanical verdict: CONCERN |

===END_SCORE_CARD===

---

===RECOMMENDATIONS===

1. **Priority 1:** Make the focus heartbeat metadata-only when nothing changed, and cache resolved Ghostty colors per generation and configuration mtime (R1).
2. **Priority 2:** Resolve leases canceled by recovery so post-recovery Focus Off and Focus Selected do not report false failures (R2).
3. **Priority 3:** Add the discriminating model tests for Go To acknowledgement (R4) and for catalogue-pruning previews (R3). Then obtain native observation for U1 (frontmost race) and U2 (launch window).

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
Input scope: Partition 1 (01-native-ui) at commit 7ecfba2.
- Source and specs: SPEC.md, PLAN.md, Package.swift, ghostty-catalog, sessions-model, sessions-view, organizer-intake, TAVSApp, MenuContent, PreferencesView, LoginItemManager, UserConfStore, process-identity, attention-state, focus-controller, Info.plist.
- Connected callers and callees read for context: ProcessRunner, terminal-visual-state, visual-restrictions-state/policy, visual-recovery, managed-output-entry, Scheduler, Broadcaster, renderer and render, PauseVisual, Clock, TimerScheduler, MuteState, LockState, ScheduleStore, FileWatcher, TAVSLog, ChallengeGate/Verifier.
- Supplied tests: ghostty-catalog, sessions-model, organizer-intake, LoginItemManager, and the mocks.
- Completion: full covers this supplied subscope only, not whole-goal acceptance.
Focus: all default
Limitations:
- Tool-free single turn. The report file could not be written to /tmp; this inline text is the report.
- Static review only. No build, tests, app launch, Ghostty control or real-home reads.
- attention-state-tests and focus-controller-tests were named in PLAN but not supplied, so they were not reviewed.
- Native catalogue, navigation, frontmost confirmation, Spaces, Automation/TCC, readability, launch window and Dock behavior are unverified.
- Linux runtime and kernel tests are unverified.
- Historical first-paint/EPERM and fresh-render timeout causes are not established. Passing tests are not treated as native acceptance.
===END_REVIEW_META===


## part02: attention reducer and focus controller

> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# Claude Review Report

> [!NOTE]
> EXPLICIT NATIVE SELECTION: the caller chose a real native Claude CLI under Hub controls. This is not an automatic fallback. It is also not evidence that the requested model or effort was applied.

**Report path:** not written. This session was tool-free, so no file under /tmp could be created. The complete report follows inline, and the caller must persist it. No original provider output or technical failure evidence exists beyond this reply.

**Mode**: code-session
**Date**: 2026-10-14
**Focus**: all

---

===DIMENSION_RATIONALE===
I used the default five code dimensions: correctness, security, maintainability, test coverage and performance. The artifact is a stateful reducer plus a concurrent focus controller that does bounded device I/O, so those five fit without adaptation. Accessibility and UI dimensions were not added because the SwiftUI view files were not in this subscope's input.

The subscope is Partition 1 / 02-attention-focus, reviewed at commit 7ecfba2. I reviewed every supplied file:

- **Reducer and controller:** `attention-state.swift` and `focus-controller.swift`.
- **Model:** `sessions-model.swift`.
- **Connected callees:**
  - `ghostty-catalog.swift`, `terminal-visual-state.swift`
  - `terminal-renderer.swift`, `terminal-render.swift`, `visual-recovery.swift`
  - `ProcessRunner.swift`, `process-identity.swift`, `organizer-intake.swift`
  - `visual-restriction-policy.swift`, `visual-restrictions-state.swift`
  - `Clock`, `TimerScheduler`, `UserConfStore`, `PauseVisual`, `MuteState`, `LockState`, `managed-output-entry.swift`
- **Tests:** `focus-controller-tests.swift`, `attention-state-tests.swift` and the five mocks.
- **Specification:** SPEC.md and PLAN.md.

Startup/Dock files (TAVSApp.swift, MenuContent.swift, sessions-view.swift) were not supplied to this subscope. I could not review them here.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
### Summary
Overall grade: 6.6/10
Risk level: Medium

The occurrence reducer is small, deterministic and closely matches D13-D15. It covers baseline on enable, per-delivery Claude completion keys, Codex turn-ID dedup, permission-episode coalescing, no replay on downgrade or re-promotion, and no cue from unverified or unsupported records. The SessionsModel Go To path snapshots cues before dispatch and acknowledges only that snapshot on verified success.

The focus controller enforces source revalidation, revision pinning and lease liveness inside the serialized write. It has one concrete lifecycle defect: after an in-GUI recovery, focus leases left retiring by `cancelForRecovery` can never be retired. This produces a persistent false cleanup error and repeated futile managed writes. Two lesser issues also exist:

- partial-mapping status is misreported as "unavailable";
- every change to the High set flashes all dimmed surfaces.

### Hypothesis falsification
1. **H1: An acknowledged or old occurrence can be replayed by polling or by High re-promotion.** Dismissed.
   - `attention-state.swift:44-46` skips records from the same actor unless both the delivery and the time advance.
   - Completion keys enter `book.completions` even when `canCreate` is false (`:68`).
   - Books survive priority changes, because `:34` filters only on coverage presence.
   - Tests at `attention-state-tests.swift:106-116` and `:118-131` agree.
2. **H2: Unknown, unverified or uncorrelated observations can cause dimming.** Dismissed.
   - The reducer requires `verifiedAgent`, a provider of claude or codex, a producer and a device (`:37-39`), plus `sample.attentionEligible` (`:54`).
   - Before painting, `focus-controller.swift:326-330` and `:389-393` revalidate the cue's producer, TTY and native binding via `validateAttentionSource` (`terminal-visual-state.swift:176-211`).
   - An unavailable source returns false, and the write then yields nil.
3. **H3: Go To can acknowledge cues that arrived during navigation, or acknowledge on failure.** Dismissed.
   - `sessions-model.swift:254` snapshots the cues.
   - `:259-260` acknowledges only on `.success`.
   - `AttentionState.acknowledge` subtracts only the captured set (`attention-state.swift:27-30`).
   - The test at `focus-controller-tests.swift:158-186` covers this.
4. **H4: Leases marked retiring by recovery are later cleaned up correctly.** Confirmed as a defect; see R1.
5. **H5: Unchanged-poll coalescing can let a stale catalogue paint.** Dismissed for identity.
   - `sameInputs` (`focus-controller.swift:257-263`) compares id, tty, foregroundPID and mappingIssue.
   - Any change in cues bumps the version (`:265`).
   - Each write still revalidates its target inside the device lock (`visual-recovery.swift:214`).
   - The 6-second freshness bound (`:317`, `:388`, `:492`) is renewed only by accepted catalogues.

### Unresolved hypotheses (not findings)
- **U1: Permission episodes with prompt only.** With only Notification(permission_prompt) delivery and no PermissionRequest hook, `permissionSeen` is never reset (`attention-state.swift:55-67`). After the first episode, later prompt-only episodes for the same producer never cue. This is intentional and test-encoded (`attention-state-tests.swift:70-79`), and consistent with "ambiguous repeats are ineligible". It is still an unlabelled coverage limit (G8).
- **U2: Transient catalogue omission.** If a native enumeration transiently omitted a surface, `books` would drop at `:34`. Re-adding the same latest completion could then recreate an acknowledged cue (`:50-53`, `:68-72`). I found no source evidence that Ghostty enumeration omits live surfaces.
- **U3: Duplicate hook registration.** If hooks were registered twice (marketplace plus cache), each Stop would get two UUID deliveries. That could rearm a cue after acknowledgement. This is deployment-dependent and not established from the supplied source.

### Verdict
CONCERN, applied mechanically: all scores are at least 5, and some are below 7.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

### Findings

### CRITICAL
None substantiated.

### IMPORTANT

1. **R1: Leases retired by recovery are never resolved, causing a persistent false cleanup error and repeated futile writes.**
   - **Location:**
     - `focus-controller.swift:171-183` (`cancelForRecovery`)
     - `focus-controller.swift:532-553` (`clearFocusLease`)
     - `focus-controller.swift:555-584` (`clearManual`)
     - `visual-recovery.swift:295-302` (`clearFocus` guard)
   - **Trigger:** The user runs Manual or Automatic focus, so an outside target T gets painted and its lease has `mayHavePainted=true`. Then:
     1. The user clicks Restore Visibility. `cancelForRecovery` marks the lease `retiring` but leaves it in `focusLeases`, and recovery rewrites the marker inode.
     2. The user clicks Re-enable.
     3. The user clicks Focus Selected with a set in which T is now emphasized or absent.
   - **Behavior:**
     1. `focusSelected` calls `focusOff`, which calls `retireFocus` and then `clearManual`, which calls `clearFocusLease(old)`.
     2. `beforeOpen` cancels the record and sets `ownershipResolved=true`.
     3. In `prepare`, `restore()` returns true. Then `restrictions.matches(lease.revision)` is false because the marker was replaced, so the write returns nil and the status is `.unaffected`.
     4. `restored` is false, and `unpainted` is false because `mayHavePainted` is true. The lease is therefore never removed (`:546-549`).
     5. Each later `clearManual`, including the one after every `updateManual` completion (`:443`), retries the write, and `focusCleanupError` stays "Some focus effects could not be cleared."
     6. Clicking Restore Visibility again does not clear the error.
   - **Impact:**
     - The cleanup report is dishonest after a recovery that succeeded (G6/G8 partial-failure honesty).
     - Every 2 s poll performs needless open/flock/effect enumeration on a TTY that focus does not own.
     - The lease persists until T vanishes or re-enters the outside set.
   - **Smallest remedy:** In `clearFocusLease`, treat `ownershipResolved && (try? restrictions.matches(lease.revision, deadline:)) != true` as retired, since emergency recovery owns that restoration, and remove the lease. Alternatively, have `cancelForRecovery` remove resolved leases once recovery reports.
   - **Criterion:** SPEC "Report restored ... failed/unverified targets separately", Phase 2 "Focus Off clears selective styling", and no uncancellable effects.
   - **Discriminating test:**
     1. Run `focusSelected([a],[a,b])` and await it so b is painted.
     2. Call `cancelForRecovery()`, then `recovery.recover()`, then `restrictions.write(suspended:false)`.
     3. Call `focusSelected([b],[a,b])` and await `$focusCleanupError` settling.
     4. Assert `focusCleanupError == nil`.
     5. Assert that no further managed-write calls hit b's TTY across two `acceptCatalogue` ticks, using MockProcessRunner `managedCallLog`.

     This fails today and passes after the fix. No existing test combines recovery, resume and refocus on one controller. `testRecoveryEndsManualWithoutPaintingAndRestartStartsOff` (`:984-996`) uses a new controller.

### MINOR

1. **R2: A partially mapped outside set is reported as "unavailable".**
   - **Location:** `focus-controller.swift:416`, `:426-433`.
   - **Trigger:** One outside row has a `mappingIssue` or no capturable binding, and the other outside targets paint successfully.
   - **Behavior:** `renewed` requires `targets.count == outside.count`, so it is false. With `failures == 0`, the status becomes "Manual/Automatic unavailable: background effects were not renewed". The "N of M outside mapped" text at `:436` is reachable only when every row maps.
   - **Impact:** The UI states that focus is unavailable while it actually dims most surfaces. This understates the visible state (G8).
   - **Remedy:** Compute `renewed` over the mapped targets only, and keep the mapped/count text for partial mapping.
   - **Test:** Use three rows with one outside `missingTTY`. Assert that the status contains "1 of 2 outside mapped" and that the healthy PTY is painted.

2. **R3: Any High-set change clears and repaints every dimmed surface.**
   - **Location:** `focus-controller.swift:242` together with `:296-302`.
   - **Trigger:** In Automatic mode with cues, a priority edit or a High surface opening or closing changes `ids`.
   - **Behavior:** `retireFocus()` retires all leases, and `clearManual` emits OSC 111 to every outside target. The new Run then repaints them with new effect IDs.
   - **Impact:** Surfaces that stay outside visibly flash, and device writes double.
   - **Remedy:** Retire only leases whose targets entered the emphasized set.
   - **Test:** Extend `testAutomaticHighPromotionClearsThatTargetsPreviousDimming` (`:250-264`) to assert that b's bytes contain no `]111` and that b's focus `effectID` is unchanged. The current test reads b without asserting either.

===END_ISSUES===

---

===SCORE_CARD===

### Rubric Scores

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | 6/10 | Reducer is sound. Leases retired by recovery cannot resolve (R1), and partial-mapping status is wrong (R2). |
| Security | 8/10 | Native allowlist, no input or navigation from focus, revision pinning and in-lock policy checks. No privacy leak in this scope. |
| Maintainability | 5/10 | `updateManual` is about 140 lines of nested closures. State is held in tuples, with many lock-guarded flags. |
| Test Coverage | 7/10 | Broad race and occurrence tests. The recovery, resume, refocus lifecycle and partial-mapping status are untested. |
| Performance | 7/10 | Bounded writes. Futile retries (R1) and full repaint on High changes (R3). |
| **Overall** | **6.6/10** | Weighted 25/25/20/15/15. Verdict: CONCERN. |

===END_SCORE_CARD===

---

===RECOMMENDATIONS===

1. **Priority 1:** Fix R1. Retire leases whose ownership is resolved and whose revision is now stale, then add the recovery, resume, refocus discriminating test.
2. **Priority 2:** Fix the `renewed` calculation so a partially mapped outside set reports accurate counts (R2), and limit lease retirement on High changes to targets that newly became emphasized (R3).
3. **Priority 3:** Surface the prompt-only permission coverage limit (U1) in row coverage text. Split `updateManual` into named preparation, lease and status helpers to reduce lock-reasoning risk.

Native catalogue, navigation, readability, Spaces and visible-paint acceptance remain unverified and are not established by this review.

===END_RECOMMENDATIONS===

---

===REVIEW_META===
Execution path: claude-cli-explicit
### Metadata
Completion: full
Review mode: code-session
Model requested: opus
Model observed: unknown
Effort requested: unspecified
Effort observed: unknown
NOTE: real native Claude CLI under Hub controls, chosen by caller. It is not an automatic fallback, and it is not evidence that the applied model or effort was observed.
Input scope:
- Partition 1, subscope 02-attention-focus, at commit 7ecfba2.
- All supplied files: SPEC.md, PLAN.md, Package.swift.
- Sources: focus-controller, attention-state, ghostty-catalog, sessions-model, terminal-visual-state, terminal-renderer, terminal-render, visual-recovery, ProcessRunner, process-identity, organizer-intake, visual-restriction-policy, visual-restrictions-state, Clock, TimerScheduler, UserConfStore, PauseVisual, MuteState, LockState, managed-output-entry.
- Tests: focus-controller-tests, attention-state-tests and five mocks.
- "Full" refers to this supplied subscope only, not whole-goal acceptance.
Focus: all default
Limitations:
- **Not supplied to this subscope:** startup/Dock sources (TAVSApp.swift, MenuContent.swift, sessions-view.swift).
- **Tool-free:** no build, no tests, no runtime, and the /tmp report file could not be written.
- **Unverified runtime acceptance:**
  - native Ghostty catalogue, navigation, Spaces and readability;
  - visible rendering and permissions;
  - Linux runtime;
  - historical first-paint/EPERM and fresh-render timeout causes.
- **Evidence basis:** passing tests and documentation were not treated as physical acceptance.
===END_REVIEW_META===


## part03: visual state, renderer and bounded writer

> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

Report path: none. This session had no tools, so no file was written under /tmp. The complete report follows inline for the parent to save.

- Verdict: **CONCERN**, 6.9/10, risk Medium (Correctness 7, Security 7, Maintainability 6, Test Coverage 7, Performance 8).
- **R1 (IMPORTANT):** one unreadable per-target record (corrupt, newer schema, or future-dated after a backward clock step) makes emergency recovery fail for a live, validated shell.
- **R2 (MINOR):** the same strict reads have no repair path for per-target records, so ordinary background signaling on that shell lifetime stops.
- **R3, R4 (MINOR):** runtime-root ownership is never checked, and recovery reports collapse errno, busy and timeout into one generic reason.
- Native, visible, Space, readability and Linux acceptance are not established by this review.

# Claude Review Report

**Mode**: code-session
**Date**: 2026-10-14
**Focus**: all

> NOTE: Real native Claude CLI under Hub controls, chosen by the caller. This is not an automatic fallback and is not evidence that the applied model or effort was observed.

---

===DIMENSION_RATIONALE===
### Metadata
- Repository: terminal-agent-visual-signals, commit 7ecfba2, branch main, clean checkout.
- Partition: 1. Subscope: 03-visual-writer.
- The working-tree diff is empty, as expected for an explicit code-files target. The current complete implementation was reviewed, not recent diffs.

Using the five default code dimensions (Correctness, Security, Maintainability, Test Coverage, Performance). They fit this artifact, which is privileged terminal-output plumbing:

- **Correctness and security** cover:
  - the bounded device writer and admission lanes;
  - the record store and lifetime validation;
  - the policy reader and the recovery fanout.
- **Performance** applies because every hook write must stay inside the unchanged 100 ms caller deadline.
- Accessibility (contrast) is assessed under Correctness, through renderer contrast bounds. Live readability cannot be assessed here.

Default weights: 25 / 25 / 20 / 15 / 15.
===END_DIMENSION_RATIONALE===

---

===EXECUTIVE_SUMMARY===
Overall grade: 6.9/10
Risk level: Medium

### Summary
The writer core matches the SPEC's ordering contract:
- `SystemProcessRunner.writeManagedToDevice` opens the device before taking the advisory lock (ProcessRunner.swift:168 vs 182-203).
- It re-checks the original deadline before every state mutation and before writing.
- Admission lanes keep one emergency attempt independent of a wedged ordinary open.
- Fresh policy is recomputed inside the serialized `prepare` (visual-recovery.swift:315). Ownership leases require a live controller generation and the 2 s preview / 6 s focus bounds (terminal-visual-state.swift:214-220).

The main defect is that recovery is less robust than the SPEC promises:
- `.emergencyReset` loads and strictly decodes all per-target records before emitting OSC 104/110/111 (visual-recovery.swift:233-243).
- One unreadable record therefore makes recovery fail for a live shell whose owner and descriptor already validated.
- Per-target records (effect, bound-intent, target) never self-repair. The latest observation and intent records do (terminal-visual-state.swift:1067-1083).

Security and privacy boundaries on payloads are strong:
- Strict key allowlists.
- Sentinel-free errors.
- `O_NOFOLLOW` and `lstat` checks.

Runtime-root ownership, however, is never verified.

### Verdict
CONCERN. All dimensions score at least 5, and Maintainability scores 6.

Native catalogue, navigation, visibility, Spaces, readability and permission acceptance remain unverified. Linux runtime tests remain unverified. Passing Swift tests do not establish any of these, nor the historical first-paint/EPERM or fresh-render timeout causes.
===END_EXECUTIVE_SUMMARY===

---

===ISSUES===

### Hypothesis falsification
- **H1: a wedged device open holds per-TTY serialization and blocks recovery. Dismissed.**
  - The device open happens at ProcessRunner.swift:168, before the lock open and `flock` at 182-203.
  - `beforeOpen` publication releases its own `withLock` before the writer locks (terminal-visual-state.swift:1017; visual-recovery.swift:160-170).
  - The emergency lane is independent (ProcessRunner.swift:245-249).
  - Covered by process-runner-tests.swift:130, 414 and 527.
- **H2: a worker that finishes after the caller's 100 ms timeout can still repaint. Dismissed.**
  - Deadline checks precede `beforeOpen`, admission, open, lock, `prepare` and every write chunk (ProcessRunner.swift:163, 165, 267, 275, 194, 205, 207, 288).
  - A late open closes its descriptor (276).
  - Small residual window: a write can begin just before the deadline and complete after it.
  - Covered by tests at 203, 243 and 606.
- **H3: emergency recovery depends only on target validity, not on unrelated record state. Confirmed false, see R1.**
  - visual-recovery.swift:233 and 238 run `cacheTargetUnlocked` and `effectsUnlocked` before the `.emergencyReset` branch at 239.
  - Both throw `invalidRecord` or `targetUnavailable` on any unreadable record or uncertain alias.
- **H4: ordinary hooks can defer to dead or stale controller ownership. Dismissed.**
  - The lease requires the current controller generation and the age bound (terminal-visual-state.swift:214-220).
  - Non-lease and expired effects are cancelled on the next ordinary write (visual-recovery.swift:404-407).
- **H5: previews are blocked during suspension, or silently succeed under a pause. Dismissed.**
  - `policy.current` returns nil while suspended (visual-restriction-policy.swift:29-31, 48-50), so previews proceed (visual-recovery.swift:253-254).
  - Under a pause, `previewBlocked` maps to an explicit failure reason (574-576).

### Findings

### CRITICAL
None substantiated.

### IMPORTANT

1. **R1 [src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:233-243; terminal-visual-state.swift:237-250, 303-347, 511-524]: Emergency reset fails for a live validated target when any per-target record is unreadable**
   - **Trigger.** Any one of these on the physical target:
     - an `effect.json`, `preview.json` or `focus.json` with an unknown key (for example a newer schema from another installed copy; strict decoder at terminal-visual-state.swift:1215);
     - such a record with `heartbeatAt` later than the reading process's wall clock, for example after a backward NTP or wake correction (validated at 515);
     - an alias `target.json` whose native application lookup is transiently unavailable (338).
   - **Behavior.**
     - `prepare` calls `cacheTargetUnlocked`, then `effectsUnlocked`, which calls `equivalentBindingsUnlocked` and `currentEffectUnlocked`. Any of these throws before the `.emergencyReset` branch.
     - Fanout maps the error to "Managed restoration unavailable." (583).
     - No OSC 104/110/111 bytes are sent, even though the owner generation and descriptor already validated at line 214.
   - **Impact.**
     - A restriction or dim stays painted on a live shell and `tavs recover` exits nonzero.
     - The failure is persistent until the record is removed, the owner exits, or the machine reboots. The clock-skew variant heals itself once wall time passes the stored heartbeat.
     - This contradicts SPEC G6 ("Recovery remains available during every visual restriction"). SPEC 257-260 treats only binding or owner uncertainty as a failure, not record decoding.
   - **Smallest remedy.**
     - In the `.emergencyReset` path, move the branch ahead of `cacheTargetUnlocked` and `effectsUnlocked`.
     - Cancel decodable effects best-effort, and quarantine or unlink unreadable per-target effect files under the held lock.
     - Always return `Self.reset` once `requireValid(target, descriptor:)` passes.
     - Optionally report the quarantined record as a separate item.
   - **Criterion.** SPEC G6, the Recovery contract (233-261), and Phase 1 acceptance: "healthy targets restore despite hung/open-busy ones".
   - **Discriminating test.**
     - Setup: owned PTY plus cached plain binding. Write an effect file containing an extra `"payload"` key, mirroring terminal-visual-state-tests.swift:846-852. Alternatively save an effect at heartbeat 1000 and set `VirtualClock` to 999.
     - Action: call `recovery.write(.emergencyReset, to:)`.
     - On current code it throws and the PTY master receives no bytes. After the fix it returns true and the master reads exactly `ESC]104 BEL ESC]110 BEL ESC]111 BEL`.
     - The test fails before the change and passes after it, so it discriminates.

### MINOR

1. **R2 [terminal-visual-state.swift:354, 396, 401-412, 909-924; visual-recovery.swift:312, 392]: Unreadable per-target bound intent stops all ordinary, preview and focus writes for that lifetime, with no repair path**
   - **Trigger.** `bound-intent.json` fails to decode or validate. Causes include an unknown key, or `updatedAt` later than now after a backward clock step.
   - **Behavior.**
     - `ordinaryBackgroundUnlocked` throws, and so does `bindOrdinaryIntentUnlocked` through `boundIntent` at 396.
     - Every `--managed-background` or `--managed-render` with a background exits 1. The same applies to preview, focus and reconcile.
     - The latest intent and observation records self-repair through `recoverInvalid` (1067-1083). Per-target records do not.
     - The test at terminal-visual-state-tests.swift:1236 asserts the throw but no repair.
   - **Impact.** Ordinary background signaling on that shell stops. The SPEC forbids raw fallback, and the caller requires compatibility of existing ordinary signaling. The trigger is rare: writes are atomic, so it needs version skew or clock skew.
   - **Smallest remedy.** Inside a fresh non-synthetic publication (`publishIntent(to:)` and `bindOrdinaryIntentUnlocked`), replace an existing regular-file bound intent that cannot be read, mirroring `readLatest(recoverInvalid:)`. Readers stay fail-closed.
   - **Discriminating test.** Corrupt `bound-intent.json`, then publish a fresh non-synthetic intent to the target. The current code throws. The fixed code succeeds and `ordinaryBackgroundUnlocked` returns the new color.

2. **R3 [terminal-visual-state.swift:976-1000, 1026-1044, 551-583; ProcessRunner.swift:171-192; organizer-intake.swift:138]: Runtime root and lock ownership are not verified**
   - **Trigger.** On a multi-user Mac, another local account pre-creates `/tmp/tavs-<uid>/organizer` with permissive modes.
   - **Behavior.**
     - The code checks file type, `O_NOFOLLOW` and lock mode `0600`, but never `st_uid == geteuid()` or the absence of group/other write.
     - A lock file the attacker owns with mode 0600 makes every managed write fail with `EACCES`, which is a denial of service.
     - The attacker can also plant readable effect, observation or intent records keyed to the victim's TTY and owner generation. `proc_pidinfo` makes those values readable.
     - Planted effects can paint attacker-chosen backgrounds through the lease path (369-392). Planted observations can spoof attention cues.
   - **Impact.** Visual-only spoofing and denial of service. No input injection is possible, because colors and titles are validated.
   - **Remedy.** Require the runtime and organizer directories and the lock file to be owned by the effective UID, with no group/other write. Fail closed as `storageUnavailable` otherwise.
   - **Test.** Chown a fixture directory, or simulate ownership through an injected stat, then assert `storageUnavailable` before any read.

3. **R4 [visual-recovery.swift:129-424, 583]: Monolithic write closure and lossy diagnostics**
   - The `prepare` closure is about 210 lines interleaving 13 operation kinds with shared mutable flags. This raises regression risk in branch ordering.
   - Fanout collapses `deviceIOFailed(errno)`, EBUSY, `deviceWriteTimedOut` and policy errors into "Managed restoration unavailable." The target is kept, but errno, emergency lane and busy-versus-timeout distinctions are lost.
   - **Remedy.**
     - Split the per-operation preparation into small functions.
     - Map `ProcessRunnerError` cases to fixed, non-sensitive reasons ("device busy", "device timeout", "device errno N").
   - **Test.** Fanout over an owned PTY whose open is held, followed by a second attempt. Assert distinct reasons for timeout versus EBUSY.

### Unresolved hypotheses (not reported as defects)
- **Theme-applied colors.** It is unverified whether `ghostty +show-config --changes-only=false` prints theme-applied `background` and `foreground` (terminal-renderer.swift:46-50). This needs native acceptance.
- **Inode reuse.** A persisted `VisualRestrictionsIdentity` in effect records compares device and inode across processes (visual-recovery.swift:371). Inode reuse after atomic marker replacement could falsely match. This is unlikely on APFS's monotonic inode allocation and was not demonstrated.
- **Grandchild pipe holders.** `runBoundedOutput` kills only the direct child (ProcessRunner.swift:77). A grandchild holding a pipe produces a timeout and survives. No current caller spawns grandchildren.
- **Duplicate items in the recovery report.** A native row whose `captureTarget` fails after its TTY was already restored through a validated cached binding adds a failed item (visual-recovery.swift:456-458). This is conservative but can make the report show both restored and failed for the same TTY. Whether that is "honest" depends on interpreting SPEC 274-279.
- **Linux.** No Linux compatibility regression is attributable to this Darwin-only subscope. Shell-side backend selection belongs to partition 3.

===END_ISSUES===

---

===SCORE_CARD===

### Rubric Scores

| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| Correctness | 7/10 | Ordering, deadline and lease contracts hold; R1 lets unrelated record state make recovery fail for a valid target |
| Security | 7/10 | Strict allowlists, no-follow and private errors; runtime root ownership unchecked (R3) |
| Maintainability | 6/10 | `performWrite` closure about 210 lines across 13 operations; diagnostics collapsed (R4) |
| Test Coverage | 7/10 | Extensive owned-PTY race, deadline and identity tests; no invalid-record emergency or repair case; visual-recovery tests not in this subscope |
| Performance | 8/10 | Bounded I/O and independent fanout; repeated directory enumeration and process lookups per write stay within budget |
| **Overall** | **6.9/10** | Mechanical verdict: CONCERN (all at least 5, one below 7) |

===END_SCORE_CARD===

---

===RECOMMENDATIONS===

1. **[Priority 1] Fix R1.**
   - Make `.emergencyReset` independent of record decoding once target and descriptor validate.
   - Quarantine unreadable effect files under the held lock.
   - Add the discriminating owned-PTY test.
2. **[Priority 2] Fix R2 and R3.**
   - Add an explicit repair path for unreadable per-target bound intent in fresh publications.
   - Verify effective-UID ownership and non-writable modes for the runtime and organizer directories and lock files.
3. **[Priority 3] Fix R4.**
   - Factor the per-operation preparation out of `performWrite`.
   - Preserve fixed errno, busy and timeout reasons in `VisualRecoveryItem`.
   - Keep native, visible and readability acceptance as explicitly unverified rather than inferring it from green runs.

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
Input scope: Partition 1, subscope 03-visual-writer, at commit 7ecfba2. Reviewed every supplied file in full against SPEC.md and PLAN.md:
- Sources: Package.swift, terminal-visual-state.swift, terminal-renderer.swift, terminal-render.swift, ProcessRunner.swift, process-identity.swift, PauseVisual.swift, visual-restriction-policy.swift, visual-restrictions-state.swift, organizer-intake.swift, managed-output-entry.swift, visual-recovery.swift, Clock.swift, MuteState.swift, LockState.swift.
- Tests: terminal-visual-state, terminal-renderer, terminal-render, process-runner, process-identity, visual-restriction-policy, visual-restrictions-state, managed-output-entry and PauseVisual tests.
- Mocks: MockBroadcaster, MockFileWatcher, MockLoginItemService, MockProcessRunner, MockTimerScheduler.
"Full" refers to this supplied subscope only, not whole-goal acceptance.
Focus: all default
Limitations:
- Tool-free single turn. No file reads beyond the supplied content, no builds or tests, and no report file written to /tmp.
- Callers outside the supplied set (Broadcaster, Scheduler, focus-controller, sessions model, shell bridges, visual-recovery-tests) were not available. Findings are limited to the supplied source.
- Native catalogue, navigation, visibility, Spaces, readability and Automation-permission acceptance are unverified.
- Linux ordinary backend and runtime tests are unverified.
- Historical first-paint/EPERM and fresh-render timeout causes remain unestablished. Passing tests are not treated as physical acceptance.
===END_REVIEW_META===


