# Portable intent publication source checks

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.0

## Parent verification and current disposition

7600aed adds held-parent atomic record I/O; 5cdf49b adds ordinary intent publication/binding.
The retained review describes a draft. Both concrete findings were reproduced and corrected.
P2: 75gYys failed the corrected native-retention expectation; target-only publication proof
now permits valid latest intent to persist before corrupt bound state reports failure. The
regression also confirms that strict ordinary rendering still refuses that corrupt state.
P3: WKdiel exposed the owned temporary left after close error; nested-finally cleanup fixes it.
2BbMPu separately exposed producer exit during observation reading; validation now checks the
producer afterward. H2C8Bq was the getter red before implementation. Final Lug0O3: 64/64 portable
checks, 1.503 seconds. NmpGpA: 561/561 Swift tests, 10.433 seconds. These are parent-run results,
not independently executed by the source reviewer. New intent tests use isolated fixtures;
earlier owned-PTY guard checks remain included, but no new physical publication acceptance ran.

Publication and rendering are different obligations. Latest intent may commit even when binding
or output fails. No effect cancellation, forced-reset implementation, backend assembly, helper
routing or complete H1/native/Linux acceptance is claimed. Operation-specific synthetic error
classification remains a helper-integration concern. Reports are retained because /tmp is ephemeral.

## Native contract source brief

# Native intent publication rules for portable_intent

Fresh source extraction only. No project edits, apps/devices/tests, fingerprints
or goal calls. References are current TAVSApp Sources/TAVSApp files.

## Shared validation and context checks

Incoming intent: schema1, normalizable background, valid tty/device/optional
producer, valid delivery ID and finite 0<updatedAt<=now. Producer start epoch must
not exceed updatedAt. intakeAt, when supplied, must be finite, positive and
<=updatedAt. These value checks precede publication (state:909-932,724-736).

| Operation | Required latest-observation/live checks |
|---|---|
| validateRenderContext ordinary | Strictly read/validate observation if present; observation.observedAt<=intakeAt; producer generation/device currently valid. Exact observation delivery equality is NOT required for ordinary render. |
| validateRenderContext synthetic | Delegate validateSynthetic: latest observation REQUIRED; exact tty/device/producer/deliveryID, observation time<=intakeAt, live producer. |
| validateSynthetic check | Missing/malformed observation becomes staleDelivery; other I/O/storage failures remain failures. No intent/target/effect publication or output. |
| publishIntent ordinary | Observation read/validation errors may be ignored EXCEPT deadlineExceeded; a valid newer observation still rejects intake. Ignoring here does not make later render-context validation permissive. |
| publishIntent synthetic | Propagate observation errors; require exact observation tty/device/producer/deliveryID and live producer. No synthetic observation/new cue. |

Sources: state:695-785. validProducer requires concrete TTY, expected device equals
current node, current process generation equals frozen producer and its device
equals expected. Not PID liveness alone. Managed entry additionally attests a
non-synthetic producer as a current helper ancestor (entry:78-111).

## Latest-intent ordering and repair

publishIntentUnlocked normalizes incoming background, then reads latest intent
using readLatest(recoverInvalid: !synthetic). If a valid current intent exists:

- Allow incoming updatedAt>=current.updatedAt; OR
- Allow a superseding delivery when the CURRENT observation exactly matches
  incoming tty/device/producer/deliveryID AND current intent differs in deliveryID,
  producer or device. This permits newer intake to beat a late render timestamp
  from superseded delivery. Matching only an ID or only a timestamp is insufficient.

Otherwise throw staleIntent. Successful publication atomically writes the
normalized record. No updatedAt/ID is regenerated to evade stale ordering.

readLatest (state:1067-1085) repairs only invalidRecord AND recoverInvalid=true
AND the currently lstat'ed destination is a REGULAR file. It returns absent to
its caller so an ordinary write replaces invalid regular JSON. It never repairs
symlink/directory/FIFO, storage-unavailable or expired-deadline failures. Synthetic
publication refuses corruption. A missing file normally returns absent.

