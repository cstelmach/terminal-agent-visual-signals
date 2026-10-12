# Phase 6 shell routing report

Status: production shell routes complete and verified with the coordinated source helper.
Date: 2026-10-12
Baseline: f0cbc45, preserving handed-off parent edits and concurrent Swift work.

## Changes

- organizer-state validates managed schema through safe --validate-config support query. Only
  metadata/support queries clear native test scopes. Actual managed calls retain dedicated scope.
- Semantic backgrounds use --managed-background, with no missing, old or failed-helper raw fallback.
- Synthetic failures and stale status suppress later palette/title output. Background-disabled
  synthetic dispatch uses --managed-check-context before emitting nonbackground signals.
- Standalone copied shellrc remains Bash 3.2/zsh compatible and requests register/current policy
  instead of parsing and printing lock or pause paints itself.
- Idle max-runtime reset uses one typed --managed-forced-reset request. It never forces the shell
  mute flag off or emits raw palette/title/reset bytes around validation.
- Debug replay requests current --managed-reconcile for the device. It never cats pending OSC,
  consumes historical titles/bells, or treats a filename as output authorization. Native entry
  worker implements the exact cached-target resolver for reconciliation from another TTY.
- Nonbackground muted output is discarded. Compatibility buffer functions cannot create or
  republish opaque pending caches, including an inherited buffer around recovery.
- Mute/lock state is read once freshly before dispatch instead of duplicated stage-0 predicates.
  REQUESTED_MUTED restores the current requested soft cause only with active persistent policy;
  MUTE_LEVEL=hard cannot outlive a finite lock or unlock grant. Independent soft pause remains.
- Candidate registry age does not prune potentially live owners.

## Test changes and safety

- Added managed-background cases first. Four cases were red against the handed-off partial source:
  forced idle spill, stale idle palette spill, pending resurrection, and raw debug replay.
- Regular-file routing fixtures use explicit safe helpers and never weaken production native fd
  validation. Semantic/privacy background-intent cases now use owned PTYs and actual helper.
- liveness teardown no longer touches live /tmp/tavs-UID wildcard paths. All liveness roots,
  output, preferences and HOME/CFFIXED_USER_HOME/ZDOTDIR are fixture-private.
- mute-gate, idle-worker-mute and shellrc tests preserve owned fixture logs instead of deleting
  live or wildcard paths. Fixture workers are explicitly killed and reaped before inspecting.
- Shellrc unit cases assert typed dispatch, standalone/copy behavior, marker suppression and
  absence of raw output. Native policy semantics are separately verified on owned PTYs.

## Verification so far

Commands used tests/run-isolated.sh with the explicitly supplied source-built baseline helper,
which has no managed capability. Each fixture suite substitutes an explicit safe stub locally.
No real native catalogue, Ghostty Automation, personal session, installed-app deployment or
real preference change ran. Installer tests modified only fixture-owned shell files.

- Four initial red regression cases and seven handed-off routing cases:
  /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.NkRQoT/command.log
- 65 fixture Bats passed together (15 managed, 18 mute-gate, 6 idle-worker-mute,
  7 liveness, 19 shellrc):
  /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.uNFUSX/command.log
- One additional independent-soft/grant regression gives managed 16/16:
  /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.YgbZbs/command.log
- Four non-native background-intent cases passed:
  /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/tavs-isolated.Ed4Toa/command.log
- Each of six changed production shell files passed separate /bin/bash -n checks.
  Standalone shellrc also passed /bin/zsh -n. git diff --check passed.
- Shellcheck warning scan found existing SC2034 cross-module variable notices and SC2174 mkdir
  behavior, no new quoting warning. Those unrelated notices were not changed.

## Owned paths

src/core/{organizer-state,terminal-osc-sequences,idle-worker-background,trigger,mute-gate}.sh
src/shell/tavs-shellrc.sh
tests/integration/{managed-background,background-intent,liveness,idle-worker-mute}.bats
tests/unit/{shellrc,mute-gate}.bats

Parent owns Git commits, docs and final meta capture. No Swift build or Swift edit ran here.
Native helper capability should advertise only once all entry verbs (including context-only
validation and exact cached reconciliation) are implemented. Actual native PTY tests remain
pending. No installed app or physical native acceptance is claimed.

## Policy parity follow-up

Parent source review identified legacy shell acceptance of absent app PID/heartbeat and future
heartbeat. Fresh inspection of visual-restriction-policy.swift confirmed the gap. New unit case
was red for missing PID at tavs-isolated.rsL8lx/command.log before the fix. Shared shell now
requires a positive live Int32 PID, decimal until/written, positive written no later than now and
at most 120 seconds old, valid Boolean/requested cause and schema, recognized reason, and legacy
hard_lock exclusion. Decimal conversion preserves leading-zero values without Bash octal parsing.
Fixtures for independent expiry/staleness cases now provide otherwise-valid metadata.

Combined fixture result is now 67/67: managed16, mute-gate19, idle-worker-mute6, liveness7,
shellrc19. Log: tavs-isolated.kCRe3n/command.log under the same private TMPDIR shown above.
Four non-native background-intent cases also pass at tavs-isolated.fq4KA2/command.log.

