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
