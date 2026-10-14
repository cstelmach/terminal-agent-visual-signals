# Final review leads and verified corrections

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.17
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

## Current follow-up reviews: 2026-10-14

Current reviewed source: `7ecfba2`. [Codex](current-codex-review-2026-10-14.md) completed three
passes; [Claude](current-claude-review-2026-10-14.md) completed eight subcalls but its final
installation/CLI-recovery call exited 1 with empty diagnostics. Coverage is explicitly partial.
AGY's developer-level fingerprint precondition remains incompatible; no provider call occurred.

`d26a4b4` resolves Codex scheduler R1 after an owned startup trap reproduced it. Candidate load
validation protects all production evaluator callers. Startup, watcher/valid replacement and
continuing manual-lock cases pass; all 573 Swift tests and serial release build pass. Default
release first failed for disk space; no cleanup was performed. Main was unchanged during reviews;
the isolated branch was integrated by fast-forward afterward.

Parent checks support missing fresh native mapping, delete-before-copy replacement, post-recovery
painted-lease bookkeeping and partial-mapping status issues. The missing Go To model tests claim
is disproved by deferred navigation tests in focus-controller-tests. Selection pruning restarting
preview has no established SPEC violation: each selection change restarts preview. Per-poll work
is real but material cost is unmeasured; mtime-only caching risks stale included-theme/config data.

Linux ordinary compatibility remains a real implementation gap. Context permits broader providers
while native and portable observations accept only Claude/Codex, blocking synthetic updates.
Raw printf fallback, README scope withdrawal, arbitrary stale-revision lease removal, deletion/
quarantine and broad refactors are not accepted remedies. Verify per-target restoration outcomes
and retain failures. Remaining claims need parent checks and discriminating tests before fixes.
Repair lock-gate's env-i fixture before any run; do not use workstation defaults.

Physical native acceptance, Linux kernel checks and historical initial-paint/EPERM/fresh-render
attribution remain open. Passing tests and completed review workflow are not product approval.

## GUI recovery cohort correction: 2026-10-14

Claude R2 is confirmed for the GUI. The remedy now captures the canceled lease objects and uses
bound restored/vanished outcomes only when state persistence succeeded. Conflicting or absent
results retain obligations. SessionsModel applies the callback on main before reporting recovery
completion. No renderer, marker, device deadline, schema or cross-process receipt was changed.

`KDzUuy` reproduced eight assertions in three initial cases. HCrV4K passed 3/3.
Seven final regressions cover actual partial open failure, failed-only retry, uncertain reports,
owner reuse, late confirmation, fresh post-recovery ordinary output and confirmed disappearance.
The focused 8ntSqD run passed 9/9, including the two old timing cases identified below. Final
L6WuHa passed 592/592 Swift in 26.732 seconds. Native/visual acceptance remains unverified.

eoVi2e retained 190 tests with five assertions, one unexpected: the existing unchanged-Manual
preparation produced no initial effect/bytes, and the existing intake-during-open fixture exceeded
its 20 ms publication deadline, then reported deviceNotWritable. The former now uses the existing
writer outcome recorder and awaits cleanup. The latter source is untouched. Passing later checks
do not attribute either failure. Independent headless recovery still lacks feedback to the live
controller's canceled leases; this narrow GUI correction does not resolve that source finding.

Full read-only source exploration and implementation check follow unchanged. Its inspected test
inventory was three cases; the parent subsequently added four further cases, all executed above.

# TAVS recovery outcomes and obsolete focus leases

Date: 2026-10-14
Scope: Read-only source exploration. No tests, live terminal operations, installations, preferences,
or repository edits were performed.

## Conclusion

Claude R2 confirms a real cleanup path: a painted FocusController lease can remain retiring after
successful recovery because its old marker revision makes `.clearFocus` return no output. The
controller correctly refuses to equate that no-output result with completed cleanup.

The suggested alternative of treating marker mismatch as recovery success is unsafe. Marker
replacement proves only that the marker identity changed. It can happen before helper discovery,
before target enumeration, or before a failed physical write. Inactive effect metadata also does
not prove physical output completed.

