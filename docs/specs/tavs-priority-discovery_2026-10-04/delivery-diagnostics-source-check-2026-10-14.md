# Managed delivery diagnostics and retained failures

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

Parent: [Progress](PROGRESS.md). Baseline: e53697c. Phase9 remains incomplete.
The two source reports below are read-only checks, not final provider approval.

## Native investigation and source check

# Native managed-output failure diagnosis

Last Updated: 2026-10-14
Version: 1.0
Scope: read-only source and retained logs at TAVS HEAD `e53697c`.
Repository: `/Users/cs/local/code/apps/terminal-agent-visual-signals`.

No tests, source edits, live terminal actions, provider calls or timing experiments were performed.
This is a source diagnosis, not an independent provider approval.

## Result

The retained evidence does not establish why the four broader Bats cases failed. It establishes a
native unavailable failure in the owned PTY synthetic case, after the first ordinary background
bytes. The native entry catches many distinct failures and emits one fixed message. A small
allowlisted diagnostic in the entry point is the useful next source change before another isolated
reproduction. Widening the 100 ms deadline or retrying the full suite unchanged is not justified.

## What the logs prove

Read in full:

- `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.i5itEP/command.log`
- `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.dQrEwk/command.log`

The first run lists 54 tests, with four failures:

1. Native ordinary-provider synthetic updates (`background-intent.bats:116,121`).
2. Portable ordinary-provider synthetic updates (`:116,125`).
3. Standalone muted background writes (`:173`).
4. Owned PTY synthetic colors (`:314`).

Only case 4 retains failure output: an assertion with `ESC ]11;#112233 ESC \`, followed by
`Managed output unavailable.` and `tavs: current render unavailable`. The script uses `set -e`;
its sequence is ordinary `#112233`, then synthetic `#445566`, then assertions and a timer worker
(`background-intent.bats:220-239`). The native entry's unavailable message means a code-1 path,
not the dedicated native code-3 stale branch. It does not identify a timer, lock, storage or device
stage. The prefix proves the initial paint happened; it does not prove publication/paint status
for the later synthetic request. No source logs show a measured elapsed duration.

`dQrEwk` reports all four cases passed independently. This weakens a deterministic always-failing
input hypothesis but is not causal evidence of timing, suite ordering, resource pressure or
cross-case contamination. Cases 1-3 suppress child output on failed status, so their causes may
be different from case 4. A targeted file inventory under `i5itEP` found the retained command log
but no worker logs, scripts or JSON snapshots for these cases. No historical process was assumed
live and no reproduction was attempted.

## First principles and return contract

The helper authenticates a concrete TTY, process generation and frozen context. It must preserve
identity and policy checks even when diagnosing a failure. Ordinary intent publication and actual
paint are intentionally separate: publication can succeed before device open fails. Conversely,
a failure can occur before any intent is written. Seeing current JSON does not prove paint.

`ManagedOutputEntry.run` currently returns:

- Code 0 plus `rendered`, `restricted` or `unaffected` for completed render classification.
- Code 3 plus `Managed output stale.` for `Failure.stale` and the four stale state errors.
- Code 1 plus `Managed output unavailable.` for every other non-persisted failure.
- A structured partial-failure recovery report after suspension was already saved.

For a render, revision replacement makes preparation return nil and hence code 0 `unaffected`;
a normal policy activation gives a restricted render, not generic code 1. Thus these successful
suppression paths alone do not explain the recorded native unavailable line. However, storage,
identity or policy reads during them can still fail and reach code 1.

The 100 ms caller deadline starts in `SystemProcessRunner.completeDeviceWrite` before dispatch.
It includes worker queue delay, prepublication, device open, output-lock acquisition, preparation
and bytes. A caller timeout can occur while a worker is still in a syscall; the worker retains its
original deadline and checks it before later opens, mutations and paint. Reporting must not read
an unfinished worker result or mutable worker stage after timeout.

## Complete source path and plausible failure stages

All file paths below are relative to the repository root.

