# TAVS Phase 6: ordinary-intent retention on device failure

Read-only source assessment, 2026-10-12. No source edits, tests, native/UI operations,
managed helpers, real runtime paths or Git commands were run. This is the one requested report.
Line references below describe the working source read during this assessment, including the
concurrent alias changes. The current No Bureaucracy rules at
`/Users/cs/.codex/AGENTS.md:327-369` were read. No new process machinery is recommended.

## Finding and recommendation

Claude R4 is source-confirmed, but its suggested after-failure remedy is incomplete.
Save and bind semantic intent before the device attempt, inside the existing 100 ms worker
budget, under the same stable per-TTY lock. Release that lock before calling device open.
Keep the existing opened-device, output-lock, publication/stale recheck and policy composition
before any bytes. Retained intent is a state result; device failure must still throw and produce
the existing nonzero helper result. Do not report restored/unaffected merely because intent saved.

There is a hard limit: no solution can guarantee serialized retention when that same lock is held
for the entire original 100 ms budget. Prepublication addresses open failure and output-lock-entry
failure *after successful prepublication*. It must fail truthfully if the publication lock itself
cannot be acquired. Guaranteeing retention in that case would require relaxing at least one
constraint: time budget, serialization mechanism, or deferred work. None is recommended here.

This recommendation preserves open-before-*output-phase*-lock ordering and guarantees the
lock is released before possibly wedged device open. It does acquire the same inode briefly for
semantic publication earlier. If the requirement forbids any lock acquisition before device open,
rather than forbidding holding output serialization during open, the requested retention and that
stricter interpretation are incompatible under the stated constraints. Do not silently reinterpret
that requirement as unconditional compliance.

## Current evidence

- `SPEC.md:154-159` requires latest normalized ordinary color/reset intent per TTY, independent
  of visible preview/focus/pause ownership, with atomic replacement and verified lifetime binding.
- `ProcessRunner.swift:119-165` currently opens the device, enters the writer lock, and only then
  calls `prepare`. The outer completion deadline is created once at `:171-182` and is 100 ms.
  A wedged or failed open, or lock timeout at `:147-157`, never calls `prepare`.
- `visual-recovery.swift:103-106` publishes and binds only inside that callback. Observation
  publication does not contain a background. R4 therefore drops this intent before callback entry.
- `terminal-visual-state.swift:535-546` has the existing public record publication path. Its
  `withLock` gets a fresh 100 ms wait at `:820`; its publication body uses `.max`, so that path is
  not an end-to-end managed deadline and cannot be used unchanged after device timeout.
- `publishIntentUnlocked` at `:580-622` already supplies normalization, latest-observation intake
  ordering, synthetic producer/delivery matching, and timestamp/new-delivery ordering.
  `bindOrdinaryIntentUnlocked` at `:323-341` supplies target, producer and continuing-owner proof
  plus equality with the normalized latest record. Use these functions, not a raw file replacement.
- The current alias changes matter: `ordinaryBackgroundUnlocked` at `:293-320` reads the latest
  per-TTY record and accepts a matching bound record from `equivalentBindingsUnlocked`. Binding
  the retained intent before device failure permits later same-lifetime recovery even if its child
  producer exits; an unbound raw intent alone cannot guarantee that behavior.
- `managed-output-entry.swift:116-129` already maps device errors to failure code 1 and stale
  semantic errors to code 3. No new success status or retry ledger is necessary.

## Why publication only after failure is inadequate

Claude's suggestion is at `phase6-claude-recovery-review.md:217`. An unchanged
`state.publishIntent(...)` in a catch after the 100 ms device timeout starts another lock wait of
up to 100 ms, followed by publication with `.max`. Caller time can approach 200 ms plus storage
work, and mutations can occur after the original deadline. The existing deadline is not preserved.

Passing the original deadline into that after-failure path fixes the budget problem but cannot
retain anything after the budget is already exhausted. It helps only early failures with remaining
time. Detached after-timeout publication would permit late mutations and obsolete delivery races;
it is not the requested solution. An atomic rename without the existing shared lock does not make
read/check/replace ordering atomic against competing observations or intents.

Publication itself does not hide device failure. Catching a device error, attempting retention,
then rethrowing the original error can be truthful. Catching it and returning success because
retention succeeded would hide output failure. Prepublication needs no catch-based second path.

## Exact smallest implementation scope

1. Extend the existing `ProcessRunner.writeManagedToDevice` contract with an optional semantic
   callback, for example `beforeOpen: ((UInt64) throws -> Void)?`. Inside its existing
   `completeDeviceWrite` operation, call it with the original absolute deadline, check that same
   deadline, then perform the existing device-open/output-lock/prepare/write sequence unchanged.
   The callback must release its record lock before returning. Keep the existing call form as a
   tiny protocol extension delegating with `beforeOpen: nil`, so unrelated callers do not need
   mechanical edits. `MockProcessRunner` and its managed handler must forward the new callback
   exactly once before an injected open/output failure; existing adapters must not discard it.

