# TAVS configured-color freshness source investigation

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Source checkout: `/Users/cs/local/code/apps/terminal-agent-visual-signals`, HEAD `9af914a`.

Read-only scope: focus controller, renderer/configuration callback, native Sessions callers,
connected effect composition and tests, and the original dated research/review reports.
No source edits, builds, XCTest runs, app launches, Ghostty invocations, real-home managed CLI
operations, native catalogue reads or device writes occurred. Existing concurrent changes were
left untouched. Findings below use freshly read source and reports, not memory summaries.

## Verdict

Confirmed source defect: ongoing Manual focus and an Automatic run with continuing cues can
reuse the first resolved Ghostty background/foreground pair indefinitely. Every catalogue tick
can renew a six-second focus lease with that old pair. The six-second ownership lifetime does
not bound the configured-color snapshot's age.

A new selection preview resolves configuration afresh. It does not share the long-lived focus
cache. Individual preview operations still use one configuration snapshot throughout their
bounded display lifetime, which is a different limitation.

The source defect matters to SPEC's configured normal-text contrast requirement. If a running
Ghostty surface reloads a different configured pair while focus remains active, subsequent
focus updates continue evaluating readability against the previous foreground and may paint
an unsuitable background. Whether a particular installed Ghostty reload changes an existing
surface's foreground is native acceptance, and was not observed here.

## Original finding and its actual history

The final reviewer did not initially identify a freshness defect. The original
`docs/specs/tavs-priority-discovery_2026-10-04/final-claude-part-b-2026-10-13.md:188-195`
(L6) identified two configuration subprocesses per preview selection, unmeasured latency and
expiry anchored before preparation. It suggested application-generation plus file-identity/mtime
caching. The corrected combined review repeats the cache suggestion at
`final-claude-corrected-review-2026-10-13.md:269-274`.

The follow-up source investigation explicitly separated that suggestion from freshness:

- `preview-timing-source-check-2026-10-13.md:37-44`: preview queries once per selection;
  manual/continuing automatic focus already caches `run.colors`.
- Same report, `:61-74`: top-level identity/mtime is insufficient to identify all resolved
  configuration dependencies, and a new cross-operation cache is not justified.
- Same report, `:112-115`: focus's `run.colors` can survive configuration changes during a long
  run; the investigation did not establish that all focus colors were fresh.
- `final-review-corrections-2026-10-13.md:421-434`: preview duration was fixed while retaining
  fresh per-selection queries; long-lived focus colors and effective-config invalidation were
  expressly left for separate verification.

`phase9-integration-contract-research.md:120-123` earlier described per-run color caching as
existing behavior to preserve during Automatic integration. It does not establish a valid
freshness boundary. The current source still has that behavior.

## Current source path

All source paths below are under `src/macos/TAVSApp/`.

1. `Sources/TAVSApp/TAVSApp.swift:210-219` constructs four candidate configuration paths:
   `config` and `config.ghostty` under XDG's Ghostty directory and macOS Application Support.
   It injects the colors closure into FocusController. Each closure call resolves the selected
   app generation through `GhosttyCatalog.executable(for:)` and calls `configuredColors`.
2. `Sources/TAVSApp/ghostty-catalog.swift:57-62` resolves the selected live Ghostty executable
   only when the closure actually runs. This is application identity validation, not cache
   invalidation or discovery of current surface colors.
3. `Sources/TAVSApp/terminal-renderer.swift:29-50` does not cache. Each invocation checks the
   supplied file paths. Configured input runs bounded `+validate-config`, then bounded
   `+show-config --changes-only=false --no-pager`. Absent/nonempty-free configuration uses
   explicit defaults. The paths preflight loading; they are not passed as CLI arguments.
4. `terminal-renderer.swift:53-71` requires valid concrete colors and rejects unresolved dual
   light/dark themes. This failure boundary is bypassed on subsequent focus updates when the
   closure is never called again.
5. `Sources/TAVSApp/sessions-model.swift:147-152,228-237` polls and accepts a catalogue every
   two seconds while the window is open or focus is active. It forwards new rows/coverage to
   FocusController. It does not invalidate or refresh configured colors.
