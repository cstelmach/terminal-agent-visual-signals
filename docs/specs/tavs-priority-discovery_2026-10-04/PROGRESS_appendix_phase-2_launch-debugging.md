> Parent: [PROGRESS.md](PROGRESS.md)
> Scope: Finished Phase 2 launch and development Dock source debugging
> Consolidated: 2026-10-14

### Phase 2 development Dock app: 2026-10-12 10:37 CEST

The operator asked to debug opening and authorized a normal Dock app during development.
The isolated process was alive but accessory activation and a leading MenuBarExtra provided
no initial window. Changed only the isolated delegate to regular activation and made its
Sessions Window the primary scene. The owned staged bundle now sets LSUIElement=false.
Production app mode, scheduler, hooks, installed TAVS and personal settings are untouched.

Rebuilt after 237/237 Swift tests passed in 2.174 seconds; release build passed in 5.54 seconds.
Backups/logs are in `/tmp/tavs-dev-dock-20261012T083034Z/`. Revalidated and terminated only the
old owned test process 37876, replaced its staged binary and verified signature/plist. The
installed process remains PID 8198. The current development app is PID 46436, with activation
policy 0 (regular), and its Sessions window is open.

Computer Use successfully bound the app in 2.115 seconds. Screenshot/AX checks confirmed
the fixture banner, distinct duplicate rows, explicit missing observations and Focus Off.
Selecting the first row then Shift-selecting the third reported three selected rows. The
bulk priority menu exposed High/Normal/Low. A priority click was interrupted by user activity;
fresh state showed unchanged Normal values, so no successful edit is claimed. Stopped UI
changes and left the normal app available to the operator.

Resizing, completed GUI priority edits/relaunch retention and actual native pane/Space navigation
remain unverified. The window uses fake rows and simulated Go To. Phase 2 remains Blocked on
the required native acceptance; the master goal is still incomplete. No unchanged access retry,
new provider review, production install or real terminal effect occurred. See
[bug reference](../../BUG_REFERENCE.md) for cause, fix and prevention.

### Phase 2 launch recovery: 2026-10-12 10:19 CEST

The operator reported the Mac unlocked. Computer Use could not bind the fixture app. Process
metadata and logs distinguished early app exit from a blocked UI: launchd reported exit 1.
A Foundation-only probe reproduced root `/tmp/...` rather than `/private/tmp/...`, making the
literal test-root guard reject our valid isolated directory. The new regression failed with
Cocoa error 258 before correction. The guard now compares the resolved system temporary root
instead of assuming its spelling. This preserves personal-root and escaping-fixture rejection.
Prevention: `testIsolatedLaunchAcceptsTheSystemTemporaryAlias` covers the `/tmp` path used by
the staged bundle. No production schedule, registry or preferences are involved in this fix.

The first corrected run failed only on the new test's URL trailing-slash equality. It now
compares resolved paths; final full Swift suite passed 237/237 in 2.192 seconds. Release rebuild
passed in 5.64 seconds. Prior failure logs/binary were retained and the owned test bundle was
updated and re-signed. Logs: `red-tmp-alias.log`, `green-tmp-alias.log`, `final-tmp-alias.log`,
`release-tmp-alias.log`, `test-root-diagnostic.log`, and `staged-launch.log` in Phase 2 scratch.

The corrected isolated process stays running; installed TAVS PID 8198 was not changed. CUA
still timed out selecting the app without a window. Its bundle-ID and SystemUIServer attempts
also timed out. Finder actions used only the owned test directory and app; a new Finder tab
preserved prior tabs. Asked the operator to open the test menu's Sessions window so CUA can
bind it. No alternative UI automation was used. GUI/native acceptance remains pending.

The independent review predates this two-line temporary-root fix and its regression. The saved
report is historical source review, not a new approval of the revised target. Bug description,
cause, fix and prevention are recorded here; `docs/BUG_REFERENCE.md` does not yet exist.

The remaining native acceptance stays in [PROGRESS.md](PROGRESS.md).

## Earlier Sessions source/build checkpoint: 2026-10-12 10:02 CEST

Implemented the resizable Sessions scene and menu action, multiselection, explicit per-row Go To,
High/Normal/Low priorities and stable native-order sorting. Rows show title, exact TTY/native ID,
directory and explicit missing observations. Focus is Off; selection has no navigation or paint.
Priorities are atomically saved under the supplied URL and retained through TAVS restart for
valid native keys. Failed/ambiguously empty refreshes retain last-known data and disable actions.
Trusted nonempty catalogues reconcile missing bindings. The model owns its two-second timer.

Added an isolated Sessions-only app branch with explicit private storage and exact target scope.
It constructs no production scheduler, preference view, login-registration delegate or discovery.
Incomplete test environment rejects before UI startup. Fixture mode labels navigation as simulated;
native test mode filters metadata and rejects out-of-scope navigation. The production catalogue
remains unrestricted. No real app installation, personal settings change or session shutdown occurred.

Verification: 12 new tests, including store restart, generation changes, moves, selection/navigation,
failure retention, malformed/write-failed storage, timer ownership and isolated launch/target scope.
The initial red run failed on missing SessionsModel. Final full Swift run passed 236/236 in
2.283 seconds; release build passed in 7.69 seconds. Compile-only native script, staged plist and
code-sign validation passed. Two invalid-environment binary launches exited 1 before UI startup.
Logs, build and the fixture test bundle are in `/tmp/tavs-phase2-20261012T092559/`.

Live acceptance remains recorded in [PROGRESS.md](PROGRESS.md).


## Completed Phase 2 review and scope notes

Independent Codex review completed successfully with the configured Sol/high route. Its original
CONCERN 7/10 finding assumed successful empty rows confirmed closure. Source verification falsified
that assumption: upstream Ghostty returns empty collections when scripting is disabled. The model
already reports unavailable coverage and disables navigation/edits. Finding dismissed, original
score retained. The wrapper's source evaluation is 8/10, Low risk, with no confirmed defects;
no revised provider approval is claimed. Installed-build equivalence is unproven.
Full outcome/disposition: [Phase 2 review](reviews/PHASE2-CODEX-REVIEW.md).

### Phase 2

- Seven planned source/test paths changed. The additional report is ordinary review documentation.
- The isolated launch branch is required by PLAN step 5; changing only HOME/registry would still
  construct the scheduler and register a temporary app at login. No adapter framework was added.
- SPEC changes are tracking frontmatter only; PLAN and the root hard-lock state remain untouched.
- Unit/build verification permits a source checkpoint, not a DONE phase or live acceptance claim.
  Recovery and previews remain future work; no OSC is added in this slice.

Current acceptance and unverified cases remain in [PROGRESS.md](PROGRESS.md).

### Swift and scoped launch checkpoint: 2026-10-15

**Phase 9 Swift/launch, 2026-10-15: 672/672 pass; guard b44727f.** [Results](caller-deadline-source-check-2026-10-14.md#fresh-isolated-swift-verification-2026-10-15).
**Scope:** one source/test and bug docs; native031/038 bootstrap timed out at 8s; next: bulk catalogue reads.
