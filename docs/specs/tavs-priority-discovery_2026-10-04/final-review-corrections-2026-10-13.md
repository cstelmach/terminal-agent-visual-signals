# Final review leads and verified corrections

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.16
Original review target: `5bd0bd2`, implementation base `e113fb8`.
First corrected product target: `71e0f60`.
Current product checkpoint: `927a746`.

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

## Recovery classification correction (Claude M3)

Resolved the registry defects in `5696f4c`. Registry-only hints become vanished only when current
device inspection is nil and positive node-loss evidence confirms absence. Unknown, live and
contradictory metadata remain failed and never authorize output. Malformed/unreadable entries
have individual failures; only directory inspection failure describes the whole registry.
Arbitrary filenames are excluded from serialized diagnostics. Native nil-capture failure remains
visible beside a cached restoration; suppressing it by a bare TTY string was rejected against
the SPEC's explicit unknown-binding failure contract. Its matching hint no longer duplicates it.

Initial `7Ws1xF` reproduced six assertions. The [source follow-up](recovery-classification-followup-2026-10-13.md)
found another reporting gap: a vanished cached owner hid a live unverified hint. `fR9LLc` reproduced
two assertions. The corrected status-sensitive deduplication retains the live hint's failure;
device-loss proof suppresses a redundant closed hint. A sixth case verifies a live owned PTY with
contradictory missing metadata stays failed and receives no output.

Final `0ctU5T` passed 513/513 Swift tests in 8.546 seconds without warnings. Current release
`uPGEcV` passed in 12.41 seconds; current-helper `nitpAv` passed 172/172 isolated Bats. The first
draft's 511-test run and 18.29-second release are intermediate evidence only. All state is private;
tests use owned PTYs or injected metadata, with no native app calls. No shell source changed.
The Bats total was placed in the product commit message before its final tool result returned;
the same confirmed live handle then completed successfully. Swift functionality/release were
already verified before commit. This sequencing error is retained rather than described as a
fully completed shell audit at commit time. Backups: /tmp/tavs-recovery-classification-20261013/.

## Repeated native I/O correction (Claude M4, partial)

`ca27873` bounds native I/O admission per validated physical terminal lifetime across runners.
Admission follows available metadata publication and lasts through actual worker cleanup rather
than caller timeout. Native aliases share ownership; different validated continuing-owner
generations do not. Raw/unresolved calls conservatively share normalized path admission.
Only `.emergencyReset` has a separate reserved slot, so ordinary blocked opens cannot exclude
same-process recovery. Both lanes retain the existing output lock and original 100 ms deadline.

The [design check](device-admission-design-followup-2026-10-13.md) explains placement and the
global-cap tradeoff. The [implementation check](device-admission-check-followup-2026-10-13.md)
found test teardown before actual permit release and raw syntactic alias amplification. Its
initial inspection predates the recovery lane and final test repairs; follow-up scope is explicit.
The root verified each issue, added path normalization, exact-slot cleanup probes and late-byte
assertions, and made the busy intent test assert metadata retention without concurrent output.
No direct mock delegation is claimed as proof of physical lifetime precision.

Initial full `ZbTOkp` failed 14 assertions after admission also blocked recovery. Final `uWrBWe`
passed 519/519 Swift tests in 9.179 seconds without warnings. Release `fakLJK` built in 13.54
seconds, and current-helper `KqB4Iq` passed 172/172 isolated Bats. All completed before commit.
The guard bounds repeated native operations for one lifetime. Arbitrary metadata callbacks,
unlimited distinct/reused lifetimes and cross-process workers have no new global bound.
Retained focus cleanup, the other part of M4, is unresolved; no global thread-cap claim is made.

The last three code slices and their staged records added 61 net production lines and 1,125 net
process-document lines before this note (18.4:1). Source checks produced the live registry-hint
fix, raw-path admission correction and worker-cleanup test repair. This is useful defect evidence,
but documentation growth is high. Keep subsequent reports/progress concise; add no process layer.

