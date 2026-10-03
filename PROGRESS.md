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

### Phase 4 — Challenge + gated unlock
- [x] T4.1 `src/core/challenge.sh` (config load with puzzle degradation, spec-2.4 hash,
      first-letter-to-end transform, 3 attempts per kind, stdin prompts so tests can
      pipe answers) + `src/core/challenge-sentences.txt` (40 sentences, lowercase
      words + spaces only).
- [x] T4.2 `tavs unlock [--for 15m|2h30m|rest-of-day]` (interactive preset menu
      otherwise; preserves lock fields, writes grant; clean no-op without a lock),
      `tavs lock set-password [--type both]` (double prompt, 16-byte urandom salt,
      600-mode challenge.conf), top-level `tavs unlock` dispatcher alias.
- [x] T4.3 `_schedule_challenge_gate` in cmd-schedule.sh: resume/add-window/add-quiet/
      remove gated while a hard lock is effective (edit permission only, no grant);
      pause never gated.
- [x] T4.4 `ChallengeVerifier.swift` (hash spec twin, transform, config degradation,
      sentence pools: app has its own embedded pool since puzzles are per-side
      ephemeral) + `TAVSApp --verify-password-hash <salt> <pw>` parity hook.
- [x] T4.5 `ChallengeGate.swift`: NSAlert password (NSSecureTextField) / puzzle /
      both flows with 3 attempts, NSPopUpButton grant-duration picker
      (15m/1h/4h/rest-of-day), NSApp.activate + main-async deferral.
- [x] T4.6 MenuContent: "Lock Now (1h)", "Unlock…" (visible while hard-locked),
      Resume routed through ChallengeGate (passing resumes, no grant);
      Scheduler.lockNow/grantUnlock/togglePause(force:); PreferencesView: per-row
      "🔒 Hard" toggles (false maps to nil so untouched files stay byte-stable),
      saveDraft challenge-gated while hard-locked.
- [x] T4.7 Tests: challenge.bats (19: hash/transform vectors, attempt limits,
      degradation, unlock grant + re-engage, failed challenge leaves lock, schedule
      gating matrix), challenge-parity.bats (6: ascii/empty/unicode/special/long +
      the salt-is-literal-string spec guard), ChallengeVerifierTests (12; hardcoded
      hash vector verified against shasum after an initial WRONG guess, the verify
      rule earning its keep). Totals: Swift 193/0, bats 142/0.
- [x] CLI flows exercised end-to-end through ./tavs by the bats tests (real binary,
      temp runtime). App dialogs (menu unlock, gated preferences save) are user-gated
      visual checks in Phase 5 (V3/V4/V8).

### Phase 5 — Acceptance, docs, deploy
- [x] T5.1 `tests/e2e/hard-lock.sh`: fully isolated 12-step lifecycle, 12/12.
- [x] T5.3 Docs: new `docs/reference/hard-lock.md` (incl. honest-limits section),
      scheduling.md hard flag, macos-menubar-app.md menu tour (Lock Now / Unlock… /
      gated Resume / quit-keeps-lock), cmd-help.sh, CLAUDE.md (key files, docs table,
      quick start, test counts; CLAUDE.md is gitignored by design, updated locally).
- [x] T5.4 Deploy: `./tavs sync` (cache + marketplace + installed shellrc; sync now
      also copies src/core data files so challenge-sentences.txt travels), TAVS.app
      rebuilt from source and reinstalled; login item enabled; doctor clean
      ("Login item OK: /Applications/TAVS.app", "No stale TAVS login items found").
- [x] Live app-integration verified with the NEW app: `tavs lock now --for 2m` →
      runtime FileWatcher picked up the CLI lock within ~1s, projected
      MUTED=true/REASON=hard_lock with UNTIL_EPOCH = lock end, broadcastLocked fired;
      at the expiry epoch the one-shot timer released everything on the second
      (lock.state LOCKED=false WRITTEN at exactly the expiry epoch, MUTED=false).
- [x] Test-infra hardening found by running suites DURING a live lock: liveness.bats,
      emit-osc.bats, schedule-evaluator-parity.bats (atomic add-window would hit the
      challenge gate!), and baseline-capture's _diff_all leaked the LIVE runtime dir.
      All now isolate TAVS_RUNTIME_DIR. Proof: full bats suite 142/0 and golden diff
      6/6 WHILE a live 4-minute hard lock was active.
- [x] T5.2 Final suite totals: Swift 193/0, bats 142/0, e2e hard-lock 12/12,
      e2e scheduling unchanged.
