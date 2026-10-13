# TAVS device-admission implementation check

Last Updated: 2026-10-13
Version: 2
Baseline: `3c1c451` plus the five-file uncommitted admission diff

## Current result after the recovery and test corrections

The latest inspected draft adds one separately bounded emergency-reset lane per physical
lifetime. Only VisualRecovery's `.emergencyReset` selects it. Ordinary retries remain limited
to one actual in-flight native operation, and emergency retries cannot amplify their own lane.
This preserves same-process recovery when an ordinary open is held without an output lock.
Both lanes still honor the original 100 ms deadline and release only after actual I/O cleanup.

The corrected tests now use typed busy admission, normalize raw syntactic aliases and perform
bounded exact-key/lane reacquisition before PTY teardown. Their cleanup asserts no late bytes.
The emergency test releases one semaphore token per actual counted open, including regression
extra opens. No material production recovery-contract objection was found in this latest
source inspection.

The parent reports an initial corrected full Swift run passed 519/519; final test-only cleanup
checks were still running when this report was updated. This reviewer did not run tests or
inspect external test logs. The initial observations below are retained as historical scope,
followed by the current correction assessment and remaining limits.

## Initial inspection result (historical)

The validated VisualRecovery-managed path implements the intended per-physical-lifetime native
I/O bound correctly. Metadata precedes admission, aliases normalize to the same key, different
validated owner generations remain distinct, and the permit survives caller timeout until the
actual worker unwinds. This is not a global thread-cap implementation.

Two concrete follow-ups remain: test teardown does not always wait for actual permit release,
and exposed raw/unresolved APIs can acquire separate permits through equivalent path spellings.
The latter is outside current canonical validated GUI calls but is a real retained-API escape
from same-device deduplication.

No source edits, tests, builds, native calls or device operations were performed. Only this
requested report was created. Source and connected test code were read directly.

All paths below are relative to:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.

## Production contract verified

`Sources/TAVSApp/ProcessRunner.swift:155` runs beforeOpen with the original worker deadline,
checks that deadline, then attempts native-I/O admission. A busy operation returns EBUSY after
the callback, preserving fresh ordinary intent and exact-ID metadata cancellation wherever the
publication lock is available. No second deadline or caller-thread publication was introduced.

The static admissionLock/inFlight collection is shared across SystemProcessRunner instances.
`DeviceWriteKey` includes path and optional `target.physicalTarget`. The predicate treats an
unresolved same-path call as conflicting with either an unresolved or known same-path call.
Known same-lifetime calls conflict across plain/native aliases. Known different owner
generations/device identities may coexist, which permits validated TTY reuse.

`visual-recovery.swift:195` passes the physical target into the protocol call. That original
target is validated before the call and its actual opened descriptor is revalidated in prepare.
Admission is not an independent source of binding authority.

The admission defer is installed before device open. Later fd-close, lock-close and unlock
defers execute first, so release follows actual I/O cleanup. The caller timeout path in
completeDeviceWrite does not remove admission. Late open still closes its fd without calling
prepare/output. Releasing the old physical key cannot remove a newer lifetime's key.

Raw writeToDevice also admits within its worker before native open and retains the permit
through descriptor cleanup. Empty raw data keeps its existing no-operation behavior.

The static lock is held only around pure key checks/mutation, with no user callback or native
device I/O under it. Independent healthy targets have separate keys; no serial global I/O queue
was introduced.

## Concrete retained-API amplification boundary

For target:nil, admission uses the literal path. POSIX-equivalent spellings such as:

```text
/dev/ttysNNN
/dev//ttysNNN
/dev/./ttysNNN
```

produce different keys, although native open resolves the same device. Alternating these through
writeToDevice or the legacy unresolved managed overload can therefore dispatch multiple native
operations for that device while the first is blocked. Symlink aliases have the analogous
unresolved identity problem.

This is not a bypass in the current validated VisualRecovery path: its concrete-TTY and target
validation reject noncanonical spellings and it supplies physicalTarget. Production source has
no direct raw writer call outside ProcessRunner itself. The retained raw/unresolved API still
needs an explicit boundary if its admission guarantee is advertised beyond exact path strings.

