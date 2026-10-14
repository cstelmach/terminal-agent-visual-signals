# Portable unbound intent source checks

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

Source: `7af2505`. Reports below are source-only and separate from executed tests.

## Parent verification and disposition

Native unbound publication at `terminal-visual-state.swift:619-632,718-768` retains ordinary
optional/exited identity as data, requires synthetic exact observation and live device, and does
not bind/cache/paint. Portable bound and unbound wrappers now share only latest publication rules;
bound before-write producer revalidation and later exact binding remain separate. Native current
supersession excludes current.tty; the shared comparison was corrected and a wrong-key fixture
verifies that field alone cannot authorize older delivery replacement. Exact observation matching
still includes TTY. Invalid synthetic records/storage remain unavailable, not stale delivery.

The source check found no functional defect in these preservation properties. It identified
missing direct equal-time and late bound-producer-exit tests, added after the check. Final tests
prove equal-time replacement and refusal before latest write after producer exit during read.
The whole portable metadata operation intentionally retains a 100 ms budget; native legacy
post-lock publication uses .max. This difference is explicit rather than a full native timing claim.

J7yKQT: four expected absent-method errors. NvUhcE: 23 intent cases after implementation.
n5WUtZ: unsupported helper verb failed three assertions/one record lookup. z3iQxk: 167 portable
checks; QS45Lt: 168 after wrong-TTY case; final rA0fi1: 170/170 portable in 5.725 seconds.
yS5dC8: 561/561 Swift in 11.320 seconds; q0Zrrt: 23/23 hooks. Native/shell source was unchanged
by later Python tests. Syntax, exact staging, .env/secrets and whitespace passed. Owned macOS PTY
CLI publication emitted no bytes and created no target cache. Missing-identity CLI publication
constructed no renderer. Neither data path grants independent output or attention authority.

Capabilities, backend selection/delivery and Linux versioning/runtime still remain pending.
Physical Ghostty acceptance and earlier configured-color/historical-failure concerns are open.
No app/VM/container launch, production install/state change or existing session termination.

## Native contract extraction

# Native unbound organizer intent contract

Source inspection on 2026-10-14. No runtime execution, tests, UI interaction, provider calls,
or repository edits were performed for this report. The requested report is the only written file.

## Source locations

- Native CLI: `/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/organizer-intake.swift`, lines 80-134, 177-203.
- Native state: `/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`, lines 619-649, 695-768, 879-884, 909-937, 969-1111.
- Portable intent: `/Users/cs/local/code/apps/terminal-agent-visual-signals/src/core/portable_intent.py`.
- Portable record validation and replacement: `src/core/portable_records.py:74-90,142-165`,
  `src/core/portable_record_io.py:64-85,88-130`, and `src/core/portable_policy.py:20-56`.
- Portable store identity: `src/core/portable_ownership.py:100-154` and
  `src/core/portable_process_identity.py:197-208`.

The portable file changed during this read-only investigation. The comparison below distinguishes
the original bound implementation from the newly present shared helper. Current helper line references
were reread after that change.

## Exact native CLI semantics

`--organizer-intent` takes TTY, base64 context, background, and a synthetic flag. Including the
executable and command name, argument count must be six. The flag must be exactly `0` or `1`.
The context decoder requires a base64 token no longer than 8,192 UTF-8 bytes, decodable typed
`OrganizerContext`, schema 1, and a supported provider. Supported context providers include
`claude`, `codex`, `gemini`, `opencode`, and `unknown`.

The command constructs only an `OrdinaryBackgroundIntent`, with the supplied TTY/background,
optional device/producer and delivery ID copied from the context, and a fresh wall-clock
`updatedAt`. It passes `context.observedAt` as `intakeAt`. Provider, verified-agent status, event,
and response ID do not enter the intent record or authorize publication. In particular,
`verifiedAgent == false` does not disqualify ordinary publication. Native context discovery can
return the foreground owner's identity without claiming an agent identity, or no owner at all.

The CLI calls the unbound `publishIntent(record, synthetic:intakeAt:)` overload. It does not
create a terminal target, render OSC bytes, create a target cache, bind an ordinary intent to a
target, or create adoption data. Success produces no command output. Failure handling is:

