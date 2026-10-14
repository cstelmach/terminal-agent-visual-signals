# Portable capability, delivery and pending routing

Last Updated: 2026-10-14 (Europe/Vienna)
Version: 1.0

Source: `039ae69`. Reports below are source-only, separate from executed verification.

## Parent checks and next boundary

The distinct portable query requires exactly three arguments, macOS, no native test-scope key
and current process inspection. It creates no marker/runtime and consumes no stdin. It does not
return native managed/organizer capability markers or claim focus/recovery/Linux support.
Sync now copies the full 13-file import closure and sets the entry executable. Source check
found no concrete defect in this narrow boundary. Current sync readiness still probes native;
hook selection and installed shellrc resources are not yet portable and H1 is incomplete.

Initial aX0rJK failed the absent capability; S6UNQd failed the absent copied helper. OVYlz3 passed
19 focused helper checks; NeR0ok passed 12 sync cases. Final KclsSP passed 171/171 portable in
8.086 seconds. H3yns9 passed 561/561 Swift in 19.183 seconds; agiDyg passed 35/35 sync/hook Bats.
Changed shell/Python syntax, staging, .env/secrets and whitespace passed. Both copied plugin
helpers probe independently; state sentinels preserve preferences, schedules and runtime locks.
All copies used private fake installations. No real installation, app/VM/container or existing
session was changed. These are copy/query checks, not physical Ghostty acceptance.

Current routing recon identifies four selectors and adapter cache transfer. Next: one small
Bash/zsh selector, native both-schema preference for ordinary operations, distinct portable
selection only for absent/unsupported native, no change after selected-operation failure and
native-only recovery. Keep operation-specific scope handling and exact cache import validation.
Standalone shellrc must receive resources independent of checkout location. Preserve missing
Python/module and partial native capability states explicitly. Linux and physical acceptance,
historical failure attribution and configured-color freshness remain pending.

## Source routing recon (historical pre-change observations)

# TAVS helper routing and packaging recon

Date: 2026-10-14
Repository: `/Users/cs/local/code/apps/terminal-agent-visual-signals`
Scope: source reads only. No helper invocation, tests, UI, provider calls, goals or repository edits.

## Conclusion

The smallest useful boundary is one Bash 3.2 and zsh compatible selection module, sourced by
`organizer-state.sh`, shell startup, and CLI recovery. Select one ordinary backend before any
operation. A native candidate is usable only when both current schema probes succeed exactly.
Choose portable only when that native candidate is absent or unsupported and a separate explicit
portable ordinary capability succeeds. A failed selected operation must return its existing
failure and retain the selected backend. Recovery stays native-only.

Do not place the shared implementation inside `organizer-state.sh`: the installed shellrc is
currently independent of the repository, and organizer-state has Bash-only cache handling.
A small sibling such as `src/core/helper-selection.sh`, plus its ordinary-call dispatcher, is
enough. No registry, generic plugin framework or persisted new state is needed.

## Current selection sites

| File and lines | Current selection contract |
|---|---|
| `src/core/organizer-state.sh:3-18` | Imports an exported organizer positive cache only if checked=1, intake=1, nonempty context, exact expected candidate path and executable. Immediately removes export attributes. |
| `src/core/organizer-state.sh:20-37` | Caches only `--validate-config --organizer-capabilities`, exact `tavs-organizer-schema=1`. |
| `src/core/organizer-state.sh:96-113` | Separate managed cache checks only `--validate-config --managed-output-capabilities`, exact `tavs-managed-output-schema=1`. |
| `src/shell/tavs-shellrc.sh:62-74` | Uncached, independent managed-only selection. |
| `src/cli/cmd-recover.sh:36-49` | Independent managed-only selection after saving suspension/resume marker. |
| `src/cli/cmd-sync.sh:73-80` | Sources organizer state and checks managed then organizer for readiness messaging. |

All these choose an explicitly present `TAVS_TEST_HELPER_BIN` value, including an empty value,
otherwise `/Applications/TAVS.app/Contents/MacOS/TAVSApp`. An override must not accidentally
fall through to the installed native app.

