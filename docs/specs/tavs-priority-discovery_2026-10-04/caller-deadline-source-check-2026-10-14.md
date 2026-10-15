# Native ready-result deadline source check

Last Updated: 2026-10-15
Version: 1.6
Base: HEAD da1f029 plus current ProcessRunner.swift and process-runner-tests.swift diff.
The final GREEN guard was retrieved after the parent confirmed restoration.
Read-only source check. No edits, test runs, live/native actions or provider review.

Parent: [Progress](PROGRESS.md). The parent verification below is a separate execution record.

## Result

No concrete source regression was found in this two-file change. It closes an existing caller
boundary gap: semaphore success alone previously allowed result retrieval without checking
whether the caller resumed before its original deadline. The new guard checks both conditions
before reading the result. This fixes reporting at that boundary; it is not a reduction in
preparation cost or proof that historical preparation failures have been eliminated.

The parent reports behavioral RED run Sohsxo: with the new clock seam but the guard removed,
the single new test produced two expected failed-throw assertions for completed true and false
at the original deadline. That is parent-provided execution evidence, not a run by this agent.
The current source was then read with the guard restored at ProcessRunner.swift:262-266.

## Publication and thread ownership

- The worker assigns `completion.result = Result { operation(...) }` before signaling the
  DispatchSemaphore (`256-260`). Successful wait remains the publication boundary.
- The caller does not access the Result on wait timeout or caller-time rejection. The new
  completionTime call is short-circuited unless wait succeeds (`262-263`).
- Result retrieval remains after both guards (`267`). The force unwrap's existing premise is
  preserved: worker result assignment precedes its only semaphore signal.
- completionTime is nonescaping and is called on the caller thread. The seam is not supplied
  to the worker or its stage recorder. Its default is real monotonic uptime.
- In the new test, originalDeadline is assigned by the worker before result publication and
  read only after successful wait. That synchronization also orders the captured fixture
  value. The sequential true/false loop does not leave a successful worker running.

No new mutex, worker cancellation, retry or shared cache was added.

## Call routing and unchanged budget

`writeToDevice` (`156-160`) and full `writeManagedToDevice` (`163-236`) call the private
stage-aware completion overload. Both use its default real monotonic completionTime.

The ProcessRunner convenience managed overloads (`30-40`) forward to the full managed call.
They do not bypass the private completion function in production SystemProcessRunner.

The internal generic one-argument-operation completion wrapper (`242-248`) forwards its
completionTime to the same private overload and marks stage operation. Existing test/mock
uses of this wrapper still use the real default unless they explicitly inject the seam.

The private overload still creates exactly one deadline at submission:
`DispatchTime.now() + .milliseconds(100)` (`254`). It passes that same uptime value to the
worker operation and stage recorder (`258`) and uses it for semaphore wait and the new caller
check (`262-263`). The seam does not change worker budget or manufacture a later deadline.

All existing managed publication, storage, admission, open, lock, preparation, descriptor-write
and cleanup deadline checks are outside this diff and retain their original behavior.

## Success, false and error semantics

Before the caller deadline:

- Generic success is returned unchanged. Managed true still reports actual output; managed
  false remains a no-output result. The new guard does not coerce false into true.
- A completed non-timeout error remains its original error through Result.get.
- Existing deviceWriteTimedOut errors preserve their explicit stage; only a missing stage
  receives the existing completion snapshot (`268-270`).

At or after the caller deadline:

- Both completed true and completed false now throw deviceWriteTimedOut rather than return.
  Equality is expired, matching all existing less-than deadline checks.
- A completed failure also reports caller timeout before its original Result error is read.
  This is the intentional changed precedence and should be documented. The caller has no
  remaining budget to accept either a value or a completed-operation error as its result.
- The timeout remains evidence of an unsuccessful bounded call. It does not prove the worker
  painted nothing or undo prior metadata/output. No restoration claim should follow solely
  from this guard.

The real clock check closes the post-wait ready-result gap. It cannot prevent the OS from
pausing the caller after that final check and before method return; it is not a universal hard
real-time return guarantee.

## Finite stage attribution

`DeviceWriteCompletion.enter` records stages only before the real original deadline
(`387-390`). `snapshot` uses NSLock.try and immediately yields unavailable on contention
(`394-397`). The new failure branch uses that same finite snapshot. It does not join or wait
for a late worker, read an unpublished Result or infer a finer-grained cause than last-entered
boundary.

Generic test operation defaults to operation stage before its result is produced. The new
test's expected operation stage is appropriate. Production plain and managed operations keep
their existing concrete stage progression. No stage enum or public error format changes.

## Concrete regression controls worth retaining

The new equality test already covers the important true/false distinction. Add only these
small deterministic controls if further coverage is needed:

1. With completionTime = originalDeadline minus one, return true and false unchanged, and
   preserve a deliberately thrown non-timeout error. This guards the valid-before-deadline
   branch without relying on wall-clock sleep or an artificial larger device budget.
2. With completionTime = originalDeadline, deliberately throw a non-timeout fixture error
   after storing the worker deadline. Assert caller deviceWriteTimedOut with operation stage.
   This specifies the changed late-failure precedence instead of leaving it implicit.

