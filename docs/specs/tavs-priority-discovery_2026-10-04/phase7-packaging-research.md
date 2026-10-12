# TAVS Phase 7 packaging exploration

Read-only exploration on 2026-10-12. Current HEAD at inspection: `1aed4a7`.
No source edits, tests, builds, installations, real-home sync, native discovery or UI actions.

## Smallest complete copy change

`src/cli/cmd-sync.sh:84-111` currently refreshes core `*.sh` and `*.txt`, config `*.conf`,
only the Claude `trigger.sh`, CLI `*.sh` and themes `*.conf`. Its real-home shell refresh at
lines 64-68 updates only `~/.tavs/shellrc`. It omits these source paths used by the changed
entry points:

| Copy into each existing plugin root | Reason and current source anchor |
| --- | --- |
| `tavs` | New root dispatcher loads `cmd-recover.sh` at `tavs:155-158`. Updating the subcommand alone leaves an old installed dispatcher unable to run recovery. Preserve executable permission. |
| `src/agents/codex/trigger.sh` | Current wrapper performs allowlisted organizer intake from appended JSON at lines 25-30. Sync currently copies only the Claude adapter at lines 96-100. |
| `src/agents/claude/hooks.json` and `hooks/hooks.json` | Current lifecycle commands carry `processing new-prompt` and `reset session-end` at both JSON files' lines 21 and 107. The changed adapter accepts these variants at `src/agents/claude/trigger.sh:20-23`. Existing source JSON files are byte-identical but distinct regular tracked files. Refreshing only the adapter leaves old lifecycle commands without the episode/session-end signal. |
| `src/shell/tavs-shellrc.sh` | The copied shell installer reads `$TAVS_ROOT/src/shell/tavs-shellrc.sh` at `cmd-install-shell-integration.sh:15,93-100`. Updating only `~/.tavs/shellrc` does not refresh the plugin's own source. A later copied `tavs install shell-integration` can reinstall stale code or fail on a missing shell directory. |
| `src/install/install-codex.sh` | Copied CLI `cmd-install.sh:33,60-68` dispatches this file. Its current lines 80-89 generate direct argv, allowing appended completion JSON to reach the wrapper. The old installer used `bash -lc`, losing that JSON. Sync currently never refreshes `src/install`. |

Use explicit copies for these known paths and create their destination parent directories.
Do not add a recursive whole-tree sync or copy generated builds, private config, settings or
unchanged agent data. The existing core and CLI globs already cover new
`organizer-state.sh`, `visual-restrictions-state.sh`, `cmd-recover.sh` and their neighboring
module dependencies. Claude `trigger.sh` is already copied.

The existing `cmd_sync` requires at least one plugin target before reaching its shellrc refresh
(`cmd-sync.sh:58-68`). That is existing developer-command behavior. A shell-only sync mode is
not needed for this packaging slice.

## Standalone and helper selection

The shellrc is already standalone: `src/shell/tavs-shellrc.sh:24-59` embeds the same bounded
restriction-state reader as `src/core/visual-restrictions-state.sh:3-37`. It has no `source`
statement and does not need an additional installed core module. Its native helper is the
external dependency at shellrc lines 62-73; register/current dispatch is at lines 108-117.

All changed helper readers select explicit `TAVS_TEST_HELPER_BIN` when set, otherwise
`/Applications/TAVS.app/Contents/MacOS/TAVSApp`:

- Organizer capability probe: `src/core/organizer-state.sh:3-19`.
- Managed output capability probe: `src/core/organizer-state.sh:67-83`.
- Standalone startup: `src/shell/tavs-shellrc.sh:62-73`.
- CLI recovery: `src/cli/cmd-recover.sh:36-49`.

The organizer and managed probes require their own schema-1 capability responses. A stale
installed app cannot satisfy the managed protocol merely because source shell files were
updated. Use the existing explicit `TAVS_TEST_HELPER_BIN` to bind copied-reader acceptance to
the staged built binary. Do not automatically prefer a source `.build` path or add fallback
helper selection. `_tavs_managed_helper` caches its result in a shell; a failed render resets
the negative managed check at organizer-state lines 168-172. `_tavs_organizer_helper` also
caches its result, so evaluate packaging in fresh fixture shells after staging.

## Existing fixtures and minimum tests

