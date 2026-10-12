# Bug Reference

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.10

## Suspended relaunch skips retained-effect cleanup

The scheduler skipped discovery and transition cleanup when suspension disabled restrictions.
That was appropriate for the old raw broadcaster, but it also skipped the new safe cached-effect
cleanup after a failed recovery repaint. Startup now always requests typed reconciliation, and
cached effects clear before optional native discovery. A transition into suspension also requests
safe cleanup after saving the new projection. Tests cover active, suspended and unavailable states
with blocked native discovery, saved definitions and no restrictive disabled paint.

## Shell suppression accepts invalid soft-pause liveness

The legacy shell gate accepted absent PID/heartbeat fields and future heartbeat timestamps.
It could suppress ordinary signals while the managed Swift writer considered the rule invalid.
The shared gate now requires a live positive PID, valid decimal times and a nonfuture heartbeat
within 120 seconds. It preserves legacy absent-schema handling and rejects explicit invalid
schemas. Isolated regressions cover the rejected metadata and hard-mirror expiry/grant behavior.

## Synthetic styling confuses producer and shell owner

An agent observation names its producer generation, while the managed target retains the
continuing shell owner's generation. Requiring equality rejected valid background-disabled
idle styling from an agent child. Validation now binds the target by TTY/device and verifies
the producer independently against the latest live observation. A regression reproduces an
agent under a continuing shell owner and proves validation produces no paint or cached target.

## Startup resets unaffected shell backgrounds

Registration followed by unrestricted reconciliation painted OSC 111 into newly discovered
plain shells. Startup now registers without paint and reconciles only cached effect targets.
An inactive global effect still requires palette/foreground cleanup because cancellation can
succeed before device output fails. Owned-PTY regressions cover both cases and preserve the
background of an untouched shell. Broadcaster routing and startup checks pass with 340 Swift
tests; headless and shell integration remain in progress.

## Suspension loses the rule needed for independent resume

The scheduler's suspension override writes effective MUTED=false. A current-rule reader then
cannot distinguish that override from an inactive soft rule. Schema 1 now retains requested
mute and hard/soft cause fields, with the requested rule's finite expiry and resolved colors.
The persistent marker still disables all restrictions before those fields are considered.

The old unmute path also cleared visuals before writing the new projection. Managed output
would read the old rule and could repaint it. The scheduler now saves both projections before
requesting reconciliation. Two regression cases exposed five assertions, then an expiry check
caught two more. All 47 related and 353 full isolated Swift tests pass. Production routing and
physical recovery remain unfinished.

## Headless catalogue needs an off-main completion

Waiting on `GhosttyCatalog.refresh` from headless main would block its main-thread callback.
The new synchronous `snapshot` explicitly enqueues enumeration on the existing native queue
and publishes its result through a semaphore, sharing request bounds and target filters.

The first implementation used `queue.sync`. Its test caught native work executing on main.
An explicit asynchronous enqueue fixes that contract; no native result callback needs the UI
event loop. Two new cases pin off-main work, dedicated scope, denial and application reuse.
All 14 catalogue and 314 full isolated Swift tests pass. Live Ghostty remains unverified.

## Writer race fixture waits past its real deadline

The full Phase 6 Swift run exposed a timeout in the paused-open test despite all store cases
passing. Its XCTest main-loop wait and suspension write occurred inside the real 100 ms writer
budget. The fixture now waits directly on a semaphore for the open barrier. No production
deadline or rejection assertion changed. Focused 57 and full 312 isolated Swift tests pass.

Keep failure logs when a timing test fails, and remove harness scheduling latency before
considering a timeout change. A timed-out writer must still reject late bytes and release its
owned resources.

## Suspension readers and policy projection

Treating suspension as an ordinary unmute would reset colors and replay opaque pending output,
including old titles/alerts. The scheduler now evaluates saved rules and expiries normally,
then disables their visual projection and skips every broadcaster path while suspended or
unavailable. Configured master activation is separate from effective mute, so menu controls
still edit the intended saved state. Independent physical recovery remains a later phase.

The shell reader initially treated inaccessible parent directories as missing active state.
An isolated permission test reproduced the mismatch with Swift. Both readers now distinguish
inaccessible/non-directory/dangling parents from an absent marker beneath accessible parents.
Canonical schema fixtures cover both shells and Swift without executing marker content.

The private app initially used a marker beside its priority file rather than under its private
HOME. A red fixture test exposed that discrepancy; explicit injection now matches
`root/home/.tavs/visual-restrictions.state`. Suspension survives relaunch and remains visible
even when catalogue refresh fails. Focus stays Off after explicit resumption.

Mute debug logging had a fixed `/tmp/tavs-mute-trace.log` sink. A source-only red assertion
avoided writing there, then the corrected logger was exercised in an injected private runtime.
This preserves test isolation without changing unrelated existing diagnostic files.

Verification: 288 Swift tests, 55 suspension/gate Bats cases, 55 earlier Bats regressions and
230 audited Python cases pass. Computer Use checked the private Sessions banner, relaunch,
unavailable state and resumption. Real menu rendering and physical recovery remain unverified.

## Organizer intake and restoration defects

The old Codex notify command let Bash consume appended JSON as `$0`. Direct argv now supplies
the adapter's second argument, with root TOML placement and escaping verified in private files.
Existing multiline notify arrays are refused before mutation instead of being partly replaced.

Core debug logging previously retained full hook JSON, free-form arguments, stdin, titles,
directories and process arguments. Intake now discards bodies and debug sinks retain fixed
metadata only. Decoded session/thread identifiers reject terminal and line control characters
before they reach title composition or identity state. A complete pending-byte capture exposed
the regression; a regular-file capture contained only the final bell and missed prior writes.

Late background rendering could overwrite a newer intent by using its newer render timestamp.
Publication now compares frozen intake time under the same per-TTY lock. Idle and delayed
error rendering preserve observation bytes and delivery identity. Standalone background writers
inspect their own process before ancestors and can retain intent without inventing an event.

Independent review confirmed that Claude's native installer resolves `claude` to a version
filename. Verification now recognizes resolved provider command paths while rejecting generic
interpreters and retaining generation/device/foreground checks. Damaged regular latest records
can be replaced by fresh legitimate publications; synthetic writes and corrupt native adoption
bindings remain fail-closed. Special-file replacements remain refused.

Verification: 273 Swift tests, 55 isolated Bats cases and 230 audited Python cases pass.
Computer Use confirmed coverage labels and failed-refresh retention in the private fixture app.
Real provider hooks, Ghostty rendering and later recovery/focus ownership remain unverified.

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
