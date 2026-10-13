# Claude H1: ordinary signaling compatibility

Baseline: `470b03553c58a8e9004cbf1c5c3dca627ee6a80f`.
Scope: read-only source, SPEC, D01-D18, adapters, delivery paths and test inspection.
No tests, builds, native requests, app launches, device writes or repository edits were performed.

## Conclusion

H1 identifies real ordinary signaling and metadata regressions. Making the optional macOS
companion mandatory is not an approved D01-D18 decision. Keep the new organizer's macOS/Ghostty
scope distinct from the existing plugin's terminal/platform compatibility. Do not close H1 by
changing expected output to zero or describing all existing installs as unsupported.

The SPEC does not require a pure Bash renderer: a bounded helper can deliver ordinary output.
It does require preservation when no controller owns an effect. Current installed-helper-only
resolution fails that behavior for valid standalone installs. Linux regression is additionally
established by the repository's existing support promises, not by a Linux organizer promise.

## Source evidence

- `SPEC.md:123-132` requires allowlisted intake, raw-body disposal and preservation of existing
  legitimate metadata behavior. `SPEC.md:161-164` preserves direct ordinary signaling when
  uncontrolled. `SPEC.md:180-186` lets ordinary hooks paint after ownership expires.
- `SPEC.md:263-272` requires in-lock current policy/target checks and the bounded writer for
  managed backgrounds/restrictions. Required recovery-helper failure is explicit at `235-237`;
  this is not a statement that every ordinary hook requires the installed GUI app.
- D02 limits initial organizer surfaces to local Ghostty; D05 includes plain shells; D17 reuses
  existing provider signals. D01-D18 contain no decision to withdraw Linux/other-terminal/plugin
  support or require installing the macOS companion for ordinary hook output.
- `PLAN.md:199-203` separates metadata preservation from unavailable observation coverage.
  `PLAN.md:292-304` preserves nonbackground styling and prohibits bypassing failed managed writes.
- `organizer-state.sh:3-19,67-83` selects only an explicit test helper or the fixed app path.
  It accepts exact capability strings. No production source-built/plugin-relative path exists.
- `_tavs_render_flush`, `organizer-state.sh:164-194`, clears pending typed output and returns
  failure if that helper/context is unavailable. Background, palette, title, bell and iTerm2 image
  are all in that batch. `terminal-osc-sequences.sh:84-120,201` routes those OSC kinds to the queue.
- `trigger.sh:267,281,408,430-431` ignores flush failure and ultimately returns zero. The loss is
  accompanied by stderr diagnostics, so strictly it is not entirely silent. Worker diagnostics
  are redirected away. Existing Kitty image subprocesses are an exception to the queued kinds.
- `_tavs_organizer_intake`, `organizer-state.sh:27-50`, exports default permission mode and empty
  transcript/session/cwd when native intake is unavailable. Claude/Codex adapters continue into
  core (`src/agents/claude/trigger.sh:25-33`, `codex/trigger.sh:25-30`). Continuing dispatch alone
  does not preserve actual OSC delivery or the lost metadata-dependent behavior.
- Mode colors consume permission mode (`theme-config-loader.sh:364-379`); session identity consumes
  session ID (`session-icon.sh:61-62`); directory identity uses cwd (`dir-icon.sh:244`); context
  estimation uses transcript path (`context-data.sh:105`). These are existing product functions.
- README `47-82,92-98,277-290,1082-1087` advertises plugin/manual installs, automatic defaults,
  compatible terminals and macOS/Linux. The companion is separately installed at `926-950`.
- `cmd-sync.sh:84-107` delivers core/adapters/hooks/CLI, but no app/helper. Agent installers likewise
  do not install the companion. `cmd-uninstall-macos-app.sh:77-93` even promises normal painting
  after companion removal. This update path can strand currently working plugin installations.

## Existing routes and limits

- Reuse `ProcessRunner.swift:159-228,259-321`: 100 ms caller budget, late-open rejection, nonblocking
  write/poll, open before advisory lock and fresh checks inside preparation. An unlocked
  `writeToDevice()` call alone does not provide managed policy/recovery serialization.
- Existing `--managed-render` can already deliver complete ordinary style without active effects.
  `managed-output-entry.swift:75-133` admits a continuing owner/context; verified provider identity
  is not required for ordinary rendering. `OrganizerIntake.producer:198-199` can bind the foreground
  owner while honestly withholding agent identity. No new OSC parser or observation inference is needed.
