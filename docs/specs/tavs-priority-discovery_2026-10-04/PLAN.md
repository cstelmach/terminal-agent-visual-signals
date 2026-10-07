# Implementation Plan: Ghostty organizer and reversible focus

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md
**Created:** 2026-10-07
**Last Updated:** 2026-10-07 (Europe/Vienna)
**Version:** 1.0
**Agent:** execute-spec (manual, one phase per invocation)
**Source inspected:** `e113fb8`

## Prerequisites

- The SPEC is authoritative. D01-D18 stay fixed; no additional provider events or locks.
- macOS 13+, Swift tools 6.0+, Swift language mode 5, Bash 3.2 and zsh.
  The inspected host has Swift 6.3.3, Bats and the required shells. No new dependency is needed.
- Ghostty's installed dictionary must expose ID, TTY, foreground PID and native focus.
  Read the installed dictionary before constructing requests. Runtime permission/specifier
  behavior still needs dedicated acceptance; a declared property does not prove it works.
- New native control needs `NSAppleEventsUsageDescription` in the existing bundle plist.
- Build/test source before installing. Current installers can stop the real TAVS app and
  alter login items; they are not isolated test launchers.
- Keep this package's state separate from root PLAN.md/PROGRESS.md, which track hard locks.

## Dependency Graph

```text
1 Native catalogue -> 2 Organizer/priorities -> 3 Test isolation
  -> 4 Observations/intent -> 5 Suspension -> 6 Independent recovery
  -> 7 Previews -> 8 Manual focus -> 9 Automatic focus
```

**Critical path:** 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9.
This decomposes SPEC product phase 1 into plan phases 1-7, product phase 2 into plan phase 8,
and product phase 3 into plan phase 9. These are implementation slices, not new approval gates.

## Shared implementation and verification rules

Use Foundation, SwiftUI, Darwin and existing `Clock`, `FileWatcher`, `TimerScheduler` and mocks.
Keep small surface/priority values beside their consumer. Add no generic adapter interface,
server, database, ledger, extra binary or deployment stamps. New Swift filenames use kebab-case;
types/test classes retain Swift naming conventions. Create each module only when its phase needs it.

Every phase runs red/green tests for its contract, then the relevant existing regressions and
the full Swift suite. Run shell suites only after phase 3 establishes private roots. A reported
failure is not a successful empty result. Never weaken deadline, identity or privacy assertions.
Use the existing native 100 ms writer; never replace a failed managed write with direct printf.

Before phase 3, Swift commands use an allocated scratch build directory and fixture-owned URLs:

```bash
swift build --package-path src/macos/TAVSApp --scratch-path "$scratch_build"
swift test --package-path src/macos/TAVSApp --scratch-path "$scratch_build"
```

After phase 3, run these through `tests/run-isolated.sh`, which supplies private child roots.
For each modified shell file, run `/bin/bash -n path/to/that-file.sh` individually; also run
`/bin/zsh -n src/shell/tavs-shellrc.sh` when it changes. Do not pass several files to `bash -n`
and assume it parsed all of them. Shellcheck is available; inspect touched-line findings.

Private roots include child HOME, `TAVS_RUNTIME_DIR`, `TAVS_TMP_DIR`, `XDG_RUNTIME_DIR`, fake
TTY output and the explicitly built helper. Swift receives explicit URLs rather than assuming
HOME changes `FileManager.homeDirectoryForCurrentUser`. Live runs use a temporary bundle with
login registration disabled and a catalogue/output allowlist limited to dedicated surfaces.
An isolated registry alone does not constrain native discovery. Preserve real agents/settings.

Do not run real-home scheduling E2E, broad unisolated Bats/pytest, `tavs sync`, or installers as
test shortcuts. Keep complete failure traces in a temporary log. No fixed test filenames in /tmp.

Each phase may update this package's PROGRESS.md, the existing META-THINKING-CAPTURE.md and only
SPEC frontmatter `status`/`phase`/`updated` as directed by execute-spec. Do not rewrite SPEC prose
or PLAN during execution. Commit each connected feature with its tests after verification.
Stage exact owned paths; the package is ignored, so its new files require explicit `git add -f`.