Existing default-clock managed no-output, before-open policy error, backpressure, wedged
operation and physical-write tests remain useful integration coverage. This source check did
not execute or assess their latest outcomes. No new instrumentation or broad test machinery
is warranted for this correction.

## Parent verification and withdrawn draft

Source verification confirms both production writers use the real clock, result access follows
both guards, and stage snapshots remain nonblocking. The recommended before-deadline and error
precedence controls were added and pass. This is scoped exploration, not final provider approval.

Private isolated command logs: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.RUN/command.log`.

- TJ8G45: initial compile RED, absent clock argument.
- Sohsxo: behavioral RED with the seam but no recheck, 1 test/2 expected failed throws.
- uf77mT: 35 writer tests pass; idVcCR: 59 writer/entry tests pass before two added controls.
- I4q8iG: 662 tests, 5 assertions (1 unexpected), all in the existing timed-out predecessor
  cleanup case. Preserve its log; no writer-stage/cost attribution is established.
- VSqicX: connected62 passes, including that cleanup case and all three clock controls.
- CWktqK: final664 passes in 19.994s after the two additional controls. This does not explain
  the previous cleanup failure or establish native Ghostty acceptance.

An earlier one-pass directory-trust draft is fully withdrawn. Lexical-only containment rejected
Foundation-enumerated `/private/var` record URLs under a `/var` runtime, causing storage failures.
The dEnOid run retained 287 tests/417 assertions (209 unexpected); not every assertion is attributed
individually. The original two walks and writer tests were restored from owned backups before
this fix. Runtime/leaf trust, alias validation, producer/cue/record reads and schemas are unchanged.
The proposed alias correction required unwalked-alias and implicit-parent checks; it was not shipped.

Rejected source, source reports and backups remain under the owned external directory:
`/Volumes/external/data/archive/tmp-by-day/2026-10-14/tavs-single-trust-walk-ojij7_li/`.
No live terminals, real preferences, scheduling settings or installed app were changed.

Production release r4zvt3 passes in 29.18s. Rebuilt-helper Bats17HSb1 passes four owned/private
checks: retained standalone intent, actual synthetic color, transferred idle paints, and public
recovery/resume. Bats per-case records remain available. Next: portable ready-result deadline
and delayed tool-error attribution. Required native acceptance and final provider reviews remain.

## Portable investigation

# Portable ready-result deadline contract

Last Updated: 2026-10-14
Version: 1.0
Source: HEAD c1d5168, portable_device_writer.py, portable_renderer.py and connected unit tests.
Read-only source investigation. No edits, tests, native/live actions or provider review.

## Confirmed gap

The portable parent can currently return success, return no-output false, or raise the original
child error after its original deadline. `write_managed` computes its remaining select timeout
at lines 147-148, but it neither checks the clock after readiness nor after pipe read/JSON
interpretation at lines 152-158. A ready pipe with an already expired zero timeout is accepted.
The parent can also be descheduled after readiness or spend its remaining budget decoding the
result. The child checks do not close these caller-side windows.

## Existing 100 ms contract

- After nonblocking reap of older owned children, one deadline is created at parent submission:
  monotonic_ns plus 100,000,000 (`112-114`). Pipe creation and fork consume this same budget.
- The child inherits that exact deadline and runs `_perform` with it (`133`). It does not get
  another 100 ms after fork, admission, locking or physical output.
- Before-open publication occurs before physical open; child inspection, exact character-device
  check, stable TTY lock, prepare and write use the inherited deadline (`63-107`).
- `prepare=None` means successful no-output false. Actual bytes are written under the output
  lock. Partial writes, EINTR and backpressure are handled inside the original deadline.
- Known write-phase failures attach the actual count through `error.bytes_written = written`
  (`104-106`), including a failure after complete output during metadata completion.
- The child sends a small JSON packet with wrote, or errno/bytes/stale (`133-139`), then exits.
  Closing inherited stdio prevents a wedged child retaining caller channels (`123-143`).
- The parent waits only for remaining original budget, reads at most 512 bytes, interprets the
  packet, then always closes its pipe and performs nonblocking owned-child cleanup (`147-172`).
  A still-running child is signaled SIGKILL and retained in `_children` for later nonblocking
  reaping. Do not replace this with blocking waitpid or an added completion budget.

This is bounded reporting with cooperative child I/O checks, not a guarantee that timeout means
zero physical output. A child may have painted before a late parent result is rejected.

## Typed caller implications

All production `write_managed` calls found are in portable_renderer.py:

- `_no_output` (`40-78`) implements register/current/check_context and normally returns false
  after typed target, context, policy and record checks. Late false must be rejected as timeout
  just like late true; it is still a completed transaction result.
- `reconcile` (`90-133`) performs policy/current-target validation and physical restoration.
  `_complete_effects` is called under the held lock only after output (`152-163`).
- Ordinary render/background/forced reset `_execute` (`165-218`) prepares finite typed bytes,
  rechecks policy and target, writes, and completes obsolete ownership records afterward.

Rejecting a late parent result must not undo effects, reread source payloads, retry output, or
claim restoration was absent. It changes the caller's accepted result only. Existing known
child write counts remain useful only when their packet is accepted before the caller deadline.

## Check placement comparison

1. **After readiness only:** catches a late select return and prevents beginning an already
   expired pipe read. It does not cover read/decode consuming or losing the remaining budget.
2. **After read/decode only:** rejects late true/false/child errors before they are interpreted,
   but starts a read after an already expired readiness event. If decoding throws, a check
   placed only after the successful decode is skipped and a late parse error becomes EIO.
3. **Recommended:** check immediately after readiness and again when bounded read/decode
   finishes, including its exceptional path. Keep both inside the existing parent try/finally.
   The second check must precede errno/stale/bytes interpretation and success return.

A small inner `try/finally` around `json.loads(os.read(read_fd, 512))` can perform the second
check on both successful and failed parsing, without another result protocol or public clock
API. It deliberately gives original-deadline timeout precedence over a late parse failure.
Before the deadline, existing malformed-packet EIO handling remains.

## Timeout and byte-count semantics

Reuse the existing `_check(deadline)` primitive, but ensure every parent-generated timeout
sets bytes_written to None. The smallest shared change is for `_check` itself to create that
attribute. Its child uses remain compatible:

- Child prewrite deadline failures already serialize getattr(error, bytes_written, None), so
  adding an explicit None produces the same packet.
- Child write-phase or after-write deadline failures are caught by `_perform`, which overwrites
  the initial None with the authoritative written count (`104-106`). Existing known count
  behavior, including complete output followed by deadline failure, is preserved.
- Parent timeout after readiness or decode must retain None, even if the child packet claims
  three or eight bytes. That packet was not accepted within the caller budget, so the parent
  reports unknown delivery rather than promoting its late byte report to trusted evidence.

Keep the existing not-ready timeout branch and cleanup behavior. Do not infer stale-record
category or physical success from an expired packet. Before deadline, child StaleRecordError
must remain distinguishable from a plain target ESTALE error, as currently tested.

## Practical RED and regression cases

Use existing unittest.mock.patch, owned PTYs and the private TAVS_TEST_ROOT. No new injectable
public clock seam is necessary. Patch clock behavior only in the parent PID; the child keeps
real monotonic time and its actual 100 ms budget. Capture the first parent clock value so the
expiry value is the exact original deadline, not a newly invented timeout.

- Wrap real parent select. Once its read pipe is genuinely ready, mark the parent clock equal
  to the original deadline. Test both a nonempty payload and prepare=None. HEAD accepts their
  true/false results; the correction must report ETIMEDOUT and bytes_written=None. Assert the
  ready-stage expiry hook actually ran so an earlier worker timeout cannot satisfy this test.
- Keep readiness in budget, then wrap parent json.loads to decode normally and advance the
  parent clock to the original deadline before returning the value. Test success/no-output
  and an original child EIO or StaleRecordError packet. HEAD accepts or propagates that packet;
  the correction must report a plain parent ETIMEDOUT with unknown bytes.
- A late error packet with a known partial count must still produce parent bytes_written=None.
  Physical owned-PTY bytes may be checked separately; they do not turn the late call into a
  success. Existing partial and after-output failure tests guard accepted known counts.
- If the implementation uses successful-decode-only checking, add a late malformed decode
  case; an inner finally check avoids that gap. Before-deadline malformed decode remains EIO.
- Retain before-deadline true/false, stale-versus-target category, held-lock deadline, delayed
  preparation, stdio detachment and existing known partial/full byte tests (`45-190`).
  Verify `_children` retires with the existing bounded teardown. No cleanup deadline widening.

The read packet is bounded at 512 bytes and current child JSON output is small. This correction
addresses result acceptance timing, not a newly designed transport, parser schema, I/O trust
system or claim that all portable deadline issues are solved. Parent read syscall failures,
record-directory trust and Linux backend completion remain separate work unless source/tests
show a directly connected regression.

## Portable parent verification

The final scoped diff check finds no concrete regression. Root verified checks after readiness,
after read and in the decode finally, before interpreting result fields. Worker deadline and
nonblocking child cleanup are unchanged. Child write-phase failures still overwrite unknown
bytes with their known count; caller timeouts retain None. No provider approval is claimed.

Five new tests cover all parent boundaries and timely/late parse errors. Parent-only clock
patches use the original deadline and require the intended expiry hook to run. Each late
boundary includes real paint, skip, EIO, stale and a known three-byte partial-output packet.
Physical bytes are checked independently. Existing write-loop partial/complete error tests pass.

Logs under the prior private `tavs-isolated.RUN/command.log` root:

- ze6SFt: initial three tests fail12 assertions, proving late acceptance/category behavior.
- q5Fi1N: first writer15 pass; dKbdxx: late parse RED fails4 assertions.
- XjAYaX: portable182 pass,7.318s; XxqKJB: final182 pass,7.348s after partial/expiry controls.
- f2H3SR: Swift664/2 unexpected assertions,24.285s. The existing delayed-clear/relaunch test
  fails its fresh render with native prepare timeout and following PTY read timeout.
- puqFoF: that single native case passes,0.080s; no unchanged full rerun erased f2H3SR.
- x9DupH: four Bats2 pass/2 fail. Portable synthetic render reports os-60; owned synthetic
  reaches all intended colors but fails its tool-error timestamp check. Records are retained.
- E1OGyv: those two shell cases pass separately. This does not explain the combined failures.

The portable root/report does not explain native preparation or delayed restore timing.
No deadline was widened, native source changed or required acceptance waived. Next: preparation
cost and delayed restore attribution, with Linux/native/headless/palette and final reviews open.

## Tool-error restore correction

Last Updated: 2026-10-15 (Europe/Vienna). Source baseline774d91d; scoped exploration only.
Two read-only reports established the original-delivery, paint-only continuation contract and
compared retained failure/control records. Root checked the source before implementation.

The worker used one context check and one synthetic render. Any precheck failure ended work;
synthetic core then hid render failures behind exit0. Either path could abandon a current
restore. The worker now retries exact code1 once after50ms, checking original context again.
Code3 stops immediately; other codes stop. Each helper call retains its original100ms budget.
The final synthetic flush returns its managed status; ordinary render failures retain exit0.
No observation, timer, counter, ownership schema or meaningful hook was added.

Retained x9DupH failure: matching tool-error observation/intent delivery, error background
#4A2A1F, timestamp delta0.42812395095825195. Passing E1OGyv control: processing background
#473D2F, delta1.8463268280029297. These records locate the failed assertion but cannot identify
which silent stage failed. The fixed timestamp-only oracle could also accept a slow initial
error paint without a restore. Current acceptance waits for a distinct configured processing
color on the same delivery and actual captured OSC bytes while the producer remains alive.

The temporary proxy Ql2lMo passed before source changes: current precheck0 and render0, with
outer measured22ms/29ms. Its wall-clock readings include launch/proxy cost, not native stage
elapsed. It did not reproduce or attribute the historical failure.

Private logs under the prior `tavs-isolated.RUN/command.log` directory:

- XRfCME: two injected one-shot check/render failure tests fail on the original source.
- eqrsYK: those two pass with the correction; hmLuin: initial five focused cases pass.
- KfPGF3: broad managed run retains two fixture failures. A stale synthetic test expected
  masked-success0; it now expects3. Retry fixture also waited on checks before required renders.
- Source review found that intent-only completion could close the PTY before output. The
  reader now acknowledges captured exact OSC bytes, and the owner waits for that flag.
  New mocks isolate state and wait for required check/render counts. Ineffective new bell
  overrides were removed; the existing actively enabled suppression test remains.
- ZVdNQI: all29 managed checks pass. ZbAaO6: all19 intent checks pass, including owned PTYs,
  stale delivery races, subagent state/count preservation, worker colors and recovery/resume.
- U538SB: earlier five real-helper restore/control cases pass before the byte-handshake repair.
- ks8aHi: full664 has one assertion, unavailable1 instead of stale3 in the existing forced-reset
  case at managed-output-entry-tests.swift:340. This is retained, not attributed to shell changes.
- 83B51F: ShellCheck reports existing SC1091/SC2329 notes outside changed lines. Bash syntax passes.

The scoped review's two concrete findings were checked in source and resolved. It did not run
runtime tests or replace required final provider reviews. Persistent helper errors can still
leave error styling until a new hook or recovery; retry is deliberately bounded. Historical
missing restore, native preparation, Linux/headless/palette and native UAT remain open.

Full agent reports and owned backups remain in
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-tool-restore-probe-tgrtibud/`.
The reports produced two confirmed failure paths, one weak restore oracle, and two concrete
review findings. This synopsis retains those outcomes without copying the443-line report set.
No working terminal, installed app or real preferences/schedules were changed.

