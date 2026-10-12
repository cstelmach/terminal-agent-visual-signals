# TAVS Phase 9 cue-producer liveness

Last Updated: 2026-10-13
Version: 1
Source baseline: `817f411`; controller integration is being added by the parent

## Finding

The described A/B/C scenario exposes a concrete automatic-focus source-validation gap.
A valid emphasized destination is not an eligible attention source. High plain shell B can
remain valid after A's completion producer exits. Checking B and outside target C does not
establish that any unacknowledged cue still has a valid producer.

This follows directly from SPEC's observation contract at lines 134-143: an adopted observation
may remain eligible only while its producer remains valid on the same controlling TTY/lifetime.
Missing, mismatched, exited or unverifiable producer generations are ineligible. SPEC product
phase 3 also releases focus when no eligible cue remains; all High surfaces are emphasized only
while at least one eligible cue exists.

At this baseline, the reducer is implemented and FocusController still supplies the Manual
request path. The finding applies to Automatic integration that reuses its emphasized-target
guard, rather than claiming a completed Automatic controller has already shipped.

## Why current helpers do not imply cue validity

All paths below are relative to:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.

`Sources/TAVSApp/focus-controller.swift:174`, `updateManual`, checks for at least one captured
working-set target before queued configured-color lookup. It subsequently captures outside
targets and passes `TerminalFocusRequest.isCurrent`, which checks the run/version and six-second
window. That is appropriate Manual working-set ownership, but does not validate an automatic
attention source.

`TerminalVisualStateStore.captureTarget` at `terminal-visual-state.swift:130` creates a binding
whose ttyOwner is the continuing owner. That owner can be a surviving shell ancestor instead of
the emitting agent. `validateTarget` at line 146 verifies that owner, device, optional descriptor
and Ghostty application generation. The independent shell can remain valid after the cue's
producer exits. Validating a binding is therefore not a substitute for validating its cue actor.

`coverage(for:)` performs the required producer validation during adoption, but its result is a
snapshot before the queued color lookup. The pure reducer cannot inspect subsequent process
exit. Its current `AttentionOccurrence` already retains provider, producer generation, TTY,
device and occurrence key, with native surface ID supplied by the cues dictionary key.

`VisualRecovery.performWrite` validates outside C's target/descriptor and checks request
currency/revision inside the existing lock at `visual-recovery.swift:235-248`. Neither that
target nor the controller lease proves A's cue producer is still valid.

## Smallest fix for the queued-paint race

Reuse the current focus request and state store. Capture the actual current unacknowledged cue
sources with their own native bindings, then revalidate at least one of those sources in the
managed callback after the queued work has finished.

The read-only check can wrap the existing private `validProducer(tty:device:producer:)` at
`terminal-visual-state.swift:786`. It already checks the concrete TTY, current character-device
number, current inspected process generation and that process's controlling device. Add checks
of the supplied original deadline before and after the bounded metadata lookup. Pair this with
the cue's own existing `validateTarget` binding and equality of its native surface/TTY/device.

Do not manufacture a binding by setting ttyOwner to the cue producer. Reuse the binding captured
from the accepted catalogue through existing target capture. That preserves the continuing-owner
and native-lifetime contract.

The current run/version guard must also establish that this snapshot still represents current
unacknowledged High cues. A Go To acknowledgement, priority change, mode change, stale catalogue
or recovery invalidating the snapshot must prevent its queued paint.

The predicate is existential over actual cue sources, not over emphasized rows:

- A's source fails after its producer exits, even if A's shell owner still survives.
- Plain High B has no cue source and cannot keep the predicate true.
- If another High surface has an independent current eligible cue whose producer remains valid,
  that cue may keep focus active. Requiring every old cue to survive would incorrectly release
  another valid cue's focus.

Pass the writer's original deadline to this revalidation through the existing request callback
or a narrowly named callback field. It belongs at the same final guards already used before
focus record publication. No new service, hook, writer, lock or state control plane is required.

## Avoid nested coverage locking