## Phase 1: Native catalogue and exact navigation

### Implementation Steps

1. Extend ProcessRunner with a bounded native/config subprocess operation: drain both pipes
   while running, check exit status, terminate at two seconds and reap owned children.
2. Add verified process-generation and foreground-family inspection without command-line logging.
   PID alone and unavailable launch dates cannot establish identity.
3. Read native windows/tabs/terminals into typed snapshots keyed by Ghostty instance plus ID.
   Preserve native order, TTY, parent IDs, name/cwd and supported selected-tab information.
4. Serialize requests with at most one pending refresh. Go To revalidates exact ID/TTY and
   uses only focus/select-tab/activate-window. Inspect success before acknowledging navigation;
   timeout never authorizes a blind retry. No device paint or input action in this phase.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/process-identity.swift`: generation/TTY validation.
- `src/macos/TAVSApp/Sources/TAVSApp/ghostty-catalog.swift`: snapshots and native requests.
- `src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift`: bounded subprocess reuse.
- `src/macos/TAVSApp/Resources/Info.plist`: Automation purpose text.
- `src/macos/TAVSApp/Tests/TAVSAppTests/Mocks/MockProcessRunner.swift`: ordered results/errors.

### Tests to Write

- `src/macos/TAVSApp/Tests/TAVSAppTests/process-identity-tests.swift` (`ProcessIdentityTests`).
- `src/macos/TAVSApp/Tests/TAVSAppTests/ghostty-catalog-tests.swift` (`GhosttyCatalogTests`).
- `src/macos/TAVSApp/Tests/TAVSAppTests/process-runner-tests.swift` (`ProcessRunnerTests`).
- Duplicate names, moved tabs/splits, missing properties, PID/TTY reuse and denied access.
  Use owned children for pipe saturation, nonzero exits and timeouts; native requests are faked.

### Verification

- [ ] Typed fixtures retain distinct native surfaces even with identical titles/directories.
- [ ] Commands contain reads and explicit navigation only; absent evidence is unavailable.
- [ ] Requests terminate within two seconds without blocked-pipe/main-thread work.

### Definition of Done

- [ ] New tests fail before implementation, then pass with the full Swift suite.
- [ ] No OSC, AppleEvents to working sessions, dependency additions or default-factory launch.

## Phase 2: Sessions window and retained surface priorities

### Implementation Steps

1. Add a resizable Sessions scene and menu Open Sessions action, using the existing window-
   presentation pattern for TAVS. Selection must never activate Ghostty.
2. Add one observable model with High/Normal/Low persistence and native-order sorting.
   Reconcile confirmed closed bindings; failed refresh shows unavailable/last-known coverage.
3. Show all surfaces, directory, provider/state coverage and age; absent observations remain
   explicitly missing until phase 4 supplies records. Add multiselection and per-row Go To.
4. Refresh every two seconds while open. Use a separate TimerScheduler instance because
   Scheduler.loadAndEvaluate cancels its timers. Focus starts Off; omit unimplemented paint actions.
5. Add minimal test-root/target injection and disable login registration for isolated GUI runs.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift`: model and small priority persistence.
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift`: table and window lifecycle.
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift`: scene and isolated launch construction.
- `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift`: Open Sessions.
- `src/macos/TAVSApp/Sources/TAVSApp/ghostty-catalog.swift`: model request wiring if needed.

### Tests to Write

- `src/macos/TAVSApp/Tests/TAVSAppTests/sessions-model-tests.swift` (`SessionsModelTests`).
- Extend `src/macos/TAVSApp/Tests/TAVSAppTests/ghostty-catalog-tests.swift` for exact Go To.
- Test priority retention on TAVS restart, reset on Ghostty restart/new surface, selection
  without navigation and timer independence from the global scheduler.

### Verification

- [ ] Ordinary shells and duplicate rows remain distinguishable; priorities default to Normal.
- [ ] Dedicated-target Computer Use confirms resizable window, multiselection and exact pane Go To.
- [ ] Hidden tabs, minimized windows and another Space are checked without input injection;
  unsupported visibility is reported rather than guessed.

