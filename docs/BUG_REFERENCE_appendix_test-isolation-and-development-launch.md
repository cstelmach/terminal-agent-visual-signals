# Test isolation and development launch bug history

Last Updated: 2026-10-15 (Europe/Vienna)
Version: 1.4

> Parent: [Bug Reference](BUG_REFERENCE.md)
> Earlier source corrections moved unchanged; pending acceptance limits are retained.

## Test fixtures escape their intended private roots

Idle-worker-mute used the live `/tmp/tavs-UID` runtime; mute-gate's default test could create
that directory. Priority-pinning used fixed capture paths and omitted state/cache overrides.
Python minimal environments discarded runtime paths and fake TTY protection. Title-only
sources additionally needed the legacy internal `_TAVS_TMP_DIR` instead of the public variable.

`tests/run-isolated.sh` gives its child private HOME/runtime/tmp/XDG/cache and regular capture
paths, requires an explicit built-helper path, retains logs and propagates the child's status.
Invoke it directly so its Bash `-p` startup ignores inherited BASH_ENV. The Python helpers
retain private paths without restoring intentionally removed feature/terminal indicators.
The three shell fixtures now use owned paths; the default resolver test stubs id/mkdir, and
worker cleanup precedes capture-file removal.

The priority test formerly asserted only a nonempty file. Exact OSC 11 assertions exposed
its attempt to replace permission inside the existing 400 ms grace interval. The test waits
through that interval and pins both processing/permission colors, without changing production.

Verification: 33 affected Bats cases, 230 audited Python cases and 237 Swift tests pass.
Startup-file and missing-wrapper red failures were retained. The full Python suite remains
unrun: fixed spinner HOME, pre-source title DB overrides and completion-worker cleanup need
their own repairs before those cases are invoked. The runner is an environment wrapper;
tests that explicitly replace its paths still require source audit.

Example, using a source-built helper and an audited suite:

```bash
TAVS_TEST_HELPER_BIN="$built_helper" tests/run-isolated.sh bats tests/unit/test-isolation.bats
```

Details: [Python isolation audit][isolation-audit].

[isolation-audit]:
  specs/tavs-priority-discovery_2026-10-04/PHASE3-PYTEST-ISOLATION-AUDIT.md

## Development app runs without showing Sessions

The isolated test app started successfully but appeared not to open. Its accessory activation
policy and leading MenuBarExtra left it without a Dock icon or initial window. Computer Use
could not bind that menu-only app, preventing the requested development checks.

The isolated app now uses regular activation and a primary Sessions window. Its staged bundle
sets `LSUIElement=false`. Production retains its existing menu-bar behavior. The test branch
still omits scheduler discovery, personal preferences and login registration.

Verification: 237 Swift tests pass; release build and bundle validation pass. Computer Use
opened the window, read the fixture banner and verified three-row multiselection. Runtime
metadata reports activation policy 0 (regular). Native Ghostty navigation remains unverified.

Prevention: staged UI acceptance must prove a visible window, not merely a running process.
Keep test-only launch metadata aligned with the delegate's activation policy.

## Isolated launch rejects the valid `/tmp` alias

The earlier test-root guard assumed Foundation would resolve `/tmp` to `/private/tmp`.
On this host it retained `/tmp`, causing Cocoa error 258 and exit 1 for the staged fixture.
Compare against the resolved system temporary root instead of assuming its spelling.
`testIsolatedLaunchAcceptsTheSystemTemporaryAlias` reproduced the failure before the fix.
Personal-root and escaping-fixture rejection tests still pass.

Further evidence and remaining acceptance:
[progress log](specs/tavs-priority-discovery_2026-10-04/PROGRESS.md).

## App replacement copy removes the prior installation

