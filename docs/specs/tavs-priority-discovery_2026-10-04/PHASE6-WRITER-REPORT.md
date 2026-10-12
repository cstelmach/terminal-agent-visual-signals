# Phase 6 managed writer foundation

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Baseline: `f067bef`

## Completed scope

Changed only:

- `src/macos/TAVSApp/Sources/TAVSApp/ProcessRunner.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/process-runner-tests.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/Mocks/MockProcessRunner.swift`

No BroadcasterTests.swift change was necessary. No broadcaster behavior,
headless route, organizer/effect record, CLI, shell, Git or project-doc state was
changed. No live device, app, process, Automation request or installation was
operated on. PTYs and filesystem roots are explicitly owned test fixtures.

## API and implementation

Added the exact protocol/system/mock method:

```swift
func writeManagedToDevice(path: String, lockURL: URL,
    prepare: @escaping (Int32, UInt64) throws -> Data?) throws -> Bool
```

True means prepared bytes were fully written. Nil prepared data skips output and
returns false. Failure and timeout throw rather than being counted as unaffected.

`SystemProcessRunner.init(openDevice:)` defaults to Darwin.open and supplies the
minimum deterministic open seam. Both legacy and managed paths share an opened
fd helper and the existing partial-write/nonblocking-poll loop. The legacy
writeToDevice interface and tests remain intact.

`completeDeviceWrite` and its existing completion object are now generic, so
Void and Bool use one original absolute 100 ms caller/worker deadline. Managed
output opens the device first and explicitly rejects/closes a late descriptor
before directory, lock, policy or output work. It creates the parent directory
with 0700 attributes as needed; opens a stable O_NOFOLLOW/O_NONBLOCK lock inode
with 0600 mode; verifies regular-file type and private mode; acquires flock with
nonblocking retries bounded by remaining time; and rechecks the same deadline
before policy, after policy, and before every partial write. Lock and descriptors
are released on success, skipped policy, callback errors and timeout paths.
The method never unlinks or replaces the lock file.

Prepare receives the actual opened fd and original monotonic deadline under
serialization. The coordinator must validate character-device/rdev, current
owner/native/producer generation, fresh suspension and current typed policy
there. It must honor that deadline before effect/state mutations after a delay.
Swift cannot forcibly cancel an arbitrary blocked closure; this foundation
rejects its late returned bytes. This contract is documented near the API.

The mock captures managed calls under its existing NSLock and provides an
explicit managedHandler. By default it throws without guessing a /dev target or
passing fd -1 as a legitimate managed device. Existing raw mock behavior remains
intact. Handlers can exercise policy against an explicitly owned descriptor.

Key changed operations: SystemProcessRunner initializer, writeManagedToDevice,
completeDeviceWrite, openNonblockingDevice, checkDeviceDeadline,
writeToDescriptor; MockProcessRunner managedHandler/managedCallLog/new method.

## Verification

Tests were written first. Initial red compiled the new acceptance tests against
the prior source and failed on missing writeManagedToDevice/openDevice APIs.
Full red log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.IVuRNz/command.log`

Ten new tests cover exact bytes and original deadline; private/stable inode;
policy nil; paused-before-open lock availability plus new persistent suspension;
paused-before-policy lock ownership plus fresh suspension/reset ordering; late
open closure and no late lock/policy/paint; late policy result rejection and lock
release; busy lock deadline/no late policy; callback error cleanup; symlink/FIFO
lock rejection; backpressure beside independent healthy output; and explicit mock
fd/policy behavior. Small helpers allocate raw owned PTYs and a per-test root
under the runner's TAVS_TEST_ROOT. Barrier cases wait for late descriptor cleanup
before fixture removal. No unrelated process is signaled.

First ProcessRunner green: **15/15**, before adding the explicit mock case.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.TJWtsa/command.log`

Relevant final regression: **49/49**, comprising ProcessRunner16 and all 33
unchanged Broadcaster tests. Log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.KDeu2t/command.log`

Full Swift: **298/298**, zero failures, exit 0; 2.955 seconds XCTest.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.P2qTlV/command.log`

Commands used the private runner and explicit baseline helper:

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-phase6-20261012T142300/baseline-helper \
  tests/run-isolated.sh swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase6-20261012T142300/build
```

The relevant run additionally used `--filter 'ProcessRunnerTests|BroadcasterTests'`.
No compiler warnings/errors in green logs. Owned diff whitespace checks pass.
The shared scratch build has been announced free; no further worker builds run.

## Capture and integration notes

[O] API coordination preceded implementation. The parent explicitly kept fd/
binding/current-policy validation in the coordinator's locked prepare closure.
[O] Test-first compilation showed the missing API, then real PTY/barrier tests
and unchanged legacy regressions passed before the full Swift run.
[O] Unsigned deadline assertions capture one monotonic time and avoid subtraction
when the deadline has already passed, so a failed assertion cannot trap the test.
[R] Reusing the completion/deadline and descriptor write loop avoided a parallel
writer engine while establishing the required output serialization boundary.
Exact served model was not observed; GPT-6 family is self-reported only. Parent
owns the mandatory project meta-capture, durable progress and coherent commit.

## Remaining work

This is the Phase 6 foundation, not independent recovery completion. The parent
must connect records/ownership, in-lock target validation, fresh typed policy,
effect persistence, every shell/global/forced writer, failure retention, headless
recovery and final dedicated acceptance. No current callback automatically
validates a target or replaces queued snapshots merely because the writer API
exists. Physical/native acceptance and full Phase 6 milestone reviews remain
unverified at this checkpoint. No Git mutation or commit was made.