| Native result | CLI behavior |
|---|---|
| `staleDelivery`, `staleObservation`, `staleIntent` | Exit 3 |
| Any other error, including invalid input, storage, lock, or deadline errors | Print `Organizer metadata unavailable.` to stderr and exit 1 |
| Success | Return normally |

There is no requirement to obtain a live target before retaining ordinary unbound intent.

## Native validation and publication ordering

Record validation requires schema 1, a supported normalized background, an absolute TTY string
of at most 128 UTF-8 bytes, no control characters or `.`/`..` path components, and a standardized
path other than `/dev/tty`. It requires a valid delivery ID and finite positive `updatedAt`
no later than the store's current wall clock. A present device cannot equal `UInt32.max`.
A present producer must have valid positive PID/start-seconds, microseconds below one million,
and a start timestamp no later than `updatedAt`.

Device and producer are independently optional. Record validation does not require the TTY
to exist or be a character device. A regular ordinary publication can therefore retain intent
with missing identity metadata, or with structurally valid metadata that is no longer live.

The public unbound overload validates the record and, when present, `intakeAt` before locking.
`intakeAt` must be finite, positive, and no later than `updatedAt`. The CLI always supplies it;
the native library overload also supports omitted intake time. It acquires the existing per-TTY
writer lock with the legacy 100 ms acquisition window, then calls `publishIntentUnlocked` with
`deadline: .max`. That preserves legacy publication timing after lock acquisition.

Under the lock, `publishIntentUnlocked` performs this sequence:

1. Check the deadline, validate the record/intake time again, and normalize its background.
2. Read and validate the latest observation for the TTY. A deadline error always propagates.
   For ordinary publication, every other observation read/validation error is ignored and the
   observation is treated as absent. For synthetic publication, that error propagates.
3. If an observation exists and `observation.observedAt > intakeAt`, reject as `staleDelivery`.
   Equality is accepted. This timestamp check applies to both ordinary and synthetic publication.
4. Compute an exact observation match from TTY, delivery ID, producer generation, and device.
   No provider, event, state, response ID, or verified-agent equality is required.
5. For synthetic publication only, require that exact match and `validProducer`; otherwise
   reject as `staleDelivery`.
6. Read and validate the latest intent with `recoverInvalid: !synthetic`.
7. A matching observation authorizes supersession when the current intent's delivery ID,
   producer, or device differs from the incoming record. Supersession can replace a current
   intent whose render timestamp is later than the incoming record's timestamp.
8. Otherwise require `incoming.updatedAt >= current.updatedAt`, rejecting an older incoming
   record as `staleIntent`. Equal timestamps are accepted.
9. Atomically replace only the latest intent file with the normalized record.

The latest observation is read, never rewritten, by intent publication. Ordinary observation
error tolerance is not observation repair.

## Synthetic live proof and exact failure classes

Native `validProducer` checks exactly these conditions:

- The path is a concrete native TTY (`/dev/tty` followed by ASCII letters/digits, with a suffix).
- Device and producer are both present.
- Current `device(tty)` equals the record's device.
- Looking up the producer PID succeeds.
- The current process generation equals the entire recorded generation.
- The current process device equals the record's device.

It does not require a verified agent, a foreground family match, continuing-owner equality,
native-surface discovery, adoption, or cached target information. Those are separate bound
publication/adoption concerns. Portable live proof should use the existing `store.device` so
Linux `/dev/pts/N` paths receive the platform's equivalent character-device check.

Important error distinction: `publishIntentUnlocked` is not
`validateSyntheticUnlocked`. The latter converts invalid observations into `staleDelivery`,
but the publication method propagates invalid observation errors unchanged. Consequently:

| Synthetic publication condition | Native state error | CLI exit |
|---|---|---|
| Observation missing, exact delivery mismatch, newer observation, or failed live producer proof | `staleDelivery` | 3 |
| Invalid observation JSON/schema, oversized/nonregular observation, invalid latest intent | `invalidRecord` | 1 |
| Unavailable observation/latest-intent storage | `storageUnavailable` | 1 |
| Deadline exhausted | `deadlineExceeded` | 1 |
| Older intent without authorized supersession | `staleIntent` | 3 |

