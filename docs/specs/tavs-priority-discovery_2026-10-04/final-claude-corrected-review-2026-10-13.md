> [!NOTE] EXPLICIT CLAUDE CLI REVIEW
> The caller selected real `claude -p`; Claude Hub retains disable, volume and concurrency controls.

# Claude Review Report

===DIMENSION_RATIONALE===
The five default code dimensions fit this aggregate review. The fifth dimension is performance, not completeness. The branch changes per-hook and per-shell-start process cost, adds 2-second polling and repaint loops, and adds retry paths around wedged devices. Completeness against SPEC and PLAN is judged under correctness and test_coverage. Weights are correctness 25%, security 25%, maintainability 20%, test_coverage 15% and performance 15%.

- **Correctness:** identity binding, cue lifecycle, recovery ordering, report classification, and compatibility with existing signaling.
- **Security:** body-free intake, strict record parsing, filesystem object handling, and control-character handling at render and title boundaries.
- **Maintainability:** the size and branching of the writer composition and the state store, plus naming and comment drift after the semantic rewrite.
- **Test coverage:** owned-PTY race tests, reducer tests, stale or vacuous assertions, and missing regressions for the confirmed defects.
- **Performance:** helper launch fan-out, unbounded retained work under wedged targets, O(N) cached-record scans, and continuous repaint.

**Scope and evidence**

The scope is 83 changed non-Markdown targets from `git diff --name-only e113fb8..71e0f60`, restricted to src/, tests/, tavs and hooks/. They were partitioned as A=15, B=15, C=11 and D=42 (sum 83). All four partitions report Completion full via claude-cli-explicit. Evidence references:

- Pass A: /tmp/claude-review-tavs-final-corrected-pass-a-20261013.md
- Pass B: /tmp/claude-review-tavs-final-corrected-pass-b-20261013.md
- Pass C: /tmp/claude-review-tavs-final-corrected-pass-c-20261013.md
- Pass D: /tmp/claude-review-tavs-final-corrected-pass-d-20261013.md

Wrapper logs are at the matching `-wrapper-20261013.log` paths.

This synopsis rechecked every product source target directly against 71e0f60. Supporting test bodies were rechecked directly for: attention-state-tests, focus-controller-tests, terminal-renderer-tests, priority-pinning.bats, run-isolated.sh, test-isolation.bats, managed-background.bats, background-intent.bats, emit-osc.bats, shellrc.bats, visual-restrictions-parity.bats, mute-gate.bats, the shared fixture and conftest.py. The remaining test targets rely on the complete partition reads.

| PLAN phase | Primary product files | Primary tests | Partitions |
|---|---|---|---|
| 1 Native catalogue / exact navigation | process-identity.swift, ghostty-catalog.swift, ProcessRunner.swift (runBounded), Info.plist | process-identity-tests, ghostty-catalog-tests, process-runner-tests, Mocks/MockProcessRunner | A, B, D |
| 2 Sessions window / priorities | sessions-model.swift, sessions-view.swift, TAVSApp.swift, MenuContent.swift | sessions-model-tests | A, C |
| 3 Test isolation | tests/run-isolated.sh, tests/conftest.py | test-isolation.bats, mute-gate.bats, idle-worker-mute.bats, priority-pinning.bats, liveness.bats, test_idle_worker.py, test_title_composition.py | D |
| 4 Observations / intent | organizer-intake.swift, terminal-visual-state.swift, organizer-state.sh, terminal-osc-sequences.sh, idle-worker-background.sh, trigger.sh, claude and codex trigger.sh, hooks.json, install-codex.sh, title-management.sh, backgrounds.sh, dir-icon.sh | organizer-intake-tests, terminal-visual-state-tests, hook-observations.bats, background-intent.bats, emit-osc.bats | A, D |
| 5 Persistent suspension | visual-restrictions-state.swift and .sh, lock-state-lib.sh, mute-gate.sh, tavs-shellrc.sh, Scheduler.swift, MuteState.swift, cmd-status.sh, cmd-lock.sh | visual-restrictions-state-tests, visual-restrictions-state.bats, visual-restrictions-parity.bats, SchedulerTests, SchedulerLockTests, MuteStateTests, shellrc.bats, cmd-lock.bats, fixture json | B, C, D |
| 6 Independent recovery / writer | visual-recovery.swift, ProcessRunner.swift (writer), managed-output-entry.swift, terminal-render.swift, visual-restriction-policy.swift, Broadcaster.swift, cmd-recover.sh, tavs, cmd-help.sh | visual-recovery-tests, process-runner-tests, managed-output-entry-tests, terminal-render-tests, visual-restriction-policy-tests, BroadcasterTests, Mocks/MockBroadcaster, cmd-recover.bats, managed-background.bats | B, C, D |
| 7 Previews / recovery controls / packaging | terminal-renderer.swift, focus-controller.swift (preview), PauseVisual.swift, MenuContent.swift, Scheduler.swift (release), cmd-sync.sh | terminal-renderer-tests, focus-controller-tests, cmd-sync.bats | A, B, C, D |
| 8 Manual focus | focus-controller.swift, terminal-renderer.swift (focusBackground), sessions-model.swift, sessions-view.swift, MenuContent.swift | focus-controller-tests, terminal-renderer-tests, sessions-model-tests | A, B, C |
| 9 Automatic focus | attention-state.swift, focus-controller.swift, sessions-model.swift, sessions-view.swift, terminal-visual-state.swift (isCurrentAttentionSource) | attention-state-tests, focus-controller-tests, hook-observations.bats | A, D |

**Forced falsification hypotheses (examined before scoring)**

