> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# Claude Review Report

===DIMENSION_RATIONALE===
The five default code dimensions fit this pass. Pass B covers the bounded writer, the headless managed-output entry, render payload parsing, the color math, recovery fanout and composition, current-policy reading, and the persistent suspension marker. Each dimension applies as follows:

- **Correctness**: ordering, deadline and report classification.
- **Security**: untrusted argv, stdin, records and filesystem objects.
- **Maintainability**: a large composition closure and a multi-role recovery type.
- **Test coverage**: PTY-backed race and ordering tests.
- **Performance**: thread use under wedged devices, fanout timing and subprocess cost.

No dimension was substituted.

Phase/file coverage for this pass (every primary target was read in full):

| Primary target | PLAN phases exercised | Coverage |
|---|---|---|
| ProcessRunner.swift | 1 (bounded subprocess), 6 (managed writer) | full |
| managed-output-entry.swift | 4 (capability query), 6 (headless verbs, recover) | full |
| terminal-render.swift | 6/7 (typed render payload) | full |
| terminal-renderer.swift | 7 (preview tint, config query), 8 (focus dim) | full |
| visual-recovery.swift | 6 (recovery, fanout), 7 (preview), 8 (focus), 9 (focus request currency) | full |
| visual-restriction-policy.swift | 5/6 (fresh in-lock policy) | full |
| visual-restrictions-state.swift | 5 (marker), 6/7 (revision pinning) | full |
| MockProcessRunner.swift and the seven test files | matching phases | full |

Dependency context used for cross-file analysis: terminal-visual-state.swift, focus-controller.swift, Broadcaster.swift, TAVSApp.swift, mute-gate.sh, organizer-state.sh, visual-restrictions-state.sh, terminal-osc-sequences.sh.

Failure hypotheses and disposition:

1. **A restrictive write queued before recovery repaints after it: DISMISSED.**
   - Device open precedes the flock (ProcessRunner.swift:150 then 175-185).
   - Policy is recomputed inside `prepare` under that lock (visual-recovery.swift:290, visual-restriction-policy.swift:29-50).
   - Renders and forced resets additionally pin the marker revision (visual-recovery.swift:168-174, 196-199).
   - Tests cover this: visual-recovery-tests.swift:336, :880, :999, and process-runner-tests.swift:130, :167.
2. **A late or hung open holds output serialization, or a late worker paints after the caller deadline: DISMISSED as a lock or paint defect.**
   - Every step re-checks the original deadline (ProcessRunner.swift:147-191).
   - Tests cover this at process-runner-tests.swift:203 and :243.
   - The leaked worker thread itself is a separate CONFIRMED performance issue (M3).
3. **Recovery or focus reports are misclassified, giving false failures or nonzero exit for confirmed-closed targets: CONFIRMED** (M1, L1).
4. **A malformed or unavailable marker breaks ordinary rendering rather than only disabling restrictions: CONFIRMED** (M2).
5. **Preview or focus composition emits foreground, palette, title or historical bytes: DISMISSED.**
   - The preview returns only `backgroundBytes` (visual-recovery.swift:245).
   - Focus and selective composition emit 104/110 only when legacy reset is required (visual-recovery.swift:356).
   - `invalidatePending` unlinks pending files and never reads them (visual-recovery.swift:545-562).
===END_DIMENSION_RATIONALE===

===EXECUTIVE_SUMMARY===
Overall grade: 6.2
Risk level: Medium
Verdict: CONCERN

The safety-critical core of this partition holds up under the scenarios checked:

- Persist-then-serialize ordering.
- Open-before-lock.
- Fresh in-lock policy.
- Revision pinning against queued renders.
- Strict parsing of the marker, policy files and render payload.

The PTY tests exercise the paused-before-open and paused-before-policy cases the SPEC requires.

The defects are in classification, degraded modes and resource behavior, not in restriction ordering:

- Recovery reports permanent failures for registry entries whose device is confirmed absent. This contradicts the exit-code contract.
- An unavailable marker makes every typed render fail, which silently removes all ordinary TAVS output.
- Each managed write to a wedged TTY leaks a blocked GCD worker. The 2-second Manual/Automatic refresh amplifies this in the GUI process.
- `performWrite` is a roughly 245-line closure with very high branching. This raises regression risk for future precedence changes.

