# Phase 1 native targeting: independent review and dispositions

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0
Source baseline: `a23acdc`, with the eight scoped Phase 1 source/test targets uncommitted.

## Execution

Canonical Codex file/partial review completed with exit 0 in 694.635 seconds, using the
read-only code-review profile. Sol configured `gpt-5.6-sol`, high effort; this is command
configuration, not server-side model attestation. One completed turn and no failed/error
events were recorded. Thread: `01a12eca-e015-7a13-9bfe-7b1e20598911`.

Full evaluated report: `/tmp/codex-review-tavs-phase1-20261012.md`.
Raw report: `/tmp/codex-review-files-terminal-agent-visual-signals-`
`tavs-phase1-native-20261012_082649.md` (one wrapped filename).

Original verdict: CONCERN, 7/10, Medium risk. Correctness 6, security 8, maintainability 8,
test coverage 5 and performance 8 give 35/5 = 7. No CRITICAL findings; one IMPORTANT and
one MINOR were confirmed. This document preserves every finding and its source disposition;
it is a synopsis, not a new provider review of the subsequent fix.

## IMPORTANT: Permission/null-proxy tests bypassed the adapter

The original decoder test supplied a fabricated permissionDenied response. The JavaScriptCore
bridge fixture never exercised a required property's lastError.code -1743 or disappearing
objectWithID lookup. The source-supported test gap allowed the classification defect below.

Verification: original test/adapter source and public SBObject.lastError/SBElementArray headers.
The reviewer reproduced permission denial and vanished lookup using the production script
with isolated JavaScript fakes. It did not send AppleEvents or run Swift tests.

Resolution: added adapter-level permission and disappearing-target tests, retaining zero-focus
assertions. Permission classification already passed. Both missing-proxy variants failed before
the correction, as recorded in `review-fix-red.log`. The test covers plain JavaScript null and
an Objective-C-nil-shaped object; the latter's truthiness/isNil behavior was independently
confirmed by a Foundation-only osascript probe with no Ghostty events.

## MINOR: Vanished exact target became generic native failure

The second exact lookup may return nil after snapshot. Dereferencing it through scalar produced
a generic exception and nativeUnavailable, obscuring the distinction from targetUnavailable.
This was a safe failure, not evidence of misnavigation.

Verification: SBElementArray.h documents a reference or nil result; the isolated red regression
reproduced generic native failure with no focus attempts. A bare `if (!target)` would not cover
real JXA Objective-C nil, which the metadata-only probe found truthy with isNil() true.

Resolution: a small missing-value helper recognizes both representations, classifies the exact
target as unavailable before property access and normalizes nil scalar/error values. The new
adapter regressions pass. No framework, native fallback, input action or retry loop was added.

## Source checks retained

- The original 100 ms device writer and DeviceWriteCompletion match baseline exactly.
- The bounded subprocess operation drains both pipes, discards stderr, checks monotonic time,
  caps stdout at 1 MiB and kills/reaps its owned direct child on failure.
- Process identity uses PID plus kernel seconds/microseconds, with exact controlling device
  and foreground-job checks. No argv or transcript data is read.
- Catalogue requests use PID-bound ScriptingBridge and objectWithID, preserve IDs/native order,
  reject stale/ambiguous TTY mappings, pass request values as JSON data and confirm focus.
- The adapter constructs only property reads and explicit focus. No input, key, split, close,
  quit or perform-action command exists. Refreshes use one serial queue and one pending batch.

## Parent verification and limits

Final full Swift run passed 224/224 tests, including 21 new tests, in 2.104 seconds. Release
build, compile-only osacompile and plist validation passed. Logs are in
`/tmp/tavs-phase1-20261012T075910/`. These are parent checks, not a new Codex verdict.

Real Ghostty enumeration/navigation, Automation attribution and UI/Space behavior were not
tested in Phase 1. They remain dedicated Phase 2 acceptance. Upstream scripting can return
empty collections when disabled; an empty catalogue alone must not prove closure during
priority reconciliation. The subsequent UI must preserve that uncertainty.

Related: [PLAN](../PLAN.md), [PROGRESS](../PROGRESS.md), [SPEC](../SPEC.md).