1. *A restrictive write queued before recovery repaints after it.* DISMISSED.
   - Device open precedes the flock (ProcessRunner.swift:150, then 175-185).
   - Policy is recomputed under the lock inside prepare (visual-recovery.swift:290; visual-restriction-policy.swift:27-51).
   - Renders and forced resets pin the marker revision before open (visual-recovery.swift:168-174) and compare it under the lock (196-199).
   - Emergency reset requires `disablesRestrictions` under the lock (visual-recovery.swift:221).
2. *Transient unavailability is treated as cue resolution.* CONFIRMED (M1). A nil observation clears the cue but the Book is retained (attention-state.swift:36-46), so the same delivery can never re-create it.
3. *A delayed synthetic restore disturbs a newer delivery.* PARTIALLY CONFIRMED (M2).
   - Output is correctly rejected: the synthetic render is stale-checked (terminal-visual-state.swift:653-680).
   - The process-side state is not protected: the synthetic trigger kills the newer completion timer and rewrites session state before that check (trigger.sh:214-229).
4. *Recovery reports a false nonzero for confirmed-closed targets.* CONFIRMED (M3).
   - Registry-only entries are always `failed` (visual-recovery.swift:422-426).
   - One non-concrete entry fails the whole registry (visual-recovery.swift:572-574).
5. *Existing helper-less signaling is preserved.* NOT PRESERVED (H1).
   - Every ordinary background, palette, title, bell and image byte now requires a capable native helper (organizer-state.sh:164-195).
   - The managed-background.bats tests at 226-238 and 370-386 pin "no raw fallback" deliberately. This is a compatibility decision for the caller, not a hidden bug.
===END_DIMENSION_RATIONALE===

===EXECUTIVE_SUMMARY===
Overall grade: 5.9
Risk level: Medium
Verdict: CONCERN

This is the aggregate source review of 71e0f60 versus e113fb8 only. Later parent corrections are not covered. Native salience, navigation and recovery acceptance were not observed and remain unverified.

**What holds**

The safety-critical ordering is sound in the source checked:

- Suspension is persisted before helper resolution (cmd-recover.sh:31-34; managed-output-entry.swift:47).
- The device is opened before the stable output lock.
- Policy and marker revision are rechecked under that lock within the original 100 ms deadline.
- No historical pending bytes are replayed (visual-recovery.swift:545-562 only unlinks).

Identity is keyed to the Ghostty instance generation plus terminal ID. Cues carry producer, TTY and device. Go To acknowledges only a pre-dispatch snapshot (sessions-model.swift:255-261). Hook intake retains only allowlisted fields.

**What does not hold**

- **H1, compatibility.** Every ordinary signal now depends on an installed, capable native helper. With the helper absent or an older build, all hook styling and shell-start lock paint silently disappear. This needs an explicit caller decision.
- **Reducer.** Transient coverage unavailability permanently drops an unacknowledged High cue and can release Automatic dimming without any resolving signal (M1).
- **Delayed tool-error restore.** The restore can kill a newer completion idle timer (M2).
- **Recovery classification.** Recovery reports false failures for registry-only closed terminals and for unbound native rows, which breaks the exit-code contract (M3).
- **Resource behavior.** Under a wedged target, retained cleanup runs and blocked worker threads grow without bound (M4).
- **Process cost.** Each hook launches the full app binary about six times, and each interactive shell start launches it three times (M5).
- **Scheduler path.** Partial failures are discarded and not retried (M6).
- **Test integrity.** One integration suite asserts the removed pending-cache contract (M7).
- **Maintainability.** Maintainability is weakened by a 245-line composition closure and a 1201-line state store (M8).
===END_EXECUTIVE_SUMMARY===

===ISSUES===
Findings are ranked by severity. Root should verify each finding against source before acting.

## HIGH

### H1. Ordinary signaling and metadata now require an installed, capable native helper (compatibility regression; caller decision required)

**Locations**
- src/core/organizer-state.sh:164-195 (`_tavs_render_flush`), 67-84 (`_tavs_managed_helper`), 27-51 (`_tavs_organizer_intake`)
- src/agents/claude/trigger.sh:25-31
- src/shell/tavs-shellrc.sh:103-117

**Trigger.** Any of the following:
- The Claude plugin is installed or synced, but `/Applications/TAVS.app/Contents/MacOS/TAVSApp` is absent.
- The installed binary is older and lacks `--managed-output-capabilities`.
- The host is not macOS.

API_REFERENCE confirms that sync does not build the helper. A sync performed before rebuilding the app therefore triggers this immediately.

**Situation.** `_tavs_render_flush` sets `result=1` when the helper probe fails (171-173). It drops background, palette, title, bell and image together. The shellrc prints "managed output helper unavailable" and no longer self-paints a lock (103-106). `_tavs_organizer_intake` exports `TAVS_PERMISSION_MODE=default` and empty session and cwd when the organizer probe fails.

**Behavior.**
- No visual output from any hook. The only evidence is stderr lines from async hooks, which users do not see.
- A `tavs lock now` hard lock no longer paints new shells without the binary.

**Impact.** This conflicts with:
- SPEC "preserve direct ordinary signaling when no controller owns an effect" and "Preserve existing legitimate metadata-dependent behavior".
- PLAN 6.2 "Legitimate nonbackground hook styling stays intact".
- The brief's existing-compatibility requirement.

The design choice is documented in API_REFERENCE and pinned by managed-background.bats:226-238 and 370-386. That makes it a deliberate boundary that was never reconciled with the SPEC text. Safety contracts are not weakened.

**Suggestion.** Do not add a raw unsafe fallback. Root should decide between two options:
- Declare "helper required" as the supported boundary in the SPEC, API, shell-integration help and plugin docs, and emit the unavailability notice once per session rather than per hook or shell.
- Explicitly re-scope titles and bells.

Also add a sync-time warning when the installed helper lacks the required capability.

