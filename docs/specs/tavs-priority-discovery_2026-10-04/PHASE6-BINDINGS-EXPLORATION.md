# Phase 6: typed target bindings, effects and independent recovery

Last Updated: 2026-10-12
Version: 1.0
Source baseline: f067bef
Scope: read-only source/spec inspection. No native calls, process inspection, builds or live state reads.

## Recommendation

Extend the existing record store and bounded writer with one target-binding type, one current
effect record and one validation result. Use these across recovery, the broadcaster and the
future preview compositor. Keep per-TTY serialization and persisted current effects as runtime
correctness state, without a daemon, watchdog, historical ledger or separate control plane.

Registry filenames and age are discovery hints only. Persist verified target evidence before
paint, including for plain shells, so headless recovery can work without Automation or the GUI.
Distinguish a proven vanished original lifetime from failure to verify it. Retry unresolved live
targets and independently restore healthy targets even if another device never returns from open.

## Current interfaces and gaps

| Existing source | Reusable evidence | Gap for Phase 6 |
|---|---|---|
| process-identity.swift | Kernel PID/start generation, controlling device, foreground family | inspect returns nil for multiple causes; recovery needs known absence versus uncertainty |
| GhosttySurfaceID | Application generation and opaque terminal ID | Must preserve the binding when TTY is later reused |
| TerminalVisualStateStore | Bounded strict JSON, per-TTY flock, atomic writes, injected lookup/device/clock | No effects, cached recovery binding or ownership lease yet |
| Adoption in terminal-visual-state.swift | Exact surface/TTY/device/producer plus adopted deliveries | Private and tied to observations; plain shells need independent target binding |
| OrganizerContext | Frozen intake generation/device/delivery/time | Helpful for ordinary hooks, but not a controller identity or all-shell recovery authority |
| Broadcaster | Concurrent per-target writes | Empty registry, guessed filename device path, failure pruning and opaque pending replay |
| SystemProcessRunner | One 100 ms caller deadline; late-open write guard; nonblocking writes | No shared advisory lock, typed policy check or effect persistence |
| VisualRestrictionsStateStore | Strict persistent active/suspended/unavailable state | Must be reread inside serialized output, rather than trusted from dispatch |

Important current facts:

- `register_active_tty` and shellrc create/touch empty active-ttys entries. They contain no
  generation, device or native association. A current file mtime does not repair this.
- Broadcaster discovery currently uses full `ps tty,command` text and permissive agent substring
  matching. That is discovery only and cannot authorize a new write. The touched Phase 6 path
  must stop treating argv content as evidence and avoid retaining private command lines.
- Broadcaster deletes registry/pending entries on any device error. A timeout or EIO cannot
  establish that a target disappeared, so this drops recoverable failures.
- The store's private `withLock` opens a stable `writer-<ttyKey>.lock`, waits up to 100 ms and
  leaves its inode intact. Reuse that naming/locking principle; do not replace or unlink locks.
- `coverage(for:)` can adopt only a fresh successful native row. It is not an API for recovery
  with unavailable native access. Its private adoption records already reject reassignment to
  another native ID/application generation and retain matched deliveries for a continuing producer.

## Minimal typed model

Illustrative API shape, with field names chosen to match the implementation's final style:

```swift
struct TerminalTargetBinding: Codable, Hashable {
    let tty: String
    let device: UInt32
    let surface: GhosttySurfaceID?
    let owner: ProcessGeneration
}

enum TargetValidation {
    case valid(TerminalTargetBinding)
    case vanished
    case unavailable
}

struct TerminalEffectRecord: Codable {
    let schema: Int
    let target: TerminalTargetBinding
    let owner: ProcessGeneration // The controller generation, distinct from target.owner.
    let effectID: String
    let kind: EffectKind
    let background: String? // Normalized color when applicable, never arbitrary OSC.
    var heartbeatAt: Double
}
```

The two owners serve different purposes: the continuing TTY owner proves the destination
lifetime; the controller generation and heartbeat prove selective rendering ownership. Name
them `ttyOwner` and `controller` in final code to make that distinction obvious.

Keep kinds minimal, distinguishing global legacy styling from background-only selective
styling. Future preview/dim kinds may be added when implemented. Never store raw OSC/title/BEL
payloads in an effect record. The current effect color is retained for independent composition;
ordinary background intent remains its own file and is reread when clearing normal effects.

An effectID represents the current requested effect, not a provider response. It allows a queued
paint/heartbeat to prove the request was not canceled or invalidated by recovery. A heartbeat may
refresh only the still-existing matching record; it must not recreate a removed/replaced effect.