KUXeoB: the single forced-reset case passes separately in0.044s. This does not explain ks8aHi
or change the retained full-suite outcome. Next work remains native deadline/status attribution.

## Record buffer checkpoint

Source baseline 1a6a5ab. The original forced-reset first result still expects stale code 3; it now
retains the fixed error label and monotonic caller elapsed on failure. No mock or accepted
status set was substituted. The original code 1 result has no retained reason and remains open.

Before the buffer change: OhryCJ focused 61 pass, 6.359s; yXyU2s full debug 664/16 assertions
(7 unexpected),39.065s; lT5Sg9 full optimized 664/19 assertions (15 unexpected),46.299s.
The forced-reset target passes both new full runs. Other publication/open/prepare failures
remain, so optimization mode does not explain them. No unchanged full rerun erased these logs.

One owned Swift-wrapper profile attempt ran100 recovery cases/3 failures but found no live
XCTest child to sample; it sampled nothing. A direct, cleared-environment owned XCTest run
successfully produced a 3 s/1 ms stack sample. That profiled run retained 100/47 assertions
(34 unexpected),25.085s. Profiling can perturb timing; it is not production latency evidence.
The sample's collapsed top-of-stack list includes 133 lstat, 32 open and 31 allocator samples,
among much larger idle-workqueue and test-poll counts. These are sampled occurrences, not
per-operation durations, an allocation measurement or an explanation of a historical failure.

