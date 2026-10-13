# TAVS automatic cues during unavailable coverage

Last Updated: 2026-10-13
Scope: source inspection only. No tests, builds, native requests, device writes, UI actions,
provider requests, source changes or peer report reads were performed.

## Conclusion

The nil-clearing lead is confirmed. An existing unacknowledged cue can be erased by temporary
coverage failure. A connected final-writer check can erase it independently, even after the
reducer is corrected. Both paths conflate evidence of absence with absence of evidence.

Use the existing valid / vanished / unavailable distinction. Preserve a cue and its occurrence
book on unavailable evidence; reject new paints that require that uncertain source. Clear only
cues with confirmed resolution, source/destination invalidation, successful captured Go To,
downgrade, fresh native closure, Focus Off or recovery. Do not treat a failed lookup as an
acknowledgement. This can be implemented in the existing state store, reducer and controller,
without a new service, persistence scheme or retry framework.

## Authoritative requirements

SPEC G8 (line 48) says missing observations, unsupported APIs and uncertain targets must not
infer success, idle, completion or permission approval. Automatic acceptance (lines 438-451)
allows processing/resumption, exit, reset or invalid destination to clear a cue, and requires
multiple cues to survive independently. D15 (lines 353-356) releases when no unacknowledged
high-priority cue remains. The observations contract (lines 134-142) rejects unverifiable new
observations, but explicitly permits retaining an already adopted observation while its producer
remains valid. Age alone neither proves nor disproves a lifetime.

## Confirmed reducer path

`attention-state.swift:32-41` filters absent native surfaces and downgraded priorities, then clears
`cues[surface]` whenever `sample.observation` is nil, unverified, unsupported or lacks identity.
`FocusController.currentCoverage` supplies a nil-observation placeholder for every present row
whose coverage dictionary entry is missing (`focus-controller.swift:213-216`). Therefore a
present High row can lose its cue merely because observation coverage is temporarily absent.

`TerminalVisualStateStore.coverage` returns this same nil shape for:

- Missing or ambiguous native TTY mapping (`terminal-visual-state.swift:748-752`).
- Writer lock timeout, storage failure or any outer exception (around lines 796-800).
- Unreadable or invalid observation data (lines 757-767).
- `adopt` rejecting unknown producer/device data or a delivery that currently cannot be
  correlated (lines 811-836).
- Confirmed exit or reuse, because `validProducer` is also Boolean (lines 837-843).

These reasons cannot be distinguished by parsing the status text. Existing books survive the
nil guard, so the old occurrence usually cannot retrigger, making accidental removal persistent.
The current `testInvalidBindingAndClosureClearCuesWithoutReplayingAnOldRecord` explicitly treats
plain nil as invalidation. Split its unknown-gap and confirmed-invalid branches; retain its
fresh-catalogue closure and no-replay assertions.

## Confirmed final-writer counterpart

`isCurrentAttentionSource` (`terminal-visual-state.swift:171-178`) computes:

    validateTarget(target) == .valid && validProducer(...)

It returns false for either confirmed invalidation or unknown inspection. `updateManual`
(`focus-controller.swift:259-263`) also drops cue sources whose target cannot be captured. If no
remaining captured source returns true, its request callback schedules
`invalidateAutomaticSources` (lines 280-285). That function acknowledges every captured cue
(lines 328-337), including cues whose source was merely unknown or omitted during capture.

A deadline exception is already handled correctly as a paint rejection with no acknowledgement.
A nil process lookup and an unavailable target must receive the same non-resolution treatment.
When one source is confirmed ended and another is unknown, clear only the ended source. When a
third source is valid, it may continue authorizing automatic dimming; source checks must not
incorrectly clear unrelated unknown cues.

## Evidence classification

| Case | Existing evidence | Classification and action |
| --- | --- | --- |
| Coverage lock times out | `withLock` reaches its 100 ms limit | Unavailable. Retain cue/book; do not create from the missing sample. |
| Native TTY missing or ambiguous | `mappingIssue` present; no exact target | Unavailable. Retain prior native-ID cue; do not guess a mapping. |
| Unreadable, corrupt or absent record | No trustworthy latest observation | Unavailable. Retain cue/book. Corruption is not producer exit. |
| Producer lookup nil; `processMissing` false | Inspection failed without ESRCH | Unavailable. Retain cue; reject a source-dependent paint. |
| Device lookup nil; `deviceMissing` false | Device metadata unavailable | Unavailable. Retain cue; reject paint. |
| Newly observed delivery uncorrelated, live producer | No accepted adoption for this delivery | Unavailable/ineligible new input. Preserve the older adopted cue/book. |
| Previously adopted delivery now backgrounded | Saved native/TTY adoption, producer still valid | Valid retained delivery, already explicitly supported by SPEC. Do not clear solely on foreground-family change. |
| Producer generation differs | Successful lookup proves PID reuse | Confirmed invalid old actor. Remove that actor's cues. |
| Producer missing with ESRCH | `processMissing` true | Confirmed exit. Remove that actor's cues. |
| Current device number differs | Successful device lookup proves old physical lifetime ended | Confirmed invalid destination. Remove affected cues. |
| Device missing with ENOENT/ENXIO | `deviceMissing` true | Confirmed invalid destination. Remove affected cues. |
| Native ID absent from fresh successful catalogue | Present rows are authoritative | Confirmed native closure. Existing dictionary filtering may clear it. |
| Native application generation differs or ESRCH | Successful instance lookup or known missing | Confirmed old native lifetime ended. Clear affected cues. |
| Continuing owner lookup is unavailable | `validateTarget` returns `.unavailable` | Unavailable. Do not promote to invalidation. |
| Producer exists on a different controlling device | Successful identity proves emitting actor left this TTY | Confirmed invalid source association; old cue no longer authorizes effects. |

