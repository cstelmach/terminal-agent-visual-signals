# Progress Log: Ghostty organizer and reversible focus

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md
**Plan:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/PLAN.md
**Status:** In Progress
**Mode:** Manual (active Codex goal supplies continuation)
**Started:** 2026-10-07 22:46 CEST
**Last Updated:** 2026-10-12 09:09 CEST
**Version:** 1.3

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
| 1: Native catalogue and exact navigation | DONE | 2026-10-12 07:59 | 2026-10-12 09:09 | Phase 1 feature commit | 224/224 | 70 min | SPEC 1a foundation |
| 2: Sessions window and retained priorities | Not Started | | | | | | SPEC 1a |
| 3: Isolate shell and hook tests | Not Started | | | | | | Before shell suites |
| 4: Observations and ordinary background intent | Not Started | | | | | | Record-only |
| 5: Persistent suspension and policy readers | Not Started | | | | | | SPEC 1b |
| 6: Bounded independent recovery | Not Started | | | | | | Every writer ordered |
| 7: Safe previews and recovery controls | Not Started | | | | | | SPEC 1c |
| 8: Manual captured working set | Not Started | | | | | | SPEC 2 |
| 9: Automatic attention focus | Not Started | | | | | | SPEC 3 |

Status values: Not Started, In Progress, DONE, Blocked. Test counts are entered only after runs.
SPEC tracking is `in-progress`, phase 1. Eight implementation phases remain incomplete.
Resolve the Phase 1 commit from `git log --grep='feat(phase-1): Add exact Ghostty catalogue'`;
the checkpoint reports its actual hash without a separate self-referencing state commit.

## Log

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