A proposed literal-prefix trust continuation was rejected after source review: removing the
second walk can miss an intervening symlink or permission change. Both original walks remain.

The two-line production change sizes the read buffer from the checked fstat size plus one.
For a 122-byte fixture it requests 123 instead of 8,193 bytes. Each request is min(buffer size,
8193 minus accumulated bytes), so it never requests zero merely because a small chunk filled.
Only actual EOF accepts a bounded complete record; byte 8,193 still rejects. Directory/leaf
trust, device/inode/type checks, producer/context rules and per-syscall deadline checks remain.

Logs under the prior private `tavs-isolated.RUN/command.log` directory:

- H0w44F: three new tests, 1 expected RED assertion (8,193 versus 123); growth cases already pass.
- rV9964: post-change 141 tests/4 deadline assertions,17.697s. All 61 entry/writer cases and the
  three new read cases pass; remaining errors are in existing state/deadline fixture work.
- YCaeuz: six reader cases pass, 0.290s, including original interrupted/partial deadline guards.
- hbhrgc: updated production release build passes, 84.37s.

The new cases check actual EOF and unchanged cached bytes, same-inode growth past the cap
using whitespace after valid JSON, and a within-cap invalid suffix beyond the first chunk.
Their format-only fixture calls use .max; the original 100 ms deadline regression cases are
unchanged. Scoped source review verifies the positive request bound and preserved contracts;
it did not run tests or replace final independent provider reviews.