The installer removed the installed bundle before its final copy. A failed copy could leave
the app missing or partial. Normal CLI errexit stopped the success print but did not save it.
The replacement is now copied beside the destination and its executable, plist identity and
signature validated before process handling. Guarded same-volume moves retain the old bundle;
failed activation restores it or reports its preserved path without overwriting a conflict.
Explicit failure propagation prevents launch even when caller errexit is suppressed.

Prevention: eleven isolated cases cover partial/corrupt copies, invalid metadata/signature,
activation/rollback failure, no-clobber skips, destination types, first install and dry-run.
All eleven plus fifteen sync regressions pass. A real signed private bundle also passes
replacement and both static headless capability probes. Process operations were stubbed;
no production install/launch, login registration or native acceptance was performed.
The prior app remains retained after success. Two renames are not crash-atomic, and restoring
its bundle does not relaunch a stopped process.
See [update recovery](reference/macos-menubar-app.md#update).

## Agent installers report success after failed configuration updates

Gemini preview checked diagnostic text instead of the subprocess status. Both JSON installers
ignored failed apply operations; the unified command also lost per-agent failures and printed
Done. Each preview/apply now checks status explicitly and reports failure before success output.
Unified installation continues independent agents but returns nonzero if any failed. Successful
updates to other agents remain applied; the command does not roll them back.

A real-Python reinstall control also exposed repeated nested-hook insertion. The unified merge
compared a missing top-level command with an empty string, failing to recognize existing entries.
Complete-entry equality now prevents exact duplicate additions and preserves distinct matchers
and user entries. Existing settings, backup behavior and confirmation remain in place.

Prevention: nine private-root Bats cases cover arbitrary preview errors, public CLI apply failure,
aggregate partial failure, malformed settings, cancellation, backups and idempotent real merges.
They pass with eleven app-replacement and sixteen sync regressions (36 total). Shell syntax passes.
Failure injection stubs only the Python process result; successful merges run the actual inline
Python against private settings. No provider process, real installation or user configuration changed.
Sync now delivers the corrected installers and their required templates/adapter into existing
plugin roots. Exact-file checks and copied Gemini/unified failure cases cover both destinations.

## Linux-format test retains an unsupported native temporary root

The Linux dispatch unit selected Linux while retaining its macOS runner root in `/var/folders`.
Production correctly rejected that path before dispatch. The case now uses a fresh owned `/tmp`
root and local environment for both positive dispatch and wrong-platform rejection. Production
root validation and deadlines are unchanged. The original native-token check also passed at
missing-device validation; a stage-specific assertion exposed that incomplete control. Explicit
device identity now lets it reach context rejection, with no process lookup or renderer call.

Prevention: exercise the actual root guard and assert the intended rejection boundary. The final
portable suite passes 197 host cases, with eight Linux kernel cases skipped. A separate 17-case
helper run passes under a `/tmp` runner. Earlier timing failures remain unattributed; a fresh
Swift run has four assertions failing across three recovery tests. These format checks do not
establish real Linux process/PTY behavior or native Ghostty acceptance.

## Recovery race fixtures charge competing work to the old writer

Three fixtures performed complete independent marker/intake transactions inside the old writer's
100 ms budget. One imposed a separate 20 ms intake limit, then turned its failure into a fake
device-open failure before stale revalidation. Marker fixtures now stage valid private state
before the writer and rename at their original policy/open boundary. The intake fixture models
publication, independent newer intake and frozen prepare separately through the existing seam.

The intake name describes its before-device-admission scope. It retains exact stale rejection,
current intent, physical-target forwarding and PTY silence. Single-budget publish/open/prepare,
wedged-open locking and publication during an admitted open remain in connected unchanged tests.
Both marker cases retain real writer timing, cached-target/byte assertions and suspended state.

Three targeted cases pass focused and in the full suite. Full Swift (671 tests) still fails seven
assertions across three other tests. No production change, widened deadline, blanket stability
or historical-cause resolution is claimed. See the dated
[source/results](specs/tavs-priority-discovery_2026-10-04/caller-deadline-source-check-2026-10-14.md).