6. `Sources/TAVSApp/focus-controller.swift:185-195` creates one Run for Manual selection.
   `:226-261` renews work with that Run. `:198-208,235-249` creates an Automatic Run once there
   are cues and retains it while cues continue. No configuration-change event retires it.
7. `focus-controller.swift:337-338` is the decisive cache:

   ```swift
   if run.colors == nil { run.colors = try self.colors(instance) }
   let colors = run.colors!
   ```

   `Run.colors` is defined at `:574`. It has no dependency identity, expiry or invalidation.
8. `focus-controller.swift:356-378` sends that cached pair in TerminalFocusRequest on every
   accepted update, and advances per-target heartbeat after actual effect publication.
9. `Sources/TAVSApp/visual-recovery.swift:273-290` computes against request.colors and persists
   them in the focus record. `:393-401` recomputes from latest ordinary intent but the persisted
   `focusColors`. Thus latest intent freshness does not refresh configured foreground or the
   default used for nil/reset ordinary intent.

Fresh configuration boundaries are new previews, explicit new Manual selection, mode switch,
Focus Off/new focus, and Automatic runs retired at zero cues or changed High sets. Failed
catalogue refresh does not clear the Run's colors (`focus-controller.swift:270-278`). A later
renewal after effect expiry creates a new lease ID but can still reuse the same old pair.

Manual surface IDs include the application generation, so a Ghostty restart generally removes
the captured set. This finding concerns changed configuration within the same live generation,
not a proven cross-generation identity defect.

## Concrete contrast consequence

SPEC `:200-207` requires background-only styling and configured normal-text contrast of at
least 4.5:1, or no worsening of an already lower baseline. SPEC `:211-219` calls configuration
a guide rather than a running-color getter and requires live config-change/appearance/override
acceptance. SPEC `:511-513` requires representative config-change readability cases.

A pure Python calculation reproducing the source arithmetic in
`terminal-renderer.swift:95-120` and `PauseVisual.swift:46-79` gave:

| Resolved input or comparison | Result |
| --- | --- |
| Initial background `#171717`, foreground `#EEEEEE` | focus background `#070707` |
| `#070707` versus old foreground `#EEEEEE` | contrast 17.362072:1 |
| Same old focus background versus later light foreground `#161616` | contrast 1.113161:1 |
| Fresh background `#FAFAFA`, foreground `#161616` | focus background `#F1F1F1` |
| `#F1F1F1` versus current foreground `#161616` | contrast 16.021566:1 |

This is a source-derived numeric check, not production-function execution or a live Ghostty
reproduction. The cache path itself is established directly by source. Persisted recipes permit
later ordinary render composition to continue using the old pair between controller updates.

## Minimal correction

Do not add a dependency cache, watcher or configuration fingerprint subsystem. The repository
has no established complete dependency graph for includes, theme files, optional configuration,
environment or launch overrides. Root-file mtime cannot resolve this problem reliably.

For every current, nonempty Manual/Automatic outside-surface render update, call the existing
bounded colors closure once on the existing worker queue, before device fanout. Reuse that
one result across the targets in that update. Keep configuration subprocesses outside the
100 ms device-writer callback (`phase8-writer-contract-research.md:126-128`). Preserve all
post-lookup run/version/current-source checks.

Keep the previous accepted pair only for comparing recipe identity, not as a cached answer.
If the pair is unchanged, keep healthy lease IDs. If it changes, retire the affected Run's owned
leases and replace them through the existing per-target cleanup/replacement path. Do not
retire the logical Manual captured set or Automatic cue history just to change a recipe.

The existing contract prevents a one-line cache removal from being complete:

- `Sources/TAVSApp/terminal-visual-state.swift:255-262` rejects changing `focusColors` under
  the same active focus effect ID.
- `visual-recovery.swift:382-386` also requires equal recipe inputs across active aliases.
- `focus-controller.swift:466-499` already retires/resolves old per-target ownership before
  allocating replacement IDs, including transfer of an unresolved repaint obligation.

Use these existing retirement mechanisms on pair changes; do not casually remove the
same-ID recipe guard. Changing that guard would require proving safe alias replacement and
stale-request behavior, making it a larger correction.

