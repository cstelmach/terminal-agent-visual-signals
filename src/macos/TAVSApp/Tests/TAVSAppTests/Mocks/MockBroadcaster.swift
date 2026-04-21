import Foundation
@testable import TAVSApp

final class MockBroadcaster: BroadcasterProtocol {
    private(set) var broadcastCallCount = 0
    private(set) var broadcastPausedCallCount = 0
    private(set) var broadcastPausedClearCallCount = 0
    private(set) var clearPendingCallCount = 0

    func broadcast() {
        broadcastCallCount += 1
    }

    func broadcastPaused() {
        broadcastPausedCallCount += 1
    }

    func broadcastPausedClear() {
        broadcastPausedClearCallCount += 1
    }

    func clearPending() {
        clearPendingCallCount += 1
    }
}