The smallest local response is to reject unsupported noncanonical raw TTY spellings or normalize
the accepted path before keying it, with one focused regression. Lexical normalization alone
does not prove identity through arbitrary symlinks; do not claim full raw-lifetime precision
without validated identity. No global thread cap or new service is needed for this boundary.

Arbitrary stalls in beforeOpen or direct completeDeviceWrite closures also remain outside native
device admission. That is the intended scope, not a claim that every callback worker is bounded
in count. No new metadata-worker machinery is recommended here.

## What the added tests prove

`testWedgedDeviceRetriesDoNotAmplifyOpenWorkersAndKeepLatestIntent` exercises an unresolved busy
path across runner instances, three metadata updates, raw same-path exclusion and independent
healthy output. Its open counter catches releasing admission at caller timeout. It does not
pass target:target, so it is not itself the integrated known-lifetime publication case.

`testAdmissionSharesPhysicalAliasesAndKeepsReusedLifetimesIndependent` passes known original,
native alias and replacement bindings. It checks alias EBUSY, two separate generation keys and
that old completion does not release the still-blocked replacement permit. Its manually
constructed replacement is a key-behavior fixture, not proof of actual native TTY reuse.

`testPostOpenPreparationRetainsAdmissionAfterCallerTimeout` proves a post-open worker keeps its
permit while prepare is blocked after the caller times out. Its second callback only increments
a counter; this does not promise metadata can pass a real writer lock held by that old worker.
The existing publication-lock failure test preserves the correct separate failure contract.

`testManagedWriterReceivesPhysicalTargetForSharedAdmission` verifies VisualRecovery passes the
physical binding to MockProcessRunner. It proves argument wiring, not actual native admission.

The first busy test would be stronger with typed admission and exact EBUSY assertions for
retries, rather than accepting every thrown error. Add one known-typed/raw mixed-key case since
the first busy test currently passes target:nil for both sides.

## Concrete cleanup synchronization flaws

The injected openDevice signals returned immediately after Darwin.open returns. That occurs
before openNonblockingDevice closes an expired fd and before the worker releases admission.
Waiting for returned therefore does not establish actual operation completion.

1. In the wedged-retry test, the cleanup defer releases blocked opens and waits for those
   returned signals. It can finish while a late close/admission release is still pending.
2. In the alias/reuse test, the successful original-lifetime reacquisition creates a third open
   and leaves its returned signal queued. The final defer's single returned.wait can consume
   that third-open signal instead of waiting for the blocked replacement's second open.
   The replacement worker may still be admitted when PTYs/root are torn down.
3. The post-open prepare test signals release in defer but never waits for the old worker's fd,
   output lock and admission to be released.

The extra third-open token is a specific finite counterexample to the alias test's cleanup
assumption. Residual process-wide admission can then interfere with later tests that reuse the
PTY path, especially unresolved calls, even though the worker will usually unwind shortly.

These flaws do not invalidate every main assertion, but can make teardown flaky and can let
cleanup succeed without checking what its name implies. Assertions made before releasing a
blocked worker do not prove there was no late output afterward.

## Smallest test repair

Release every blocked seam in defer, then wait for actual permit release before closing PTYs or
removing fixture roots. Existing safe zero-output probes can do this: retry the relevant exact
key while it returns EBUSY, then let a nil prepare return successfully. Ensure those probes use
an open seam that does not block again. Use a bounded monotonic test deadline and fail if the
permit never becomes available; do not leave it silently in flight.

For the alias case, wait/probe both original and replacement keys and do not use a shared
returned semaphore containing unrelated open tokens as the completion authority. Existing
late-fd-close and late-policy tests can be reused for no-late-output assertions after release.

The mock's legacy managedHandler/managedBeforeOpenHandler do not receive the new target argument.
Handlers that delegate back to SystemProcessRunner currently fall through the unresolved
overload. The new managedTargets spy records the input, but does not repair those delegations.
If a delegated integration test claims known lifetime/reuse coverage, forward target explicitly
through that existing seam; do not read a shared call-log last element in concurrent fanout.