## Independent preview cleanup (Claude M4, partial)

`eeed5cb` separates focus-retirement batches from preview cleanup without changing the shared
per-TTY writer. Red `Q72Rts` proves a held unrelated focus cleanup delayed healthy preview clear.
Final `HBwtxF` passed 520/520 Swift tests in 11.032 seconds; release `KcJkJV` built in 15.83
seconds; current-helper `kzSZFO` passed 172/172 isolated Bats. All completed before commit.
The [source design](focus-cleanup-design-followup-2026-10-13.md) proposes per-target leases and
retirement gating, preserving healthy renewals. Retention remains unresolved. Root confirmed
the post-rename deadline check and no-paint clear paths: absent callbacks and canceled metadata
do not establish physical restoration. The next change needs focused cancellation evidence,
retained repaint responsibility and tests for unknown writes, not blind pruning of retired IDs.

## Focus cancellation evidence (Claude M4 prerequisite)

`372e1f0` adds a focused defaulted acknowledgement after complete validated alias cancellation
under the existing TTY lock and original deadline. It reports metadata resolution, not repaint.
The [source check](focus-cancellation-evidence-followup-2026-10-13.md) found no contract objection.
Consumers must invalidate old renewal predicates first; absent IDs receive no tombstone.
Partial writes and post-rename deadline errors before acknowledgement remain unknown and retryable.
Later device failures or suppressed paint do not undo the acknowledged metadata fact.
Final `28SNKq` passed 526/526 Swift tests in 9.340 seconds; release `lhIshL` built in 12.93
seconds; current-helper `tehdJQ` passed 172/172 isolated Bats. All completed before commit.
Controller retention is still unimplemented. Use this narrow evidence in the per-target bound,
and retain outstanding physical responsibility through failures, masking and recovery revisions.

## Per-target retirement correction (Claude M4)

`dc2671c` replaces catalogue-wide rollover with one lease per physical target and one coalesced
clear per lease. Twelve two-second refreshes with a failed peer preserve the healthy ID/heartbeat;
six explicit mode changes cannot replace unresolved ownership. Cancellation and repaint work
remain separate, with transfer only to an explicit current request. This fixes the reproduced
growth without pruning uncertain IDs or changing the captured working set.

The [source check and follow-up](focus-lease-check-2026-10-13.md) verified the narrow lease bound,
revision retention and balanced clear joins. Its ended-global-rule finding reproduced in `kUhdWq`;
requested focus restoration now emits only background bytes, while ordinary reconciliation still
resets legacy colors. Factory regressions preserve alias and cross-lifetime TTY conflict rejection.
The proposed additional race/debt cases in that report are coverage suggestions, not observed bugs.

Red `z38y9h` reproduced healthy rollover and timeout. Draft timing failures exposed clear ordering
and unnecessary completion retries; the shared join and wanted/blocked retry checks corrected them.
Intermittent `HO4JDM` is retained; corrected `5ksHzD` passed 124 focused tests. Final `yuaDn0` passed
534/534 Swift tests in 10.024 seconds without warnings; release `B0b4DB` built in 17.61 seconds;
current-helper `BTL5Xg` passed 172/172 isolated Bats tests. All returned before commit.
The change bounds retained controller leases, not every distinct native lifetime or global worker.

## Recovery-stable reconciliation (Claude L4 / Pass C L1)

`15fb863` fixes the source-verified emergency-recovery contract breach in shared reconciliation,
covering scheduler calls, delayed native work and startup cleanup. Disabled reconciliation emits
nothing for canceled ownership or retained ordinary intent alone. Active global residue resets
defaults; focus/stale preview residue resets only background. Current suspended previews preserve
composition, expiry and current-intent clearing. Normal active release and fresh hooks still work.