- `TerminalRender` is a finite 23-field encoder (16 KiB cap), not arbitrary stream interpretation.
  `OrganizerIntake.decode/readInput` provides top-level JSON allowlists, a 1 MiB limit and a two-second
  input deadline. These are usable existing contracts to retain rather than discard.
- Those paths import Darwin and live in a macOS Swift executable. The package is macOS 13+.
  No existing portable bounded writer plus ownership/policy check, or finite top-level hook parser,
  was found in production shell modules. Python is used by installers/tests, not a declared hook
  runtime dependency. Old `cat` plus greedy `sed` extraction retained bodies, accepted nested keys
  and mishandled JSON escapes. Restoring it would violate the current privacy/parser contract.
- Original `emit_osc` performed direct `printf > "$TTY_DEVICE"`; it did not have the new output
  lock/deadline. TTY query timeouts, identity mkdir locks and provider hook timeouts are not substitutes.

## Smallest safe repair direction

1. Keep the typed queue and existing macOS managed renderer. Provide an ordinary transport that
   standalone supported installs actually receive. Select its capability before rendering, rather
   than raw-writing after a failed managed operation. Reuse the bounded writer/parser contracts.
2. Any ordinary compatibility transport must prove uncontrolled/current policy under the same stable
   per-TTY output lock and budget. It must reject uncertain live ownership/targets, preserve suspension
   ordering and never replace failed controlled rendering. App absence or a pre-open file check is
   not proof that a controller owns no effect. Existing stale/failed-helper no-bypass tests remain valid.
3. Extract allowlisted legacy metadata independently of native organizer availability, using one bounded
   real JSON parser. Organizer correlation/context may remain unavailable; never invent trusted cues.
4. Deliver/preflight the selected transport through plugin/manual install and sync. Add owned-PTY cases
   for absent/old app with no owner, title/bell-only ordinary output and metadata, plus controlled/racing
   cases which still reject bypass. Preserve positive healthy-helper cases and explicit recovery failure.

## Creator decision

Preserving current ordinary compatibility is already required. The unresolved choice is how to supply
its safe transport on standalone macOS and Linux: package a plugin-local executable/runtime, or approve
one portable runtime dependency. PLAN `37-45` currently forbids an extra binary and says no new dependency.
That delivery choice needs creator input before a portability implementation; choosing Python merely
because tests use it or requiring Swift/app installation silently would add an unapproved requirement.
Resolving only the fixed app path to a scratch build fixes a developer case, not the product contract.

## Test interpretation

`hook-observations.bats:220-243` checks missing/old-helper dispatch into a substituted recording core;
it never verifies ordinary terminal bytes and does not assert preservation of the four metadata fields.
`managed-background.bats:226-238,370-385` correctly disallows raw bypass, but does not establish that
dropping all uncontrolled standalone signaling satisfies the SPEC. Extend coverage, do not weaken safety.

## Sync diagnostic follow-up

- Two-file diff preserves source-copy success independently of readiness: missing capabilities warn,
  omit the prompt-testing invitation and still report completed copying. Copy failures still return early.
- The ready branch requires both exact managed and organizer capability tokens. The `&&` short-circuits
  the organizer probe when managed support fails, which cannot falsely report readiness.
- Both existing probes use `--validate-config` and omit all three Sessions fixture launch keys.
  Current capability handlers return before native discovery, SwiftUI launch or device operations.
- This diff adds no raw output route, native catalogue query, helper installation or rendering change.
- One wording fix is needed: "Rebuild TAVS.app before testing these sources" presumes macOS and an app
  installation. On standalone/nonmac hosts it offers an unavailable remedy. Prefer "Hook rendering and
  metadata remain unavailable; sync does not build/install the helper" until creator scope is resolved.
- Added tests describe missing, unsupported and render-only probes. They were inspected, not executed.

## Approved portability direction and metadata source checks (2026-10-13)

The operator authorized all remaining steps needed for the goal. The implementation chooses
Python 3 standard-library support for standalone macOS/Linux compatibility. PLAN/SPEC bodies
remain fixed; PROGRESS records this narrow dependency/file-list exception. Metadata is the first
verified slice. H1 remains open until the safe writer, lifecycle and platform acceptance pass.

### Retained source report: explorer-tavs-portable-helper-20261013.md

# H1 Python3 portable helper route

Source-only investigation at 3144a88. No edits to project files, builds, tests,
apps, native/libproc calls, devices, web calls or parent-goal access. Python3
runtime approval is taken from the parent's brief; installed runtimes were not probed.

## Recommendation and bounded implementation order

