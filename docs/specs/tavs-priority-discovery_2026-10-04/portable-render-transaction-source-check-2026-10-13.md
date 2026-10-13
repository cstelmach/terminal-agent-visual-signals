# Portable ordinary transaction source review

Last Updated: 2026-10-13 (Europe/Vienna)
Version: 1.0

## Parent verification after review

1a914a7 shares the original output lock/budget with publication and completion;
b805282 assembles ordinary rendering and exact obsolete-effect cancellation.
UeqMyv was the worker red before its new interfaces; CBXR3V passed 10 worker tests.
pu6NAN was the renderer red; NeBG2B passed six actual owned Mac PTY cases.
The retained review inspected the 74-check stage. The parent then added changed-snapshot and
completion-deadline cases. Final yXsIbe: 76/76 portable checks in 1.912 seconds. Full Swift
mssSCZ: 561/561 in 10.455 seconds. Those extra regressions passed on first addition; no red
claim is made for them. Source syntax and staged checks pass.

Cancellation after successful output is deliberate: failed writes retain retry work. The
shared lock prevents cooperating controllers from changing effects during output; exact
snapshot comparison also refuses unexpected changes. Partial completion still reports failure
with known bytes, including fully delivered output with failed metadata completion. No helper
verbs, forced reset/reconcile, hook routing, Linux support or complete H1 claim is made.

## Retained bounded source review

# Portable ordinary render transaction source check

Bounded read-only inspection of portable_renderer.py, portable_device_writer.py
and their renderer/worker tests. No tests, apps/devices, goal calls, project edits
or fingerprints. Parent reports 226r9z (74 portable) and mssSCZ (561 Swift) passing;
I did not run or independently verify those results.

## Conclusion

No concrete remaining transaction defect found in the inspected source.
Post-output effect cancellation is an explicit behavioral difference from native
pre-output cancellation, with coherent failure handling in this implementation.

## Checked transaction boundaries

- The writer creates one monotonic 100 ms deadline before pipe/fork dispatch.
  before_open publication, device validation/open, output-lock acquisition,
  prepare, finite writes and after_write all receive that SAME deadline. No
  nested helper renews it. Late open/lock/prepare guards remain present.
- before_open captures/pins the marker revision and publishes requested background
  under the existing private stable per-TTY output_lock, then releases that lock
  before device open. This preserves valid latest intent when open fails.
- prepare runs under the reacquired SAME output lock. It checks pinned revision,
  strict current/synthetic context, re-publishes requested background, checks
  ordinary ownership with actual descriptor, selects current intent, and checks
  target/revision again before returning bytes.
- Byte ordering is legacy OSC104/110 cleanup prefix when required, finite palette,
  current background, title, iTerm image framing and ordinary audible bell.
  Synthetic suppression applies to the audible bell only. Style-only requests
  publish no background intent; obsolete presentation can still require a current
  background reset. No raw stream replay or controlled composition is added.
- after_write is called only AFTER all payload bytes have been accepted, while the
  output lock is still held. It re-reads each obsolete effect and requires FULL
  snapshot equality before replacing only that record with active=false. Missing,
  malformed or changed snapshots fail; a new effect cannot be canceled by ID alone.
- Device partial/failed writes do not invoke after_write, so active residual work
  remains retryable. Callback failure after complete output propagates a known
  full bytes_written count; successful pixels and successful metadata completion
  are not conflated. Cancellation itself remains inside the original deadline.

## Scope and verification limits

The API returns writer success/failure, not the final native capability/status
protocol. No hooks, routing, forced reset, reconcile or H1 completion is claimed.
Metadata cancellation failure can leave some records canceled and others active
AFTER complete output; callers must preserve that failure and avoid blindly
replaying alerts. Parent timeout can still report unknown output count, and child
kill/poll is not the same as proven retirement. Test fixtures have separate owned
child drains, retaining the original caller deadline.

Useful focused regression coverage: changed/missing obsolete snapshot after
successful output must fail with complete bytes and leave the changed record
uncanceled; after_write deadline expiry must not report success; partial device
write must never enter cancellation. Existing tests exercise failed output retry
work, held-lock callback execution, before-open retention and synthetic byte order.
These are bounded verification suggestions, not additional demonstrated defects.