**Confidence.** High on the behavior; medium on whether it is intended.

## MEDIUM

### M1. Transient coverage unavailability permanently drops unacknowledged cues and can release Automatic dimming

**Locations**
- src/macos/TAVSApp/Sources/TAVSApp/attention-state.swift:36-42, 44-46
- terminal-visual-state.swift:749-751, 795-797, 960
- focus-controller.swift:185-191, 213-217, 280-287, 328-338

**Trigger.**
1. A High Claude surface has an unacknowledged Stop cue.
2. On one 2-second refresh, `coverage(for:)` cannot take the per-TTY writer lock within its default 100 ms (960). This happens when a hook render against a backpressured device holds the same `writer-*.lock`. Alternatively, Ghostty's `optional(terminal,'tty')` read fails and the row becomes `missingTTY`.
3. Either way the sample has `observation: nil`.

**Situation.** `reconcile` sets `cues[surface] = nil` and continues, but keeps `books[surface]` (only closure removes books at line 34).

**Behavior.**
- On the next refresh the same delivery returns from the same actor. The guard `record.observedAt > previous.latest.observedAt` fails, so the cue is never restored.
- If it was the last cue, `acceptCatalogue` calls `retireFocus()` (190-191) and Normal/Low dimming is cleared.
- A second path behaves the same way. `invalidateAutomaticSources` (328-338) acknowledges every cue when no sampled source validates inside a writer callback. Only the first cue per surface is sampled.

**Impact.** An attention occurrence disappears without processing, exit, reset, acknowledgement or confirmed invalid destination. This contradicts G8. attention-state-tests.swift:118-125 encodes "nil clears and never replays" without separating transient unavailability from confirmed invalidity.

**Suggestion.**
- Give `TerminalVisualCoverage` an explicit distinction between temporarily unavailable and confirmed invalid.
- On temporary unavailability, retain cues and books without creating new ones, mirroring `catalogueUnavailable()`.
- Clear only on confirmed producer exit, generation or device mismatch, resumption, reset, downgrade or closure.
- Do not add stronger coverage locks.

**Confidence.** High on the mechanism; medium on frequency.

### M2. Delayed tool-error restore can kill a newer completion idle timer

**Locations.** src/core/trigger.sh:405-418 (check at 410, synthetic dispatch at 413/415); 214-215 and 229 (processing case `kill_idle_timer`, `record_state`); 349-352 (subagent branch).

**Trigger.**
1. A PostToolUseFailure hook runs.
2. At 1.5 s, `_tavs_managed_check_context` passes because the observation is still the tool-error delivery.
3. A Stop hook then publishes its observation, renders, and records its idle worker PID.
4. Only then does the synthetic `trigger.sh processing` reach line 215. Re-sourcing roughly 14 modules plus helper capability probes widens this window.

**Behavior.**
- `should_change_state processing` passes (30 > 20).
- `kill_idle_timer` kills the completion worker, and `record_state processing` overwrites the session DB.
- The synthetic render is then rejected as stale (exit 3), so nothing repaints.

**Impact.** The terminal stays at the completion color with no idle graduation and no forced reset, and the state DB claims processing. Cues are unaffected. background-intent.bats:261-294 sends Stop at 0.5 s, before the check, so this ordering is untested.

**Suggestion.** In synthetic mode, skip `kill_idle_timer`, `record_state` and the subagent increment. The tool-error hook already killed any prior timer at line 395, so a live timer at restore time belongs to a newer delivery. Add an ordering test that injects the completion between check and dispatch.

**Confidence.** Medium; the window is narrow but real.

### M3. Recovery classification reports false failures and breaks the exit-code contract

**Locations.** src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:422-429, 564-578, 401-404; src/core/mute-gate.sh:143-150.

**Trigger A (registry).** Registry entries that never received a cached binding report `failed "Registry target is unverified."` with no device or process evidence consulted. Examples:
- Entries from before this upgrade. The active-ttys registry existed in the base.
- Entries created while the helper was missing or unsupported.

`clean_active_tty_registry` is a no-op, so these persist until /tmp is cleared.

**Trigger B (`/dev/tty`).** A hook that resolved `TTY_DEVICE=/dev/tty` registers `_dev_tty`. That name fails the `^_dev_tty[sp][A-Za-z0-9]+\z` regex, sets `unavailable = true`, and adds "Active terminal registry unavailable." as a whole-registry failure.

**Trigger C (native capture).** `captureTarget(for: row)` returns nil because of a mapping issue or a foreground process race. A `failed` item is then appended even when the same physical TTY was already restored through its cached binding, and the TTY is not added to `known`, so a registry hint duplicates the failure.

**Impact.**
- Every `tavs recover` and every GUI Restore Visibility exits nonzero, potentially until reboot.
- This contradicts "Confirmed closed targets do not produce false failure" and "Exit zero means ... no live target failed".
- Operators learn to ignore nonzero recovery. Suspension itself is still saved.

**Suggestion.**
- Classify a registry entry as `vanished` when `knownDeviceMissing` confirms the node is absent; this is already used as evidence in `validateTarget`.
- Report non-concrete names per entry rather than failing the whole registry.
- Skip native-capture failures for a TTY already restored or unaffected, and add it to `known`.
- Paint none of these.

**Confidence.** High on the code path. Frequency depends on macOS pty node lifetime, which is unverified.

### M4. Wedged-target resource amplification in the GUI process

This finding consolidates Pass A M2 and Pass B M3.

**Locations.** focus-controller.swift:23, 104, 197-206, 293-296, 300-305, 340-357; ProcessRunner.swift:199-211, 225-231.

**Trigger.** Manual or Automatic focus is active, and one outside TTY keeps failing. Causes include a hung open, a busy writer lock, or `focusUnavailable`.

