# Focus color refresh source check and failure diagnosis

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

## Parent disposition

`52102fe` queries once per update, retires changed recipes and preserves unchanged healthy IDs.
It clears old owned focus on lookup failure without dropping logical mode/set/cues. Original
immutable store/alias checks, run-version checks and device deadline remain. Four new owned-PTY
cases first failed r1e4Su (28 assertions, one unexpected); 3BGNKJ passed all four after correction.
The first draft used nonexistent Data.hasSuffix; DjtXat retains that compiler error and corrected
suffix assertions were compiled before the behavioral red run.

GQNGvE exposed a fixture blocking every lookup; its initial-only gate now admits later required
queries. gPgVPv had an EPERM teardown, with normal owned permissions and an inactive record
retained. The last-closure fixture now awaits renewal and cleanup completion; that is not proof
of every older teardown cause. rEYbJl had an initial-paint timeout. Independent 9IKEE0 reproduced
an initial preview failure in a fresh process, excluding preceding teardown as a necessary cause.
The test-only recorder preserves the physical target; diagnostic nil-target delegation was
corrected before final verification. No deadline increase or arbitrary retry was added.

Final focused controller aouKnN passes 48; PToDKG passes 565 full Swift tests in 10.858 seconds.
Release zdna94 passes in 14.53 seconds. No source defect found in the scoped refresh check.
Slow-query supersession is a remaining source-visible limit; initial-paint failure cause is
unresolved. Do not treat passing checks as historical attribution or native acceptance.
Next diagnostics should preserve target/emergency, Boolean/error and timing at open/prepare.
No app/VM/container, real settings/schedules/install or existing-session action occurred.

## Scoped source check

# Focus color refresh source check

Date: 2026-10-14. Scope: current uncommitted focus controller and tests, plus connected
rendering, immutable effect storage, cancellation, writer deadline, and catalogue contracts.
No source edits, build, tests, app operations, real-home writes, or native acceptance were performed.

No concrete correctness defect was found in the color refresh diff.

The query occurs once in each prepared update, before per-target fanout
([focus-controller.swift:337](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:337)).
An accepted changed pair marks only that run's leases retiring and saves the normalized
`Colors` pair. Unchanged colors leave lease retirement untouched. The existing lease helper
then preserves the ID when ownership, retirement, and heartbeat permit reuse, or cancels and
replaces it
([focus-controller.swift:349](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:349),
[focus-controller.swift:480](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:480)).
This satisfies the store's immutable active recipe requirement instead of attempting to save
changed `focusColors` under the same ID
([terminal-visual-state.swift:252](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift:252)).

Both success acceptance and failure retirement check run identity and catalogue version while
holding the controller lock. A query released after Focus Off, a replacement run, or a newer
catalogue cannot accept its colors, retire the newer update's healthy leases, or publish a
current focus request. The final device preparation also repeats lease/version and age checks
([focus-controller.swift:339](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:339),
[focus-controller.swift:371](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:371)).
Stale completion can still invoke ordinary cleanup, but cleanup selects only already-retiring
leases, and replacement waits for their ownership resolution.

A current lookup failure retires existing leases and clears `attempted`, so the completion
does not exclude those targets from cleanup. It preserves mode, the captured working set, and
attention cues; subsequent catalogues can recover with a new ID. Failed metadata cancellation
keeps the old lease and blocks replacement. Successful cancellation followed by failed device
restoration leaves `mayHavePainted` true; an explicit current replacement transfers that
obligation. Unaffected writes restore the prior obligation only while the same lease remains
current and non-retiring
([focus-controller.swift:394](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:394),
[focus-controller.swift:496](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:496),
[focus-controller.swift:517](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:517)).
The failure path therefore does not discard exact ownership or outstanding repaint work.

Global masking still saves the refreshed focus recipe and heartbeat without painting focus.
Retirement under a global rule restores only that rule's background. Normal rendering later
uses the saved recipe
([visual-recovery.swift:273](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:273),
[visual-recovery.swift:320](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:320),
[visual-recovery.swift:393](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:393)).
Cleanup resolves exact metadata ownership under the writer deadline before device admission;
a separate device failure remains a failure, rather than being treated as completed restoration
([visual-recovery.swift:186](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:186)).
The color query stays on the background preparation queue. It is outside each device's
100 ms deadline, which remains enforced before metadata changes and output
([ProcessRunner.swift:159](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift:159)).

The added tests directly assert manual rotation and stable IDs, masked automatic refresh with
cue retention, query failure and recovery, and Focus Off during a blocked renewal lookup
([focus-controller-tests.swift:559](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Tests/TAVSAppTests/focus-controller-tests.swift:559)).
Existing tests cover failed target retirement and unresolved ownership across mode changes
([focus-controller-tests.swift:703](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Tests/TAVSAppTests/focus-controller-tests.swift:703)).
Test results are the parent's responsibility; this report does not infer passing tests from source.

One source-visible timing limit: configured colors may require two commands with separate
two-second timeouts, while the catalogue timer runs every two seconds. A consistently slower
lookup can be invalidated on every completion and stop renewal
([terminal-renderer.swift:46](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/terminal-renderer.swift:46),
[sessions-model.swift:152](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/sessions-model.swift:152)).
This already affected initial preparation; querying on each update exposes it during renewal.
No native timing failure was observed. Single-theme Ghostty reload behavior, perceived
dimming, foreground readability, real cleanup failures, and dual-theme refusal remain
native acceptance matters. Source correctness and PTY bytes do not establish that acceptance.

