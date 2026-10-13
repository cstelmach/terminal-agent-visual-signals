# Progress Log: Ghostty organizer and reversible focus

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md
**Plan:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/PLAN.md
**Status:** In Progress
**Mode:** Manual (active Codex goal supplies continuation)
**Started:** 2026-10-07 22:46 CEST
**Last Updated:** 2026-10-13 07:47 CEST
**Version:** 4.6

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
| 3: Isolate shell and hook tests | DONE | 2026-10-12 10:57 | 2026-10-12 11:14 | e485618 | 33 Bats; 230 Python; 237 Swift | 17 min | Audited slices only |
| 4: Observations and ordinary background intent | DONE | 2026-10-12 11:41 | 2026-10-12 13:08 | Feature hashes below | 273 Swift; 55 Bats; 230 Python | 87 min | Record-only; fixture UI verified |
| 5: Persistent suspension and policy readers | DONE | 2026-10-12 13:23 | 2026-10-12 14:04 | Feature hashes below | 288 Swift; 110 Bats; 230 Python | 41 min | Reader/projection foundation; fixture UI |
| 6: Bounded independent recovery | DONE | 2026-10-12 14:23 | 2026-10-12 20:57 | 818fe5e, 0704512; earlier hashes below | 405 Swift; 100 selected Bats; 230 audited Python | 394 min | Source/owned PTYs verified; native acceptance stays in Phase 2 |
| 7: Safe previews and recovery controls | Blocked | 2026-10-12 21:07 | | Feature hashes below | 439 Swift; 62 selected Bats | | Source/fixture/copies verified; physical Ghostty pending |
| 8: Manual captured working set | Blocked | 2026-10-12 23:17 | | c7151ff, a982b9f; earlier hashes below | 466 Swift; 43 selected Bats | | Source and partial fixture verified; native acceptance pending |
| 9: Automatic attention focus | In Progress | 2026-10-13 00:48 | | eeed5cb; earlier hashes below/appendix | 520 Swift; 172 Bats; earlier Python below | | Final reviews complete; remaining source fixes and native acceptance open |

Status values: Not Started, In Progress, DONE, Blocked. Test counts are entered only after runs.
SPEC tracking is `in-progress`, phase 9. Four implementation phases remain incomplete.
Phase 2 has tested source but cannot be marked DONE before required live acceptance.
Resolve its source checkpoint with `git log --grep='feat(phase-2): Add Sessions and priorities'`.
Resolve Phase 3 with `git log --grep='test: Isolate shell and Python test roots'`.
Checkpoints report hashes without separate self-referencing state commits.

## Appendices

- [PROGRESS_appendix_phase-1.md](PROGRESS_appendix_phase-1.md): completed Phase 1 source log.

- [PROGRESS_appendix_phase-3.md](PROGRESS_appendix_phase-3.md): completed Phase 3 isolation logs.

- [PROGRESS_appendix_phase-4.md](PROGRESS_appendix_phase-4.md): completed Phase 4 record/intake source log.

- [PROGRESS_appendix_planning-and-goal-preparation.md](PROGRESS_appendix_planning-and-goal-preparation.md): finished initial planning and goal preparation.

- [PROGRESS_appendix_phase-7-renderer-foundation.md](PROGRESS_appendix_phase-7-renderer-foundation.md): completed renderer/controller and GUI/client logs.

- [PROGRESS_appendix_phase-8-foundations.md](PROGRESS_appendix_phase-8-foundations.md): finished renderer/writer source logs.

- [PROGRESS_appendix_phase-9-foundation.md](PROGRESS_appendix_phase-9-foundation.md): finished reducer/classifier source log.

## Log

> Phase 4 startup is complete. [Detailed log](PROGRESS_appendix_phase-4.md).

### Phase 3: DONE (2026-10-12)
> Detailed log: [PROGRESS_appendix_phase-3.md](PROGRESS_appendix_phase-3.md)
> Private test isolation and audited suites verified.

### Phase 2 development Dock app: 2026-10-12 10:37 CEST

The operator asked to debug opening and authorized a normal Dock app during development.
The isolated process was alive but accessory activation and a leading MenuBarExtra provided
no initial window. Changed only the isolated delegate to regular activation and made its
Sessions Window the primary scene. The owned staged bundle now sets LSUIElement=false.
Production app mode, scheduler, hooks, installed TAVS and personal settings are untouched.

Rebuilt after 237/237 Swift tests passed in 2.174 seconds; release build passed in 5.54 seconds.
Backups/logs are in `/tmp/tavs-dev-dock-20261012T083034Z/`. Revalidated and terminated only the
old owned test process 37876, replaced its staged binary and verified signature/plist. The
installed process remains PID 8198. The current development app is PID 46436, with activation
policy 0 (regular), and its Sessions window is open.

Computer Use successfully bound the app in 2.115 seconds. Screenshot/AX checks confirmed
the fixture banner, distinct duplicate rows, explicit missing observations and Focus Off.
Selecting the first row then Shift-selecting the third reported three selected rows. The
bulk priority menu exposed High/Normal/Low. A priority click was interrupted by user activity;
fresh state showed unchanged Normal values, so no successful edit is claimed. Stopped UI
changes and left the normal app available to the operator.

Resizing, completed GUI priority edits/relaunch retention and actual native pane/Space navigation
remain unverified. The window uses fake rows and simulated Go To. Phase 2 remains Blocked on
the required native acceptance; the master goal is still incomplete. No unchanged access retry,
new provider review, production install or real terminal effect occurred. See
[bug reference](../../BUG_REFERENCE.md) for cause, fix and prevention.

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

### Phase 1 completed implementation log

> Detailed log: [PROGRESS_appendix_phase-1.md](PROGRESS_appendix_phase-1.md)
> Native catalogue and navigation source completed; physical acceptance remains Phase 2 work.

### Finished planning and goal preparation

> Detailed log: [PROGRESS_appendix_planning-and-goal-preparation.md](PROGRESS_appendix_planning-and-goal-preparation.md)
> Approved goal preparation and initial plan are complete; current phase state remains above.

## Divergence Checks

### Phase 3

> Completed isolation notes. [Detailed log](PROGRESS_appendix_phase-3.md).

### Phase 2

- Seven planned source/test paths changed. The additional report is ordinary review documentation.
- The isolated launch branch is required by PLAN step 5; changing only HOME/registry would still
  construct the scheduler and register a temporary app at login. No adapter framework was added.