No production managed-path amplification counterexample was found within validated same-lifetime
calls. This report does not assert a global bound across different lifetimes or claim test passes
that were not executed here.

## Current emergency-lane assessment

Fresh source now includes emergency in DeviceWriteKey. Collision checks compare lane as well as
canonical path and physical lifetime. This allows one ordinary and one emergency operation per
validated lifetime, not an unbounded override of admission. Native alias normalization and
exact release still apply independently to both keys.

VisualRecovery sets emergency true exclusively for `.emergencyReset`. Forced timeout resets,
normal ordinary output, focus/preview and resume reconciliation retain the ordinary lane.
Raw writeToDevice also remains ordinary. The reset's locked prepare still checks suspension,
validates its target/descriptor and cancels exact effect metadata before emitting reset bytes.

An ordinary blocked open has not acquired output serialization, so emergency can independently
open and take that lock. An ordinary blocked operation already holding the output lock can
still prevent reset; the emergency caller then returns a truthful partial failure within its
own original budget while persistent suspension is already saved. The lane does not bypass
serialization, promise reset through an occupied lock or release the old ordinary permit early.

Repeated emergency reset requests use the same lane/lifetime key and return EBUSY while the
first emergency operation remains stuck. Old ordinary completion cannot release emergency
admission and old emergency completion cannot release a newer lifetime's admission.

The new `testEmergencyAdmissionIsIndependentAndDoesNotAmplifyRetries` exercises both first
opens and three busy retries in each lane, asserts two opens total and probes both exact lanes
after releasing blocked work. Its corrected defer reads the locked opens count and signals that
many tokens, so an amplification regression does not strand its extra blocked open callbacks.

## Current metadata and test corrections

The busy-intent test now supplies target:target, and the mock spy still verifies physical target
wiring. It continues to prove publication before EBUSY across SystemProcessRunner instances.
Admission does not count a typed latest intent update as concurrent physical painting.

`testForcedResetCannotEraseAStandaloneIntentPublishedDuringOpen` now expects EBUSY from the
new ordinary physical attempt, checks that its beforeOpen nevertheless preserved `#778899`,
then verifies the older forced reset is rejected as stale and emits no bytes. That matches the
new single ordinary-I/O slot rather than requiring a second concurrent ordinary open.

The initial returned-semaphore cleanup issues above are corrected in fresh source. The bounded
waitForAdmissionRelease helper retries EBUSY, then performs a successful nil-prepare operation
with the exact target/lane using an unblocked runner. That successful return occurs after its
own fd/lock/admission cleanup. The alias test probes both owner generations, post-prepare
cleanup probes its key and the new defers assert no late PTY output before teardown.

Raw syntactic paths are now keyed by standardizedFileURL.path, and the new alias test explicitly
expects EBUSY for redundant slash/dot spellings while the first raw operation is held.

## Remaining limits

- Arbitrary symlink aliases in raw/unresolved APIs are not established as identical by lexical
  standardization. Current validated VisualRecovery calls reject those unsupported spellings
  and use trusted physical bindings. Do not advertise precise raw-lifetime identity through
  arbitrary paths from this change.
- Two per-lifetime lanes are not a total process thread cap across unlimited distinct lifetimes.
  BeforeOpen callback stalls and arbitrary completeDeviceWrite closures are also outside native
  device admission. This is the intended implementation scope, not an additional fix request.
- A blocked write holding the stable lock may still make recovery partial and may prevent later
  publication through that lock. No unlocked metadata or reset fallback should be introduced.
- Mock handler delegations still do not receive target/emergency fields. Delegated tests should
  not claim actual known-lifetime/emergency-lane coverage unless they forward those values.
  Direct SystemProcessRunner tests and the production VisualRecovery call exercise that path.

No remaining concrete amplification bypass was found in canonical validated managed calls
within either lane. No additional service, registry, process manager or global-cap mechanism
is proposed by this implementation check.