Capture input for the parent: [O] Read the current diff and traced both color outcomes through
run/version guards, lease replacement, immutable storage, global composition, and device
deadlines. No external report was treated as current evidence. Shared project capture remains
with the parent because this subtask explicitly permits no source edits.

## Initial paint diagnosis

# TAVS initial paint failure diagnosis

Last updated: 2026-10-14. Read-only investigation; no source edits or builds.

## Finding

The initial-paint failure is unresolved. A preceding FocusController fixture teardown is not a
necessary cause: the immediate predecessor preview test failed when run first in a fresh isolated
process. The log hides the original managed-writer error, so increasing deadlines or declaring a
fixture-only failure would exceed the evidence.

## Current evidence

- Original full-run failure: [rEYbJl log](/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.rEYbJl/command.log:163)
  shows the manual test's initial PTY 1 read timing out, before its preview or clear operations.
  This is the test-side 1,000 ms poll timeout, not direct evidence of the writer's 100 ms timeout.
- Focused reproduction used the existing 10:37 test binary with `swift test --skip-build`, the
  specified scratch path and source-built helper, through `tests/run-isolated.sh`. Only
  `testLatePreviewTimerSchedulingUsesTheRemainingDisplayLifetime` and
  `testManualCapturedSetIsIndependentOfPreviewAndClearsLatestIntent` were selected.
- [EW6xsi](/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.EW6xsi/command.log:5)
  passed both tests. The second fresh process,
  [9IKEE0](/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.9IKEE0/command.log:5),
  failed the first preview test: previewed = 0, status =
  `0 of 1 terminals previewed. Managed restoration unavailable.`, then PTY 0 timed out.
  The manual test subsequently passed. Testing stopped on this failure; no broad suite ran.
- The preview test's `entered.wait` assertion did not fail. Its injected `openDevice` closure
  signals that semaphore on the initial open. Therefore the failed attempt reached the open
  callback, although it might have consumed most of its deadline before reaching it.
- The older EPERM teardown's retained directory has normal ownership, 0700 permissions and no
  filesystem flags. It contains a writer lock and an inactive focus record. This supports an
  unfinished-writer investigation, but does not prove which syscall caused EPERM.

## Why existing assertions cannot locate the failure

[awaitManual](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Tests/TAVSAppTests/focus-controller-tests.swift:93)
accepts any status containing `outside` or `unavailable`. A status with `1 failed` also contains
`outside`. Checking only that status lacks `unavailable` misses this case.

[VisualRecovery.fanout](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:583)
replaces arbitrary thrown errors with `Managed restoration unavailable.`. It can hide a writer
timeout, EBUSY, a state-storage error or a target-validation failure.

The first manual update owns an empty `focusLeases` dictionary. The new color-change retirement
loop therefore has no old lease to clear or await on this initial paint
([updateManual](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:349)).
This does not exonerate the diff, but rules out waiting on a same-controller prior color lease as
this failure's mechanism.

## Minimal diagnostics

Keep the existing deadline. First record the returned Boolean or exact thrown error, monotonic
elapsed time and final status in these two tests. A successful `false` return needs recording too.

If the error is a timeout, add only these callback timestamps, measured against the supplied
deadline:

| Stage | What it distinguishes |
|---|---|
| Delegating runner entry and return/throw | Total caller duration and original error |
| Injected `openDevice` entry and exit | Time consumed before open and inside open |
| Wrapped `prepare(fd, deadline)` entry | Whether admission, open and writer-lock setup completed |
| Wrapped prepare return/throw | Metadata/preparation failure versus final descriptor write |

[completeDeviceWrite](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift:217)
sets the 100 ms deadline before dispatching its worker. The same deadline covers queue delay,
admission, PTY open, writer-lock acquisition, preparation and descriptor write. A caller timeout
does not join the worker.

Preserve the physical target when delegating. The existing
[MockProcessRunner handler](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Tests/TAVSAppTests/Mocks/MockProcessRunner.swift:82)
omits target/emergency, and its shorter SystemProcessRunner overload passes target = nil.
That changes [admission conflict matching](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift:239):
nil conflicts with any writer on that path. Use the known test target explicitly or a preserving
handler, so the recorder cannot manufacture the suspected EBUSY.

## Cleanup prerequisites

[Fixture teardown](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Tests/TAVSAppTests/focus-controller-tests.swift:43)
closes PTYs and removes the root without waiting for controller cleanup. PTY bytes alone are not a
cleanup completion signal: they can arrive before the managed worker returns and releases its
admission, and before the controller publishes its completion.

For successful cleanup, subscribe before triggering it and await the corresponding `cleanupError`
or `focusCleanupError` publication. The parent already added this to the last-closure test. The
immediate predecessor preview test still ends after restored PTY bytes. On a timeout, that
publication itself can precede the surviving worker's exit; diagnostic callbacks must reveal
whether such a worker remains before deleting the fixture. Do not add sleeps as proof of drain.

Next reproduction should run the two instrumented cases sequentially and stop at the first
captured original error. A passing retry does not close the issue.

## Capture input for the parent session

[O] A pass followed by a fresh-process first-test failure prevented a fixture-only attribution.
[O] Source tracing found generic error erasure and a diagnostic wrapper that discards the target.
[R] Preserving call semantics before collecting timing is the smallest useful next step. No
project capture file was edited because this delegated investigation was explicitly read-only.