`validateTarget` already makes the important separation using `processMissing` and `deviceMissing`
(`terminal-visual-state.swift:146-169`). Tests at `terminal-visual-state-tests.swift:557-605`
already assert that nil lookup alone is `.unavailable`, while ESRCH, generation reuse, actual
device reuse and confirmed native absence are `.vanished`. Reuse this contract rather than
introducing a general availability framework.

The producer helper needs the equivalent tri-state distinction. Checking lookup generation and
controlling device is enough for source association; ongoing foreground-family membership must
not invalidate a cue already adopted against the same native/TTY lifetime.

## Smallest connected remedy

1. Give nil coverage an explicit confirmed-invalid versus unavailable indication, defaulting to
   unavailable. It can reuse `TerminalTargetValidation` if practical. Compute confirmed
   invalidation only from a trustworthy record identity plus positive lifetime evidence. Missing
   mapping, failed reads and lock failure stay unavailable. `attentionEligible` remains the
   separate new-occurrence creation guard. Never infer invalidation from display status strings.
2. In `AttentionState`, unavailable input skips updates and preserves cues and books. An explicit
   invalid indication removes cues while retaining seen-occurrence history for that surviving
   native surface. Fresh row absence still removes the book; actor replacement and verified
   processing/reset retain their existing semantics.
3. Change the source final check from Bool to tri-state, using the existing target classification
   plus generation/device evidence. Maintain the original caller deadline before and after every
   inspection. A missing captured source is unavailable, not proof that it vanished.
4. In the controller callback, authorize a paint only when at least one current cue source is
   valid. If none are valid, reject the paint. Schedule removal only for exact cue snapshots whose
   sources are confirmed vanished. Preserve unavailable snapshots. Existing main-thread
   version/run guards and captured identities still prevent delayed removal of a later cue.

A reducer-only nil guard is insufficient: it would preserve memory until the final writer's
Boolean check silently acknowledges it. A writer-only fix is also insufficient: the next
coverage poll would still erase the cue first. No new observation hooks or stored raw payloads
are needed.

## Concrete regressions

- Reducer: create a completion cue, apply nil unavailable coverage while its native row remains,
  assert the same snapshot remains; restore the old record, assert one original cue, not replay;
  acknowledge across the gap, restore old record, assert no recreation.
- Reducer: repeat for permission request plus delayed `permission_prompt`; the unavailable gap
  must not end the episode or create a second one.
- Reducer: explicit known invalidation removes the cue and old record cannot replay. Fresh native
  closure, downgrade, verified resumption/reset and new actor retain existing outcomes.
- Store: hold an owned writer lock so coverage reaches its existing 100 ms timeout; its result
  must be unavailable, not confirmed invalid. Missing/ambiguous mapping and a deliberately corrupt
  owned observation fixture receive the same classification.
- Store final check: remove producer metadata without marking missing; expect unavailable.
  Mark ESRCH and expect vanished. Repeat nil device metadata versus confirmed missing/reused
  device, and generation reuse. Preserve existing backgrounded-but-live producer acceptance.
- Controller barrier: queue an automatic paint, make cue-producer inspection temporarily nil
  while the continuing owner and other High shell remain alive, release worker. Assert no bytes,
  no focus record renewal and original cue retained. Restore inspection and assert the cue can
  resume dimming without a new trigger.
- Controller multiple cues: A confirmed exited, B unavailable, C valid. Remove only A; retain B
  and C, continue dimming via C. With no C, reject dimming and retain B. Later successful Go To
  may acknowledge B using its captured identity.
- Deadline: the tri-state source inspection cannot extend the existing 100 ms writer deadline;
  expired inspection rejects paint without resolving unknown cues.

All regressions should use the existing isolated Swift roots, injected missing-process/device
sets and owned PTYs. Current source was inspected without executing these cases; the report
claims code-path verification, not runtime reproduction.

## Connected heartbeat and zero-outside-target follow-up

### Heartbeat evidence is currently too broad

`FocusController.updateManual` updates `run.lastHeartbeat = at` when every outside row mapped and
no recovery item is `.failed` (`focus-controller.swift:291-295`). This is not evidence that any
focus metadata was renewed. `VisualRecovery` returns `.unaffected` when a writer predicate
returns false and emits no bytes (`visual-recovery.swift:254-259,267,503`). In that branch no
`saveEffectUnlocked` occurs, yet `.unaffected` satisfies the controller's heartbeat condition.

