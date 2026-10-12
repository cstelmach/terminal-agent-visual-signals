# Progress Log: Ghostty organizer and reversible focus

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md
**Plan:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/PLAN.md
**Status:** In Progress
**Mode:** Manual (active Codex goal supplies continuation)
**Started:** 2026-10-07 22:46 CEST
**Last Updated:** 2026-10-12 10:19 CEST
**Version:** 1.5

## Session Metadata

| Field | Value |
|---|---|
| Agent Model | GPT-6 family self-report; exact served variant unobserved |
| Max Iterations | Not set; manual invocation |
| Context Strategy | One mode/phase per execute-spec invocation |
| Initial Source | e113fb8 |
| State Directory | The dated SPEC package, not the root hard-lock state |

## Phases

| Phase | Status | Started | Completed | Commit | Tests | Duration | Notes |
|---|---|---|---|---|---|---|---|
| 1: Native catalogue and exact navigation | DONE | 2026-10-12 07:59 | 2026-10-12 09:09 | 338c1c2 | 224/224 | 70 min | SPEC 1a foundation |
| 2: Sessions window and retained priorities | Blocked | 2026-10-12 09:25 | | Checkpoint by title below | 237/237 | | Source verified; live acceptance pending |
| 3: Isolate shell and hook tests | Not Started | | | | | | Before shell suites |
| 4: Observations and ordinary background intent | Not Started | | | | | | Record-only |
| 5: Persistent suspension and policy readers | Not Started | | | | | | SPEC 1b |
| 6: Bounded independent recovery | Not Started | | | | | | Every writer ordered |
| 7: Safe previews and recovery controls | Not Started | | | | | | SPEC 1c |
| 8: Manual captured working set | Not Started | | | | | | SPEC 2 |
| 9: Automatic attention focus | Not Started | | | | | | SPEC 3 |

Status values: Not Started, In Progress, DONE, Blocked. Test counts are entered only after runs.
SPEC tracking is `in-progress`, phase 2. Eight implementation phases remain incomplete.
Phase 2 has tested source but cannot be marked DONE before required live acceptance.
Resolve its source checkpoint with `git log --grep='feat(phase-2): Add Sessions and priorities'`.
The checkpoint reports its hash without a separate self-referencing state commit.

## Log

### Phase 2 launch recovery: 2026-10-12 10:19 CEST

The operator reported the Mac unlocked. Computer Use could not bind the fixture app. Process
metadata and logs distinguished early app exit from a blocked UI: launchd reported exit 1.
A Foundation-only probe reproduced root `/tmp/...` rather than `/private/tmp/...`, making the
literal test-root guard reject our valid isolated directory. The new regression failed with
Cocoa error 258 before correction. The guard now compares the resolved system temporary root
instead of assuming its spelling. This preserves personal-root and escaping-fixture rejection.
Prevention: `testIsolatedLaunchAcceptsTheSystemTemporaryAlias` covers the `/tmp` path used by
the staged bundle. No production schedule, registry or preferences are involved in this fix.

The first corrected run failed only on the new test's URL trailing-slash equality. It now
compares resolved paths; final full Swift suite passed 237/237 in 2.192 seconds. Release rebuild
passed in 5.64 seconds. Prior failure logs/binary were retained and the owned test bundle was
updated and re-signed. Logs: `red-tmp-alias.log`, `green-tmp-alias.log`, `final-tmp-alias.log`,
`release-tmp-alias.log`, `test-root-diagnostic.log`, and `staged-launch.log` in Phase 2 scratch.

The corrected isolated process stays running; installed TAVS PID 8198 was not changed. CUA
still timed out selecting the app without a window. Its bundle-ID and SystemUIServer attempts
also timed out. Finder actions used only the owned test directory and app; a new Finder tab
preserved prior tabs. Asked the operator to open the test menu's Sessions window so CUA can
bind it. No alternative UI automation was used. GUI/native acceptance remains pending.

