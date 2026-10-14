# Focus poll coalescing source check

Inspected the current uncommitted controller/tests and the connected capture, attention,
recovery, restrictions, renderer, catalogue, Sessions model, and SPEC contracts on 2026-10-14.
No builds, tests, native operations, or real-home writes were run. The parent owns those checks.

No new paint-safety defect was confirmed in this diff. The following conclusions are source
findings, not native acceptance.

`focus-controller.swift:257-267` coalesces only while an update is in flight. It compares the
emphasized IDs and each row's `id`, `tty`, `foregroundPID`, and `mappingIssue`. Those are exactly
the surface fields read by `TerminalVisualStateStore.captureTarget` (`terminal-visual-state.swift:
129-136`). Ignoring title, directory, window/tab grouping, and selected-tab status does not omit
a capture or rendering input. `GhosttySurfaceID` includes the application process generation,
so an application restart differs even when terminal text IDs repeat.

The comparison uses the latest pending catalogue, but does not undo a prior invalidation:
once a real change increments `run.version`, identical later polls preserve that new version;
the older worker still fails its captured version checks. Polls overwrite a single pending
tuple. When work finishes, `updateManual` consumes that tuple and performs another color
lookup, so coalescing does not suppress configuration refresh indefinitely.

Cue changes are independently compared before/after `AttentionState.update`. New occurrences,
resumption, producer replacement, or removals change the cue dictionary or retire the run.
`AttentionState.sameActor` includes provider, producer generation, TTY, and device
(`attention-state.swift:35-79`). A producer change with unchanged surface PID therefore cannot
be silently coalesced if the coverage reports it. Missing coverage retains the cue intentionally;
`automaticSourcesCurrent` validates its exact producer generation/device and current captured
binding before preparation and inside each write's repeated currentness checks
(`focus-controller.swift:322-330,385-395,454-474`; `terminal-visual-state.swift:176-210`).

The heartbeat is taken after the color lookup (`focus-controller.swift:374-400`). Currentness
requires both that prepared heartbeat and the latest successful run catalogue to be at most six
seconds old (`488-492`). This allows long preparation with healthy identical polls while
rejecting preparation that finishes after catalogue coverage has expired. The original run and
lease identity guards remain present. Healthy lease IDs are reused only with the same owner,
non-retiring lease, and heartbeat gap at most six seconds; expiry and color changes still retire
ownership (`362-368,495-528`).

Catalogue failure increments the version and clears pending/latest catalogues. Focus Off,
mode replacement, and recovery remove the run or mark its leases retiring. A restrictions-file
replacement is independently rejected in the managed writer. Physical target/process/device
validation occurs again under the output lock before the focus request is admitted
(`visual-recovery.swift:211-214,273-290`; `ProcessRunner.swift:193-209`). Coalescing does not
weaken these guards. This is an inspection of the guarded paths; it does not establish native
visual timing or claim atomicity between arbitrary state changes and the final device syscall.

Two narrowly useful test improvements remain in the inspected test snapshot:

1. The slow unchanged-poll helper advances only four seconds (`focus-controller-tests.swift:
   742-750`). Extend it beyond the original catalogue's six-second lifetime, such as four
   two-second polls. Otherwise success does not prove that fresh identical polls, rather than
   the still-fresh original timestamp, authorize the old preparation.
2. Isolate a same-count binding change while colors are blocked, for example changing one
   outside row's `mappingIssue`, then holding the replacement lookup. Assert that the old
   preparation cannot publish or paint. The existing blocked catalogue-failure test invalidates
   through `catalogueUnavailable`, so it cannot catch a missing binding comparison. A directly
   changed emphasized set would exercise the parallel set comparison.

The parent added `testNewAutomaticCueStillInvalidatesBlockedPreparationOnIdenticalSurfaces`
during this check. Its blocked second lookup separates old preparation from the replacement,
addressing the cue-only invalidation gap. Existing tests inspect healthy IDs, color changes,
producer exit, final cue checks, Focus Off, and catalogue failure; they were read but not run.

The row comparison is order-sensitive. A reordered native catalogue conservatively invalidates
work even if all per-ID render inputs match. That is safe for painting; the scope does not prove
whether Ghostty supplies stable ordering during ordinary polling. Native acceptance still needs
dedicated surfaces, visible readability, configuration changes, and recovery behavior.

## Parent disposition: 2026-10-14 11:17 CEST

The source conclusions match the current guarded paths. The two test suggestions were
accepted: identical polls now span eight virtual seconds, and a same-count foreground PID
change invalidates held preparation. A new cue on otherwise identical surfaces has its own
negative case. The second lookup is blocked to prevent it masking loss of the initial effect.
YgOuTa passed 53 controller tests; 9EJ6KJ passed all 570 Swift tests in 11.760 seconds.
Release T163Yn passed in 26.05 seconds. Code/tests/API/bug/roadmap are committed in `0c8ca92`.
The review ran no tests and establishes no native acceptance. Native ordering/readability,
Linux runtime and the separate intermittent initial-paint error remain unresolved.