- SPEC changes are tracking frontmatter only; PLAN and the root hard-lock state remain untouched.
- Unit/build verification permits a source checkpoint, not a DONE phase or live acceptance claim.
  Recovery and previews remain future work; no OSC is added in this slice.

### Phase 1

> Completed native notes. [Detailed log](PROGRESS_appendix_phase-1.md).

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


### Phase 4: DONE (2026-10-12)
> Detailed log: [PROGRESS_appendix_phase-4.md](PROGRESS_appendix_phase-4.md)
> Typed record/intake source verified; physical provider cases remain unverified.

### Phase 5 started: 2026-10-12 13:23 CEST

Reoriented from clean 120c79d. Phase 4 completed authoritative source work; Phase 2 native
acceptance remains Blocked. The previous goal turn was progress: five source commits, one
review/fix record and passing connected verification. Phase 5 is independent policy-reader work.
Backups and scratch: `/tmp/tavs-phase5-20261012T132300/`.

Two read-only explorations cover scheduler/UI projection and shell/CLI/standalone readers.
The persistent marker remains `~/.tavs/visual-restrictions.state`, schema 1 plus suspended boolean.
The planned shared data format is canonical quoted SCHEMA_VERSION/SUSPENDED text, never sourced.
Active/suspended/unavailable statuses distinguish absent state from malformed existing state;
unavailable disables restrictions visibly. Malformed state is not treated as an active rule.

Scheduler must keep raw rule/lock/grant evaluation and timers while overriding the visual
projection. Suspension bypasses ordinary unmute replay as well as restrictive painting.
Standalone shellrc embeds the same small parser because its installer copies only that file.
Cross-language fixtures must pin classification, bounds and no evaluation of marker content.
This phase does not claim serialized repaint or queued-write cancellation, which belong to 6.


### Phase 5 complete: 2026-10-12 14:04 CEST

Persistent suspension uses the existing `.tavs` convention and canonical schema-1 text:
`SCHEMA_VERSION="1"` plus `SUSPENDED="true"/"false"`, two quoted LF-terminated lines.
Readers do not source data. Absent markers under accessible parents are active; valid true is
suspended; malformed, unknown, unreadable or special-file state is unavailable and disables
restrictions visibly. Shell and Swift writers atomically replace a regular marker. Explicit
false resumes configured rules instead of deleting definitions or resurrecting selective focus.

Bounded Bash 3.2/zsh reads were empirically probed for LF, NUL and saturation before use.
The standalone shellrc embeds the identical reader/predicate because only that file is installed.
One shared fixture matrix pins canonical and malformed classifications across both shells and
Swift. Native headless capability/read/write verbs run before UI launch and require explicit
absolute paths; unavailable read returns nonzero with a generic status.

All policy readers now fresh-read suspension above restrictions: trigger stage-0, stage-1,
worker ticks, effective-lock predicates and standalone startup. Normal observations/intent and
TTY registration continue. CLI status explains saved versus effective state. New locks are
saved but inert; suspended unlock/schedule edits bypass challenges and preserve definitions.

Scheduler still evaluates raw rules, merges lock/grant state and arms schedule, lock/grant-expiry
and heartbeat timers. It overrides only visual mute/hard-lock projection. Disabled state emits
no broadcaster operation, including startup discovery, pause/lock paint and ordinary unmute
reset/replay. Explicit resumption re-evaluates current rules. Configured master activation is
published separately so menu labels/actions cannot mistake suspended visuals for an active
master rule. Menu/icon/Preferences status consume that projection; Sessions reads its marker
before the in-flight catalogue guard, with a banner independent of catalogue availability.

**Verified defect/fix evidence.**

- A Bash missing-file check treated an inaccessible parent as active, unlike Swift's EACCES
  classification. A private chmod test produced red; nearest accessible-parent validation now
  keeps both readers consistent. Additional tests cover dangling/non-directory parents and
  genuinely absent nested directories. Canonical state and malformed controls never execute.
- The private app's first injected marker URL was beside priorities rather than in private HOME.
  A changed-path test went red before the constructor was corrected to `root/home/.tavs`.
- Mute debug logging used fixed `/tmp/tavs-mute-trace.log`. A source-only red avoided writing
  there. Logging now uses the injected runtime; the connected green asserts an owned trace.
  Existing unrelated/global trace files were not deleted or modified by this correction.
- Immediate quit/rebind produced transient macOS procNotFound (-600). Rebinding the same bundle
  succeeded with its persisted suspension banner; no product code or security workaround changed.

**Verification.**

- Full Swift: 288/288, zero failures, 2.488 seconds, `tavs-isolated.bTx0ZO/command.log`.
  Six state tests plus 64 focused lifecycle/lock/Sessions tests are included. Focused consumer
  red/green and private-root mismatch logs are recorded in the saved worker report.
- New/relevant Bats: 55/55 in `tavs-isolated.jEQIfH/command.log`: six shared-state, six native
  parity/core/gate and 43 lock/standalone cases, including 14 original worker red regressions.
  Existing three fixture-only shell installers were explicitly scoped to private rc/HOME.
- Earlier isolated Bats: 55/55 in `tavs-isolated.65Sfgh/command.log`; combined 110 cases.
- Audited Python: 230/230, 26.35 seconds, `tavs-isolated.X4ZtGs/command.log`.
- Release: successful in 24.36 seconds, `tavs-isolated.maC83i/command.log`.
- Every changed shell script passes its separate Bash syntax check; standalone also passes zsh.
  New Bats files were individually preprocessed and syntax-checked. Shared/standalone functions
  compare verbatim. ShellCheck passes with unchanged dynamic-source, cross-module-global and
  legacy mkdir-mode notices excluded (SC1091/SC2034/SC2174). No new warning was introduced.
- Whitespace and staged credential scans pass; `.env` remains ignored. SPEC prose is unchanged.

Runner log prefixes expand to `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/`.
Source backups and additional logs remain under `/tmp/tavs-phase5-20261012T132300/`.

