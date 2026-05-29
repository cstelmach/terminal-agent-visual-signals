import Foundation
@testable import TAVSApp

final class MockBroadcaster: BroadcasterProtocol {
    private(set) var broadcastCallCount = 0
    private(set) var broadcastPausedCallCount = 0
    private(set) var broadcastPausedClearCallCount = 0
    private(set) var discoverCallCount = 0
    private(set) var callOrder: [String] = []
    private(set) var lastPausedVisual: PauseVisual?
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

    func broadcastPausedClear() {
        broadcastPausedClearCallCount += 1
        callOrder.append("broadcastPausedClear")
    }

    func discoverAndRegisterActiveAgentTTYs() {
        discoverCallCount += 1
        callOrder.append("discover")
    }
}