This verdict covers Pass B only, not aggregate implementation sign-off. Native, UI and visual acceptance remain unverified.
===END_EXECUTIVE_SUMMARY===

===ISSUES===
**MEDIUM**

**M1. Registry-only targets with confirmed-absent devices are permanent recovery failures; a `/dev/tty` registry entry fails the whole registry**

- **Location:** src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:422-429 and :564-578. Related: src/core/mute-gate.sh:143-150, where `clean_active_tty_registry` is a no-op and `register_active_tty` touches unconditionally.
- **Trigger:**
  - A shell ran a hook, but no managed write ever reached `cacheTargetUnlocked`. Examples: the helper was unsupported at that time, a pre-upgrade registry was left in `/tmp`, or the render failed its context or ancestry check.
  - That terminal later closed. On macOS the pty slave node is removed on free, so `lstat` returns ENOENT.
  - Separately, a hook that resolved `TTY_DEVICE=/dev/tty` registers `_dev_tty`.
- **Situation:** `registryHints` reports every entry not in `knownTTYs` as `failed "Registry target is unverified."`. Any entry not matching `^_dev_tty[sp]...` sets `unavailable = true`, which yields "Active terminal registry unavailable."
- **Behavior:**
  - No device-existence or process evidence is consulted.
  - Registry entries are never pruned.
  - Every later `tavs recover` and every GUI Restore Visibility reports `hasFailures`, and the CLI exits 1 until reboot clears `/tmp`.
- **Impact:** This violates "Confirmed closed targets do not produce false failure" and "Exit zero means ... no live target failed." Operators learn to ignore nonzero recovery, which defeats the purpose of honest partial-failure reporting. Suspension itself is still saved, so safety is not reduced.
- **Suggestion:**
  - Classify a registry entry as `vanished` when its device node is confirmed missing. The store already has `knownDeviceMissing`.
  - Report a non-concrete name such as `_dev_tty` as a per-entry unverified item, not a whole-registry failure.
  - Do not paint any of these. No new control plane is needed.
- **Confidence:** high for the code path. Medium for frequency, because it depends on how often registry entries lack cached bindings.

**M2. An unavailable suspension marker makes every typed render and forced reset fail**

- **Location:** src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:168-174, calling src/macos/TAVSApp/Sources/TAVSApp/visual-restrictions-state.swift:56-57.
- **Trigger:** `~/.tavs/visual-restrictions.state` is malformed, oversized, a symlink, unreadable, or under an inaccessible parent. Any of these makes `read()` return `.unavailable`.
- **Situation:** For `.render` and `.forcedReset`, `beforeOpen` calls `captureRevision()`. That call throws `storageUnavailable` whenever `read() == .unavailable`.
- **Behavior:**
  - `ManagedOutputEntry.run` maps the error to code 1.
  - `_tavs_render_flush` prints "current render unavailable".
  - Because `send_osc_bg`, titles, palette and bell all go through `--managed-render` (terminal-osc-sequences.sh:84-91, organizer-state.sh:164-195), no ordinary TAVS output is produced at all.
  - Previews also cannot start: focus-controller.swift:48-50 uses the same capture. The SPEC lets harmless previews continue while restrictions are disabled.
- **Impact:** The documented meaning of "unavailable" is "Visual restrictions disabled until repaired" (visual-restrictions-state.swift:13). In practice, a 40-byte file corruption silently disables the whole product's ordinary signaling, and the message does not say so.
- **Suggestion:** Permit capture of any regular or missing marker regardless of parse status. Pin its device and inode, so any later replacement still invalidates. Keep `policy.current` treating unavailable as disabled.
- **Confidence:** high.

**M3. Each managed write to a TTY wedged in `open` leaks a blocked GCD worker; GUI focus refresh repeats it every 2 seconds**

