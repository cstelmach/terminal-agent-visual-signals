# TAVS Phase 8 managed-writer contract

Last Updated: 2026-10-12
Version: 1
Source baseline: `efcb6cd`+
## Scope and conclusion

This is a read-only source assessment. No build, test, native request, AppleEvent, UI action,
device write or real-home operation was performed. Only this requested report was created.

The smallest sound extension is a renewable `.selectiveBackground` record containing normalized
manual transform inputs, a separate selective slot in the existing target directory, and typed
start/renew/clear operations through `VisualRecovery.performWrite`. The existing writer lock,
deadline, target validation, alias reconciliation, lease lifetime and renderer math can all be
reused. A stored rendered color must stop being the authority for manual dimming.

No separate focus service, output writer, token file, arbitrary OSC parser or persisted desired
Manual mode is needed.

All source paths below are relative to:
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.

## Existing contracts to preserve

### Managed writer and latest ordinary intent

`Sources/TAVSApp/visual-recovery.swift:114`, `VisualRecovery.performWrite`, owns the composition
point. It publishes ordinary intent before opening and opens the device before acquiring the
existing per-TTY lock. Inside that locked callback it validates the descriptor and current
target again, then composes within the original bounded deadline. It does not need another
lock or writer.

Ordinary publication is bound to the validated target at lines 207-211 before current policy is
evaluated. The normal-background lookup is
`TerminalVisualStateStore.ordinaryBackgroundUnlocked(for:deadline:)` at
`Sources/TAVSApp/terminal-visual-state.swift:301`. It reconciles the current per-TTY intent and
bound copies for valid aliases, including the latest adopted ordinary state after the producer
has exited.

Today, `visual-recovery.swift:239-250` chooses a selective lease's stored `background` verbatim.
`testOrdinaryUpdatesRemainStoredWhileActiveSelectiveBackgroundWins` records that frozen-color
behavior. New ordinary colors are stored, but dimming is not recomputed while the lease wins.

### Lease, tombstone and decoder

`TerminalEffectRecord` at `terminal-visual-state.swift:49` holds schema, target, controller
generation, effect ID, kind, background, heartbeat and active flag. `isSelectiveLeaseActive` at
line 170 checks the owning process generation and uses a six-second selective lifetime.
Previews use their distinct two-second, nonrenewable lifetime.

`saveEffectUnlocked` at line 207 prevents reactivating a canceled record with the same ID.
`refreshEffectUnlocked` at line 231 checks ID/controller, controller generation and target, but
does not check the old lease's age, the current desired run or the recovery revision. Blindly
calling that helper can revive an expired lease. A typed renewal must add those checks.

The custom decoder at line 1108 rejects unknown keys. New fields need explicit decoding and
kind-specific validation. Bad or missing manual inputs must not silently acquire default colors.

## Minimal connected extension

### Record and slot

Keep `TerminalEffectRecord` and add one narrowly defined optional manual-color input containing
the normalized configured background and foreground. `TerminalRenderer.Colors` already
normalizes those inputs, but is currently Equatable rather than Codable. Either make that
existing value strictly Codable or store its two normalized strings in the existing effect.
There is no need for a generic recipe format or configurable transform implementation.

For `.selectiveBackground`, composition derives the visible color from the current ordinary
background and these fixed inputs. The existing `background` may remain a last result or a
compatibility field, but cannot supply the manual output color.

`effectURL` at `terminal-visual-state.swift:466` currently puts global and selective effects in
the same `effect.json`. A global pause therefore overwrites a manual lease. Give selective
records a dedicated filename alongside `preview.json`, for example `selective.json`.
Update only the connected slot readers:

- `currentEffectUnlocked` at line 193 must validate the requested slot's actual kind.
- `cachedRecords` at line 366 must recognize the new filename and its exact target path.
- `VisualRecovery.effectsUnlocked` at `visual-recovery.swift:427` must enumerate all three slots.
- Existing cancellation and recovery should receive those records through the same enumeration.

