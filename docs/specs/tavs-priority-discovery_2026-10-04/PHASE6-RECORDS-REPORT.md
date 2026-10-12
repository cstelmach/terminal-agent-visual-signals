# Phase 6 target and effect record foundation

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Initial baseline: `f067bef`; managed writer subsequently committed by parent as `bd27c08`.

## Scope

Only these two assigned repository files were edited:

- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-visual-state-tests.swift`

No coordinator, renderer, GUI, hook, shell, documentation or Git edit was made by this worker.
Parent-owned state changes and the managed-writer commit were preserved. No commit was made.
Diff: 688 insertions, 10 deletions across the two files, including 271 test lines.

## Public data types

- TerminalTargetBinding: Codable/Hashable; tty, device, ttyOwner generation, nativeSurface optional.
- TerminalTargetValidation: valid, vanished, unavailable.
- TerminalEffectKind: globalRestriction or selectiveBackground.
- TerminalEffectRecord: schema 1, target, controller generation, effectID, kind, normalized
  background, heartbeatAt Unix double and active boolean.
- TerminalCachedVisualRecords: typed bindings/effects plus unreadable record URLs.
- New generic TerminalVisualStateError cases: targetUnavailable, staleEffect, deadlineExceeded.

Existing observation/intent schemas, publication signatures and coverage behavior are preserved.
All new JSON decoders reject unknown nested target/native/application/controller fields.
Effects contain no title, OSC, BEL, foreground, palette, arguments or provider payload.

## Public operations

```text
captureTarget(for: freshGhosttySurface) -> TerminalTargetBinding?
captureTarget(tty:owner: ProcessGeneration) -> TerminalTargetBinding?
validateTarget(_:descriptor: native: confirmedNativeAbsent:) -> TerminalTargetValidation
lockURL(forTTY:) throws -> URL
cachedRecords() -> TerminalCachedVisualRecords
isSelectiveLeaseActive(_:) -> Bool

cacheTargetUnlocked(_:deadline:) throws
currentEffectUnlocked(_:deadline:) throws -> TerminalEffectRecord?
saveEffectUnlocked(_:deadline:) throws
matchingEffectUnlocked(_:effectID:controller:deadline:) throws -> TerminalEffectRecord?
refreshEffectUnlocked(_:effectID:controller:deadline:) throws -> Bool
cancelEffectUnlocked(_:effectID:controller:deadline:) throws -> Bool
ordinaryBackgroundUnlocked(for:deadline:) throws -> String?
```

The unlocked methods require the caller to hold the existing shared per-TTY writer lock and
pass the original monotonic UInt64 deadline. They never call coverage/publish/withLock, never
start another 100 ms allowance and perform no native request. Read guards run after IO/decode;
write guards run before temp creation, during file writes, before rename and after rename.
The managed writer remains responsible for its final deadline check before any device bytes.
Blocking filesystem IO cannot itself be forcibly interrupted; late completion does not permit
the managed writer to paint late.

lockURL is pure and uses the existing organizer/writer-Base64URLTTY.lock path. The managed
writer creates its parent after device open within the same original deadline. Lock files are
never replaced or unlinked by this store. Existing publication locking reuses the exposed URL.

## Target capture and validation

Native capture requires a fresh exact non-ambiguous row, concrete TTY, current device and
verified current foreground family. It walks at most 16 parents using only injected/kernel
generation, parent PID and controlling-device metadata, then rechecks the chosen continuing
owner generation. No command names, arguments, bodies or native queries are read.

Owner-only capture uses the same bounded continuing-owner walk. This supports independently
cached plain shells without observations or native access. The coordinator must authenticate
any caller-supplied seed generation before treating it as a shell registration request.

Validation uses narrow injected deviceMissing, processMissing and descriptorDevice closures.
Defaults use lstat known ENOENT/ENXIO, kill(pid, 0) known ESRCH and descriptor fstat character/rdev.
Tests inject metadata/presence and never probe arbitrary user processes.

- Same continuing owner generation/device remains valid after backgrounding.
- A descriptor must be a character device with the expected rdev; generic descriptor failure
  is unavailable rather than proof that the terminal vanished.
- Known device absence/replacement or native application generation absence/replacement is
  vanished. confirmedNativeAbsent may be supplied only after an affirmative exact native probe.
- Missing owner lookup, reused owner PID/start, owner-device mismatch or an unrelated fresh
  native row is unavailable when the physical device still exists. No request is retargeted.
- Cached native targets validate through current owner/device/application generation without
  an AppleEvents query. An uncertain application lookup remains unavailable unless absence is
  positively proved. Registry filenames or empty entries authorize no target.

## Record lifetime and lease

Current records use direct encoded identity components, not hashes or a paint history:

```text
organizer/targets/<Base64URLTTY>/<ownerPID-startSeconds-startMicroseconds>/plain/target.json
organizer/targets/<Base64URLTTY>/<ownerGeneration>/<appGeneration>/<Base64URLTerminalID>/target.json
```

Each same directory contains one current effect.json. Old unresolved owner/native bindings
remain separate candidates. Saving an effect caches its target first, before any caller paint.
Directory components are checked as directories before child creation; record replacement is
atomic using a temporary file in that same final directory. Existing bounded regular-file
reads and O_NOFOLLOW apply. Foundation enumeration's /var versus /private/var aliases are
normalized for exact record/path matching. One malformed record cannot hide healthy candidates.

Cancellation sets active=false, retaining target/effect evidence for recovery. Heartbeats match
the current effectID and controller generation and update only an existing active record.
saveEffect refuses reactivation with a canceled matching ID, including from a replaced
controller. Deliberate activation requires a new effect ID.

Selective lease validity requires active selective kind, verified live controller generation,
nonfuture finite heartbeat and age at most six seconds. Two-second refresh is the caller's
responsibility. Expired/dead leases remain discoverable. Global records are not selective
leases: callers must recompute current lock/mute policy first, including finite hard locks
that survive controller death. A false selective-lease result never authorizes bypassing them.

## Latest ordinary background

For a still-valid native target, strict existing adoption can bind the latest intent even after
its agent exits into the continuing shell. The exact native/app/device/TTY and frozen producer/
delivery adoption must match. Dead producer removes observation/cue coverage but does not erase
that established terminal intent. Different native IDs cannot acquire that color.

Owner-only intent with no native adoption still requires a currently verified producer and
matching continuing-owner ancestry. Missing/unadopted/unavailable intent returns nil, leaving
the caller to perform the explicit reset-to-default composition. Corrupt data throws a generic
error instead of silently authorizing a guessed color.

## Red/green evidence

Tests preceded implementation. Public API, cancellation field, original deadline and conservative
absence classification were agreed with parent. No build began before the managed-writer worker
released the shared scratch.

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-phase6-20261012T142300/baseline-helper \
  tests/run-isolated.sh swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase6-20261012T142300/build --filter TerminalVisualStateTests
```

