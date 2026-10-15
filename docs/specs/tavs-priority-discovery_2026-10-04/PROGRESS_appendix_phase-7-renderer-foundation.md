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


### Phase 7 GUI preview/recovery checkpoint: 2026-10-12 22:50 CEST

Reoriented from `67b89f1` and continued only Phase 7. Feature commits are `42c6849`
(bounded partial process reports), `473bd0d` (current-bundle headless client), `4352517`
(selection/clear/recovery model) and `0bcc176` (shared GUI factory and controls). Recovery uses
one serialized background queue, current Bundle executable, exact private roots and fixture IDs.
Capabilities retain two seconds; recovery allows ten seconds. Device callers still use 100 ms.

Selection changes start previews only in an open available catalogue. Refresh/priority edits
leave selection previews alone; Clear Preview, Escape, window close and stale coverage cancel.
Recovery cancels in-memory preview work without an ordinary repaint, saves the marker before
scope decoding/helper probing, and keeps partial JSON on exit 1. Failed helpers cannot undo
saved suspension. Model feedback survives refresh and flags unavailable native coverage.
Fixture preview colors are explicitly unavailable; they cannot query the real Ghostty app.

Preserved red logs for missing output/client/model APIs: `aWUa66`, `TPY6z2`, `c162EX` under
isolated runner roots. The new factory/scope test run `nCGKpp` failed on missing createDefault
before wiring; focused `ER4JHG` passed 105 tests. Final full Swift `GWACY7` passed 443/443
in 7.740 seconds with no warnings; release `imNxPL` passed in 16.34 seconds. Recovery/suspension
Bats `HvRYSG` passed 20/20. All used tests/run-isolated.sh and the owned Phase 6 scratch build.

Fresh ad-hoc signed bundle: `/tmp/tavs-phase7-gui-20261012/staged/TAVS Preview Acceptance.app`.
Only its private fixture state was mutated. CUA verified three distinct duplicate rows, missing
observations, suspended/active recovery controls, accurate three-target partial failure, explicit
unavailable preview and Escape clearing while selection remained. A High edit hit capture error
-3811 after input; fresh AX and the private priority file confirmed success, without re-clicking.
Quit/relaunch through the same owned bundle retained High and suspension, with Focus Off.
The relaunched owned PID is 26990; launch/relaunch logs and state remain in that scratch root.
No real Ghostty action, production install/sync, login registration, schedule edit or real-process
termination occurred. Physical color/timing/navigation/Spaces cases remain unverified.

ProcessRunner, managed-output visibility and the safe fixture factory are connected changes beyond
Phase 7's named primary files. Reused the existing runner, marker, catalogue decoder and JSON;
no new service, dependency or recovery protocol. API, bug, roadmap and companion docs are current.

**Next:** finish Phase 7 exact-copy packaging and fake-install coverage. Read cmd-sync and its
connected CLI/adapters before tests. Keep required native acceptance Blocked in Phase 2. Do not
start Phase 8 or treat fixture controls as physical terminal evidence. The master goal stays active.



> Current execution: [PROGRESS.md](PROGRESS.md).

### Phase 7 source and copied-install checkpoint: 2026-10-12 23:05 CEST

Continued from `185e4d2` with clean source. `0efa3c4` copies the root dispatcher, Claude/Codex
adapters, both hook JSON files, plugin shell source and Codex installer. Required directories,
copy operations and execute-bit repairs propagate errors, including conditional Bash callers.
Core/CLI dependencies still use existing globs. No recursive sync, rollback service or new
installer mode was added. Earlier successful copies may remain when a later copy fails.

Seven new fake-install tests compare exact bytes and execute copied CLI recovery/help,
standalone shell installation/readers, Codex installation and disabled-visual Claude/Codex
intake. Direct scripts start at 0644 to reproduce stale modes. Preferences, schedules and lock
sentinels are preserved. Missing explicit helpers remain failures after suspension is saved.
Typed fixture logs contain only fixed provider/session identifiers; no raw payload logging.

Red `Cn3aV3` failed all six initial copy/dispatch/error cases. First green attempt `D33Qwd`
passed five but failed an expected path containing a double slash: the copied Codex installer
correctly normalized it. Normalized the test root, not production argv. Final seven cases
passed in `W0bqBi`. Selected regressions `n3orIs` passed 62/62 (sync, recover, shellrc,
managed-background and suspension parity). `BQPYDG` repeated seven copied-entry cases against
the newly rebuilt helper. bash -n and diff whitespace checks passed.

`cc1b515` retires the old Scheduler reset method after the menu replacement left only test
callers. Four action-only tests are removed; mixed scheduler suspension/unknown-state assertions
remain, as do current independent recovery/client regressions. Full Swift `Mz8PCt` passed
439/439 in 7.188 seconds without warnings. The previous 443 count included those four retired
tests. Release `o4lwtX` passed in 9.97 seconds, using the owned Phase 6 scratch build.
Read-only follow-up: `/tmp/explorer-tavs-sync-failure-cases-20261012.md`; source findings were
verified with failure injection and existing-mode fixtures. No native query or real-home sync.

Phase 7 implementation steps 1-5 now have source/owned-PTY/fake-copy/fixture evidence. Required
physical two-second +/-250 ms highlighting, keyboard focus, real hidden/split targets, ANSI/
TrueColor and light/dark content, pane/Space navigation and locked-menu use remain unverified.
Phase 7 is Blocked on these accepted native cases, not DONE. Earlier Ghostty Computer Use
access denial remains binding; no alternate native automation or unchanged access retry ran.
The prior staged fixture remains available; production app, schedules and sessions are untouched.

**Next:** Phase 8 manual captured working set may proceed from this verified source foundation.
Keep Phases 2/7 blocked acceptance visible. Read Phase 8 plan/spec and connected state/controller
callers before tests. One phase per next goal iteration; the master goal remains active.

### Phase 9 native preview diagnostic source checkpoints

**Phase 9 native preview diagnostics, 2026-10-15: 3a579d2.** Expiry retains outcomes; preparation distinguishes colors/mapping. Three new cases pass; real-PTY/full checks remain unstable. [Results](caller-deadline-source-check-2026-10-14.md#native-preview-outcome-and-binding-diagnosis-2026-10-15).
**Next:** fix denied inspection of root-owned login parents in Swift/Python without weakening identity checks. KERN_PROC_PID probe succeeds. Native highlight still fails; staged app remains suspended/Focus Off. Final reviews, full677 and native/Linux acceptance remain open. Goal incomplete.

> [Verified Darwin identity checkpoint](PROGRESS_appendix_phase-2_launch-debugging.md#verified-darwin-identity-checkpoint).

**Phase 9 mapping/recovery, 2026-10-15: 34a838a.** Mapping snapshots omit display reads.
Catalogue 19/19 passes; full Swift 683 has 88 failures across 41 methods, still unresolved.
Independent recovery with only the test app stopped restores both panes in 1.829 s, then resumes it.
Post-recovery 038 preview reports 1/1; the operator visible check on 031 is pending.
[Results](caller-deadline-source-check-2026-10-14.md#mapping-only-snapshots-and-independent-native-recovery-2026-10-15).
**Next:** measure queue/native time and device preparation; inspect the saved source map
`/Volumes/external/agent-data/reports/2026-10-15/tavs-device-prepare-cost-explorer-220300.md`.
Keep the app open, suspended and Focus Off. Final reviews/native/Linux cases remain; goal incomplete.