| Stage | Source | Possible unavailable failure and distinctions |
| --- | --- | --- |
| Request shape and roots | `managed-output-entry.swift:25-49,188-221` | Unknown verb/count, invalid absolute/control-character path, invalid isolated root or allowlist. Fixed `Failure.unavailable`, launch errors or decoding errors become code 1. `--managed-render` receives no actual UI scope under the normal isolated shell harness. |
| Device and context authentication | `managed-output-entry.swift:51-114`; `organizer-intake.swift:128-135` | Non-concrete or unavailable device, `/dev/tty`, invalid context/schema/provider/generation, illegal synthetic flag. Decoding is code 1. Frozen device, live generation or device mismatch is `Failure.stale`, code 3. Non-synthetic ancestor authentication can fail unavailable after its separate 100 ms traversal. Synthetic requests skip that ancestor traversal but still check the exact producer. |
| Render stdin and schema | `managed-output-entry.swift:118-121,153-181`; `terminal-render.swift:12-57` | Stdin must be FIFO or regular, flags must permit nonblocking read, EOF must arrive within a separate 100 ms input deadline, payload must remain <=16 KiB. Read errors, oversize and timeout are indistinguishable `Failure.unavailable`. NUL count, UTF-8, field limits, color/title/image/bell validation throw `invalidRecord` and code 1. |
| Factory construction | `managed-output-entry.swift:130,249-272` | Isolated environment/fixture configuration can throw; ordinary factory creation itself mostly allocates stores. A bad controller lookup yields nil rather than immediately throwing. Native snapshot is used only when required by target scope. |
| Target capture and cache selection | `managed-output-entry.swift:132-134`; `visual-recovery.swift:498-542`; `terminal-visual-state.swift:136-178` | Missing TTY/continuing owner, unavailable process inspection, stale owner/device/application, conflicting validated cached aliases, ambiguous native bindings or missing allowed scoped surface. `targetUnavailable`, `scopeUnavailable` and `vanished` become code 1. Ordinary unscoped targets do not invoke Ghostty catalogue simply to find their plain binding. |
| Pre-write validation | `visual-recovery.swift:130-155,592-598` | Allowed-surface membership and exact target validation must still hold. These failures precede `completeDeviceWrite`. Malformed operation/reset values throw `invalidRecord`. |
| Worker admission and first trust check | `ProcessRunner.swift:156-171,227-239` | Worker may start after its caller deadline. Lock URL must be file URL. Parent trust traversal can fail; runner translates it to `deviceIOFailed(EACCES)` unless the deadline is already exhausted. Caller semaphore expiration is `deviceWriteTimedOut` without reading unfinished result. |
| Before-open revision and intent publication | `visual-recovery.swift:158-179`; `terminal-visual-state.swift:622-639,714-756,966-1012` | Marker revision capture can fail storage trust/metadata. The per-TTY state lock can fail trust, open, metadata, bounded acquisition or deadline. Equivalence lookup/producer validation, observation/intent reads, JSON validation, synthetic correlation and atomic latest/bound writes can fail. Synthetic missing/mismatched delivery is stale code 3. A corrupt synthetic observation or other current record can produce `invalidRecord` code 1. Unavailable storage is code 1. This stage may have already committed some intent data when a later step fails. |
| Device admission/open | `ProcessRunner.swift:172-181,254-277` | Same physical device already admitted in this process gives EBUSY. Device open failure loses raw errno and is `deviceNotWritable`; late open completion closes the FD and throws timeout. Per-process in-flight admission is not a cross-process mutex and cannot itself explain a collision between separate helper processes. |
| Stable output lock | `ProcessRunner.swift:182-209` | Parent revalidation, wrong directory, lock open failure, wrong UID/type/mode or flock error becomes device IO failure. Busy flock retains the original deadline and can time out. The before-open publisher releases its state lock before device open; prepare reacquires the same stable per-TTY lock. |
| Opened-target/render preparation | `visual-recovery.swift:211-239` | Descriptor device and current owner must still match. Marker mismatch is normal nil suppression; marker storage/deadline error throws. Synthetic render context is revalidated. Target cache and equivalent-binding/effect reads/writes can fail storage/record/deadline. |
| Ordinary publication, policy and composition | `visual-recovery.swift:305-423`; `visual-restriction-policy.swift:20-140` | Repeated intent publication/binding, lock/mute rule trust/read, elapsed deadline, missing controller for hard/soft restriction, effect save/cancel, ordinary intent read, or unresolved safe focus styling can throw. Policy malformed content may simply produce nil; unsafe or unavailable rule metadata throws. Restriction marker unavailability disables restrictions, but revision capture has already rejected an unavailable marker for a render. Conflicting active selective leases throw staleEffect and code 3. |
| Physical bytes | `ProcessRunner.swift:210-215,279-332` | Preparation returning nil is successful `false` -> `unaffected`. Nonempty bytes face original deadline, partial-write retries, EINTR, EAGAIN/poll, zero write, terminal disconnect or poll errors. Device timeout is code 1. A partial write followed by failure must remain failure, not falsely claim full render. |