Keep the existing controller retirement predicate. The smallest narrow GUI fix can use successful
per-target recovery items for the canceled cohort. A fix covering independent headless recovery
must instead let obsolete leases obtain an actual cleanup result through the shared renderer, or
add an explicit per-target outcome source. The current source contains no cross-process physical
success receipt to read. Do not infer such a receipt from existing metadata.

## Current outcome contract

Source root: `/Users/cs/local/code/apps/terminal-agent-visual-signals`.

### Renderer and physical writer

- `src/macos/TAVSApp/Sources/TAVSApp/visual-recovery.swift:39-54`: item statuses are `restored`,
  `vanished`, `unaffected`, and `failed`. `hasFailures` means failed persistence or an item marked
  failed. `catalogueAvailable == false` is a separate limitation.
- `visual-recovery.swift:553-589`: fanout groups aliases by `physicalTarget`, validates the target,
  rejects conflicting live owners on one TTY, and reports one physical result. A completed managed
  write returning true maps to restored. A prepare callback returning nil maps to unaffected.
  Proven disappearance maps to vanished; errors map to failed.
- `terminal-visual-state.swift:35-43`: `physicalTarget` preserves TTY path, device number, and owner
  process generation, stripping only the native alias. Match results by this value, never by TTY
  string alone.
- `ProcessRunner.swift:159-168`: beforeOpen metadata work precedes admission and device open.
- `ProcessRunner.swift:193-210`: descriptor preparation runs under the stable writer lock.
  Returning nil skips output. Returning bytes is not itself success; writeToDescriptor must finish
  before true is returned.
- `ProcessRunner.swift:217-228`: the original 100 ms deadline covers the whole device operation.
  Timeout is failure even if earlier metadata work completed.
- `ProcessRunner.swift:239-251`: physical-target admission retains a separate emergency attempt.
  This is not a reason to loosen the deadline or target validation.

Here, restored proves writer completion under these checks. It does not prove the terminal emulator
visually rendered the bytes or that the user accepted its appearance.

### GUI Restore Visibility and Resume Visual Rules

- `sessions-model.swift:169-182`: the GUI calls cancelForRecovery before dispatching the action.
  Its logical focus state becomes Off before physical recovery begins.
- `TAVSApp.swift:221-234`: a serial recovery queue validates the root, saves the marker, prepares
  fixture scope where relevant, and delegates to recoverHeadlessly.
- `visual-recovery.swift:74-96`: recoverHeadlessly saves the marker before probing the helper.
  It checks capability support and preserves a decoded partial report when helper exit code is 1
  and report.hasFailures is true. A Swift `.success(report)` can therefore contain target failures.
- `sessions-model.swift:185-197`: finishRecovery displays status counts, the catalogue limitation,
  and a failure reason. It never passes the per-target outcomes to FocusController.
- `sessions-model.swift:174-177`: even the missing-action path saves the marker and then reports
  helper failure. Marker replacement cannot certify physical recovery.

### Headless helper

- `managed-output-entry.swift:45-55`: `--visual-recover` saves the marker first, validates isolation,
  constructs the recovery object, and applies emergencyReset or resume reconciliation.
- `managed-output-entry.swift:143-146`: a failure after persistence becomes a report with
  stateSaved true and a failed item. This can be an unbound item with no target.
- `managed-output-entry.swift:182-186`: encoded reports use exit code 1 for hasFailures, otherwise 0.
- `visual-recovery.swift:426-436`: the direct recovery method follows the same persist-first model.
  Suspension uses emergencyReset; resume uses reconcile(resetLegacy: true, clearSelective: true).
- `visual-recovery.swift:239-243`: emergencyReset cancels effect records and invalidates pending
  output before returning full reset bytes to the physical writer.
- `visual-recovery.swift:319-337`: resume can cancel selective records, then create a current global
  restriction record and return its bytes. Again the state mutation precedes physical completion.

An independent helper has no reference to the live GUI FocusController. Existing marker/effect
state prevents obsolete focus publication, but does not carry a successful physical-write result
back to its in-memory leases.

### Scheduler and broadcaster

- `Scheduler.swift:238-242`: the scheduler receives item results through Broadcaster.resultChanged
  and exposes terminalUpdateIssue, including target failure count and catalogue limitation.
- `Scheduler.swift:403-434`: suspension suppresses the projected restrictive paint. On a prior
  muted-to-unmuted transition it invokes managed clearing/reconciliation against the new policy.