**Mechanism 1: retained cleanup runs grow.**
- `lastHeartbeat` advances only when every outside target succeeds (293-296).
- Every refresh more than 6 s after that creates a new `Run` and appends the old one to `pendingFocusClear` (203-206).
- A clear that fails on the same target re-appends itself (350-351).
- Retained runs therefore grow by about one per 8 s.

**Mechanism 2: blocked threads leak.** `completeDeviceWrite` returns after 100 ms, but a worker blocked in `open` stays parked on a global-queue thread. Every focus apply and every cleanup retry to that TTY adds another.

**Impact.**
- The serial `clearQueue` is shared with preview clears, so after a few minutes Clear and Escape miss the one-second clear bound.
- Blocked threads can exhaust global-queue capacity, after which healthy in-process writes also fail.
- Headless recovery runs in a fresh process, so the recovery guarantee is not affected.

**Suggestion.**
- Coalesce focus cleanup per physical target, not per run.
- Drop a target once a clear returns restored, unaffected or vanished.
- Give preview clears their own queue.
- Keep a process-local in-flight set per device path and fail fast while an earlier worker has not returned. This is a small guard, not a stronger lock.

**Confidence.** High on both mechanisms. Wedge frequency is unverified.

### M5. Process fan-out per hook and per shell start, plus O(N) cached-record scans with no retirement

**Locations.**
- organizer-state.sh:3-20, 53-65, 67-84, 164-178
- claude/trigger.sh:26-33
- tavs-shellrc.sh:62-117, header 17-18
- terminal-renderer.swift:29-51 with focus-controller.swift:64
- visual-recovery.swift:437-452, 463-469, 384-394
- managed-output-entry.swift:128-129
- terminal-visual-state.swift:382-436, 271-315

**Submechanism 1: helper launches.** Each Claude hook launches the full TAVSApp binary about six times:
1. Organizer probe in the adapter.
2. Intake in the adapter.
3. Organizer probe again after `exec`, because `_TAVS_ORGANIZER_HELPER_CHECKED` is not exported.
4. Observe.
5. Managed-output probe.
6. Render.

Every interactive shell start now synchronously runs a probe, `--managed-register` and `--managed-current`. The shellrc header still claims "<1ms ... zero forks in zsh", and the install help still says "Cost: <1ms".

**Submechanism 2: preview configuration queries.** Each preview selection change runs `+validate-config` and `+show-config`, each up to 2 s. Expiry is anchored at `startedAt`, so slow queries shrink or eliminate the visible preview.

**Submechanism 3 (synopsis-only): cached-record scans.** Every `--managed-render` and `--managed-background` calls `recovery.target(tty:owner:)`. That calls `state.cachedRecords()`, a full walk and JSON decode of every `targets/**` record. Nothing ever deletes a target directory, so N grows with every shell lifetime and native alias until reboot. `equivalentBindingsUnlocked` also enumerates every historical owner under one TTY key, inside the 100 ms writer deadline.

**Impact.**
- Hooks are async, but CPU and latency scale with tool calls.
- Shell startup latency regresses visibly.
- Per-render cost grows unbounded until reboot.
- Actual launch time and N are unmeasured.

**Suggestion.**
- Export the verified helper path and checked flags across `exec`.
- Fold the two capability probes into one.
- Correct the cost claims in the header and help.
- Cache configured colors per application generation plus configuration file identity and mtime.
- Retire confirmed-vanished bindings (SPEC permits this), and look up a single TTY's subtree instead of the global tree in `target(tty:owner:)`.

**Confidence.** High on the counts and code paths; magnitude is unmeasured.

### M6. Scheduler-driven restriction and release results are discarded and not retried

**Locations.** Broadcaster.swift:17-21, 98-107, 110-114; Scheduler.swift:425-434, 458-473.

**Trigger.** A lock begins or a pause ends while one cached terminal is busy or backpressured past 100 ms.

**Behavior.**
- `record()` stores the result only in `lastResult`, which no production code reads.
- No log entry is written.
- The scheduler repaints only on a projection or visual change, so a missed target stays unpainted (or unreleased) until the next transition.
- Agent terminals self-heal on their next hook. Plain shells do not.

**Impact.** The SPEC requires busy and unverified targets to be reported as partial failures and kept retryable. Recovery satisfies this; the normal lock and pause path does not.

**Suggestion.** Log failed items via `TAVSLog.broadcaster`, restricted to the TTY. Reissue `.currentRestriction` or `.reconcile` on the existing 60 s heartbeat when the last result contained failures. No new mechanism is needed.

**Confidence.** Medium. The behavior predates the branch, but the branch introduced the partial-failure contract.

### M7. priority-pinning.bats asserts the removed pending-cache contract and drops the test helper

**Locations.** tests/integration/priority-pinning.bats:1-19, 61-70, 87-97, 114-121, 132-141.

**Behavior.**
- No production path creates `pending/*.osc`. The buffer functions are no-ops (mute-gate.sh:153-154), and recovery unlinks pending files.
- The `[ -f "$pending" ]` and `wc -c < "$pending"` assertions therefore cannot pass.
- `env -i` drops `TAVS_TEST_HELPER_BIN`, so the trigger probes and invokes `/Applications/TAVS.app` when it is installed.
- The header still documents verbatim replay, which the SPEC forbids.

**Narrowed claim.** The `mktemp -d` at line 27 does not escape isolation. run-isolated.sh sets a private TMPDIR, and `_dispatch` forwards it. Only the helper path is affected.

**Impact.** Either the reported shell totals excluded this file, or it fails. It also exercises a live binary, contrary to PLAN Phase 3.

**Suggestion.** Delete the file, or rewrite it to assert latest-wins typed intent with a stub helper and preserved `TAVS_TEST_HELPER_BIN`.