Persist one current record per target binding rather than erase an unresolved prior lifetime
just because its TTY pathname is reused. Per-TTY serialization still uses the physical TTY key.
If using a single per-TTY effect file, replacing a different old binding must first establish
that the old target is vanished; otherwise retain it or report unavailable. Do not add a history
of every paint. Normalized existing key encoding and opaque IDs suffice; no hashes are needed.

## Capturing a safe continuing owner

For a fresh native row with one exact TTY association:

1. Validate concrete TTY and current character-device number.
2. Inspect the native foreground PID and verify its current generation/device/group evidence.
3. Capture a continuing controlling-TTY owner. A verified parent shell on that same controlling
   device is usually a better recovery anchor than a short-lived agent or helper.
4. If walking parents, use only bounded `ProcessIdentity` parent/device/generation metadata.
   Verify each relevant generation; do not read argv, process bodies or private session files.
5. Preserve the native application/terminal ID with this owner, before the first effect paint.

Ordinary hook intake can bind an intent through its validated producer. It cannot magically
upgrade an empty registry entry or infer native identity. A headless registration/write helper
can capture the actual caller shell generation/device for an owner-only registry binding.
The standalone shellrc must pass its actual caller PID; the helper must verify the relation and
device rather than trust caller-supplied numbers. Its own short-lived process is not the owner.

An owner does not have to remain foreground to prove that the controlling TTY lifetime is still
the same. Foreground-family correlation is required for first meaningful agent adoption, not for
restoring an already verified continuing plain-shell target.

## Target validation rules

| Evidence | Result |
|---|---|
| Fresh exact native ID/app generation/TTY, with new continuing owner captured | Valid |
| Cached binding and same live TTY-owner generation/device, while native access unavailable | Valid |
| Validated old Ghostty application generation ended/replaced | Original native target vanished |
| Revalidated exact native target absence in the same current application instance | Original target vanished |
| Known original device absent, from trustworthy device metadata | Vanished |
| Native timeout/denial, unreadable record, ambiguous TTY, generation lookup unavailable | Unavailable |
| deviceNotWritable, EIO, backpressure or lock timeout | Unavailable/failed, retain for retry |
| TTY exists with another owner generation/device/native ID | Do not paint the new lifetime with the old request |

`ProcessIdentity.inspect` returning nil is not enough to choose vanished. It hides short reads,
permission failure, invalid metadata, zombie/exiting state and absent PID. Add a narrow presence
classification for recovery, or preserve relevant syscall evidence, instead of teaching every
caller to guess. A mismatched PID generation proves the old process ended, but not necessarily
that the native pane ended: the agent may have exited into a surviving shell. Use fresh native
evidence or the complete cached target/device evidence to classify the target itself.

A single missing row during catalogue traversal can race with a moved tab. Where absence is
material, revalidate the exact native terminal property rather than converting a transient
enumeration omission into proof of closure. Application generation termination is stronger.

Inside the writer, revalidate the opened descriptor with `fstat` and the expected character
device number. A matching pathname alone is insufficient. Also inspect current cached owner
generation/device and the application generation where available. Do not perform a two-second
native request while holding a lock inside the 100 ms device budget.

Native preflight can acquire a binding off the UI thread; the cheap continuing-owner checks in
the serialized write prevent a later TTY reuse from authorizing the old paint. If neither a
continuing owner nor sufficient current native evidence can be acquired, report unavailable.

## Minimal shared operations

Extend the current store with focused operations rather than create a new framework:

- Capture/validate a binding from a fresh native row or verified shell caller.
- Read cached candidate bindings and current effects without adopting observations from cache.
- Persist/refresh/invalidate one current effect and validate controller ownership.
- Read latest ordinary intent already bound to that target, otherwise return reset intent.
- Execute an already-opened device operation under the shared per-TTY lock and passed deadline.

Use one typed managed-write request enum for ordinary background, current global restriction,
background-only effect, ordinary clear and emergency reset. It selects rendering from fresh
policy instead of carrying precomputed unrestricted bytes. The request should include expected
target and, for an effect, its expected effectID/controller generation.

Avoid calling the existing public store methods that acquire `withLock` again from inside the
same managed output lock. Expose narrowly scoped unlocked read/composition functions under the
single serialized operation. Two independent lock acquisitions can consume two budgets or wait
on the caller's own lock; neither proves the required ordering.

The order remains:

```text
deadline starts -> bounded device open -> descriptor validation -> shared lock acquisition
-> fresh target/suspension/global-policy/effect check -> persist effect before paint
-> compose current permitted bytes -> deadline check -> bounded write
```

Every blocking/file step must be followed by the deadline check before any device write. A caller
timeout can leave a worker completing file IO, but it must never permit a late paint. Healthy
target fanout stays independent of that worker. The current 100 ms completion helper can be
extended; no second background service is needed.

## Lease versus global policy