2. Extend the existing public `TerminalVisualStateStore.publishIntent` path to accept the managed
   target and original deadline, retaining the legacy unbound call behavior. In its existing lock
   body, first validate the requested target and `equivalentBindingsUnlocked` to reject changed
   lifetimes and conflicting/unknown aliases, then call `publishIntentUnlocked` and
   `bindOrdinaryIntentUnlocked` with the same deadline. That is semantic lifetime proof without
   claiming an opened descriptor. Leave opened-descriptor proof in the output callback.

   Extend `withLock` to accept a supplied absolute deadline. For managed use, check it before and
   after directory/lock-file work, during lock waiting, immediately after acquisition, and before
   the body. Do not reset it after lock-file open. Keep existing secure regular-file checks and
   deadline checks in `read`/`write`; managed lock entry should retain the writer's 0600 validation.
   The legacy path may keep its existing local wait and publication behavior.

3. In `VisualRecovery.write`, extract the existing publication tuple before starting the runner.
   Validate forced-reset title/reset constraints there, so malformed style cannot prepublish reset.
   For `.ordinary` and `.forcedReset`, pass `beforeOpen` that calls the target-aware publication
   path above. `.checkSynthetic`, register, restriction, reconcile and emergency reset do not
   prepublish an ordinary intent.

   Keep the existing in-output-lock `publishIntentUnlocked` plus binding call. Reusing it as the
   post-open recheck is the smallest safe change: a newer observation/intake or newer synthetic
   rendering arriving between publication and output still rejects the older writer. Removing
   that recheck would permit stale paint. Policy, effect ownership, cancel/reset and all OSC bytes
   remain under the opened-device output lock with the original deadline.

This reaches `ProcessRunner.swift`, `terminal-visual-state.swift`, `visual-recovery.swift`,
`Mocks/MockProcessRunner.swift`, and the targeted existing tests/adapters. There is no new schema,
runtime file kind, lock, ticket, service, shell output route or dependency. No shell status changes
are needed for retention; existing code 1 versus code 3 semantics remain meaningful.

## Targeted tests to add before implementation

Use the existing injected roots, PTY fixtures, process identities, semaphores and open injection.
Preserve the already present alias and late-open tests; do not replace them with mocks alone.

1. **Immediate device-open failure retains normalized intent and still fails.** Start with an older
   bound color, issue a fresh ordinary color through `VisualRecovery.write`, inject open failure.
   Expect the device error, latest normalized intent plus bound copy, no PTY bytes, unchanged
   observation, and a later healthy reconcile that paints that latest color. Repeat with reset.
   Current source is red because the failed open never publishes.
2. **Wedged open retains intent within one caller budget.** Block injected open beyond 100 ms.
   Expect caller timeout at the existing bound, retained latest bound intent, and no bytes. While
   open is blocked, another descriptor must acquire the same writer lock: prepublication released
   it. Release open after timeout; expect descriptor closure and no late policy/publication/paint.
3. **Output lock acquired by another writer after publication still retains intent.** Acquire the
   same fixture lock from the injected open barrier after semantic publication has completed;
   hold it through the remaining deadline. Expect output timeout, retained latest bound intent,
   no bytes, and no new 100 ms publication attempt after the error. This proves the later
   output-lock failure remedy, distinct from publication-lock failure.
4. **Fresh publication cannot authorize later stale output.** Prepublish A, stop it at open, then
   publish a newer observation/intake and B. Release A within its budget. Expect A to return stale,
   no A bytes, B to remain latest and bound, and subsequent reconcile to paint B. Include stale
   synthetic/forced-reset input before prepublication to prove it cannot replace B at all.
5. **Lifetime proof survives child exit but does not migrate.** Retain a child producer's intent
   before injected open failure; remove the child while its verified shell owner remains. Both
   plain and native aliases of that lifetime restore it. Changed owner generation, wrong device,
   unknown native metadata and conflicting live native aliases must not gain that bound copy or
   paint. Reuse existing state alias fixtures instead of introducing a new fixture system.
6. **Publication-lock full-budget boundary stays truthful.** Hold the stable lock before starting
   the call until after its deadline. Expect a bounded failure and no retained new delivery, no
   device open, no extra retry budget and no late mutation after release. This is the explicit
   unavoidable limit, not evidence that all lock-entry failures retain intent.

No tests or implementation were performed. Timing and filesystem stall behavior remain
unverified; only current source and existing test structure were inspected.