Remove the filter for the full Swift suite. Retained logs below share the prefix
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/`.

- Initial red: tavs-isolated.eEQLEQ/command.log, missing new types/constructor arguments.
- First behavioral run: tavs-isolated.6LKQkD/command.log, 40 tests, eight failed assertions.
  All involved cachedRecords rejecting its own files due to /var versus /private/var URL aliases.
- Adopted-intent regression first: tavs-isolated.qgCkLp/command.log, one failure. The store
  returned nil after producer exit despite exact native adoption and a continuing shell.
- Final focused green: tavs-isolated.MluliS/command.log, **41 tests, zero failures**, 0.246 s.
- Full run: tavs-isolated.6qihzf/command.log, **312 tests, one unexpected failure**, 3.571 s.
  Store tests remained 41/41. No compiler warnings/errors were reported.
- Both owned files pass git diff --check. Shared scratch was released to parent. No further
  builds or source changes followed the full run.

The full-suite failure is outside these two owned files:

```text
ProcessRunnerTests.testPausedOpenDoesNotHoldLockAndPolicyReadsNewSuspension
process-runner-tests.swift:147: deviceWriteTimedOut("/dev/ttys041")
```

That owned-PTY fixture parks open on a semaphore, waits for an XCTest expectation on main and
writes suspension before releasing the worker, all within the device call's original 100 ms.
The full-run case took 0.304 s. A main-runloop scheduling delay can consume the deadline; the
timeout safely prevented painting. Parent is investigating the fixture without relaxing the
writer deadline. This worker did not edit the separately owned writer/test or blind-rerun the
full suite. A green full suite is still required before parent commits this foundation.

## Added test coverage and remaining work

Fourteen new tests cover cached plain shells, bounded parent-owner capture/background retention,
owner uncertainty versus proved absence, native/application/device/descriptor reuse, separate
unresolved bindings, cancellation and strict ID/controller matches, 2s/6s lease boundaries,
global-policy separation, held stable-lock nonreentrancy, expired-original-deadline mutation
rejection, metadata/color/future-time guards, empty registry non-authorization and safely adopted
intent after producer exit. Existing 27 observation/intent tests also pass.

Capture observations for parent: original failures were preserved; URL alias handling was fixed
without relaxing lifetime identity; an unsafe restoration restriction was turned into a red
test before correction; held-lock tests prove unlocked helpers do not reacquire it; a separate
writer fixture failure was reported honestly without changing its 100 ms constraint. Fold these
facts into the required meta-thinking capture with truthful model attribution.

This is record foundation only. Actual managed routes, fresh policy composition, candidate
union/dedup, independent recovery/reporting, GUI recovery, coordinator integration, required
reviews and visible acceptance remain parent Phase 6 work. No user session, native AppleEvent,
UI, install, hook, shell-suite or real-home scheduling action was performed. The full Swift run
includes existing owned-PTY and self-process test fixtures, not existing user sessions.
