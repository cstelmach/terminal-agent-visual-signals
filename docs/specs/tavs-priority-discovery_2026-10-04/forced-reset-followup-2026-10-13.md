# TAVS forced-reset cleanup source check

Last Updated: 2026-10-13
Version: 1
Baseline: `95a391f` plus the uncommitted forced-reset fix inspected here

## Current result after correction

The freshly inspected corrected draft rejects the identified counterexample by validating any
current intent's TTY/device/producer/delivery before entering either live or orphan branch.
That guard applies to both publications. No further concrete bypass was found within the
existing one-delivery-per-intake contract in this focused check.

The original draft had a concrete live-to-exited transition bypass. The first publication could
replace a newer standalone intent through the live synthetic path, then the second publication
treated its own first reset's bound record as the orphan authority. That finding and its
confirmed regression are preserved below rather than overwritten by the successful correction.

This is a focused source check of one fix, not a final review. No build, test, native query,
device operation, hook, installation, real-home action or peer-report read was performed.
Only this requested report was created. The parent owns source changes and verification.

Paths below are relative to:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.

## Checks that are present

`Sources/TAVSApp/managed-output-entry.swift:81` exempts forced reset from the live-producer
entry guard, while preserving the context device/current TTY device match. At line 127, a
producer-generation mismatch selects `recovery.cachedTarget`, which returns a validated cached
continuing-owner binding instead of deriving a target from an exited producer.

`terminal-visual-state.swift:610`, `publishForcedResetUnlocked`, validates reset intent, target
TTY/device, finite intake time and the current target owner. In its orphan branch it requires:

- a valid current observation matching request TTY, device, producer and delivery ID, with
  observedAt no later than the captured intake;
- a valid latest intent matching that same TTY/device/producer/delivery;
- exact equality of that latest intent with a previously bound intent on a valid equivalent
  binding;
- a still-valid continuing-owner target and valid alias set.

That branch rejects a new delivery and a newer standalone intent with a different delivery,
missing/unbound intent, invalid records and incompatible/reused owner/device/native aliases.
The check relies on typed identity and structured equality, not a metadata fingerprint.

`VisualRecovery.performWrite` publishes through this helper before opening under the existing
per-TTY metadata lock. It releases that lock before open, then revalidates the actual descriptor
and target and invokes the same helper again under the managed writer lock. A new delivery,
standalone intent or owner/device change appearing between those checks is rejected by the
second orphan check when the producer remains invalid.

## Original draft counterexample: first publication created its own orphan authority

The original live branch at `terminal-visual-state.swift:617-625` called ordinary
`publishIntentUnlocked(... synthetic: true ...)` and binds its result before it performs the
orphan branch's latest-bound-intent checks.

`publishIntentUnlocked` at line 679 accepts a matching observation and computes
`supersedesDelivery` when the current intent has a different delivery/producer/device.
This generic meaningful-delivery precedence is unsuitable as permission for an old timeout
cleanup to replace a newer standalone intent without a new observation.

A source-valid sequence is:

1. Observation D is current, and its agent producer P is live on the TTY. D's background was
   previously published and bound to continuing shell owner O.
2. A newer standalone ordinary intent S is published and bound on that same target, without
   replacing observation D. This is supported by the existing ordinary/standalone path.
3. D's timeout invokes forced reset while P is still live. The first helper call takes its live
   branch. Synthetic publication matches observation D and sets supersedesDelivery because
   current intent S has a different delivery. It replaces S with reset R for D and binds R.
4. Device open is queued or delayed. P exits, while O, the target device and native binding remain
   valid. No new observation arrives.
5. The second helper call takes its orphan branch. It sees observation D and latest intent R,
   now exactly matching bound R. Those checks pass because the first call created that proof.
6. The managed write emits the old timeout cleanup/title, although newer standalone S existed
   before this forced-reset operation began.

No forged record, reused UUID, failed owner check or malicious payload was required. The
producer can genuinely exit during the injected open seam. The same generic live branch can
also supersede S while P remains live; exit exposes how the first publication launders this
into the new orphan permission path.