**Confidence.** High on the contradiction; unknown whether the file was in the executed set.

### M8. Maintainability: concentrated composition, monolithic store, naming and comment drift

**Locations and issues.**
- visual-recovery.swift:124-369 (`performWrite`, about 245 lines covering 12 operation kinds):
  - layered `beforeOpen` rewrites;
  - mutable captured `effects`, `clearSelective` and `resetLegacy`;
  - precedence rules spread across `.preview`, `.focus`, `.clearFocus` and the shared tail;
  - special-case guards such as line 296 and the stale-snapshot read at 338.
- terminal-visual-state.swift: 1201 lines covering record schemas, locking, adoption, leases, binding and IO. Lock-holding invariants exist only as `...Unlocked` naming and comments.
- focus-controller.swift:25-30, 243, 323, 340: `manual*` names also own the Automatic run.
- Scheduler.swift:153-163 (stale ps-discovery comment) and 469 (`clearPausedVisualAndReplayPending` no longer replays).
- Broadcaster.swift:29-31: `visual` and `untilText` are dead parameters.
- visual-recovery.swift:589-593: the lock title uses `Calendar.current` `%02d:%02d`, while Scheduler.swift:691-697 uses DateFormatter with the scheduler calendar.
- tavs-shellrc.sh:8-18: the header still describes self-paint and its cost.

**Impact.** Regression risk for any future precedence change. Replay-era names invite reintroducing forbidden behavior.

**Suggestion.**
- Split `performWrite` into a per-operation typed decision, a pure composition function and byte emission, all inside the existing writer callback.
- Rename the replay-era and "manual" APIs.
- Share one time formatter.
- Split the store by concern without behavior change.

**Confidence.** High.

## LOW

### L1. An unavailable suspension marker blocks all ordinary renders and previews

**Locations.** visual-recovery.swift:168-174 via visual-restrictions-state.swift:56-57; focus-controller.swift:48-50.

**Trigger.** The marker is malformed, oversized, a symlink, unreadable, or under an inaccessible parent.

**Behavior.**
- `captureRevision` throws, so every render and forced reset exits 1 with "current render unavailable".
- Previews report "suspension state cannot be verified".
- The documented meaning of unavailable is "restrictions disabled", not "no output". The shell readers treat it as disabled-restrictions only.

**Impact.** Triggering requires corruption, and the menu does show the unavailable state, so it is LOW. The impact when triggered is total.

**Suggestion.** Pin the device and inode of any regular or missing marker regardless of parse status, so a later recovery replacement still invalidates it. Keep `policy.current` treating unavailable as disabled.

**Confidence.** High.

### L2. Forced idle reset bypasses palette, background and title feature gates

**Locations.** idle-worker-background.sh:129; managed-output-entry.swift:119; visual-recovery.swift:339-340, 357, 362.

**Behavior.**
- The forced reset always prepends OSC 104 when no legacy reset applies.
- It emits OSC 111 from the just-published reset intent.
- It always writes OSC 0 with `SHORT_CWD`.

**Impact.** All three happen regardless of `ENABLE_PALETTE_THEMING`, `ENABLE_BACKGROUND_CHANGE`, `ENABLE_TITLE_PREFIX`, `TAVS_TITLE_MODE=off` or a title lock. After about 450 s, user or program palette, background and title can be overwritten. The 104 also conflicts with the SPEC rule against using 104 for background-only clears.

**Suggestion.** Pass the gating decisions to `--managed-forced-reset`, and omit the title when titles are disabled or locked.

**Confidence.** High on current behavior. Base behavior was not supplied, so the size of the regression is medium-confidence.

### L3. Inactive global-restriction records are never retired

**Location.** visual-recovery.swift:309-313 with 454-461.

**Behavior.** `effects.contains { $0.kind == .globalRestriction }` ignores `active`. Every reconcile, and every launch's `reconcilePriorEffects`, therefore re-emits OSC 104/110 for any target that ever carried a pause. This resets TAVS's own palette theming until the next hook.

**Suggestion.** Retire the record once its legacy reset has been delivered under the lock.

**Confidence.** High.

### L4. A running GUI recomposes ordinary intent right after emergency recovery

**Locations.** Scheduler.swift:392-397, 421-423, 469-473, 505-512.

**Trigger.** The GUI is muted when `tavs recover` or Restore Visibility runs.

**Behavior.**
- The marker write triggers the `~/.tavs` watcher.
- `wasMuted && !projectedMuted` enqueues a reconcile, which writes OSC 104/110 plus `11;intent`.
- Byte order relative to the helper's 104/110/111 is nondeterministic.

**Impact.** This diverges from "emergency recovery does not immediately reapply ordinary themes". Visibility is still restored.

**Suggestion.** Skip the background recomposition when the release cause is suspension, or document the behavior.

**Confidence.** Medium-high.

### L5. One invalid or future-dated effect record blocks recovery of that target

**Locations.** visual-recovery.swift:219-224; terminal-visual-state.swift:205-218, 469-482 (`heartbeatAt <= now`), 882.

**Behavior.** `effectsUnlocked` runs before the emergency-reset branch. A record that fails validation throws and the target reports `failed`. Causes include manual corruption, a future schema, or a clock stepped backward past a recent heartbeat (for example after a wake-time NTP step). Observations with future timestamps are likewise rejected.

**Impact.** The failure is honest and retryable, but recovery cannot reset that terminal until the record ages into validity or is repaired.

**Suggestion.** In the emergency path, cancel or ignore unreadable records rather than aborting the reset. Tolerate small clock skew.

**Confidence.** Medium.

### L6. Shell and Swift policy parity gaps; shell stubs prove the wrong predicate