A host snapshot after the post-change run reports load 80.13/81.16/73.89 with 12 logical CPUs.
This is uncontrolled timing context, not causal attribution. No other job/session was stopped,
no budget widened and no broad timing rerun added after that snapshot. Native timing and
physical Ghostty acceptance remain pending; operator availability was requested.

Full reports, sample, logs and owned backups are retained under
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-reset-status-ccm__mfv/`.
No speedup, whole-suite pass, resolution of the old mismatch or goal completion is claimed.

## Native recovery race fixture correction, 2026-10-15

Baseline `9b16246`; only three tests in `visual-recovery-tests.swift` change. Production source,
100 ms writer/caller checks, identity validation and cleanup behavior remain unchanged.

X4ovLj's retained four assertions across three cases did not demonstrate wrong output. The intake
fixture's own 20 ms target publication expired; its catch returned -1 from open, hiding the desired
stale check behind deviceNotWritable. The marker cases ran complete trusted marker writes inside
policy/open callbacks; prepare then timed out. No single latency cause was established.

Marker fixtures now prepare real owned mode-0600 suspended files before the operation, then use
checked same-directory rename at their original pidAlive/open boundary. Preview still verifies
cached target before policy replacement, rejects the old revision, leaves no preview or pixels,
and asserts suspended state. Reconciliation retains exact reset bytes and a following no-op.
The cached-record enumeration remains in pidAlive, so no blanket callback-cost claim is made.

The intake test is renamed BeforeDeviceAdmission. It performs the original beforeOpen publication
through the existing bounded completion helper, publishes the independent newer observation and
bound intent, then invokes real SystemProcessRunner with frozen prepare/afterWrite and exact
physical target. Each bounded operation uses the existing 100 ms helper. It requires exact stale,
latest background, target forwarding and no PTY bytes. It does not test one combined deadline or
publication during already-held admission. Those combinations remain covered by unchanged
ProcessRunner publish/open retry/original-deadline and wedged-open tests, plus VisualRecovery's
standalone-intent publication during admitted open. Their source assertions were checked directly.
The read-only source assessor found no uncovered product open-order invariant in this change;
its assessment did not execute tests or establish native acceptance.

Isolated verification, with the explicit source-built helper and owned scratch build:

- dHx3w2: all three original cases pass alone, 0.109 s. This does not attribute X4ovLj's failures.
- aeaXdu: three revised cases pass, 0.101 s; test rebuild 7.26 s.
- EFWqkG: full 671, seven assertions (five unexpected), 33.042 s. All three revised cases pass,
  including final suspended-state assertions. No whole-suite pass is claimed.

Current failures are `BroadcasterTests.testSystemProcessRunnerDeliversLargePTYWriteWhileReaderDrains`
(write-stage timeout, read timeout and an unwaited expectation),
`FocusControllerTests.testMixedCueSourcesRemoveOnlyKnownExitAndContinueThroughAnotherValidSource`
(missing PTY3 bytes and timeout), and
`VisualRecoveryTests.testClearRestoresLatestIntentAndCanceledRecordRemainsRetryable`
(prepare timeout and subsequent read timeout). These are the next evidence targets. The observed
host load 25.27/28.81/25.02 is context, not causal proof. All failed runs remain recorded independently.

Original files, complete logs and the full source assessment are retained in
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-native-race-fixtures-4pnllwsc/`.
Scope divergence: one existing test file and relevant docs, supporting Phase 9 verification.
No live app install/sync, real preferences/schedules, native Automation, terminal paint or existing
session shutdown occurred. Linux kernel and Ghostty physical acceptance remain open; goal and
Phase 9 remain incomplete. SPEC/PLAN bodies are fixed. Earlier failures remain retained.

