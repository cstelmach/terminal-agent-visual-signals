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