The independent review predates this two-line temporary-root fix and its regression. The saved
report is historical source review, not a new approval of the revised target. Bug description,
cause, fix and prevention are recorded here; `docs/BUG_REFERENCE.md` does not yet exist.

### Phase 2 source checkpoint: 2026-10-12 10:02 CEST, live acceptance BLOCKED

Implemented the resizable Sessions scene and menu action, multiselection, explicit per-row Go To,
High/Normal/Low priorities and stable native-order sorting. Rows show title, exact TTY/native ID,
directory and explicit missing observations. Focus is Off; selection has no navigation or paint.
Priorities are atomically saved under the supplied URL and retained through TAVS restart for
valid native keys. Failed/ambiguously empty refreshes retain last-known data and disable actions.
Trusted nonempty catalogues reconcile missing bindings. The model owns its two-second timer.

Added an isolated Sessions-only app branch with explicit private storage and exact target scope.
It constructs no production scheduler, preference view, login-registration delegate or discovery.
Incomplete test environment rejects before UI startup. Fixture mode labels navigation as simulated;
native test mode filters metadata and rejects out-of-scope navigation. The production catalogue
remains unrestricted. No real app installation, personal settings change or session shutdown occurred.

Verification: 12 new tests, including store restart, generation changes, moves, selection/navigation,
failure retention, malformed/write-failed storage, timer ownership and isolated launch/target scope.
The initial red run failed on missing SessionsModel. Final full Swift run passed 236/236 in
2.283 seconds; release build passed in 7.69 seconds. Compile-only native script, staged plist and
code-sign validation passed. Two invalid-environment binary launches exited 1 before UI startup.
Logs, build and the fixture test bundle are in `/tmp/tavs-phase2-20261012T092559/`.

Independent Codex review completed successfully with the configured Sol/high route. Its original
CONCERN 7/10 finding assumed successful empty rows confirmed closure. Source verification falsified
that assumption: upstream Ghostty returns empty collections when scripting is disabled. The model
already reports unavailable coverage and disables navigation/edits. Finding dismissed, original
score retained. The wrapper's source evaluation is 8/10, Low risk, with no confirmed defects;
no revised provider approval is claimed. Installed-build equivalence is unproven.
Full outcome/disposition: [Phase 2 review](reviews/PHASE2-CODEX-REVIEW.md).

Live checks are unverified. `cua.getApp("Ghostty")` was denied for safety. Selecting the separate
fixture bundle then failed because the Mac is locked and automatic unlock could not complete.
The operator was asked to unlock; no response or alternative screen/control route was used.
The test bundle has fake rows and simulated navigation, so it cannot prove native pane/Space focus.
Window resizing, GUI multiselection, window-close timer lifecycle, Automation permission, exact
native pane navigation, hidden/minimized windows and other Spaces still require acceptance.

Next input: manually unlock the Mac for fixture UI checks, then obtain supported Ghostty tool access
or direct operator observations on dedicated native targets. Do not retry unchanged access failures,
paint working terminals or substitute title matching. Phase 2 stays Blocked; the master goal is
incomplete. The sequential plan's dependent phases have not started. Preserve this tested source
checkpoint and resume acceptance from here rather than rebuilding the feature.

### Phase 2 started: 2026-10-12 09:25 CEST

Re-read current state at clean 338c1c2 and selected Sessions/priorities. Backups and scratch
work live in `/tmp/tavs-phase2-20261012T092559/`. Tests will precede model/UI implementation.
Computer Use `cua.getApp("Ghostty")` was denied for safety by the tool. No workaround will be
used; actual native pane/Spaces acceptance is unverified. Independent model/unit and a staged
Sessions-only fixture app remain useful work. The isolated app must omit production scheduler,
discovery, settings and login registration, not merely substitute a temporary registry.

### Phase 1: Native catalogue and exact navigation COMPLETE, 2026-10-12 09:09 CEST