- [ ] T5.5 V1-V10 user-gated visual checklist: awaiting user (see below).

## Checkpoint Summary — 2026-07-13/14 session (discovery → deploy)

**State at checkpoint:** All phases 0-5 complete and committed (11 commits,
`b399843..7855569` + capture commit). Suites green: Swift 193/0, bats 142/0, e2e
hard-lock 12/12, golden diff 6/6. Deployed: TAVS.app rebuilt from source and
reinstalled (login item verified clean), plugin cache + marketplace + ~/.tavs/shellrc
synced, shell integration installed on this machine (~/.zshrc + ~/.bashrc fenced
blocks; zshrc backup at ~/.zshrc.tavs-backup-*). Branch is ~75 commits ahead of
origin/main, NOT pushed. Only V1-V10 (interactive checks, table below) remain.

### What was built (one paragraph)
A hard-lock system layered on the existing mute: `/tmp/tavs-$UID/lock.state`
(fail-closed: no APP_PID/heartbeat, finite expiry always wins, absent/malformed =
unlocked), engaged via `tavs lock now`, menu "Lock Now", or `hard: true` on schedule
rules; challenge-gated unlock (`tavs unlock`, menu "Unlock…") with time-boxed grants
that suspend hard-caused mute only; schedule edits gated while locked; all-terminal
coverage via opt-in shellrc (registers TTY + self-paints at shell open); plus
autolaunch cleanup (login-item doctor, uninstall fix, keychain leak).

### What worked (repeat these)
- **Adversarial plan review before code.** The codex-reviewer pass deleted planned
  machinery (HMAC signing, watchdog, chflags, PATH shims) with the argument "zero
  value against the machine owner". Nothing removed was ever missed.
- **Explicit contradiction check with the user.** Original ask said "new sessions
  cannot be started"; round-1 answer said visual-only. One targeted question settled
  scope permanently (D1) instead of building blocking machinery on a guess.
- **Verify subagent claims by direct reads.** All Explore/Plan file:line anchors were
  spot-checked before design; the parity-test precedent claim was load-bearing and
  real (tests/integration/schedule-evaluator-parity.bats).
- **Empirical shell probes before writing tests.** One-liners revealed: zsh RESETS an
  inherited $TTY when stdin is not a terminal (tests must assign TTY inside the zsh
  invocation); bash passes it through; both set `i` in `$-` with `-i -c`.
- **Live verification on the real machine per phase.** Two bugs that no test caught
  were found this way (see below). Cost: a few brief gray-screen minutes.
- **Running the full suite WHILE the feature's live state is active** (a real hard
  lock engaged). This surfaced 4 latent test-infra leaks in one shot and is now the
  de-facto hermeticity acceptance check for this repo.
- **Contract tests for dual implementations.** challenge-parity.bats pins the shell
  and Swift hash to one spec (incl. unicode + "salt is a literal hex string" guard).

### What did NOT work / failed approaches (do not repeat)
- **HMAC-signed state, watchdog relaunch, chflags, uninstall-blocking:** rejected by
  design (D3). Any key/signature on an owner-controlled machine is forgeable by the
  owner; it adds code, failure modes, and dishonest security claims. If someone
  proposes "tamper-proofing" lock.state again: the answer is in
  docs/reference/hard-lock.md "Honest limits".
- **PATH shims for blocking agent launches:** out of scope (D1) AND structurally weak
  even if scope changes: the repo's own palette-theming `alias claude=...` shadows
  any shim (aliases beat PATH); absolute paths, `command`, `env`, non-interactive
  shells all bypass. If blocking is ever wanted, use agent-side hooks
  (SessionStart/UserPromptSubmit), not shims.
- **A new Swift `--login-item-doctor` flag:** abandoned; SMAppService can only see
  the CURRENT bundle's registration. Foreign/debug registrations are only reachable
  via System Events enumeration (shell) + running the surviving binary with the
  EXISTING `--unregister-login-item` flag.
- **`[[ cond ]] && action` as the LAST command of a sourced CLI function:** silently
  kills the whole `tavs` dispatcher (set -euo pipefail) when the guard is false,
  while bats (sourcing without set -e) passes everything. Symptom was "command
  prints nothing, exit 1". Use if-blocks and explicit `return 0`. (Bug shipped to
  the working tree, caught only by live run; fixed in cmd-lock.sh.)
- **Hardcoding a hash constant from memory in a test:** the SHA-256 vector written
  into ChallengeVerifierTests was wrong. Compute constants (`printf ... | shasum`)
  before committing them. This near-miss was caught pre-run.