### Definition of Done

- [ ] Model/native tests and full Swift suite pass; isolated GUI launch touches no live state.
- [ ] Priorities survive only for valid native lifetimes and selecting a row writes no background.

## Phase 3: Isolate shell and hook tests

### Implementation Steps

1. Add one small test runner supplying private roots to its child command, leaving parent HOME
   untouched. Use it for Bats/pytest and later helper tests; retain logs on failure.
2. Fix idle-worker-mute's live runtime and mute-gate's unset-runtime case before running them.
   Test default selection with stubbed resolution/no real default-directory creation.
3. Make pytest's environment fixtures/helpers retain the private roots. Move priority-pinning's
   fixed temporary output into its fixture and check intended bytes rather than nonzero size.
4. Audit any remaining suite's overrides before invoking it. Explicit fake TTY prevents automatic
   resolution to a working terminal. No production behavior changes are needed for isolation.

### Files to Create/Modify

- `tests/run-isolated.sh`: child environment wrapper, no new framework.
- `tests/conftest.py`: private environment propagation.
- `tests/unit/mute-gate.bats`: safe default-root test.
- `tests/integration/idle-worker-mute.bats`: private runtime/cache/worker paths.
- `tests/integration/priority-pinning.bats`: owned output and meaningful assertion.
- `docs/BUG_REFERENCE.md`: verified test-isolation defects and prevention.

### Tests to Write

- `tests/unit/test-isolation.bats`: runnable child-root and propagation check.
- Extend the three changed Bats files to verify their output/runtime paths stay private.

### Verification

- [ ] Run the isolation check first, then affected suites through the new wrapper.
- [ ] The wrapper supplies HOME/runtime/tmp/XDG/helper/TTY overrides without printing private env.
- [ ] No fixture cleanup can target a real registry, pending file or unrelated process.

### Definition of Done

- [ ] Safe red/green checks reproduce the leakage without writing to the real defaults.
- [ ] Repaired affected tests and full Swift suite pass; broader suites run only after their audit.

## Phase 4: Typed observations and latest ordinary background intent

### Implementation Steps

1. Add small atomic per-TTY observation/intent records with schema, stable delivery identity,
   producer generation and lifetime adoption. Keep them separate from consolidated legacy state.
2. Extract bounded allowlisted metadata at adapter intake. Preserve permission mode/context/
   identity behavior, but stop raw JSON/free-form argv/stdin/process-argument debug retention.
   Before calling a new headless verb, establish support through the existing --validate-config
   entry with a safe query qualifier. Legacy helpers must exit through that known branch, not
   fall through unknown flags into SwiftUI. Unsupported helpers report unavailable coverage.
3. Repair existing Codex notify metadata forwarding: bash currently consumes the payload as $0.
   Parse supplied completion IDs without adding lifecycle hooks or handing JSON to core debug.
4. Update intent through send_osc_bg even when muted. Route idle OSC 11/111 through it; generated
   idle and delayed tool-error restoration retain intake identity and are not new observations.
5. Adopt records only against verified native/producer lifetimes, reject late reused-TTY records
   and populate honest row coverage. Records remain observational; no preview ownership yet.

### Files to Create/Modify

