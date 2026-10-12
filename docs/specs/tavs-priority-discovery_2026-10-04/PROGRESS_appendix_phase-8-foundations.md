> Parent: [PROGRESS.md](PROGRESS.md)
> Scope: Completed Phase 8 renderer and dynamic writer foundations
> Consolidated: 2026-10-13

### Phase 8 renderer foundation: 2026-10-12 23:34 CEST

Continued from clean `efcb6cd`, skipping only the explicitly Blocked native acceptance in
Phases 2/7. This slice covers the pure Phase 8 renderer, not an active manual controller.
`3ed6136` adds focusBackground: linear-light desaturation plus bounded neutral luminance
adjustment. Candidates require RGB distance 24, luminance change at most 0.08 and configured
normal-text contrast at least 4.5, or no worsening below that baseline. Invalid/unsafe cases
are unavailable. Shared current/reset background resolution preserves existing preview behavior.
PauseVisual.linearized became module-visible for reuse; this is the sole connected extra file.

Three new tests cover neutral dark/light/black/white, saturated current intent, invalid colors
and low-contrast extremes. Red `NO2q4J` failed on missing focusBackground. Focused `u9Gnlq`
passed 10/10; full `UpDPzH` passed 442/442 in 7.330 seconds without warnings. Final focused
`baLTjz` rechecked normalization assertions. Release `tCKZ1J` passed in 10.13 seconds. All runs
used tests/run-isolated.sh and the owned Phase 6 scratch build. No shell source changed.

Read-only source reports are preserved as phase8-writer-contract-research.md and
phase8-manual-lifecycle-research.md. Verified the important seams in source: current global and
fixed selective leases share effect.json; composition reuses the stored color; strict effect
JSON rejects new keys; $objectWillChange precedes mode publication. A manual recipe needs a
separate recoverable slot, fresh-intent composition, guarded renewal and exact-ID clear.
An already persisted lease also needs to reject old recovery revisions after partial cancel
and resume. Request-only guards cannot prove that. Preserve the pinned revision lifetime;
do not serialize descriptors or add another token file/service. No guard design is implemented
or claimed complete in this pure-renderer slice.

**Next:** add owned-PTY writer/record tests before enabling manual focus. Cover dynamic intent,
three-slot precedence, aliases, metadata validation, partial recovery/resume, queued renewal,
expired/canceled IDs and independent clear. Reuse current 100 ms writer and marker revision.
Then extend the same controller with captured IDs and keep Sessions' existing refresh timer
alive while window open OR Manual, observing the actual new $mode value. Catalogue failure
retains logical IDs and authorizes no new dimming; require a verified working binding before
painting outside targets. Preserve preview independence and end Manual on confirmed last closure.
Manual UI, lease/controller implementation and physical native acceptance remain pending.
The goal stays active. Do not start Phase 9 or claim real salience/readability from color math.


### Phase 8 dynamic writer checkpoint: 2026-10-13 00:10 CEST

Continued from `0b53c50`. `66111ec` exposes strict serializable marker identity while retaining
pinned revision comparison. `e1396ef` adds focus.json with normalized color inputs and revision,
without moving legacy fixed/global data. Unknown/missing/wrong-kind fields fail; blind heartbeat
and expired/canceled same-ID renewal cannot revive dynamic focus. `574ea99` composes from fresh
ordinary intent on every managed paint, preserving pause/preview precedence and alias authority.
Ordinary paint does not extend heartbeat. Exact clear cancels metadata before opening a device;
old IDs/revisions cannot repaint newer state or rearm after failed recovery and resumption.
`0f27931` retains retired preview pins through pending cleanup and verifies no stale repaint.

Red logs: `xcVcSx` lacked serializable identity, `b6ToyR` lacked focus record fields, `1XQ3hQ`
lacked writer operations. First record green exposed a lowercase expected-background fixture
(`SF51Vk`/`yHsyi0`); canonicalized the expected value. Integration `4ovYDw` used an unsupported
LockReason.none; corrected the unlocked fixture to manual, then 134 focused checks passed in
`CjUEpN`. Expanded writer/alias/style cases passed; final focused `zaXQgk` passed 75/75.
Full `ELq4oM` passed 457/457 in 7.623 seconds without warnings. Release `teOxiL` passed in
11.30 seconds. Managed-background, parity, recover and sync Bats `LebnbS` passed 43/43 using
the rebuilt helper. Every run used tests/run-isolated.sh and the owned Phase 6 scratch build.

Read-only follow-up is preserved in phase8-writer-followup-2026-10-13.md. The initial preview
pin concern was checked against fresh source after correction; the explorer found no additional
concrete normal-path writer/decoder mismatch. This is source assessment, not native acceptance.
Scope extensions are connected record/recovery/marker modules and tests. Reused the same stable
lock and original 100 ms deadline; no new token file, service or persisted desired mode.
No GUI activation, native query, production install/sync, real settings or session shutdown.

**Next:** extend FocusController and Sessions with captured working IDs and Off/Manual. Retain
revision pins while effects/pending cleanup remain live. After expiry, use a new paint ID rather
than renewing an expired ID. Require a verified working binding before dimming outside surfaces;
failed/empty catalogues preserve logical IDs but authorize no new paint or renewal. Keep polling
while Sessions is open OR Manual and observe the new published mode value. Focus Off preserves
preview; confirmed last closure ends Manual. Recovery and restart always leave Off. Then expose
and check the controls in a fresh private fixture. Physical Ghostty acceptance stays unverified.
A restored focus request may paint a preview layer; do not label that outcome as visible dimming.



> Current execution: [PROGRESS.md](PROGRESS.md).
