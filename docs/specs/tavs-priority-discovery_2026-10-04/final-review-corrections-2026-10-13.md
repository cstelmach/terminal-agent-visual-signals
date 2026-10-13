# Final review leads and verified corrections

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.4
Original review target: `5bd0bd2`, implementation base `e113fb8`.
First corrected product target: `71e0f60`.
Current product checkpoint: `47fdf9b`.

## Review execution status

Neither original provider invocation produced an accepted final review. Codex's native call
exited zero and returned four concrete leads, but omitted the required scores, phase coverage
and verdict. Claude's Hub stage exhausted 1800 seconds with SessionStartTimeout; its automatic
fallback failed report validation. No scores or readiness verdict are inferred from either.

- [Codex failure](final-codex-failure-2026-10-13.md) and
  [imported raw leads](final-codex-raw-2026-10-13.md).
- [Claude failure](final-claude-failure-2026-10-13.md), including retained diagnostic paths.
- [AGY unavailable](final-agy-unavailable-2026-10-13.md): the installed fingerprint requirement
  still conflicts with the user's instructions. No provider dispatch or fingerprint occurred.

Fresh Codex file-mode and explicit Claude CLI wrapper reviews completed for `71e0f60`.
Both cover all nine phases and 83 product/test paths, with adjacent dependencies. Codex returned
CONCERN, 7/10; Claude's four passes and native synopsis returned CONCERN, 5.9/10. They ran no
tests or native acceptance. Later corrections are outside their reviewed target. This document
records parent verification and corrections; it does not substitute a provider verdict.

## Findings adjudicated against source and execution

1. **Queued full render (`4940466`).** An owned-PTY open barrier reproduced stale output after
   recovery and resume. Pin the marker before open and compare under output serialization;
   fresh hooks remain allowed.
2. **Delayed tool-error restore (`9f660ef`).** A real adapter/core PTY test reproduced legacy
   `processing` after a newer Stop. Check retained delivery before launching the synthetic trigger.
3. **Idle notification handoff (`95a391f`).** A real Stop-to-idle test reproduced a delivery
   mismatch and absent graduated color. Restart with current context at the first idle stage.
4. **Exited-producer timeout reset (`71e0f60`).** Entry/owned-PTY tests reproduced code 3, no reset
   and retained idle intent despite a live shell. Use its validated cached binding and unchanged
   observation/latest bound intent.

The cleanup fix checks current intent identity before both live and orphaned publication paths,
then repeats validation after device open. It rejects missing bound orphan intent, newer delivery,
new standalone intent and owner reuse. Forced resets also pin the recovery revision, preventing
late palette or directory-title output after suspension changes. The original 100 ms writer
budget covers these checks; no helper verb, title guessing or native catalogue access was added.

An independent [focused source check](forced-reset-followup-2026-10-13.md) found a race in the
first cleanup draft: live publication could overwrite a newer standalone intent and become its
own bound evidence after producer exit during open. `TtcCjQ` reproduced three assertions.
The common unchanged-intent guard fixes it before the first mutation. A further green regression
checks standalone intent arriving during open. This source check found no further concrete
bypass within the one-delivery-per-intake contract; it ran no builds, tests or device operations.

## Verification and retained failures