Important contrast: ordinary publisher can ignore a bad observation, but
validateRenderContext ordinary reads it STRICTLY before style output. Persisting
intent despite output failure is deliberate; it does not authorize bypass.

## Target binding and later ordinary restoration

bindOrdinaryIntentUnlocked (state:383-411) requires a valid current target, matching
intent tty/device, nonnull LIVE producer and continuingOwner(producer)==target.owner.
It reads latest intent STRICTLY and requires FULL RECORD equality to normalized
incoming intent, including deliveryID, timestamp, producer, device and background.
It validates any existing bound copy, caches matching target.json, then atomically
writes normalized bound-intent.json. It does not repair corrupt bound state.

A bound copy itself requires valid intent, schema1 exact matching target.json,
same target tty/device and nonnull producer. ordinaryBackgroundUnlocked can restore
latest when ANY equivalent bound copy equals latest in ALL fields, even after
producer exit. Without that equality, producer must remain live with same continuing
owner; a native alias additionally needs matching adoption/surface and either its
intentDeliveryID or observationDeliveryID equal latest deliveryID (state:350-378).

## beforeOpen and output-lock ordering

VisualRecovery.performWrite (131-175,214-245,303-315):

1. Validate target. Set publication for ordinary/background operations, forced reset,
   or render with NONEMPTY background field. Style-only render publishes no intent.
2. Before device open, capture a pinned suspension revision for render/forced reset,
   THEN perform target-aware publication under the stable TTY lock. That method
   validates aliases, live producer and continuing owner, publishes and binds.
   Forced reset runs its dedicated publication under that same lock instead.
3. Release that metadata lock before bounded device open. Open device, acquire
   stable output lock and revalidate descriptor/target plus pinned revision.
4. Check synthetic context or strict render context BEFORE target caching and
   composition. Re-publish/bind the SAME frozen intent inside the output lock;
   forced reset re-runs its dedicated checks. A delivery arriving during open
   cannot be overwritten by the previously accepted beforeOpen publication.
5. Recompute current policy/effects and output from CURRENT ordinary intent.

All managed stages share the writer's original deadline. Before-open publication
preserves latest intent if open fails; it does not imply pixels were delivered.
The non-device publishIntent overload uses legacy .max publication timing after
its lock, but managed portable code must use the supplied original deadline.

## Forced reset boundaries

publishForcedResetUnlocked (state:654-691) always requires reset background,
matching tty/device, valid intake/timestamp and a CURRENT valid target owner.
If latest intent exists, it must retain incoming tty/device/producer/deliveryID.

| Producer case | Additional reset authority |
|---|---|
| Current valid producer | continuing owner matches target; synthetic observation match; publish synthetic reset and bind normally |
| Producer no longer validates | Latest intent REQUIRED, latest observation REQUIRED with exact tty/device/producer/deliveryID and time<=intake; at least one equivalent bound copy must FULLY equal latest. Then publish ordinary reset and update that target's bound copy directly. |

The latter branch is not a generic missing-process permission: native uses
validProducer=false, not a separate ESRCH death predicate. Authority is unchanged
stored delivery/bound intent plus positively validated continuing target lifetime.
Do not broaden this to old unbound intent, another producer, another delivery,
newer observation or reused TTY. Managed entry selects cachedTarget for orphaned
forced reset and still requires that cached target to validate (entry:127-130).
Reset title separately requires <=512 UTF-8 bytes and no native control characters.

## Atomic write details and outcomes

state.write:1088-1112 checks deadline before/after JSON encoding; <=8192 bytes;
creates a unique sibling .record-UUID.tmp via O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|
O_CLOEXEC mode600; bounded complete writes with EINTR retry; checks before atomic
rename AND after rename; closes/unlinks only its own temporary file. A post-rename
error may mean publication committed, not that nothing changed. Preserve that
failure and never compensate with raw output. Do not extend the deadline mid-write.

Managed stale delivery/observation/intent/effect maps to code3; generic storage,
validation, target/policy failure maps to nonzero unavailable. CheckSynthetic emits
no bytes and returns unaffected when validation succeeds. Ordinary rendered output
classification follows actual writer completion, not successful intent publication.

