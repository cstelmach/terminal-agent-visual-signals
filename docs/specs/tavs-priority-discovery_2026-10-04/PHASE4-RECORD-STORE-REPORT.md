# Phase 4 Swift record foundation

Last Updated: 2026-10-12 (Europe/Vienna)
Version: 1.0

## Delivered scope

Only these two repository files were created by this worker:

- `src/macos/TAVSApp/Sources/TAVSApp/terminal-visual-state.swift`
- `src/macos/TAVSApp/Tests/TAVSAppTests/terminal-visual-state-tests.swift`

No existing source, shell, docs, native helpers, preferences or Git state was modified by this
worker. Parent-owned SPEC/PROGRESS edits were observed and preserved. No commit was made.

## Public interface

The proposed schema and APIs are preserved:

- `TerminalObservation: Codable, Equatable`, with schema 1, optional device/producer and optional
  real provider response identity. All timestamps are Unix doubles.
- `OrdinaryBackgroundIntent: Codable, Equatable`, with normalized uppercase hex or `reset`.
- `TerminalVisualStateStore(runtimeDirectory:clock:lookup:device:)` takes an explicit URL.
- `publishObservation(_:)`, `publishIntent(_:synthetic:)`, `coverage(for:)`.
- `TerminalVisualCoverage` returns observation, intent, attentionEligible and metadata-only status.
- `TerminalVisualStateError` cases: invalidRecord, storageUnavailable, lockUnavailable,
  staleDelivery, staleObservation, staleIntent. Descriptions contain no input content.

Key implementation functions are `adopt`, `validProducer`, `correlated`, `withLock`, `read`,
`write`, `normalizedBackground`, and the strict record decoders.

## Runtime files and ordering

All files are below the injected runtime URL's `organizer/` directory. The whole TTY path is
UTF-8 encoded as unpadded Base64URL. No basename collisions, path separators or guessed titles
participate in file identity.

```text
observation-<encodedTTY>.json
intent-<encodedTTY>.json
adoption-<encodedTTY>-<pid>-<startSeconds>-<startMicroseconds>.json
writer-<encodedTTY>.lock
```

The consumer owns adoption records. Each producer generation retains its immutable native
binding across TAVS restart. Its observation and intent delivery fields track the last adopted
tokens. New native IDs/application generations or devices cannot acquire an old producer's
binding. A new valid producer can adopt independently on a surviving surface.

Comparison plus atomic replacement is serialized by a per-TTY `flock`, with acquisition bounded
to 100 ms using monotonic time. Separate TTYs share no write lock. Existing 100 ms device writing
was not changed. Temporary files are created with mode 0600 and renamed in the same directory.
Only those owned temporary paths are unlinked after use. Directory mode is 0700 when created.

Reads lstat first, require a regular file no larger than 8192 bytes, open with O_NOFOLLOW,
revalidate the descriptor identity/type/size and read at most 8193 bytes. Unknown top-level and
nested producer/native-binding fields fail closed. All read/parser errors are generic.

Records permit bounded absolute diagnostic paths (128 UTF-8 bytes), including repeated slash
separators from the isolated runner. Traversal and `/dev/tty` aliases are rejected. Only concrete
`/dev/tty*` paths can adopt, and only when the injected/real device and live generation agree.
Valid ordinary intent can publish independently of a corrupt observation. Synthetic intent
requires an intact current observation with the same TTY/device/producer/delivery and a live
producer. It never rewrites observation JSON.

Observed timestamps order observations. Intent render timestamps order one continuing delivery;
a token matching the newest meaningful observation can supersede the previous delivery even
when the previous synthetic render timestamp was later than that new intake timestamp.

## Adoption and cue boundary

`coverage(for:)` must receive a fresh row from a successful catalogue refresh. The single-row API
cannot independently distinguish a cached row or count duplicate TTYs. Its mappingIssue guard
consumes the native catalogue's missing/ambiguous mapping evidence. Parent must preserve that
call boundary, as documented in source.

