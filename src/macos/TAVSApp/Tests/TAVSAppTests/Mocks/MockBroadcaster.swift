import Foundation
@testable import TAVSApp

final class MockBroadcaster: BroadcasterProtocol {
    private(set) var broadcastCallCount = 0

    func broadcast() {
        broadcastCallCount += 1
    }
}