**Locations.**
- mute-gate.sh:68-77 vs visual-restriction-policy.swift:37-43: a malformed `UNLOCK_UNTIL_EPOCH` or `WRITTEN_EPOCH` means locked in the shell but absent in Swift.
- mute-gate.sh:108 accepts an empty `REASON` and unquoted lines, which Swift rejects.
- lock-state-lib.sh:56-67 has the same grant parsing, so `tavs lock status` and `tavs unlock` can disagree with the native paint.
- emit-osc.bats:38-39 (and the stubs in liveness.bats and idle-worker-mute.bats reported by Pass D) decide output with `_tavs_check_mute_state`. These tests therefore prove the shell predicate, while production output is decided by Swift.

**Impact.** The shell predicate now governs only Kitty suppression and CLI messaging.

**Suggestion.** Align the shell readers to Swift strictness, add these cases to the parity fixture, and make the stubs policy-agnostic.

**Confidence.** Medium.

### L7. Plain-shell rows are indistinguishable from uncovered agent rows

**Locations.** sessions-view.swift:102-106; terminal-visual-state.swift:789-791.

**Behavior.** An idle zsh and a Claude session whose hooks failed both show "No agent observation". The coverage status line differs only when intent exists. The SPEC requires distinguishing shell or other-process rows from missing agent coverage.

**Suggestion.** Show a foreground-process role from the already validated `foregroundPID`, using executable basename only and never command lines.

**Confidence.** Medium.

### L8. UI explanation specificity

**Locations.** MenuContent.swift:36-40; sessions-view.swift:41-48.

**Narrowed from Pass A LOW 4.** Explanations do exist:
- The suspended message and "Focus stays Off" are shown.
- Preview under a rule reports "Preview unavailable while a pause or lock owns the visual" (visual-recovery.swift:507).
- Focus status says rules may mask dimming.

**Remaining gap.** "Saved schedules and locks may apply immediately" is unconditional. The SPEC asks to explain when a schedule will apply. Scheduler already computes `requestedMuted` but does not publish it.

**Suggestion.** Publish the requested projection and make the caption conditional on it.

**Confidence.** Medium.

### L9. Isolated-launch environment precedes legacy headless flags

**Location.** TAVSApp.swift:46-56 precedes 57-105.

**Behavior.** With any `TAVS_SESSIONS_TEST_*` key set, `--validate-config <schedule>`, `--reported-status` and similar flags launch the isolated GUI or exit 1. The new managed, organizer and restriction verbs are dispatched earlier and are unaffected, and the shell probes strip these keys.

**Suggestion.** Move the check after the legacy flag branches.

**Confidence.** High on ordering; low on frequency.

### L10. One unsafe title component drops the whole render

**Locations.** title-management.sh:526 and organizer-state.sh:147-149 → terminal-render.swift:40-42, 68-71.

**Behavior.** A tab or C0/C1 character in a user format or context token rejects all 23 fields, including the background.

**Suggestion.** Run `sanitize_for_terminal` on the composed title before queueing.

**Confidence.** Medium.

### L11. Decoded cwd can forge dir-icon cache lines

**Locations.** organizer-intake.swift:42-45, 53, 59 (cwd allows control characters) → organizer-state.sh:44 → dir-icon.sh:316-326.

**Behavior.** A newline in cwd injects a `worktree_icon=` line, which displays arbitrary printable text in the title. Native `safeText` still blocks escape sequences, so the effect is cosmetic.

**Suggestion.** Reject control characters in cwd, as already done for session IDs.

**Confidence.** Medium.

### L12. Codex notify JSON transits a here-string temp file

**Location.** src/agents/codex/trigger.sh:28.

**Behavior.** Bash 3.2 here-strings use an unlinked temp file in TMPDIR, so the full payload (including messages) briefly exists on disk. The window is transient, the directory is private, and the argv is already visible to `ps`.

**Suggestion.** Use process substitution, which goes through a pipe.

**Confidence.** High on mechanism; low on impact.

### L13. Gemini, OpenCode and unknown providers log an observation failure on every hook

**Locations.** organizer-state.sh:53-65 vs terminal-visual-state.swift:860.

**Behavior.** `--organizer-context` accepts these providers, but `publishObservation` rejects them, producing stderr noise on every hook. Renders still proceed.

**Suggestion.** Skip observe for unsupported providers.

**Confidence.** High; gemini/trigger.sh was supplied.

### L14. Codex installer rewrite loses file metadata and over-deletes

**Location.** install-codex.sh:121-129.

**Behavior.**
- The original mode and ownership are lost.
- A symlinked config is replaced by a regular file.
- `notify =` lines under any table are deleted, not only the root key.

A backup is kept.

**Confidence.** Medium.

### L15. Marker write can report failure after it has persisted

**Location.** visual-restrictions-state.swift:145-147.

**Behavior.** If `setAttributes(0600)` fails after the atomic rename, the write throws and `recover()` reports `stateSaved: false` and skips repaint, although suspension is in effect.

**Suggestion.** Create the temp file with mode 0600 before renaming, as the shell writer does.

**Confidence.** Medium; the event is rare.

### L16. Runtime and organizer directory ownership is not checked

**Locations.** ProcessRunner.swift:153-174; terminal-visual-state.swift:931-958.

**Behavior.** Type and mode are checked, but not `st_uid`. A pre-created `/tmp/tavs-$UID` owned by another user is accepted. This convention risk predates the branch. Bytes remain constrained to normalized colors and validated bindings.

**Confidence.** Medium.

### L17. Active focus repaints every outside terminal every 2 s

**Locations.** visual-recovery.swift:254-273 then 337-367; focus-controller.swift:209-210.

**Behavior.** Each refresh re-applies `.focus`, rewrites `focus.json`, and emits OSC 11 to every outside TTY. This continuously overrides application-set backgrounds and generates steady TTY and disk traffic. The SPEC does not promise exact restoration of program colors, but the heartbeat does not require repainting.