- `src/core/organizer-state.sh`: typed record/bridge helpers and explicit built-helper selection.
- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`: record parsing/adoption.
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift`: headless metadata/record entry points.
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift`: observations and age.
- `src/core/terminal-osc-sequences.sh`: intent publication at send_osc_bg.
- `src/core/idle-worker-background.sh`: semantic background routing and synthetic updates.
- `src/core/trigger.sh`: intake, debug privacy and delayed delivery identity.
- `src/agents/claude/trigger.sh`, `src/agents/codex/trigger.sh`: metadata-only delegation.
- `src/install/install-codex.sh`: existing notify argv forwarding, isolated configuration tests.

### Tests to Write

- `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-visual-state-tests.swift`.
- `tests/integration/hook-observations.bats`: debug-enabled sentinels, metadata/argv parsing.
- `tests/integration/background-intent.bats`: atomic records, idle and delayed updates.
- Include invalid JSON/shell syntax, absent helper, late producer, ten owned concurrent TTYs,
  supported/missing completion IDs and preserving allowed permission-mode metadata.

### Verification

- [ ] Prompt/tool/answer sentinels do not enter new records, diagnostics or parser errors.
- [ ] Titles/directories remain legitimate display metadata only, absent from diagnostic logs
  and automatic identity decisions; metadata-dependent existing behavior is preserved.
- [ ] Normal hook behavior retains legitimate metadata and latest intent while suppressed.
- [ ] Old records never attach to a new native lifetime; unknown records cannot signal attention.

### Definition of Done

- [ ] New tests, isolated relevant shell/pytest regressions and full Swift suite pass.
- [ ] Polling/idle/synthetic updates cannot create a new meaningful event or inferred resumption.

## Phase 5: Persistent suspension and consistent policy readers

### Implementation Steps

1. Add schema-1 suspension under the persistent .tavs root, atomic shell/Swift writers and
   strict data parsing. Define malformed/unknown state handling visibly; never source the file.
2. Apply suspension before global lock/mute in trigger stage 0, worker checks, standalone shellrc,
   CLI predicates and scheduler projection. Keep schedule/lock/grant definitions intact.
3. Show suspended status and inert new rules. Resume leaves selective focus Off. This phase
   establishes readers; it does not claim independent repaint until phase 6 completes ordering.

### Files to Create/Modify

- `src/core/visual-restrictions-state.sh`: shared persistent state read/write.
- `src/macos/TAVSApp/Sources/TAVSApp/visual-restrictions-state.swift`: matching Swift semantics.
- `src/core/trigger.sh`, `src/core/mute-gate.sh`, `src/core/lock-state-lib.sh`:
  fast/persistent gates.
- `src/shell/tavs-shellrc.sh`: matching standalone reader.
- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift`: suspension projection, preserve definitions.
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift`: explicit persistent state injection.
- `src/cli/cmd-status.sh`, `src/cli/cmd-lock.sh`: suspended versus configured status.

### Tests to Write

- `src/macos/TAVSApp/Tests/TAVSAppTests/visual-restrictions-state-tests.swift`.
- `tests/unit/visual-restrictions-state.bats`.
- `tests/integration/visual-restrictions-parity.bats`.
- Extend `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerTests.swift`
  and `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerLockTests.swift`.
- Extend `tests/unit/shellrc.bats` and `tests/unit/cmd-lock.bats` for overlapping rules,
  relaunch and inert newly saved locks.
- Share data fixtures at `tests/fixtures/visual-restrictions-state.json` across shell/Swift tests.

### Verification

- [ ] Persistent suspension survives new processes and loss of runtime files.
- [ ] All readers agree; valid suspension overrides soft/hard visual restrictions without challenge.
- [ ] Existing definitions remain identical and status explains explicit resumption.

### Definition of Done

- [ ] State/parity/scheduler/gate regressions and full Swift suite pass in private roots.
- [ ] No claim that an earlier policy check alone prevents a later restrictive paint.

## Phase 6: Bounded independent recovery across every writer

### Implementation Steps

1. Extend the existing device writer: one 100 ms deadline through open, nonblocking advisory
   lock, fresh in-lock binding/suspension/policy check, composition and write. Open precedes lock.
   Use a stable lock inode; do not replace/unlink an in-use lock to acquire another one.
2. Route global broadcaster writes, shell-start restriction paints, background writes, forced
   idle resets and debug replay through the managed typed path. Reject invalid queued/delayed work.
   Legitimate nonbackground hook styling stays intact; no arbitrary OSC parser is introduced.
3. Persist effects before painting every affected target, including unregistered plain shells.
   Cache verified binding and owner generation. Dead/six-second-stale ownership no longer blocks
   ordinary hooks; relaunch clears valid orphaned effects to latest intent/default.
4. Add headless recover and internal managed-write entry points before SwiftUI/login initialization.
   CLI persists suspension before resolving Swift. Recover invalidates ownership/pending output,
   then resets the validated union of effects/registry/available catalogue with OSC 104/110/111.
   Reuse phase 4's safe support check; an older executable must not launch its GUI on unknown flags.
5. Report restored/vanished/unaffected/failed separately and retain live failures. A hung GUI,
   denied Automation or missing helper never prevents persistence or healthy-target fanout.
   Resume keeps focus Off and cannot replay historical alerts/titles.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift`: shared headless/GUI recovery operation.
