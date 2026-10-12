# Phase 6 current visual restriction policy

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Baseline: `43914a0`

## Completed scope

Only these four owned project paths changed:

- `src/macos/TAVSApp/Sources/TAVSApp/visual-restriction-policy.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/visual-restriction-policy-tests.swift`
- `src/macos/TAVSApp/Sources/TAVSApp/MuteState.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/MuteStateTests.swift`

Parent owns Scheduler projection, coordinator integration, durable docs/capture
and commits. No native/runtime lookup, real PID liveness query, argv inspection,
app/terminal operation, installation, Git mutation or other source edit occurred.
All policy tests inject PID liveness and use explicit private file URLs.

## API and current-rule behavior

Added the agreed `GlobalVisualRestriction` enum with paused(PauseVisual) and
locked(PauseVisual, untilEpoch: Int64), plus `VisualRestrictionPolicy.current(deadline:)`.
Its initializer receives suspension store, mute/lock URLs, clock and a bounded
kill-zero default liveness function. No schedule/config reload or AppKit call
runs inside the policy callback.

Suspension is read fresh first. Suspended/unavailable state returns nil before
rule files are opened. Active finite hard lock wins independently of the GUI's
PID/heartbeat and uses LockStateReader.parse/isEffectivelyLocked after strict
known flag/numeric validation. Active grants release only the hard cause;
an independent valid soft mute still applies.

Rule input is bounded to 8 KiB with lstat plus O_NOFOLLOW/O_NONBLOCK regular-file
open, opened inode/type checks and bounded reads. Missing regular rule is nil;
malformed regular content cannot enable its cause. Special, symlink, unreadable
and oversized files throw fixed `VisualRestrictionPolicyError.unavailable`.
Deadline guards follow every blocking segment; expiry throws fixed timedOut.
Errors contain no paths or file contents. Optional legacy schema defaults to 1;
an unknown present schema is inactive.

Soft mute requires a positive alive Int32 PID, nonnegative numeric epochs,
written time not in the future, and heartbeat age at most 120 seconds. Until 0
is indefinite; until equal to current integer epoch remains valid, matching
existing shell readers. Time is refreshed after PID liveness, and suspension is
read again before returning, covering delays inside policy evaluation.

Colors use only the existing PauseVisual normalization/default background and
readable foreground. Invalid colors do not become terminal escape content.

## Additive mute projection fields

MuteStateData adds `hardCaused: Bool = false` and `requestedMuted: Bool? = nil`.
Schema remains 1. Serialization preserves the original eight fields/order, then
appends `MUTE_LEVEL="hard|soft"` and `REQUESTED_MUTED="true|false"`; default
requested value is the effective muted flag. Existing shell readers ignore the
new keys. Atomic serialization tests now expect ten complete lines.

Explicit MUTE_LEVEL is authoritative. A hard mirror cannot remain paused after
its actual finite lock is granted/expired/missing. For legacy absent level,
hard_lock reason is hard; other known causes keep soft liveness behavior.

REQUESTED_MUTED, when present and valid, is authoritative for current soft-rule
intent. Legacy absence uses MUTED. Invalid requested flag cannot enable paint.
This preserves the rule projected before the suspension override, allowing
headless explicit resume without waiting for a GUI tick. Effective MUTED remains
false while suspended. Parent still must populate both fields in Scheduler.

Key functions/types: GlobalVisualRestriction, VisualRestrictionPolicy/current,
softRestriction, readRule, fields, epoch, deadline check; MuteStateData fields and
serialize. No further policy API or general control plane was introduced.

## Test-first and failure evidence

Initial red build failed because the agreed policy types and hardCaused member
did not yet exist. No claim of executed failing assertions for that build.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.AXXijj/command.log`

Initial focused green: 26/26, with an unreachable-catch compiler warning in an
async XCTest assertion. It was corrected before final verification.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.c8vl9H/command.log`

A real liveness-time regression then failed one test with three assertions:
clock changes across heartbeat age, expiry and future-written boundaries still
returned paused from the initial time snapshot. The clock now refreshes after
liveness. Red log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.ush5Cr/command.log`

Parent's verified Scheduler edge added requested projection requirements.
Two tests failed with three assertions: effective MUTED false lost requested
soft intent, and stale MUTED true ignored requested false/invalid. The additive
requested field and selection fixed this without replay or schedule mutation.
Red log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.9UBQQT/command.log`

Final focused: **30/30**, comprising Policy16 plus MuteState14, zero failures.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.ufmmRB/command.log`

Final full Swift: **332/332**, zero failures, exit 0, 3.088 seconds XCTest.
Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.IfaRi2/command.log`

Both final logs contain no compiler warnings/errors. Commands used:

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-phase6-coordinator-20261012T152000/baseline-helper \
  tests/run-isolated.sh swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase6-coordinator-20261012T152000/build
```

Focused runs additionally filter VisualRestrictionPolicyTests/MuteStateTests.
The build slot and owned sources were announced free after terminal full-suite
verification. Parent held its edits and the record worker to keep runs unmixed.

## Capture and remaining work

[O] Source/API orientation and test-first missing-interface failure preceded
implementation. Actual runtime regressions were retained separately from the
initial compilation red.
[O] An additional virtual-clock probe found stale soft validity after liveness;
refreshing time fixed the reproduced edge rather than adding timing tolerance.
[O] Parent verified the lost projected intent while suspended. Two targeted red
cases established requested-field selection and later explicit resume behavior.
[O] No malformed state was sourced or executed; availability errors are fixed
cases and assertions verify private paths/body sentinels are absent.
[R] Reusing the lock predicate and PauseVisual while adding one direct bounded
reader avoided config loading inside the 100 ms callback.
Exact served model was not observed; GPT-6 family is self-reported only. Parent
owns mandatory project META-THINKING-CAPTURE and durable progress.

Scheduler assignments, locked coordinator invocation, effect/output routes and
live independent recovery acceptance remain parent work. The current policy
module itself does not persist effects, paint devices, resume schedules or
establish native target validity. Phase 6 and the overall goal remain incomplete.
No commit was made.
