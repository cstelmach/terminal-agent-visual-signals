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

    // MARK: - broadcastPaused / broadcastPausedClear tests

    func testBroadcastPausedWritesGreyBytes() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        broadcaster.broadcastPaused()

        XCTAssertEqual(mockRunner.writtenDevices.count, 1)
        let written = try XCTUnwrap(String(data: mockRunner.writtenDevices[0].1, encoding: .utf8))
        XCTAssertTrue(written.contains("#3A3A3A"), "Grey background OSC present")
        XCTAssertTrue(written.contains("⏸ Paused"), "Paused title present")
        XCTAssertTrue(written.contains("SetBackgroundImageFile="), "iTerm2 bg image clear present")
    }

    func testBroadcastPausedUsesAgentNeutralFace() throws {
        // H1: Paused title must not hard-code an agent-specific face wrapper.
        // Claude's `Ǝ[...]E` would be jarring for Gemini/Codex/OpenCode users.
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        broadcaster.broadcastPaused()

        let written = try XCTUnwrap(String(data: mockRunner.writtenDevices[0].1, encoding: .utf8))
        XCTAssertFalse(written.contains("Ǝ["), "Must not use Claude-specific face wrapper")
        XCTAssertFalse(written.contains("]E "), "Must not use Claude-specific face wrapper")
        XCTAssertTrue(written.contains("[⬛ ⬛]"), "Uses generic eye-closed face")
    }

    func testBroadcastPausedClearWritesResetBytes() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        broadcaster.broadcastPausedClear()

        XCTAssertEqual(mockRunner.writtenDevices.count, 1)
        let written = try XCTUnwrap(String(data: mockRunner.writtenDevices[0].1, encoding: .utf8))
        XCTAssertTrue(written.contains("]111"), "Background reset OSC present")
        XCTAssertTrue(written.contains("]104"), "Palette reset OSC present")
    }

    func testBroadcastPausedClearDoesNotWipeTitle() throws {
        // H3: Do not emit `\x1B]0;\x07` (empty title). It blanks user-set tab
        // names in prefix-only title mode. The next hook/idle-worker tick
        // repaints the correct title naturally.
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        broadcaster.broadcastPausedClear()

        let written = try XCTUnwrap(String(data: mockRunner.writtenDevices[0].1, encoding: .utf8))
        XCTAssertFalse(written.contains("]0;\u{07}"),
                       "Must not emit empty-title OSC 0 — would blank user tab names")
        XCTAssertFalse(written.contains("]0;\u{1B}\\"),
                       "Must not emit empty-title OSC 0 with ST terminator either")
    }

    // MARK: - clearPending (H2)

    func testClearPendingRemovesAllPendingFiles() throws {
        try Data([0x01]).write(to: pendingDir.appendingPathComponent("dev_ttys001.osc"))
        try Data([0x02]).write(to: pendingDir.appendingPathComponent("dev_ttys002.osc"))

        broadcaster.clearPending()

        let remaining = try FileManager.default.contentsOfDirectory(atPath: pendingDir.path)
        XCTAssertTrue(remaining.isEmpty, "All pending files removed")
    }

    func testClearPendingMissingDirectoryIsNoOp() throws {
        try FileManager.default.removeItem(at: pendingDir)
        broadcaster.clearPending()  // must not throw
    }

    // MARK: - SystemProcessRunner throwing contract (B1)

    func testSystemProcessRunnerThrowsOnUnwritablePath() {
        // Documents the throwing contract wired in after switching from the
        // non-throwing FileHandle.write(Data) to write(contentsOf:).
        // The old API silently swallowed I/O errors, which broke dead-TTY
        // pruning. This test locks in the current behavior for the path-open
        // failure mode (nil FileHandle). Real EIO/EPIPE on a live pty requires
        // integration-level fixtures and is out of unit-test scope.
        let runner = SystemProcessRunner()
        XCTAssertThrowsError(
            try runner.writeToDevice(path: "/nonexistent/device-xyz", data: Data([0x01]))
        )
    }

    // MARK: - Empty pending cleanup

    func testBroadcastRemovesEmptyPendingFile() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )
        let emptyPending = pendingDir.appendingPathComponent("dev_ttys001.osc")
        try Data().write(to: emptyPending)

        broadcaster.broadcast()

        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyPending.path),
                       "Empty pending file is cleaned up so it does not accumulate")
    }

    func testBroadcastPausedBroadcastsToMultipleTTYs() {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys002").path,
            contents: nil
        )

        broadcaster.broadcastPaused()

        XCTAssertEqual(mockRunner.writtenDevices.count, 2, "Both TTYs written")
        XCTAssertEqual(mockRunner.writtenDevices[0].1, mockRunner.writtenDevices[1].1,
                       "Both TTYs received identical bytes")
    }

    func testBroadcastPausedSkipsStaleEntries() throws {
        let entryPath = activeTTYsDir.appendingPathComponent("dev_ttys001").path
        FileManager.default.createFile(atPath: entryPath, contents: nil)
        let oldDate = Date().addingTimeInterval(-25 * 3600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: entryPath)

        broadcaster.broadcastPaused()

        XCTAssertEqual(mockRunner.writtenDevices.count, 0, "Stale entry skipped")
        XCTAssertFalse(FileManager.default.fileExists(atPath: entryPath), "Stale entry pruned")
    }

    func testBroadcastPausedPrunesDeadTTY() {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        mockRunner.writeError = ProcessRunnerError.deviceNotWritable("/dev/ttys001")

        broadcaster.broadcastPaused()

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path
            ),
            "Dead TTY pruned from registry"
        )
    }
}
