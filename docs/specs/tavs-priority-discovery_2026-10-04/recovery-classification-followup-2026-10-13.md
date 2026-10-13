> Read-only source check of the first correction draft on baseline `298230a`.
> Its vanished-owner/live-hint finding was reproduced and corrected in `5696f4c`, with a direct
> live-hint test added. See [final review corrections](final-review-corrections-2026-10-13.md).
> Original: /tmp/explorer-tavs-recovery-classification-check-20261013.md.

# Recovery classification diff check

Last Updated: 2026-10-13
Scope: current three-file recovery-classification diff and connected recovery source/tests.
Read-only source inspection. No builds, tests, devices, native apps or user payloads were accessed.

## Assessment

The four new cases match the implemented behavior. Positive device loss is the only new path
that marks an otherwise unverified registry-only hint vanished. Live or unverifiable registry
hints never become output targets. Malformed entries remain individual failures rather than
being reported as a failed registry directory. Native rows whose target capture failed preserve
their failure even when a separate cached lifetime on the same TTY was restored.

There is one pre-existing TTY-only reporting edge outside the four new cases: a vanished cached
lifetime can suppress reporting of a still-live registry hint. That should be addressed or
explicitly bounded before claiming complete registry reporting under TTY/owner reuse.

## Positive device-loss classification

`TerminalVisualStateStore.isKnownMissingTTY` requires all three facts:

1. A concrete accepted TTY path.
2. No current device number from `device(tty)`.
3. Positive `deviceMissing(tty)` evidence.

The default positive-missing helper uses `lstat` failure with ENOENT/ENXIO. A nil device lookup
alone, an inaccessible node, `/dev/tty`, or a currently present device does not satisfy this
helper. It has no device-write or process-selection path.

`VisualRecovery.apply:427-430` uses the helper only to choose `.vanished` versus `.failed` for
registry-only hints. Those paths append a report item; they do not call `captureTarget`, `write`,
`fanout` or native navigation. The empty registry file is preserved. The new
`testKnownMissingRegistryDeviceIsVanishedWithoutAuthorizingOutput` checks the classification,
no managed calls, retained file and persistent suspension state.

Existing `testEmptyUnverifiedRegistryEntryIsReportedAndNeverAuthorizesOutput` covers nil device
inspection without positive missing evidence. The current new diff does not add an explicit
live-device registry-only test, but source inspection shows the same no-output reporting branch.
A small live owned-PTY/no-cache case would close that direct coverage gap. A contradictory fixture
with `device != nil` and `deviceMissing == true` should still remain failed, not vanished.

## Individual malformed-entry failures

`registryHints:567-590` reports whole-directory failure only when the directory itself cannot be
validated/listed. ENOENT is an empty registry. A symlink or non-directory root fails validation;
no directory fallback is introduced.

Each invalid entry name is now an individual `.failed` item. The special legacy `_dev_tty` is
reported as `/dev/tty`; other invalid names are omitted from tty/reason fields. This avoids
leaking arbitrary entry text. A valid-looking name whose entry cannot be statted or is not a
regular file gets its own concrete-TTY failure. Entry symlinks and directories cannot authorize
output. Regular file contents are not read or interpreted.

The malformed-entry test checks healthy cached restoration alongside three failures, including
legacy `/dev/tty`, an unverified concrete TTY and an arbitrary invalid filename. It also checks
that the arbitrary filename is absent from serialized output and that no whole-directory failure
is emitted. Note that `_dev_ttys889` is structurally valid, so that particular failure tests an
unverified hint rather than a malformed-name branch. An entry symlink/directory or injected stat
failure is not covered by the four new cases; the source branch is nevertheless explicit.

`registry.items` is appended after hint deduplication. Consequently an individual malformed or
unreadable-entry failure cannot disappear merely because a healthy cached target shares its
TTY. This is deliberate conservative reporting of the damaged registry entry itself.

## Native nil-capture reporting and deduplication

When a fresh native row cannot be captured, `apply:403-405` appends a failed item containing the
native row's TTY but no `target`. Existing physical-target deduplication compares
`item.target?.physicalTarget` with a real fanout target. The nil-capture item cannot compare equal
to that real target and is not removed. Alias-registration replacement likewise only removes
items with that exact nonnil physical target.

`reportedTTYs` is used only to avoid an additional unverified registry-hint failure for a TTY
already reported by the native nil-capture item. It does not remove the original failed item.
Therefore the two new tests correctly distinguish:

- Unbound native row plus matching registry hint: one native binding failure, no output.
- Unbound native row plus independently valid cached target on that TTY: one binding failure
  plus one cached restoration, with `hasFailures == true` and reset output only to the cached
  verified lifetime.

I found no new hidden-native-failure path in this diff.

## Pre-existing hidden live-hint edge

`knownTTYs` is derived from all initial cached targets, including ones fanout classified
`.vanished`. `reportedTTYs` also includes vanished items. Both use the pathname rather than a
current lifetime. Consider:

1. Cache an owned TTY target for generation A and create its registry entry.
2. Positively invalidate A by changing its PID generation or marking its process exited, while
   the TTY node still exists.
3. Supply an empty successful native catalogue, or unavailable native enumeration.
4. Recover. Cached fanout returns `.vanished` for A; no output occurs.
5. The registry hint is skipped solely because its TTY appears in `knownTTYs`/`reportedTTYs`.

The result may contain only `.vanished`, so `hasFailures` is false despite a currently live,
unverified registry hint. This is not introduced by the new helper: the prior implementation
already skipped all hints sharing `knownTTYs`. The new `reportedTTYs` retains that broad behavior.
The four added cases do not exercise this combination.

Smallest correction if this reporting guarantee is required: suppress a registry-only hint when
there is an existing failed item for that TTY, or a valid/current handled restoration. A vanished
historical owner should suppress another vanished hint only when positive device-loss evidence
also proves the TTY node gone. Otherwise report the remaining live/unavailable hint as unverified
without attempting output. No target synthesis, process guessing, new registry format or file
cleanup is needed.

Regression: extend the existing known-owner-reuse recovery fixture with its matching regular
registry entry while the device stays live. Expect the old target `.vanished` and a separate
unverified registry hint `.failed`, no managed output. Repeat with known device loss; expect a
closed report with no false partial failure. Ensure a restored cached target still avoids a
redundant hint and a nil-capture native failure stays visible.

## Verification limits

The report verifies source paths and assertion scope only. It does not claim these tests passed.
Runtime evidence should come from the parent's isolated Swift execution. In particular, direct
live-hint no-output coverage and the pre-existing vanished-owner/live-hint dedup case remain
unproven by the four newly added tests.