Added typed Ghostty surface/native process identities, bounded native/config subprocesses,
serialized refresh/coalescing and exact PID/ID/TTY Go To with focus confirmation. Readonly
metadata uses public proc_pidinfo and rejects missing/exiting generations. Request values are
JSON arguments, not interpolated source. Missing/ambiguous TTY rows remain explicit and
unactionable. Added Automation purpose text; UI remains the next phase.

Verification: 21 new tests; baseline 203/203 and final 224/224 full Swift tests passed in
2.104 seconds. The red run failed on missing implementation. Release build, compile-only
native script and plist validation passed. Foundation-only probes verified scalar/void-call
and truthy Objective-C nil behavior without Ghostty events. Existing 100 ms writer is unchanged.
Logs/build: `/tmp/tavs-phase1-20261012T075910/`.

Independent Codex review: SUCCESS, CONCERN 7/10 on the original target. Both confirmed findings
were source-verified and resolved: adapter-level permission/nil coverage and vanished-target
classification. The latter reproduced two assertion failures before its correction. Final
regressions passed; no new provider approval is claimed. Durable findings/dispositions:
[Phase 1 review](reviews/PHASE1-CODEX-REVIEW.md).

Decisions: PID-bound ScriptingBridge, exact objectWithID lookup, opaque generation/terminal key,
separate typed metadata and existing runner/mocks. A 1 MiB stdout cap reports oversized data
explicitly; raise only if a measured native catalogue requires it. No dependency or live setting
change, input, terminal paint, shell suite or personal-session interruption occurred.

Observation for Phase 2: disabled scripting can yield empty native collections. Do not infer
confirmed closure or discard retained priorities merely from an empty/unavailable refresh.
Real native/TCC/Spaces behavior remains unverified Phase 2 work, not a completed SPEC acceptance.

Next: Phase 2: Sessions window and retained surface priorities. Goal remains active.

### Phase 1 verification in progress: 2026-10-12 08:30 CEST

Baseline passed 203/203 Swift tests. New tests first failed on missing implementation
(`red-swift.log`). After implementing the native catalogue/process primitives, an XCTest
callback compile error was corrected without weakening assertions. The latest full run passed
222/222 tests in 2.280 seconds (`green-swift-3.log`); the release build passed in 7.58 seconds.
Logs and the owned scratch build are under `/tmp/tavs-phase1-20261012T075910/`.

Compile-only osacompile validated the native script and plutil validated Info.plist. A separate
Foundation-only JXA probe confirmed scalar unwrapping and zero-argument Objective-C invocation.
It sent no Ghostty AppleEvents. Process metadata uses public proc_pidinfo generation/device/group
fields; native requests use a PID-bound ScriptingBridge proxy and exact objectWithID lookup.
TTY ambiguity and current focus are checked before navigation; post-request generation and
focus confirmation determine success. Real Ghostty/TCC/Space behavior remains Phase 2 work.

Independent canonical Codex file/partial review is running in agent review_phase1_codex;
its CLI session is 42628 and intended report is `/tmp/codex-review-tavs-phase1-20261012.md`.
No review verdict exists yet. Phase 1 remains In Progress pending source-verified findings.
Do not rerun passing suites without a new edit/failure; inspect the live review handle first.

### Phase 1 started: 2026-10-12 07:59 CEST

The native Codex goal is active. Re-read SPEC/PLAN/PROGRESS/GOAL and selected Phase 1.
Worktree starts clean at a23acdc. Backed up touched existing files under
`/tmp/tavs-phase1-20261012T075910/backup/`. The phase covers bounded subprocesses, verified
process generations, native catalogue parsing and exact navigation; it performs no live
AppleEvents, terminal painting, installs or shell regression runs. Tests precede implementation.
Goal continuations authorize the next phase after this phase's verified checkpoint.

### Goal preparation: 2026-10-08 07:14 CEST

