import XCTest
@testable import TAVSApp

final class BroadcasterTests: XCTestCase {
    private var tempDir: URL!
    private var activeTTYsDir: URL!
    private var pendingDir: URL!
    private var mockRunner: MockProcessRunner!
    private var broadcaster: Broadcaster!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-broadcaster-test-\(UUID().uuidString)")
        activeTTYsDir = tempDir.appendingPathComponent("active-ttys")
        pendingDir = tempDir.appendingPathComponent("pending")
        try! FileManager.default.createDirectory(at: activeTTYsDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)
        mockRunner = MockProcessRunner()
        broadcaster = Broadcaster(runtimeDir: tempDir, processRunner: mockRunner)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testBroadcastWritesPendingToDevice() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        let oscBytes = Data([0x1b, 0x5d, 0x31, 0x31, 0x3b])
        try oscBytes.write(to: pendingDir.appendingPathComponent("dev_ttys001.osc"))

        broadcaster.broadcast()

        XCTAssertEqual(mockRunner.writtenDevices.count, 1)
        XCTAssertEqual(mockRunner.writtenDevices[0].0, "/dev/ttys001")
        XCTAssertEqual(mockRunner.writtenDevices[0].1, oscBytes)
    }

    func testBroadcastRemovesPendingAfterWrite() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        let pendingFile = pendingDir.appendingPathComponent("dev_ttys001.osc")
        try Data([0x01]).write(to: pendingFile)

        broadcaster.broadcast()

        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingFile.path),
                       "Pending file removed after successful write")
    }

    func testBroadcastPrunesDeadTTY() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )
        try Data([0x1b]).write(to: pendingDir.appendingPathComponent("dev_ttys001.osc"))

        mockRunner.writeError = ProcessRunnerError.deviceNotWritable("/dev/ttys001")

        broadcaster.broadcast()

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path
            ),
            "Dead TTY pruned from registry"
        )
    }

    func testBroadcastSkipsStaleEntries() throws {
        let entryPath = activeTTYsDir.appendingPathComponent("dev_ttys001").path
        FileManager.default.createFile(atPath: entryPath, contents: nil)
        let oldDate = Date().addingTimeInterval(-25 * 3600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: entryPath)

        try Data([0x01]).write(to: pendingDir.appendingPathComponent("dev_ttys001.osc"))

        broadcaster.broadcast()

        XCTAssertEqual(mockRunner.writtenDevices.count, 0, "Stale entry skipped")
        XCTAssertFalse(FileManager.default.fileExists(atPath: entryPath), "Stale entry pruned")
    }

    func testBroadcastSkipsMissingPending() {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        broadcaster.broadcast()

        XCTAssertEqual(mockRunner.writtenDevices.count, 0, "No pending = no write")
    }

    func testBroadcastMultipleTTYs() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys002").path,
            contents: nil
        )

        try Data([0x01]).write(to: pendingDir.appendingPathComponent("dev_ttys001.osc"))
        try Data([0x02]).write(to: pendingDir.appendingPathComponent("dev_ttys002.osc"))

        broadcaster.broadcast()

        XCTAssertEqual(mockRunner.writtenDevices.count, 2, "Both TTYs written")
    }

    func testBroadcastEmptyRegistryIsNoOp() {
        broadcaster.broadcast()
        XCTAssertEqual(mockRunner.writtenDevices.count, 0)
    }

    func testBroadcastEmptyPendingFileSkipped() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )
        try Data().write(to: pendingDir.appendingPathComponent("dev_ttys001.osc"))

        broadcaster.broadcast()

        XCTAssertEqual(mockRunner.writtenDevices.count, 0, "Empty pending file skipped")
    }
}
