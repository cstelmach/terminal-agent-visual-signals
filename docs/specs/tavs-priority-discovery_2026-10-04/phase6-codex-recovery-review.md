# TAVS Phase 6 Recovery Review

## Metadata

- Wrapper status: SUCCESS.
- reviewer: Codex delegated Sol; outer reviewer verified all raw findings against source.
- review_type: code.
- review_mode: gatekeeping for HIGH findings; coaching for LOW.
- tier: standard calibration; partial review at xhigh effort.
- date: 2026-10-12.
- Invocation: model sol, noninteractive, file mode, bounded Phase 6 recovery concern.
- Target: 43914a0..4bd7ce2 plus production shell working edits; in-session source commits
  2ee25f7 and 8970a77 were present when verified. Evaluation observed HEAD 95a90a0.
- Focus: identity, recovery ordering, stale delivery, all-writer coverage, partial failure and
  backward compatibility. Connected ProcessRunner, VisualRecovery, state/policy, broadcaster,
  managed entry/main, shell bridge/background/idle/mute/shellrc and recover CLI were inspected.
- Raw skill report: /tmp/codex-review-files-terminal-agent-visual-signals-tavs-phase6-recovery-20261012_190024.md.
- Evidence directory: /tmp/codex-review-artifacts-files-terminal-agent-visual-signals-tavs-phase6-recovery-20261012_190024.
- Thread: 01a1310e-f2fc-77c3-96f8-babe154916e6.
- Requested engine: sol. Configured model: gpt-5.6-sol.
- Requested level/floor: partial/high. Effective effort: xhigh.
- Increase reason: delayed writers, identity, fanout and original-deadline serialization interact.
- Continuations: none; post-launch effort increases: none.
- Elapsed: 1012.304 seconds. Whole-review allowance: 7200 seconds.
- Evaluated severity counts: CRITICAL 0, IMPORTANT 2, MINOR 1.
- Repository writes, Git mutations, tests, helpers, native/UI actions and cross-review reads: none.

## Rubric Scores

| Dimension | Score | Evidence |
|---|---:|---|
| correctness | 5 | Suspended launch omits cleanup; ordinary direct output escapes fresh policy. |
| security | 8 | No supported injection/credential/authorization defect found in this scope. |
| maintainability | 7 | Typed state is separated; cleanup is coupled to discovery. |
| test_coverage | 6 | Relevant tests exist, but these source paths lack the cited regressions. No tests run. |
| performance | 6 | Native registration delays cleanup; aliases contend for one deadline. |

## Verdict

- verdict: CONCERN (all scores at least 5, at least one below 7).
- confidence: high for cited source behavior; runtime timing/native acceptance remains unverified.
- Codex outcome: Medium risk, 6/10 (mean 6.4 rounded to 6).
- This file review does not assert Phase 6 completion or release/native acceptance.

## Findings

### [R1] HIGH: Suspended startup skips prior-effect cleanup

- Situation: `Scheduler.swift:243`; `Broadcaster.swift:41-42,98-99`.
- Behavior: suspended/unavailable startup never requests cached-effect reconciliation. The
  alternative transition clear is also disabled at `Scheduler.swift:433`.
- Impact: a failed/interrupted emergency repaint leaves restrictive paint on a valid cached
  terminal after relaunch. Active startup can also delay cached cleanup behind native discovery.
- Suggestion: request cached-effect cleanup unconditionally before optional native registration.
- Trigger: valid retained effect, failed repaint, saved suspension, relaunch without a new hook.
- Verification to add: suspended/unavailable startup plus cached effect and blocked native query.

### [R2] HIGH: Direct hook styling can overwrite a newly active restriction

- Situation: `terminal-osc-sequences.sh:86`; `trigger.sh:67,220-224`.
- Behavior: a hook computes suppression once, then the managed background helper fresh-reads and
  paints a new restriction. Palette/title/image output follows outside the shared lock using the
  old shell flag. A synthetic worker has the same validation-to-direct-output gap.
- Impact: ordinary palette, lock-title replacement or image output can partially undo the new
  restriction. A superseded synthetic title can arrive after a newer delivery.
- Suggestion: compose and deliver coupled ordinary render bytes in the typed managed transaction,
  using its fresh policy and target validation under the existing lock.
- Trigger: pause after initial unmuted gate, activate hard lock, release processing hook with
  title/palette/image options enabled.
- Verification to add: no ordinary render bytes after the managed restriction; delayed synthetic
  rendering cannot deliver after a newer legitimate hook.

### [R3] LOW: Plain/native aliases duplicate one physical terminal

- Situation: `visual-recovery.swift:160,189-191,231-244`;
  `terminal-visual-state.swift:35-40`.
- Behavior: hashing includes nativeSurface, so plain and native bindings of the same continuing
  TTY owner remain distinct and fan out onto the same writer lock.
- Impact: duplicate reset bytes and report items. Near the original deadline, duplicate contention
  can produce an avoidable partial failure. That timing scenario was not executed.
- Suggestion: deduplicate by TTY, device and continuing owner before fanout, preserving conservative
  failures for genuinely conflicting generations.
- Trigger: native registration followed by an ordinary hook on the same TTY, then recovery.
- Verification to add: one physical-target write/report with plain/native cached aliases.

## Summary

- Two IMPORTANT and one MINOR raw findings are confirmed; none were dismissed.
- Suspended startup needs unconditional cached cleanup before discovery.
- Coupled direct shell styling must share the current managed policy transaction.
- Plain/native aliases need physical-lifetime deduplication before recovery fanout.
- No additional provider pass or source/prompt/report fingerprint mechanism was used.

The full raw output, exact evidence paths, technical falsification, evaluated execution paths and
proposed regressions are in the raw skill report linked above. Skipped: tests, PTY/native/UI/helper
execution, install/sync and repository meta-thinking writes. Risk: native and owned-PTY acceptance
remain open. For future isolated corrections, partial/high scope should suffice; retain wider
concurrency analysis when the all-writer contract changes.