- `src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift`: ordered bounded managed writes.
- `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift`: typed policy and retryable candidates.
- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`: effects and owner heartbeat.
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift`: headless dispatch, no default scheduler start.
- `src/core/organizer-state.sh`: shared output bridge; unavailable helper is an explicit failure.
- `src/core/terminal-osc-sequences.sh`, `src/core/idle-worker-background.sh`, `src/core/trigger.sh`:
  every managed background/reset/replay path.
- `src/core/mute-gate.sh`, `src/shell/tavs-shellrc.sh`: current policy and startup routing.
- `src/cli/cmd-recover.sh`, `tavs`: recover/--resume and lazy dispatch.
- `src/macos/TAVSApp/Tests/TAVSAppTests/Mocks/MockProcessRunner.swift`: writer expectations.
- `src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift`: existing PTY regression cases.
- `docs/reference/hard-lock.md`, `docs/API_REFERENCE.md`: recovery semantics and command help.

### Tests to Write

- `src/macos/TAVSApp/Tests/TAVSAppTests/visual-recovery-tests.swift`.
- Extend `src/macos/TAVSApp/Tests/TAVSAppTests/process-runner-tests.swift`
  and `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-visual-state-tests.swift`
  for ordering/liveness.
- `tests/unit/cmd-recover.bats`, `tests/integration/managed-background.bats`.
- Owned PTYs: paused-before-open and paused-before-policy writers, late open, busy advisory lock,
  backpressure, healthy fanout, cached plain shell without Automation and confirmed/unknown exit.
- Stub missing/failed helper and paused GUI; prove saved suspension, nonzero partial results,
  unchanged definitions and no old title/BEL on recovery or later resume.

### Verification

- [ ] Every restrictive writer checks fresh policy inside the shared serialized write.
- [ ] Device caller returns within 100 ms; known healthy repaint completes within one second.
- [ ] Recovery reaches every safely bound affected shell and reports unsafe/live failures honestly.

### Definition of Done

- [ ] Race/PTY/CLI/gate tests and full Swift suite pass; no failure pruning defeats retry.
- [ ] Independent recovery works without the menu event loop and precedes any preview release.

## Phase 7: Safe two-second previews and recovery controls

### Implementation Steps

1. Add background-only composition over latest intent. Reuse PauseVisual's hex/contrast math
   where needed, without changing foreground. Resolve configured colors with bounded subprocesses;
   never claim those are arbitrary running-program colors or use OSC query/reply capture.
2. Selection restarts one two-second preview, clears deselections and preserves keyboard focus.
   Clear/Escape/window close restore latest intent or OSC 111. Keep separate preview/refresh timers.
3. Integrate Restore Visibility and Re-enable Visual Restrictions in GUI/status. Recovery clears
   previews, persists suspension and disables focus activation while allowing new harmless previews.
4. Replace global-pause release's opaque pending replay with legacy-color reset and current
   background recomposition. Merge the old Restore Terminal Colors action.
5. Fix exact sync packaging for CLI root/changed adapters and any standalone helper dependencies.
   Test copied readers and staged signed-bundle behavior, then refresh only proven owned old workers
   for authorized deployment. Do not use broad process killing or alter agent sessions.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/terminal-renderer.swift`: background composition and tint.
- `src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift`: preview/ownership lifecycle.
- `src/macos/TAVSApp/Sources/TAVSApp/PauseVisual.swift`: share existing color math if required.
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift`: preview controls.
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift`: preview UI.
- `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift`: recovery/status controls.
- `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift`: recovery/controller wiring.
- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift`: normal release composition.
- `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift`: composed output.
- `src/cli/cmd-sync.sh`, `src/cli/cmd-install-shell-integration.sh`: exact copied-file coverage.
- `src/cli/cmd-install-macos-app.sh`: source/staged bundle support only where needed for acceptance.
- `docs/reference/macos-menubar-app.md`, `docs/ROADMAP.md`: verified organizer/recovery delivery.

