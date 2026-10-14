# Shared helper routing source checks

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

## Parent disposition

Source implementation is `4afb1ed`. The original source report and separate R1 recheck below
are preserved unchanged. R1 was confirmed against the cache export/import branches and red
copied-adapter regression gfkBci before correction. Existing intake `0` now retains the failed
selected attempt without successful context authority. Latest combined aNJgoa passes 106/106
shell tests; SSQ5YN passes 172 portable tests; fZwwDH passes 561 Swift tests. The Swift source
is unchanged by this shell-only correction. Bash/zsh syntax and staged diff checks pass.

The original checker used an incompatible workspace release binary for two connected checks.
Its known-capability queries explain those native-dependent expectation failures. Parent checks
and R1 recheck used `/tmp/tavs-focus-leases-84v8mqbc/build/arm64-apple-macosx/release/TAVSApp`.
No source defect was inferred from the stale binary. The follow-up approves only R1/cache scope;
its eight focused cases and 24 native/portable Bash/zsh hint combinations pass. Physical Ghostty,
standalone shell delivery and Linux remain pending, as recorded in PROGRESS.

## Original report

# Review Report

## Metadata

- **reviewer**: Codex delegated source checker. Exact runtime model variant unverified.
- **review_type**: code
- **review_mode**: coaching
- **tier**: standard, bounded to shared selection and the core bridge
- **date**: 2026-10-14
- **target**: Current uncommitted `src/core/helper-selection.sh`,
  `src/core/organizer-state.sh`, `src/cli/cmd-sync.sh`, their adapter callers and connected tests.
- **scope**: Read-only repository review. Temporary fixtures and test output only. No source edits,
  installation, real-home commands, production helper invocation or live native/UI acceptance.

## Rubric Scores

| Dimension | Score | Evidence |
|-----------|-------|----------|
| correctness | 6 | Normal selection and dispatch are correct; failed intake loses selection across exec. |
| security | 8 | Candidate validation, private unexporting and dedicated native-scope handling are explicit. |
| maintainability | 8 | Existing organizer and render bridge use one small selection module. |
| test_coverage | 7 | Strong successful paths, scope checks and PTY test; failed-intake test misses actual core selection. |
| completeness | 6 | This slice misses its no-reselection failure invariant; standalone/Linux/native acceptance is separate. |

## Verdict

**verdict**: CONCERN
**confidence**: high for the failure-path finding and source invariants; limited for native runtime checks
because the available workspace release binary does not implement the current capability verbs.

## Findings

### [R1] HIGH: Failed intake discards the selected backend at the adapter exec boundary

- **Situation**: `src/core/organizer-state.sh:48-56` exports the private selection cache only if
  intake produced both the success marker and a nonempty context. `src/agents/claude/trigger.sh:28-33`
  and `src/agents/codex/trigger.sh:28-30` continue into core even when intake fails.
  `src/core/helper-selection.sh:27-30` also accepts an imported cache only with a successful
  organizer intake/context hint.
- **Behavior**: A native helper can pass both capability checks, fail the selected intake operation,
  and then be probed again by the core process. If its capabilities are now unavailable, core
  selects portable and generates a new portable context. The original body is not reparsed, but
  the helper choice is replaced after an operation failure. Even a stable failing helper receives
  a redundant capability pair in core because no selection was transported.
- **Impact**: The slice does not satisfy one selection before intake across exec, or the stated
  requirement that a selected operation failure never changes backend. The behavior is also
  reachable when a chosen portable intake fails and native support appears before core selection.
- **Suggestion**: Transport the completed selection independently of successful metadata/context,
  preserve the selected result on failed intake, and make core consume then unexport that result.
  Keep organizer context authority separate from the selection handoff. Add a copied-adapter test
  whose core sources the real bridge, and whose selected intake fails before helper availability
  changes. Assert one capability pair, no alternate helper operation and no private cache in later
  children. No new backend abstraction is needed.

### Reproduction evidence

Owned fixture: `/tmp/tavs-helper-review-1014-pwkpjyy4`.
It copies the actual Claude adapter, organizer bridge and shared selector. Only helper operations
and the final core entry are stubbed; all paths/home/runtime are inside the owned temporary root.
The native stub returns both exact capability lines, consumes intake, marks itself unsupported,
and exits 1. Core sources the actual bridge and invokes `_tavs_organizer_helper` then begin.