The standalone muted-background native test was corrected to expect the current explicit soft
pause paint (#314159), preserving a reset intent without emitting its reset over the policy.
Public CLI recovery/resume acceptance is prepared in background-intent using the existing PTY
harness. A live owned child generation seeds a temporary catalogue plus nonempty target
allowlist, and a fixture wrapper verifies the public CLI saved the expected marker before the
native helper is invoked. It asserts 104/110/111 recovery, updated current soft color on resume,
pending invalidation, no historical title, and no BEL outside OSC framing. No Automation route
is used. This acceptance is held until the coordinated native helper is released.

## Final verification with coordinated source helper

Released helper: /tmp/tavs-phase6-routing-20261012T165000/build/arm64-apple-macosx/debug/TAVSApp.
Entry worker reported full363 Swift tests/build/capability green before releasing this binary.
This worker did not build Swift or invoke the installed app.

- Combined 76/76 Bats green using the released helper through tests/run-isolated.sh:
  tavs-isolated.ip8QKp/command.log. Breakdown: background-intent9, managed-background16,
  mute-gate19, idle-worker-mute6, liveness7, shellrc19.
- Enhanced public recovery acceptance additionally exercises actual standalone shellrc startup,
  managed ordinary background, managed forced reset under soft policy, and typed debug reconcile
  on the same owned fixture-scoped PTY. Focused test green at tavs-isolated.B4vX1P/command.log.
- Final background-intent9 regression green at tavs-isolated.6l7hWj/command.log.
- Final separate six Bash syntax checks, standalone zsh syntax and git diff --check green.

### Retained acceptance failures and limits

The enhanced fixture initially tried a synthetic forced reset without a valid agent observation;
it correctly rejected the stale delivery. An interactive shell also put each helper job in a
separate foreground process group while the static fixture listed the parent as foreground.
Exact binding rejected that mismatch. Fixing the fixture required job control disabled in the
owned shell (set +m) and a valid Claude observation before synthetic reset. No source validation,
identity, deadline or device checks were relaxed. Failure logs are preserved:

- tavs-isolated.SYPeX3/command.log: missing observation rejected the synthetic forced reset.
- tavs-isolated.RY2VvY/command.log: interactive foreground mismatch rejected native scope.
- tavs-isolated.BMYhQW/command.log: unknown provider could not publish a valid observation.

The final scoped PTY case proves typed shellrc dispatch and native managed policy using an owned
PTY with job control disabled and a synthetic catalogue seeded from its real process generation.
It does not prove actual Ghostty Automation mapping, interactive job-control acceptance, or the
physical native UI. Unscoped production shell registration authenticates ancestry owner directly;
the native scoped mapping path still needs separately authorized dedicated physical acceptance.

The public CLI recovery wrapper confirms suspension/resumption persistence before actual native
entry. Recovery emits 104/110/111, invalidates historical pending bytes, and resume applies the
updated current requested soft rule without old title or standalone alert BEL replay. OSC frame
BEL delimiters are retained and distinguished from standalone alert BEL.

All owned shell implementation/tests are ready for parent atomic commits. No real-home suite,
installed-app deployment, real preference change, native Automation, personal session shutdown
or bulk/live-path deletion ran. Fixture installer changes and native pending invalidation stayed
inside owned roots.

## Continuing-owner synthetic validation regression

Parent reproduced and fixed a Swift checkSynthetic regression in commit 2ee25f7. The observation
producer may be a live nested process while target ownership remains with its continuing outer
shell. Same TTY/device and latest live observation guards remain. Parent released the rebuilt
helper after full364 Swift tests passed; this worker made no Swift change or build.

Added exactly one case to the existing background-intent suite and reused _owned_pty. The owned
outer shell registers its plain TTY; a nested shell publishes a Claude-provider observation and
calls validation-only synthetic context while the outer shell stays alive. Assertions read the
actual cached binding and observation: outer-owner PID equals the owned outer shell, producer
PID equals the distinct nested shell, and observation/device matches the binding. Validation
succeeds with zero PTY output, no intent/bound-intent/effect, and unchanged cached binding.

An initial fixture attempt ran both Bash processes in the same foreground group, so the metadata
fallback correctly bound the foreground outer PID. The fixture precondition failed before the
new validation path was called. Failure logs EHpdYF and LUwh16 are preserved. The fixture now
uses the owned outer interactive shell's job control so the nested shell owns the actual foreground
group. This requires no provider impersonation, catalogue fixture, Automation or native mapping.
The observation remains unverified agent metadata from owned Bash processes, not a real agent.

Focused new case: 1/1 green, tavs-isolated.gnTLHo/command.log.
Final background-intent suite: 10/10 green, tavs-isolated.fqdnea/command.log.
Final git diff --check: green.
All logs remain below /var/folders/sc/3sxw5lhd5hs05l8sr8tc1lqc0000gn/T/.

This adds ordinary owned-PTY ancestry coverage. It does not establish real provider events,
physical native terminal mapping, or Ghostty interactive job-control acceptance. Scope for this
follow-up was only background-intent.bats and this report; parent owns commits and combined checks.

## Parent final regression run

After the producer/owner correction in `2ee25f7`, parent verified **86/86** isolated Bats cases:
background-intent10, managed-background16, mute-gate20, idle-worker-mute6, liveness7,
shellrc19 and cmd-recover8. Log `tavs-isolated.GJcrSl/command.log` under the prefix above.
The extra mute-gate case confirms absent legacy schema remains accepted while explicit empty
or unknown schema is rejected. It passed before any source edit, falsifying a suspected mismatch.
Separate Bash checks for all six changed production files, zsh shellrc and diff checks pass.