Conversely, a global pause or lock intentionally masks focus bytes *after* saving its focus
record (`visual-recovery.swift:263-271`). That also returns `.unaffected`, but represents an
actual metadata renewal. Therefore simply rejecting every `.unaffected` result would avoid the
false-heartbeat failure but would unnecessarily rotate IDs for correctly renewed masked focus.
Bytes and metadata renewal are distinct facts here.

`saveEffectUnlocked` correctly rejects renewal of an expired same-ID focus record
(`terminal-visual-state.swift:220-230`). `acceptCatalogue` rotates to a fresh run only when
`now - run.lastHeartbeat > 6` (`focus-controller.swift:197-205`). Repeated false controller
heartbeats can thus make a later healthy write reuse an expired ID. The write safely fails;
automatic focus then cannot renew that run until some other event resets it. Failed writes no
longer advance the heartbeat, so a later tick eventually rotates, but recovery is delayed and
misreported during the gap.

This ambiguity exists in current source for final-source inspection deadline errors: the callback
catches the error and returns false without invalidation, while its `.unaffected` result still
advances the controller heartbeat. The current nil/false cue-clearing behavior usually retires the
run for other unknown-source cases. Retaining those cues, as proposed above, exposes the same
heartbeat defect much more reliably. It is therefore a connected remedy requirement, not a
reason to abandon cue retention.

### Smallest heartbeat correction

Record explicit successful focus-metadata renewal at the point immediately after
`saveEffectUnlocked(effect, ...)` succeeds, including global-masked updates. A tiny focus-request
renewal callback, or an equivalent explicit renewal result returned to the existing controller,
is sufficient. It need not add persisted fields or change the terminal-byte semantics of
`.restored` and `.unaffected`.

Advance the run heartbeat only from actual renewal evidence for its current run/version and the
intended complete mapped target set. Keep rejected source predicates, thrown deadline errors and
zero-target fanout from advancing it. Preserve the existing full-mapping rule, retirement and
cleanup machinery. After more than six seconds without actual renewal, the existing next
catalogue acceptance should retire the old run and allocate a new ID.

Avoid reading cached effect files merely to infer renewal from `.unaffected`: the writer already
knows whether it saved that exact run's heartbeat, and an explicit transient success fact avoids
extra filesystem reads and ambiguous races. Any callback called under concurrent fanout must
record its fact safely. It must not independently extend the original writer deadline.

### All-High / zero-outside-target source resolution

With all catalogue rows High, `outside` and `targets` are empty. `recovery.apply` has no per-device
work, so `TerminalFocusRequest.isCurrent` never runs. Current source can therefore retain a
positively exited cue when stale but previously accepted coverage is supplied and its continuing
shell owner remains alive. There is no writer callback to schedule `invalidateAutomaticSources`.
It can also advance the in-memory heartbeat vacuously because `0 == 0` and the empty items array
contains no failed item. Fresh normal coverage presently erases any nil sample, which masks this
case, but that is the incorrect unknown-clearing behavior being fixed.

Resolve cue-source lifetimes once in the worker independently of outside-target fanout. Run this
before a failed emphasized-binding guard can bypass positive producer-exit evidence. Use the
same tri-state inspection and exact captured cue identities proposed above. Schedule removal of
confirmed invalid sources even when there are no device targets. Retain unknown sources. This
preflight complements, rather than replaces, the existing final writer checks, because a producer
can exit after preflight and before a later target's device write.

No targets means no focus metadata renewal and no device deadline to extend. Source inspection
must still be bounded; final checks with real targets continue receiving the writer's existing
original deadline. Do not introduce a second time allowance within a writer callback.

### Additional regressions

1. Start with a real focus record on an owned outside PTY; reject source validation on every
   two-second refresh for eight seconds while retaining its cue. Assert the saved metadata
   heartbeat remains unchanged and the controller does not claim renewal. Restore availability;
   the next accepted catalogue must write a fresh active effect ID, not first attempt the expired
   ID. The original cue must survive throughout.
2. Repeat with final-source inspection deadline errors. Assert rejection cannot advance the
   controller's heartbeat and cannot resolve the cue.
3. Apply a global pause while Automatic remains valid. Refresh beyond six seconds; focus metadata
   must genuinely renew although no focus bytes are written. Ending the pause must restore the
   dimmed set without stale-ID failure or unnecessary reset of attention occurrences.
4. Use only High rows and create a cue on a child agent with a continuing shell owner. Block the
   worker, positively exit that producer, then release it without any outside target. Assert the
   exact cue resolves and no device writer is called. Another unknown cue must survive, while a
   surviving valid cue must remain unacknowledged.
5. In an all-High catalogue, make every cue-source lookup unknown rather than ESRCH. No cue may
   resolve and no metadata renewal may be claimed. Restore inspection; require the same cue
   snapshot, not a new occurrence.

These are source-derived cases, not executed reproductions. The established defective
`.unaffected` heartbeat rule and zero-target predicate bypass should be corrected together with
the nil/Boolean availability distinction.
