# Progress Log — TAVS Hard Lock

**Spec:** /Users/cs/.claude/plans/i-had-following-thoughts-reflective-naur.md
**Plan:** /Users/cs/local/code/apps/terminal-agent-visual-signals/PLAN.md
**Status:** Phase 0 in progress
**Mode:** Manual (interactive)
**Started:** 2026-07-13

> Prior PLAN.md/PROGRESS.md (fizzy-pebble closeout) archived to
> `docs/_archive/2026-07-13_hard-lock/`.

---

## Phases

### Phase 0 — Baseline
- [x] T0.1 Archived prior PLAN.md/PROGRESS.md; re-baselined both files.
- [x] T0.2 Baseline suite run: Swift 148 tests / 0 failures; bats 68 tests / 0 failures (exit 0). 2026-07-13.

### Phase 1 — Autolaunch cleanup
- [x] T1.1 Uninstall no longer early-returns when the bundle is missing; leftover login
      items, running debug processes, and orphaned mute.state are still cleaned.
- [x] T1.2 Install: removed the dead `security create-keychain /tmp/tavs-build.keychain-db`
      (cert always went to login.keychain-db); now deletes any stale leftover keychain.
      Header comment fixed (app self-registers; script only launches + verifies).
- [x] T1.3 Login-item doctor implemented as shared shell helper
      `src/cli/login-item-doctor.sh`, called from install (post-launch) and uninstall
      (both bundle-present and bundle-missing paths).
      DEVIATION from spec T1.3: no new `--login-item-doctor` Swift flag. SMAppService
      cannot enumerate other binaries' registrations, so an in-app flag adds no capability
      beyond the existing `--reported-status` / `--unregister-login-item` primitives the
      doctor already reuses per binary. Enumeration uses System Events (the documented
      troubleshooting path). Auto-removal restricted to paths containing `.build/`;
      unrecognized entries are surfaced, never deleted.
- [x] T1.4 `tests/unit/uninstall-macos-app.bats` (8 tests: early-return regression,
      orphan mute.state, doctor classification matrix, scan-failure fallback, full flow).
      Suite totals after Phase 1: Swift 148/0 (untouched), bats 76/0.
- [ ] Live verify (move app aside, uninstall, reinstall): deferred to Phase 5 deploy
      (T5.4 reinstalls the app; V10 checks login items) to avoid disturbing the running
      TAVSApp mid-implementation.

### Phase 2 — Shell integration + all-terminal coverage
- [x] T2.1 `src/shell/tavs-shellrc.sh`: interactive+TAVS_STATUS guards (builtins-only,
      case-pattern lowercase match), TTY resolve (zsh $TTY / bash one tty fork),
      registration via `: >|` into active-ttys/, builtins-only lock.state + mute.state
      reads, effective-lock predicate (spec 2.2), lock paint (OSC 104/10/11/1337 + 🔒
      OSC 0 title), soft-mute paint mirroring _tavs_check_mute_state validity rules.
      Paint goes to stdout (rc-sourcing context; hooks-style TTY redirect not needed).
- [x] T2.2 `src/cli/cmd-install-shell-integration.sh` (idempotent fenced block for
      ~/.zshrc + existing ~/.bashrc, --remove strips exactly the fence), dispatcher
      cases in `tavs`, `tavs sync` now refreshes an installed ~/.tavs/shellrc.
- [x] T2.3 mute.state additive PAUSE_BG/PAUSE_FG (resolved visual at write time);
      SCHEMA_VERSION stays 1; writeMuteState resolves the provider internally
      (no call-site churn). Updated 6-line asserts to 8 lines in MuteStateTests.
- [x] T2.4 `tests/unit/shellrc.bats` (14 tests: fence idempotency, zsh+bash paint
      matrix, expiry/grant/non-numeric, soft-mute fail-open, lock-over-mute priority,
      kill switch). Swift MuteStateTests +2 (visual fields, schema pinned).
      Note: zsh resets inherited $TTY when stdin is no terminal; zsh tests assign
      TTY inside the shell, bash tests pass it via env.