**Computer Use.** Strictly signature-verified release fixture app is open at
`/tmp/tavs-phase5-20261012T132300/TAVS Development.app`. CUA confirmed the suspended banner,
persistence after quit/relaunch, unavailable marker status despite a failed catalogue refresh,
and explicit resumption with Focus Off. Catalogue navigation is labeled simulated. The private
app has no Scheduler, so real menu/icon rendering and physical terminal recovery are unverified.
No production install, existing app/session shutdown, live preference/schedule changes or
Ghostty safety-denial workaround occurred. No terminal repaint is claimed for suspension alone.

**Feature commits:**

- `a6dbacd`: paired persistent stores, safe headless entry, six state tests per language boundary.
- `ae4d100`: fresh shell/CLI/standalone precedence, scoped diagnostics and connected parity tests.
- `6924216`: scheduler/UI projection, preserved definitions/timers and existing documentation.

**Scope reconciliation.** 24 source/test/documentation paths changed in those three commits.
Additional connected view/menu/model tests implement required status without changing product
scope. Debug sink relocation is the narrow test-isolation correction in a planned touched module.
The parser copies preserve the existing single-file install boundary; no new dependency/service,
configuration hierarchy, watcher, daemon, lease or process-control mechanism was introduced.
Saved reports: [shell exploration](PHASE5-SHELL-EXPLORATION.md),
[scheduler exploration](PHASE5-SCHEDULER-EXPLORATION.md), [shell worker](PHASE5-SHELL-REPORT.md),
[scheduler worker](PHASE5-SCHEDULER-REPORT.md). These reports predate parent's final boundary tests
and debug correction; this entry records the final source/test results.

**Next:** Phase 6, bounded independent recovery across every writer. Re-read this package and
trace all device/pending/forced-reset paths. Keep one 100 ms deadline through fresh serialized
policy checks. Implement actual `tavs recover`/`--resume`, ownership invalidation, safe resets,
partial-failure reporting and no historical replay. Required independent recovery reviews follow
that phase. Phase 2 still needs native acceptance. Preview/manual/automatic phases remain
unfinished, and the complete Codex goal remains active.


### Phase 6 started: 2026-10-12 14:23 CEST

Reoriented from clean f067bef. Prior goal turn was progress: paired persistent stores and all
policy readers/projections committed with 288 Swift, 110 isolated Bats, 230 Python and fixture
UI evidence. Phase 2 native acceptance remains open. Phase 6 must establish actual ordered
independent recovery before previews, not equate disabled policy with restored pixels.

Three read-only explorations map bounded writer, target/effect binding and every shell/CLI
output route. Scratch/backups: `/tmp/tavs-phase6-20261012T142300/`. Begin with the shared writer
and binding foundations, then route callers and recovery through them. Whole phase remains
In Progress until every route, recovery result and required review is verified.

Use the original 100 ms deadline, open device before stable per-TTY lock, and re-read binding,
suspension and current policy inside it. Do not invoke existing store methods that reacquire
that same lock. Empty registry entries and generic I/O errors cannot authorize a target or
prove disappearance. Main-dispatched native catalogue callbacks cannot be awaited on a blocked
headless main thread. Preserve failures, explicit unavailable states and independent fanout.

### Phase 6 foundation checkpoint: 2026-10-12 15:13 CEST

Phase 6 remains **In Progress**. Independent recovery is not implemented end to end, and no
preview/focus phase is released. The active Codex goal still covers all nine PLAN phases.

**Committed features.** `dcb40d0` adds recover/--resume dispatch that persists the shared marker
before helper resolution/capability queries. Eight private stub cases pin missing/old helpers,
partial failure, unchanged saved definitions, persistence failures and help/argument behavior.
Native support is not yet exposed by the actual helper; it fails explicitly after persistence.

`bd27c08` adds managed writes with one original 100 ms caller/worker deadline, device open before
stable per-TTY serialization, original-deadline policy callback and late-byte rejection. Nil
policy skips output. Ten tests cover private lock inodes, paused open/policy, cleanup, timeout,
backpressure and healthy independent output. The coordinator must supply descriptor/binding/
current-policy validation and honor the original deadline before any record mutation.

`8fb1448` adds typed target/effect records and 14 tests. Fresh native capture verifies exact
mapping and continuing owner ancestry; cached restoration validates owner/device/app generation
without Automation. Unknown owner/device results remain unavailable. Confirmed physical/native
lifetime absence or replacement is vanished. Canceled IDs cannot revive through save/heartbeat;
selective leases use the same live controller and at most six seconds. Global rules remain a
separate current predicate. Under-lock record helpers do not reacquire the lock or add budgets.
An exact adopted native intent survives producer exit into its still-valid shell; its observation
and attention coverage end on exit. Unadopted owner-only intent remains conservative.

`c523a26` adds headless catalogue snapshot using the same native enumeration/request path, target
allowlist and two-second request bound. Explicit queue.async keeps native work off main; a
semaphore publishes completion without requiring the GUI event loop. Two new tests cover scope,
thread, permission and application-generation behavior. The API is for headless/background use.

**Failures retained and corrected.** The record-store behavioral run had eight assertions fail
because Foundation enumeration canonicalized /var to /private/var; canonical path comparison
now accepts its own records without weakening identity. A test-first adopted-intent case exposed
the unnecessary live-producer requirement during restoration. The first full 312 run then failed
the separately owned paused-open fixture: XCTest main-loop waiting consumed its real deadline.
`fb7fae7` replaces that wait with direct semaphore synchronization, retaining the 100 ms writer
budget and strict no-timeout/no-output assertions. No timeout was lengthened.

The first snapshot used queue.sync and failed its off-main assertion. Explicit asynchronous
enqueue corrected it. The focused failed log JANC6k and full failed log tBoXai remain preserved.
The failed full run was dispatched before the focused failure was inspected; subsequent full
verification ran only after the focused 14-case check passed. This was a verification-order
mistake, not evidence of a separate product defect.

**Final verification.** Private runner and explicit baseline-helper, shared scratch used serially:

- Writer: 49 focused and 298 full green before record integration (KDeu2t, P2qTlV).
- Records: 41 focused green (MluliS); original full failure 6qihzf remains in the worker report.
- Fixture correction: 57 focused (m4BK8A), full 312 (p0FX95), zero failures.
- Catalogue correction: 14 focused (xbPNad), final **314/314**, 4.045 seconds (dNHPF8).
- CLI stub green: eight cases (rr3A75). These prove dispatch/persistence, not restored pixels.
- Touched source/doc diffs and staged credential scans pass; .env remains ignored. No production
  install, real-home suite, live Ghostty operation, existing app/session shutdown or native safety
  denial workaround occurred. No new release build or physical recovery check is claimed here.

