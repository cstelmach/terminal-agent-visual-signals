# Implementation Plan — TAVS Hard Lock

**Spec:** /Users/cs/.claude/plans/i-had-following-thoughts-reflective-naur.md
**Created:** 2026-07-13
**Agent:** interactive (Fable 5)

> Prior plan/progress for the fizzy-pebble closeout archived to
> `docs/_archive/2026-07-13_hard-lock/` per the execute-spec pre-step protocol
> (different spec, must not co-mingle).

The authoritative plan (product context, high-level design, phases, tasks, verification)
lives in the spec file above. This file tracks the repo-local phase map and scope fence.

---

## Prerequisites

- macOS 13+ with Swift 6.0 toolchain
- TAVS.app installed at `/Applications/TAVS.app`
- Test commands:
  - `swift test --package-path src/macos/TAVSApp`
  - `bats tests/unit/ tests/integration/`

## Phase Map (mirrors spec §3)

```
Phase 0 (baseline)
   ├─→ Phase 1 (autolaunch cleanup)          [independent]
   ├─→ Phase 2 (shell integration/coverage)  [independent]
   └─→ Phase 3 (lock model + shell gate) ─→ Phase 4 (challenge + gated unlock)
                                                      │
                                                      ▼
                                       Phase 5 (acceptance + docs + deploy)
```

## Scope Fence

| File / path | Phase | Change |
|---|---|---|
| `src/cli/cmd-uninstall-macos-app.sh` | 1 | Drop bundle-missing early-return; login-item cleanup |
| `src/cli/cmd-install-macos-app.sh` | 1 | Header comment fix; delete temp build keychain |
| `src/macos/TAVSApp/Sources/TAVSApp/TAVSApp.swift` | 1,4 | `--login-item-doctor`, `--verify-password-hash` flags |
| `src/shell/tavs-shellrc.sh` (new) | 2 | Register TTY + self-paint at shell open |
| `src/cli/cmd-install-shell-integration.sh` (new) | 2 | Idempotent rc-block install/remove |
| `src/macos/.../MuteState.swift` | 2 | Additive PAUSE_BG/PAUSE_FG |
| `src/macos/.../LockState.swift` (new) | 3 | Lock state read/write/merge |
| `src/macos/.../ScheduleStore.swift` | 3 | `hard` flag on TimeWindow/QuietPeriod |
| `src/macos/.../Scheduler.swift` | 3,4 | hardness, lock projection, grants, timers, gate |
| `src/macos/.../Broadcaster.swift` | 3 | `broadcastLocked` |
| `src/cli/cmd-lock.sh` (new) | 3,4 | `lock now/status/set-password`, `unlock` |
| `src/core/trigger.sh`, `src/core/mute-gate.sh` | 3 | Fail-closed lock gate |
| `src/core/challenge.sh` (new), `challenge-sentences.txt` (new) | 4 | Challenge verify + pool |
| `src/macos/.../ChallengeVerifier.swift`, `ChallengeGate.swift` (new) | 4 | Hash/puzzle + NSAlert UI |
| `src/macos/.../MenuContent.swift`, `PreferencesView.swift` | 4 | Lock Now / Unlock… / gating |
| `src/cli/cmd-schedule.sh` | 3,4 | validator hard flag; gate resume/add/remove |
| `tavs` | 2,3 | dispatcher cases |
| `tests/**` | all | per-phase suites, see spec §3 |
| `docs/**`, `src/cli/cmd-help.sh`, `CLAUDE.md` | 5 | reference docs + help |
| `PLAN.md`, `PROGRESS.md` | meta | Re-baselined for this spec (Phase 0) |