`tests/unit/cmd-sync.bats` does not exist in this checkout, although
`docs/specs/tavs-priority-discovery_2026-10-04/PLAN.md:387` names it. There is no existing
dedicated macOS install test file. Reuse the simple fixture style already present:

- `tests/unit/shellrc.bats:11-35` requires `TAVS_TEST_ROOT`, makes a private home/runtime and
  supplies an executable helper stub. Lines 76-106 cover installer copy/fence idempotency and
  removal. Lines 222-236 already cover the copied standalone shellrc without source modules.
- `tests/integration/managed-background.bats:3-28` demonstrates typed capability/dispatch
  stubs; it keeps all state and fake TTY output beneath the test root.
- `tests/unit/uninstall-macos-app.bats:10-39` demonstrates command stubs and an isolated
  bundle destination, but its destination override applies only to uninstall.

Suggested compact `cmd-sync.bats` cases:

1. Create fake versioned cache and marketplace directories with stale sentinel entry points;
   call sourced `cmd_sync` with fake HOME and fixture `TAVS_ROOT`. Compare each explicit path
   above plus representative new core/CLI files byte-for-byte to the source. Assert copied
   `tavs` and adapter executability. Keep a separate user config sentinel byte-identical.
2. Execute copied `tavs recover --help` so the root dispatch and CLI/core dependency layout are
   exercised without native output. Execute copied `tavs install shell-integration` in fake
   HOME, then source its installed shellrc in both interactive zsh and bash with the fixture
   helper. Check typed register/current dispatch and fence idempotency.
3. Execute copied Claude/Codex adapters with the helper stub recording organizer intake;
   disable subsequent visual behavior with the existing kill switch, keep all runtime,
   tmp, XDG and HOME roots private, and verify Codex JSON reaches the intake. Check copied
   lifecycle hook commands against source JSON.
4. Exercise the copied Codex installer only against a fake `.codex/config.toml`, feeding its
   ordinary confirmation input; parse the resulting root `notify` array and verify direct
   argv plus the copied adapter path. This catches stale installer copying, not only presence.
5. A missing or unsupported explicit helper must produce the existing unavailable result,
   never select `/Applications` after the explicit fixture value was provided. The test can
   source the copied module and call its probe directly. Capability-check the staged signed
   native helper separately when the parent build is ready.

Export `HOME`, `CFFIXED_USER_HOME`, `ZDOTDIR`, `TAVS_RUNTIME_DIR`, `TAVS_TMP_DIR`,
`_TAVS_TMP_DIR`, `XDG_RUNTIME_DIR`, `TAVS_TEST_ROOT` and `TAVS_TEST_HELPER_BIN` before
loading commands. Avoid running a broad suite as a packaging shortcut.

## macOS bundle staging boundary

`cmd-install-macos-app.sh:16-17` hardcodes `/tmp/TAVS-build` and `/Applications/TAVS.app`.
The full command immediately performs build, assembly, sign, install, launch and login-item
doctor at lines 55-65. `_assemble_bundle` removes the build root at line 139;
`_install_bundle` uses `pgrep -x TAVSApp` plus `killall TAVSApp` at lines 365-368 and removes
the destination at lines 371-376. Changing the destination alone does not isolate this path.

The binary contains the managed/organizer implementations because the executable target
uses the entire `Sources/TAVSApp` directory (`Package.swift:11-16`). Bundle assembly already
copies the resulting binary and current Info.plist (`cmd-install-macos-app.sh:143-159`).
There is no separate native helper resource missing from bundle assembly.

For copied-file unit coverage, source the installer, replace its private build/package/plist
variables with fixture paths, and call `_assemble_bundle` with a fake binary and stubbed
`plutil`. Do not call the full installer. For signed native staging, the parent can continue
its existing staged-bundle procedure and bind readers with `TAVS_TEST_HELPER_BIN`; no new
installer option is required merely for these tests. If a public stage-only entry point is
actually needed, it must stop before `_install_bundle`, `_launch_and_register` and doctor,
and use an explicitly owned staging root rather than the fixed global temporary path.

## Limits

Findings are based on fresh source reads, tracked-path comparison and current tests. I did not
execute fake-install tests, native helper probes, signing, builds or live deployment. Native
staged acceptance and proven owned-worker refresh remain parent work.
