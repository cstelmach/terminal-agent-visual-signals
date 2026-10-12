# Phase 4: observation and background-intent records

Last Updated: 2026-10-12
Version: 1.0
Scope: read-only source inspection; no live hooks, native calls, GUI or personal-state reads.

## Recommendation

Reuse `ProcessGeneration`, `ProcessIdentity.foregroundFamilyContains`, `GhosttySurfaceID` and
the existing runtime-root convention. Keep two small, independently atomic JSON files per TTY:
one meaningful observation and one ordinary background intent. Preserve one native adoption
binding per TTY/producer, owned by the consumer. Do not derive identity from titles, directories,
the legacy title SESSION_ID, `kill -0` or numeric PID alone.

The first adoption requires current native evidence and current foreground-family evidence.
An observation already adopted to that exact native lifetime can remain last-known while its
verified producer continues on that device, even when another process becomes foreground.
Its age changes display information; age alone is neither proof of exit nor proof of validity.

## Existing foundations

- `process-identity.swift:4-9`: a Codable/Hashable PID plus kernel start-seconds/microseconds.
- `process-identity.swift:17-31`: `PROC_PIDTBSDINFO` verifies the PID, generation, non-zombie and
  non-exiting status, plus parent PID, group, controlling device and foreground group.
- `process-identity.swift:33-37`: device lookup requires a character device under `/dev/tty`.
- `process-identity.swift:40-57`: foreground correlation requires current source and foreground
  generations, equal controlling device, valid foreground group, and membership in that group.
- `ghostty-catalog.swift:4-20`: native application generation plus opaque terminal ID and exact
  TTY association, with missing/ambiguous mappings made explicit.
- `ghostty-catalog.swift:119-148`: native decoding rejects duplicate IDs and marks duplicate TTYs
  ambiguous. Do not adopt against those rows.
- `sessions-model.swift:93-118`: catalogue refresh is already the appropriate point to revalidate
  observations and publish honest row coverage. A failed/empty refresh retains last-known rows.
- `mute-gate.sh:22-34`: `$TAVS_RUNTIME_DIR`, otherwise UID-namespaced `/tmp/tavs-$UID`, is the
  shared runtime convention. New state belongs in its `organizer/` subdirectory.
- `title-state-persistence.sh`: legacy title IDs are small random display identities persisted
  by TTY name. They are not a native lifetime authority. Preserve their existing display role.

## Minimal schemas

Use explicit Unix timestamps, not JSONEncoder's default Date epoch. Suggested field names are
illustrative; choose one spelling and cover it with shared shell/Swift fixtures.

```json
{
  "schema": 1,
  "tty": "/dev/ttys001",
  "device": 123,
  "producer": {"pid": 43, "startSeconds": 1791780000, "startMicroseconds": 1},
  "deliveryID": "generated-once-at-intake",
  "observedAt": 1791780000.25,
  "provider": "claude",
  "state": "permission",
  "event": "PermissionRequest",
  "responseID": null
}
```

Observation fields should be typed enums or bounded allowlisted strings. Retain supported
provider response/turn IDs when present; absence must stay absent. Provider session IDs can
remain legitimate metadata for existing icon behavior but are not terminal identity. Neither
session ID nor a generated delivery UUID substitutes for a real provider response/turn ID.

```json
{
  "schema": 1,
  "tty": "/dev/ttys001",
  "device": 123,
  "producer": {"pid": 43, "startSeconds": 1791780000, "startMicroseconds": 1},
  "deliveryID": "same-intake-identity",
  "updatedAt": 1791780020.25,
  "background": "#804040"
}
```

Use a normalized `#rrggbb` color or the literal `reset`. No arbitrary OSC, shell syntax,
palette, foreground, title or BEL content belongs in this intent record. Timer-generated idle
colors update only this file and retain the originating producer and delivery identity.
They do not update meaningful observation time, state or occurrence identity.

