# Implementation Plan — Paused Visual State for TAVS

**Spec:** /Users/cs/.claude/plans/can-we-actually-make-functional-gray.md
**Created:** 2026-04-21
**Agent:** execute-spec (manual mode)

---

## Prerequisites

- macOS 13+ with Swift 6.0 toolchain
- Existing test suite passes: `cd src/macos/TAVSApp && swift test` (84 tests)
- No shell-side changes required (spec §2: "No changes to mute-gate.sh, trigger.sh, emit_osc, defaults.conf, or any other shell file")

## Dependency Graph

```
Phase 1 (Broadcaster) ──→ Phase 2 (Scheduler wiring)
```

**Critical path:** Phase 1 → Phase 2

## Scope Fence

Only these files are in scope:

| File | Phase | Change |
|------|-------|--------|
| `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift` | 1 | Add `broadcastPaused()`, `broadcastPausedClear()`, `writeToAllActiveTTYs(_:)` |
| `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift` | 1, 2 | Extend `BroadcasterProtocol` (Phase 1), rewire `loadAndEvaluate()` (Phase 2) |
| `Tests/.../Mocks/MockBroadcaster.swift` | 1 | Add call counters for new methods |
| `Tests/.../BroadcasterTests.swift` | 1 | Byte-content verification tests |
| `Tests/.../SchedulerTests.swift` | 2 | Transition matrix tests |

**Explicit exclusion:** `trigger.sh`, `mute-gate.sh`, `emit_osc`, `defaults.conf`, any shell file.

---

## Phase 1: Broadcaster — Protocol, Implementation, Mock, Byte Tests

Consolidates spec tasks 1, 2, 4, and 6 into a single compilable unit.

### Implementation Steps

1. **Extend `BroadcasterProtocol`** in `Scheduler.swift:146-148`:
   - Add `func broadcastPaused()`
   - Add `func broadcastPausedClear()`

2. **Implement in `Broadcaster.swift`**:
   - Add private `writeToAllActiveTTYs(_ data: Data)` helper that handles TTY enumeration
     (list `active-ttys/`, filter stale >24h, concurrent write, prune on failure).
     Same enumeration logic as `broadcast()` but without pending-file read/remove.
   - `broadcastPaused()`: Generate OSC bytes once, call `writeToAllActiveTTYs(_:)`:
     - OSC 104 (reset palette): `\x1b]104\x07`
     - OSC 11 with `#3A3A3A` (grey bg): `\x1b]11;#3A3A3A\x07`
     - OSC 0 with title (paused face + icon): `\x1b]0;Ǝ[⬛ ⬛]E ⏸ Paused\x07`
     - iTerm2 clear bg image: `\x1b]1337;SetBackgroundImageFile=\x07`
   - `broadcastPausedClear()`: Generate reset bytes, call `writeToAllActiveTTYs(_:)`:
     - OSC 104 (reset palette): `\x1b]104\x07`
     - OSC 111 (reset bg): `\x1b]111\x07`
     - OSC 0 with empty string (clear title): `\x1b]0;\x07`

3. **Update `MockBroadcaster`** in `Tests/.../Mocks/MockBroadcaster.swift`:
   - Add `broadcastPausedCallCount: Int = 0`
   - Add `broadcastPausedClearCallCount: Int = 0`
   - Implement both protocol methods incrementing respective counters

4. **`broadcast()` stays UNCHANGED.** It has per-TTY pending-cache logic; the new helper
   is for the uniform paused/clear bytes only.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift` — extend BroadcasterProtocol (lines 146-148)
- `src/macos/TAVSApp/Sources/TAVSApp/Broadcaster.swift` — add 3 methods
- `Tests/.../Mocks/MockBroadcaster.swift` — add counters + method implementations
- `Tests/.../BroadcasterTests.swift` — add 5 byte-content tests

### Tests to Write

In `BroadcasterTests.swift`:

| Test | Setup | Assert |
|------|-------|--------|
| `testBroadcastPausedWritesGreyBytes` | Register one TTY, call `broadcastPaused()` | Written data contains `#3A3A3A` AND `⏸ Paused` |
| `testBroadcastPausedClearWritesResetBytes` | Register one TTY, call `broadcastPausedClear()` | Written data contains `]111` (bg reset) AND `]104` (palette reset) |
| `testBroadcastPausedBroadcastsToMultipleTTYs` | Register two TTYs, call `broadcastPaused()` | Both devices received identical bytes |
| `testBroadcastPausedSkipsStaleEntries` | One stale TTY (>24h) | No write attempt, entry pruned |
| `testBroadcastPausedPrunesDeadTTY` | Register TTY, mock write failure | Entry removed from active-ttys |

### Verification

- `swift build --package-path src/macos/TAVSApp` compiles
- `cd src/macos/TAVSApp && swift test` — all 84 existing + 5 new tests pass
- `broadcast()` method body is byte-identical to pre-change (no modifications)