Log names expand under `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.<name>/command.log`.
Backups and shared build remain in `/tmp/tavs-phase6-20261012T142300/`.

**Reports.** [writer exploration](PHASE6-WRITER-EXPLORATION.md),
[binding exploration](PHASE6-BINDINGS-EXPLORATION.md),
[shell exploration](PHASE6-SHELL-EXPLORATION.md), [writer report](PHASE6-WRITER-REPORT.md),
[record report](PHASE6-RECORDS-REPORT.md), saved by b4947c5. Worker reports retain their original
test outcomes; this entry records later integration green. Current cmp shows the two Claude
hook JSON files are identical, correcting the shell report's stale claim. Its copy has that
source correction. Actual recovery discovery must preserve dedicated-target settings.

**Scope.** Existing modules and test files were extended; no dependency, daemon or second writer
engine was added. The connected GhosttyCatalog change is necessary to avoid headless callback
deadlock even though not named separately in Phase 6's file list. Foundation commits are split
by coherent feature; the large record/test diff stays together because its types, strict decoders
and held-lock operations form one contract. Source implementation uses the existing runtime,
kernel metadata, atomic file records, native queue and bounded writer.

**Next bounded slice.** Implement visual-recovery.swift coordinator/current typed composition
and connect actual headless support before advertising the managed capability. Revalidate opened
fd/binding and fresh suspension/global policy inside the same lock. Persist effects before paint;
invalidate temporary ownership/pending output, retain failed targets and fan out independently.
Discover effects plus registry plus available catalogue, with dedicated scope preserved. Route
Broadcaster, semantic backgrounds, standalone startup, forced idle reset and debug reconciliation;
never fall through to raw restrictive output or historical replay. Authenticate shell caller
generation rather than trusting passed PIDs. The remaining inner env-i tests need their explicit
helper/private roots carried before managed shell coverage runs. Resume must keep focus Off and
apply only current global rules. Required Phase 6 AGY/Codex reviews follow complete integration.
Phase 2 still needs native acceptance. Do not mark Phase 6 DONE from these foundation tests.

### Phase 6 typed coordinator checkpoint: 2026-10-12 16:32 CEST

Previous goal turn was progress, with verified foundations and clean 43914a0. This slice remains
Phase 6, not a preview/focus release. Source backups/build/helper are under
`/tmp/tavs-phase6-coordinator-20261012T152000/`. Worker builds and parent integration used one
shared scratch serially. Re-read all four dated state files and current source before edits.

**Features.** `29d2a1f` adds bounded current global policy. It reuses finite lock/grant predicates,
reads regular rule files under the original callback deadline, refreshes soft validity after
PID liveness, and rechecks suspension before returning. Unknown/malformed rules do not enable
restrictions; unsafe/unreadable files have fixed availability errors. No config/AppKit work is
introduced inside prepare. Schema 1 appends hard/soft cause and requested mute fields.

`2aa8ceb` connects those fields to Scheduler. Effective MUTED stays false during suspension;
requested mute, cause, finite expiry and resolved colors survive for independent resume.
Both projections are saved before visual reconciliation. Existing schedule/merge/timer policy
remains the authority. Old opaque replay callers still require replacement later in this phase.

`eee5573` adds unlocked intent publication and exact latest target-local copies. It uses the
existing lock/deadline, retaining public metadata-only publication timing. Bound plain/native
intent can survive producer exit only while its exact continuing target remains valid. An
unmatched delivery or another binding cannot borrow that authority. Corrupt/orphan bound records
remain explicit failures rather than guessed colors. The seven new store cases pass.

`30b61b9` adds visual-recovery.swift. It saves state before discovery, restores cached targets
while bounded native discovery proceeds, then includes available exact native bindings.
Registry files are discovery hints only; unknown entries fail visibly. Current policy/intent
composition, effect persistence before paint and cancellation run through the managed writer.
Recovery never reads/replays opaque pending bytes. Known failures remain cached; confirmed
vanished and unaffected results are separate. Catalogue unavailable is reported independently
and is not itself evidence of a failed live target, so cached recovery requires no Automation.
Dedicated scopes refuse cached owner-only bindings without an allowed native identity.

**Test evidence.** All commands used tests/run-isolated.sh, explicit baseline-helper and the
owned shared build. Runner logs have the same prefix recorded at the previous checkpoint.

- Policy/state: 30 focused (ufmmRB), 332 full (IfaRi2), zero failures/warnings.
- Scheduler integration: two new cases first failed five assertions (mOW1JT); added expiry
  check failed twice (TDyoDM), then 47 related (otS6Q3) and 334 full (NQ0pRg) passed.
- Locked intent: expected missing-API red (OtjDsw), 48 focused green (9IAQZj).
- Coordinator: missing-class red (cZLZPy); first compile caught the mock handler's nonescaping
  callback (opgSa9), corrected with the protocol's escaping contract. First behavioral run
  (ACx699) exposed a missing private home directory in the new fixture, then nine cases passed.
- Final 12 coordinator cases plus store/policy: **76/76** (KDl520). Final full Swift:
  **353/353**, zero failures/warnings, 4.128 seconds (URGfvx).

Owned PTYs prove marker persistence before discovery, no historical title/alert replay, current
requested soft resumption, cached plain-shell recovery without Automation, healthy repaint before
blocked discovery returns, effect presence before device bytes, uncertain versus vanished
classification, retained failures, strict dedicated scope and queued restriction rejection.
They do not establish physical Ghostty/native acceptance. No production install, real runtime
mutation, existing session/app shutdown, live native operation or denial workaround occurred.
No new release build, shell suite or public headless capability is claimed at this checkpoint.

Reports saved by d5941bb: [current-policy exploration](PHASE6-CURRENT-POLICY-EXPLORATION.md),
[policy worker](PHASE6-CURRENT-POLICY-REPORT.md), [locked-intent worker](PHASE6-LOCKED-INTENT-REPORT.md).
Original worker outcomes remain unchanged; this entry records later parent integration.
Source inspection verified a live wildcard cleanup in tests/integration/liveness.bats:23-26.
Do not run it until teardown and inner child environments are surgically isolated.