Internal state helpers translate trust exceptions to their own typed errors, so the outward error
category cannot always identify the exact syscall. No listed path is established as the cause by
the two logs. New lock-state mutation machinery from `e53697c` is not automatically implicated;
the managed renderer reads current lock state through `VisualRestrictionPolicy`, and no recorded
error indicates that read failed.

## Existing useful seams and coverage

No new production injection interface is required to test entry reporting:

- `ManagedOutputEntry.run` already injects recovery factory, identity lookup and render-input reader.
  Factory or input closures can throw each typed error to exercise the mapping and privacy.
- Entry tests own a PTY, identities, state and temporary marker/runtime. Existing cases cover malformed
  render/no private sentinel leakage, stale synthetic delivery, wrong ancestry/device, scoped binding,
  persisted suspension after factory failure, and no title replay.
- `SystemProcessRunner(openDevice:)` injects open errors/delays; `completeDeviceWrite` is directly
  testable. `process-runner-tests.swift` covers exact bytes/private stable lock, unsafe parent,
  delayed open, original deadline, busy lock, descriptor cleanup, independent healthy device,
  before-open failures, late prepublication, retained intent, and no worker amplification.
- `MockProcessRunner.managedBeforeOpenHandler` / managed handlers can interpose around publication
  and prepare. `visual-recovery-tests.swift` covers complete/style-only renders, recovery revisions,
  synthetic supersession, retained intent on open failure and fresh policy after queued work.
- State-store lookup, device, descriptor and readDescriptor closures test inspection and interrupted
  bounded reads without real sessions. No raw payload dump is needed.
- `background-intent.bats` has owned PTY scripts and snapshots but three failures do not print
  `$output` on status failure. Adding an existing pattern like case 4's status diagnostic at those
  assertions preserves evidence without changing success behavior or adding trace infrastructure.

## Smallest recommended source correction

Add one entry-local fixed stage enum and one pure allowlisted error-to-reason switch. Set the stage
before existing operations such as argument validation, context authentication, render input,
factory, target selection and render/write. On the existing non-persisted generic catch, retain
code 1, empty stdout and the generic line, then append only fixed tokens, for example:

`Managed output failure: stage=render reason=device-deadline.`

Suggested categories include `invalid-request`, `invalid-record`, `state-storage`, `state-lock`,
`state-target`, `state-deadline`, `marker-storage`, `marker-deadline`, `policy-unavailable`,
`policy-deadline`, `device-open`, `device-busy`, `device-io`, `device-deadline`, `target-unavailable`,
`scope-unavailable`, `target-vanished`, `focus-unavailable`, `input-unavailable`, and `unknown`.
Use enum matching; never `String(describing: error)`, localized descriptions, error userInfo or
interpolated path/title/token/payload/provider data. If numeric errno is retained, it should be an
explicitly bounded allowlist or a fixed category, not arbitrary error rendering.

Preserve the current code-3 stale branch and message unchanged. Preserve successful stdout tokens
and structured recovery reports. Do not add diagnostic output to success, mutate recovery state,
relax authentication, repaint on failure, retry writes or lengthen any deadline.

The entry-local stage is safe because only the caller sets/reads it. It distinguishes pre-write
failures from a render transaction but cannot prove whether a generic device timeout happened
while queued, publishing, opening, locking, preparing or writing. Say that explicitly. Avoid a
shared mutable transaction-stage variable: after timeout the worker may still run, making an
unsynchronized snapshot unsafe. Add finer transaction stages only if the first diagnostic result
shows a concrete need, using typed errors or existing completion synchronization.

Test the fixed mappings, unknown error fallback, distinct input/target/render stages, exact stale
contract, zero added bytes, and privacy sentinels through existing injected entry closures. Then
rebuild the source helper and run the four isolated cases together once with all failure output
preserved. If that fails, use the diagnosed stage/category to form the next targeted experiment.
Do not describe a later pass as attribution or erase the original four failures.

## Limits

This report establishes source reachability and an evidence gap. It does not prove load sensitivity,
filesystem trust violations, deadline exhaustion, process inspection intermittency, palette behavior
or visible native acceptance. Read-only memory guidance was used only to retain the boundary that
live PIDs, TTYs and app state are snapshot-specific; no historical runtime fact was adopted.


