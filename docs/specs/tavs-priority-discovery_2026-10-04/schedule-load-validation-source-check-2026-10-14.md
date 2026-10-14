# Schedule load validation source check

Last Updated: 2026-10-14
Version: 1.0

Worktree: /Users/cs/.codex/worktrees/tavs-schedule-validation/terminal-agent-visual-signals
Branch: codex/validate-loaded-schedules

Scope: Scheduler.swift/SchedulerTests.swift diff and connected production callers, ScheduleStore
validation, status projection and lock merge. Read-only; no builds, tests, app control or real-home
state were used. The parent reported a reproduced startup trap and a passing 572-test run; those
runs were not repeated here.

## Conclusion

The minimal guarded-load fix is sufficient for the concrete malformed schedule-time crash. No
unguarded production ScheduleEvaluator time parse remains reachable in the inspected checkout.
No material correctness finding requires a larger parser rewrite or new validated-config type.

## Caller coverage

The only external production calls to ScheduleEvaluator.evaluate and nextTransition are adjacent
inside Scheduler.loadAndEvaluate. That method now loads into a local candidate, validates it, then
assigns the private config. Startup, file/runtime watches, heartbeat, transition/epoch timers,
system wake, lockNow and grantUnlock all converge on this method.

ScheduleConfig and its nested rules are value types. The scheduler's config is private, with no
other adoption path. togglePause starts from that validated private value and only changes the
master-active Boolean before saving; subsequent evaluation still reloads and validates. Preferences
may load an invalid editable draft, but validateDraft gates its save and never calls the evaluator.
The headless --validate-config branch already invokes the same validator.

ScheduleStore.validate checks every enabled window's start/end before the evaluator can parse it.
Enabled fixed-daily quiet start/end values are also validated when present; the evaluator guards
both optional values before parsing. Disabled rules are filtered out by both validation and
execution. The validator checks two integer components, their length and hour/minute range, so the
time parser's indexed components and Int unwraps are safe for validated inputs. Missing quiet
fields are existing no-match behavior rather than an unguarded parse.

## Rejection and existing projections

Semantic validation rejection sets config to nil and uses the existing no-config evaluation tail.
Missing files and decode/storage errors retain that same tail and existing logging, without the
new semantic-rejection prefix. The source schedule is not rewritten by this path.

finishEvaluation still runs LockStateMerge, writes the projected mute state, clears prior paused
visuals on an actual unmute transition, preserves a continuing manual lock/grant, respects recovery
suspension, and schedules the heartbeat/lock wakes. The prefix is appended after the tail computed
status, so a rejected schedule can correctly report a continuing lock, grant or suspension. It does
not incorrectly claim an active state merely because schedule evaluation was rejected.

Each reevaluation replaces status first, then adds one prefix; prefixes do not accumulate. A valid
replacement takes the ordinary branch and removes the rejection message. The new startup/watcher
tests check unchanged source bytes, no pause paint and acceptance of a later valid file.

## Narrow verification limit

The two added tests do not directly combine semantic rejection with a pre-existing manual lock or
suspension. Source tracing shows the unchanged merge/status path handles those cases; an assertion
for that combination would be useful if the parent wants to strengthen coverage, but is not a
confirmed defect or reason to widen implementation. Existing absent-config and lock lifecycle
regressions remain relevant. General HH:MM grammar strictness or malformed editable drafts outside
execution are outside this crash fix.