Use portable `StaleRecordError` for stale delivery/intent cases. Do not map all
`OSError(errno.ESTALE)` failures to exit 3: bound target/ownership failures also use `ESTALE`
without being stale delivery results. Preserve invalid/unavailable errors as ordinary errors.
For publication, do not pass `stale_invalid=True` to `_observation`; that option belongs to
render-context validation.

## Ordinary repair boundary

Native `readLatest` catches only `invalidRecord`. It permits repair only when recovery is enabled
and `lstat` confirms the latest path is currently a regular file. It then returns no current
record and allows the subsequent normalized replacement. It neither deletes the file first nor
changes the observation. Synthetic publication disables repair.

Malformed JSON/schema, invalid timestamps/background/producer, and oversized ordinary intent
data can be replaced if the intent destination remains regular. Symlinks, FIFOs, directories,
unavailable storage, and deadline failures cannot be repaired this way. The portable
`records.read_latest(..., recover_invalid=not synthetic)` already expresses this boundary and
should remain the common implementation. Its `records.write` also refuses a nonregular
destination and uses a same-directory temporary replacement.

## Minimal shared helper recommendation

Keep the shared helper in the existing `Intents` class. Normalize once in each public wrapper.
A concrete useful boundary is:

```python
_publish_latest_unlocked(normalized, synthetic, intake_at, deadline, target=None)
```

The helper should own observation reading, stale-intake checking, exact synthetic observation
matching, synthetic live producer proof, latest-intent repair/ordering, and the latest intent
write. It should never render, inspect a paint policy, write target/bound caches, or perform
adoption. `target=None` is justified only by the two existing caller contracts; do not add a
policy object, extra storage layer, or configurable proof framework.

For the bound caller, retain its existing `_require_producer` and `_current(...,
targets_only=True)` checks before calling the helper. Pass the target solely so the helper can
retain the existing second `_require_producer` immediately before the latest-intent write.
Keep all target/bound cache reads, binding checks, latest-record equality checking, and bound
writes after the shared helper in `publish_unlocked`.

For the unbound caller, acquire the same per-TTY output lock, normalize the record, and call
the helper without a target. Ordinary unbound publication must not call `_require_producer`,
`status`, `_current`, `continuing_owner`, `ordinary_background_unlocked`, or the renderer.
Synthetic unbound publication needs only the narrower native-equivalent live proof above.

## Comparison with the portable file observed at report completion

The original bound-only `publish_unlocked` contained the common observation/ordering/write
block inline. Its `_require_producer` requires a valid bound target, producer/device equality,
exact live generation, and continuing-owner equality. Reusing it directly for unbound
publication would incorrectly reject ordinary records with missing identities and would
write target/bound data.

The refreshed portable source now has `publish_unbound` at lines 154-160 and the shared
`_publish_latest_unlocked` at lines 162-184. The helper follows the recommended boundary:
ordinary mode has no live producer requirement, synthetic mode checks observation before
live identity, `_latest` preserves regular-only repair, and a bound target adds the late
producer check without adding cache/adoption/painting to the helper. The bound wrapper at
lines 125-152 retains its own ownership/cache/binding checks.

Two exact-parity details remain for the parent to assess against its task scope:

- Native supersession compares current delivery ID, producer, and device, excluding the
  current intent's TTY. Portable `_delivery(latest)` includes TTY. They agree for correctly
  keyed intent records. A structurally valid record stored under another TTY's key could
  receive different ordering treatment. This alone does not justify broadening the task.
- The portable unbound wrapper currently gives normalization, lock acquisition, and
  publication one 100 ms deadline. Native legacy unbound publication gives lock acquisition
  100 ms and then uses `.max` for publication. The portable behavior is bounded, but is not
  identical to native legacy timing. Managed bound callers already retain their deadlines.

No runtime behavior or test results were checked. This report establishes source semantics
and the extraction boundary, not successful implementation or live acceptance.

## Implementation source check

# TAVS unbound intent source check

Date: 2026-10-14
Scope: Current uncommitted changes to `src/core/portable_intent.py`,
`src/core/portable_helper.py`, and their two unit-test files, compared with the native
intent publisher and organizer dispatcher. Source reads only. No imports, implementation
execution, tests, UI, provider calls, goal calls, repository edits, or other explorer report
reads were performed.

## Conclusion