## Scoped source check of native diagnostics diff

Checked the current uncommitted `managed-output-entry.swift` and its entry-test diff against
`e53697c`, plus existing `MockProcessRunner` handlers and source error enums. No tests, compilation,
source changes or provider calls were performed. This is a source check, not provider approval.

### Findings

No confirmed material defect was found in the scoped diagnostic change.

- `Stage` is private and stores only fixed enum cases. The caller assigns it before the existing
  request/root, identity/context, input, factory, target and write operations. No worker callback
  captures or mutates it. The catch reads caller-local stage state after `render`/`write` returns or
  throws, so it does not inspect asynchronous mutable worker state following a timeout.
- `stage=write` correctly describes the entry call into `VisualRecovery`; it does not claim to
  distinguish before-open publication, device open, stable-lock wait, policy preparation or
  physical byte delivery. A `device-deadline` category therefore establishes the error class
  when observed, not the internal stage or root cause of elapsed budget.
- The typed category switch matches the current source enums. State record/storage/lock/target
  and deadline cases, marker storage/deadline, policy deadline/unavailability, recovery
  target/scope/policy/effect cases, and runner device errors have valid mappings. Process-only
  runner cases collapse to `process`; unrecognized errors collapse to `other`.
- The sole dynamic reason fragments are numeric errno fields. Device errno is restricted to
  `1...4095`, otherwise `device-io`; POSIXError prints the known `POSIXErrorCode.rawValue`. No
  path, payload, token, title, error domain, message, userInfo or localized description is
  interpolated. `deviceNotWritable` discards its associated path. No raw error formatting is
  introduced.
- Generic failures preserve code 1 and empty stdout; the generic text prefix remains with the
  fixed diagnostic added on the same stderr line. Existing code-3 stale catches and their exact
  stderr, successful tokens/classification, capability handling and unrelated-argument nil
  behavior are unchanged. No deadline, identity check, writer call, publication, retry or
  recovery mutation is changed by stage assignments/category formatting.
- After suspension persistence, the existing partial recovery report still has `stateSaved=true`,
  `catalogueAvailable=false` and a failed item. Only its fixed reason gains the diagnostic.
  Normal `recovery.apply` item reasons are unchanged, so this patch diagnoses top-level exceptions
  but does not add categories to per-target fanout failures. That is an honest scope limitation.

### Tests examined

`testInputFailureReportsFixedStageWithoutExceptionDetails` injects an NSError through the existing
render-input seam, checks exact `stage=input failure=other`, code 1/empty stdout, zero factory
calls and zero PTY bytes. Its private domain and description are omitted because the error is
classified, never rendered. `testDeviceFailureReportsStageAndBoundedCodeWithoutItsPrivatePath`
uses the existing `managedBeforeOpenHandler`, throws EIO with a private associated path, and
checks exact `stage=write failure=device-io-5`, code 1/empty stdout and zero PTY bytes. The mock
handler throws before invoking publication/prepare; it tests reporting without pretending to
simulate a physical syscall. Existing factory-failure coverage now checks the exact fixed
`stage=setup failure=target` reason while retaining the persisted marker and partial-report checks.

The new tests cover two representative privacy/stage paths, while existing source tests cover
stale and success contracts. Other category mappings, numeric out-of-range fallback and
`device-deadline` are source-verified but do not receive new dedicated cases in this diff. There
is no evidence in this source check that the historical four Bats failures were timeouts. Preserve
those failures and use the rebuilt helper's next diagnostic output to choose further investigation.


## Shell/portable investigation and source check

# Shell and portable background-delivery source diagnosis

Last Updated: 2026-10-14
Version: 1.0

Repository: `/Users/cs/local/code/apps/terminal-agent-visual-signals`
Baseline: `e53697c`; initial worktree clean.
Scope: read-only source and retained-log inspection. No tests, native actions, helper executions,
or source modifications were performed. This is a source diagnosis, not independent approval.

## Established contracts

- SPEC lines 154-163 separate meaningful observations from ordinary background intent. Synthetic
  idle paints retain the existing delivery; they must not create or replace an observation.
- SPEC lines 263-271 require shared per-TTY serialization and the original 100 ms device caller
  deadline across open, lock acquisition and write. Longer fixture waits do not relax this bound.
- Shell chooses one native/portable backend before intake, carries it through a hook, and does
  not switch backend when an operation fails (`helper-selection.sh`).