Deliver a plugin-relative Python3 standard-library helper with the existing core
source tree. Keep the native renderer preferred whenever its exact capability
probe succeeds. The portable route must implement the complete finite ordinary
render batch, metadata and delivery lifecycle, and prove absence of applicable
control under the existing output lock. It does not replace native controller
composition or independent native recovery. Never choose it after a selected
native managed operation has failed.

First slice: portable allowlisted metadata parser plus capability/resolver wiring
and delivery preflight. This immediately repairs legacy metadata without needing
process/TTY inspection. It is useful, but cannot close H1 because it paints nothing.
Next slice: process identity bridge, compatible delivery/context records and the
bounded ordinary writer, including synthetic idle/context-check/forced-reset
paths. Test and commit those slices separately. Do not stop at the metadata slice
or silently withdraw Linux/standalone signaling to make tests pass.

Suggested small modules: src/core/portable_helper.py (verbs/intake/render parser),
portable_process_identity.py (macOS/Linux bridge), portable_output.py (records,
policy, lock and bounded write). No server, generic backend interface, index or
new persistent protocol is needed. Reuse schema-1 records on macOS. Advertise a
distinct portable ordinary-output capability until every claimed native verb is
implemented; do not claim full managed-output semantics for an uncontrolled-only
writer. Selection remains outside the render operation, not a failure handler.

## Existing contracts to retain

- SPEC:123-164 preserves top-level allowlisted metadata, drops raw bodies, creates
  one delivery identity at intake, tracks latest ordinary intent even under control,
  and preserves ordinary signaling when uncontrolled. SPEC:263-272 requires fresh
  in-lock policy/identity checks, open-before-output-lock and the 100 ms writer bound.
- helper-compatibility-check-2026-10-13.md proves native-only fixed-path resolution
  breaks standalone installs. Current plugin/manual/sync delivery does not install
  TAVS.app. Missing native recovery remains explicit; ordinary output is a different
  compatibility promise. PLAN:37-45's no-extra-dependency wording needs narrow
  updating for the newly approved Python runtime, not another approval request.
- organizer-state.sh:20-140 currently probes exact native organizer/managed tokens,
  creates contexts, observes, checks synthetic freshness, reconciles and forces
  reset. Its 23-field NUL queue/flush at 145-214 already carries the whole style.
  Preserve rendered/restricted/unaffected outcomes and code 3 stale behavior.
- OrganizerIntake:23-67 is the metadata mapping: Claude permission_mode, session_id,
  cwd, transcript_path, allowed hook_event_name/notification_type; Codex thread-id,
  cwd, type and turn-id. Keep exact byte limits, null/empty handling, decoded JSON
  strings and session-ID control rejection. Unknown/nested payload bodies are not
  retained. Input is <=1 MiB with a two-second read deadline; no cat/sed/eval route.
- TerminalRender:12-54 requires <=16 KiB, exactly 23 UTF-8 fields plus final NUL,
  finite flags/actions, normalized hex/rgb/reset, title/image control rejection.
  Preserve palette-before-background, title/image-after-background and synthetic
  BEL suppression. Title persistence happens only after actual rendered outcome.
- managed-output-entry:78-134 verifies source generation/device/ancestry, then
  continuing owner, before rendering. TerminalVisualStateStore:695-785 checks
  synthetic delivery against latest observation and rejects superseded intake.
  Context/identity is not inferred from provider JSON, title or directory names.
- VisualRecovery:181-425 publishes typed intent, rechecks policy under serialization,
  composes native ownership, handles expired ownership and emits finite bytes.
  Portable code must not parse arbitrary OSC or reuse pending OSC files.

## Minimum identity bridge

macOS: ctypes with system libproc's proc_pidinfo(PROC_PIDTBSDINFO=3), exact returned
size, matching pbi_pid, pbi_start_tvsec/usec, PPID, PGID, e_tdev and e_tpgid.
Reject SZOMB=5 and PROC_FLAG_INEXIT=4. Local SDK headers confirm these fields and
constants (sys/proc_info.h:59-81,105,723; sys/proc.h:153; libproc.h:96).
The declared struct has 12 uint32 fields, 16+32 char bytes, five uint32 fields,
one int32 and two uint64 fields: 48+48+20+4+16=136 bytes. Assert that layout and
returned size; unsupported layout is unavailable, not a ps timestamp fallback.
proc_pidpath is needed only if porting native provider verification; ordinary
binding can honestly remain verifiedAgent=false, as OrganizerIntake:198 allows.

