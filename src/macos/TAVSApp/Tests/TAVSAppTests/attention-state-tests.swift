import XCTest
@testable import TAVSApp

final class AttentionStateTests: XCTestCase {
    private func generation(_ pid: Int32) -> ProcessGeneration {
        ProcessGeneration(pid: pid, startSeconds: 100, startMicroseconds: 1)
    }
    private func surface(_ name: String = "a") -> GhosttySurfaceID {
        GhosttySurfaceID(application: generation(80), terminalID: name)
    }
    private func observation(_ delivery: String, time: Double, state: String = "complete",
                             event: String? = "Stop", provider: String = "claude",
                             response: String? = nil, pid: Int32 = 11) -> TerminalObservation {
        TerminalObservation(tty: "/dev/ttys043", device: 43, producer: generation(pid),
            provider: provider, verifiedAgent: true, state: state, event: event,
            deliveryID: delivery, responseID: response, observedAt: time)
    }
    private func coverage(_ record: TerminalObservation?, eligible: Bool = true) -> TerminalVisualCoverage {
        TerminalVisualCoverage(observation: record, intent: nil,
            attentionEligible: eligible, status: "Test binding")
    }
    private func update(_ state: inout AttentionState, _ record: TerminalObservation?,
                        eligible: Bool = true, high: Bool = true) {
        state.update([surface(): coverage(record, eligible: eligible)], high: high ? [surface()] : [])
    }

    func testActivationBaselinesExistingCompletionAndPermission() {
        let a = surface(), b = surface("b")
        let records = [a: coverage(observation("complete", time: 999)),
                       b: coverage(observation("request", time: 999, state: "permission", event: "PermissionRequest"))]
        var state = AttentionState(coverage: records, high: [a,b], enabledAt: 1_000)
        state.update(records, high: [a,b])
        state.update([a: records[a]!, b: coverage(observation("companion", time: 1_001,
            state: "permission", event: "permission_prompt"))], high: [a,b])
        XCTAssertTrue(state.cues.isEmpty)
    }

    func testIndependentHighCuesAndAcknowledgementSnapshotPreserveLaterArrivals() {
        let a = surface(), b = surface("b")
        var state = AttentionState(coverage: [:], high: [a,b], enabledAt: 1_000)
        let first = observation("first", time: 1_001), other = observation("other", time: 1_001)
        state.update([a: coverage(first), b: coverage(other)], high: [a,b])
        let captured = state.snapshot(for: a)
        state.update([a: coverage(observation("later", time: 1_002)), b: coverage(other)], high: [a,b])
        state.acknowledge(captured, for: a)
        XCTAssertEqual(state.snapshot(for: a).count, 1)
        XCTAssertEqual(state.snapshot(for: b).count, 1)
        state.acknowledge(state.snapshot(for: b), for: b)
        XCTAssertEqual(state.cues.count, 1)
        state.acknowledge(state.snapshot(for: a), for: a)
        XCTAssertTrue(state.cues.isEmpty)
        state.update([a: coverage(observation("later", time: 1_002)), b: coverage(other)], high: [a,b])
        XCTAssertTrue(state.cues.isEmpty)
    }