- `Scheduler.swift:480-483`: clearing enqueues broadcastPausedClear and broadcast.
- `Broadcaster.swift:37-42,117-126`: those operations use the same VisualRecovery apply paths.
- `Broadcaster.swift:131-150`: failure state is keyed by physical target. Only restored or vanished
  removes a prior failure. Unaffected and registration results cannot erase a failed paint.
- `Scheduler.swift:494-498`: targeted restriction retry runs while muted and restrictions remain
  enabled. It does not automatically settle in-memory GUI focus leases after external recovery.

The broadcaster already demonstrates the honest per-target policy that focus retirement needs.

## R2 source verification

Review source:
`docs/specs/tavs-priority-discovery_2026-10-04/current-claude-native-2026-10-14.md:150-169`.

1. `focus-controller.swift:190-202`: cancelForRecovery marks all focus leases retiring and clears
   logical run state, but retains the leases. It deliberately starts no device cleanup.
2. `focus-controller.swift:308-320,579-592`: later focusOff or an existing cleanup path invokes
   clearManual and attempts clearFocusLease.
3. `focus-controller.swift:557-565`: that request carries the original lease revision. didCancel
   marks ownershipResolved; restoreBackground returns the conservative mayHavePainted flag.
4. `visual-recovery.swift:190-203`: beforeOpen cancellation resolves exact old ownership using
   effect kind, effect ID, controller generation, and original revision. This can complete before
   device failure.
5. `visual-recovery.swift:295-302`: prepare checks the original revision even when restoration is
   explicitly requested. Marker replacement makes that check false and returns nil.
6. `focus-controller.swift:566-576`: unaffected is not restored. A lease whose mayHavePainted flag
   remains true stays in focusLeases, even when ownershipResolved is true.
7. `focus-controller.swift:596-602`: the remaining retiring lease produces the cleanup error.

This confirms the conditional false-error case after actual successful recovery. It also confirms
the error is truthful after a failed target. R2's word "never" has a limit: an explicit new focus
request can transfer the remaining paint obligation to a new lease after ownership is resolved
(`focus-controller.swift:535-551`). The old retiring lease otherwise has no successful automatic
physical-result path across marker replacement.

The marker check uses inode and device (`visual-restrictions-state.swift:75-95`), not recovery
outcomes. Writes are atomic (`:136-147`), and holding the old revision descriptor prevents inode
reuse (`:71-72`). Repeated writes can change identity even when the boolean state is unchanged.

## Smallest source and test changes

### Narrow GUI fix, if that is the chosen scope

Modify FocusController and SessionsModel, with tests in focus-controller-tests.swift:

- Have cancelForRecovery identify the exact existing lease cohort for this action. Apply its
  returned report only to that cohort, keyed by physical target and existing lease object identity.
- On a report with stateSaved true, resolve only cohort leases with explicit restored or vanished
  items. Preserve failed, unaffected, absent, and unbound results. Do not use !report.hasFailures
  as a blanket success condition, because the report may cover only known targets.
- Do not overwrite a new lease created after the action. Existing pre-recovery publications remain
  fenced by the marker revision and exact cancellation rules.
- Keep original lease revisions available until metadata ownership has been resolved. A successful
  physical item is usable for physical cleanup; it does not justify relaxing old publication guards.

This fixes the GUI false error without re-emitting retained ordinary colors after successful reset.
It does not cover independently invoked headless recovery. Document that scope honestly if used.

### Shared renderer repair for all recovery entry points

The smallest useful shared repair is in performWrite's clearFocus branch, plus renderer/controller
tests. Preserve the original revision for exact metadata cancellation, but distinguish it from a
fresh current marker revision for a new cleanup transaction. Validate that cleanup revision and
the opened target under the existing writer lock and original deadline. Never renew the obsolete
focus recipe. Let clearFocusLease retire only after its actual restored/vanished result, as it
already does at :566-576. Failed output must retain the obligation for retry.

This is a new physical cleanup, not a claim that prior recovery succeeded. It reaches the GUI,
independent helper, and scheduler-triggered controller cleanup without wiring every recovery path
to the GUI.

There is a concrete compositing decision to test before implementing this option:

