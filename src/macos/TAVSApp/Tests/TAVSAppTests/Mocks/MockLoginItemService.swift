import Foundation
@testable import TAVSApp

// Test double for `LoginItemService`. Exercises the LoginItemManager
// contract without touching the real SMAppService database.
final class MockLoginItemService: LoginItemService {
    var isEnabled: Bool = false
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    var registerError: Error?
    var unregisterError: Error?

    func register() throws {
        registerCallCount += 1
        if let error = registerError { throw error }
        isEnabled = true
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let error = unregisterError { throw error }
        isEnabled = false
    }
}