**Suggestion.** Emit bytes only when the composed background changes, and renew the lease metadata otherwise.

**Confidence.** High on behavior; low on impact.

### L18. Test debt (consolidated)

- **Vacuous assertions:** shellrc.bats:129-173 (`']11;'` absence can never fail now). The chroma assertion at terminal-renderer-tests.swift:23 is near-vacuous: `max - min < 1` fails only for fully saturated primaries.
- **Missing regressions for confirmed defects:** M1 (unavailable sample between identical observations; store lock timeout), M2 (ordering), M3 (registry vanished, `_dev_tty`, already-restored native row), M4 (persistent failure across heartbeats), L1 (malformed marker still renders).
- **Other gaps:** no static allowlist assertion over `GhosttyCatalog.script` (the source itself contains only property reads, `objectWithID` and `focus`), and no injected-lookup test for `OrganizerIntake.producer`.
- **Environment notes:** tests/test_idle_worker.py depends on `rg` being installed. baseline-regression.bats is unchanged but its byte path now requires the helper; its harness was not supplied, so its status is unverified.

## Dismissed or narrowed hypotheses (source evidence)

- **Go To acknowledges in-flight or replacement-producer cues:** dismissed. The snapshot is taken before dispatch (sessions-model.swift:255), acknowledgement subtracts only that set (attention-state.swift:27-30), and occurrences include producer, TTY and device (3-9). Tested at focus-controller-tests.swift:102-130 and attention-state-tests.swift:38-54, 127-134.
- **Automatic currency takes another TTY's lock:** dismissed. `isCurrentAttentionSource` validates without `withLock` (terminal-visual-state.swift:171-179).
- **Preview or focus repaints after Clear, Focus Off or retirement:** dismissed. Targets attach only under `current === run` or `manual === run` (focus-controller.swift:66-70, 271-275), and `isCurrent` is rechecked in prepare. Tested at focus-controller-tests.swift:210-228, 278-311, 509-525.
- **Priority transfers through TTY reuse or Ghostty restart:** dismissed. Keys are application generation plus terminal ID, pruned against fresh non-empty catalogues (sessions-model.swift:229-236).
- **Preview or focus emits foreground, palette or title bytes:** dismissed. Preview returns `backgroundBytes` only (visual-recovery.swift:245). 104/110 appear only on legacy reset (356).
- **Broadcaster coalescing drops a required clear:** dismissed (Broadcaster.swift:63-72).
- **Unmute clear reads the old projection:** dismissed. mute.state is written before the enqueue (Scheduler.swift:417-423).
- **Raw payload leakage:** dismissed. Intake keeps allowlisted fields (organizer-intake.swift:32-69), records reject unknown keys (terminal-visual-state.swift:1079-1082), and debug logs fixed fields (trigger.sh:70-93).
- **priority-pinning tempfile escapes isolation:** dismissed. TMPDIR is private (run-isolated.sh:19). Narrowed to the helper-path drop (M7).
- **Rejecting `/dev/tty` in managed output is a regression:** supported boundary under exact TTY identity.
- **Challenge-free master resume or schedule edits while suspended:** consistent with the binding "immediately reversible" direction. `isHardLocked` is false while suspended (Scheduler.swift:436), so PreferencesView saves are also ungated. Lock and schedule definitions are preserved. Flagged for caller awareness only; no stronger lock is recommended.

## Empirical acceptance gaps (unverified; not defects)

- JXA `target.focus` actually focusing the exact pane across Spaces, minimized and fullscreen windows, and multiple displays.
- `isFocused` false negatives after a Space switch. These are safe: no acknowledgement occurs.
- Visible preview tint and focus dimming on neutral dark and light backgrounds; ANSI and TrueColor readability.
- Active-cue and relaunch UI.
- Real Ghostty `+show-config` output.
- Automation TCC prompts from the built bundle and at launch-time enumeration.
- Real recovery timing with many hung targets.
- macOS pty node removal on close (affects M3 frequency).
- Helper launch latency (M5 magnitude).
- Claude hook concurrency. A subagent or parallel-tool PostToolUse on the same TTY may clear a still-pending permission cue via `resumed()`. This is unverified and partly covered by the documented latest-only boundary.

## Supported product boundaries

- npm or node-hosted Claude and Codex processes are rejected as unverified (organizer-intake.swift:206-208) and never create cues.
- Codex is completion-only.
- Latest-only records may miss intervening events.
- The Kitty `kitten @` path is outside the Ghostty scope.
- Arbitrary program-set colors are not restored.
- Emergency recovery does not reapply ordinary themes, and old lock titles may remain.
- Only local Ghostty is supported.
===END_ISSUES===

===SCORE_CARD===
| Dimension | Score | Key Finding |
|-----------|-------|-------------|
| correctness | 6/10 | Recovery ordering, revision pinning, identity keys and snapshot acknowledgement are correct. Transient unavailability drops cues (attention-state.swift:36-46), the delayed restore kills a newer timer (trigger.sh:214-229), recovery reports false failures (visual-recovery.swift:401-429), scheduler-path failures are unreported, and helper-less signaling is lost (H1) |
| security | 7/10 | Strict record and payload parsing, O_NOFOLLOW, 0600/0700 modes, control-character rejection and body-free intake. Residual: no uid check on runtime directories, transient here-string tempfile, cosmetic cwd cache injection |
| maintainability | 5/10 | 245-line `performWrite` closure with mutable captures, 1201-line state store, `manual*` names owning Automatic, replay-era names, dead parameters and stale cost comments |
| test_coverage | 6/10 | Strong owned-PTY ordering, sentinel and reducer tests. One suite asserts the removed pending contract, shellrc assertions are vacuous, the chroma assertion is weak, and none of M1-M4 or L1 has a regression test |
| performance | 5/10 | About six binary launches per hook and three per shell start, unbounded retained cleanup runs and leaked blocked workers under a wedged TTY, O(N) cached-record scans with no retirement, 2 s repaint of all outside terminals |
| Overall | 5.9/10 | 25%, 25%, 20%, 15%, 15% respectively |
===END_SCORE_CARD===

