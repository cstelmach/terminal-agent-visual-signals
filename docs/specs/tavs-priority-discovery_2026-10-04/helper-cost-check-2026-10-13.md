# TAVS M5 helper launches
Date: 2026-10-13. Source baseline: c6b4d2c; checkout was clean.
Read-only source investigation. No tests, builds, helpers, apps, native calls or devices were run.

## Confirmed counts
A normal Claude/Codex hook with valid intake, a TTY and a pending ordinary render launches:
1. Organizer capability: organizer-state.sh:3-19, called by adapter intake at :31.
2. Organizer intake: organizer-state.sh:41.
3. Organizer capability again in the new Bash interpreter after adapter exec.
4. Organizer observation: organizer-state.sh:63-64, core/trigger.sh:106.
5. Managed capability: organizer-state.sh:67-83, render flush at :168.
6. Managed render: organizer-state.sh:175-177.
Claude exec is src/agents/claude/trigger.sh:33; Codex exec is codex/trigger.sh:30.
Private CHECKED/path variables are not exported; intake context and metadata are exported.
These are six helper binary launches, not six total subprocesses or a measured latency.
Suppressed/no-TTY/duplicate states can skip rendering. Invalid intake can add a context call.
Synthetic workers and delayed restoration have their own calls; six is not a universal ceiling.

Interactive shell startup with enabled status, valid TTY and active/missing marker launches:
1. Managed capability: tavs-shellrc.sh:67-70.
2. Managed register: :108-109.
3. Managed current policy: :116-117.
Suspended/unavailable marker skips current, leaving two; missing/unsupported helper skips both verbs.
Noninteractive, disabled, or unresolved-TTY paths return earlier.
A missing marker is classified active at :29-39, so no state files still reaches all three.
Bash may additionally launch tty; absent registry adds mkdir calls. Zsh is not zero-process here.
The shellrc header cost claim at :17-18 is stale. Magnitude remains unmeasured.

## Cache and safety boundaries
- Organizer CHECKED=1 caches both success (selected path) and failure (empty path), per Bash process.
  Re-sourcing organizer-state only redefines functions; it does not reset this state.
- Managed uses separate CHECKED/path variables. Failed resolution in render flush resets CHECKED=0
  at organizer-state.sh:171; ordinary helper-call failure does not invalidate a positive cache.
- Shellrc has no capability cache across calls to _tavs_shellrc_main or repeated sourcing.
- Success of organizer query does not establish managed support. Never set the managed checked
  flag from organizer support; the two exact schema strings must remain independent.
- Existing private variables can already be inherited if a caller explicitly exports them.
  A bare export optimization would make that ambient cache easier to inherit and reuse stale.
  CHECKED=1 plus an arbitrary helper path bypasses safe capability dispatch; no provenance is proved.
- Fixed/test helper selection and executable existence should be rechecked if an env cache is imported.
  A PID-scoped, consumed hint avoids accidental descendant reuse, but cannot authenticate hostile env.
  Do not promote such a hint to producer/target/policy authority.
- Missing executable after a positive check fails at the actual call. Helper calls and render
  outcomes must still run and report failure; an earlier probe never proves current rendering.
- Same-path replacement is already a race between every probe and subsequent call. An exported
  positive cache enlarges its reuse interval. A legacy replacement can reach unknown flags and GUI
  startup, not necessarily a clean typed failure. Path/executable checks do not detect that case.
  No environment flag alone makes executable replacement safe; a fresh query also has a TOCTOU gap.

## Smallest recommended change
Preserve exec. Sourcing core in the OLD adapter shell is rejected: Codex JSON remains in the OS
command line despite set --, and forked Bash workers can retain that body. This was an initial
candidate corrected after the parent raised argv disposal. Core restore uses SCRIPT_DIR at
:416/:418, not $0; its usage messages use $0. Raw argv alone is decisive.
Recommend one small handoff function in existing organizer-state, used by Claude/Codex only:
after a locally verified positive organizer capability, exec a FRESH /bin/bash -c with a fixed
script that assigns private organizer cache locals from positional data and sources core.
Equivalent fixed script: '_TAVS_ORGANIZER_HELPER_CHECKED=1; _TAVS_ORGANIZER_HELPER=$1; shift; source "$@"'
Pass core path as argv0, then validated helper path, core path and existing fixed state/reason.
Keep </dev/null. This exec replaces raw argv before core starts or forks workers; no eval, body
argument or exported cache contract is needed. Healthy helper count becomes five.
Clear incoming organizer checked/path variables at adapter intake before the existing safe probe.
Transfer POSITIVE support only; failed intake/capability uses the original exec so core reprobes
exactly as today. Do not infer managed support, carry negative state, or export the private cache.
Core resolves its directory with BASH_SOURCE[0] (:39), has no top-level return and exits (:431).
Both interpreters are already Bash; sourced core receives explicit argv. Verify before shipping.
The earlier same-path replacement caveat remains; this is no guarantee against binary replacement.
Leave shell-startup verbs, direct-core callers, Gemini/OpenCode and H1 unchanged. Keep managed
render calls/results and privacy checks. Do not fold capability protocols or add dependencies.