First adoption requires exact producer generation/device and current foreground-family
correlation. An already adopted observation retains coverage only for the same delivery and
continuing producer/device/native lifetime; backgrounding changes its status to last-known.
A new observation delivery requires current foreground correlation. Intent matching an already
adopted meaningful delivery may also remain valid after foreground changes.

`attentionEligible` is a cue boundary, not just physical correlation:

- Verified Claude complete/Stop or permission/PermissionRequest, Notification, permission_prompt.
- Verified Codex complete/agent-turn-complete with a real responseID present.
- Unverified agents, manual event=nil, unsupported associations and missing Codex IDs are false.

Other physically adopted states remain observations. Later processing/resumption consumers must
validate the appropriate supported state/event association independently. No provider IDs are
invented. Missing response IDs remain nil.

## Red/green evidence

Exact command family used, always through the isolated runner:

```bash
TAVS_TEST_HELPER_BIN=/tmp/tavs-phase3-20261012T105131/build/arm64-apple-macosx/debug/TAVSApp \
  tests/run-isolated.sh swift test --package-path src/macos/TAVSApp \
  --scratch-path /tmp/tavs-phase4-20261012T114102/build --filter TerminalVisualStateTests
```

Remove the filter for the full Swift suite. Each runner retains its command.log under its
private fixture directory. Log prefixes below expand to:
`/var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/`.

- Tests first: `tavs-isolated.TXDMXo/command.log`, exit 1 because the three new types did not exist.
- Initial implementation: `tavs-isolated.23uspC/command.log`, exit 1 for private nested adoption
  access. Corrected the nested type to fileprivate for its strict decoder extension.
- First behavioral run: `tavs-isolated.PyAO7j/command.log`, 21 tests, one fixture-path failure.
- Follow-up: `tavs-isolated.i2vzY7/command.log`, 22 tests, same diagnostic path failure exposed
  repeated separators produced by the isolated runner. Fake paths remain diagnostic-only.
- New meaningful delivery versus later synthetic render: `tavs-isolated.VAE6mA/command.log`,
  one red regression with staleIntent. Fixed token-aware intent supersession under the same lock.
- Independence regression: `tavs-isolated.5eE4zH/command.log`, one red regression because a
  corrupt observation blocked ordinary intent. Kept the two resources independently writable.
- Color bound regression: `tavs-isolated.J2tMlw/command.log`, one red assertion because arbitrary
  leading whitespace was trimmed by PauseVisual. Added the 32-byte bound before normalization.
- Final focused green: `tavs-isolated.jNtRZx/command.log`, **25 tests, zero failures**.
- Final full green: `tavs-isolated.zT00pM/command.log`, **262 tests, zero failures**, 2.160 s.
- Both owned new files produce no whitespace diagnostics from
  `git diff --no-index --check /dev/null <path>` (exit 1 denotes the added-file difference).

The 25 tests cover exact and persisted adoption, missing/ambiguous mappings, retained versus
new backgrounded deliveries, exit/PID-start/device reuse, native terminal/application reuse,
new producer adoption, intent-only and diagnostic records, unverified/manual/unsupported cues,
real/missing provider IDs, bounded and normalized colors, malformed/unknown/future/oversize/
symlink/directory inputs, corrupt adoption, stale synthetic tokens, meaningful delivery
supersession, same-TTY competing publications, lock timeout and ten concurrent distinct TTYs.

## Capture notes for parent

Observed actions: tests preceded implementation; schema/API assumptions were shared before
divergence; all writes stayed in two assigned files and owned isolated roots; tests established
two additional semantic defects, intent timestamp dominance and corrupted-observation coupling,
before fixes. Byte bounds were tightened after a red normalization regression. The final check
used XCTest's actual executed-test count, not Swift Testing's separate zero-test footer.

Parent should fold these observations into its required meta-thinking capture with truthful
model attribution. This worker was prohibited from editing repository docs or capture files.

## Limits

No UI, native Ghostty requests, device writes, live hooks, shell suites, agent classification
runtime probes, real-home scheduling or preferences were exercised. Source tests prove the
injected metadata/ordering contract only. Live/native acceptance remains parent goal work.
The shared scratch build is idle and available for parent integration verification.
