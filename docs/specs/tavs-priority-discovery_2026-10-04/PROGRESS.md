# Progress Log: Ghostty organizer and reversible focus

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md
**Plan:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/PLAN.md
**Status:** In Progress
**Mode:** Autonomous goal (active after operator resumption)
**Started:** 2026-10-07 22:46 CEST
**Last Updated:** 2026-10-14 20:55 CEST
**Version:** 4.50

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
| 9: Automatic attention focus | In Progress | 2026-10-13 00:48 | | 6e0aaee; earlier below/appendix | 661 Swift/4 failures;59 connected/4 Bats pass;177 Python historical | | Historical reviews retained; source fixes and native acceptance open |

Status values: Not Started, In Progress, DONE, Blocked. Test counts are entered only after runs.
SPEC tracking is `in-progress`, phase 9. Four implementation phases remain incomplete.
Phase 2 has tested source but cannot be marked DONE before required live acceptance.
Resolve its source checkpoint with `git log --grep='feat(phase-2): Add Sessions and priorities'`.
Resolve Phase 3 with `git log --grep='test: Isolate shell and Python test roots'`.
Checkpoints report hashes without separate self-referencing state commits.

## Appendices
- [Review source checkpoints](PROGRESS_appendix_phase-9_review-source-checkpoints.md)
- [PROGRESS_appendix_phase-9_focus-poll-coalescing.md](PROGRESS_appendix_phase-9_focus-poll-coalescing.md): completed polling source fix.
- [PROGRESS_appendix_phase-9_ordinary-helper-routing.md](PROGRESS_appendix_phase-9_ordinary-helper-routing.md): completed core and standalone routing.
- [PROGRESS_appendix_phase-2_launch-debugging.md](PROGRESS_appendix_phase-2_launch-debugging.md): finished launch/Dock source corrections.
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

### Phase 2 launch and Dock debugging

> Finished source corrections: [launch/Dock appendix](PROGRESS_appendix_phase-2_launch-debugging.md).
> Native acceptance remains Blocked. Historical runtime IDs require a current inventory.

### Phase 2 source checkpoint: 2026-10-12 10:02 CEST, live acceptance BLOCKED

> Finished Sessions source/build checkpoint: [Phase 2 appendix](PROGRESS_appendix_phase-2_launch-debugging.md).

> Finished review: [Phase 2 appendix](PROGRESS_appendix_phase-2_launch-debugging.md).

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
> Finished scope notes: [Phase 2 appendix](PROGRESS_appendix_phase-2_launch-debugging.md).

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

### Phase 7 source and copied-install checkpoint

> Finished source log: [Phase 7 appendix](PROGRESS_appendix_phase-7-renderer-foundation.md).
> Physical two-second timing, keyboard focus, hidden/split targets, light/dark ANSI/TrueColor,
> pane/Space navigation and locked-menu acceptance remain unverified. Phase 7 stays Blocked.

### Phase 8 renderer and dynamic writer foundations

> Finished source logs: [Phase 8 appendix](PROGRESS_appendix_phase-8-foundations.md).
> Current captured-set source and unresolved native acceptance remain below.

### Phase 8 captured-set source checkpoint

> Finished source/fixture history: [Phase 8 appendix](PROGRESS_appendix_phase-8-foundations.md).
> Native salience/readability, close/reopen and recovery-in-Manual acceptance remain unverified.

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

### Phase 9 independent preview clear

> Finished queue correction: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 focus cancellation evidence

> Finished prerequisite: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 per-target focus retirement

> Finished correction: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 recovery-stable reconciliation

> Finished correction: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 delivery reporting and retry

> Finished correction: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 helper compatibility diagnostic

> Finished checkpoint: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md). H1 remains open.

### Phase 9 measured helper cost

> Finished checkpoint: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 per-TTY cached lookup

> Finished checkpoint: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).

### Phase 9 preview preparation and replacement cleanup

> Finished source checkpoints: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).
> Historical managed-reset failure attribution remains unproven; current suite evidence is below.

### Phase 9 standalone metadata correction

> Finished metadata/source-sync checkpoint: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).
> H1 rendering and historical deadline attribution remain open in current entries below.

### Phase 9 fixture and identity/device foundations

> Finished source checkpoints: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).
> Historical failures and Linux/native acceptance remain unresolved in current entries.

> [Portable reader checkpoint](PROGRESS_appendix_phase-9-foundation.md). Full goal incomplete.

### Phase 9 portable ownership guard

> Finished source checkpoint: [Phase 9 appendix](PROGRESS_appendix_phase-9-foundation.md).
> Historical failure attribution, Linux and native acceptance remain open below.

> [Intent publication checkpoint](PROGRESS_appendix_phase-9-foundation.md). Full goal incomplete.

> [Ordinary transaction checkpoint](PROGRESS_appendix_phase-9-foundation.md). Goal incomplete.

> [Forced-reset checkpoint](PROGRESS_appendix_phase-9-foundation.md). Full goal incomplete.

> [Reconcile checkpoint](PROGRESS_appendix_phase-9-foundation.md). Full goal incomplete.

> [Context/publication checkpoint](PROGRESS_appendix_phase-9-foundation.md). Goal incomplete.

> [Caller/no-output checkpoint](PROGRESS_appendix_phase-9-foundation.md). Goal incomplete.

> [Dispatcher checkpoint](PROGRESS_appendix_phase-9-foundation.md). Goal incomplete.

> [Unbound intent checkpoint](PROGRESS_appendix_phase-9-foundation.md). Goal incomplete.

> [Capability/delivery checkpoint](PROGRESS_appendix_phase-9-foundation.md). Goal incomplete.

### Phase 9 ordinary helper routing and delivery