## Focused verification to add
- Extend hook-observations.bats with a counting stub and a core that sources organizer-state,
  begins observation and flushes a typed render. Both real adapters must produce one organizer
  probe, one intake, one observe, one managed probe and one render, with exact qualifiers.
- Check stdin is empty in core; fixed state/reason argv, quoted paths and allowed metadata survive.
  Retain body sentinels and invalid/oversized input privacy cases; no new raw environment payload.
- Inspect core and forked worker OS argv for Codex body sentinels, not only Python sys.argv.
- Missing, legacy, organizer-only and managed-only helpers: no unsupported new verb or GUI route;
  no inference of one capability from the other. Direct core still performs its own support query.
- Separate hooks reprobe; forged incoming checked/path values cannot bypass adapter validation.
  Helper selection changes between hooks must be honored; no private cache exports reach children.
- Remove/replace a capable stub before observation/render: actual failure remains visible, no raw
  fallback, and no successful delivery bookkeeping. Same-path legacy replacement is a known race.
- Reuse managed-background.bats failures/stale/no-bypass cases (:226-238,370-399).
  hook-observations' substituted recording core (:14-23) alone cannot prove render behavior.
- Shellrc counting fixture: three active calls, two suspended/unavailable, zero functional verbs
  for missing/unsupported helper; assert Bash/zsh and standalone copied shellrc behavior.
- Existing managed-output-entry-tests.swift:158-166 proves managed capability query bypasses
  native factory/isolation; keep that dispatch and exact tokens. No Swift change is needed here.

## Follow-up: original script exec, 2026-10-13
The parent reports that fresh Bash -c/source fails real timer PID regressions; that candidate is
withdrawn. This follow-up supersedes the recommendation above. No runtime was run by this worker.
Exporting existing organizer checked/path ONLY after valid intake, immediately before original
exec-to-script, preserves raw argv disposal and the established timer process behavior.
Remove their export attributes at organizer-state load; keep their values private inside core.
Workers already inherited local positive caches in baseline; helpers/new execs should receive none.
Intake must clear inherited organizer checked/path before probing, as the current working change does.
Small import guard: accept positive cache only with intake=1, nonempty context, currently selected
fixed/test helper path equality and executable existence; otherwise unset cache and safely probe.
Keep the explicit-empty test-helper selection semantics. Never export managed capability state.
Missing path then becomes ordinary unavailable support; changed selection gets a fresh safe query.
Transfer no negative cache: invalid intake/missing/legacy helper retains today's core reprobe.
Direct core already trusted ambient checked/path in c6b4d2c. The guard narrows that existing trust:
ambient flags without valid intake/context or matching selection no longer bypass the safe query.
A forged complete tuple is still unauthenticated; same-path executable replacement is still a race.
Neither export removal nor -x proves schema support after replacement. Preserve actual call failures,
typed outcomes, no raw bypass and H1. No hash, inode tracking or new capability protocol is warranted.

## Parent measurements and final implementation

The initial fresh-Bash/source recommendation was rejected after owned timer regressions.
The final implementation transfers the existing positive cache inside successful intake,
retains the original adapter script exec and validates/unexports imported cache in core.
No handoff function, new binary, combined capability protocol or source-in-c path remains.

| Run | Three hook trials, ms | Helper count | Three shell trials, ms | Helper count |
|---|---|---|---|---|
| Baseline | 681.411, 194.317, 191.649 | 6 | 45.799, 44.602, 43.209 | 3 |
| Draft with original exec | 488.234, 186.536, 187.517 | 5 | 46.913, 47.128, 44.006 | 3 |

These are three fresh private-root, owned-PTY trials on this host, not a workload benchmark.
The counting wrapper logs only helper verbs, then execs the explicit current release helper.
No payload, context, title, cwd or process command line was saved in these measurements.
The profile uses tests/run-isolated.sh, separate child HOME/runtime/state per trial, processing
with title/palette/identity disabled, and an interactive Bash source of shellrc. The one-call
count reduction is exact for the measured path; latency benefit is not statistically established.
Reproduction script: /tmp/tavs-helper-profile-e_wsxhbv/profile.py. Full role lists and bytes are
in the two retained command logs. Final behavior is covered by hook-observations.bats.

Parent verification: final 548 Swift tests (`0ribbd`, 10.300 seconds); 178 Bats (`AVKcmZ`,
fixtures retained), syntax for all touched shells and helper/adapter ShellCheck. Reports are
source investigations, not native/UI acceptance. The unchanged helper was not rebuilt.
The separate verification diagnosis is retained in cost-verification-check-2026-10-13.md.