**Next.** Wire production Broadcaster and headless/internal managed entry points to VisualRecovery,
then shared/standalone shell registration, semantic background, forced idle reset and debug
reconciliation. Add a no-marker-mutation batch operation for ordinary broadcaster actions;
do not call recover() to paint normal rules. Keep native work off the UI thread and serialized,
revalidate each opened fd/current policy, preserve the original device deadline and current
nonbackground styling. Replace all opaque replay/failure/age pruning. Audit inner env-i helper
paths and use only owned PTY/scoped fixtures. Add actual helper/CLI tests before advertising
tavs-managed-output-schema=1. Resume and relaunch must clear selective ownership and leave mode
Off. Required AGY/Codex recovery reviews follow complete routing. Phase 2 native acceptance and
Phases 7-9 remain open; the full goal remains active.

### Phase 6 production routes verified: 2026-10-12 19:12 CEST

Phase 6 remains In Progress until independent review findings are verified and resolved. Phase 2
still lacks physical native acceptance; phases 7-9 have not started. The native goal stays active.

**Delivered.** Typed ordinary/registration/forced-reset operations (`f0cbc45`) now serve the shell
bridge. Mutation-free synthetic validation (`0ede632`) checks current delivery under the existing
writer lock, including background-disabled styling. Startup and cached-target corrections
(`be25dd8`) preserve unaffected shells and reject ambiguous/reused bindings. Headless entry
(`70400c2`) dispatches before UI/login, authenticates callers, retains explicit dedicated scopes,
persists suspension before discovery and reports partial failures. Broadcaster (`4bd7ce2`) uses
coalesced current-policy operations off main, clears only prior effects on relaunch and retains
failed candidates. Shell routing (`8970a77`) connects backgrounds, startup, forced idle resets
and debug reconciliation. Historical pending output is discarded; age alone cannot prune owners.

**Confirmed defects.** Startup register followed by unrestricted reconcile reset untouched
shells; focused prior-effect clearing fixes this. Canceled global effects still need foreground
cleanup if the original repaint failed. Legacy shell suppression accepted missing PID/heartbeat
and future heartbeat, contrary to managed policy; the shared reader now rejects them while
preserving legacy absent-schema behavior. Parent found one incorrect synthetic guard requiring
producer generation to equal the continuing shell owner's generation. The agent-child regression
failed before correction (`cktEMs`), then passed with independent producer/target checks in
`2ee25f7`. Actual nested Bash processes also prove distinct producer/owner metadata and successful
validation without output, intent, binding or effect mutation.

**Verification.** Every run used tests/run-isolated.sh, explicit source-built helper and private
roots. Logs share `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.<id>/command.log`.

- Expected missing entry/API compile reds: gWja28 and kuyDvs. First integrated run mhaH36 found
  URL representation and simulated-future timestamp fixture errors. Only fixtures changed.
- Connected focused89 passed dN0urz. Initial full363 passed kILG2B with no warnings.
- Producer/owner correction: focused38 qtrw97 and full **364/364** nzPxDC, zero failures/warnings,
  3.956 seconds XCTest. Full count includes replacement of obsolete broadcaster replay/pruning
  contracts; the six original device-writer cases remain, as detailed in its report.
- Final **86/86 Bats** GJcrSl: background-intent10, managed16, mute-gate20, idle-worker-mute6,
  liveness7, shellrc19 and public recover stub8. Actual-helper cases include startup/current
  paint, forced reset, typed debug reconciliation and public recover/resume with marker-first
  persistence, current rule restoration and no historical title/standalone alert replay.
- Audited **230/230 Python** KbVIgI, 13.96 seconds. Existing unsafe worker/root exclusions remain.
- Debug build XZJOkR and release build rSkegw pass; release builds in 17.72 seconds, no warnings.
  Release public recovery HplRgE and distinct nested-producer lCZUuu each pass an owned-PTY case.
- Separate Bash syntax on six changed shell files, zsh shellrc, diff checks and staged credential
  scans pass. `.env` remains ignored. Existing cross-module ShellCheck notices were retained.

Preserved fixture failures include wrong context provider, missing observation, interactive
foreground mismatch and same-group fallback. Static scoped catalogues require job control off;
they do not prove Ghostty's actual foreground mapping. The separate unscoped nested-producer case
uses real owned Bash job control without native discovery. A suspected absent-schema mismatch
was falsified by its passing regression before any source edit. Do not weaken producer, scope,
foreground or original-deadline checks to make those fixtures pass.

**Reviews.** Codex (`/root/review_phase6_codex`) and Claude (`/root/review_phase6_claude`) are still
running one independent read-only call each, with no tests/native interactions or cross-reading.
Their snapshots can precede `2ee25f7`; verify findings against current source before any fix.
AGY did not invoke its provider: its developer-level reviewer contract required a repository
fingerprint prohibited by the project's No Bureaucracy Theater instructions. The archived
failure report is not a code verdict. No retry or host-model replacement was presented as AGY.

**Docs and scope.** Architecture, hard-lock recovery reference and BUG_REFERENCE describe the
new behavior. Worker reports survive in this package as phase6-broadcaster-routing-report.md,
phase6-synthetic-validation-report.md, phase6-headless-managed-report.md and
phase6-shell-routing-report.md; phase6-agy-review-failed.md preserves the technical failure.
Store/core/entry/broadcaster changes were split into separate verified feature commits. The six
shell callers and their connected fixtures form one atomic all-writer migration; splitting it
would leave raw or stale output paths in a transitional commit. The extra small headless module,
decoder access modifier and connected fixture repairs are necessary integration scope, not new
product features. No dependency, adapter, stronger lock or generic OSC parser was added.

**Next.** Collect the two reviewer reports, inspect concrete findings in source, resolve material
issues and record Phase 6's review outcome before starting Phase 7. Do not rerun passed suites
without a new change, failure or unresolved concern. No source has been deployed into the working
app. Physical Ghostty pixels, native job-control mapping, Spaces/minimized-window behavior and
real provider events remain unverified; the prior Computer Use denial must not be bypassed.

### Phase 6 review findings and first correction: 2026-10-12 19:48 CEST

Both available reviews returned CONCERN, 6/10, rather than release approval. Codex completed one
read-only pass. Claude's Hub request exceeded 1800 seconds; its mandatory wrapper used the visibly
degraded claude-p fallback. The archived report preserves that warning and its transport TODO.
The Hub issue belongs to that other project, not this source implementation. AGY still has no
provider verdict. No review was rerun against a new hash, and no source fingerprint was added.

