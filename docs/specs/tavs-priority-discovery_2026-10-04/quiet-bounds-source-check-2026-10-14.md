# Quiet-bound validation checks and limits

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0
Source baseline: `35ca2c0`.

## Parent verification

Codex R3 is confirmed. Enabled quiet rows with a missing selected-kind bound passed validation
and were ignored by evaluation. Swift and shell now require both selected bounds. Disabled
incomplete rows, hourly 0/0 and 55/5, and daily overnight ranges remain supported. Preferences
identifies the required values or offers disabling the row; it does not invent missing values.
The existing hourly editor's visible-0/nil ambiguity remains a UI limitation, now exposed by
validation. No native UI acceptance is claimed.

A connected resume bypass was also confirmed. The previous function reported validation errors,
returned zero and modified a private file even with the stricter current validator (nHvIOY).
Resume now revalidates a master-inactive copy to retain only the documented empty-window warning.
Other invalid enabled rows return before the atomic write. Configuration data is preserved.

| Check | Result | Isolated log ID |
|---|---|---|
| Native missing bounds and scheduler rejection RED | 3 cases, 7 assertions | ebEMby |
| Prior-helper parity RED | Missing-bound case failed; edge control passed | AJrV2b |
| Focused native validation | 29/29 | wG8gCD |
| Release build | Passed, 223.51 seconds | 0xpWqp |
| Full isolated shell/native parity | 22/22 | 1nDFbD |
| Prior resume with current validator | Status 0, file changed; expected regression | nHvIOY |
| Initial full Swift with parallel parity workload | 614 tests, 14 failures (6 unexpected) | LsYHBP |
| Five affected cases after parity completion | 5/5 | GaF3m3 |
| Sequential full Swift | 614/614, 23.588 seconds | l1xmDk |

LsYHBP failed in three existing focus cases, cached-entry reconciliation and global-background
restoration. It includes an explicit Organizer deadline error; other original writer outcomes
were not captured. A read-only snapshot showed load 57.12/59.91/43.05 and 13823.25 MB swap used.
The separated control and sequential full run pass, but neither establishes the historical cause.
No deadline, target check, assertion or production writer was relaxed. Preserve this evidence;
do not infer that all failures were caused by concurrent parity processes or by this validation.
The parity concurrency case checks valid JSON only, not complete concurrent semantic retention.

The suite now requires a private test root and explicit source-built helper, with no in-checkout
build or installed-helper search. Shell syntax passes under macOS Bash 3.2. There were no live
app, native Ghostty, installation, personal schedule/settings, VM or existing-session actions.
This source check is not a replacement for final independent provider reviews or native acceptance.
SPEC/PLAN and D01-D18 remain fixed; the full goal remains active and incomplete.

## Full read-only exploration and checks

The report below is preserved unchanged, including its historical proposed-fix sections.

# Enabled quiet-period missing-bound exploration

Last Updated: 2026-10-14
Version: 1

Read-only source exploration for the parent task. No application, test suite, shell suite,
real-home settings, state projection, build, or installation was run. Repository files were not
edited. Source references below describe the code inspected before the parent's implementation.

## Finding and scope

The current R3 finding is confirmed by source. `QuietPeriod` stores both possible bound pairs
as optional fields (`ScheduleStore.swift:24-43`). The central validator only checks an hourly
minute or fixed-daily time if that individual value exists (`113-141`). Therefore an enabled
quiet period with a missing start, missing end, or both missing passes quiet-period validation.

The evaluator requires both selected-kind bounds and returns `false` if either is missing
(`Scheduler.swift:111-127`). The incomplete enabled period can consequently never mute or
create its requested hard lock. This also affects enabled `hard: true` periods.

This matches the retained review and evaluation in
`docs/specs/tavs-priority-discovery_2026-10-04/current-codex-recovery-2026-10-14.md:57-61,140-155`.
`docs/BUG_REFERENCE.md:79` still records missing quiet-period bounds as open.

## Contract to preserve

- Validate only enabled entries. The central loop already applies
  `for quiet in config.quietPeriods where quiet.enabled` (`ScheduleStore.swift:94-96`).
  `docs/reference/scheduling.md:122` explicitly says disabled entries skip all checks.
  Disabled incomplete rows must remain semantically valid.
- Require only the pair belonging to `quiet.kind`: `startMinute` and `endMinute` for hourly;
  `start` and `end` for fixed daily. Other-kind fields may be nil. There is no contract requiring
  four populated fields or clearing preserved values when the kind changes.
- `masterActive == false` does not skip enabled quiet validation. It only permits empty allowed
  windows. The validator still processes each enabled quiet, so the guard should continue to
  reject an incomplete enabled row while the schedule is paused.
- Missing JSON keys and JSON null both decode to nil for these optional fields. Empty daily
  strings are present fields and already fail `invalidTime`; retain that distinct failure.