Observed adapter exit: 0. Observed core output: `core backend=portable`.
Observed stderr: `tavs: organizer metadata unavailable`.
Call order:

```text
native:--validate-config:--organizer-capabilities
native:--validate-config:--managed-output-capabilities
native:--organizer-intake:claude
native:--validate-config:--organizer-capabilities
native:--validate-config:--managed-output-capabilities
portable:--validate-config:--portable-ordinary-capabilities
portable:--organizer-context:claude
portable:--organizer-observe:<owned temporary tty>
```

The existing integration case at `tests/integration/hook-observations.bats:400` correctly checks
that failed native intake is not reparsed. Its normal fixture core only captures environment and
stdin; it does not source organizer-state or select a helper. It therefore cannot detect R1.

## Invariant checks

| Requested invariant | Result and evidence |
|---------------------|---------------------|
| Native needs both exact capabilities | Satisfied. `helper-selection.sh:42-49` checks each exit status and compares both results. Organizer-only, managed-only and unsupported stubs select portable. |
| Selection precedes intake | Satisfied within adapter. `organizer-state.sh:25-40` clears inherited state then selects in the parent shell before process-substitution intake. |
| Selection survives exec privately | Satisfied after successful intake. Cache is exported at intake then validated and unexported by the core source. Failed intake is R1. |
| Operations never choose another backend or reparse | Satisfied inside one shell and on successful handoff. `_tavs_helper_call` returns the selected executable status and cached selection is never cleared by render failure. Failed handoff is R1. |
| Native probe/organizer scope sanitized | Satisfied. Both probes and `_tavs_organizer_call` remove the three native test-scope keys. |
| Managed and all portable calls retain scope | Satisfied. Managed calls use `_tavs_helper_call`; portable capability, organizer and managed operations keep the environment. Empty scope-key presence is rejected by portable helper. |
| Copied modules independent | Satisfied for ordinary support. `cmd-sync.sh:109-117` copies selector, all Python imports and executable entry; copied capability/intake checks passed for both plugin targets. |
| Recovery remains native-only | Satisfied by source. `cmd-recover.sh:36-54` chooses the explicit/default native candidate, validates native managed capability and invokes `--visual-recover` directly. Portable rejects recovery/native capability verbs. |
| Bash 3.2 and zsh shared source/cache | Satisfied for shared selector. Runtime Bats covered both shells, selection, cached failures, imports and private exports. Core bridge/adapters are Bash entry points. |
| Spaces and canonical aliases | Satisfied for an adapter-produced canonical cache. Explicit symlink-directory fixture with spaces imported the physical portable path in both shells without another probe. |

## Forced falsification

1. Partial native capability could accidentally win: disproved by the conjunction and both-shell tests.
2. Portable scope could be silently stripped through organizer dispatch: disproved by branch structure,
   empty-key refusal tests and the added post-selection scope case.
3. A canonical alias could cause another portable probe on successful handoff: disproved by the owned
   alias fixture. An initial manually fabricated `/tmp` cache used the wrong noncanonical path and was
   correctly rejected; repeating with the physical path produced no probes.
4. Private cache could leak into later children: disproved by `typeset +x` and environment assertions.
5. Failed intake could preserve the original choice across exec: falsified by R1's owned adapter run.

## Verification

All suites used `tests/run-isolated.sh` with a source-tree release helper explicitly selected by path.
No `tavs sync` or recovery was run against real home. The wrapper creates private home, runtime,
state and test roots. Fixtures were retained for inspection.

| Check | Result | Full output |
|-------|--------|-------------|
| `bats tests/unit/helper-selection.bats` | 9/9 passed | `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.9zdJqm/command.log` |
| `python3 -m unittest discover -s tests/unit -p test_portable_helper.py` | 20/20 passed, including owned hook PTY | `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.siZW7v/command.log` |
| `bats tests/unit/cmd-sync.bats` | 11/12 passed; native-recovery output expectation failed with incompatible release binary | `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.QHTU9e/command.log` |
| `bats tests/integration/hook-observations.bats` | 23/24 passed; native-cache candidate expectation failed with incompatible release binary | `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.bt71cA/command.log` |
| Available release binary capability check | Both verbs exit 1 and are treated as missing config filenames | `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.2RkGFB/command.log` |
| Bash syntax for three scoped modules; zsh syntax for shared selector | Passed | Direct syntax checks |
| Canonical portable cache through alias path in both shells | Exit 0, zero probes, no exported private selection variables | `/tmp/tavs-helper-canonical-review-1014-47f0ae1i` |
| Failed-intake actual copied-adapter reproduction | Confirms backend replacement | `/tmp/tavs-helper-review-1014-pwkpjyy4` |