Parent confirmed Codex's suspended-startup and raw-style findings directly in current source.
Its alias duplicate observation overlaps Claude's more serious alias-dependent intent composition.
Claude's source-verification appendix also confirms ended-owner classification and transient idle
failure behavior. Intent loss before device entry is a confirmed path; its remedy still needs a
bounded design that preserves target validation, stale ordering and the original device deadline.
The original review reports remain unchanged evidence of their snapshots, not post-fix approvals.

**Fixed: Codex R1.** `cd17388` makes startup request typed cleanup even with suspended/unavailable
state, performs cached-effect cleanup before native discovery, and permits safe transition cleanup
into suspension after saving policy. Saved rules/grants and disabled restrictive paint are tested.
The first test-only compile typo is retained as RFpdMA; actual behavior failed 23 assertions in
HJvJuu, including three PTY timeouts behind native discovery. Focused67 F38C1k and full367 BnDgf8
pass without deadline relaxation. Source verification and report are archived. Only a comment
changed after full green, so no additional suite repetition was needed.

**Open and next.** `/root/implement_phase4_record_store` owns the next bounded alias/lifetime fix:
visual-recovery.swift, terminal-visual-state.swift and their two tests, plus the shared Swift build.
Its agreed hypothesis uses validated TTY/device/continuing-owner identity for physical grouping,
shares exact-latest bound intent across aliases, resolves a unique native alias for ordinary hooks,
cancels matching alias effects under one existing lock and reports/writes once per physical target.
Proven owner-generation end is vanished; unavailable metadata remains unavailable. No retirement,
record deletion, schema, generic adapter or weakened native-scope check is authorized for that slice.
Do not edit those four files or build concurrently until it releases them.

Then implement Codex R2's complete typed current-invocation render. The read-only caller census
and minimal finite 23-slot transport are archived in phase6-managed-style-design.md. A single
managed transaction must choose current restrictions or complete ordinary palette/background/
title/image/fresh-bell output. Style-only requests do not publish reset intent. Synthetic checks
repeat inside that transaction; title-last-set persistence follows actual ordinary delivery.
Updating the old shell flag or rechecking just before printf leaves the demonstrated race.
No opaque style history, generic OSC parser, new dependency or subprocess control service is needed.
Ghostty is the fixed release scope; preserve the existing optional Kitty image backend and record
its separate legacy limitation without claiming all-backend repair or adding a Kitty adapter.

Also resolve Claude's idle retry gap (retain the last successfully applied stage and stop only
for actual stale delivery) and design/test ordinary-intent retention when device entry fails.
Phase 6 remains In Progress; previews and later focus phases have not started. The release/PTY
checks recorded above precede the scheduler correction; latest full source evidence is 367 Swift.

Review files now saved: phase6-codex-recovery-review.md and phase6-claude-recovery-review.md.
The latter preserves its degraded execution banner, reviewer recommendations and separate host
source-verification appendix. Its assertion that all writers are routed does not close Codex R2:
ordinary palette/title/image writes remain outside the managed transaction and can race a rule.
Root read the full evaluated findings and keeps that confirmed gap open.

Current committed source is cd17388 (367 full Swift). Alias/lifetime worker is active; it may
leave owned red-test/source edits in its four paths before the next continuation. Preserve them
and wait for its source/build release before any competing compilation. The next goal iteration
continues Phase 6, collects that worker's result, verifies it, then implements the finite typed
render and remaining idle/intent issues. No new phase, product decision or live deployment has
been started. Full captures above are historical; the current mid-task review stub will be folded
into a later capture. Goal stays active. Physical acceptance and stronger locks remain gated.

### Phase 6 aliases and complete renders: 2026-10-12 20:39 CEST

Previous goal turn was progress. Reoriented from d745e02 and confirmed the alias worker live;
no goal completion or blocked state is warranted. Phase 6 remains In Progress.

65f52c1 fixes plain/native intent and effect composition, physical write/report duplication and
proven-ended classification. Unknown metadata remains unavailable; conflicting live aliases fail.
The worker found a legacy same-ID/rdev changed-owner adoption leak after full378 green. It was
reproduced and fixed without a schema or retirement: live adoption snapshots exact owner-bound
intent, while legacy fallback requires the live exact owner. Final focused86 pBMxVx and full379
uc68Lh pass. All four owned paths were released before renderer compilation.

3a718d0 defines the finite 23-NUL-field UTF-8 render payload; fcb684a composes whole ordinary style
or current restrictions inside the existing lock/deadline. Style-only requests neither publish
reset nor read unrequested background intent. New parser, prepare-time policy flip, selective
lease, stale whole-batch and authenticated entry tests cover the contract. Expected missing-type/
API reds: 1oOwYO, 1YAYQF, OxI7De. Joined emoji exposed Foundation controlCharacters rejecting
format scalars (5Grkj7); explicit C0/C1 validation preserves emoji. A corrupt unrequested intent
stopped style-only output (hhdsmj); lazy background composition fixes it. Focused57 hTJPWD and
full390 Z2PMal pass without warnings. Explicit helper build9nYwxU passed before actual CLI tests.

666c950 routes the connected shell callers through one ephemeral current batch, flushes before
forking workers, defers title-last-set persistence until rendered, and retries transient idle
failure without advancing its applied stage. Only actual stale status3 stops the worker.
Old raw style writes/encoders were removed from the four style families. The optional Kitty
image subprocess remains an explicitly separate legacy feature outside this Ghostty release.
Actual helper integration53/53 I36HTq passes: background12, managed22, idle6, emit6, liveness7.
Audited Python230/230 2NwdoZ and scoped title/idle/persistence58/58 0DBw00 pass. Six separate Bash
syntax/diff checks and queued trace-label follow-up y6HCOc pass. No live/native Ghostty ran.

R4 remains open. Read-only explorer confirmed dropped intent before device entry but showed that
publishing after timeout starts another budget, while an already-expired budget cannot retain it.
The accepted foundation is semantic publication/binding before device open under the SAME100ms
worker deadline and stable record lock, released before open; opened-device output still takes
its lock after open and repeats stale validation. Device failure remains failure. A publication
lock held for the whole budget must fail truthfully without an extra budget or late mutation.
This explicitly distinguishes semantic publication from holding output serialization during open.