### Tests to Write

- `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-renderer-tests.swift`.
- `src/macos/TAVSApp/Tests/TAVSAppTests/focus-controller-tests.swift`.
- Extend `src/macos/TAVSApp/Tests/TAVSAppTests/sessions-model-tests.swift`,
  `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerTests.swift`
  and `src/macos/TAVSApp/Tests/TAVSAppTests/BroadcasterTests.swift`.
- `tests/unit/cmd-sync.bats`: copied CLI/adapters/helper paths in fake installations.
- Preview while meaningful/idle intent changes; missing intent, global precedence, owner death,
  relaunch, neutral dark/light tint, contrast and no foreground/palette/cursor/title bytes.

### Verification

- [ ] Dedicated Computer Use: selection preserves focus, two seconds +/-250 ms, immediate Clear/
  Escape, hidden/split targets, light/dark and ANSI/TrueColor. Bytes alone do not prove visibility.
- [ ] Copied readers agree on suspension; staged bundle permission denial is an explicit state.
- [ ] Recovery remains menu-accessible under locks and a separate process restores visibility.

### Definition of Done

- [ ] Renderer/controller/regression tests pass; SPEC product phase 1 acceptance is recorded.
- [ ] Unsupported or unobserved live cases remain Blocked/unverified, never marked passed.

## Phase 8: Manual captured working set

### Implementation Steps

1. Extend the existing focus controller with Off/Manual and Focus Selected snapshot semantics.
   Browsing and priority changes do not change the working set; new surfaces remain outside it.
2. Dim outside backgrounds readably; neutral dark/light shells must visibly change. Keep normal-
   text contrast at 4.5:1 or do not worsen a lower baseline. Report no safe effect as unavailable.
3. Focus Off restores current background. Losing the last working surface ends focus. Preview
   expiry and global-pause release recompose the captured set; restart/resume always leaves Off.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift`.
- `src/macos/TAVSApp/Sources/TAVSApp/terminal-renderer.swift`.
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift`.
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift`.
- `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift`.
- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift`: release recomposition wiring if necessary.
- `docs/ROADMAP.md`: manual focus acceptance and limits.

### Tests to Write

- Extend `src/macos/TAVSApp/Tests/TAVSAppTests/focus-controller-tests.swift`,
  `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-renderer-tests.swift`,
  `src/macos/TAVSApp/Tests/TAVSAppTests/sessions-model-tests.swift`
  and `src/macos/TAVSApp/Tests/TAVSAppTests/SchedulerTests.swift`.
- Captured set versus browsing, new/closed surfaces, preview overrides, priority edits,
  global-pause release, suspension/explicit resume, kill/relaunch and sleep/wake.

### Verification

- [ ] Dedicated live samples retain readable default, ANSI and TrueColor text with outside salience.
- [ ] Manual set survives browsing and pause transitions; all background clears use latest intent.

### Definition of Done

- [ ] Tests and full Swift suite pass; SPEC product phase 2 live acceptance is recorded.
- [ ] Focus Off is always reachable and no selective mode survives restart or recovery resume.

## Phase 9: Opt-in automatic attention focus

### Implementation Steps

1. Add one pure occurrence reducer beside existing focus policy. Baseline observations on enable;
   only new supported, correlated High permission/completion occurrences create cues.
2. Coalesce permission companions within a verified episode, keep supported completion IDs stable
   and treat ambiguous repeats as ineligible. Polling/synthetic idle cannot rearm or resolve cues.
3. While any eligible cue remains, emphasize all High surfaces and dim Normal/Low. Go To captures
   cue IDs before dispatch and acknowledges only those on verified success; later cues survive.
4. Resumption/reset/known exit/invalid binding/downgrade removes eligibility; zero cues releases
   dimming. Explicit Automatic/Manual switching is exclusive, and armed Automatic still refreshes.
