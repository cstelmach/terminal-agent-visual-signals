import Foundation
@testable import TAVSApp

final class MockBroadcaster: BroadcasterProtocol {
    private(set) var broadcastCallCount = 0
    private(set) var broadcastPausedCallCount = 0
    private(set) var broadcastPausedClearCallCount = 0
    private(set) var discoverCallCount = 0
    private(set) var lastPausedVisual: PauseVisual?
    var lastPausedBackgroundColor: String? {
        lastPausedVisual?.backgroundColor
    }

    func broadcast() {
        broadcastCallCount += 1
    }

    func broadcastPaused(visual: PauseVisual) {
        broadcastPausedCallCount += 1
        lastPausedVisual = visual
    }

    func broadcastPausedClear() {
        broadcastPausedClearCallCount += 1
    }

    func discoverAndRegisterActiveAgentTTYs() {
        discoverCallCount += 1
    }
}
