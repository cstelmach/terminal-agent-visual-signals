> Parent: [PROGRESS.md](PROGRESS.md)
> Scope: Completed Phase 7 renderer foundation
> Consolidated: 2026-10-12

### Phase 7 preview foundation: 2026-10-12 21:18 CEST

Previous goal turn was progress: Phase 6 source/PTY recovery completed. Source was clean at
1aed4a7. Phase 7 remains In Progress; source rendering precedes controller/UI activation.
Two read-only explorations are saved as phase7-preview-lifecycle-research.md and
phase7-packaging-research.md. No build or live/native operations were delegated.

6ea096e reuses existing hex/luminance/contrast math for a conservative preview tint, guided by
current ordinary intent or configured defaults. Invalid/unsafe/negligible results are unavailable.
Configured normal-text contrast stays at 4.5:1 or the existing lower baseline. Four pure tests
cover light/dark, current intent/reset, unsafe baseline and invalid input; no program-color claim.

ad5d0ca adds a separate preview.json slot within exact target records. Preview leases expire at
two seconds; foreground/palette/title/cursor are untouched by these background effects. Ordinary
updates retain intent beneath the cue. Expiry/clear reveals latest intent, OSC111 for plain shells
or an underlying selective lease. Suspension permits previews, global rules win and recovery
cancels both slots once across aliases. Seven owned-PTY cases cover those paths and owner exit.

Missing-API red Dhy8yw preceded focused106 green JPQH9q and full416 green ZXLvOU. A targeted
renewal regression then found same-ID saves could change the original heartbeat (ZplMaF, two
assertions). Save now preserves preview timestamps, and refresh cannot extend preview ownership.
Final full416 PYYaKP passes in 4.366s without warnings; release5XFpXO passes in 9.54s.
Current release-helper Bats61 xSV7r5 passes (background12, managed22, idle6, emit6, liveness7,
CLI recovery8). Full isolated logs are retained. Scratch/backups:
`/tmp/tavs-phase7-preview-foundation-20261012/`; shared owned Swift scratch remains Phase 6's build.

Scope: six connected Swift source/test paths, including three existing shared writer paths from
Phase 6 required for preview lifetime/composition; API/bug/roadmap docs track this foundation.
No new product decision, generic parser, dependency, timer framework or recovery protocol.

Next: bounded configuration resolution; exact-ID controller start/clear and a separate selection
expiry timer; Sessions/menu recovery wiring; exact copied-file sync and fixture tests. Resolve and
regress an initial preview queued across independent recovery before enabling it: an in-memory
ID alone cannot observe headless cancellation of an effect not yet saved. Existing refresh/normal
release already use safe typed composition; do not reintroduce pending replay. No actual Ghostty,
installed-app change or real settings/schedules/process shutdown occurred. All physical cases
remain unverified. Goal active; Phases 8/9 not started. PLAN and SPEC body remain fixed.


> Current execution: [PROGRESS.md](PROGRESS.md).


## Additional preserved finished notes

### Phase 7 controller and configuration: 2026-10-12 22:19 CEST

Previous turn was progress; resumed clean f27d65d. Phase 7 remains In Progress. No native or
Ghostty runtime call was made. Two read-only follow-ups examined existing marker ordering and
installed manuals; native primary-source research closed the canonical-output and appearance gap.
Wiki recall returned unrelated passages (proceed). AGY stopped before provider because mandatory
fingerprinting conflicted with project rules; no retry, verdict or substitute AGY claim was made.

6ad445a adds start/clear operations and a pinned read-only marker revision. Cache the validated
target before in-lock comparison, preserving recovery discovery ordering and the original100ms.
Same-value recovery/resume replacements reject queued starts; stale clear cannot reapply ordinary
color after emergency reset. No new schema, counter, marker or polling protocol. Missing-API red
EeVWRO preceded implementation. Focused51 ZBRrkE caught a fixture reading bytes for a target
cached only after recovery; reading actual restored report items fixed it. Focused59 vkRHZl passed.

7c66769 adds one two-second selection expiry, exact current-ID guards, separate start/clear queues,
retryable cleanup and cancellation for recovery without painting. The skeleton was drafted before
its controller tests, a test-order deviation; tests then exposed a real multiselection failure.
Y7XFZg failed three assertions; pre-creating only the shared targets directory made EETWo0 pass.
7af78be fixes the common-parent creation race and preserves directory/deadline checks. A stress
case covers 32 targets in four fresh roots; no fake pre-created directory remains in the fixture.
Focused123 jqKiLg passed. The policy-race fixture's misspelled enum case failed compilation in
YdbNlw; current-source masterPaused corrected it, without production semantics changes.

a19a087 validates existing config before canonical color parsing. Missing nonempty config uses
explicit defaults to avoid Ghostty's default-template branch. Duplicate/missing/bad output and
unresolved dual-theme appearance fail explicitly. Upstream +show-config has no appearance flag
and can omit diagnostics; +validate-config is required. Config deletion during query and optional
file reads remain native limitations. No config input parser, copied config or OSC query was added.
Renderer missing-API red YyaNSR preceded seven-test green JFEYuB. Installed runtime remains untested.

Final full435 qr2sDR passes in 4.926s without warnings; release xHie4A passes in 15.74s. Earlier
full430 eWsOn6 and full434 BuURVw also passed. Broadened Bats73 YrbhdG found two obsolete parity
fixtures: regular-file output and an unused private lock-flag assertion. Fixed in 2a78209
by using an owned PTY and keeping observable suppression/definition/intent assertions.
Focused parity6 aU1cpi and final connected73 0wjoLC pass with the current release helper;
preprocessing/source syntax oFTeG3 and diff checks pass. No new Python scope warranted a rerun.

Reports: phase7-recovery-order-research.md, phase7-installed-config-research.md,
phase7-native-color-gap-research.md and phase7-agy-color-research-failed.md. Backups:
`/tmp/tavs-phase7-preview-controller-20261012/`; isolated failures/full logs retained.
Scope: ten Swift source/test paths plus one connected parity fixture and API/bug/roadmap docs;
shared state/recovery helpers are necessary Phase 7 extensions. PLAN and SPEC body unchanged.
Next: connect Sessions selection/Clear/Escape/close and GUI recovery; use a PID-bound executable
and explicit private configuration paths, then exact sync copies and signed fixture acceptance.
Before a fixture GUI recovery action, verify its headless factory cannot enumerate real Ghostty.
No install, sync, real settings/schedules, existing process shutdown or physical acceptance.
Goal stays active. Phase 2 remains Blocked; Phases 8/9 not started.


> Current execution: [PROGRESS.md](PROGRESS.md).