A background intent may be produced with no meaningful event, for example direct normal
signaling. It still needs a verified producer/lifetime; absence of an observation is not itself
a reason to fabricate one. Invalid/unavailable identity means missing intent coverage.

## Native lifetime adoption

The hook helper need not enumerate Ghostty on each invocation. Let the catalogue consumer adopt
unbound records once against an exact current row. Remember the adopted `GhosttySurfaceID`
alongside TTY/device and producer generation. This can be a small runtime adoption record if
it must survive TAVS restart; a memory-only cache cannot remember that a prior record belonged
to another native lifetime after relaunch.

Do not rewrite hook-owned observation or intent JSON to add binding, because the GUI could
overwrite a concurrent hook update. A separate per-TTY adoption record is the smallest useful
way to preserve that fact without shared whole-file read/modify/write. Only the consumer owns
this record. It is a runtime correctness guard, not a provenance ledger.

Adoption/reading algorithm:

1. Parse a small regular file as data, validate schema, bounded strings/enums, timestamps,
   absolute concrete TTY, positive PID/start time and device. Reject `/dev/tty` aliases,
   missing/ambiguous native associations and unavailable producer evidence.
2. Require the record TTY to match exactly one current native row. Re-read its device metadata.
   Inspect the row's foreground PID immediately and obtain its current kernel generation.
3. For first adoption, call `foregroundFamilyContains` with the record producer, the freshly
   inspected native foreground generation and current device. An ancestor being alive is
   insufficient. The same numeric TTY/PID is insufficient.
4. Store the exact surface/application generation with the adopted producer. Subsequent records
   from that continuing producer must agree with the remembered binding. A prior binding to a
   different application/terminal ID cannot silently migrate to a new native surface.
5. For a retained already-adopted observation, require the same native ID/TTY/device and the same
   live producer generation/device. Do not require that producer to remain foreground merely to
   show last-known coverage. A new occurrence still requires valid current correlation; retention
   must not become permission for new uncorrelated attention.
6. Producer exit, PID reuse, device mismatch, missing native lifetime or failed generation lookup
   makes the observation unavailable/ineligible. Failed catalogue refresh means last-known
   coverage, not authorization to adopt against cached rows.
7. A new foreground producer on a surviving surface may be adopted independently. Delayed old
   workers keep their original producer, delivery and native binding, so they cannot acquire the
   new producer/surface identity from the current environment or current TTY filename.

The stored binding must match the particular producer being adopted; a TTY-wide cookie alone
would allow an old producer's late write to masquerade as the current owner. Never copy a newer
adoption binding into an older producer's frozen token.

## Write and synthetic-update rules

- Allocate delivery identity once at adapter intake, before any delayed/background work.
- Capture the actual emitting process generation once. Workers inherit that identity rather
  than inspecting their own later PPID or choosing the TTY's current foreground process.
- Publish via same-directory temporary file and atomic replacement. Per-TTY files prevent
  cross-session lost updates. Atomic replacement does not itself establish chronological order.
- Before accepting a delayed synthetic intent, compare its frozen delivery identity against the
  current meaningful observation and validate its producer/binding. A worker from an older
  delivery must not repaint after a newer processing delivery. If conditional replacement is
  promised under same-TTY concurrency, the comparison/replacement must be serialized; an
  unlocked read-then-write is a race. Reuse the later shared per-TTY serialization design.
- The current tool-error delayed branch calls the core trigger again with `processing` or
  `subagent`. Mark this as synthetic and retain the intake token, otherwise it creates false
  resumption observations and eventually false automatic-focus transitions.
- New observation capture belongs before legacy `should_change_state` suppression. Repeated
  colors are not proof that no new meaningful delivery occurred.
- Updating intent must precede suppression handling in `send_osc_bg`; muted rendering still
  changes the latest desired ordinary background.

## Producer metadata without arguments or body reads

Public libproc declarations in the installed SDK are sufficient:

- `libproc.h:99`: `proc_name(pid, buffer, buffersize)` supplies a bounded public process name.
- `libproc.h:102`: `proc_pidpath(pid, buffer, buffersize)` supplies executable path, not argv.
- `sys/proc_info.h:64-78`: parent PID, `pbi_comm`, `pbi_name`, process group, controlling device
  and foreground group are available through the same BSD info structure already read.

Use basename or a small allowlisted executable-name classification only transiently for ancestor
selection. Do not retain the full executable path or log it. Walk a bounded parent chain from
the actual hook/helper caller, verify generation at each relevant step, and stop on uncertainty.
Capture the agent's generation, not the short-lived hook shell's generation.

Known `claude`/`codex` executable basenames can help select a candidate. Generic `node`, `bash`
or `zsh` cannot by themselves identify the provider. A mutable/truncated process name is a hint,
not sufficient authority. The adapter can state its provider, but PID/generation plus exact
ancestry, controlling device and current foreground-family validation must prove correlation.
If the actual runtime is ambiguous without argv, report unavailable producer coverage instead
of reading arguments or guessing from titles. Do not persist a runtime version assumption.

The existing `resolve_tty` ancestor walk is destination discovery only. Its `ps -o tty/ppid`
checks do not establish the producer generation or current foreground-family correlation.
The existing `foregroundFamilyContains` is the reusable final correlation check.

## Headless compatibility boundary

`TAVSAppMain.main` currently routes any isolated Sessions environment into SwiftUI before it
parses headless arguments. New headless verbs must take precedence over this branch, including
when launched from the isolated development app. Otherwise a helper invocation can unexpectedly
open another UI process.

Use the existing `--validate-config` branch for a safe support query qualifier. Old binaries
already enter that branch and exit on a known validation error, avoiding unknown-flag fallthrough
into `TAVSApp.main`. Only invoke new intake/publish verbs after a successful explicit version
response. Do not probe the new flag itself against an unknown installed helper. A missing or
unsupported helper leaves organizer coverage unavailable without breaking ordinary signals.

Select the explicit source-built/test helper in tests. Never choose another installed helper
after an explicit override fails. Feed new helper structured small allowlisted values, and emit
generic parse errors without echoing raw argv/stdin. Existing debug code in `trigger.sh:125-189`
currently records process args, directories and raw payload and must be removed/restricted in
the touched intake paths.

## Focused tests

Extend existing injected-lookup style from `process-identity-tests.swift`; no live process is
needed beyond its existing self-generation test.

1. Exact device/foreground generations adopt once; missing and duplicate native TTYs reject.
2. Same PID with changed start microseconds rejects; same TTY name with new native ID rejects
   an old persisted adoption. Ghostty generation changes reject even if terminal IDs match.
3. Already-adopted live producer moved to background remains last-known; dead producer rejects.
4. An old observation never first-adopts after producer exit or after a different native binding.
5. Invalid JSON, unsupported schema, shell syntax, malformed color, future/nonfinite timestamps,
   oversized fields and unknown state/provider fail with metadata-only diagnostics.
6. Synthetic idle changes only intent and preserves meaningful time/delivery/state.
7. A delayed tool-error synthetic branch cannot imply meaningful processing/resumption.
8. Ten separate TTY files retain independent observations/intents during concurrent publication.
9. Repeated supported completion ID preserves provider identity; missing ID remains missing.
10. Legacy helper support query exits through the known validation branch; no GUI is launched.
11. Debug-enabled prompt/tool/answer sentinels never appear in records or diagnostics; permission
    mode, cwd/session identity and existing context fallback metadata retain their allowed uses.

## Limits and unresolved empirical questions

No native provider/runtime names were inspected, so actual installed Claude/Codex process-name
classification remains unverified. The installed headers prove API availability, not that those
executables expose distinguishing names. Dedicated runtime acceptance must establish it later.

The catalogue PID is used as foreground evidence in current source and SPEC. This report does
not independently prove the installed Ghostty property's behavior. Current-generation/group
checks should reject a value that does not actually belong to the current foreground group.

No application writes, native enumeration/navigation, live state reads or shell suites were run.