5. Explain completion-only coverage and Go To acknowledgement. No inferred direct resumption,
   task success, navigation, input, permission approval or additional provider lifecycle hooks.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/attention-state.swift`: deterministic occurrence reducer.
- `src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift`: automatic mode and composition.
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift`.
- `src/macos/TAVSApp/Sources/TAVSApp/sessions-view.swift`.
- `src/macos/TAVSApp/Sources/TAVSApp/MenuContent.swift`.
- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`: only needed correlation fixes.
- `docs/ROADMAP.md`: automatic focus, partial coverage and acceptance.

### Tests to Write

- `src/macos/TAVSApp/Tests/TAVSAppTests/attention-state-tests.swift` (`AttentionStateTests`).
- Extend `src/macos/TAVSApp/Tests/TAVSAppTests/focus-controller-tests.swift`,
  `src/macos/TAVSApp/Tests/TAVSAppTests/sessions-model-tests.swift`
  and `tests/integration/hook-observations.bats`.
- Multiple High cues, permission companions, late arrivals during Go To, failed navigation,
  acknowledged repeats, new completion, stale binding, priority changes and mode switches.

### Verification

- [ ] Deterministic reducer and isolated hook delivery agree; completion means response end only.
- [ ] Dedicated UI shows acknowledgement leaves other cues active and zero cues restores salience.
- [ ] Unknown/uncorrelated observations never activate focus; completion-only limits are visible.

### Definition of Done

- [ ] New/affected tests and full isolated suites pass; SPEC product phase 3 acceptance is recorded.
- [ ] No automatic navigation; all three product phases' acceptance cases have explicit outcomes.

## Risk Areas

| Risk | Phase | Mitigation |
|---|---|---|
| Native dictionary differs from runtime or TCC denies access | 1-2, 7 | Capability checks and bundle acceptance |
| Duplicate identity, TTY/PID reuse or late records | 1, 4, 6, 9 | Verified generation, never title matching |
| Global timer cancellation stops organizer behavior | 2, 7 | Distinct existing timer instances |
| Fixtures alter live state despite temporary HOME | 3 | All runtime/tmp/XDG/TTY roots and explicit URLs |
| Raw debug payload or Codex argv loses metadata | 4 | Allowlist/sentinels and real notify-shape fixture |
| Queued paint defeats recovery | 5-6 | Fresh policy inside shared bounded serialization |
| Stalled device blocks healthy recovery | 6 | One original 100 ms deadline and independent fanout |
| Old copies/workers bypass the new policy | 7 | Exact packaging and owned-worker verification |
| Neutral backgrounds show no effect or obscure text | 7-8 | Visible dark/light acceptance plus contrast |
| Duplicate or unsupported cues rearm focus | 9 | Observed episodes, identity cutoff and coverage |

## Sequencing & Dependencies

| Phase | Depends On | Can Parallel With |
|---|---|---|
| 1 | None | None in this manual workflow |
| 2 | 1 | None |
| 3 | 2 | None |
| 4 | 1-3 | None |
| 5 | 3-4 | None |
| 6 | 1, 4-5 | None |
| 7 | 2, 4-6 | None |
| 8 | 7 | None |
| 9 | 4, 8 | None |

## Source-grounded planning notes

Fresh recon reports: `/tmp/explore-tavs-execute-swift-plan-20261007.md` and
`/tmp/explore-tavs-execute-shell-tests-plan-20261007.md`. Their implementation consequences
are captured above so continuation does not require those ephemeral files.

Verified sources: Scheduler.loadAndEvaluate cancels all its timer instance's timers;
Broadcaster prunes failures and replays opaque pending bytes; shellrc/idle/replay bypass writers
need shared ordering; session-state has an independent TAVS_TMP_DIR; Codex notify loses appended
JSON in bash $0; sync omits the CLI root and Codex wrapper. Info.plist lacks Automation purpose.
PauseVisual already supplies hex normalization and contrast/luminance math for reuse.

No source tests, native requests, installation, process termination or visual acceptance were
performed during planning. Apply execute-spec's frontmatter maintenance only when execution starts.