Capability probes erase `TAVS_SESSIONS_TEST_ROOT`, `TAVS_SESSIONS_TEST_FIXTURE` and
`TAVS_SESSIONS_TEST_TARGETS`. This avoids fixture-driven native launch during probing.
Actual managed and recovery operations preserve dedicated target scope. Organizer calls erase
those three keys. Preserve this operation-specific distinction; a shared dispatcher must not
blanket-strip every call's environment.

Native capability implementations are `managed-output-entry.swift:26-28` and
`organizer-intake.swift:72-75`; both require the exact three-argument probe form.

## Actual call sites and delivery flow

All ordinary core calls are centralized in `src/core/organizer-state.sh`:

| Lines | Request |
|---|---|
| 39-42 | `_tavs_organizer_call`, sanitized environment dispatcher |
| 63 | `--organizer-intake` |
| 86-87, 119-120 | `--organizer-context` |
| 92-93 | `--organizer-observe` |
| 127-129 | `--managed-forced-reset` |
| 136-138 | `--managed-check-context` |
| 148-149 | `--managed-reconcile` |
| 204-206 | `--managed-render`, piped finite NUL payload |

Additional production sites:

- `src/shell/tavs-shellrc.sh:108-109`: `--managed-register`.
- `src/shell/tavs-shellrc.sh:116-117`: `--managed-current`.
- `src/cli/cmd-recover.sh:53-54`: `--visual-recover`.

There are no direct shell ordinary calls to `--organizer-intent` or `--managed-background`.
The finite helpers support them, but current backgrounds use the batched `--managed-render`
route. Do not add unnecessary shell callers.

Claude and Codex adapters source organizer state at their line 26, perform intake, then exec
core with stdin `/dev/null` (`claude/trigger.sh:33`, `codex/trigger.sh:30`).
`terminal-osc-sequences.sh:10` sources organizer state for core, idle workers and legacy adapters.
Gemini and OpenCode directly exec core (`src/agents/{gemini,opencode}/trigger.sh:15`).

High-level users remain unchanged if selection/call dispatch is centralized:

- `src/core/trigger.sh:106` observe, `191` reconcile, `413` check context, and render batches.
- `src/core/idle-worker-background.sh:129` forced reset; `141-180` render batch.
- `terminal-osc-sequences.sh`, `backgrounds.sh`, and `title-management.sh` queue typed visuals.

Unrelated native-only lifecycle calls exist in `cmd-install-macos-app.sh:409`
(`--reported-status`), `login-item-doctor.sh:76`, and `cmd-uninstall-macos-app.sh:72`
(`--unregister-login-item`). These are app lifecycle operations and should not enter the ordinary
backend selector.

## Cache and failure boundaries

`_tavs_organizer_intake` currently clears its incoming organizer cache/context at lines 48-49,
then selects before consuming stdin. On success it exports its organizer cache plus context
and intake hint at lines 72-73 so the exec'd core avoids another organizer probe. Core imports
that positive cache only under the narrow checks described above, then unexports it.
Managed cache has no explicit inheritance validation or export lifecycle.

One shared backend selection should travel with that existing adapter-to-core hint and be
validated against the exact selected candidate, including whether native or portable was chosen.
On direct core/shell startup, select locally. Clear inherited selection before adapter intake;
do not accept an arbitrary inherited checked flag. Retain the existing no-child-export behavior.
Do not invent additional identity machinery for this ordinary cache.

Current native intake failure does not reparse through `portable_metadata.py`:
the legacy metadata branch is entered only when selection was unavailable (`61-67`).
That rule must survive the portable routing extension. A selected portable intake failure also
must not retry a different backend or metadata parser. Preserve default metadata clearing,
privacy-safe diagnostics, stale status 3 and unavailable status 1.

`_tavs_render_flush:200` currently permits a later reprobe only after selection was unavailable.
It does not invalidate a successfully selected helper after operation failure. Keep operation
failure separate from selection failure in the new shared code.

## Portable capability and packaging gaps

`src/core/portable_helper.py:24-27` exposes four organizer and seven managed ordinary verbs.
`run:72-74` rejects non-Darwin execution, native dedicated scope variables, unknown verbs and
wrong argument counts. There is no capability verb. Recovery is absent from its finite verb set.