The [source investigation and draft follow-up](recovery-scheduler-check-2026-10-13.md) found two
additional draft errors: unavailable marker contents could preserve an inode-matching preview,
and startup selective clearing reset a current suspended preview to defaults. Parent regressions
reproduced both in `vEcOjq`/`NOFptk` before correcting the preview exemption. This report describes
the baseline and first draft, not a final provider readiness verdict for `15fb863`.
Canceled metadata is not a physical-success receipt. A failed emergency reset remains reported
and explicitly retryable through recovery; generic disabled reconciliation does not certify it.

Corrected red `oO97Qq` reproduced 12 assertions; `PZHEA5` used an older preview fixture first.
Draft `PY19Ka` exposed stale emergency-terminator and no-effect output expectations, corrected to
the existing reset sequence and preservation of unowned backgrounds. Final `B7MIEA` passed
543/543 Swift tests in 10.556 seconds without warnings. Release `uoUGOC` built in 17.66 seconds;
current-helper `Mv6nxc` passed 172/172 isolated Bats. All returned before commit, using private
roots and owned PTYs. Nine new tests cover the contract; native visual acceptance remains open.

## Scheduler failure reporting and bounded retry (Claude M6)

`86d7fe3` consumes delivery results on the main queue, exposes earlier failures/native coverage
in the menu and logs counts only. Unresolved exact targets survive registration and no-output
results. The existing heartbeat retries only failed restriction targets while muted, using
targeted fanout and current writer policy. Repeated busy retries coalesce without native queries.

The [source investigation and follow-up](scheduler-failures-check-2026-10-13.md) confirmed M6 and
the bounded repair. Its historical-wording finding is corrected: independent recovery or fresh
hooks can repair a target without acknowledging the menu process's older failed delivery.
Whole-catalogue release retries would reset healthy palettes; even a failed target may receive
a new hook before retry. Release/suspended cleanup therefore retains explicit Restore Visibility.
This satisfies reporting and retryability without adopting unsafe automatic reset suggestions.

`fIfs0V` exposed the new API; stub red `CL8Vb2` reproduced absent publication/retry. Its initial
filter excluded SchedulerLifecycleTests, corrected in subsequent checks. `7nT31J` passed 54 focused
tests. Final `OrlRQX` passed 548/548 Swift in 12.212 seconds without warnings; release `qwEuRv`
built in 47.49 seconds; current-helper `8dNSYB` passed 172/172 isolated Bats. All returned before
commit with private roots and owned PTYs. Five new tests cover main publication, targeted paint,
failure retention, coalescing/suspension, unknown bindings and scheduler gating. Menu rendering
and physical Ghostty acceptance remain unverified. Scratch: /tmp/tavs-delivery-retry-_t_d8pfv/.

## Confirmed standalone compatibility gap (Claude H1)

The [source investigation](helper-compatibility-check-2026-10-13.md) confirms ordinary output
and legacy metadata regressions when the installed helper is absent, old or unavailable on Linux.
The organizer's macOS/Ghostty scope does not withdraw existing standalone plugin compatibility.
No portable bounded writer/parser exists in current production. A safe transport needs packaging
or runtime approval beyond PLAN's no-extra-binary/no-new-dependency boundary. The creator question
is pending; no answer, scope amendment or unsafe renderer bypass has been inferred.

`4b6abf6` addresses the independent misleading sync-readiness message. Source copying remains
successful while missing managed-render or organizer-metadata capability is reported separately.
The probes reuse existing validation branches, omit isolated launch keys and never echo their
output. Neutral wording applies on nonmac hosts too. The follow-up source finding about a Mac-only
rebuild hint was already corrected before receipt. This diagnostic does not resolve H1.