If a later lookup becomes invalid, unavailable, timed out or unresolved dual-theme input,
report unavailable and stop renewing the cached recipe. Retire/clear the old owned effects
through existing exact-ID cleanup, retaining explicit cleanup failures and retry behavior.
Keep logical mode/captured set/cues so a later valid accepted update can recover. Never
silently return the last pair after lookup failure.

The current result handler excludes attempted targets from generic retirement cleanup
(`focus-controller.swift:392,415`). An implementation must ensure config-failure retirement
actually schedules cleanup instead of marking leases retiring and then excluding them. No
new cleanup queue is necessary.

One fresh resolution can take up to two independent two-second subprocess bounds. Existing
coalescing keeps one active update and one pending catalogue; the stale-catalogue/run-version
checks still reject outdated preparation. This fixes stale reuse, not native lookup latency or
an atomic configuration snapshot. Measure cost before designing any cache.

## Meaningful tests

Existing harnesses are sufficient. FocusControllerTests injects `colors`, fake identities,
VirtualClock, isolated TAVS_TEST_ROOT and owned PTYs (`:20-40,50-71`). No Ghostty app or CLI
is required. Existing tests use a constant pair for renewals and therefore do not cover this
failure. Renderer tests validate arithmetic, strict parser inputs and query failures, but not
long-lived controller freshness.

Recommended small regression set:

1. **Manual pair change within one run.** Start Manual with one working surface and at least
   two outside surfaces; colors callback returns the dark pair. After initial paint, advance
   two seconds, return the light pair and accept the same catalogue. Assert one callback per
   update, not per target; both persisted recipes and OSC 11 bytes use the light pair; contrast
   is checked against the new foreground; logical captured set/mode stay Manual. Under the
   existing immutable-recipe contract, assert changed recipes get new lease IDs. A third tick
   with the same pair preserves those replacement IDs.
2. **Automatic continuing cue.** Arm Automatic, introduce a valid completion cue, then change
   the callback pair while preserving High IDs and the same unacknowledged occurrence. Assert
   fresh colors/bytes, cue identity and Automatic mode retained. This cannot be tested only
   by switching modes or acknowledging every cue, since those already create new Runs.
3. **Successful lookup followed by unavailable lookup.** After a real initial focus effect,
   make the next callback throw unresolvedAppearance or process/configuration failure. Assert
   lookup occurred, no old-pair renewal or old-pair repaint, unavailable status, and old ownership
   cancellation/cleanup result. Mode/set/cues stay retained. A later valid update gets current
   input without reviving retired ownership. Current code fails because it never calls the
   second lookup. Use existing cleanup-failure behavior rather than demanding guaranteed
   physical restoration when the writer is deliberately blocked.
4. **Cancel while a renewal lookup is blocked.** Block the second callback, then call Focus Off,
   recovery cancellation or accept a superseding catalogue. Release it and assert no late
   publication/renewal/paint and no loss of the newer logical state. Existing tests block the
   initial callback; recurring lookups introduce this additional boundary.

Useful retained regressions: healthy per-target ID/heartbeat retention, expiry replacement,
global-mask metadata renewal, separate preview cleanup, latest-intent composition and alias
recipe disagreement. A configuration change while globally masked must also update or retire
the recipe so removing the mask cannot expose stale input; this can be included in test 2.

Do not relax `terminal-visual-state-tests.swift:38-48` (expired same-ID rejection) or
`visual-recovery-tests.swift:355-368` (conflicting alias recipes rejected). Pure renderer contrast
checks already exist at `terminal-renderer-tests.swift:5-38`; the essential new tests belong
at the controller boundary, where the stale pair originates.

## Remaining native acceptance after correction

Fresh per-update CLI resolution still does not read running per-surface OSC colors, program
cell backgrounds, launch overrides, selected dual-theme appearance, or guarantee that CLI and
running app loaded the same files. The parser correctly retains dual-theme unavailable behavior.
The lookup's validation and show-config calls are separate snapshots.

Live acceptance remains necessary for a single-theme configuration reload in the same app
lifetime, neutral dark/light de-emphasis, configured normal-text contrast, ANSI/TrueColor
readability, appearance and launch override limitations, and native update/cleanup timing.
Those limitations do not make the confirmed indefinite Run cache solely a native acceptance
question. Source-level freshness tests can and should close that narrower defect first.