Add a separate explicit ordinary capability before connecting selection. Its response must not
advertise native managed/recovery capability. The probe must not consume stdin, inspect a TTY,
register a target or create state. Preserve the helper's current Darwin/platform/import gates.
Ordinary support must not make `tavs recover` report recovery success.

The full portable import closure is these 13 sibling files:

```text
portable_helper.py
portable_context.py
portable_device_writer.py
portable_intent.py
portable_metadata.py
portable_observation.py
portable_ownership.py
portable_policy.py
portable_process_identity.py
portable_record_io.py
portable_records.py
portable_render.py
portable_renderer.py
```

`cmd-sync.sh:104-106` copies all core shell scripts and text data but only
`portable_metadata.py`, so a copied plugin currently lacks the rest of the portable backend.
Copy the full existing `portable_*.py` family together; its sibling imports require co-location.
`portable_helper.py` is executable with a Python shebang in the current tree. An explicit
Python dispatch is also possible, but no dependency is needed.

`cmd-install-shell-integration.sh:99-101` and `cmd-sync.sh:67-69` copy only standalone shellrc.
If shellrc sources the shared selector, install and refresh the selector and its portable sibling
files into an installed resource directory too. Installed sourcing must work after its source
checkout disappears. Derive paths from the sourced shellrc/module, with an explicit Bash/zsh
branch if needed; do not trust a stale inherited `TAVS_ROOT`.

Agent installers configure absolute hook paths to their existing checkout and do not copy core
modules (`src/install/install.sh`, `install-codex.sh`, `install-gemini.sh`). Their hook/config
contracts do not need a new resource copy step. Plugin/marketplace source copying is `cmd-sync`.

## Tests and fixtures affected by this boundary

These are source-derived impact notes only; no tests were run.

- `tests/integration/hook-observations.bats:8-16` builds a miniature repository by copying
  organizer-state and portable metadata individually. Copy the selector and required portable
  modules there too. Its fake core at line 230 sources the copied organizer module.
- The same fixture's probe-count/cache tests at 206-280 must expect both native probes for one
  native selection, while retaining one adapter selection and no exported cache after core
  import. The failed-native-intake fake at 361-387 currently advertises organizer only; it must
  advertise both native schemas to remain a selected-operation-failure test.
- `tests/unit/shellrc.bats:27-34` fake supports only managed capability. It needs both schemas
  if native ordinary selection requires both. Its copied standalone test at 222-235 copies
  only shellrc and points TAVS_ROOT at a nonexistent directory; install resources in that fixture
  and keep the no-repository-dependency assertion.
- `tests/unit/cmd-recover.bats:12-32` fake supports managed only and lines 36-40 assert one
  validation call. If recovery uses shared native selection, update the fixture/probe count but
  keep persistence before the first probe, empty override behavior and result forwarding.
- `tests/unit/cmd-sync.bats:40-41` checks only portable metadata among copied Python files.
  Expand this to the complete closure and selector. Its copied installed shell tests at 87-102,
  no-native metadata cases at 71-84 and missing/partial native cases at 150-198 need the new
  intentional selection behavior. The render-only fake should remain an unsupported native
  candidate and should not claim native readiness.
- `tests/integration/managed-background.bats:13-23` already exposes both native schemas.
  Missing/old-native tests at 370-378 currently expect selection failure; after portable selection
  those expectations need either a deliberately unavailable portable candidate or assertions
  about safe ordinary operation failure on fake devices. Keep failed native operation tests
  at 381-386 and shell startup 410-423 as no-backend-change/no-raw-output checks.
- `tests/integration/{emit-osc,liveness}.bats` fakes expose both native schemas.
  `tests/integration/background-intent.bats:510` sources the repository shellrc and relies on
  its connected resource discovery. `tests/e2e/hard-lock.sh:39` holds the same shellrc path.

Useful additional narrow coverage: native both-supported preference over portable; each partial
native schema; distinct portable capability; missing interpreter/modules; selected native and
portable operation failure without backend change; adapter cache transfer; installed/copied
portable modules and shellrc with checkout unavailable; native-only recovery after suspension.

## Current progress alignment and limits

The current Phase 9 appendix confirms this is the next approved H1 work:
`PROGRESS_appendix_phase-9-foundation.md:841-848` says the last checkpoint adds unbound intent,
with advertised capability, hook delivery and backend selection still pending. Lines 819-820
explicitly require native preference and no backend change after selected-operation failure.
The current code matches that status. Historical test counts were not rerun or used as fresh
verification. Linux support and native physical acceptance remain outside this recon.