Red `0epna4` reproduced three assertions. Final `DIM1gt` passed 548 Swift tests in 9.892 seconds
without warnings; `5eFk7R` passed 175 isolated Bats and final focused `DQcM7q` passed 10/10.
Bash syntax passed. Followed ShellCheck retains only pre-existing SC2012 at the unchanged cache
enumeration; its initial dynamic-source warning was resolved by the source directive. Swift
source/helper is unchanged and was not rebuilt. All terminal results preceded commit, with
private roots and fixture plugin installations. No real install/sync, app or native operation ran.

## Measured helper launches (Claude M5, partial)

The [source investigation and measurements](helper-cost-check-2026-10-13.md) confirm six helper
launches per normal hook and three per active shell start. Three owned-PTY baseline samples gave
medians 194.317 ms and 44.602 ms. Draft samples gave five/three calls and 187.517/46.913 ms;
the samples do not establish general latency improvement. Shell cost descriptions now reflect
helper calls rather than an unsupported submillisecond/zero-fork promise.

`aa85072` transfers only the existing positive organizer cache after successful intake. Core
checks selected path, executable presence and the existing intake/context hint, then unexports it.
Incoming adapter cache is cleared; original script exec, argv disposal and managed validation stay.
This is a capability hint, not authenticated environment or executable replacement protection.
Three new cases cover one probe, fixed argv/empty stdin, parent/worker privacy and rejected cache.
The fresh-Bash/source candidate failed timer PID liveness in `AuuWTa`/`bwQdro` and was removed.

`295f107` makes test cleanup retry timed-out no-output probes within its existing one-second
window; production device calls retain 100 ms. `l1OpGN` retained one bounded-record-read failure;
`SmKc4f` retained two cleanup timeouts. Final `0ribbd` passed 548/548 Swift in 10.300 seconds.
`lJxcb9` retained three shell failures. The [verification source check](cost-verification-check-2026-10-13.md)
identified a failed permission render and insufficient diagnostics for the other two cases;
it did not prove pressure or a cache regression. Targeted `u0AVQq` passed 3/3, and final
`AVKcmZ` passed 178/178 Bats with fixtures retained. Syntax and helper/adapter ShellCheck passed.
No Swift source/helper rebuild, real app/native operation or personal installation/state change ran.
Cached-record scaling and preview configuration cost remain separate M5 work.

## Remaining adjudication and implementation

Other Claude findings still require parent source/spec verification before fixes or dismissal.
H1 transport work awaits the creator choice. Next M5 work is preview configuration cost and
retained history within one TTY.
Do not suppress an unbound
native-row failure based
only on its TTY string: nil capture cannot establish current physical/native identity.

Helper-required compatibility must be reconciled with the original supported scope and direct
ordinary-signaling requirement before proposing a product decision. Do not revise the SPEC to
make current tests easier to satisfy or introduce an unsafe raw fallback. Maintainability,
performance, UI and other lower-ranked recommendations remain visible in the complete report;
they are not accepted defects merely because the provider assigned them a rank.

## Pre-crash UI evidence

PID 68022 remained the same running private Automatic Acceptance process. Computer Use timed
out through both its path and registered bundle ID. Enabled-app inventory confirmed its ID.
A one-second sample observed the normal AppKit event loop, not a demonstrated deadlock; it does
not prove visible UI or responsiveness. The documented native launch capability is absent on
this Mac provider. No activation workaround or process restart occurred. The sample remains at
`/tmp/tavs-ui-observation-20261013/sample-68022.txt`. Native Ghostty access remains denied.
These process IDs and staged paths describe the earlier snapshot; the crash invalidated them.
The lease correction used owned PTYs and private roots without app or native control.

The source freeze was released after confirming that remaining provider inputs were immutable
`71e0f60` packets. Every completed review stays labeled with that target; `689203e` is a separately
verified correction. The goal remains active with source defects and required acceptance open.

## Per-TTY cached lookup (Claude M5, partial)