- **Tests that isolate HOME but not TAVS_RUNTIME_DIR:** liveness.bats, emit-osc.bats,
  the parity atomicity test, and baseline-capture's `_diff_all` all read the LIVE
  /tmp/tavs-$UID. Consequences observed: fail-open assertions fail while a real lock
  is active; the parity add-window test hits the challenge gate; golden reset bytes
  drift when the live identity registry churns (dir flag 🇧🇬→🇧🇪, same-size diff).
  Rule: ANY test that runs trigger.sh or ./tavs must export an isolated
  TAVS_RUNTIME_DIR. Note baseline-capture has TWO capture paths (_capture_one AND
  _diff_all); fixing one is not fixing both.
- **Plan-mode subagents writing /tmp reports:** blocked by plan-mode write
  restrictions; the global "save report to /tmp" template fails there. Ask plan-mode
  subagents for inline output with a word budget instead.

### Key design decisions (beyond D1-D7 above, all in the spec file)
- lock.state carries NO APP_PID and NO heartbeat: that IS the fail-closed mechanism.
  Every writer sets a finite LOCK_UNTIL (schedule-driven writes cap at now+24h when
  no transition is known; heartbeat refreshes). No indefinite locks exist.
- Writer merge rules prevent the app's rewrite from clobbering CLI state: unexpired
  manual lock keeps the LATER end; unexpired grants always survive; engaging a lock
  cancels grants. Pure function `LockStateMerge.merged` + bash twin in cmd-lock.sh.
- Grants suspend HARD-caused mute only; soft rules unaffected (pinned by
  SchedulerLockTests.testGrantDoesNotAffectSoftMute).
- Manual lock outside schedule mute projects `REASON="hard_lock"` into mute.state
  (new MuteReason case); mute.state also gained additive PAUSE_BG/PAUSE_FG
  (SCHEMA_VERSION stays 1) so shellrc paints without theme resolution.
- masterPaused is NEVER hard; `tavs schedule pause` / menu Pause are never gated.
- Puzzle pools are per-side (shell txt file, Swift embedded array) because puzzles
  are generated+verified ephemerally per side; only the password HASH needs parity.
- Challenge degradation: missing/inconsistent challenge.conf → puzzle. There is no
  configuration state that locks the user out permanently.
- shellrc paints to stdout (rc-sourcing context = terminal), needs no /dev write;
  registration uses `: >|` (builtin); worst case 2 forks (bash), 0 forks (zsh via
  zsh/datetime).
- Scheduler init derives lockStateURL/runtimeWatcher defaults from muteStateURL so
  the 3 pre-existing test constructions stay hermetic and unchanged; production
  passes real runtime-dir URLs in createDefault.
- App writes lock.state only on semantic change (writtenEpoch excluded) so its own
  runtime-dir FileWatcher does not feed back; watcher events dedupe against the last
  read state (active-ttys/pending churn is ignored).

### Open items / next steps (in order)
1. **V1-V10 user-gated checklist** (table below): menu dialogs, multi-terminal
   paint, reboot semantics. Suggested smoke test: two plain terminals,
   `./tavs lock now --for 5m`, watch paint, menu "Unlock…", puzzle, 15m grant.