Memory lookup found only prior TAVS runtime safety context, not helper-routing history; current
findings above are all from source reads. The read-only scope avoids prior live-terminal risks.

<oai-mem-citation>
<citation_entries>
MEMORY.md:662-665|note=[prior TAVS runtime safety context]
</citation_entries>
<rollout_ids>
01a100cb-205c-7840-8268-c3d4ab1f7849
</rollout_ids>
</oai-mem-citation>

## Capability/delivery source check

# Narrow capability and delivery source check

## Metadata

- Reviewer: Codex, source inspection only
- Review type: code
- Review mode: coaching
- Tier: lite
- Date: 2026-10-14
- Target: current diff in `src/core/portable_helper.py`, `src/cli/cmd-sync.sh`,
  `tests/unit/test_portable_helper.py`, and `tests/unit/cmd-sync.bats`
- Scope: capability contract, import closure, copied modes, preserved sync targets and state
- Excluded: execution, imports, tests, UI, provider calls, routing changes, and goal activation

## Rubric Scores

| Dimension | Score | Evidence |
|---|---:|---|
| correctness | 8 | Exact three-element argv, Darwin gate, scope rejection, self inspection |
| security | 8 | Presence of any native test-scope key refuses; private failure text persists |
| maintainability | 8 | Small early branch and explicit existing-module delivery list |
| test_coverage | 7 | Added source tests cover success, wrong count, scope, Linux and inspect failure |
| completeness | 8 | Thirteen files close all local imports; helper receives executable mode |

## Verdict

**verdict**: APPROVE

**confidence**: high for the inspected source properties; runtime behavior unverified

## Findings

No concrete defects identified within this narrow diff.

## Evidence

1. `src/core/portable_helper.py:72-76` accepts only
   `--validate-config --portable-ordinary-capabilities`, exactly three argv elements including
   the program name. It requires `sys.platform == "darwin"`, rejects presence of any of the
   three `_SCOPE_KEYS`, and calls `inspect(os.getpid())` before success. A failed inspection
   enters the existing private error boundary.
2. Success returns only `tavs-portable-ordinary-schema=1\n`. Other capability aliases remain
   absent from `_COUNTS`. The new marker advertises neither native managed output, organizer
   focus, recovery, Linux support, nor native test-scope support.
3. The early return precedes `capture`, `read_input`, `_roots`, `Store`, `Policy`, `Renderer`,
   lock acquisition, and device output. `portable_process_identity.py:42-62` performs the
   Darwin process query through libproc and validates the requested PID and live generation.
   No application runtime, marker, record, or TTY state is created on this branch.
4. `src/cli/cmd-sync.sh:106-112` copies the helper plus all twelve local import dependencies.
   Inspection of all thirteen files found only those local modules and Python standard
   library imports, including `portable_record_io` and `portable_device_writer`. No dynamic
   import or additional local module dependency was found. The helper's source mode is
   executable, and sync explicitly restores its executable bit. Imported modules are
   readable and do not need executable mode.
5. Existing target selection at `cmd-sync.sh:37-58`, installed shellrc copying at `66-69`,
   and native capability reporting at `73-80` retain their source behavior. User preferences,
   saved schedule, and runtime lock paths are not copy destinations. Failures from each new
   copy and chmod propagate before reporting success.
6. `tests/unit/test_portable_helper.py:29-44` tests the ordinary marker and rejection paths,
   excludes intake/input calls, and checks runtime and marker absence. The copied-helper
   test at `tests/unit/cmd-sync.bats:87-105` compares all thirteen delivered files in both
   private installations, checks executable mode, invokes each copied entry, and checks
   the three existing state sentinels. It inherits the suite's private HOME/runtime setup.

## Summary

The inspected capability and delivery changes meet their narrow source contract. Routing
remains pending, and this report makes no claim about an installed helper or native acceptance.
No code, imports, tests, UI, providers, or goals were executed. Python bytecode cache behavior
is interpreter controlled; the isolated test runner sets `PYTHONDONTWRITEBYTECODE=1`.