- `_tavs_render_flush()` accepts native outcomes `rendered`, `restricted`, or `unaffected` only
  with status 0. Status 3 denotes stale record/context; `send_osc_bg()` deliberately consumes it
  as a harmless obsolete update. Generic status 1 remains a failure
  (`organizer-state.sh:160-189`, `terminal-osc-sequences.sh:84-91`).
- `_tavs_organizer_begin()` has compatibility-oriented status handling: context/observation
  failure can print a diagnostic or return success without publication. A test that calls it
  needs to check context and resulting records separately (`organizer-state.sh:63-74`).
- Before-open publication is intentional. Both renderers can retain the requested background
  even if later device preparation/open/write fails. Intent existence does not prove delivery
  (`portable_renderer.py:175-198`, `visual-recovery.swift:159-185`).
- Portable dispatch keeps stale record errors at code 3 and generic target/policy/I/O failures
  at code 1. It intentionally does not expose exception strings, paths, context, or payload
  (`portable_helper.py:156-159`, `test_portable_helper.py:162-177`).

## What the retained evidence proves

`tavs-isolated.i5itEP/command.log` contains 54 combined Bats cases and four failures:

| Case | Failing assertion | Current evidence |
| --- | --- | --- |
| 38 native ordinary providers | `background-intent.bats:116` | Owned child returned nonzero; its captured output was not printed. Provider and operation stage unknown. |
| 39 portable ordinary providers | same helper assertion | Same attribution gap. Backend selection is asserted before the first paint, but the log does not identify whether it failed there. |
| 42 standalone muted reset | `background-intent.bats:173` | Owned child returned nonzero; captured helper output was not printed. |
| 45 owned synthetic PTY | `background-intent.bats:314` | PTY child returned nonzero after at least one `#112233` OSC. Output includes generic `Managed output unavailable` and `tavs: current render unavailable`. |

The four-case `dQrEwk/command.log` is entirely passing. This proves the separated control's
result only. It does not prove load, elapsed deadlines, cleanup, scheduling order, or any other
cause for the earlier failures. The original failures must stay unresolved.

A scoped `rg --files --hidden` inventory of `i5itEP` finds the wrapper log and owned regular-file
TTY fixtures, but no per-case organizer records or worker logs. Bats cleans its nested run
directory by default; `tests/run-isolated.sh` retains its outer root only. The historical record
contents and exact failed call cannot now be recovered from that root.

For case45 the source sequence has an initial `#112233` paint, then synthetic `#445566`, then
worker `#AABBCC`, then a newer `#778899` paint and stale checks. The short captured output is
consistent with failure in an early synthetic render. Without fixed stage/status evidence it
does not prove that exact call or establish whether before-open intent had already committed.

## Source findings

### Confirmed diagnosis/acceptance gaps

1. Three failed status assertions omit `$output`; the fourth prints it but still lacks an
   operation label. `--print-output-on-failure` uses Bats' existing output seam and is preferable
   to accepting a retry as success.
2. Worker assertions watch the published intent color, not the writer outcome or worker color
   bytes. In the provider case, the final output check looks for the preceding synchronous
   `#AABBCC`; the worker's expected `#CCBBDD` bytes are not asserted. Publication-before-open
   permits the worker intent check to pass when its physical delivery failed. The current owned
   synthetic case similarly checks worker intent but never verifies its `#AABBCC` bytes.
3. Generic dispatch diagnostics collapse many private failures. Portable writer already
   retains numeric `errno`, `bytes_written` and stale classification internally, but portable
   helper drops those fields at its public boundary. A log containing only "unavailable" cannot
   distinguish render-input validation, policy, ownership, record, device, or completion stages.

### Timer cleanup does not currently establish a defect

The provider and owned synthetic tests explicitly start one worker in a subshell with `set +e`
and stop/wait for that owned PID. `unified_timer_worker()` installs TERM/INT handling returning
0, preserves its inherited delivery context, exits harmlessly on stale status3, and advances
`last_applied_stage` only after status0 (`idle-worker-background.sh:70-91,179-182`). Generic
failure leaves the stage pending for a later tick. These tests do not invoke
`cleanup_stale_timers()` during the affected worker section. Source does not justify blaming
that broader pgrep cleanup function for the recorded combined failures.

