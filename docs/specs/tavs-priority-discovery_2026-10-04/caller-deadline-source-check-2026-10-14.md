# Native ready-result deadline source check

Last Updated: 2026-10-14
Version: 1.0
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