## Draft implementation source review

# Portable record I/O and ordinary intent source review

Read-only comparison of portable_record_io.py and portable_intent.py with native
publication/binding/getter contracts. No imports/execution, tests, apps/devices,
goal calls, project edits or fingerprints. No forced-reset/cancellation/routing
capability is claimed by this slice.

## Concrete findings

[P2] Corrupt bound state prevents latest-intent retention before binding.

publish_unlocked first calls _require_producer, whose Store._current scan validates
bound-intent.json, and explicitly reads/validates cached+bound copies at127-141.
Only later, at151, does it write latest intent. A malformed regular bound copy
therefore leaves the requested valid ordinary intent unretained. The added
invalid-bound test expressly asserts that latest stays unchanged.

Native target-aware publish validates live target aliases/producer, calls
publishIntentUnlocked to retain normalized latest, THEN bindOrdinaryIntentUnlocked
reads/validates its bound copy. Bound corruption causes binding/output failure,
but valid latest intent has already been retained. That retention is distinct
from permission to paint and is required when a device/binding path fails.

Separate positive producer/current-target proof for publication from bound-state
validation. Retain the valid current intent under the same lock/deadline, then
fail binding/output on corruption. Never repair bound data permissively or allow
style output through the error. Update the regression to check latest retained,
bound remains corrupt and output is still unavailable. This does not relax
synthetic observation/delivery checks or current target authority.

[P3] An exceptional close skips owned temporary cleanup.

portable_record_io.write:106-112 calls os.close(fd) before its unlink attempt.
If close raises after a failed pre-rename write, unlink is never reached and the
owned .record-UUID.tmp remains. Native closes and unlinks in its unconditional
defer without propagating close errno. Put the unlink in a nested finally so it
runs even if close fails; preserve the underlying failure and never delete other
files. This is a narrow lifecycle defect, not evidence of a successful publication.

## Source-verified matching behavior

- Incoming record/synthetic flag/intake are validated and background normalized.
  Producer generation/device and continuing owner are revalidated before/after
  publication; current target and competing aliases must remain valid.
- Older intent cannot overwrite latest unless the current observation matches
  exact tty/device/producer/delivery and proves a superseding delivery. Synthetic
  requires matching latest observation and a live producer; ordinary may ignore
  bad observation for intent retention but strict context validation still refuses
  it for style output. Deadline/storage failures are not permissive repair.
- Latest ordinary repair is restricted to invalid REGULAR intent data; symlink,
  wrong node and unavailable storage do not become overwrite permission. Synthetic
  refuses corruption. Missing data does not create directories on read.
- Binding re-reads latest and requires full record equality, not only delivery ID.
  A matching bound/latest copy supports restoration after producer exit. Without
  it, live continuing producer is required; native targets also need exact existing
  adoption tty/device/producer/surface and matching intent/observation delivery ID.
- Parent directories are opened/pinned without following links. Reads and atomic
  replacement use parent FDs; ancestor paths are checked before/after the operation.
  Publication validates bounded JSON, uses a private exclusive sibling temporary,
  complete writes and replace, with the original deadline checked throughout.
  A post-replace failure can still mean data committed; it must not trigger raw output.

## Bounded test additions

Exercise the native-retention order on corrupt bound JSON, preserving synthetic
refusal and checking no authorized style. Inject close failure during an aborted
pre-rename write and verify only its owned temporary is cleaned. Add a publication
read/write hook that changes producer generation immediately before binding and
assert failure without a new binding. Existing full-record mutation, exited
producer and adoption cases cover the principal getter paths in source.

Internal error-class caveat: invalid synthetic observation JSON maps to ESTALE,
while non-regular/oversized observation reads can propagate EINVAL/EFBIG. Native
validateSynthetic maps invalidRecord to staleDelivery, though direct synthetic
publication can propagate invalidRecord. All current paths refuse. Future helper
exit-code integration should preserve that operation-specific distinction.
