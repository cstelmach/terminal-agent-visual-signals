# Phase 4 adapter and notify implementation

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

## Scope

Only these six project paths are owned by this worker:

- `src/agents/claude/trigger.sh`
- `src/agents/codex/trigger.sh`
- `src/install/install-codex.sh`
- `src/agents/codex/README.md`
- `src/agents/codex/HOOKS_REFERENCE.md`
- `tests/integration/hook-observations.bats`

No Git mutation, personal config, live agent, native app, install/sync operation,
working terminal or process termination was performed. Production parsing is
exclusively the parent's `_tavs_organizer_intake` API in `organizer-state.sh`.

## Changes

Both adapters validate existing fixed states, retain `processing new-prompt` and
`reset session-end`, and discard other arguments before core. Claude supplies
actual stdin to intake (terminal stdin uses `/dev/null`). Codex supplies its second
argument through a here-string in the current shell. Both unset inherited
`_TAVS_HOOK_PAYLOAD`, preserve intake's allowed compatibility exports, and exec
core with empty stdin. No raw JSON is assigned/exported by the adapters.

Codex notify now uses `["bash", absolute_script_path, "complete"]`. The installer
escapes quotes, backslashes and TOML control characters. With the parent's
additional scope approval, it prepends notify at root before any existing table,
retains the original backup, and rejects existing multiline notify arrays before
mutation. A new parser/config migration system was not added.

The two Codex documents now explain appended argv, absolute paths, allowlisted
metadata, missing turn IDs, partial completion-only coverage, and safe multiline
refusal. Historical broader provider comparisons are explicitly labeled.

The Bats tests run actual copied wrappers plus actual shared intake against a
capture-only core stub. This establishes adapter boundaries without spawning
completion/idle workers. Installer fixtures use an owned HOME/config and a
repository path containing spaces, quotes and backslashes. Fourteen tests cover
metadata decoding/top-level selection, context allowlist, raw env/argv/stdin
sentinels, fixed flags, missing turn ID, malformed/wrong types, unknown enums,
shell syntax, missing/legacy helpers, oversized input, argv round-trip, root
placement, backup retention and multiline refusal.

## Verification so far

Initial red (12/12 failures on old wrappers/installer):

`TAVS_TEST_HELPER_BIN=/tmp/tavs-phase4-adapter-backup-20261012/legacy-helper tests/run-isolated.sh bats tests/integration/hook-observations.bats`

Log: `/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.Xtosk0/command.log`

The controlled legacy-helper fixture accepts only the known
`--validate-config --organizer-capabilities` query, returning unsupported.
No new verb was invoked against an old or unknown binary.

Green compatibility subset (3/3): unknown-state rejection, manual fixed flags,
and absent/legacy helper availability. Log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.eJzG7I/command.log`

Additional red placement/multiline subset (2/2 failures):
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.7ycC2l/command.log`

Green placement/multiline subset (2/2):
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.gTfT4C/command.log`

Individual `/bin/bash -n` checks on all three changed shell files pass.
`shellcheck -S warning` on all three passes. Owned diff whitespace checks pass;
no credential-pattern match was found, and `.env` is ignored.

Full metadata green requires the parent's newly built helper readiness signal.
No source-built helper's new verbs have yet been called by this worker.

## Failure/recovery notes for parent capture

[O] The first tool result was reduced to `.output`, accidentally dropping a live
PTY session handle. Inspection of its exact retained command log and absence of
the test command established terminal red evidence. Later long calls retained
full result objects and exact session handles.

[O] The root-placement test initially compared paths containing inherited `//`
against the installer's `pwd`-normalized path. Retaining the failing Bats fixture
showed valid TOML and the same physical path. The fixture root now uses `pwd`;
no production workaround or weakened path/metadata assertion was introduced.

[R] The smallest useful approach was to keep JSON parsing centralized in the
existing Swift helper and use real wrappers with a capture-only core for their
transport boundary. This avoids parallel parsers and unrelated worker cleanup.

Exact served model was not observed; GPT-6 family is a self-report only.
Parent owns the project's mandatory META-THINKING-CAPTURE append.

## Remaining limitations

No real installer/provider/native acceptance was performed. The adapter fixture
does not establish real core debug/record behavior or Ghostty rendering; those
checks belong to the parent's connected Phase 4 work. Existing multiline notify
requires manual editing and is deliberately refused without mutation.

## Final verification

The parent announced source-helper readiness and exact support-query verification.
With that explicit binary, all 14 tests passed (exit 0):

`TAVS_TEST_HELPER_BIN=/tmp/tavs-phase4-20261012T114102/build/arm64-apple-macosx/debug/TAVSApp tests/run-isolated.sh bats tests/integration/hook-observations.bats`

Full log:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.Xn2IKY/command.log`

This closes the earlier full-green dependency. No further Swift build or real
provider/native invocation was performed. Parent retains full Swift, real-core
privacy/intent, hooks JSON parity, project docs/capture and exact staged commit
responsibility. All six owned paths are ready for parent integration.

Key touched operations: wrapper fixed-state/flag dispatch and shared intake call;
installer TOML path escaping, root placement and multiline preflight; Bats
`setup`, `_claude`, `_codex`, `_assert_private_dispatch` and 14 acceptance cases.