- **Location:** src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift:199-211 and :225-231. Driven by focus-controller.swift:291 through visual-recovery.swift:484-521.
- **Trigger:** One outside surface's TTY stalls inside `open`. The comment at ProcessRunner.swift:196 documents this as a real macOS case. Manual or Automatic focus is active.
- **Situation:** `completeDeviceWrite` returns `deviceWriteTimedOut` after 100 ms, but the dispatched worker stays blocked in `open`. Every 2-second catalogue update issues a new `.focus` apply to the same target, and nothing remembers that a prior attempt is still in flight.
- **Behavior:** One more blocked global-queue thread accumulates per attempt. After tens of attempts, global-queue capacity is exhausted. New `completeDeviceWrite` workers then do not start within their 100 ms window, and in-process healthy targets also fail.
- **Impact:** GUI preview and focus degrade to universal failure within minutes. Headless recovery runs in a fresh process and is unaffected, so the recovery guarantee holds. This is a resource defect, not an ordering defect.
- **Suggestion:** Keep a process-local set of device paths with an outstanding writer. Fail fast with a busy/unverified failure while the earlier worker has not returned. This is a small guard, not a stronger lock or control plane.
- **Confidence:** high for the mechanism. Real-world wedge frequency is unverified.

**M4. `performWrite` concentrates all managed-output semantics in one high-complexity closure**

- **Location:** src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:124-369.
- **Situation:** About 245 lines handle 12 operation kinds. These include two layered `beforeOpen` rewrites, where the clear path replaces the publication closure. There are also captured mutable locals (`effects`, `clearSelective`, `resetLegacy`) that change mid-closure, plus several early returns whose meaning depends on the operation.
- **Behavior:** The code is correct for the paths checked here. However, precedence rules 1-5 from the SPEC are spread across `.preview`, `.focus`, `.clearFocus` and the shared composition tail.
  - One example: `effects.contains(where: { $0.active })` at :338 deliberately reads a stale pre-cancel snapshot.
  - Another: line :296 exists only to stop `.clearFocus` from repainting a restriction.
- **Impact:** This creates high regression risk for the next precedence or kind change. Reviewers cannot locally verify that a new branch preserves "global pause owns its visual" or "no title on clear."
- **Suggestion:** Split into three parts:
  - Per-operation preparation that returns a typed decision (skip, restriction, or compose with a lease set).
  - One pure composition function.
  - Byte emission.

  Keep everything inside the existing writer callback, so no ordering change is needed.
- **Confidence:** high.

**LOW**

**L1. A failed native capture is reported as failure even when the same physical TTY was already restored through its cached binding**

- **Location:** visual-recovery.swift:401-404.
- **Trigger:** Any of the following, where a cached plain binding for that TTY restored successfully in the first fanout:
  - The foreground process exits between Ghostty enumeration and `lookup`.
  - The foreground process is unreadable.
  - A transient race occurs.
- **Behavior:** A `failed "Native target binding unavailable"` item is appended without checking existing restored items for that TTY. The TTY is also not added to `known`, so a registry hint for it is reported again as a second failure.
- **Impact:** False nonzero exit and duplicated failure counts.
- **Suggestion:** Skip or downgrade when an item for the same TTY is already restored or unaffected.
- **Confidence:** medium.

**L2. Inactive global-restriction records are never retired and keep forcing legacy resets**

- **Location:** visual-recovery.swift:309-311 with :454-461.
- **Trigger:** A target that ever carried a global pause.
- **Behavior:**
  - Every later `.reconcile` emits OSC 104/110, because `effects.contains { $0.kind == .globalRestriction }` ignores `active`.
  - `reconcilePriorEffects` at launch repaints every target with any historical record.
- **Impact:** Current ordinary palette themes are reset on each TAVS launch or reconcile until the next hook. This is a visual glitch only.
- **Suggestion:** Retire a global record once its legacy reset has been delivered under the lock.
- **Confidence:** high.

**L3. Swift policy and shell parity differ on a malformed lock grant or written field**

- **Location:** visual-restriction-policy.swift:37-43 vs src/core/mute-gate.sh:68-77.
- **Trigger:** `UNLOCK_UNTIL_EPOCH="bad"` or `WRITTEN_EPOCH="bad"` on an otherwise valid lock.
- **Behavior:** Swift treats the whole lock as absent, matching LockState.swift's "malformed means NOT locked". The shell treats it as locked and sets `_TAVS_SUPPRESS_OUTPUT=1`.
- **Impact:** The shell and the managed helper can disagree about suppression. Only manual edits can trigger this.
- **Suggestion:** Align the shell reader to the Swift strictness and add the case to the parity fixture.
- **Confidence:** medium (the parity test body was not in scope).

**L4. A marker write can report failure after it has already persisted**

