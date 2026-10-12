# Phase 6 current render shell integration

Status: shell source complete; safe fixtures and coordinated native renderer integration green.
Date: 2026-10-12
Scope: shell half of confirmed Codex R2. Parent owns native implementation, docs and commits.

## Changes

- One process-local current render collects exactly23 typed NUL-delimited fields. No style request
  file or pending OSC history is written. Managed helper uses safe existing schema1 query.
- --managed-render receives marker/runtime/TTY/frozen context/synthetic flag. Actual managed output
  preserves dedicated native scope; only metadata/support queries clear it.
- send_osc_bg queues semantic background instead of painting early. Palette apply/reset, both title
  APIs, iTerm2 image set/clear and fresh bell queue typed values. Native owns all OSC encoding.
- Outside a batch these APIs use an implicit one-item flush, with the same typed writer.
- Removed raw emit_osc, and own newly orphaned OSC palette encoders/managed-background shell bridge
  after checking every tracked caller. Existing typed forced reset/check-context/reconcile remain.
- Each synchronous trigger flushes once. Complete/idle start and delayed tool-error callbacks flush
  before forking. Every worker stage starts a fresh empty batch. Synthetic bells remain off.
- Hook exit0 behavior is preserved for agents. Flush returns native3 for stale or1 for unavailable;
  malformed/missing/unsupported helper responses fail closed, with no raw fallback.
- Idle last_applied_stage advances only after successful flush. Status3 alone stops the worker;
  other failures skip/retry, and max-runtime whole reset retains its existing typed path.
- TITLE_LAST_SET and saved title state update only after exact rendered outcome. Restricted,
  unaffected, stale or failed renders cannot commit the candidate title as delivered.
- Existing Kitty opt-in image backend is unchanged and remains explicitly outside the Ghostty
  renderer acceptance. No generic process runner or new adapter was added.

## Test-first evidence

Backups before edits: /tmp/tavs-phase6-routing-20261012T165000/backup/render-shell/.

New regression run tavs-isolated.86CpkV/command.log was red before source changes. The existing
processing hook overwrote the stub helper's new RESTRICTED paint with direct ordinary title
output, reproducing confirmed R2.23field batch, deferred-title and transient-retry contracts were
also red before their APIs existed. Full failures are retained, not overwritten.

New safe fixture cases verify:

- Newly active native rule cannot be overwritten by queued ordinary style.
- Exactly23 Unicode-safe fields, no early output, one flush, typed palette/title/image/bell values.
- Title-state persistence occurs only after rendered, with no save after restricted.
- Transient idle failure retries the same stage before marking it applied; forced-reset path remains.
- Old prefix-only renderer fails closed and synthetic batches contain no alert bell.
- Background-disabled styling carries no background request.

Connected safe helpers now understand managed-render, preserving fresh mute/PID/heartbeat checks.
The legacy emit-osc suite was audited before running: env-i dropped helper/private roots and old
assertions required opaque history. Its fixture now keeps all roots private and uses a typed safe
helper. Assertions retain dispatch, candidate registration, ordinary output and mute behavior,
while proving no persistent OSC cache. Owned workers are explicitly killed/reaped in teardown.

Python title composition captures the typed current payload into a fixture file and preserves all
original title/face/order assertions. Idle source checks use typed queue/flush expectations.
Title persistence functions remain covered separately. No production fd check was weakened.

## Verification before native release

-41/41 safe Bats fixtures green (managed22, idle6, emit6, liveness7):
  tavs-isolated.X7nnuE/command.log.
-58/58 scoped Python checks green (title composition, idle worker, title persistence):
  tavs-isolated.0DBw00/command.log.
- Six production shell files each passed a separate /bin/bash -n check; git diff --check passed.
- Shellcheck found only existing SC2034 cross-module unused notices. Existing intentional zsh
  parameter syntax in title-management produces SC2296 in Bash-only lint; excluding that dialect
  notice adds no new warning. No unrelated variables were removed.

Infrastructure/fixture failures retained:

- rbJjTg: system python3 lacks pytest. Used installed pytest, no installation attempted.
- eN4st7:57 Python green, one unchanged home-shortening test failed because runner HOME contained
  /T// but cd/pwd collapsed it. The single fixture now normalizes HOME before cd and preserves
  its original tilde assertion. No product get_short_cwd source change was made.
- HHPj8o: title fixture exposed missing-debug-function return1 after successful queue. Title helper
  now returns success explicitly on queued success and failure on queue failure.
- ScUOOX/pADYuN: old raw-route assertions and one1second idle retry boundary were exposed during
  connected migration. Assertions now target the finite batch, and the retry fixture has2seconds
  so first/second attempts are not truncated by Bash integer-second rounding.

All log roots above are /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/.

## Prepared actual acceptance

background-intent now has12 cases. New owned-PTY tests activate a hard rule after collection but
before flush, asserting only restrictive palette/background/title/image clear and no ordinary
style/bell; and supersede a frozen synthetic batch before flush, asserting zero style/intent.
Existing actual intent/privacy/recovery/continuing-owner cases remain. These are held until parent
releases the rebuilt renderer helper. No actual native catalogue/Automation/installed app ran.

## Owned paths

src/core/{organizer-state,terminal-osc-sequences,trigger,idle-worker-background,
          title-management,backgrounds}.sh

tests/integration/{managed-background,background-intent,idle-worker-mute,emit-osc,liveness}.bats

tests/{test_title_composition,test_idle_worker}.py

No Swift edits/builds, Git writes, real-home suites, deployment, personal session shutdown,
new control plane or live/bulk deletion occurred. Parent handles final verification and commits.

## Final actual renderer integration

Parent released /tmp/tavs-phase6-routing-20261012T165000/build/arm64-apple-macosx/debug/TAVSApp
following full390 Swift tests (Z2PMal) and explicit build9nYwxU. No Swift build ran in this worker.

Combined53/53 Bats green with that explicit helper through tests/run-isolated.sh:

- background-intent12, including8 actual owned-PTY cases and4 stub/static diagnostic cases;
- managed-background22;
- idle-worker-mute6;
- audited current-render emit-osc6;
- liveness7.

Complete log: tavs-isolated.I36HTq/command.log under the private TMPDIR recorded above.
No test session/fixture worker remains running.

Actual owned-PTY R2 acceptance confirms:

- Activating a hard rule after ordinary collection but before flush paints current restrictive
  background/title/palette reset/image clear. Queued ordinary title, palette, image and alert BEL
  are absent. Latest ordinary background intent remains #112233 for later current restoration.
- Superseding a frozen synthetic batch before flush rejects it with status3 and emits neither
  style bytes nor semantic intent.
- Existing intent/privacy, current soft policy, public recover/resume and continuing-owner cases
  remain green with the new renderer. No raw fallback or historical title/alert replay occurred.

Parent source review also identified premature debug labeling: queue success said write=ok even
if the batch later became restricted. It now says request=queued. Focused title-state/trace test
passed after that change at tavs-isolated.y6HCOc/command.log, with final Bash syntax/diff checks
also green. Parent independently reports audited230 Python checks green at2NwdoZ.

The standalone scoped recovery fixture retains its explicit synthetic-catalogue/job-control
limitation from the earlier report. The new nested-producer case uses actual owned ordinary
Bash job control with no native catalogue. Neither establishes actual provider events, physical
Ghostty mapping, native UI acceptance, or all terminal backends. Existing Kitty subprocess image
styling remains unchanged and outside the Ghostty release scope.

Files are released for parent atomic commits. This worker made no Git mutation, native Ghostty
call, installed-app deployment, personal-session shutdown or live/bulk cleanup.
