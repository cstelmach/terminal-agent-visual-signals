import XCTest
@testable import TAVSApp

final class LoginItemManagerTests: XCTestCase {

    func testIsEnabledReflectsService() {
        let mock = MockLoginItemService()
        let mgr = LoginItemManager(service: mock)
        XCTAssertFalse(mgr.isEnabled)
        mock.isEnabled = true
        XCTAssertTrue(mgr.isEnabled)
    }

    func testRegisterCallsService() throws {
        let mock = MockLoginItemService()
        let mgr = LoginItemManager(service: mock)

        try mgr.register()

        XCTAssertEqual(mock.registerCallCount, 1)
        XCTAssertTrue(mgr.isEnabled)
    }

    func testUnregisterCallsService() throws {
        let mock = MockLoginItemService()
        mock.isEnabled = true
        let mgr = LoginItemManager(service: mock)

        try mgr.unregister()

        XCTAssertEqual(mock.unregisterCallCount, 1)
        XCTAssertFalse(mgr.isEnabled)
    }

    func testRegisterIfNeededSkipsWhenEnabled() throws {
        let mock = MockLoginItemService()
        mock.isEnabled = true
        let mgr = LoginItemManager(service: mock)

        try mgr.registerIfNeeded()

        XCTAssertEqual(mock.registerCallCount, 0,
                       "registerIfNeeded must not invoke register when already enabled")
    }

    func testRegisterIfNeededRegistersWhenDisabled() throws {
        let mock = MockLoginItemService()
        mock.isEnabled = false
        let mgr = LoginItemManager(service: mock)

        try mgr.registerIfNeeded()

        XCTAssertEqual(mock.registerCallCount, 1)
        XCTAssertTrue(mgr.isEnabled,
                      "registerIfNeeded must transition the service to enabled on success")
    }

    func testRegisterPropagatesError() {
        let mock = MockLoginItemService()
        mock.registerError = NSError(domain: "test", code: 1)
        let mgr = LoginItemManager(service: mock)

        XCTAssertThrowsError(try mgr.register())
        XCTAssertEqual(mock.registerCallCount, 1)
    }

    func testRegisterIfNeededPropagatesError() {
        let mock = MockLoginItemService()
        mock.isEnabled = false
        mock.registerError = NSError(domain: "test", code: 99)
        let mgr = LoginItemManager(service: mock)

        XCTAssertThrowsError(try mgr.registerIfNeeded())
    }
}