No confirmed functional defect was found in the requested preservation properties. The
shared publisher keeps ordinary publication permissive about absent or exited identity,
requires an exact observation and live identity for synthetic publication, and leaves
target binding and rendering in their existing callers. The unbound metadata operation's
100 ms budget is intentional. Native legacy publication's `.max` internal I/O deadline is
not a requirement for this portable path and is not reported as a defect.

Two small test coverage gaps are worth distinguishing from source defects: equal intent
timestamps are not directly exercised by the new unbound tests, and no direct publication
test kills the bound producer during the latest-intent read to exercise the preserved
before-write revalidation. The source checks for both cases are present.

## Preservation findings

### Ordinary publication retains optional or dead identity

`Intents.publish_unbound` normalizes the record, acquires only the stable per-TTY writer
lock, and calls `_publish_latest_unlocked` without a target
(`portable_intent.py:154-160`). The common publisher performs process/device lookup only
inside `if synthetic` (`166-173`). Therefore ordinary publication can persist a valid
record with no producer or device, or one whose recorded producer has exited. Identity
shape and record chronology are still validated by `_normalize` and the record decoder.

This matches native unbound `publishIntent` at
`terminal-visual-state.swift:619-632`, which validates the record and calls the common
publisher without binding, and native `publishIntentUnlocked:752-755`, which invokes
`validProducer` only for synthetic publication.

`test_unbound_normal_intent_needs_no_device_or_live_producer_and_creates_no_target`
(`test_portable_intent.py:20-31`) covers both omitted identity and later publication after
the test's identity map is cleared. The helper test at
`test_portable_helper.py:123-133` also covers missing identity through the dispatcher.

### Synthetic publication requires the exact observation and a live producer/device

The common publisher reads the observation strictly for synthetic publication and checks
that `observedAt <= intake_at` (`portable_intent.py:164-165`, `82-87`). `_delivery` compares
the complete `(tty, device, producer, deliveryID)` tuple. Missing observation or any
identity mismatch raises `StaleRecordError` before publication.

The new synthetic branch checks all of these conditions (`166-173`): producer exists,
recorded device exists, current TTY device equals the recorded device, current process
generation equals the recorded producer, and process device equals the current TTY
device. `_lookup` and the subsequent explicit check retain the supplied deadline.

This matches native `matchesObservation` and `validProducer` at
`terminal-visual-state.swift:748-754` and `879-884`. Production `device_number` accepts
only concrete terminal paths and character devices (`portable_process_identity.py:197-208`).
Its `/dev/pts` support is existing portable device support, not newly introduced by this diff.

The new intent test at `test_portable_intent.py:33-43` asserts observation preservation,
successful synthetic publication, and rejection without replacing intent when the live
producer's device changes. Existing bound tests at `153-168` cover missing/mismatched
observation, newer intake, and generation replacement. The new owned PTY helper test at
`test_portable_helper.py:257-266` describes a real child producer and exact observation
success case, including no device output. These tests were read, not run.

### Record/storage errors retain their unavailable category

Synthetic publication calls `_observation` with `tolerate_invalid=False` and the default
`stale_invalid=False` (`portable_intent.py:164`). A malformed observation is therefore
an unavailable record (`EINVAL`), not stale delivery. Invalid files and storage errors
remain generic `OSError`; deadlines are propagated. `_latest` converts malformed JSON
to unavailable `EINVAL`, and passes storage errors through (`74-80`).

This intentionally differs from `validate_context_unlocked`, whose invalid synthetic
observation is classified as stale for output-context validation (`89-93`). Native has
the same distinction: `publishIntentUnlocked:735-743` propagates synthetic observation
read/validation errors, while `validateSyntheticUnlocked:702-712` maps invalid records
to stale delivery.

Ordinary publication may tolerate observation failures other than timeout
(`portable_intent.py:57-72`), matching native publication's ordinary catch behavior at
`739-743`. Its latest-intent recovery remains limited to invalid regular files, as
`portable_record_io.read_latest:71-85` verifies the destination is regular before repair.
Links, unavailable storage, and deadlines are not converted into repairable missing data.

The helper catches the distinct `StaleRecordError` class before generic `OSError`
(`portable_helper.py:151-154`), yielding silent organizer exit 3 only for stale data.
Generic storage/record failures produce exit 1 and the fixed private error. This matches
native organizer catches at `organizer-intake.swift:121-124`.

