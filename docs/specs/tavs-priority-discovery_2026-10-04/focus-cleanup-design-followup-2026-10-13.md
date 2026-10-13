# TAVS retained focus cleanup design
Last Updated: 2026-10-13
Version: 1
Source: `edd9528`; design only, retention remains unresolved

## Recommendation
Keep one logical focus Run, with one lease ID/heartbeat per physical outside target.
Retire only an expired/removed target's exact lease. While its cleanup is unresolved,
block new IDs on that target, not renewal on healthy targets. Split focus and preview
clear queues. No new persistent store, service, registry or generic result protocol is needed.

Source paths below are relative to
`/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/`.
No implementation, tests, builds, native/device calls or peer-report reads ran here.

## Existing cause and reuse points
- [focus-controller.swift:197](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:197): one aggregate heartbeat
  rolls the entire Run after six seconds, even when healthy targets have renewed.
- [focus-controller.swift:293](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:293): didRenew now records
  metadata-save evidence, but aggregate completion still demands every outside target.
- [focus-controller.swift:377](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/focus-controller.swift:377): any failed clear retains
  the entire Run, repeatedly retrying healthy/superseded targets with the bad target.
- [visual-recovery.swift:272](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:272): focus saves its record,
  then calls didRenew before physical output. This is metadata evidence, not paint success.
- [visual-recovery.swift:183](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:183): pre-open exact-ID/revision
  cancellation already uses the existing TTY lock and can precede an I/O failure.
- [terminal-visual-state.swift:250](/Users/cs/local/code/apps/terminal-agent-visual-signals/src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift:250): canceled IDs
  and expired same IDs cannot reactivate; retain those guards.

## Minimum connected source change
1. In the existing controller Run, replace the global focus heartbeat/ID role with an
   ephemeral physicalTarget-to-lease map. Each lease retains its full binding, exact ID,
   revision pin, confirmed renewal time and active/retiring state. Preview Run behavior stays
   separate. The current desired Manual/Automatic set remains logical controller state.
2. Build a per-target TerminalFocusRequest using that lease ID. Reuse VisualRecovery's
   independent fanout with a per-target request/operation factory; avoid sequentially waiting
   for bad F before renewing healthy H. No effect-record schema change is required.
3. isCurrent must also require that exact lease is still active for the target. Set retiring
   before cleanup, invalidating queued renewals. An unconditional didRenew updates the lease's
   actual-save evidence even if the logical Run/version has changed; only UI/current-version
   publication remains conditional. Keep candidate targets until uncertainty is resolved.
4. On expiry, that target's parallel worker clears its old exact ID first. If restoration is
   completed, issue a fresh ID and paint on the same accepted refresh. Each existing device
   call has its own 100 ms budget; two calls are not one 100 ms operation.
5. On failed retirement, retain one obligation and one coalesced retry for that physical target.
   Explicit mode switches must consult those pending obligations before creating another ID
   on the same lifetime. Healthy unchanged targets continue with their current IDs.

## Required write-stage distinction
Current VisualRecoveryItem alone cannot distinguish cancellation from repaint failure.
clearFocus can return unaffected because a global rule, changed marker or absent old record
suppresses paint. It is not evidence that the old physical presentation was restored.
Retain the target's repaint obligation after failed/no-paint cleanup; do not discard it merely
because ownership metadata is inactive. A proven newer owner/current repaint may take it over.

The smallest API addition is focused cancellation evidence from the existing pre-open locked
stage, analogous to didRenew, rather than a generic result protocol. Report exact old ownership
resolved only after all matching aliases are canceled or absence/supersession is established.
Physical completion still comes from the existing write outcome. If metadata is resolved but
physical output remains pending, recompose current policy/intent using the existing managed
reconcile path, without blindly canceling a newer ID or repainting an old revision's snapshot.
Keep the revision pin while ownership remains unknown; retain the restore target until actual
restoration or proven superseding responsibility resolves it.

No didRenew callback is not proof of no save: store.write can rename a record, then throw its
final deadline check before didRenew runs. An attempted lease therefore remains possible
ownership until the existing lock-protected record check resolves it. Never prune solely by age,
aggregate failure, missing callback or the newest logical Run.

## Contrast with pruning whole retired Runs
Locked cancellation/supersession evidence can safely prune obsolete exact target obligations.
It cannot bound the current whole-Run rollover model when F's metadata remains unreadable:
every rollover adds another possible owner. Repacking those IDs into a per-target dictionary
still grows history. Per-target retirement prevents issuing the next F generation while its
previous authority is unknown, preserving healthy H without inventing evidence.

## Finite bound and regression
Start H:h0 and F:f0 at t=0. At t=2/4/6 H renews; F fails. At t=8 only f0 retires.
At t=10/12/14/16/18/20/22/24 H:h0 still renews every tick; F retries f0 without issuing f1.
There are two target leases/obligations and one retiring F obligation throughout, rather than
three retired whole Runs and 15 old-run batches at t=24. When F clears successfully at t=26,
that same refresh paints f1 while H keeps h0. Repeating failure/recovery cycles stays bounded.
Test both pre-cancellation failure and post-cancellation repaint failure; unchanged healthy ID/
heartbeat, same-refresh fresh expired ID, mode switches, aliases, marker changes, post-rename
uncertainty and independent preview clear. Parent owns builds; these are required checks, not
evidence that retained-focus cleanup has been implemented or accepted.