- [x] Live: `./tavs install shell-integration` run on this machine (zshrc backup
      created); fence verified in ~/.zshrc and ~/.bashrc. Marginal startup cost of
      the shellrc fast path measured at ~0-10ms (measurement noise floor; user zshrc
      baseline itself is 4.3s). Menu-bar pause paint check deferred to Phase 5 V1-V2.
      Suite totals after Phase 2: Swift 150/0, bats 90/0 expected (76 + 14).
- [x] Fixed pre-existing golden flakiness found en route: baseline-capture.sh now
      isolates TAVS_RUNTIME_DIR (reset golden embeds the dir-icon flag; live registry
      churn drifted it). Separate commit.

### Phase 3 — Lock model, projection, fail-closed shell gate
- [x] T3.1 `LockState.swift`: serialize/read/parse (nil on malformed, D3), effective-lock
      predicate, `LockStateMerge.merged` pure function (manual-max, grant preservation,
      24h cap for unknown transitions).
- [x] T3.2 `hard: Bool?` on TimeWindow + QuietPeriod (nil = absent key, old files parse
      unchanged); parity fixture `valid-hard-flags.json` + test (CLI validator accepts).
      NOTE: `Fixtures/schedule-canonical.json` intentionally NOT changed (round-trip
      tests keep covering the pre-hard shape; hard coverage lives in dedicated tests).
- [x] T3.3 `ScheduleEvaluator.Result.hard`; hardness rules (any enabled hard window
      hardens outside-window mute; matching hard quiet hardens quiet mute; masterPaused
      never hard); `nextTransition` now fires on hard-flips too (lock release while
      still muted would otherwise wait for the 60s heartbeat).
- [x] T3.4 Scheduler: `finishEvaluation` shared tail (config + no-config paths), lock
      merge + grant-aware projection (grant unmutes hard-caused mute only; manual lock
      implies mute via new MuteReason `hard_lock`), `isHardLocked` published, lock/grant
      one-shot timers, runtime-dir FileWatcher with content-change dedupe, write-on-
      change only (no lock.state file on machines that never lock), `togglePause`
      refuses resume while hard-locked. New init params default-derived so existing
      tests stay hermetic; createDefault passes real runtime-dir URLs.
- [x] T3.5 `Broadcaster.broadcastLocked` (paused bytes + OSC 0 🔒 title, documented
      exception), MockBroadcaster extended.
- [x] T3.6 `src/core/lock-state-lib.sh` (read/predicate/atomic-write) +
      `src/cli/cmd-lock.sh` (`lock now [--for]`, `lock status`, duration parser d/h/m,
      merge-max, grant cancel on engage, colors from TAVS_PAUSE_*_DARK) + dispatcher.
- [x] T3.7 Shell gate: trigger.sh stage-0 reads lock.state builtins-only WITHOUT the
      PID gate; mute-gate stage-1 evaluates the predicate first and keeps suppression
      fail-closed; on lock-not-effective the mute verdict is recomputed from scratch
      (incl. PID/version, since stage-0 sets suppression for either cause);
      `_tavs_check_mute_state` (idle worker) checks the lock first.
- [x] T3.8 Tests: LockStateTests (19), SchedulerLockTests (10), ScheduleStore hard (2),
      cmd-lock.bats (15), lock-gate.bats (11, incl. the fail-closed core: dead APP_PID +
      stale heartbeat still suppressed; expiry/grant/malformed release; fail-open
      regression guard). Totals: Swift 181/0, bats 117/0.
- [x] Live verify: `./tavs lock now --for 2m` on this machine → status LOCKED,
      repo trigger.sh suppressed (0 TTY bytes, pending buffered), installed shellrc
      painted `🔒 locked until 21:51` with user's #4A4A4A pause bg. Lock left to
      self-expire. Bug found live and fixed: `[[ ]] &&` as last command of
      `_lock_resolve_colors` returned 1 under the dispatcher's `set -e` (bats sourced
      without set -e, hiding it).
- [ ] App-integrated broadcast paint (all-terminal): Phase 5 after app reinstall.
