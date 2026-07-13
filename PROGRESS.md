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