Portable policy validates current marker content/revision and lock/mute values under bounded
reads; malformed/current native rules and ownership conflicts may reject ordinary pixels while
retaining intent. This is explicit limited portable behavior, not a new fallback to bypass.
The combined cases use private HOME/runtime paths, and source inspection found no definite
installed-home policy leak explaining these failures.

No production defect explaining all four failures is confirmed by this read-only inspection.

### Separate deadline source concern, not historical attribution

The portable writer parent computes remaining wait from its original 100 ms deadline, then
parses a ready result and returns without another parent-side deadline check
(`portable_device_writer.py:147-158`). A deterministic parent-result seam test should establish
whether a ready reply processed after deadline can report success. The existing after-output
expiry test injects the child callback, which covers a different location. This concern cannot
explain the logged code1 failures and should not be presented as their cause. Keep failures
honest even if bytes were already written.

## Minimal diagnostic improvement

Recommended first slice uses the current fixtures and helper-call seams:

1. Preserve the next diagnostic Bats run with `--no-tempdir-cleanup` and enable
   `--print-output-on-failure`. Both flags are present in installed Bats1.14.0
   (`/opt/homebrew/Cellar/bats-core/1.14.0/libexec/bats-core/bats:69,80`).
2. Add fixed fixture labels before backend selection, initial render, synthetic render, worker
   start/expected-color check, worker stop/wait, newer render, and stale checks. On failure emit
   only label, provider enum, backend enum and exit status. Do not emit command text, `$@`,
   delivery context, observation JSON, arbitrary environment or input. Use Bash3.2-compatible
   explicit result checks or an ERR trap with `set -E`; ensure cleanup retains the original
   failing status and reports worker kill/wait separately.
3. In a private test helper proxy or `_tavs_helper_call()` test override, record only verb enum,
   returned status, and recognized finite outcome to a private file, forwarding exact stdout,
   stderr, stdin and status. Do not log arguments. This identifies dispatch failure versus a
   status0 `unaffected` result. The writer's deadline stays unchanged inside the real helper.
4. Assert the worker's expected color bytes separately from the existing intent and unchanged
   observation checks. Record worker flush success, not merely `grep` of persisted intent.
5. Only if status1 is reproduced and still ambiguous, add the smallest typed stage plus numeric
   errno/written-byte diagnostic using the existing native/portable result seam. Never expose
   raw exception strings, and do not retry the failed action as a success substitute.

## Safe focused commands for the parent

These commands are recommendations, not executed here. Set `TAVS_TEST_HELPER_BIN` to the
existing explicit source-built release helper verified by the parent; do not select installed
`/Applications/TAVS.app`.

```bash
tests/run-isolated.sh bats --no-tempdir-cleanup --print-output-on-failure \
  --filter 'ordinary provider synthetic|standalone muted|owned PTY synthetic colors' \
  tests/integration/background-intent.bats
```

Run the focused control once after adding diagnostics, then one combined diagnostic run with
the original files/order if needed to reproduce context. Preserve both outputs; a passing
combined result still does not causally explain `i5itEP`.

```bash
tests/run-isolated.sh python3 -m unittest discover -s tests/unit \
  -p 'test_portable_device_writer.py'
tests/run-isolated.sh python3 -m unittest discover -s tests/unit \
  -p 'test_portable_helper.py'
tests/run-isolated.sh python3 -m unittest discover -s tests/unit \
  -p 'test_portable_renderer.py'
```

Unit additions should use the existing `unittest.mock.patch` seams for input failures,
generic target ESTALE versus stale-record errors, device errno/partial byte reports and metadata
completion failure. Native source-built helper tests and owned PTY checks remain necessary;
none establish Ghostty pane/Space/readability acceptance while native access is denied.

## Boundaries and context

No source/test edits or verification runs were made. Reports contain no hook payloads, context
tokens or user session inventory. Memory registry lines748-749 were used only to retain the
user's terminal-session boundaries; actual repository and logs were inspected afresh.

<oai-mem-citation>
<citation_entries>
MEMORY.md:748-749|note=[Retained runtime and terminal-session boundaries]
</citation_entries>
<rollout_ids>
01a100cb-205c-7840-8268-c3d4ab1f7849
</rollout_ids>
</oai-mem-citation>

## Follow-up source check of diagnostic and worker-oracle diff

Checked the uncommitted diff of `src/core/portable_helper.py`,
`tests/unit/test_portable_helper.py` and `tests/integration/background-intent.bats` on 2026-10-14.
No tests or source edits were performed. This check supplies no provider score or approval.

