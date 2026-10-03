---
title: "Gate focus restriction hardening after reversible testing"
description: "Keep testing restrictions reversible; gate stronger locks on validated recovery."
created: 2026-10-03T14:58:22
modified: 2026-10-03T14:58:22
tags:
  - t/todo/task
  - c/todo/task/planned
cssclasses:
  - custom_todo-note
  - custom_todo-task
status: open
priority: low
projects: "[[IPC17_terminal-agent-visual-signals]]"
source: /Users/cs/local/code/apps/terminal-agent-visual-signals/PROGRESS.md#^focus-restriction-testing-decision
---

# Gate focus restriction hardening after reversible testing

> [!warning] Deferred until reversible focus-restriction testing is complete.
> The operator requires immediate reversal throughout testing. Stronger reversal friction is
> future work, not permission to enable it now.

## Description

On 2026-10-03 the operator clarified the older hard-lock ideas: keep all focus restrictions
reversible while testing, and consider making them harder to reverse only after the
restriction behavior is reliable and has no known unresolved bugs. Existing challenge-gated
hard-lock code is already documented; this is a validation and later hardening/promotion task,
not a request to rebuild it or activate it today. Finite tests cannot prove absolute bug-
freeness; assess each supported restriction and recovery path, actual testing results and
unresolved defects.

## Entry Point

Read these in order. Every path is absolute so this note stays valid if it is moved into the Obsidian vault.

1. `/Users/cs/local/code/apps/terminal-agent-visual-signals/PROGRESS.md` Focus restriction testing decision (2026-10-03) and existing acceptance checklist. Current author instruction and recorded unfinished live checks.
2. `/Users/cs/local/code/apps/terminal-agent-visual-signals/docs/reference/hard-lock.md` Concepts, lock sources, state/lifecycle and honest limits. Existing hard-lock behavior and recovery model to evaluate before stronger restrictions.

**Next action:**

```
Read the testing decision and acceptance checklist; check restriction/recovery coverage and known defects before proposing hardening.
```

## Dependencies & Prerequisites

Every box must be true before work restarts.

- [ ] Every implemented focus restriction has been exercised on its supported window/session surfaces.
- [ ] Immediate undo and recovery work without aborting, quitting or reconstructing a coding session.
- [ ] No known unresolved focus-restriction defects remain in the current project issue/test records.
- [ ] Regression checks cover failures and recovery as well as the normal restriction flow.
- [ ] The operator confirms that reversible testing is complete before stronger reversal friction is introduced.

## Acceptance Criteria

- [ ] Testing behavior remains immediately reversible until all prerequisites pass.
- [ ] Future hardening reuses validated existing mechanisms where possible and states its exact affected restriction paths.
- [ ] Each stronger restriction has a tested, documented recovery path; harder reversal must not become permanent loss of control.
- [ ] Readiness describes tested coverage and remaining limits rather than claiming mathematically proven absence of bugs.

## Implementation Plan

### Approach

First inspect the existing restriction, unlock, expiry, crash and recovery behavior and finish
missing reversible tests. Only after the gate is met, specify the desired stronger reversal
behavior with the operator and implement the smallest change with regressions. This note does
not change live settings or start that implementation.

## Implementation Notes

### State at pause

| Field | Value |
|---|---|
| Repo | /Users/cs/local/code/apps/terminal-agent-visual-signals |
| Branch | main |
| Last Commit | 85434ce docs: Record fresh TAVS app reinstall |
| Session | codex 01a0fde7-d31c-7b12-9961-da5a3f53a3d8 (confidence: exact) |
| Working Tree | Clean before this authored todo and decision entry. |

## Edge Cases (Pre-Mortem)

- Do not treat older July hard-lock decisions as current permission to harden testing behavior.
- Do not activate locks, alter login/shell configuration or disturb running sessions while capturing this todo.
- Do not interpret a green unit suite as proof that every live restriction and recovery path is bug-free.

## Resources

- `/Users/cs/local/code/apps/terminal-agent-visual-signals/PROGRESS.md`
- `/Users/cs/local/code/apps/terminal-agent-visual-signals/docs/reference/hard-lock.md`

---

## Brain Dump

Operator direction: "We will for now keep them reversible, since we are in the testing phase. But it will be a todo, once we see no problems that we make it hard to reverse. But for now we don't want like we have it now to run into problems and then actually have them be irreversible. Only once every of the focus restrictions are bug free. So make a todo and save it in docs (theres a skill for that)."