### Definition of Done

- [ ] `BroadcasterProtocol` has `broadcastPaused()` and `broadcastPausedClear()` methods
- [ ] `Broadcaster` implements both via shared `writeToAllActiveTTYs(_:)` helper
- [ ] `MockBroadcaster` tracks call counts for both new methods
- [ ] 5 byte-content tests pass, verifying OSC sequences contain expected strings
- [ ] All 84 existing tests still pass (zero regressions)

---

## Phase 2: Scheduler Wiring — Transition Logic and Tests

Consolidates spec tasks 3 and 5.

### Implementation Steps

1. **Modify `loadAndEvaluate()` in `Scheduler.swift`** (currently lines 224-230):

   Current logic:
   ```swift
   if wasMuted && !result.muted {
       broadcaster.broadcast()
   }
   writeMuteState(...)
   ```

   New logic (preserving existing transition order):
   ```swift
   // Unmute transition: clear grey → replay pending → write state
   if wasMuted && !result.muted {
       broadcaster.broadcastPausedClear()
       broadcaster.broadcast()
   }

   writeMuteState(...)

   // Mute transition: write state first → paint grey
   if !wasMuted && result.muted {
       broadcaster.broadcastPaused()
   }
   ```

2. **Key invariant preserved:** `broadcast()` still called before `writeMuteState()` on
   unmute transition (spec §2 timing table). `broadcastPaused()` called AFTER
   `writeMuteState()` on mute transition.

3. **Existing test `testMutedToUnmutedCallsBroadcaster`** (SchedulerTests.swift:415)
   should pass unmodified — it checks `broadcastCallCount == 1`, which is still true.
   The new `broadcastPausedClear()` call before it doesn't affect the count.

### Files to Create/Modify

- `src/macos/TAVSApp/Sources/TAVSApp/Scheduler.swift` — modify `loadAndEvaluate()` (±10 lines)
- `Tests/.../SchedulerTests.swift` — add 6 transition tests

### Tests to Write

In `SchedulerLifecycleTests`:

| Test | Setup | Action | Assert |
|------|-------|--------|--------|
| `testActiveToMutedPaintsGrey` | masterActive=true, inside window | togglePause + fileWatcher change | `broadcastPausedCallCount == 1`, `broadcastCallCount == 0` |
| `testMutedToActiveClearsAndReplays` | masterActive=false | togglePause (resume) + fileWatcher change | `broadcastPausedClearCallCount == 1`, `broadcastCallCount == 1` |
| `testHeartbeatDuringMuteIsStable` | masterActive=false | Start (mutes), advance 60s, fire heartbeat | `broadcastPausedCallCount == 1` (from startup only) |
| `testAppStartupIntoMuted` | masterActive=false | `scheduler.start()` | `broadcastPausedCallCount == 1` |
| `testScheduleUnmuteClearsAndReplays` | Inside window, quiet at :50-:59 | Start at :55 (muted), advance to :00 (next hour), fire boundary timer | `broadcastPausedClearCallCount == 1`, `broadcastCallCount == 1` |
| `testMutedToMutedReasonChangeNoRetrigger` | Schedule muted + also quiet | Transition from quiet→schedule-muted (still muted) | Counts unchanged beyond initial mute paint |

### Verification

- `cd src/macos/TAVSApp && swift test` — all existing + Phase 1 + Phase 2 tests pass
- Existing `testMutedToUnmutedCallsBroadcaster` still passes (regression check)
- `git diff --stat` shows only the 2 source files + 1 test file touched

### Definition of Done

- [ ] `loadAndEvaluate()` calls `broadcastPausedClear()` + `broadcast()` on unmute
- [ ] `loadAndEvaluate()` calls `broadcastPaused()` after `writeMuteState()` on mute
- [ ] 6 transition tests pass covering: active→muted, muted→active, heartbeat stability, startup into muted, schedule unmute, reason-change no-retrigger
- [ ] All existing tests pass (including `testMutedToUnmutedCallsBroadcaster`)

---

## Risk Areas

| Risk | Phase | Mitigation |
|------|-------|------------|
| TTY enumeration duplication between `broadcast()` and `writeToAllActiveTTYs()` | 1 | Accept duplication — extracting a shared helper would modify `broadcast()` body, violating scope |
| OSC escape sequence bytes incorrect | 1 | Byte-content tests verify exact substrings in written data |
| Transition order regression | 2 | Existing `testMutedToUnmutedCallsBroadcaster` + new transition tests |
| `previousMuted` init value causing false transition on first evaluation | 2 | Test `testAppStartupIntoMuted` covers this: `previousMuted=false` → `result.muted=true` triggers paint |

## Sequencing & Dependencies

| Phase | Depends On | Can Parallel With |
|-------|-----------|-------------------|
| 1     | —         | —                 |
| 2     | 1         | —                 |
