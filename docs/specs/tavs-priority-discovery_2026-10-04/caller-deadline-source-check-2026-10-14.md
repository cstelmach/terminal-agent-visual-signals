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
