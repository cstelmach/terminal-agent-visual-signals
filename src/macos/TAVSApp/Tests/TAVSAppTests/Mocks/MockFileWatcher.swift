import Foundation
@testable import TAVSApp

final class MockFileWatcher: FileWatcherProtocol {
    var startCallCount = 0
    var stopCallCount = 0
    var onChange: (() -> Void)?

    func start(watching directory: URL, onChange: @escaping () -> Void) {
        startCallCount += 1
        self.onChange = onChange
    }

    func stop() {
        stopCallCount += 1
    }

    func simulateChange() {
        onChange?()
    }
}