- **Location:** visual-restrictions-state.swift:145-147.
- **Trigger:** `setAttributes(0600)` fails after the atomic rename.
- **Behavior:** `storageUnavailable` is thrown. `recover()` then returns `stateSaved: false` and skips repaint, and the CLI path reports a helper failure, although suspension is in effect.
- **Suggestion:** Write a temp file with mode 0600 and then rename, as the shell writer does. Alternatively, report saved state separately from a permission-repair failure.
- **Confidence:** medium, though the event is rare.

**L5. No ownership check on runtime lock and record directories**

- **Location:** ProcessRunner.swift:153-174, which checks type and mode but not `st_uid`.
- **Trigger:** Another local user pre-creates `/tmp/tavs-$UID`. This is pre-existing convention risk, already present for `lock.state`.
- **Impact:** Planted effect or lock records could tint or lock the user's own terminals. Bytes are still constrained to normalized colors and validated targets, so there is no privilege crossing.
- **Suggestion:** Reject a runtime or organizer directory or lock file whose `st_uid != getuid()`.
- **Confidence:** medium.

**L6. Preview start spawns two Ghostty configuration subprocesses per selection change**

- **Location:** terminal-renderer.swift:29-51, invoked per preview from focus-controller.swift:64.
- **Trigger:** Each selection change with existing user configuration.
- **Behavior:** Every click runs `+validate-config` and `+show-config`, with no reuse across runs.
- **Impact:** The visible preview window shrinks by the query latency, because expiry is anchored at `startedAt` and the 2 s ±250 ms tolerance is at risk. Process churn accompanies rapid browsing. Actual latency is unmeasured.
- **Suggestion:** Cache resolved colors per application generation plus configuration file identity and mtime. Invalidate the cache on change.
- **Confidence:** low-medium.

**L7. Weak chroma assertion**

- **Location:** terminal-renderer-tests.swift:23.
- **Behavior:** `max - min < 1` in 0..1 units rejects only fully saturated primaries. It would pass a transform that barely reduced chroma.
- **Suggestion:** Assert that dimmed chroma is strictly less than the input chroma by a margin.
- **Confidence:** high.

**L8 (adjacent callee). Wall-clock steps backward invalidate effect records**

- **Location:** terminal-visual-state.swift:473 and :882.
- **Trigger:** The system clock is set backward past record timestamps.
- **Behavior:** `currentEffectUnlocked` throws `invalidRecord` for that target, so all managed writes to it fail and recovery lists those records as unreadable until the clock catches up.
- **Suggestion:** Tolerate small future skew, or treat future-dated records as expired rather than invalid.
- **Confidence:** medium.

**Dismissed hypotheses (with evidence)**

- **State-record lock and device lock share one file (`lockURL(forTTY:)`), so nested flock could self-deadlock.** Dismissed. `withLock` is used only in `beforeOpen` before the device lock, or outside writers. All in-`prepare` calls use the `Unlocked` variants (visual-recovery.swift:157-163, 183-190, 280-288).
- **The clear path's replacement of `beforeOpen` drops publication or revision capture.** Dismissed. Clear operations never set publication or render (visual-recovery.swift:137-152, 175-192).
- **Double intent publication (beforeOpen and prepare) can overwrite a newer intake.** Dismissed. The second publication re-checks observation and `updatedAt` and throws `staleIntent` or `staleDelivery`. This is tested at visual-recovery-tests.swift:450.
- **An ordinary `--managed-background` write queued across recovery is not revision-pinned.** Accepted as designed. It carries no title, palette or BEL, and policy is recomputed under the lock. The SPEC permits the next legitimate hook to restore ordinary color.
- **Rejecting `/dev/tty` at managed-output-entry.swift:59 regresses the fallback TTY path.** This is a supported product boundary under exact TTY identity. It is a compatibility note, not a defect.
- **Partial OSC on a timed-out write** (ProcessRunner.swift:242-287). This is a pre-existing pattern, and the next managed ESC aborts the partial sequence. It is noted as a limitation only.

**Empirical acceptance gaps (not defects)**

