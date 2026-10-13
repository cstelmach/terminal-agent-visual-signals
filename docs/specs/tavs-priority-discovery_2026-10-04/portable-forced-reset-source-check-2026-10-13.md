# Portable forced-reset source review

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.0

## Parent verification after review

9ab0446 implements unchanged bound reset authority and cached target selection;
b600128 connects it to the bounded writer. The retained review describes a draft.
Its P2 was verified against managed-output-entry.swift:127-129. Regression 9nuDC1
reproduced reset from a live same-generation producer on another device. Removing
that case from orphan selection made WhWDhg pass 12 renderer cases. Actual producer
exit with its parent terminal still live remains accepted through unchanged bound
proof, not missing PID alone. Direct publication's invalid-producer branch remains
native-compatible; the entry selection is a separate restriction.

Initial reds: gthkkC (forced publisher absent), 2sYAE5 (cached selector absent),
kfS4v1 (reset writer absent). D3h7vy passed 17 intent cases; GeRYQu 16 ownership
cases. Final dRWtI2: 85/85 portable checks, 2.250 seconds. Full Swift 7hZtMI:
561/561, 11.947 seconds. Syntax/staged checks passed. The source reviewer inspected
code but did not execute these tests. No helper/routing/reconcile/Linux or complete
H1/native acceptance claim is made. Only owned actors/workers were terminated.

## Retained source-only review

# Portable forced-reset source check

Read-only review of current portable intent/renderer/cached-target additions and
their tests against native publication and managed entry selection. No runtime
actions, tests, devices, project edits, fingerprints or goal calls.

## Concrete finding

P2: portable_renderer.py:47-48 broadens the orphan entry route to a producer with
the SAME generation but a different current TTY device. An old delivery can still
have unchanged observation/latest/bound records and a valid continuing-owner
cached target, so this branch can emit the old palette/background/title reset.
Native managed-output-entry.swift:127 selects cachedTarget only for a missing or
different generation. With the same generation on another device, native goes
through target/captureTarget; continuingOwner rejects the device mismatch.

Smallest correction: remove the device mismatch from the renderer orphan
selection predicate. Keep the publication function's existing invalid-producer
branch, which matches the directly callable native publication contract. Add a
renderer regression retaining matching old records and a live same-generation
producer now on another device; require refusal before open and no old reset
publication/output. Existing tests cover actual exited producer, changed delivery,
changed bound copy, new observation and owner reuse, but not this entry distinction.

## Other checked boundaries

- Latest identity requires unchanged TTY/device/producer/delivery, independent of
  timestamp. Orphan publication also requires full latest equality with a bound
  copy, current target, observation no newer than intake and nonolder update time.
- Live publication delegates to current producer plus continuing-owner validation
  and strict synthetic observation. Missing lookup alone grants no authority;
  orphan output requires the retained full bound proof, matching native behavior.
- cached_target scans the requested TTY, includes effect-only targets, rejects
  conflicting physical owners/native aliases, and revalidates its final choice.
  Its rejection of unknown/malformed cached peers is intentionally stricter than
  native cachedTarget filtering, preserving the ordinary portable guard.
- Both before-open publication and prepare publication use the existing output
  lock and original writer deadline. Prepare checks captured marker revision and
  current descriptor/target before returning bytes. No new deadline is created.
- Forced title is at most 512 UTF-8 bytes and rejects control/format characters.
  Palette reset is OSC104 BEL, plus OSC110 BEL only for obsolete global cleanup;
  background follows current intent and title follows background. No audible bell
  or image output is added. Live native control is refused through the existing
  portable unavailable path instead of claiming managed composition.

Source-only conclusion: one introduced entry-selection mismatch above; no further
concrete forced-reset defect found. No reconcile, capability or H1 completion
claim. Tests were inspected, not executed.