- While active, compose current pause/lock, current preview or focus, or latest ordinary background
  through the existing precedence rules. Do not restore the old recipe or snapshot.
- While suspended, replaying retained pre-recovery ordinary intent would violate the existing
  recovery behavior. An unconditional default reset can instead overwrite a fresh ordinary render
  that arrived after successful recovery but before delayed cleanup.
- Existing state has no affirmative physical outcome or per-recovery ordinary-render boundary
  that can simply be read to distinguish both histories. Marker mismatch and inactive records
  must not be substituted for that missing evidence.

Therefore a one-line removal of the old revision guard is not a complete repair. Either make the
cleanup's suspended compositing semantics explicit and verify them against fresh output, or use
the narrow GUI outcome fix and leave the all-entry-point cleanup gap open. No new cross-process
receipt mechanism is needed for the narrow fix, and one should not be introduced by inference.

### Discriminating cases

| Case | Required observation |
|------|----------------------|
| Painted focus, successful recover, later Focus Off | No false cleanup error; old publication remains impossible |
| Painted A and B, recover writes A but fails B | A settles; B remains pending; retry clears B once writable |
| Marker replacement only, helper absent | Painted lease remains an obligation |
| Cancellation metadata saved, physical output fails | Inactive record does not clear the lease's paint obligation |
| Independent headless successful recovery, GUI refresh | No dependence on a GUI-owned recovery callback for any claimed all-path fix |
| Same paths, failed external recovery | Logical focus becomes Off; unresolved painted target is retained honestly |
| Resume into requested pause/lock | Old focus cannot reappear; successful cleanup preserves current rule |
| Fresh suspended preview | Old focus cleanup cannot overwrite the current preview |
| Successful recovery then fresh ordinary render before delayed cleanup | Cleanup preserves fresh output and cannot replay retained pre-recovery intent |
| Reused TTY or ambiguous owner metadata | Compare complete physical binding; proven end is vanished, uncertainty is failed |

## Existing tests to extend and preserve

- `visual-recovery-tests.swift:81-94`: failed recovery changes policy and prevents revival without
  proving output or requiring old focus metadata to have been canceled.
- `visual-recovery-tests.swift:97-111`: cancellation callback and inactive focus record can exist
  before a physical device failure. This disproves metadata-only retirement.
- `visual-recovery-tests.swift:283-294`: explicit missing-record restoration currently restores
  latest intent with a matching revision, then deliberately rejects the changed revision. A shared
  repair must replace the second assertion with a policy-specific bounded-cleanup assertion.
- `visual-recovery-tests.swift:322-339`: old clear cannot cancel a newer focus ID; alias recovery
  writes once and cancels both relevant records.
- `visual-recovery-tests.swift:782-804`: headless client preserves partial report and saves marker
  before helper probe.
- `visual-recovery-tests.swift:897-912,958-970`: suspended stale effects reset defaults while a
  current suspended preview remains intact.
- `visual-recovery-tests.swift:1138-1156`: healthy fanout completes despite failed and uncertain
  targets; target metadata remains retryable.
- `visual-recovery-tests.swift:1209-1224`: resume paints the current requested rule and cancels old
  selective ownership.
- `visual-recovery-tests.swift:1729-1748`: proven old-owner end is vanished; unknown process
  metadata remains failed and does not authorize retirement.
- `focus-controller-tests.swift:1193-1205`: successful recovery ends Manual focus, but does not
  call Focus Off afterwards on the same controller or assert absence of cleanupError. Extend it.
- `focus-controller-tests.swift:1258-1275`: external marker change switches Manual Off, but merely
  waits for publication of cleanupError without asserting it is nil. Extend it with a real recovery
  and contrasting failed target.
- `focus-controller-tests.swift:1701-1725`: GUI displays partial report, but currently tests preview
  cancellation rather than settlement of painted focus leases. Add focus target outcomes.
- `BroadcasterTests.swift:183-205,222-253`: delayed suspended reconciliation cannot replay old
  intent or overwrite fresh ordinary complete render. Shared cleanup must preserve these cases.
- `BroadcasterTests.swift:429-448`: unaffected registration/retry does not erase a failed paint.

## Exploration trace and limits