Do not call `coverage(for:)` from C's managed prepare callback. Coverage acquires the cue TTY's
writer lock and may publish adoption/bound-intent metadata. Holding C's lock and then taking A's
lock introduces cross-TTY lock ordering and spends the write budget on consumer adoption.

The proposed producer/device/native-binding check only inspects metadata. The cue was already
verified and adopted at catalogue intake, so SPEC's retained-adoption alternative permits fresh
producer revalidation without re-adopting or requiring current foreground membership again.
Backgrounding a valid already-adopted producer must not itself invalidate that occurrence.

`ProcessIdentity.inspect` rejects zombie/exiting processes and verifies PID/start generation.
The store's injected lookup/device closures supply existing deterministic test seams. Each cue
check needs deadline checks; the outer ProcessRunner also rejects a prepare result after its
original 100 ms deadline, preventing late output after a slow metadata inspection.

This is a fresh check at the managed decision point, not an assertion that the process cannot
exit immediately afterward. No process-exit lock or additional watcher is recommended.

## Important separate lease boundary

Returning false from `TerminalFocusRequest.isCurrent` prevents new `.focus` publication/paint.
It does not cancel an existing focus record. Current `TerminalEffectRecord` stores controller
generation, heartbeat, colors and marker revision, but does not retain cue producers. Common
ordinary composition at `visual-recovery.swift:291` consequently validates the existing focus
lease/controller, not an automatic cue actor.

For the requested new-paint race, a request-level check is the smallest fix. When the controller
learns that zero actual cue sources survive, it must also release prior automatic effects through
the existing exact-ID focus-clear path while remaining armed as specified. Otherwise an earlier
lease could remain usable until expiry despite a rejected renewal.

Do not claim that a request-only callback independently revalidates cue liveness on every later
ordinary lease-composition write. If that stronger requirement is adopted, the smallest connected
extension would carry the source metadata in the existing effect record and apply the same
read-only predicate during composition. That is a separate scope decision, not needed merely to
fix the queued new-paint race. No separate persisted cue registry is proposed.

## Required focused tests

Extend the current isolated FocusControllerTests/VisualRecoveryTests; parent owns builds.

1. Adopt/create A's cue, leave High plain B and Normal C valid, then remove A's producer from
   injected lookup during the blocked configured-color callback. Releasing lookup must not
   publish or paint a new focus lease on C. Keep A's continuing shell owner alive to prove the
   test detects cue liveness rather than target disappearance.
2. Repeat with producer PID reuse/start-generation mismatch, changed controlling device and
   unavailable process inspection. All must fail closed without native queries or real exits.
3. Add a second actual High cue D with a live producer. A's exit must not reject all focus merely
   because one of several cue sources ended. Plain B alone still cannot pass.
4. Adopt A while foreground-correlated, then background it while its original producer generation
   and controlling device remain valid. Retained-adoption semantics must remain eligible.
5. Acknowledge or downgrade the captured cue during lookup and assert the run/version guard
   suppresses its queued paint. A later, distinct unacknowledged cue must remain separate.
6. For an already-painted automatic lease, losing its last live cue schedules the existing
   metadata clear/current-background restoration and leaves Automatic armed with zero cues.
7. Expire the original managed deadline during metadata lookup. No late focus record or device
   output may appear; C's operation must not acquire A's coverage lock.

No tests, builds, native queries, device output or real-home actions were performed for this
report. The outcome is a source-confirmed race and a bounded reuse recommendation.


## Parent adjudication and checks

`hZE1x5` reproduced focus publication and output after the cue producer exited while its
continuing shell and another High shell remained valid. `d1oS7k` lacked the new metadata check.
`a0937e8` adds the deadline-aware cue-source predicate, exact-ID release on zero valid sources,
and post-lookup currency checks. `IRiXPh` passed 157 connected tests; full `DIx6uo` passed
490 tests. The original deadline is forwarded unchanged at all three focus decision guards.
Later ordinary composition still uses the accepted lease; no persistent cue actor was added.
Private UI controls were checked, but active-cue/native and relaunch UI acceptance remain due.