/root/implement_phase4_record_store owns ProcessRunner.swift, terminal-visual-state.swift,
MockProcessRunner.swift and their two existing test files for R4, plus the shared Swift build.
Root owns visual-recovery/entry wiring. APIs agreed: writeManagedToDevice(path:lockURL:beforeOpen:
prepare:) with one optional deadline callback, and target-aware publishIntent(_:to:synthetic:
intakeAt:deadline:). A new four-argument mock seam preserves faithful callback/deadline forwarding;
legacy three-argument handlers remain for nil callbacks, and incompatible forwarding must fail.
Do not overlap those five files/builds. Shell worker released all 13 connected paths after green.

Worker/explorer reports are durable as phase6-alias-lifetimes-report.md,
phase6-render-shell-report.md and phase6-intent-retention-design.md. No source is deployed;
physical native acceptance remains unverified. Next: finish/test R4 foundation and root wiring,
then record all review dispositions before Phase 7. No new product decision, hook, adapter,
stronger lock, generic OSC parser or control plane was added.


### Phase 6 COMPLETE: 2026-10-12 20:57 CEST

818fe5e adds deadline-bound pre-open publication and exact lifetime binding; 0704512 wires
ordinary color/reset and full renders. The metadata lock is released before device open.
Preparation repeats stale validation under the output lock. Style-only requests publish no
background. Malformed forced-reset titles fail before publication. Failed delivery remains failure.
Full-budget publication-lock contention cannot retain intent and receives no second budget.

Foundation missing-API red ME0UfZ preceded 83/83 focused green 94ycmO. Parent behavioral red
E5EXgN had seven assertions across three tests. Wiring yielded focused121 green jCKqYd.
Added a newer-intake-during-open race. Full405 WQ84I6 caught only the fixture's future timestamp;
advancing its clock fixed it. Final full405 smUB0P passes in 4.334 seconds without warnings.
Release build e4etSg passes in 10.29 seconds. Logs remain in the isolated runner directories;
backups/builds are in `/tmp/tavs-phase6-routing-20261012T165000/`.

Current release-helper verification: 100/100 Bats RqPiYw (background12, managed22, idle6,
emit6, liveness7, CLI recovery8, mute-gate20, shellrc19), including actual scoped public CLI
recovery/resumption and owned-PTY whole-render races. Audited Python230 WKHXsg passes in 10.86s.
These suites use private roots and explicit helper paths. No actual Ghostty automation occurred.

Review disposition: Codex R1 suspended cleanup fixed cd17388, R2 coupled styling fixed
fcb684a/666c950, R3 duplicate aliases fixed 65f52c1. Degraded Claude R1 alias intent and R2 proven
ended owner fixed 65f52c1, R3 transient idle retry fixed 666c950, R4 intent retention fixed above.
Each finding was source-verified before correction and has targeted regressions. Historical review
verdicts are preserved, not relabeled as approval of later source. AGY supplied no verdict before
provider execution; its recorded technical limitation was not retried or bypassed.

The five-file worker report is saved as phase6-intent-retention-report.md; its handoff boundary
claims foundation83 only. This parent entry records final combined results. API_REFERENCE.md
now documents public recovery and finite typed output. BUG_REFERENCE.md records cause/fix/tests;
hard-lock reference reflects review limitations. Source, documentation and credential checks pass.
Scope: seven connected Swift source/test paths for retention plus three API/bug/reference docs;
all implement Phase 6 ordering and review fixes. No schema, raw output history or new hooks.

Phase 6 DoD is satisfied for source and owned PTYs without the menu event loop. Phase 2 remains
Blocked on physical Ghostty/UI acceptance. No install, sync, real preferences/schedules or existing
process shutdown occurred. Goal remains active and incomplete. Next iteration: Phase 7 safe
two-second previews and recovery controls, using this writer foundation; PLAN and SPEC body fixed.


### Phase 7 renderer foundation

> Completed renderer checkpoint. [Detailed log](PROGRESS_appendix_phase-7-renderer-foundation.md).

### Phase 7 controller/configuration foundation

> Completed controller checkpoint. [Detailed log](PROGRESS_appendix_phase-7-renderer-foundation.md).

### Phase 7 GUI preview/recovery checkpoint

> Finished fixture/client log: [Phase 7 appendix](PROGRESS_appendix_phase-7-renderer-foundation.md).
> Required physical acceptance remains Blocked in the current Phase 7 checkpoint below.

### Phase 7 source and copied-install checkpoint: 2026-10-12 23:05 CEST

Continued from `185e4d2` with clean source. `0efa3c4` copies the root dispatcher, Claude/Codex
adapters, both hook JSON files, plugin shell source and Codex installer. Required directories,
copy operations and execute-bit repairs propagate errors, including conditional Bash callers.
Core/CLI dependencies still use existing globs. No recursive sync, rollback service or new
installer mode was added. Earlier successful copies may remain when a later copy fails.

Seven new fake-install tests compare exact bytes and execute copied CLI recovery/help,
standalone shell installation/readers, Codex installation and disabled-visual Claude/Codex
intake. Direct scripts start at 0644 to reproduce stale modes. Preferences, schedules and lock
sentinels are preserved. Missing explicit helpers remain failures after suspension is saved.
Typed fixture logs contain only fixed provider/session identifiers; no raw payload logging.

Red `Cn3aV3` failed all six initial copy/dispatch/error cases. First green attempt `D33Qwd`
passed five but failed an expected path containing a double slash: the copied Codex installer
correctly normalized it. Normalized the test root, not production argv. Final seven cases
passed in `W0bqBi`. Selected regressions `n3orIs` passed 62/62 (sync, recover, shellrc,
managed-background and suspension parity). `BQPYDG` repeated seven copied-entry cases against
the newly rebuilt helper. bash -n and diff whitespace checks passed.

`cc1b515` retires the old Scheduler reset method after the menu replacement left only test
callers. Four action-only tests are removed; mixed scheduler suspension/unknown-state assertions
remain, as do current independent recovery/client regressions. Full Swift `Mz8PCt` passed
439/439 in 7.188 seconds without warnings. The previous 443 count included those four retired
tests. Release `o4lwtX` passed in 9.97 seconds, using the owned Phase 6 scratch build.
Read-only follow-up: `/tmp/explorer-tavs-sync-failure-cases-20261012.md`; source findings were
verified with failure injection and existing-mode fixtures. No native query or real-home sync.