Selective owner validity requires the same live controller generation and heartbeat no older
than six seconds. Refresh every two seconds while effects are needed. Reject future/nonfinite
heartbeats. A PID alone and a recent timestamp alone each fail ownership validation.

Dead/stale selective ownership stops blocking ordinary hooks. Relaunch starts focus Off and
clears valid orphaned selective effects to the latest ordinary intent, or OSC 111 for ordinary
shells. It must not adopt and continue the prior Manual/Automatic mode.

The ownership lease does not replace global lock/mute predicates. A finite legacy hard lock
remains effective until expiry despite controller death; that is the existing product contract.
Soft pause uses its existing PID/heartbeat rules. A dead effect owner cannot allow ordinary
paint through a still-valid global lock. Recompute global policy before selective lease policy.
Persistent recovery suspension disables both regardless of their owner or definitions.

For a global pause/lock ending normally, reset its palette/foreground and recompose the current
ordinary background plus any active selective policy. Emergency recovery instead sends only
OSC 104/110/111 defaults and does not immediately restore an ordinary theme. Neither path
replays historical titles or alerts.

## Recovery union and independent execution

Candidate discovery is the union of persisted effects, typed/legacy active-registry entries and
the current native catalogue when available. An empty legacy registry entry can be upgraded
through current exact native mapping or another verified cached binding. If no such evidence
exists, it remains an unverified candidate; do not silently discard it or write by pathname.

Deduplicate verified candidates by target binding, not titles/directories or bare TTY strings.
Retain old unresolved bindings separately from current new lifetimes. Catalogue denial does
not suppress cached effects/owner-only registry targets. Include plain shells painted without
shell integration: their persisted effect binding is how recovery discovers them.

Do not run the old `enumerateActiveTTYs` pruning before recovery. Its 24-hour mtime and attribute
failure rules erase candidates without proving closure. Candidate reading should be nonmutating;
retire only confirmed vanished state after classification, retain failures.

Recovery sequence:

1. Persist suspension, before helper discovery or any repaint. Swift/GUI use the same persistent
   store; the CLI uses its existing strict shell writer first.
2. Invalidate current selective ownership and obsolete opaque pending output. Preserve current
   typed observations/background intent.
3. Restore every safely validated candidate via the shared writer and independent healthy fanout.
   Revalidate suspension and binding after acquiring serialization. Record per-target results.
4. Report restored, vanished, skipped unaffected and failed/unverified separately; nonzero means
   incomplete live recovery. Missing helper still leaves the saved suspension intact.
5. Keep failed targets available for a retry. Resume explicitly persists active state, keeps
   selective focus Off and permits current global rules without replaying historical payloads.

Only label a target unaffected with affirmative evidence. Missing effect or an empty registry
does not prove that no old global styling reached it. The native union is explicitly required
by SPEC, so do not omit it merely because known cached candidates were restored first.

A healthy cached target need not wait for an unavailable native catalogue; cached fanout can run
while bounded native discovery resolves additional targets. Native revalidation has its separate
two-second limit, but the device call remains 100 ms including serialization.

`GhosttyCatalog.refresh` always dispatches its completion onto main. A headless command that
blocks main waiting for that callback can deadlock even though the native subprocess is bounded.
Expose one headless-safe synchronous/off-main snapshot path sharing the same serialized native
implementation, or run the recovery continuation off main. Do not initialize SwiftUI, default
Scheduler, login-item registration or rely on the menu application's event loop.

## Focused tests and limits

- Cached painted plain shell restores with native denied; registry-only empty live entry fails
  visibly; other healthy targets still receive reset.
- Same PID/new start time, same TTY/new native ID, app generation replacement, moved tabs and
  continuing owner moved out of foreground exercise binding validation independently.
- Lookup unavailable and deviceNotWritable remain failed; exact native/device absence becomes
  vanished. Failed records are present on the next retry.
- Effect record is present before a paint failure, survives a controller crash and can be
  recovered independently; no record may be omitted for unregistered targets.
- Live controller plus 2s/6s heartbeat boundary, dead generation and future heartbeat establish
  selective lease semantics; active legacy hard lock still wins after selective controller death.
- Paused-before-open and paused-before-policy writers are released after suspension. Neither
  repaints old restrictions; busy lock/backpressure/hung open do not delay healthy fanout.
- Recovery invalidates a queued effectID; stale paint/heartbeat cannot recreate it. A fresh
  deliberate preview remains possible under suspension in Phase 7.
- Relaunch clears valid orphaned selective effects to current intent/default with no title/BEL.
- Resume and later unmute cannot replay old pending OSC; observation/intent bytes are preserved.

No actual process, registry, native API or UI was examined. All recommendations require owned
PTY/injected-identity tests before implementation claims and dedicated visual acceptance later.