### Managed diagnostics and privacy

The portable helper stage is assigned only from fixed literals: request, roots, identity,
context, input, setup and write. Error families use a fixed label set; OSError emits its errno
only when it is exactly an integer in1...4095. Exception text, filename, arguments, context,
payload and subclass name are not interpolated. The custom `BODY_SENTINEL` ValueError subclass
test addresses both private class names and messages. The input failure test uses the existing
read-input seam and proves the code1 path remains empty stdout with a fixed diagnostic.

The success return, organizer error text, and code3 stale handler precede or remain outside the
new generic diagnostic path. Generic target ESTALE still returns code1, distinct from stale
record code3. No deadline or native/portable selection change appears in this diff. Returning
the original typed outcome with an added fixed diagnostic on code1 is a narrow observable API
change; existing documentation should identify it.

### Stream forwarding and worker oracle

The worker override calls `_tavs_helper_select()` then the same selected `_TAVS_HELPER_BIN`.
It introduces no fallback, alternate helper, runtime root, or native property access. Only the
worker subshell sources the override. Parent calls keep the production function.

The real helper receives the original `"$@"` and inherited payload-pipe stdin. Its stderr flows
to the existing private worker log; helper stdout is captured, then returned to the outer
flush's stdout pipe. Command substitution removes trailing newlines, and the wrapper adds one
newline. This is not byte-exact forwarding for arbitrary output, but it preserves the actual
finite helper-token contract because the surrounding production flush already captures and
strips trailing newlines. The wrapper emits only numeric returned status and one recognized
finite outcome to its own diagnostic line. It does not log arguments or arbitrary response
content. Capturing helper stdout does not intercept OSC bytes written directly to the PTY.

The worker runs with `set +e`; status is saved directly after the helper command, the wrapper
returns that status, and the normal `_tavs_render_flush()` handles success/stale/failure. The
extra log line is emitted after the selected helper returns. Checking status0/rendered plus
the correct intent now excludes a mere before-open publication from satisfying the worker
condition. The explicit `#CCBBDD` provider PTY check and `#AABBCC` owned-PTY check add physical
byte evidence. These colors do not appear in current production core/config/theme files, and
are distinct from the other explicit colors in these respective fixtures. This oracle does
not substitute for Ghostty's visible acceptance.

The original 40 iterations at50ms and the15s owned-child guard remain; production device100ms
is unchanged. A TERM can arrive after the wrapper records rendered but before the outer flush
finishes its bookkeeping. That does not invalidate the physical-output assertion because the
real helper has already returned and its bytes are separately observed. Cleanup targets only
the owned worker PID, not pgrep or existing user processes. The EXIT trap's kill/wait cleanup
does not explicitly replace the original failing exit status.

### One diagnostic issue to correct

Both generated fixtures currently use only `set -e` with an ERR trap. ERR is not inherited in
shell functions by default. Consequently, an errexit inside `send_osc_bg()` or its helper
functions can exit before the top-level fixed fixture label is printed. This directly affects
the previously missing initial/synthetic failure attribution, rather than only an unlikely
edge case. The installed Bash manual states the inheritance rule at
`/opt/homebrew/Cellar/bash/5.3.15/share/info/bash.info:1374-1375,5088-5092`.

Use Bash3.2-compatible `set -eE` in the two generated parent fixtures, or explicit nonzero
checks around the relevant helper functions that print the fixed stage and saved status then
exit with it. Keep worker `set +e`; ERR diagnostics there must remain observation only. No
production rewrite or deadline increase is needed. This concern was sent to the parent.

No additional confirmed production/privacy/isolation defect was found in this scoped diff.
The broad write stage intentionally does not yet distinguish policy versus ownership versus
device internals. A reproduced stage=write/errno failure can justify a further minimal seam
diagnostic; the historical four failures remain unattributed.

### Resolution of ERR inheritance concern

Final read-only inspection confirms both affected generated fixture headers now use `set -eE`:
the ordinary-provider script and the owned synthetic PTY script. Both worker subshells still
explicitly run `set +e` before sourcing the unchanged worker capture override. The override
still selects the real helper, saves its returned status, logs only the finite worker outcome,
forwards the response to the normal flush, and returns the saved status.

The parent reports an additional `/bin/bash` probe printed status7 and exited7 with an inherited
ERR trap. This subagent did not run or independently inspect that probe; its own resolution is
based on the current headers and the documented inheritance rule. The earlier concern is
resolved in source. No additional source defect appeared in this final narrow read. Earlier
failure evidence remains recorded above; no test run or provider approval was supplied here.