Legacy fixed selective records in the base slot must remain safely recoverable or receive a
narrow, explicit retirement rule. They must not be interpreted as a new manual recipe by
inventing a configured foreground. No production manual controller exists at this baseline.

### Typed start, renewal and clear

Use a manual request analogous to `TerminalPreviewRequest` at `visual-recovery.swift:4`: run ID,
normalized colors, pinned restrictions revision and an `isCurrent` closure. Add typed operations
to `ManagedVisualOperation`, then handle them within the existing locked callback.

For start or renewal, verify the current run and matching revision before policy lookup and
again after it, as preview already does at lines 180-198. Validate the actual current target and
descriptor through the existing path. Renewal must identify the same active record, controller
and manual inputs. An expired or canceled ID must not gain a new heartbeat merely because a
previous request finally ran.

Only the controller's explicit renewal advances the heartbeat. Ordinary agent writes may
recompute the visible color but must not extend the lease. Otherwise busy agent output could
sustain restrictions after the controller stops renewing.

Clear only the matching manual run/controller records across valid aliases, then recompose.
An old clear must not cancel a newer manual run or a preview. A fresh start replacing another
manual ID should cancel that prior ID using the current record machinery.

### Composition on every managed paint

Read the latest ordinary intent inside the writer callback, after this operation's publication
and binding. Derive manual dimming using one pure native renderer function and the stored
normalized color inputs. Reuse `PauseVisual` color, luminance and contrast math already used by
`TerminalRenderer.previewBackground` at `terminal-renderer.swift:64`.

For each painting callback with a current manual record, derive from that current intent rather
than a start-time or last-painted color. This includes ordinary render paths without a new
background when an overlay is active. Nonpainting `.register` and `.checkSynthetic` operations
should keep their current early returns.

Select visible output in the existing priority order: current global rule, active preview,
active manual transform, current ordinary background. A hidden manual transform being
unavailable must not block a valid global pause or preview. When dimming is visible but no safe,
detectable result exists, report it as unavailable; do not reuse an old color or claim success.

The manual function must visibly alter neutral dark, light and gray bases, rather than only
reducing chroma. Its normal-text contrast must remain at least 4.5, or not worsen a baseline
already below 4.5. `nil` or `reset` ordinary intent resolves through the captured configured
background. Load/validate configuration outside the 100 ms writer callback; perform only
bounded native arithmetic inside it.

Preserve existing ordinary-render title and BEL semantics. Focus clear/preview clear should
emit only the recomposed background, except the existing foreground/palette reset needed when
leaving a global restriction. Do not replay stored title text, BEL or prior full terminal output.

## Alias, preview, pause and recovery boundaries

### Alias handling

`equivalentBindingsUnlocked` at `terminal-visual-state.swift:255` validates physical lifetime,
device and native surface identity, rejects unknown/conflicting aliases and allows at most one
native surface for a physical target. `VisualRecovery.apply` at `visual-recovery.swift:383`
deduplicates physical writes and reports. Preserve those rules.

Manual alias agreement must compare run ID, controller generation, normalized transform inputs
and cancellation revision, if recorded. Comparing last computed backgrounds is wrong because
those colors can legitimately lag the current ordinary intent. Disagreeing manual authority
must fail rather than choose whichever alias was read first.

### Preview and global pause

Previews keep their own record and precedence. Selection preview clear or expiry must expose a
fresh manual transform of the latest ordinary intent, not the manual start color. Changing UI
selection or priority cannot retarget the captured manual working set.

A global rule paints first but must preserve the separate manual record and its owner renewal.
On global release, use the existing legacy foreground/palette reset, then derive the manual
background from the latest ordinary intent. Preserve desired Manual state across that pause;
explicit persistent suspension/recovery/resume ends it.

`focus-controller.swift` currently contains only the preview run and preview timers. Its
`clearPreview` cancels all current controller timers. Manual renewal needs a distinct timer/run
within that same controller so preview cleanup cannot accidentally stop manual heartbeats.

### Recovery revision cancellation