- Preserve hourly equality: `startMinute == endMinute` is a one-minute interval because hourly
  evaluation includes both ends (`Scheduler.swift:114-115`). `SchedulerTests.swift:840-841`
  intentionally constructs 0/0. Do not add hourly zero-length rejection.
- Preserve hourly wrapping, for example 55/5, and fixed-daily overnight ranges, for example
  23:00/01:00. Require presence, not ascending order. Existing daily equality rejection remains.

## Existing callers

### Preferences

`ScheduleTab.validateDraft()` calls the central validator, sets a visible `validationHint`, and
disables Save when invalid (`PreferencesView.swift:80-88,112-138`). A new specific validation
error needs a corresponding catch here to avoid the generic `localizedDescription` hint.

`loadDraft()` decodes existing saved data and then validates it (`105-110`), so users can repair
an already incomplete saved row after the rule is tightened. The existing load does not overwrite
that file. `ScheduleStore.save` itself does not call `validate`; keep awareness of that boundary.

### Headless validation

The `--validate-config <path>` entry directly calls `ScheduleStore.load` and `validate`, exits 0
on success, and prints `validation error: \(error)` before exiting 1 on failure
(`TAVSApp.swift:57-67`). Tightening the central validator covers this entry without another
validation implementation.

### Scheduler loading

`Scheduler.loadAndEvaluate()` already validates a decoded candidate before adoption
(`Scheduler.swift:340-351`). A new `ScheduleValidationError` is recognized as semantic
rejection, sets `config = nil`, preserves the existing manual-lock projection path, and prefixes
the status with `Schedule rejected: invalid configuration.` (`349-360`). No extra loader guard
is needed for missing bounds.

## Editor compatibility and the visible nil issue

`addQuietPeriod()` creates an enabled hourly row with 50 and 59 (`PreferencesView.swift:183-193`).
The proposed presence check preserves this default exactly.

The kind Picker binds directly to `$quiet.kind` (`282-287`). Switching from the default hourly
row to Fixed Daily does not initialize `start` or `end`. The string getter displays nil as an
empty field (`351-357`). The stricter validator will correctly disable Save until the user enters
both daily times or disables the row. Switching back retains already stored hourly bounds.

An imported fixed-daily row commonly has no hourly fields. Switching it to Hourly likewise leaves
both minute fields nil. Its integer getter displays nil as 0 but does not write 0 into the model
(`342-348`). Merely showing the row therefore does not make it valid. The user must enter a value
in each missing minute field, or disable the row. Whether retyping the displayed same value
invokes SwiftUI's setter was not tested by this source-only task.

This is an existing presentation ambiguity newly exposed by honest validation, not a reason to
accept absent bounds. Do not silently populate optional fields from a getter. A targeted editor
change can be considered separately if the parent needs native acceptance for that interaction.

Recommended actionable hints, including the kind and editable ID:

- Hourly: `Enter start and end minutes (0-59) for hourly quiet period "quiet-1", or disable it.`
- Fixed daily: `Enter start and end times (HH:MM) for fixed daily quiet period "quiet-1", or disable it.`

These messages tell the user how to repair the rule. A small specific error carrying the quiet
ID and kind is sufficient; no new error hierarchy or model abstraction is needed. If the error
carries the missing field, naming `start minute`, `end minute`, `start time`, or `end time` would
be even more precise. Do not add that payload solely to create extra framework.

## Supported fixtures and existing test construction

Read-only `jq` inspection found:

- `Fixtures/schedule-canonical.json`: two quiet periods, both enabled, both selected pairs
  complete (hourly 50/59 and daily 12:00/13:00).
- `Fixtures/scheduler-matrix.json`: five quiet periods, four enabled and one disabled. Every
  selected pair is complete. Includes hourly 55/5, daily 23:00/01:00, and disabled hourly 50/59.
- All existing `QuietPeriod(...)` construction sites in `ScheduleStoreTests`, `SchedulerTests`,
  and `SchedulerLockTests` populate the selected-kind pair. In particular,
  `SchedulerTests.swift:935-937` explicitly sets minute fields nil for a complete fixed-daily row.
- `tests/integration/schedule-evaluator-parity.bats` uses complete selected pairs for its valid
  fixtures. Its native validation helper calls `--validate-config` at line 117.

No supported fixture or existing default relies on an enabled incomplete selected pair being
accepted. The change deliberately rejects that erroneous state. Existing tests cover invalid
provided values, but not the missing-bound matrix or disabled incomplete quiet rows.

Recommended discriminating regression cases are missing start, missing end, and both missing
for each kind; disabled counterparts; selected-kind complete with other-kind fields nil;
hourly 0/0 and 55/5; daily 23:00/01:00. Use a valid allowed window to avoid masking the expected
error with `emptyAllowedWindows`.