The workspace binary was not rebuilt during this read-only review. Its incompatible responses are
not evidence that current native source lacks capability support. The source handlers in
`organizer-intake.swift:72-77` and `managed-output-entry.swift:26` explicitly implement those verbs.

## Pending acceptance versus source bugs

- Standalone shellrc still selects a native managed helper directly. Wiring its installed,
  standalone Bash/zsh path to portable support is subsequent routing work, not a defect introduced
  by this shared-selection/core-bridge slice.
- Portable helper intentionally rejects non-Darwin requests. Actual Linux support/acceptance is not
  supplied by this slice and cannot be inferred from platform-mocked tests.
- Current SPEC-owned progress retains incomplete native acceptance for phases 2, 7 and 8 and the
  active/incomplete phase 9 goal. Owned PTY bytes establish only the requested local ordinary hook
  behavior. They do not establish live Ghostty pixels, native pane/Space navigation or focus/recovery
  product acceptance.
- No installed application, native GUI or live terminal acceptance was attempted here.

## Summary

The shared selector correctly centralizes native-versus-portable capability choice and preserves
the intended scope boundaries. The successful adapter path, copied module capability, private
cache and owned ordinary hook render have direct passing evidence. Fix R1 before claiming the
selection also remains fixed after intake failure. Native-dependent test expectations need a
current source-built helper rerun; the available release binary is incompatible.

## Capture note for the parent session

The parent owns the repository meta-thinking capture. Read-only task scope prevents appending a
separate session entry to `META-THINKING-CAPTURE.md`. This note supplies observed events for that
session capture, without changing project files. Exact runtime model variant is unverified.

[O] Source inspection isolated cache export to successful intake. A copied-adapter fixture then
made native support disappear after intake failure and observed core select portable. Passing
shared-selector tests did not cover this adapter failure boundary. [O] A manually supplied alias
cache initially failed because `/tmp` differed from the selector's physical `/private/tmp` path;
using the actual canonical cache passed in Bash and zsh with no probe. [O] Two connected test
expectations failed with the available release helper; direct capability checks showed the binary
was incompatible, so those failures were not classified as source defects. [R] The useful review
heuristic is to exercise the entire process boundary and verify the actual test helper contract
before attributing a suite failure to current source.

Memory was used only for orientation about live runtime sensitivity and locating SPEC-owned
state. Current progress/source supplied all status conclusions; no historical runtime snapshot was
used as current evidence.

## Separate R1 recheck

# Review Report

## Metadata

- **reviewer**: Codex delegated source checker. Exact runtime model variant unverified.
- **review_type**: code
- **review_mode**: coaching
- **tier**: standard, limited to R1 and cache semantics
- **date**: 2026-10-14
- **target**: Latest `src/core/helper-selection.sh:19-39`,
  `src/core/organizer-state.sh:21-60`, and focused helper/adapter cache regressions.
- **scope**: Read-only recheck. No broad suites, source changes, app/VM operations, installation,
  real-home commands or native/UI acceptance. Earlier report remains unchanged.

## Rubric Scores

| Dimension | Score | Evidence |
|-----------|-------|----------|
| correctness | 8 | Failed selected intake transports the same backend; invalid hint pairs trigger fresh selection. |
| security | 8 | Candidate match/executable checks remain; core removes private export attributes. |
| maintainability | 8 | Existing intake flag distinguishes success and failure without another transport mechanism. |
| test_coverage | 8 | Original failure scenario, no-reparse behavior, import privacy and both-shell hint cases pass. |
| completeness | 8 | R1 is fixed in the requested selected-intake/cache scope; wider acceptance remains outside this recheck. |

## Verdict

