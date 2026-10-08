# TAVS master goal: Ghostty organizer and reversible focus

Last Updated: 2026-10-08 (Europe/Vienna)
Version: 1.0
Human sign-off: Approved on 2026-10-08. Goal activation has not been requested.

## Recommended Strategy

Use one implementation-mode master goal for all nine PLAN phases. One execute-spec phase runs
per goal iteration; the next automatic continuation rereads state and starts the next verified
phase. Resume after compaction/restart from durable files. A normal per-phase checkpoint does
not complete the master goal. Activation is a separate operator action after this draft is approved.

## Rationale

The task is finite, substantial and verifiable. PLAN and PROGRESS belong to this exact SPEC;
all nine phases are Not Started at source commit 53d3cfe. The core acceptance surface is source
and isolated native/visual testing. A /goal fits better than a polling automation or another plan.
Existing manual continuation is replaced only for the activated goal, not by editing the PLAN.
No token budget was requested; no budget tracking, purchases or model overrides are proposed.

## Source Files

Project root: `/Users/cs/local/code/apps/terminal-agent-visual-signals`

- [SPEC.md](SPEC.md): D01-D18 and product acceptance.
- [PLAN.md](PLAN.md): nine implementation phases, source scopes and tests.
- [PROGRESS.md](PROGRESS.md): current implementation state and evidence.
- [GOAL.md](GOAL.md): approved operating policy and this exact copyable goal.

Read applicable AGENTS/CLAUDE rules and current phase source/test files as well.
The old root hard-lock PLAN/PROGRESS are not this goal's implementation state.

## Copyable /goal

Length: 3560 / 4000 characters. Copy this block from the project root to activate the goal.

```text
/goal Implement and verify all nine phases of the TAVS Ghostty organizer and reversible-focus SPEC. Finish source implementation and dedicated isolated acceptance, preserving D01-D18.

Before each phase or bounded slice, read and orient from:
@docs/specs/tavs-priority-discovery_2026-10-04/SPEC.md
@docs/specs/tavs-priority-discovery_2026-10-04/PLAN.md
@docs/specs/tavs-priority-discovery_2026-10-04/PROGRESS.md
@docs/specs/tavs-priority-discovery_2026-10-04/GOAL.md

Mode: implementation. Start at the next incomplete phase; currently Phase 1.

Work policy:
- Read applicable project rules and connected callers/tests. State a brief local plan, then execute exactly one PLAN phase per iteration using execute-spec and red/green tests.
- After a verified checkpoint, re-read durable state and continue in the next goal iteration. Do not wait for another routine phase approval. This goal supplies the continuation trigger; do not combine phases in one iteration.
- Reorient after compaction/restart, preserving verified work and failed-attempt evidence. Prefer existing helpers/native features; no speculative abstractions or new control plane.
- Commit coherent features with tests only after verification, staging exact owned paths. Update relevant docs, append PROGRESS evidence and required capture; only SPEC tracking frontmatter may change.

Success means:
- All nine phases and every SPEC acceptance criterion have passing evidence, including exact native targeting/priorities, two-second previews, stable manual sets, automatic cue coalescing/acknowledgement and independent persistent recovery.
- No unresolved material defects or unverified required live cases. Owned changes are committed and final acceptance/review outcomes are recorded; unrelated dirty changes are preserved and reported.

Constraints:
- Ghostty only, visual effects only. Preserve agents, keyboard input, schedules and user data; no guessed title targeting, raw payload logs, automatic navigation, new hooks or stronger locks.
- Recovery precedes previews; retain the 100 ms device deadline and fresh serialized suspension checks. No historical title/BEL replay.
- Use private preference/runtime/tmp/XDG roots, explicit Swift URLs and only dedicated live surfaces. No real-home scheduling E2E, unisolated shell suites, real install/sync/settings changes or shutdown of existing sessions without separate authorization. Follow project bulk/deletion approval rules; preserve secrets and .env.

Verification:
- Per phase: focused red/green checks, relevant regressions and full Swift suite with an owned scratch build. After Phase 3, use tests/run-isolated.sh for shell/pytest checks; syntax-check each changed shell file.
- Computer Use on a staged test bundle and dedicated targets must establish visible acceptance; bytes or dictionary declarations alone do not. Missing access leaves cases unverified.
- Targeted independent reviews after Phases 1 and 6; final codex-reviewer, claude-reviewer and agy-reviewer when available. Save reports in /tmp, verify findings in source before fixes, report technical failures honestly and do not blind-retry a failed provider.

Between iterations, report:
- Phase, changes, exact verification results, docs/state, commit and next phase.

Blocked stop condition:
- On missing access, required approval or an exhausted repeated-failure path, record commands/errors, attempts, remaining work and the exact next input in PROGRESS; stop dependent work. Never mark blocked or unverified work complete and never loop on unchanged approval state.
```

## State Authority

This file is the approved policy refresher; PROGRESS remains the implementation-state authority.
Creating this artifact does not start a native goal or complete an implementation phase. Upon
separate activation, goal continuations supply the next execute-spec invocation after each
verified checkpoint. Preserve the one-phase-per-iteration boundary without routine approval
round trips. Re-read these files after context compaction and before selecting the next phase.
Do not overwrite SPEC or PLAN or change phase statuses merely to create or refresh a goal.

## Validation Checklist

- [x] Prompt validator accepts this exact 3560-character text with four @ references.
- [x] SPEC/PLAN/PROGRESS ownership and phase order match; planned GOAL refresher resolves there.
- [ ] Meaningful phase tests, full Swift checks and safely isolated shell regressions pass.
- [ ] Dedicated Computer Use covers exact navigation, preview clearing, dimming and recovery.
- [ ] Targeted native/recovery reviews and available final reviews have source-verified outcomes.
- [ ] Current background restoration, 100 ms writes, persistent suspension and cue edge cases pass.
- [ ] No required case is silently skipped; failure/coverage distinctions and docs are accurate.
- [ ] Atomic owned commits preserve unrelated work; deployment approval remains separate.

## Stop Conditions

Success requires every acceptance case and all nine phases verified, not just a build or initial
organizer. Missing native permission, unavailable Computer Use or unresolved required live
acceptance is a blocker. Repeated failures need a new hypothesis rather than unchanged retries.
Record the smallest concrete blocker and next input; do not introduce a separate handoff system.
Use the native goal status tools according to their blocking thresholds when actually activated.
Stop before unapproved destructive/bulk operations, paid spend or real installation/state changes.

## Human Sign-off

On 2026-10-08 the operator replied: "Looks good. Continue." This approved the presented full
nine-phase master-goal strategy: automatic continuation between verified phases, targeted
reviews after phases 1/6, available final triple review, tested atomic commits and separate
authorization for real deployment/state changes. It approved saving this file, not activation.

The prompt validator returned VALID for the exact 3560-character goal. Source ownership and all
nine Not Started phases were checked against the current package. No implementation, test suite,
AppleEvent, OSC, installation, settings change or native goal activation was performed by the
builder. Run the Copyable /goal block above only when ready to start the implementation goal.