## Adjacent CLI parity limitation

`src/cli/cmd-schedule.sh` describes its shell validator as mirroring the Swift validator. Its
existing validation path also checks optional quiet fields only if present (`209-240`). A central
Swift fix therefore leaves shell `tavs schedule validate` behavior different for incomplete
loaded files. This is separate from the headless native entry, which is covered by the central
fix. The CLI `add-quiet` commands already require both selected-kind arguments (`489-505`).

No CLI changes or suites were performed in this exploration. The parent should record this
remaining mismatch or include it in explicitly authorized scope.

## Observable workflow for the parent's final capture

The task traced the validator and evaluator first, then the three callers and editor bindings,
then checked fixture values and existing test constructions. The strongest additional finding
was the hourly binding's nil-to-visible-0 presentation. Broad search output exceeded the tool's
aggregate cap, so the follow-up reads narrowed to fixture values and construction sites. Two
guessed shell-test paths did not exist; the actual file inventory showed the schedule parity
suite under integration. No execution-based correctness or native UI acceptance is claimed.

## Follow-up: actual diff and resume exception source check

### Metadata

- Reviewer: Codex source-check subagent; review-standards standard tier.
- Review type: code, focused coaching review.
- Date: 2026-10-14.
- Target: current quiet-bound changes in ScheduleStore, PreferencesView, shell validation,
  ScheduleStoreTests and schedule-evaluator-parity, plus the connected resume caller.
- Evidence limit: source only. No tests, builds, app launches, settings or repository edits.

### Rubric Scores

| Dimension | Score | Evidence |
|-----------|-------|----------|
| correctness | 5 | Selected-bound guards are correct; existing resume still writes invalid candidates. |
| security | 7 | No changed credential or privilege boundary; test paths resolve privately. |
| maintainability | 8 | One specific central error, one hint catch, direct shell presence guards. |
| test_coverage | 7 | Omission matrix, disabled rows, selected kinds and edge bounds have source tests. Resume needs a regression. No execution verified. |
| completeness | 5 | Validator callers covered, but resume bypass remains pending at time of read. |

### Verdict

CONCERN for the current diff until the confirmed resume bypass is corrected. Confidence is high
for the source behavior and medium for the proposed correction because it was not implemented
or executed by this reviewer.

### Findings

**[R1] HIGH: resume still writes invalid enabled quiet rules**

- Situation: `src/cli/cmd-schedule.sh:387-401` sets the candidate's master flag true and invokes
  `_schedule_validate`.
- Behavior: Every validator failure enters a warning that incorrectly identifies the failure as
  no enabled windows. Execution then reaches `_schedule_atomic_write` and a success message.
  The new missing-bound checks therefore still permit a paused incomplete rule to be resumed
  and saved. Invalid existing time values use the same branch.
- Impact: Resume bypasses the newly repaired shell validator; an enabled incomplete quiet can
  still be accepted by this mutating command. The native loader rejects it later.
- Suggestion: Keep the documented no-enabled-window exception, but validate a candidate copy
  with only `master_active` changed to false. If that copy fails, return nonzero before the
  atomic write. Only if it passes should the original master-active candidate be written with
  the existing no-windows warning.

### Why the proposed resume fix preserves bootstrapping

`docs/reference/scheduling.md:248` explicitly permits resume with no enabled windows and a
warning. File lifecycle at `306-307` includes resume as a first-use creation command.
`_schedule_load_or_create` creates an empty master-active skeleton at `52-58`.

The only check conditioned on `master_active` inside `_schedule_validate` is the empty enabled
allowed-window check at `147-150`. The loops at `155-196` still inspect every enabled window
and quiet regardless of the master flag. Therefore the relaxed copy removes precisely that
one exception. It does not waive missing selected-kind bounds, invalid provided time values,
minute ranges, empty IDs, empty window days, zero-length daily intervals or unknown quiet kind.

With a fresh empty skeleton, full validation fails for no windows, relaxed validation passes,
and resume retains creation plus success/warning. With an existing incomplete enabled quiet,
relaxed validation still fails and a return before `_schedule_atomic_write` preserves that
existing file. Disabled incomplete quiet rows retain their explicit exemption. The dispatcher
calls `_schedule_resume` directly (`707-709`), so a nonzero return propagates to the command.

This conclusion covers the requested decodable schedule and semantic field cases. It does not
establish general shell-validator schema parity for arbitrary malformed JSON or wrong types.

### Checks against likely regressions

1. Requiring the inactive-kind pair: disproved. Swift guards only the selected pair; shell
   switch cases do the same. New omission cases include complete inactive-kind fields so that
   accidental cross-kind acceptance is detected.