Observed: searched the current recovery, controller, writer, state, GUI, scheduler and test source;
read R2 at its exact report path; compared its remedies with cancellation ordering and existing
regression cases. Tests were inspected, not executed. No claims of current runtime or visual
acceptance are made. Repository meta capture remains the parent task's responsibility because this
delegation explicitly prohibited edits.

The previous TAVS memory entry was used only to reinforce the read-only runtime boundary. All code
claims and line pointers above come from source retrieved during this exploration.

## Addendum: selected narrow GUI cohort closure

The parent selected the narrow GUI fix: cancelForRecovery returns a completion closure containing
only its canceled lease cohort; SessionsModel invokes it for a stateSaved report; only explicit
restored/vanished physical-target items settle those old leases. No renderer, marker, schema or
independent-helper outcome mechanism is changed. That scope is supported by the current source.

### In-flight canceled publication

Capture the cohort inside the same NSLock critical section that sets manual to nil and marks
leases retiring (`focus-controller.swift:190-194`). focusLease creation checks manual/owner/version
under that lock (`:523-524`) before inserting a lease (`:549-552`). A canceled run therefore cannot
insert a new missed lease after the snapshot. A lease allocated immediately before cancellation is
already in the captured map.

Slow color or catalogue preparation rechecks matchesManual before requesting focus leases
(`:367-397`). A prepared focus request rechecks current run and old marker identity in the writer
(`visual-recovery.swift:274-290`). If it has already passed those checks and entered its metadata
publication, didRenew can conservatively set mayHavePainted (`focus-controller.swift:420-429`).
That does not make a successful recovery report premature: a restored reset needs the same stable
writer lock (`ProcessRunner.swift:193-210`). Either the old focus write completes first and reset
follows, or the recovery marker invalidates the delayed old operation before its output. If a
blocked writer prevents recovery from completing, the target is failed and remains in the cohort.
Do not remove the old publication checks.

### Concurrent clear and replacement

- Completion must check `focusLeases[key] === capturedLease` before changing/removing a map entry.
  A fresh explicit request can transfer an outstanding repaint obligation and install a different
  lease at the same physical key (`focus-controller.swift:535-551`). An old recovery report must
  not drop it.
- Do not enter or leave capturedLease.finished from report completion. The old clear worker owns
  its pairing (`:583`, `:575`) and may still be running.
- Existing clearFocusLease can finish after report settlement. Its own identity check at :571
  already prevents removing a replacement. It may update the detached old lease object, but that
  object cannot regain ownership of the map.
- GUI action completion is delivered on main (`sessions-model.swift:180-181`). Publish cleanupError
  on main too, deriving it under lock from all still-retiring current map entries, not from the
  captured cohort or report counts alone. An unrelated failed/new retiring lease remains visible.
- Keep mode, workingSet and new runs unchanged in the result closure. cancelForRecovery already
  put the canceled logical state Off; a later explicit request is separate.
- Ordinary GUI focus controls are already disabled while recovering (`sessions-model.swift:51-61`).
  The identity check still protects direct calls and future callers without relying on UI gating.

### Partial and incomplete results

Swift Result.success does not imply all targets succeeded. stateSaved true also does not imply any
physical target succeeded. A report with restored A and failed B must remove only the captured A
entry and retain B. Unaffected, absent, and unbound items cannot certify the captured B binding.
catalogueAvailable false does not prevent using an explicit bound restored A item, but forbids
assuming anything about an unreported B.

Vanished is already an accepted terminal cleanup outcome (`focus-controller.swift:566`). Match
the complete physical binding so the same TTY path with a different device or owner generation
cannot settle an old or replacement lease by name alone.

### Minimal tests for this choice

1. Extend the existing same-controller recovery test at :1193: paint, cancel, perform actual
   successful recovery, apply the returned closure, then Focus Off. Assert no new paint and no
   cleanup error. The current test restarts a new controller, hiding the old retained lease.
2. Paint two outside targets. Return a report with explicit restored A and failed B. Assert B's
   cleanup remains pending; after its writer becomes available retry it without repainting A.
3. Repeat with unaffected B, absent B, unbound restored item, and a different owner generation at
   the same TTY. None may settle B.
4. Capture closure 1, then explicitly resume/request fresh focus for the same target before
   invoking it. A late restored item from closure 1 must preserve the new effect ID and dimming.