## Owned-PTY outcome and cleanup observation, 2026-10-15

Baseline `c819653`; only BroadcasterTests and focus-controller-tests change. The selected baseline
0PMLbF reproduces the large-write timeout/read-timeout/unwaited-expectation cascade while the
mixed-cue and preview-clear cases pass (three cases, three assertions, 6.333 s). This distinguishes
current evidence from assuming every earlier missing-pixel report is a writer timeout.

The 65,536-byte test now captures synchronized writer Result and its own elapsed time, retains
reader progress on error and always reaches a bounded completion wait before assertions and
normal descriptor cleanup. The exact bytes and actual 100 ms native writer remain mandatory.
An owned CLOEXEC slave duplicate stays with the queued writer until return, so delayed outer
startup retains that PTY allocation. Descriptor setup occurs before creating the expectation;
missing-result diagnostics include received/read counts and elapsed time. Background code no
longer emits XCTest failures before publishing its completion. Poll errors retain raw outcomes.

The Focus missing read at old line652 was final Focus Off restoration. Earlier reads and cue
assertions succeeded. A stale awaitManual after acknowledgement did not prove a new operation
completed. The case now installs the existing recordedWriter for its only outside target D,
retains cue/PTY checks, and subscribes to a fresh cleanup publication before Focus Off. It requires
nil cleanup error and actual PTY bytes. Failed reads include current status, cleanup error, raw
poll outcome and existing writer trace. No new production diagnostic API or tracing layer exists.

Source reports found no production loop/semantic defect. They identified two fixture error-path
gaps, both fixed: expectation creation before descriptor setup and missing-result diagnostics
after unwrap. The shared raw-poll message improves observability without turning every read
error into evidence about a writer. No writer deadline was extended and no payload was reduced.

Retained isolated runs:

- EWpjLa: both instrumented selected cases pass, 0.240 s; test rebuild 13.38 s.
- mckQjj: full 671, seven assertions (three unexpected), 42.198 s. Targeted cases pass; four other
  cases fail. A failed Focus read now explicitly records poll0/revents0, rather than unknown errno.
- eNYnR5: controlled first-read cancellation; one test intentionally fails three assertions.
  It captures 0/65,536 received, one read, writer 102,949,875 ns and pre-assertion total 139,827,459 ns.
  Actual writer error is write-stage timeout. No unwaited expectation appears. Whole case 4.438 s
  includes assertion reporting and is not the writer duration. The temporary injection is removed;
  cmp confirms exact restoration to the saved pre-probe test source.
- nGQwrj: final full 671, 60 assertions (43 unexpected) across 30 cases, 70.893 s. Both changed target
  cases pass (large write 0.017 s, mixed cue 0.114 s). This remains a failed suite, not acceptance.

At 12:44 the host reports load 73.17/97.87/104.43 with 12 logical CPUs. This is uncontrolled context,
not per-failure causal proof. No unchanged broad rerun follows. Historical errors remain open.

All logs, prior files, pre-probe source and two complete source assessments are retained in
`/Volumes/external/data/archive/tmp-by-day/2026-10-15/tavs-pty-write-outcomes-5chy1fto/`.
Production, SPEC and PLAN are unchanged; no live install/settings/terminal/session action occurred.
Next independent source work is review S4: session-state still does unlocked shared-file RMW;
its atomic rename cannot prevent stale snapshots losing another TTY row. Source recon is saved
at `/tmp/explorer-tavs-shared-session-color-races-20261015.md`. Linux kernel and Ghostty physical
acceptance, runtime timing validation and the full goal remain incomplete.

## Fresh isolated Swift verification: 2026-10-15

At `3ef11af`, a new external debug build completed in 37.63 s without warnings. Seven
representative previously failing tests pass in 0.121 s. The full isolated XCTest run passes
671/671, zero failures, in 16.375 s. The 100 ms writer deadline and source were not changed
to obtain this pass. Host load before/after was 5.93/7.03/7.00 and 8.64/7.55/7.18, respectively.
These observations do not identify the cause of the earlier nGQwrj failures; retain that history.

The focused source inspection found no confirmed load-independent semantic defect explaining
those failures. It identified a conditional fixture teardown hazard after caller timeout and
existing prepare/read seams for any recurrence. No speculative instrumentation was added.
Full source assessment:
`/Volumes/external/agent-data/reports/2026-10-15/tavs-native-prepare-deadline-explorer-174500.md`.
Complete build/selected/full logs and load snapshots are retained under
`/Volumes/external/agent-data/retained/terminal-agent-visual-signals/swift-failure-repro-20261015-174233-bd669d/`.