- The real Ghostty `+show-config` output format and theme application are unverified.
- Visible dim and preview salience on neutral dark and light backgrounds is unverified.
- Recovery timing with many hung targets on real hardware is unverified.
- Byte-level tests cannot establish rendering.
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| correctness | 6/10 | Ordering, pinning and in-lock policy are sound; false recovery failures (M1, L1) and render failure on an unavailable marker (M2) break stated contracts |
| security | 7/10 | Strict argv/stdin/record parsing, control-character rejection, O_NOFOLLOW and size caps; runtime-dir ownership unchecked (L5) |
| maintainability | 5/10 | `performWrite` is a roughly 245-line multi-operation closure with mutable captured state (M4); VisualRecovery mixes client, fanout and composition |
| test_coverage | 7/10 | Strong PTY race tests for paused open/policy, late open, busy lock, fanout and revision reuse; gaps for registry-vanished, unavailable-marker render, repeated wedged writes, and a weak chroma assertion (L7) |
| performance | 6/10 | Leaked blocked worker per wedged write, amplified by the 2 s focus loop (M3); per-selection config subprocesses (L6) |
| Overall | 6.2/10 | 25%, 25%, 20%, 15%, 15% respectively |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. **Fix recovery classification (M1, L1).**
   - Treat registry entries with a confirmed-missing device node as `vanished`.
   - Report a non-concrete registry name as a per-entry unverified item rather than whole-registry unavailability.
   - Do not report native-capture failure for a TTY already restored by a validated cached binding.
   - Add tests for each case.
2. **Let typed renders proceed when the marker is unavailable (M2).** Pin the existing regular-file or missing identity instead of throwing, keep policy treating unavailable as disabled, and add a test that a malformed marker still renders ordinary bytes.
3. **Add a process-local in-flight guard per device path in `completeDeviceWrite` callers (M3).** This prevents unbounded blocked-thread accumulation from repeated focus/preview writes to a wedged TTY. Report busy as failed or unverified.
4. **Refactor `performWrite` into a typed decision step plus pure composition (M4)** inside the existing writer callback. Address L2 (retire delivered inactive global records) in the same refactor.
5. **Lower priority:** shell/Swift malformed-grant parity (L3), 0600 temp marker write (L4), runtime-dir uid check (L5), configured-color caching (L6), and a stronger chroma assertion (L7).
===END_RECOMMENDATIONS===

===PR_READINESS===
Status: NEEDS WORK
Blockers:
- M1 (recovery exit-code contract violated for confirmed-closed registry targets).
- M2 (unavailable marker disables all ordinary rendering).
- Empirical acceptance remains incomplete: active-cue UI, relaunch UI, and native salience/navigation/recovery are unverified and must stay so.

Scope: Pass B partition of the complete branch review (managed writer, headless entry, render, renderer, recovery, policy, marker, and their tests). This is not aggregate coverage.

Commit quality: unknown. Commit history was not supplied beyond recent subjects, which are scoped "fix:" messages.
===END_PR_READINESS===

===SUGGESTED_PR_DESCRIPTION===
Not ready. Before a PR:
- Classify confirmed-absent registry and native-capture cases so recovery exit codes match the SPEC (M1, L1).
- Allow revision pinning of an unavailable marker so ordinary renders and previews continue (M2).
- Bound per-device in-flight writer workers (M3).
- Consider the `performWrite` decomposition (M4).

Then rerun the isolated Swift and shell suites and record that native/UI acceptance remains unverified.
===END_SUGGESTED_PR_DESCRIPTION===

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-branch
Model requested: opus
Effort requested: high
Model observed: unknown
Effort observed: unknown
Input scope: target 71e0f60, base e113fb8, Pass B, all 15 primary targets (ProcessRunner.swift, managed-output-entry.swift, terminal-render.swift, terminal-renderer.swift, visual-recovery.swift, visual-restriction-policy.swift, visual-restrictions-state.swift, MockProcessRunner.swift, managed-output-entry-tests.swift, process-runner-tests.swift, terminal-render-tests.swift, terminal-renderer-tests.swift, visual-recovery-tests.swift, visual-restriction-policy-tests.swift, visual-restrictions-state-tests.swift) plus supplied dependency sources and SPEC/PLAN/API_REFERENCE
Focus: correctness, security, maintainability, test_coverage, performance
Limitations: tool-free external review; no executed tests/builds/native/UI; reported execution evidence is not independently rerun; this is a complete partition, not aggregate coverage; shell callers (trigger.sh, shellrc) and parity Bats bodies were not supplied, so cross-language parity findings carry medium confidence
===END_REVIEW_META===
