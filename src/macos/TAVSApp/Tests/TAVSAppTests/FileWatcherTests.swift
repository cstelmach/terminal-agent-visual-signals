import XCTest
@testable import TAVSApp

final class FileWatcherTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-fwtest-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSingleChangeFiresCallback() {
        let watcher = FileWatcher(debounceInterval: 0.1)
        let expectation = XCTestExpectation(description: "callback fires")

        watcher.start(watching: tempDir) {
            expectation.fulfill()
        }

        let file = tempDir.appendingPathComponent("test.json")
        try! "hello".write(to: file, atomically: true, encoding: .utf8)

        wait(for: [expectation], timeout: 2.0)
        watcher.stop()
    }

    func testFiveRapidRenamesFiresExactlyOnce() {
        let watcher = FileWatcher(debounceInterval: 0.15)
        var callbackCount = 0
        let finalExpectation = XCTestExpectation(description: "debounced callback")

        watcher.start(watching: tempDir) {
            callbackCount += 1
            finalExpectation.fulfill()
        }

        for i in 0..<5 {
            let tmpFile = tempDir.appendingPathComponent("tmp-\(i)")
            let target = tempDir.appendingPathComponent("target.json")
            try! "content-\(i)".write(to: tmpFile, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: target)
            try! FileManager.default.moveItem(at: tmpFile, to: target)
        }

        wait(for: [finalExpectation], timeout: 3.0)
        // small extra wait to catch any spurious extra fires
        Thread.sleep(forTimeInterval: 0.3)
        watcher.stop()

        XCTAssertEqual(callbackCount, 1, "Expected exactly 1 debounced callback, got \(callbackCount)")
    }

    func testStopPreventsCallback() {
        let watcher = FileWatcher(debounceInterval: 0.1)
        var callbackFired = false

        watcher.start(watching: tempDir) {
            callbackFired = true
        }
        watcher.stop()

        let file = tempDir.appendingPathComponent("test.json")
        try! "hello".write(to: file, atomically: true, encoding: .utf8)

        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(callbackFired, "Callback should not fire after stop()")
    }

    func testMockFileWatcherSimulatesChange() {
        let mock = MockFileWatcher()
        var fired = false
        mock.start(watching: tempDir) { fired = true }
        mock.simulateChange()
        XCTAssertTrue(fired)
        XCTAssertEqual(mock.startCallCount, 1)
    }
}