The separately verified `b44727f` launch guard requires private settings for the exact test
bundle even when opened without environment keys. Its test failed compilation before the new
policy, then passed. Full isolated XCTest: 672/672, zero failures/warnings, 18.949 s. The signed
staged bundle also exits 1 before UI or private preference writes when settings are absent.
Red/green/full and bare-bundle logs plus launcher sources are retained under
`/Volumes/external/agent-data/retained/terminal-agent-visual-signals/native-acceptance-20261015-180639-d93516/`.

The operator supplied only `/dev/ttys031` and `/dev/ttys038` for native checks. The prepared
launcher resolves exact native IDs, uses private roots and copies only configured background/
foreground guides into its private Ghostty config. Five offline color-guide cases pass.
The native catalogue, UI and device effects have not been exercised by the parent. Computer
Use access to `com.mitchellh.ghostty` is denied for safety; no alternate control route was used.
The operator was asked to run the launcher. Docker's socket is still absent, so eight real
Linux cases remain unrun. Native acceptance and the full goal remain incomplete.

The operator subsequently explicitly instructed the parent to run that exact launcher. Its
property-only bootstrap timed out after 8 s before launch or paint. A bounded instrumented read
confirmed native properties return, distinguishing this failure from a permission rejection.
A Scripting Bridge column-read probe obtains 37 IDs/TTYs and the two dedicated matches in
0.538 s, within the unchanged 2 s product budget. The next slice should eliminate repeated
per-property/per-loop catalogue requests, then retry the scoped app. Complete launch/diagnostic
logs and scripts were copied to the same native-acceptance retained directory above.
Portable mutation source recon is also available for the next independent correction:
`/Volumes/external/agent-data/reports/2026-10-15/tavs-portable-mutation-trust-explorer-182507.md`.
It distinguishes a whole-transaction lost-update defect from conditional pathname races.

## Native selector batching: 2026-10-15

`39bed38` replaces per-terminal metadata/collection-count evaluation with Scripting Bridge
`arrayByApplyingSelector` column reads. Global ID order is checked before publication, metadata
length mismatches become missing coverage, and hierarchy/ID mismatches reject the catalogue.
Window/tab proxies remain exact-ID and PID bound. Native/device budgets remain 2 s/100 ms.

The generic properties probe returns -1728; the KVC-column prototype still exceeds 2 s. The
selector prototype reads 37 surfaces across 33 windows in 1.184 s. Two behavioral RED cases
fail three assertions, including 185 individual metadata reads. Final connected checks pass
17 catalogue cases and the previously failing broadcaster case: 18/18, 2.710 s. The final full
isolated XCTest run is 674/674, zero failures/warnings, 17.447 s (17.494 s elapsed).

Earlier full 2IuBk2 retains two assertions in the existing startup plain-shell broadcaster test,
27.697 s. Its native snapshot is a fixture closure, not the changed adapter. Current source
therefore does not establish a catalogue semantic cause. A subsequent host snapshot reports
232.43/109.75/60.86 load on 12 CPUs; this is context, not a failure-cause finding. The final full
run used the updated permission case with the owned test app stopped, then reopened it.

The explicitly requested launcher now obtains only ID/TTY bootstrap columns within 2 s.
Computer Use confirms the dedicated banner and exactly `/dev/ttys031` and `/dev/ttys038`.
Duplicate title/directory rows remain distinguishable by TTY. Resizing from 1100 x 500 to
954 x 434 and two-row multiselection work. High priority on031 survives a test-app restart;
038 remains Normal. Restore Visibility persists the private
marker and suspension survives relaunch with Focus Off. During catalogue timeouts, retained
rows are marked unavailable and focus controls are disabled. Recovery reports native discovery
unavailable and zero known targets checked rather than claiming terminal restoration.

The test app remains open, Focus Off, no selection/preview, with its private suspension enabled.
Ghostty cannot be viewed directly through Computer Use. Visible terminal backgrounds, exact
Go To, hidden/minimized windows, other Spaces, cues, working-set effects, hung-menu/device
recovery and Linux kernel cases remain unverified. No real install/settings or working-session
shutdown occurred. System Settings also displayed older TAVS Automatic/Manual Acceptance login
items; their paths/active state were not investigated or changed.

All catalogue RED/green/connected/full/final logs, variants and launch results are retained in
the native-acceptance directory above. The staged app/build/cache trees remain at their native
external working paths. No cache/build/report purge was performed. Next source work is the
portable lock transaction described in the already saved mutation recon report.

## Native preview outcome and binding diagnosis: 2026-10-15

`3a579d2` retains the current run's outcome after automatic expiry while clearing active state
and scheduling existing cleanup. Explicit cancellation resets it; unfinished delivery says
unconfirmed, and late results cannot overwrite a newer attempt. Preparation errors distinguish
colors from native mapping; typed device/state deadlines retain finite reasons without raw paths.
The [source check](/Volumes/external/agent-data/reports/2026-10-15/tavs-preview-outcome-source-check-203000.md)
confirms exact native enumeration precedes the100 ms device deadline. No budget was widened.