All runs use `tests/run-isolated.sh`, explicit source-built helpers, private roots and owned PTYs.
Log IDs below belong to
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.ID/command.log`.

| Check | Result | Log ID |
|---|---|---|
| Queued-render initial regression | Four assertions failed before correction | `DgsRi0` |
| Tool-error-to-Stop regression | Failed with unexpected processing | `8urFZB` |
| Stop-to-idle handoff regression | Failed with retained completion delivery | `9PIOVW` |
| Exited-producer reset regression | Code 3, missing bytes and unchanged color | `iwLJPF` |
| Live-to-orphan standalone-intent race | Three assertions failed before common guard | `TtcCjQ` |
| Final full Swift suite | 497/497, 8.040 seconds, no warnings | `L6yRjc` |
| Final product release build | Passed in 11.86 seconds | `c7aA6M` |
| Broad isolated Bats audit | 165/165 before final common-intent guard | `uaFGiJ` |
| Audited Python modules | 230/230, 10.02 seconds | `6bEfyY` |
| Final release-helper connected Bats | 50/50 after common-intent guard | `CKXAQ5` |

Fixture failures are retained separately: immutable-context assignment (`HT7w0o`), stale simulated
ancestry (`6voVmp`), future virtual timestamp (`eJFKcV`) and throwing code in a nonthrowing open
seam (`5aJZRM`). Corrected fixtures precede passing runs. They are not product regressions.
The default Python lacked pytest (`xXZPzS`); the installed `pytest` command passed without any
dependency installation. The final during-open case was added after the guard and is a green
check, not claimed initial red evidence. Scratch/backups: `/tmp/tavs-final-review-fixes-20261013/`.

## Remaining work

Read and verify fresh provider reports before acting on findings. Active-cue UI, relaunch UI,
and the required physical/native cases in Phases 2/7/8/9 remain incomplete. Ghostty access was
denied; no alternate native automation, device painting, installation, sync, personal preference
or schedule change, or shutdown of a user session occurred. The earlier owned fixture remains
running; its relaunch Computer Use attachment timed out. No repeated unchanged retry occurred.

The SPEC body and PLAN are fixed. Phase 9 remains In Progress; the master goal remains active.

## Completed reviews and the next correction

- [Complete Codex review](final-codex-corrected-review-2026-10-13.md).
- [Complete Claude synopsis](final-claude-corrected-review-2026-10-13.md), with accepted
  [A](final-claude-part-a-2026-10-13.md), [B](final-claude-part-b-2026-10-13.md),
  [C](final-claude-part-c-2026-10-13.md) and [D](final-claude-part-d-2026-10-13.md).

Codex R1 is resolved by `689203e`. A successful empty catalogue is confirmed closure, while
actual native errors retain last-known state. `CWtVBe` reproduced nine failed assertions in
the model suite, including retained priority/selection, Manual membership and Automatic cues.
The accepted path now clears closed rows, stored priorities, selection and previews; ends Manual
after its last member closes; and clears closed cues while Automatic stays armed. The connected
empty activation guard separately failed in `Ewz7tl` before correction.

Final `ukRCyM` passed 500 Swift tests in 8.011 seconds with no warnings. Current release `tfCNTK`
passed in 10.69 seconds. These isolated tests use nil device/lifetime lookup and a mock writer;
they cannot open a real device. Failed-native retention remains tested separately.
Backups: `/tmp/tavs-empty-catalogue-20261013/`.

## Priority-suite repair (Codex R2 / Claude M7)

Resolved the source-verified fixture finding in `tests/integration/priority-pinning.bats`.
The child inherits the explicit source helper and all private roots; a separate PTY-child check
verifies those values. Owned PTYs replace regular-file devices, and both per-TTY targets remain
live together before either can release its device. The policy uses supported `quiet_period`.
Assertions cover current typed intent, distinct deliveries, pause precedence, repeated replacement
and fresh background output after resumption without historical title/bell replay or OSC caches.
No production behavior, API, installed app or personal setting was changed.

After isolation repair, legacy `TKNLLK` failed its three removed-cache assertions. That run also
rejected regular-file targets; it is obsolete-test evidence, not a new product regression.
The first owned-PTY drafts failed two assertions because legitimate OSC BEL terminators were
mistaken for audible bells (`CZFUqp`, `pKXRWf`, `DLscOe`). Retained byte captures identified the
error. The final checks remove complete OSC sequences before testing for standalone bells.
Focused `yuM9HW` passed 4/4; connected `1jV0wk` passed 169/169 Bats; full `E8VXVU` passed 500/500
Swift tests in 7.940 seconds without warnings. The existing current release helper was used;
no product rebuild was needed for this test-only change. Backups: `/tmp/tavs-priority-tests-20261013/`.

## Unknown-cue correction (Claude M1)

Resolved in `02708b8`. Nil/unsupported coverage preserves cue history. Three-way source
validation uses the exact native surface and optional captured binding; unavailable data rejects
new paint and retains its cue, while proven lifetime loss resolves only captured occurrences.
Independent device/owner/application invalidation is not masked by an unknown producer. The worker
checks sources even with no outside targets, and final callbacks use the original writer deadline.
Already proven exits still resolve when a later inspection exceeds the common budget.

The post-save `didRenew` callback distinguishes real metadata renewal from rejected/unaffected
requests. Global masks renew ownership without painting; rejected predicates cannot refresh it.
After expiry, restored inspection uses a fresh effect ID and the original cue. Missing renewal
also displays unavailable state rather than a successful emphasis label.

Initial `eADpHC` reproduced 11 assertions across the reducer and controller. The first fixture
draft `qcCzhn` failed compilation on immutable coverage and PID types; it is retained separately.
The [source check](unknown-cue-correction-followup-2026-10-13.md) verified the primary change and
found positive invalidation masked by unknown metadata plus lost partial results on timeout.
`x40p68` reproduced the first edge. Exact native-instance validation and collecting independent
evidence fix it; a dictionary-order-independent timeout regression covers the second. `VgzSe6`
reproduced three misleading status assertions before the unavailable-state correction.

Final `EhjKGL` passed 507/507 Swift tests in 8.671 seconds without warnings. Current release
`Zl3ABu` passed in 11.45 seconds; current-helper `LWPlNE` passed 169/169 isolated Bats. New checks
cover completion/permission gaps, all-High exit resolution, mixed valid/unknown/exited cues,
prolonged rejected writes, masked renewal, partial deadlines and restored inspection. Heartbeat
and masked-renewal cases were added after the initial implementation and passed on first execution;
they are regression coverage, not claimed initial red evidence. Backups: /tmp/tavs-unknown-cues-20261013/.
No native or visible acceptance is inferred from these source/owned-PTY checks.

## Delayed synthetic restore correction (Claude M2)

Resolved in `47fdf9b`. A real-helper barrier pauses after successful context validation, then
delivers a newer Stop or SubagentStart before releasing the restore. `WuVtc2` reproduced changed
Stop state and a subagent count of 1 becoming 2. Synthetic processing/subagent handlers now skip
timer cancellation, session-state writes, count increments and new-prompt identity work. Normal
hooks preserve their prior branches, while final managed validation still controls all output.

The [focused source report](synthetic-restore-followup-2026-10-13.md) found no source defect in
those guards, but identified test limits. The corrected fixture records exact helper results:
3 for stale restoration, 0 for successful current stages. It also observes later graduated
background bytes and the same timer PID, rather than relying on PID existence alone. A positive
case verifies current subagent restoration paints without another spawn or meaningful state write.
The helper-return marker is intentionally not claimed as a whole-trigger exit handshake; the
named state/timer/count mutations all precede that marker in the inspected source.

Final `knbxNp` passed 172/172 isolated Bats across the 15 audited files. Focused `OiEX9s` passed
the three corrected cases; `3T8M2E` passed 507/507 Swift tests in 8.379 seconds without warnings.
Shell syntax and whitespace passed. The current release helper is unchanged; no Swift source
needed rebuilding. Earlier fixture runs `aZZ9pp` and `t5Iyfs` are retained but are not the final
two-case red evidence. The first patch attempt was rejected before any edit due to a missing
diff prefix. Backups: /tmp/tavs-synthetic-restore-20261013/. Native/UI acceptance remains open.

## Remaining adjudication and implementation

The following source findings are verified; execution regressions and fixes remain pending:

1. **Cleanup growth (Claude M4).** The [source follow-up](focus-cleanup-bound-followup-2026-10-13.md)
   proves a finite 24-second sequence with three retired runs and 15 retry jobs. These share one
   revision object, not one descriptor per rollover. Blind replacement by the newest attempted
   ID can lose older ownership. Preserve exact IDs/pins, and verify any bound against partial
   healthy focus and physical restoration rather than accepting a weaker product behavior.

Other Claude findings still require parent source/spec verification before fixes or dismissal.
Prioritize recovery classification, wedged-worker growth
and post-recovery scheduler recomposition. Do not suppress an unbound native-row failure based
only on its TTY string: nil capture cannot establish current physical/native identity.

Helper-required compatibility must be reconciled with the original supported scope and direct
ordinary-signaling requirement before proposing a product decision. Do not revise the SPEC to
make current tests easier to satisfy or introduce an unsafe raw fallback. Maintainability,
performance, UI and other lower-ranked recommendations remain visible in the complete report;
they are not accepted defects merely because the provider assigned them a rank.

## Current UI evidence

PID 68022 remained the same running private Automatic Acceptance process. Computer Use timed
out through both its path and registered bundle ID. Enabled-app inventory confirmed its ID.
A one-second sample observed the normal AppKit event loop, not a demonstrated deadlock; it does
not prove visible UI or responsiveness. The documented native launch capability is absent on
this Mac provider. No activation workaround or process restart occurred. The sample remains at
`/tmp/tavs-ui-observation-20261013/sample-68022.txt`. Native Ghostty access remains denied.

The source freeze was released after confirming that remaining provider inputs were immutable
`71e0f60` packets. Every completed review stays labeled with that target; `689203e` is a separately
verified correction. The goal remains active with source defects and required acceptance open.