Created [GOAL.md](GOAL.md) after operator sign-off, "Looks good. Continue." The approved strategy
covers all nine phases with one execute-spec phase per goal iteration, automatic continuation
after verified checkpoints, targeted reviews after phases 1/6 and available final triple review.
Existing tests/commit/docs requirements and separate deployment authorization remain binding.

The exact copyable prompt passed the goal validator at 3560 characters. Source ownership,
all nine Not Started states, the GOAL refresher and unchanged SPEC/PLAN were checked. This
iteration saved the goal artifact only; no native goal activation, product edit, test suite,
app/device operation or real settings change occurred. Mode remains Manual until activation.
Next action: activate the Copyable /goal block in GOAL.md, which starts with plan Phase 1.

### Planning: 2026-10-07 22:46 CEST

Read SPEC v1.1 and execute-spec's orientation/planning references. No PLAN/PROGRESS existed in
this package, so selected PLANNING mode. There was no state collision or archive operation.
Created a nine-phase plan mapping the three agreed product phases to bounded implementation
slices, preserving D01-D18. Root PLAN/PROGRESS and SPEC content/frontmatter were not changed.

Two read-only exploration reports traced current native app and shell/test flows. Verified
the consequential findings in source: distinct timer instances are needed; recovery must retain
failed live targets and order every writer; shell test roots include HOME/runtime/tmp/XDG/TTY;
two Bats fixtures leak into live runtime; Codex notify needs metadata forwarding; copied paths
and old loaded workers must be tested before previews ship. Reused PauseVisual color math is
already present. Detailed consequences and concrete source/test scopes are in PLAN.md.

Verification for this iteration is document validation: phase/dependency consistency, required
sections, concrete paths, SPEC unchanged, safe exact staging and append-only capture preservation.
No build/test suite, hook, native request, OSC, install, schedule/config mutation or app/agent
termination was performed. Native/bundle and visible acceptance remain future phase work.

**Next:** Phase 1: Native catalogue and exact navigation. Start with its tests and current source.
Do not run shell regression suites before the isolation phase. If interrupted, read this file
and PLAN.md, then select the next incomplete phase through execute-spec.

## Divergence Checks

### Phase 2

- Seven planned source/test paths changed. The additional report is ordinary review documentation.
- The isolated launch branch is required by PLAN step 5; changing only HOME/registry would still
  construct the scheduler and register a temporary app at login. No adapter framework was added.
- SPEC changes are tracking frontmatter only; PLAN and the root hard-lock state remain untouched.
- Unit/build verification permits a source checkpoint, not a DONE phase or live acceptance claim.
  Recovery and previews remain future work; no OSC is added in this slice.

### Phase 1

- Eight planned source/test paths changed, all linked to the Phase 1 steps/tests.
- SPEC edits are limited to tracking frontmatter; PLAN and root hard-lock state are untouched.
- Added one review synopsis required by the GOAL milestone and refreshed GOAL activation metadata.
  These are state/review documentation, not additional product scope.
- Kept the runner's polling/draining responsibilities small; no dependency, adapter framework,
  service or process-provenance mechanism was introduced.
- Checks passed before the connected native-catalogue feature commit. No duplicate unchanged
  failure loop or unsafe real-home shell run occurred.

Planning previously changed only the package state files and required capture; those logs remain.

## Learnings (Cross-Session Memory)

### Project-Specific Patterns

- Reuse injected clocks/watchers/timers, with separate timer instances for separate owners.
- Preserve the original 100 ms device deadline; an unlocked marker precheck is not write ordering.
- Supply explicit Swift root URLs and every shell cache/runtime root for isolated testing.
- The package is Git-ignored; stage its new state files by exact path with `git add -f`.

### Common Errors & Solutions

- Do not confuse the root hard-lock PLAN/PROGRESS with this SPEC's state directory.
- Do not use opaque pending OSC replay as background restoration or cue evidence.
- Do not infer live rendering, Automation permission or agent resumption from source/tests alone.
