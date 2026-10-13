import Foundation
@testable import TAVSApp

final class MockBroadcaster: BroadcasterProtocol {
    var resultChanged: ((Bool, [VisualRecoveryItem]) -> Void)?
    private(set) var retryCallCount = 0
    func retryFailedRestrictions() { retryCallCount += 1 }
    private(set) var broadcastCallCount = 0
    private(set) var broadcastPausedCallCount = 0
    private(set) var broadcastLockedCallCount = 0
    private(set) var broadcastPausedClearCallCount = 0
    private(set) var discoverCallCount = 0
    private(set) var callOrder: [String] = []
    private(set) var lastPausedVisual: PauseVisual?
    private(set) var lastLockedUntilText: String?
    var onPausedClear: (() -> Void)?
    var lastPausedBackgroundColor: String? {
        lastPausedVisual?.backgroundColor
    }

    func broadcast() {
        broadcastCallCount += 1
        callOrder.append("broadcast")
    }

    func broadcastPaused(visual: PauseVisual) {
        broadcastPausedCallCount += 1
        callOrder.append("broadcastPaused")
        lastPausedVisual = visual
    }

    func broadcastLocked(visual: PauseVisual, untilText: String) {
        broadcastLockedCallCount += 1
        callOrder.append("broadcastLocked")
        lastPausedVisual = visual
        lastLockedUntilText = untilText
    }

    func broadcastPausedClear() {
        broadcastPausedClearCallCount += 1
        callOrder.append("broadcastPausedClear")
        onPausedClear?()
    }

    func discoverAndRegisterActiveAgentTTYs() {
        discoverCallCount += 1
        callOrder.append("discover")
    }
}