Linux: bounded reads of /proc/<pid>/stat, splitting after its final ')' so spaces
or parentheses in comm cannot shift fields. Required fields are state, PPID,
process group, tty_nr, foreground group and starttime ticks. Compare device numbers
through one documented Linux encoding adapter against lstat/fstat character-device
identity. Support real /dev/pts/N as well as concrete /dev/tty names; the current
macOS concreteTTY predicate cannot be copied unchanged. Never authorize /dev/tty
as a lifetime-specific target. Reject zombies, missing/mismatched generations,
unreadable proc data, absent controlling TTY and ambiguous foreground owners.
Retain start ticks as the canonical generation; if interoperable seconds/useconds
are required, derive them with integer btime+ticks/SC_CLK_TCK arithmetic and verify
stability within the boot. Do not use rounded ps start times or PID-only identity.
Linux /proc field/device/boot semantics need official or Linux-target verification
before implementation acceptance; no Linux host or external reference was queried.

For both adapters, repeat generation/device checks, cap ancestry walks at 16,
reject loops and attest the non-synthetic producer as an actual helper ancestor.
Follow the existing same-device continuing-owner rule. Synthetic workers use the
original current delivery and live producer checks, not new agent occurrences.
Permission denial or kill(0) EPERM does not establish process death. Native surface
records also require their app generation checks; unsupported/unknown identity
must reject ownership resolution rather than imply no controller.

## Complete ordinary writer boundary

Use the same organizer/writer-<URL-safe-base64-TTY>.lock (600), target-generation
paths, observation/intent schemas and bounded regular-file reads. Validate paths,
file kinds, schemas, canonical placement, aliases and same-TTY owner ambiguity.
Reject symlinks, malformed/unknown records and uncertain live ownership. Preserve
stale-delivery checks even for title/palette/BEL-only requests. Publish latest
normalized ordinary intent under the lock; no active owner means no controller
currently applicable, not merely an absent helper executable.

Evaluate the exact suspension marker, lock.state and mute.state and target effects
under the output lock, matching VisualRestrictionPolicy's current rules. Preview
lease is two seconds, other selective ownership six seconds; controller generation
must validate. Suspended restrictions can still have an explicit preview. Do not
mistake an unavailable marker for ordinary-output authorization. If native control
is applicable, use the already selected compatible native route, or return explicit
unavailable from portable output while retaining safe typed intent. No raw bypass,
no stale color/palette replay, no composition guessed from cached background alone.

For output, use os.open O_NONBLOCK/O_NOCTTY/O_NOFOLLOW, fstat device checks,
fcntl.flock LOCK_EX|LOCK_NB, monotonic deadline checks and bounded select/poll/write.
A thread alone does not establish the caller deadline if open blocks. A single
request-local supervisor plus forked worker is a small standard-library route on
both Unix platforms: one absolute 100 ms deadline starts before worker dispatch;
parent waits only to that deadline and terminates an overdue worker; child checks
expiry after late open and before metadata/output. No late paint or fresh budget
per stage. The worker opens the TTY before acquiring output serialization. Python
startup/intake are separate from this writer budget, just as native startup/input
are separate today; do not claim entire hook execution <=100 ms without measurement.

## Delivery and required verification

Resolve portable files relative to organizer-state.sh's own installed location;
use a declared/preflighted Python3 runtime, without pip/native build/GUI dependency.
Retain explicit test-helper override isolation and positive native capabilities.
Do not advertise a portable organizer capability while its context/observe/intent
verbs are absent. Metadata-only capability can ship earlier without invented cues.
The full route needs the idle check/reset/reconcile operations used at trigger:191,
413 and idle-worker-background:129, with existing stale/target-generation safety.

cmd-sync:102-107 currently copies only *.sh and *.txt from core: explicitly copy
all required Python modules and validate readiness in the destination. Plugin/full
repository installs naturally receive tracked files; agent install/preflight and
README prerequisites must acknowledge Python3. OpenCode's npm package ships only
dist/README and locates an external core tree (signal-bridge.ts:24-46); ensure that
installed core tree carries the helper. Do not infer delivery from a source checkout.

Acceptance: owned PTYs on macOS AND Linux for absent/old native app, metadata,
complete ordinary background/palette/title/BEL/image batch, synthetic freshness,
late/reused TTY, expired/dead owner, active/uncertain controller, suspension/recovery
race, held lock, blocked open and deadline expiry with no late bytes. Keep healthy
native cases and failed-native no-bypass tests. Existing hook-observations:50-78,
165,301-319 tests include metadata/privacy but missing-helper dispatch uses a fake
core; managed-background:226,370,388 protects no raw fallback. Extend them with
actual portable bytes, complete deployment copies and platform identity fixtures.
Passing metadata fixtures or a macOS-only mock does not close H1 portability.