> Finished source checkpoints: [ordinary helper appendix](PROGRESS_appendix_phase-9_ordinary-helper-routing.md).
> Linux/native acceptance and historical initial-paint attribution remain open below.

### Phase 9 continuing focus color refresh: 2026-10-14 10:52 CEST

> Finished source 1: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

DjtXat caught a test Data.hasSuffix mistake; corrected before behavioral red r1e4Su (4 cases,
28 failures). Focused 3BGNKJ: 4/4; jqWujh: 48/48 after initial-only blocking fixture correction.
GQNGvE retains the old fixture's repeated-block failure. gPgVPv retains EPERM teardown; normal
permissions and inactive focus record remain inspectable. Last-closure fixture now awaits both
renewal and cleanup completion. rEYbJl/9IKEE0 initial-paint failures remain unattributed; a fresh
process reproduced preview failure first, so prior teardown is not a necessary cause. Test
recorder preserves physical target after correcting its nil-target draft. Do not widen 100 ms.
> Finished source 3: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

Next: instrument original initial-paint Boolean/error and open/prepare timing with exact target
semantics; verify slow-valid color lookup coalescing. Keep both attribution questions open.
Linux versioned records/kernel verification still await Docker/Linux-host choice; no startup
approval answer arrived. Native phases 2/7/8 remain Blocked and phase 9 remains In Progress.
> Finished source 4: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).


### Phase 9 slow focus preparation coalescing

> Finished source checkpoint: [focus poll appendix](PROGRESS_appendix_phase-9_focus-poll-coalescing.md).
> Native/Linux acceptance and historical timing attribution remain open in current entries.

### Phase 9 paint outcome diagnostics and revision fixtures: 2026-10-14 11:32 CEST

> Finished source 5: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

Seven fresh instrumented pairs pass: 8x3WjO, MNZYMg, lAxPbf, EKuMHz, nNohET, O3FRsJ, HbNQcQ.
No initial-paint failure reproduced; historical rEYbJl/9IKEE0 and EPERM attribution stay open.
Full TJMEY4 retained **570 tests, 3 unexpected failures**: forced-reset queued result timed out;
queued-render's later fresh render exceeded organizer deadline and its following read timed out.
The revision fixtures' paused-open barrier required full independent recovery/reset assertions
inside 100 ms. They now publish once under a bounded call, gate outside the device transaction,
then use the original prepare with exact target and a fresh real writer deadline. Captured revision
still must reject old style/title after full recover/resume. This changes test scope, not production
budgets. It does not explain the subsequent fresh-render timeout, which remains unattributed.
> Finished source 6: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

Next: scoped final review of current source, or Linux kernel checks after the pending host/Docker
answer. Capture original initial/fresh writer failures if they recur; passing retries cannot close
attribution. Native 2/7/8 remain Blocked, 9 In Progress, full goal active and incomplete.

### Phase 9 current reviews and schedule-load fix: 2026-10-14 12:46 CEST
[Codex full review](current-codex-review-2026-10-14.md): three calls, 118 supplied entries.
[Claude partial review](current-claude-review-2026-10-14.md): eight calls; final delivery/CLI call
exited 1 with empty diagnostics. No retry/substitute. AGY's developer fingerprint prerequisite
still blocks provider dispatch; neither source review establishes UAT.
> Finished source 2: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

> Finished schedule-load scope: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).
Next: fresh native/recovery checks, projection/release retries and compatibility/isolation fixes.
Linux ordinary code remains incomplete. Native 2/7/8 remain Blocked, 9 In Progress. No real install,
settings/schedules/native action or shutdown. SPEC/PLAN unchanged; full goal active and incomplete.

### Phase 9 fresh native effect validation: 2026-10-14 13:45 CEST
> Finished source 7: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

vpyTDw initial-paint attribution remains open in [its source check](effect-native-revalidation-source-check-2026-10-14.md).

### Phase 9 GUI recovery confirmation: 2026-10-14 14:18 CEST
> Finished GUI source: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).
Independent headless bookkeeping remains open; marker/metadata changes alone cannot prove restoration.
eoVi2e retained 190 tests/5 failures (1 unexpected): no Manual paint and a 20 ms intake deadline failure.
Neither timing cause is established; [full source/failure notes](final-review-corrections-2026-10-13.md#gui-recovery-cohort-correction-2026-10-14) remain available.

### Phase 9 failed release retries: 2026-10-14 14:36 CEST
> Finished release retry: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).
Active legacy cleanup can still reset fresh palette; [limits](release-retry-source-check-2026-10-14.md) remain unresolved.

> Finished projection retry: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).
> Finished quiet validation: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).
Prior LsYHBP614/14 timing failures remain unattributed in [its checks](quiet-bounds-source-check-2026-10-14.md).

> Finished provider checkpoint: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).
Both full616 runs fail (2/12 assertions); isolated controls pass. Goal/Phase9 remain incomplete; next diagnose timing/root trust and compatibility, with headless/Linux/native/palette limits open. No live actions.

> Finished record-read checkpoint: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

> Finished native trust checkpoint: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

> Finished marker checkpoint: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

> Finished checked-Scheduler checkpoint: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

> Finished native mute I/O: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

> Finished shared lock transaction: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

> Finished delivery diagnostics: [review appendix](PROGRESS_appendix_phase-9_review-source-checkpoints.md).

### Phase 9 writer deadline boundaries: 2026-10-14

661 full/4 failures retained;59 connected/4 Bats/release pass;prepare timeout located.
[Source/results](delivery-diagnostics-source-check-2026-10-14.md#parent-writer-boundary-verification).
Next: preparation work, delayed restore, portable parent bound; native UAT remains open.