2. **Push decision:** ~75 commits ahead of origin/main; nothing pushed this session.
3. **Observation, needs user decision:** user.conf sets pause FG == BG (#4A4A4A on
   dark, #837677 on light) → text invisible during pauses/locks. Pre-existing user
   config, deliberately untouched.
4. Possible follow-ups (NOT commitments): wizard step for lock/challenge setup;
   `hard` flag support in `tavs schedule add-window --hard`; Gemini/OpenCode hook
   parity for lock suppression (they already funnel through trigger.sh, so they
   inherit it — untested); light/dark lock colors in lock.state (currently dark
   pause colors only from CLI, appearance-resolved from app).
5. CLAUDE.md is gitignored in this repo by design; its updates live only locally.
   The capture file META-THINKING-CAPTURE.md IS tracked and committed.

### Where to look first (next developer orientation)
- Spec + decisions: /Users/cs/.claude/plans/i-had-following-thoughts-reflective-naur.md
- Product docs: docs/reference/hard-lock.md (start with "Honest limits")
- State machine: src/macos/TAVSApp/Sources/TAVSApp/LockState.swift (merge rules) and
  src/core/lock-state-lib.sh (the same predicate in bash)
- Gate order: src/core/trigger.sh stage-0 → src/core/mute-gate.sh stage-1
  (_tavs_validate_mute_liveness: lock first, then recomputed mute verdict)
- Session methodology record: META-THINKING-CAPTURE.md (failure arcs F1-F4)

## User-gated acceptance checklist (V1-V10)

| # | Scenario | Expected |
|---|---|---|
| V1 | Scheduled hard window begins (app running, 3 terminals open: 1 agent, 2 plain) | All 3 turn gray with 🔒 title within 1s |
| V2 | Open a 4th terminal during the lock | Painted gray + 🔒 at open, instantly |
| V3 | Menu "Resume TAVS" during hard window | Challenge dialog; wrong answer keeps lock; Esc keeps lock |
| V4 | `tavs unlock`, correct answer, pick 15m | All terminals clear; agent signals work; menu shows "Unlocked until …" |
| V5 | Grant expires | Lock re-engages, terminals repaint without user action |
| V6 | `pkill -x TAVSApp` during lock, then open new terminal | New terminal still paints locked; `tavs lock status` says locked |
| V7 | Reboot during a manual `tavs lock now --for 4h` | After login: manual lock gone (D6); scheduled hard window re-engages once the login item starts |
| V8 | `tavs schedule add-window` during lock | Challenge required |
| V9 | `tavs lock now` / menu "Lock Now" | Engages with zero prompts |
| V10 | Uninstall + reinstall app | Exactly one login item, no debug items, doctor clean (programmatic half already verified in T5.4) |

## 2026-10-03: Terminal restoration repair and manual color reset

- Diagnosed the October 2 23:59 pause: the installed app blocked in terminal device opens,
  preventing the midnight unmute. Pause foreground/background pairs intentionally match.
- Added nonblocking terminal I/O, partial-write handling, and a 100 ms caller completion
  deadline. Live testing disproved the initial assumption that O_NONBLOCK alone bounded
  macOS open calls; the outer deadline isolates those kernel stalls. Late opens do not paint.
- Added active-only **Restore Terminal Colors** using OSC 104/110/111. It does not replay
  pending signals, change titles/preferences, or release pauses and hard locks.
- Final Swift suite: **203 tests, 0 failures**. Coverage includes real PTYs, disconnection,
  backpressure, successful partial writes, mixed fanout, wedged-operation deadlines, and
  reset state preservation. Release build and packaged signature verification succeeded.
- Installed the repaired ad-hoc-signed bundle. Original app/settings backup:
  `/Users/cs/.tavs/backups/2026-10-03-restoration/`; source backup is in /tmp.
- Live app PID 16452 wrote MUTED=false, completed a brief CLI pause/resume cycle, and
  continued producing fresh state updates. Schedule and user.conf match their backups
  byte-for-byte. Ghostty PID 961 and Claude sessions were not stopped.
- Four kernel-stalled devices were timeout-pruned: ttys008, ttys021, ttys024, ttys032.
  Kernel-stalled workers can remain until macOS releases those devices. Earlier TAVS
  processes 17081 and 14110 received SIGKILL but remained in macOS exiting state.
- Direct independent source review approved with no actionable findings:
  `/tmp/native-review-tavs-repair-2026-10-03.md`. The external Claude review timed out;
  `/tmp/claude-review-tavs-repair-2026-10-03.md` records that failure, not approval.
- Visual acceptance/menu-click testing remains unverified: Computer Use blocks Ghostty
  and cannot attach to TAVS through the stale LaunchServices registration. User observation
  was requested. No broad settings reset or kernel-device repair was performed.
- Separate existing observation: the schedule directory watcher also sees mute.state
  writes and re-evaluates. Live CPU was 4%; this pre-existing watcher behavior was not changed.
- Code commits: `f965575` (bounded terminal I/O) and `a7d070a` (manual color restore).

### Fresh rebuild and replacement, 14:21 CEST

- Rebuilt release and tests in a new scratch directory:
  `/tmp/tavs-fresh-build-2026-10-03-141647/`. All 203 tests passed again.
- Assembled a fresh app from the new executable and source Info.plist, retaining the icon.
  Ad-hoc signing and strict installed-bundle verification passed.
- Moved the previous installed app intact to
  `/Users/cs/.tavs/backups/rebuild-2026-10-03-141647/TAVS.app` and installed the new bundle.
- Relaunched with the macOS app launcher as a new instance, PID 23998, parent launchd.
  The app is active and login-item registration is enabled. Installed executable and plist
  match the staged bundle; user.conf and schedule.json match the new backups byte-for-byte.
- Ghostty and Claude sessions were kept open. The three older TAVS processes remain exiting
  in macOS; automatic menu inspection still returned procNotFound. No source code changed.