===RECOMMENDATIONS===
1. **Decide H1.** Either declare "helper required" as the supported boundary across the SPEC, API, plugin and shell-integration docs, or re-scope which nonbackground styling must survive helper absence. Emit unavailability once per session, and warn in sync when the installed helper lacks the capability. Do not add a raw fallback.
2. **Fix cue lifecycle (M1).** Add an explicit "temporarily unavailable" coverage state that retains cues and books, and clear only on confirmed invalidity or resolution. Apply the same rule to `invalidateAutomaticSources`. Add reducer and store regressions.
3. **Make synthetic tool-error restores non-destructive (M2).** Skip `kill_idle_timer`, `record_state` and the subagent increment in synthetic mode, and add an ordering test.
4. **Fix recovery classification (M3).** Confirmed-missing registry devices become `vanished`. Report non-concrete registry names per entry. Do not double-report a TTY already restored through a cached binding.
5. **Bound wedged-target work (M4) and process cost (M5).**
   - Coalesce focus cleanup per physical target and give preview clears a separate queue.
   - Add a per-device in-flight guard.
   - Carry the verified helper across `exec` and merge the two capability probes.
   - Cache configured colors.
   - Retire confirmed-vanished bindings and scan only the TTY's subtree on render.
   - Correct the "<1ms" claims.
6. **Surface scheduler partial failures (M6)** via logging and a heartbeat retry when the last result failed.
7. **Repair test integrity (M7, L18).** Delete or rewrite priority-pinning.bats with a stub helper. Replace the vacuous shellrc and chroma assertions. Add the missing regressions listed above.
8. **Lower priority.**
   - Gate the forced-reset palette, background and title (L2).
   - Retire delivered global records (L3).
   - Decide the post-recovery GUI recomposition behavior (L4).
   - Make the emergency reset tolerant of unreadable records (L5).
   - Align shell parity (L6).
   - Row role display (L7) and conditional re-enable caption (L8).
   - Flag ordering (L9).
   - Title sanitization (L10) and cwd control-character rejection (L11).
   - Pipe-based Codex intake (L12).
   - Skip observe for unsupported providers (L13).
   - Installer metadata (L14), marker mode (L15) and runtime-directory uid check (L16).
   - Change-only focus emission (L17).
   - The M8 refactor without behavior change.
===END_RECOMMENDATIONS===

===PR_READINESS===
Status: NEEDS WORK

Blockers:
- **H1:** a product decision on helper-required signaling.
- **M1, M2, M3:** source fixes with regressions.
- **M7:** test-suite integrity.
- **Native acceptance:** salience, readability, Go To across Spaces, active-cue UI, relaunch UI and real recovery remain unverified and must be recorded as such, not as passed.

Scope: complete original 71e0f60 product review versus e113fb8, covering all 83 primary targets and all nine PLAN phases through four complete partitions plus this synoptic source recheck.

Commit quality: unknown. Commit history was not supplied beyond recent scoped "fix:" subjects.
===END_PR_READINESS===

===SUGGESTED_PR_DESCRIPTION===
Not ready. Before a PR:
- Resolve and document the helper-required signaling boundary (H1).
- Retain cues across transient coverage or mapping unavailability (M1).
- Prevent synthetic tool-error restores from killing newer timers (M2).
- Correct recovery classification for confirmed-absent registry entries and already-restored native rows (M3).
- Bound wedged-target cleanup and workers, and cut helper fan-out and cached-record scans (M4, M5).
- Log and retry scheduler-path partial failures (M6).
- Remove or rewrite the stale priority-pinning suite and the vacuous assertions (M7, L18).
- Rerun the isolated Swift and shell suites.
- Record the native salience, navigation, active-cue, relaunch and recovery acceptance outcomes on dedicated surfaces, leaving any unobserved case explicitly unverified.
===END_SUGGESTED_PR_DESCRIPTION===

===REVIEW_META===
Execution path: claude-cli-explicit
Completion: full
Review mode: code-branch
Model requested: opus
Effort requested: high
Model observed: unknown
Effort observed: unknown
Input scope: 71e0f60 versus e113fb8; all 83 primary non-Markdown targets reviewed in four complete-source partitions (A=15, B=15, C=11, D=42), plus supplied dependencies and fresh SPEC, PLAN and API_REFERENCE requirements; synoptic source verification rechecked every product source target and the supplied subset of supporting test source directly
Focus: correctness, security, maintainability, test_coverage, performance
Limitations: tool-free external review; no executed tests/builds/native/UI; reported execution evidence is not independently rerun; full cumulative source/test scope; final synopsis rechecks supplied product and supporting test source, while remaining test bodies (including visual-recovery-tests, process-runner-tests, managed-output-entry-tests, terminal-visual-state-tests, sessions-model-tests, ghostty-catalog-tests, SchedulerTests, SchedulerLockTests, BroadcasterTests, hook-observations.bats, cmd-recover.bats, cmd-sync.bats) rely on the complete partition reads; baseline-capture harness and base-revision sources were not supplied; later parent corrections outside scope
Selected route: claude-cli (explicit caller selection)
Wrapper evidence: /tmp/claude-review-tavs-final-corrected-synoptic-wrapper-20261013.log
Whole-review allowance: 7200 seconds total; all five serial provider calls completed within that one allowance
Host verification elapsed: 4094 seconds from the original allowance start
===END_REVIEW_META===