5. Block old publication before prepare, cancel and recover, then release it. It must publish no
   old focus bytes/metadata after the completed reset. Also cover cancellation after didRenew with
   a failing physical writer: only the report's target result can settle the retained obligation.
6. Let an old clear worker complete after the report closure. Its DispatchGroup must balance and
   its identity check must preserve any new lease.

The independent headless path remains explicitly open. No report/schema receipt is proposed for
that path as part of this slice.

## Addendum: actual implementation source check

Read-only check of the current diff after implementation. No tests were run and no source was
edited. At the time of this read, three new focus-controller tests existed. The parent was separately
adding table-driven unconfirmed outcomes and a late-report replacement regression.

### Source findings

No blocking defect found in the inspected change:

- `focus-controller.swift:190-196` captures Array(focusLeases.values) under the lock that cancels
  manual publication and marks the cohort retiring. This satisfies the in-flight lease creation
  boundary described above.
- `focus-controller.swift:204-207` requires stateSaved and discards unbound report items from
  confirmation matching. Grouping uses the complete physical binding, including device and owner
  generation. The target force unwrap is safe because the immediately preceding filter excludes
  nil targets; no input mutation occurs between them.
- `focus-controller.swift:209-215` requires map object identity and a matching nonempty group of
  outcomes. Dictionary(grouping:) does not create empty groups, so allSatisfy cannot vacuously
  release an absent target. All statuses for that physical target must be restored or vanished;
  mixed restored/failed or restored/unaffected items are conservatively retained.
- Assigning ownershipResolved true and mayHavePainted false is supported by the actual recovery
  operations' successful per-target contract. emergencyReset cancels metadata before successful
  reset, resume reconciliation clears selective ownership before successful current composition,
  and vanished is already an accepted retirement result.
- The callback removes only the captured object still installed at its original physical key.
  A replaced lease's transferred obligation cannot be deleted by this older report.
- `focus-controller.swift:217-220` computes pending cleanup from the full current map while locked.
  Healthy successful targets settle even in a partial report, and any retained retiring target
  keeps the cleanup error. It does not infer blanket success from catalogue availability or global
  hasFailures.
- The callback does not enter or leave a DispatchGroup. Existing clear workers retain their own
  balanced lifetime and old-object identity checks. A worker evaluating restoration after the
  callback sees the old lease unpainted, but cannot remove a replacement map object.
- `sessions-model.swift:171,180-184` binds the closure to this action and invokes it on main only
  for Result.success reports. It runs before finishRecovery publishes recovering false. The
  FocusController guard, not Swift Result.success, decides whether persistence permits settling
  any targets.
- Missing action and Result.failure paths never apply confirmation. They preserve obligations.
  Existing publication checks, marker revisions, target validation, stable locks and 100 ms writer
  budget remain untouched.

The returned closure does not enforce main-thread use itself, matching the controller's existing
public API assumptions. Its production caller explicitly dispatches to main. Direct test or future
callers must preserve that existing ObservableObject publication requirement.

### Three inspected new tests

- `focus-controller-tests.swift:1207`: uses actual recovery, checks reset bytes, calls Focus Off on
  the same controller, explicitly resumes, re-focuses the formerly outside target, and checks no
  stray output there. It directly covers the R2 false-error path hidden by the old restart-only test.
- `focus-controller-tests.swift:1237`: injects a real failed device open for one painted target.
  It checks the partial report, subsequent Focus Off retry targeting only that unresolved device,
  and a later successful recovery releasing its remaining obligation. It does not use marker or
  metadata success as physical proof.
- `focus-controller-tests.swift:1275`: returns an unaffected item after only marker replacement.
  It checks that Focus Off still reports a cleanup obligation and emits no bytes. This rejects
  R2's unsafe marker-mismatch retirement alternative.

The pending table should include unbound restored, absent target, different owner generation,
stateSaved false, and conflicting statuses sharing one physical key. A positive vanished item
checks the other accepted retirement status. The late-report test should install a distinct new
lease for the same physical key and apply the captured old action closure afterwards, proving its
object-identity guard preserves the new effect ID and dimming.

No new renderer behavior or cross-process receipt is present. Independent headless recovery still
has no callback to the live GUI cohort, as explicitly scoped by the parent.