The new unbound corruption test (`test_portable_intent.py:64-75`) explicitly checks
unavailable rather than stale errors for synthetic corrupt intent and observation.
The new helper test (`test_portable_helper.py:135-140`) checks silent synthetic mismatch
and unavailable invalid flags. The existing dispatcher test (`143-158`) proves generic
target `ESTALE` is not mistaken for the stale record subclass.

### Unbound publication remains separate from target/cache authority and painting

The unbound call has no target argument and invokes neither `_current`, `status`,
`_require_producer`, target-path reads/writes, nor the renderer. It writes only the
ordinary intent record; the lock helper creates its ordinary writer lock and parent
directory. It does not write observations, adoption, bound intent, effects, or target
cache records (`portable_intent.py:154-184`).

The new helper dispatch extracts the existing delivery ID and original intake timestamp,
uses a fresh update timestamp, copies only present device/producer fields, and invokes
`publish_unbound` (`portable_helper.py:90-104`). It returns before the managed renderer
branch. The native organizer handler constructs the same ordinary-intent fields and
passes the original `context.observedAt` (`organizer-intake.swift:110-118`). Both accept
only synthetic flag `0` or `1`.

The new optional-identity test checks the exact two files created, intent and writer lock,
and absence of `targets` (`test_portable_intent.py:20-31`). Helper tests assert no renderer
construction and no target directory (`123-133`); the owned PTY test additionally asserts
no readable output bytes (`257-266`). Existing native intent adoption requirements remain
in `ordinary_background_unlocked` (`portable_intent.py:95-123`), so unbound persistence
does not itself grant rendering authority.

### Bound publication still revalidates producer before the latest-intent write

`publish_unlocked` still validates producer/owner and current target aliases before common
publication (`portable_intent.py:125-129`). It passes its existing target into the shared
publisher. After observation and latest-intent reads, `_publish_latest_unlocked` calls
`_require_producer(target, normalized, deadline)` immediately before `records.write`
(`174-183`). This preserves the old bound publisher's before-write revalidation.

Binding also retains its later target/producer revalidation and full latest-record equality
check (`142-150`), so a changed delivery or background cannot silently acquire the bound
copy. Cached target equality and malformed bound-copy failures remain in the bound
wrapper (`130-141`); they are absent only from deliberately unbound publication.

`test_binding_requires_the_full_latest_record_not_only_delivery_identity`
(`test_portable_intent.py:242-256`) covers the later full-record binding check. The existing
producer exit test at `230-240` exercises `validate_context_unlocked`, not publication's
after-latest-read check. A direct publication regression test for that specific timing
would close this coverage gap; the source itself retains the check.

### Ordering and delivery supersession match the native common publisher

Both implementations reject only strictly older `updatedAt` when there is no authorized
supersession. Python's `<` at `portable_intent.py:178` therefore accepts equal timestamps,
matching native's `>=` condition at `terminal-visual-state.swift:762`.

Supersession requires an observation whose complete delivery tuple equals the incoming
record. The prior latest record must differ in device, producer, or delivery ID
(`portable_intent.py:175-178`). Excluding the latest record's TTY from this second comparison
matches native `760-761`, which compares those three fields only. A corrupted-but-valid
cached TTY alone cannot authorize replacing a later intent with an older one.

The new unbound ordering/supersession test (`test_portable_intent.py:45-52`) covers older
same-delivery rejection and an observation-authorized new delivery whose update timestamp
is older than the cached intent. The adjacent wrong-cached-TTY test (`54-62`) guards the
comparison change. Equal-timestamp acceptance is clear in source but lacks a direct new
test case.

## Bounds and limitations

`publish_unbound` starts one deadline at 100 ms before normalization and supplies it to
locking, observation and intent reads, process lookup, and atomic record publication.
It does not renew that budget. The existing lock and record I/O helpers use nonblocking
lock admission and deadline checks (`portable_device_writer.py:35-60`,
`portable_record_io.py:64-130`). No request is made to reproduce native legacy infinite
internal I/O timing.

The report confirms source behavior only. Test results, macOS execution, UI behavior,
and externally installed hook routing are outside this check. No current runtime or
acceptance claim is made.
