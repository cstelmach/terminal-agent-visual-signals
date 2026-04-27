import Foundation
@testable import TAVSApp

final class MockBroadcaster: BroadcasterProtocol {
    private(set) var broadcastCallCount = 0
    private(set) var broadcastPausedCallCount = 0
    private(set) var broadcastPausedClearCallCount = 0
    private(set) var lastPausedBackgroundColor: String?

    func broadcast() {
        broadcastCallCount += 1
    }

    func broadcastPaused(backgroundColor: String) {
        broadcastPausedCallCount += 1
        lastPausedBackgroundColor = backgroundColor
    }

    func broadcastPausedClear() {
        broadcastPausedClearCallCount += 1
    }
}