Phase 7 implementation steps 1-5 now have source/owned-PTY/fake-copy/fixture evidence. Required
physical two-second +/-250 ms highlighting, keyboard focus, real hidden/split targets, ANSI/
TrueColor and light/dark content, pane/Space navigation and locked-menu use remain unverified.
Phase 7 is Blocked on these accepted native cases, not DONE. Earlier Ghostty Computer Use
access denial remains binding; no alternate native automation or unchanged access retry ran.
The prior staged fixture remains available; production app, schedules and sessions are untouched.

**Next:** Phase 8 manual captured working set may proceed from this verified source foundation.
Keep Phases 2/7 blocked acceptance visible. Read Phase 8 plan/spec and connected state/controller
callers before tests. One phase per next goal iteration; the master goal remains active.


### Phase 8 renderer and dynamic writer foundations

> Finished source logs: [Phase 8 appendix](PROGRESS_appendix_phase-8-foundations.md).
> Current captured-set source and unresolved native acceptance remain below.

### Phase 8 captured-set source checkpoint: 2026-10-13 00:44 CEST

Continued from clean `52b44a0`. `c7151ff` captures native IDs independently of selection and
priorities, keeps one Sessions timer alive while open or Manual, and coalesces current catalogue
updates on the existing worker. New surfaces stay outside; confirmed last closure ends Manual.
Missing/empty coverage retains membership and rejects queued paint. A verified working binding
is required before outside styling. Focus Off preserves preview; recovery/restart/resume leave Off.
Retired pins survive cleanup; expired ownership gets a fresh ID and old cleanup follows replacement.
`a982b9f` connects Sessions/menu controls, cleanup feedback and accessible working-set labels.

Red logs `c43ZeM`/`kChRMp` lacked controller/model APIs. `ilShW7` exposed old-clear output before
replacement; deferred cleanup corrected ordering. Review found unmapped rows falsely advanced
the common heartbeat. Regression `jsee8s` reproduced expired-ID reuse; all-mapped/no-failure
renewal made `JKIr5M` pass. `RZfoUp` failed on teardown directory recreation by unfinished
cleanup; waiting for its completion made `ebsONq` pass. No production semantics were relaxed.
Final `kvH5Sx` passed 17 controller cases, including blocked/coalesced work invalidation. Full
`Tic2GM` passed 466/466 in 7.593 seconds without warnings. Release `jNZdCo` passed in 10.23
seconds; selected managed-background/parity/recover/sync Bats `0tzzCW` passed 43/43. All used
tests/run-isolated.sh, explicit helpers and the owned Phase 6 scratch build. Whitespace checks pass.

CUA initially verified Manual controls and a captured first-row label while browsing selected
another row. The fixture had unavailable bindings/colors, so no dimming claim follows. Closing
its sole window ended that fixture. A test menu and WindowGroup experiments stayed alive but
CUA attachment timed out; the added fixture changes were retired, preserving the simple scene.
Later attachment still timed out, so close/reopen, accessible-label and recovery-in-Manual UI
acceptance remain unverified. Only exact owned PIDs were restarted; current fixture PID 76191.
Scratch/backups: /tmp/tavs-phase8-controller-20261013. The read-only report and adjudication are
preserved in phase8-controller-followup-2026-10-13.md. Finished Phase 7 GUI text moved unchanged
to its existing appendix, with a pointer and verified round trip to keep this file below 900 lines.

**Scope:** five Swift source/test paths named by Phase 8 plus API/bug/roadmap documentation.
No Scheduler change was needed; existing release composition reuses dynamic focus. PLAN and
SPEC body remain fixed. No real Ghostty call, install/sync, schedule edit or user-process shutdown.
Phase 8 source steps are complete; required physical salience/readability and window lifecycle
acceptance remain Blocked. The master goal stays active. Next iteration: Phase 9 pure occurrence
reducer and explicit Automatic mode, preserving all unresolved native acceptance in Phases 2/7/8.


### Phase 9 occurrence foundation

> Finished reducer/classifier log: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).


### Phase 9 controller and controls

> Finished source/fixture checkpoint: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 first review corrections

> Finished four-fix checkpoint: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 final reviews and confirmed closure

> Finished review/empty-catalogue checkpoint: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 priority-suite correction

> Finished isolated-test repair: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 unknown-cue correction

> Finished availability/renewal correction: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 delayed restore correction

> Finished synthetic-restore correction: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 recovery classification

> Finished registry-reporting correction: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 native device admission

> Finished admission correction: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 independent preview clear: 2026-10-13 07:47 CEST

Previous turn progressed through admission `ca27873`, recorded in `edd9528`.
`eeed5cb` gives preview and focus cleanup separate queues. Shared per-TTY output serialization,
exact-ID cancellation, target checks and the original device deadline are preserved.
Red `Q72Rts` failed the 0.5-second healthy-preview completion expectation while another target's
focus cleanup was held. Green `OpyL1V` passed all 33 controller tests. The regression checks
completion before unrelated release, exact reset bytes and canceled preview metadata on owned PTYs.
Final `HBwtxF` passed 520/520 Swift tests in 11.032 seconds without warnings; release `KcJkJV`
built in 15.83 seconds; current-helper `kzSZFO` passed 172/172 isolated Bats. All returned before
commit. No shell source changed. Backups: /tmp/tavs-focus-cleanup-20261013/backup/.

The retained source design proposes per-target leases within one logical focus run. Healthy
renewals must continue while one target retains its old exact ID/revision and one retiring
obligation. Missing didRenew cannot prove absence: record rename precedes a final deadline check.
Canceled metadata and an unaffected/no-paint result also cannot prove physical restoration.
Root verified both source paths. A focused cancellation-stage distinction is still required;
no new effect schema, persistent registry or generic result protocol is proposed or implemented.

**Next:** implement and test that per-target retirement bound, including same-refresh fresh IDs,
mode switches, unknown saves and outstanding repaint. The preview queue defect is resolved;
retained-run growth remains open. The previous finished admission block moved unchanged to its
existing appendix with reconstruction verified. SPEC body/PLAN remain fixed. Phases 2/7/8 remain
Blocked, Phase 9 In Progress, and the goal active. No native/app-control call, install, personal
settings/schedule change or user-session shutdown occurred. Required native acceptance is unverified.
