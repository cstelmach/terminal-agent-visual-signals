# Progress Log: Ghostty organizer and reversible focus

**Spec:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md
**Plan:** /Users/cs/local/code/apps/terminal-agent-visual-signals/docs/specs/tavs-priority-discovery_2026-10-04/PLAN.md
**Status:** Not Started
**Mode:** Manual
**Started:** 2026-10-07 22:46 CEST
**Last Updated:** 2026-10-07 22:46 CEST
**Version:** 1.0

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
| 1: Native catalogue and exact navigation | Not Started | | | | | | SPEC 1a |
| 2: Sessions window and retained priorities | Not Started | | | | | | SPEC 1a |
| 3: Isolate shell and hook tests | Not Started | | | | | | Before shell suites |
| 4: Observations and ordinary background intent | Not Started | | | | | | Record-only |
| 5: Persistent suspension and policy readers | Not Started | | | | | | SPEC 1b |
| 6: Bounded independent recovery | Not Started | | | | | | Every writer ordered |
| 7: Safe previews and recovery controls | Not Started | | | | | | SPEC 1c |
| 8: Manual captured working set | Not Started | | | | | | SPEC 2 |
| 9: Automatic attention focus | Not Started | | | | | | SPEC 3 |

Status values: Not Started, In Progress, DONE, Blocked. Test counts are entered only after runs.
The implementation SPEC remains `draft`; planning is not an implementation-phase completion.

## Log

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

Planning only: two new package state files plus the required append-only session capture.
No product files were modified and no implementation phase is marked DONE.

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