The first four focused tests failed four assertions, then passed4/4 after correction. An added
preparation-phase case failed both branches, then passed. The latest five-case run passes all
three new cases; two augmented real-PTY cases fail on device deadlines after previously passing.
Full676 first has3 failures across3 methods; its focused rerun passes3/3. The subsequent full676
has37 failures across12 methods,13 unexpected,45.803 s (46.047 s elapsed). Current677-test source
builds, but a full677 run has not been performed. Broader verification remains open.

The isolated app was updated, signed, relaunched and inspected through Computer Use. Its existing
launcher now refuses a changed native cohort before rebinding the two approved TTY names. Prior
executables/launcher were preserved. Focus remains Off with recovery suspended. Selecting031
through TAVS reproduces native-mapping failure; the operator again reports no visible highlight.
Private CLI color validation/show completes in0.162/0.105 s with valid colors. No Ghostty UI access,
navigation, working-session termination or production install/settings change occurred.

Scoped native reads return the correct zsh foreground PIDs for031/038, with matching device/group
metadata. Both zsh processes have root-owned login parents. PROC_PIDTBSDINFO returns0/EPERM for
those parents, so continuingOwner rejects the binding. Only count/errno from failed calls are
meaningful; zero-initialized fields do not establish identity. A read-only KERN_PROC_PID probe
returns full648-byte records for both parents and children, valid matching start times and TTY
groups, root UID and no P_WEXIT. This is a concrete owner-inspection blocker, not an implemented
fix or proof that every native failure has this cause. Preserve identity checks when correcting it.
The [Darwin inspection report](/Volumes/external/agent-data/reports/2026-10-15/tavs-darwin-parent-inspection-source-check-210000.md)
recommends one primary KERN_PROC_PID snapshot in Swift/Python. SDK compiler checks agree for
arm64/x86_64. Kernel P_WEXIT is distinct from the old libproc exit bit. The report supplies
binding/layout details and RED cases; no product implementation or Intel runtime check is claimed.

Complete logs, private color/native/kernel probes, source and executable backups are retained at
`/Volumes/external/agent-data/retained/terminal-agent-visual-signals/preview-outcome-20261015-203300/`.
The staged app and build/cache remain external. Next: replace the denied parent-inspection path,
then rerun required acceptance and broader checks. The goal remains incomplete.

## Public Darwin identity and the next native timeout: 2026-10-15

`66a402f` and `efe7b98` replace Darwin identity inspection with public `KERN_PROC_PID`
snapshots in Swift and Python. Both preserve birth-time, TTY and strict parent-walk checks.
Swift uses the SDK structure; Python validates the compiler-checked 648-byte arm64/x86_64
layout and keeps executable-path lookup independent. Linux code and both deadlines stay fixed.
The previously failing root-parent regression is GREEN: Swift 8/8 in 0.004 s and Python 14/14
in 0.052 s, including independent libproc parity and a real Python PTY. A scoped read with the
new Python implementation verifies both original dedicated shells and their exact retained
login-owner generations. It does not establish physical delivery.

The full portable run executes 234 cases in 33.785 s: 6 failures, 15 errors, 8 Linux skips.
Full Swift 681 has 49 failures across 26 methods, 30 unexpected, 61.436 s (61.806 s elapsed).
All 8 identity cases also pass in that full run. Failures include deadline errors and dependent
state/byte assertions; they remain unresolved. An isolated prior-libproc renderer control has
33 cases with 1 deadline error in 3.799 s. The current-inspector renderer control has 33 cases
with 4 failures and 20 errors in 9.756 s. These runs are not controlled enough to assign cause.
The first stdin-based control executed no tests because the isolation wrapper closes stdin;
its empty success is excluded. The corrected controls use a saved script/module selection.

An interleaved own-process comparison makes 200 reads per implementation. Prior-libproc
median/p95/max are 0.00446/0.02475/1.04729 ms; current-sysctl are 0.02633/0.31592/54.84542 ms.
One sample does not establish a performance distribution, but its latency tail stays a risk.
No tests, budgets or guards were relaxed to obtain passing results.

The previous isolated executable is preserved. The updated bundle was signed, signature-
verified and launched only after the original native cohort matched. Computer Use confirms
two rows, retained High/Normal priorities, suspension and Focus Off. Selecting 031 reports
`Preview unavailable: resolving native terminal mapping timed out.` No visible highlight or
successful writer entry is claimed. No Ghostty UI, navigation or real installation was used.

The [queue source check](/Volumes/external/agent-data/reports/2026-10-15/tavs-native-preview-queue-source-check-213600.md)
matches current source: a snapshot's 2 s budget includes waiting behind an in-flight refresh,
then a second complete scan. Display metadata is fetched even for mapping-only consumers.
This is a possible timeout schedule, not a demonstrated cause of this attempt. Next try the
smallest mapping-only query, preserving fresh ID/TTY/PID/hierarchy validation and both bounds;
measure the result before claiming queue contention resolved. Final reviews and required
native/Linux acceptance remain open. The app stays suspended with Focus Off.

Complete test logs, both controls, timing/owner probes and source/executable backups are in
`/Volumes/external/agent-data/retained/terminal-agent-visual-signals/darwin-process-identity-20261015-211800/`.
Build/cache and active scratch remain at their external native paths. No cleanup was performed.