The parent confirmed the original failure with the TtcCjQ regression run: there was no throw,
bytes were emitted and reset replaced `#778899`. This is parent-provided test evidence; this
reviewer did not execute that regression or inspect another reviewer's report.

## Corrected path inspected

The current `publishForcedResetUnlocked` reads optional latest intent immediately after reset
and target validation. If a latest record exists, it validates the record and requires matching
TTY, device, producer and delivery before either branch can mutate metadata. The orphan branch
then additionally requires the matching observation and exact previously bound latest intent.

That rejects standalone S before the first publication in the original sequence. It also
rejects a different S inserted after a valid first publication and before the second publication,
regardless of whether P remains live or exits during open. Both calls execute under the same
existing per-TTY lock, released across open; the second call rereads the latest record rather
than relying on the first call's local copy.

The existing live no-intent reset case stays valid. An orphan without any latest bound intent
remains stale. Same-delivery generated ordinary changes remain within the original intake
identity contract; this fix does not invent another identity for those updates.

The connected remedy applied here is:

Give forced reset its own latest-intent authority check before either publication branch can
overwrite metadata. When a latest intent exists, reject a newer/different standalone delivery
rather than authorizing reset through generic synthetic supersedesDelivery. Recheck the same
condition after open, so another ordinary publication cannot be erased between the checks.

Preserve the orphan branch's exact latest-bound-intent and continuing-owner requirements. The
existing live reset case with no previous intent is separate and is exercised by an existing
test; tightening that case is not required merely to block this counterexample. A conservative
check of existing latest identity before both branches can preserve that no-intent live case.

The relevant authority must precede the operation's first metadata mutation. Its own newly
bound reset cannot prove that there was no newer unrelated intent before it started.
Use existing typed fields and record equality. No hash, fingerprint, extra marker, service or
new control plane is needed.

## Recovery revision boundary

`visual-recovery.swift:169` now captures a pinned marker revision for forced reset as well as
ordinary style rendering. The locked callback checks it at lines 196-199 before its second
publication or any palette/title output. Atomic replacement, including the same suspended
boolean, therefore suppresses queued forced-reset repaint.

The first typed intent may already have been published before recovery replaced the marker.
The new revision guard does not undo that publication; it cancels queued visual/title replay.
That distinction matches the existing separation of typed ordinary intent from queued style
output. The test `testForcedResetQueuedAcrossRecoveryCannotReplayItsTitle` exercises this
physical output boundary, not rollback of the first intent publication.

No additional recovery-revision bypass was found in the reviewed callback. Current policy and
effect composition still govern any accepted reset, so global/selective presentation is
recomposed rather than bypassed by direct output.

## Regression coverage and remaining focused case

The initial new entry tests removed P before invoking forced reset. They covered the static orphan
branch, reused continuing owner, a changed delivery and missing/unbound/new standalone intent.
They did not cover P alive during the first publication and exited during device open. The
current new `testLiveProducerResetCannotEraseANewerIntentBeforeExitingDuringOpen` covers the
confirmed original scenario. In the corrected path, its stale guard prevents reaching open at
all, which is the required protection against the first overwrite.

The regression's relevant sequence using existing state, lookup and open seams is:

- keep D observation and P/O alive;
- publish and bind newer standalone S while leaving observation D unchanged;
- begin forced reset and remove P during injected device open;
- assert S was not overwritten by the first publication, no stale palette/title bytes appear
  and cleanup reports stale rather than success.

One additional focused case can put S between the first publication and the second check while
P remains live, to exercise the second invocation directly. The current source guard rejects
that sequence by inspection; no separate execution evidence is claimed here. Keep existing
tests for correct
orphan cleanup, malformed/stale delivery, continuing-owner reuse and recovery revision change.

An inspection failure and a proven exit both enter the current invalid-producer path; the
helper does not separately claim ESRCH. That is a naming/coverage distinction here. Its safety
authority is the unchanged typed observation and bound intent on a validated live owner.
The concrete bypass above exists even with a proven actual exit, so it does not depend on that
distinction.