    func testPermissionCompanionsShareEpisodeUntilVerifiedResumption() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        update(&state, observation("request", time: 1_001, state: "permission", event: "PermissionRequest"))
        update(&state, observation("prompt", time: 1_002, state: "permission", event: "permission_prompt"))
        XCTAssertEqual(state.snapshot(for: surface()).count, 1)
        state.acknowledge(state.snapshot(for: surface()), for: surface())
        update(&state, observation("late", time: 1_003, state: "permission", event: "permission_prompt"))
        update(&state, observation("repeat", time: 1_004, state: "permission", event: "PermissionRequest"))
        XCTAssertTrue(state.cues.isEmpty)
        update(&state, observation("resumed", time: 1_005, state: "processing", event: "PostToolUse"), eligible: false)
        update(&state, observation("next", time: 1_006, state: "permission", event: "PermissionRequest"))
        XCTAssertEqual(state.snapshot(for: surface()).count, 1)
    }

    func testLatePromptAfterResumptionCannotInventAnotherPermissionEpisode() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        update(&state, observation("first", time: 1_001, state: "permission", event: "permission_prompt"))
        XCTAssertEqual(state.cues.count, 1)
        update(&state, observation("resumed", time: 1_002, state: "processing", event: "PreToolUse"), eligible: false)
        update(&state, observation("late", time: 1_003, state: "permission", event: "permission_prompt"))
        XCTAssertTrue(state.cues.isEmpty)
        update(&state, observation("new-request", time: 1_004, state: "permission", event: "PermissionRequest"))
        XCTAssertEqual(state.cues.count, 1)
    }

    func testCodexTurnIDsDeduplicateNewDeliveriesAndPermitNewCompletionWithoutProcessing() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        update(&state, observation("one", time: 1_001, event: "agent-turn-complete", provider: "codex", response: "turn-1"))
        state.acknowledge(state.snapshot(for: surface()), for: surface())
        update(&state, observation("duplicate", time: 1_002, event: "agent-turn-complete", provider: "codex", response: "turn-1"))
        XCTAssertTrue(state.cues.isEmpty)
        update(&state, observation("two", time: 1_003, event: "agent-turn-complete", provider: "codex", response: "turn-2"))
        XCTAssertEqual(state.cues.count, 1)
    }

    func testPollingAndObservedIdleCannotResolveOrRearmCompletion() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        let done = observation("done", time: 1_001)
        update(&state, done); let cue = state.snapshot(for: surface())
        update(&state, done)
        update(&state, observation("idle", time: 1_002, state: "idle", event: "idle_prompt"), eligible: false)
        update(&state, observation("compacting", time: 1_003, state: "compacting", event: "PreCompact"), eligible: false)
        update(&state, observation("subagent", time: 1_004, state: "subagent", event: "SubagentStop"), eligible: false)
        update(&state, observation("error", time: 1_005, state: "tool_error", event: "PostToolUseFailure"), eligible: false)
        XCTAssertEqual(state.snapshot(for: surface()), cue)
        state.acknowledge(cue, for: surface())
        update(&state, done)
        XCTAssertTrue(state.cues.isEmpty)
    }

    func testPriorityDowngradeRemovesEligibilityWithoutReplayingOnPromotion() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        let done = observation("done", time: 1_001)
        update(&state, done); update(&state, done, high: false); update(&state, done)
        XCTAssertTrue(state.cues.isEmpty)
        update(&state, observation("low-delivery", time: 1_002), high: false)
        update(&state, observation("low-delivery", time: 1_002))
        XCTAssertTrue(state.cues.isEmpty)
        update(&state, observation("new", time: 1_003))
        XCTAssertEqual(state.cues.count, 1)
    }

    func testInvalidBindingAndClosureClearCuesWithoutReplayingAnOldRecord() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        let done = observation("done", time: 1_001)
        update(&state, done); update(&state, nil); update(&state, done)
        XCTAssertTrue(state.cues.isEmpty)
        update(&state, observation("new", time: 1_002)); state.update([:], high: [])
        XCTAssertTrue(state.cues.isEmpty)
    }

    func testNewProducerOccurrenceCannotBeAcknowledgedByAnOldNavigationSnapshot() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        update(&state, observation("same", time: 1_001, pid: 11))
        let old = state.snapshot(for: surface())
        update(&state, observation("same", time: 1_002, pid: 12))
        state.acknowledge(old, for: surface())
        XCTAssertEqual(state.snapshot(for: surface()).count, 1)
    }

    func testOldAndAmbiguousEqualTimeObservationsCannotTriggerOrResolve() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        update(&state, observation("old", time: 999))
        XCTAssertTrue(state.cues.isEmpty)
        update(&state, observation("new", time: 1_002)); let cue = state.snapshot(for: surface())
        update(&state, observation("stale", time: 1_001, state: "processing", event: "PostToolUse"), eligible: false)
        update(&state, observation("tied", time: 1_002))
        XCTAssertEqual(state.snapshot(for: surface()), cue)
    }

    func testUnknownUnverifiedAndUnsupportedSignalsCannotCreateCues() {
        var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
        var unverified = observation("unverified", time: 1_001); unverified.verifiedAgent = false
        update(&state, unverified)
        update(&state, observation("unknown", time: 1_002, provider: "unknown"))
        update(&state, observation("missing-turn", time: 1_003, event: "agent-turn-complete", provider: "codex"))
        update(&state, observation("manual", time: 1_004, event: nil))
        update(&state, observation("uncorrelated", time: 1_005), eligible: false)
        XCTAssertTrue(state.cues.isEmpty)
    }

    func testVerifiedResetAndProcessingClearAllCurrentOccurrences() {
        for (stateName,event) in [("processing","UserPromptSubmit"),("reset","SessionEnd")] {
            var state = AttentionState(coverage: [:], high: [surface()], enabledAt: 1_000)
            update(&state, observation("one", time: 1_001)); update(&state, observation("two", time: 1_002))
            XCTAssertEqual(state.snapshot(for: surface()).count, 2)
            update(&state, observation("resolved", time: 1_003, state: stateName, event: event), eligible: false)
            XCTAssertTrue(state.cues.isEmpty)
        }
    }
}