`VisualRestrictionsStateStore.captureRevision` and `matches` at
`visual-restrictions-state.swift:38` and `:57` pin the existing marker inode/device with an open
descriptor. Rewriting the marker with the same boolean still changes that revision. Reuse this
authority for queued manual starts, renewals and clears. A boolean or manual UUID alone is not
sufficient.

`VisualRecovery.recover` at `visual-recovery.swift:270` writes the marker first, then clears
effects while painting recovery output. `reconcilePriorEffects` clears cached selective state
on relaunch. Do not restore desired Manual mode from effect cache after relaunch/resume.

There is one additional source boundary to test: request-only revision guards do not invalidate
an already persisted manual lease when cancellation fails because its device/lock is busy.
After a later resume marker replacement, an ordinary helper could otherwise display that old
lease within its six-second lifetime. The existing record can carry the serializable identity
of its initiating marker revision, checked by every composer. Keep the owning run's pinned
revision alive while that run or pending cleanup is live. Do not serialize the descriptor
integer/object or add another token file/service. If another minimal implementation is chosen,
it must pass this partial-cancellation case, including replacement with the same boolean.

## Required source tests

Extend the existing tests, using injected clocks, process generations, roots, policies and
descriptor/device seams. None of these needs native Ghostty or real terminal access.

1. In `visual-recovery-tests.swift`, change ordinary intent repeatedly during Manual and assert
   each managed paint derives from the newest intent. Include a native/plain alias, an ordinary
   render without a background, and latest bound intent after the producer exits.
2. Assert explicit renewal sustains a lease, ordinary writes do not refresh it, and dead/reused
   controller generations, expired IDs and canceled IDs cannot renew or resurrect.
3. Assert manual/global/preview records coexist. Global release and preview clear/expiry expose
   freshly recomputed manual output without stale title/BEL replay. Recovery cancels all slots
   across aliases once. Old clear operations cannot clear newer runs.
4. Extend existing queued-marker tests to manual start/renew and late callback execution. Include
   marker replacement with the same boolean and recovery/resume with failed or busy cancellation
   followed by an ordinary write. No old manual record may regain authority.
5. Assert equal manual recipes across aliases compose once and conflicting colors, controller,
   revision or native/physical identity fail. Preserve scoped-target guards and healthy fanout.
6. In `terminal-visual-state-tests.swift`, cover the third slot, cached recovery enumeration,
   strict new-field decoding, invalid colors, wrong-kind fields and narrow legacy handling.
7. In `terminal-renderer-tests.swift`, cover dark/light/neutral bases, changed ordinary colors,
   reset resolution, visible difference, contrast floor and unavailable results. Do not equate
   pure color math tests with physical readability acceptance.
8. In `focus-controller-tests.swift`, cover independent preview/manual timer cleanup, current
   run/revision renewal guards, captured set versus browsing, pause release and suspension Off.

Useful current regression anchors in `visual-recovery-tests.swift` include:
`testPreviewCancellationPreservesUnderlyingFocusAndIgnoresOldID`,
`testGlobalRuleWinsOverPreviewWithoutDestroyingItsSeparateRecord`,
`testNativePreviewAndPlainFocusRecoverOnceAndCancelBothRecords`,
`testResumePaintsCurrentRequestedSoftRuleAndDoesNotReviveOldSelectiveID`,
`testReconcileRestoresLatestBoundIntentOnceAcrossAliasesAfterAgentExit`, and
`testUnscopedHookComposesNativeLeaseAndRecoveryCancelsEveryAliasOnce`.

## Validation limits

This assessment establishes reuse points and source changes, not working native behavior.
Existing writer deadlines, open-before-lock ordering, fresh descriptor identity validation and
output backpressure tests remain binding. Keep configuration subprocesses, native catalog
queries and timer ownership outside the locked writer callback.

Physical dark/light readability, distinct-target painting, preview/pause release, sleep/wake
and kill/relaunch behavior still require the separately authorized dedicated-target native
acceptance. Earlier native acceptance blockers must remain visible in Phase 8 status.