`70e5e74` uses the existing TTY cache partition for ordinary and orphaned-producer resolution.
All same-TTY owner generations, native/plain aliases and effect-only bindings remain candidates.
Full recovery/relaunch retains global enumeration and unreadable records. No history is retired.
A Foundation probe exposed a pre-existing scanner defect: calling `skipDescendants()` on a link
pruned the next actual directory. Keeping link rejection without that call preserves valid peers.
Three new snapshots and two extended ambiguity checks cover the correction. `NJBAjY` was API red;
`Q521S1` additionally exposed fixture URL spelling and missing peers; `vGkCtp` retained the latter.
Final `1cYi6l` passed 9/9 focused; `i9FV5n` passed 551/551 Swift in 10.631 seconds. Release
`OGadCV` passed in 19.97 seconds; current-helper `jP9fYJ` passed 178/178 isolated Bats. No warnings.
The [source review](tty-cache-scope-check-2026-10-13.md) found no introduced defect, with explicit
pre-existing policy/enumeration limits. The initial investigation's requirement to skip link
descendants was corrected by the probe. No latency or native acceptance claim follows these checks.
Next: preview configuration cost and retained history within one TTY; H1 input remains pending.

## Preview preparation lifetime (Claude M5/L6, partial)

`a710d9f` fixes the proven duration defect while retaining one fresh validated query per selection.
One display-start anchor, established after successful preparation, feeds the effect heartbeat,
paint-age predicate and remaining-delay timer. Preparing selections remain immediately cancellable.
Failure reports explicit unavailable state without active preview. No cross-preview cache is added.
The [investigation and follow-up](preview-timing-source-check-2026-10-13.md) retain source-only limits.
A draft gap allowed an accepted start to expire before timer enqueue. `CDAsJf` reproduced missing
cleanup; accepted starts now queue expiry before the paint-age guard, including zero remaining time.
The clock counter is synchronized and the cancellation fixture drains queued main callbacks.
Five new tests cover the timing paths. Final `1SEz4e`: 556/556 Swift, 10.803 s; release `o2l0ps`:
22.08 s; current-helper `ydknN9`: 178/178 isolated Bats. No deadline or parser validation was relaxed.
`RoXBKk` retained old-timer and unrelated managed-reset output failures after earlier full passes.
Their cause is unproven; targeted diagnostic `4vjXjB` passed both, followed by the final full pass.
Preview query cost is not reduced or measured. Existing long-lived focus colors and effective-config
invalidation require separate verification. Native duration/contrast acceptance remains incomplete.

## Replacement preview cleanup ordering

`a5c6549` adds optional bounded waits and per-physical completion; `927a746` uses them for previews.
`KMqaUW` reproduced EBUSY against finite prior cleanup, no replacement paint and an unchanged ID.
The original `RoXBKk` cause remains unproven. A serial-batch draft then blocked B behind A;
`ZTqHdl` reproduced five failures after fixing the fixture's physical/native storage-path mistake
(`ZEIU1L`/`oLoWRh`). Cleanup batches now progress concurrently while each target retains its predecessor.
`KelinG` reproduced a timeout successor dropping that older dependency. Completion notification now
requires both its own result and predecessor completion; bounded failure reporting still returns.
Waits occur before admission under the original 100 ms budget, outside controller/record locks.
Exact-ID cancellation, alias/conflicting-owner checks, current-run predicates and emergency recovery
are preserved. No generic busy retry, admission change, new schema or persistent state is introduced.
Five new tests include cancellation, alias/failed callbacks, timeout retention and a fresh post-drain
preview. `a54Lpn`: 142/142 focused; `40ORys`: 561/561 Swift, 11.028 seconds; release `aqws2z`:
14.02 seconds; current-helper `7WAkIc`: 178/178 isolated Bats. No warnings or deadline relaxation.
The [full source checks](preview-timing-source-check-2026-10-13.md) retain superseded draft findings.
Separate managed-reset failures, focus-color freshness, H1 and physical/native acceptance remain open.