**verdict**: APPROVE
**confidence**: high for this bounded R1/cache recheck.

## Findings

No new source defects found in the requested scope. R1 from the earlier source report is resolved.
This verdict covers the correction only, not complete standalone routing, Linux support or native
product acceptance.

## Source verification

`organizer-state.sh:25-27` clears inherited context/intake/cache before selecting. On failed selected
intake, lines 53-55 export the selected cache and `TAVS_ORGANIZER_INTAKE=0`; they do not export a
successful context. The function still returns failure and preserves its existing unavailable
metadata diagnostic.

`helper-selection.sh:27-35` imports a matching selected cache for either of two pairs:

- `INTAKE=1` with nonempty context: successful intake.
- `INTAKE=0` with empty/absent context: selected intake completed unsuccessfully.

Other hint/context combinations are rejected. Native and portable candidate checks remain exact,
and the imported candidate must be executable. Line 39 removes the three private cache variables'
export attributes, preserving the choice in the current core shell while excluding it from later
child environments. Subsequent organizer/managed calls reuse that selection. Generating context
with the same selected helper after failed intake does not reparse the consumed hook input or
choose another backend.

The new regression at `tests/integration/hook-observations.bats:434` uses the actual copied adapter,
shared selector and organizer bridge. Native capability support disappears after the selected
intake fails. Core then uses the original native helper for context/observation and a failing
managed render. The assertions require exactly two original native capability invocations, no
portable calls, a reached native managed render and no private cache exports. It passes.

The existing no-reparse regression now correctly expects absent context plus `INTAKE=0` after the
failed selected operation. The helper-selection import regression covers successful and failed
native intake hints in Bash and zsh, including child export exclusion.

## Focused verification

Every runner call used the explicitly supplied current source-built helper:

`/tmp/tavs-focus-leases-84v8mqbc/build/arm64-apple-macosx/release/TAVSApp`

The workspace `.build` binary was not used.

Eight focused Bats cases passed, selected by this filter across helper-selection and
hook-observations:

```text
selected operation failure|imported cache requires|valid adapter intake|portable adapter choice|
Failed native intake|failed selected intake|core rejects an imported capability cache|
adapter intake ignores forged
```

Full output:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.n67mYH/command.log`

An additional owned fixture matrix exercised 24 combinations: native/portable caches, Bash 3.2/zsh,
and six hint/context pairs. Both accepted pairs produced zero probes. Missing, inconsistent and
unsupported hints triggered the expected capability rechecks. Every case verified that private
selection variables were absent from child environment output. All 24 passed.

Matrix script: `/tmp/explorer-tavs-r1-cache-matrix-20261014.py`
Full output:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.LtQ8fV/command.log`
Owned matrix fixture:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.LtQ8fV/r1-cache-matrix-ptvfxshj`

Bash syntax checks passed for the selector and organizer bridge; zsh syntax passed for the selector.

## Forced falsification

1. Failure marker could import stale successful context: disproved. `0` plus nonempty context is
   rejected in source and in both-shell native/portable matrix cases.
2. Missing hint could import an inherited selection: disproved by focused Bats and matrix cases.
3. Failed portable intake could lose its matching import: disproved by the portable `0`/no-context
   cases in both shells, which made no capability calls.
4. Core could retain export attributes after failed handoff: disproved by failed-native adapter
   regression and every matrix case.
5. Original native capability disappearance could still select portable: disproved by the new
   copied-adapter regression's count, backend and call-log assertions.

## Summary

R1 is resolved. Failed selected intake preserves the chosen helper across adapter exec without
claiming successful metadata context, and core consumes the cache privately. Eight focused
regressions and 24 Bash/zsh cache cases passed. No broader runtime or acceptance claim is made.

## Capture note for the parent session

[O] Source inspection verified the existing flag now carries selected intake failure separately
from context success. Focused Bats reproduced capability disappearance and kept native selection.
[O] An initial inline Python matrix did not execute because the isolated runner intentionally
redirects command stdin from `/dev/null`. The check was rerun from a temporary script and all
24 cases executed and passed. The empty initial runner log was not counted as test evidence.
[R] Use a script path rather than stdin when verifying through a runner that clears stdin.
The parent owns the repository session capture; this recheck made no project capture-file edit.