## Parent implementation and verification

Native and portable managed code1 errors gain fixed caller-stage and allowlisted category
labels. Numeric OS/device codes are bounded; no raw error/message/path/classname is rendered.
Code3 stale, successful tokens, organizer errors, capabilities and write/publication/deadline
behavior remain. Persisted native suspension failures retain the partial report and gain a
fixed diagnostic reason. Stages are caller-local, not asynchronously read worker state; write
includes publication/metadata/locking/bytes and cannot identify a physical substage by itself.

The worker fixture records real selected-helper status and finite render outcome, forwards
non-render operations directly to preserve binary/NUL stdout, waits for returned rendered plus
intent, and requires actual worker color bytes. Existing40*50ms and device100ms bounds remain.
ERR inheritance was verified by a /bin/bash probe (status7/exit7) and enabled in affected
fixtures. These labels can also appear for handled internal nonzero returns; only the retained
terminal exit/assertion proves test failure. No command/argument/context dump was introduced.

Exact isolated logs use /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.RUN/command.log:

- wniVjg: native RED3/3 assertions,0.148s; input/write/partial-report diagnostics absent.
- B0xcbx: Python RED3/2 failures; new managed input/write cases lacked stage/category.
- iUs2Fe: native entry23/23,0.371s; k6QV3G: portable helper23/23,3.564s.
- AuKEaV: full660/660 Swift,24.622s;7RdjRh:177/177 portable Python,13.716s.
- 7AlPOG: source release53.84s on owned external scratch.
- FMZyFj: rebuilt-helper focused4/4 with physical worker assertions. Three retained worker
  logs each have status0/outcome rendered. Bats kept its per-case records and scripts.
- gWpd4z: combined54 cases,1 failure (53 pass). The previously failing native/portable provider
  and standalone cases pass. Case45 emits #112233/#445566/#AABBCC/#778899 and records worker
  rendered; a later delayed tool-error check fails Python line7 (intent timestamp >observed+1).
  Same delivery is retained; observedAt1792000739.0828872, intent.updatedAt1792000739.39995,
  delta0.3170628548, color#4A2A1F. This proves the sampled restore was missing, not its cause.
- iaRBfu: that one-case control passes after stricter non-render forwarding and additional
  tool-error/check labels. This does not attribute gWpd4z or the historical i5itEP failures.
- 2eDDNU: final four-case control3/4; the owned synthetic case fails earlier at the newer
  permission render, after #112233/#445566/#AABBCC. Its new diagnostic is stage=write,
  failure=device-deadline. This establishes the native 100ms caller transaction expired,
  not whether queue/publication/open/lock/prepare/bytes consumed it. No #778899 is delivered
  before that failure. All three other control cases pass. Files remain in bats-run-ccevZc.

Bats directories are printed as BATS_RUN_TMPDIR in retained logs. gWpd4z keeps test/45's
script, worker log and records beneath tmp/bats-run-lDYmiz; FMZyFj uses bats-run-VLQYQg and
iaRBfu uses bats-run-lhZDK0. Runtime/prefs/TTYs remain private; no installed app/state changed.
No unchanged combined run erased a failure and no source deadline was widened.

Scope:2 production/3 test files plus existing docs and this durable report. Two new Swift and
two Python cases verify input/write reporting and privacy; existing partial-report assertions
are strengthened. Earlier broad failures retain their independent circumstances and must not
be merged into one asserted cause. Current combined failure concerns a later timestamp check,
where production's asynchronous restore redirects its output. Its timer/context/helper stage
needs a focused observation. The final native transaction deadline now also has direct
error-class evidence and needs synchronized or typed internal-stage investigation. A source concern about portable parent parsing a ready result
without rechecking the original deadline also needs its own deterministic test; it is not
historical timeout attribution. Native/Linux/headless/palette and final review limits remain.

Documentation footprint check since goal baseline e113fb8: tracked gross additions are8842
production lines and34926 process-document lines (3.95:1), excluding tests/product reference
files and this previously untracked report. The review checks produced the missing physical
worker oracle and ERR-inheritance correction here; earlier checks produced the accepted lock
snapshot and color validation corrections. No new process instruction or control plane was added.
SPEC/PLAN bodies remain fixed; Phase9 and the full goal remain active/incomplete.