### Retained source report: explorer-tavs-portable-metadata-followup-20261013.md

# Portable metadata-first diff review

Source-only review of current portable_metadata.py, organizer-state.sh, connected
intake/tests and the latest sync source. No edits to project files, builds/tests,
apps, native/device/web actions or parent-goal reads. H1 rendering is not solved.

## Findings

No concrete introduced parser, privacy or stale-export defect found in the
inspected implementation. The brief's initially pending sync copy is now present
in current source; this review does not claim that its red test has been rerun.

## Checked contracts

- read_input uses nonblocking fd reads and select with one monotonic two-second
  input deadline. It reads at most 1 MiB plus one rejection byte and restores
  stdin flags in finally. A pipe withholding EOF expires instead of waiting forever.
  The bound covers stdin reading, not Python process startup or a separate hard
  deadline around json.loads, matching the native read/decode distinction.
- json.loads requires a top-level object and rejects nonstandard constants. The
  four field mappings match OrganizerIntake: Claude mode/session/cwd/transcript,
  Codex default mode/thread-id/cwd with empty transcript. Missing/null values clear
  to empty, unsupported mode clears to default, wrong types are rejected.
- Field limits are UTF-8 BYTES (128 mode, 512 session, 4096 paths), with NUL rejected.
  Session/thread IDs reject Cc and Cf. The installed CoreFoundation CFCharacterSet.h
  defines kCFCharacterSetControl as exactly those two Unicode categories, matching
  the native CharacterSet.controlCharacters check. Decoded newline in cwd remains
  data, and terminal/control syntax in metadata is not executed as shell code.
- Only four fields and TAVS_LEGACY_METADATA_INTAKE are emitted as NUL pairs, after
  all metadata validation succeeds. Raw JSON, unknown/nested fields and body text
  are not logged, forwarded or persisted. Malformed UTF-8/surrogates, parse recursion,
  I/O and validation failures use a generic body-free diagnostic, without traceback.
- The portable path intentionally does not validate/extract provider event/turn
  fields because it creates no organizer context or observations. This differs
  from native event validation, but does not grant observation authority or change
  the requested four legacy-field contract.
- organizer-state.sh chooses the native route from its exact capability probe
  before intake, then executes only that chosen branch. A failed native intake
  is not reparsed with Python. Unsupported/absent native helper selects Python
  before reading the payload. Metadata success still returns organizer-unavailable.
- Every call unsets raw payload, organizer context/intake and helper caches, uses
  local default/empty legacy fields, then exports the resulting four fields. Missing
  Python, missing script, malformed input or native failure cannot preserve prior
  context/intake. Portable success does not export a native helper cache or trusted
  TAVS_ORGANIZER_INTAKE. The private marker is consumed as a local flag only.
- command-v failure avoids Python invocation and produces the generic metadata
  unavailable status. Invocation/parser failures likewise leave safe defaults.
  Existing adapters intentionally continue fixed signal dispatch, but no portable
  terminal writer is provided by this slice.
- Current cmd-sync.sh:104-107 explicitly copies portable_metadata.py and returns
  nonzero on copy failure. Python invokes the file directly, so executable mode
  is unnecessary. The comparison test checks both existing installation targets;
  it does not replace missing-helper render readiness with a success claim.

## Tests inspected and remaining useful coverage

New tests cover missing/old native helpers preserving decoded metadata, Codex
escapes/newlines, nested-body privacy, invalid types, NUL/session controls, lone
surrogates, invalid constants, oversized input and an open-pipe deadline. Existing
native metadata/privacy cases remain; the fixture now copies the Python helper.

Add a supported native capability whose intake consumes stdin then fails, with
valid portable-readable metadata, and assert empty/default fields, no context and
no portable reparse. Add missing-runtime and missing-file cases with stale legacy
fields/context/intake preseeded, asserting clearing and generic failure. Include
TAVS_ORGANIZER_INTAKE in capture assertions because current portable tests inspect
context but do not directly assert absence of that trust hint. Exact 512-byte /
multibyte boundaries would strengthen byte-limit parity without duplicating tests.

Delivery/runtime caveat: installers/docs still need the approved Python3 prerequisite
and later helper readiness work. The current native-render readiness warning can
remain explicit during this bounded metadata slice. Neither portable metadata
success nor source-copy success establishes ordinary OSC output or H1 closure.