2. Rejecting disabled incomplete rows or valid wrapping/equality: disproved in source. Enabled
   filtering remains, while the new edge fixture includes hourly 0/0, hourly 55/5, daily
   23:00/01:00 and incomplete disabled rows.
3. Losing first-use resume: disproved for the proposed relaxed validation. The empty skeleton's
   only validation failure is the master-active empty-window condition.
4. Hidden live test paths: no escape found in the inspected invocation path. The suite now
   requires an absolute executable `TAVS_TEST_HELPER_BIN` and `TAVS_TEST_ROOT` instead of
   building inside the source tree. `tests/run-isolated.sh:9-23` uses a private root and fresh
   environment. Fixture/test homes inherit its private TMPDIR; setup overrides HOME and runtime
   paths. `cli-utils.sh:14-15` computes config paths from that test HOME. The helper invocation
   is `--validate-config <fixture>`, which exits before GUI startup. This is source assurance,
   not a run result.
5. Preferences showing absent minutes as 0: existing ambiguity remains. The new message is
   actionable and disables Save; no editor-binding change was introduced by this diff.

### Suggested minimal resume regression

Under the existing isolated suite, verify one paused incomplete selected-kind rule with a
valid window returns nonzero and leaves the existing file byte-for-byte unchanged. Also verify
the same rejection with zero enabled windows, so the intentional exception cannot mask the
missing-bound error. A no-window valid or first-use control must still succeed, warn, and store
`master_active:true`. Invalid present times should fail the same relaxed check. These are direct
behavior tests of the repaired bypass, without a new wrapper or test control plane.

### Summary

The actual central validator, Preferences hint and shell guards satisfy selected-kind presence,
disabled-entry and interval-edge requirements by source inspection. The proposed resume copy
check correctly narrows its exception to the documented empty-window case. Execution and native
UI acceptance remain parent work.

## Final actual-source check after resume correction

The final diff was retrieved again on 2026-10-14. This section supersedes the earlier pending
resume observation. It contains technical findings only, with no approval decision.

- `ScheduleStore.swift:95-96,119-138` validates enabled rows only. Each kind now guards its own
  start and end, throws `missingQuietBounds` when either is nil, and continues existing range,
  syntax and daily-equality checks. Inactive-kind fields remain irrelevant. Hourly equality,
  hourly wrapping and daily overnight ordering remain accepted by this code.
- `PreferencesView.swift:135-138` catches that specific error, distinguishes minutes from
  HH:MM times, identifies the editable quiet ID, offers disabling as the alternative, and marks
  the draft invalid. Existing Save disablement consumes that state. The nil-to-visible-0 hourly
  binding ambiguity remains the existing native-interaction limitation described above.
- Shell selected-kind guards at `cmd-schedule.sh:214-217,232-235` are inside the existing
  enabled-row loop. They reject omitted/null selected fields, while skipping disabled rows and
  retaining valid 0/0 and wrapping bounds. Blank daily values also fail, although shell labels
  them missing while Swift labels a present blank string an invalid time; both reject the file.
- Actual `_schedule_resume` now validates its master-active candidate, then revalidates a copy
  differing only in `master_active:false` (`395-400`). Failure returns 1 before the write at
  `405`. Since only the empty-enabled-window requirement depends on the master flag, the copy
  preserves all enabled-row validation and restricts the warning exception to that requirement.
  A valid empty skeleton still reaches the documented warning and stores master-active true.
- New resume regressions use the real repository `tavs schedule resume` dispatcher. One saves
  a paused incomplete hourly row with zero allowed windows, asserts nonzero, and uses `cmp` to
  verify no byte changes (`schedule-evaluator-parity.bats:154-163`). The valid empty-window
  control asserts success, the warning text and saved true flag (`165-172`). The rejection
  fixture directly exercises the potential empty-window-exception bypass.
- The parity suite requires an absolute executable `TAVS_TEST_HELPER_BIN` plus the private-run
  marker (`7-10`) and calls that helper directly with `--validate-config` (`110-112`). It no
  longer builds a release helper inside the tracked workspace or searches the installed app.
  `tests/run-isolated.sh:9-23` establishes private HOME, TMPDIR, runtime and state paths with a
  fresh environment. Suite fixture and test homes inherit private TMPDIR; CLI settings resolve
  from test HOME through `cli-utils.sh:14-15`. `tavs` sources the repository schedule module
  for this command (`140-142`). The native validation branch exits before GUI startup, and the
  scheduler still validates a loaded candidate before adopting it.

No additional connected defect was found in this narrow final source check. No tests, builds,
live apps, settings or repository mutations were performed by this subagent. The parent reports
22 passing isolated parity tests, 29 passing focused native checks, and a prior-resume control
that returned zero and changed the fixture. Those execution results were not independently
rerun or used as substitutes for the source trace here. Full-suite timing controls and the
ongoing sequential run are outside this source-check scope.
