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

    func testBroadcastPausedWritesForegroundAndBackgroundBytes() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        let visual = PauseVisual(
            backgroundColor: "#3A3A3A",
            foregroundColor: "#F8F8F2",
            defaultBackgroundColor: UserConfStore.defaultPauseBgDark
        )
        broadcaster.broadcastPaused(visual: visual)

        XCTAssertEqual(mockRunner.writtenDevices.count, 1)
        let written = try XCTUnwrap(String(data: mockRunner.writtenDevices[0].1, encoding: .utf8))
        XCTAssertTrue(written.contains("\u{1B}]104\u{07}"), "Palette reset OSC present")
        XCTAssertTrue(written.contains("\u{1B}]10;#F8F8F2\u{07}"), "Foreground OSC present")
        XCTAssertTrue(written.contains("\u{1B}]11;#3A3A3A\u{07}"), "Background OSC present")
        XCTAssertLessThan(
            try XCTUnwrap(written.range(of: "\u{1B}]10;#F8F8F2\u{07}")?.lowerBound),
            try XCTUnwrap(written.range(of: "\u{1B}]11;#3A3A3A\u{07}")?.lowerBound),
            "Foreground must be set before background"
        )
    }

    func testBroadcasterMethodsDoNotEmitOSC0() throws {
        // Contract-level guarantee: NO Broadcaster method emits OSC 0
        // (title sequence). The previous version of this test only covered
        // broadcastPaused, which let a future title-restore in
        // broadcastPausedClear or a new method slip through unnoticed.
        // This loops over every public paint surface and asserts the
        // invariant uniformly. Adding a new method that emits OSC 0
        // without an explicit title contract should fail this test.
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        let invocations: [(String, () -> Void)] = [
            ("broadcastPaused",      {
                self.broadcaster.broadcastPaused(
                    visual: PauseVisual(
                        backgroundColor: "#3A3A3A",
                        foregroundColor: "#F8F8F2",
                        defaultBackgroundColor: UserConfStore.defaultPauseBgDark
                    )
                )
            }),
            ("broadcastPausedClear", { self.broadcaster.broadcastPausedClear() })
        ]

        for (label, fire) in invocations {
            mockRunner.resetWrittenDevices()
            fire()
            for (_, bytes) in mockRunner.writtenDevices {
                let written = try XCTUnwrap(String(data: bytes, encoding: .utf8))
                XCTAssertFalse(written.contains("\u{1B}]0;"),
                               "\(label) must not emit OSC 0 title sequence; got: \(written)")
                XCTAssertFalse(written.contains("⏸ Paused"),
                               "\(label) must not emit paused title text")
            }
        }
    }

    func testBroadcastPausedClearResetsForegroundAndBackground() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        broadcaster.broadcastPausedClear()

        XCTAssertEqual(mockRunner.writtenDevices.count, 1)
        let written = try XCTUnwrap(String(data: mockRunner.writtenDevices[0].1, encoding: .utf8))
        XCTAssertTrue(written.contains("]104"), "Palette reset OSC present")
        XCTAssertTrue(written.contains("]110"), "Foreground reset OSC present")
        XCTAssertTrue(written.contains("]111"), "Background reset OSC present")
        XCTAssertLessThan(
            try XCTUnwrap(written.range(of: "\u{1B}]110\u{07}")?.lowerBound),
            try XCTUnwrap(written.range(of: "\u{1B}]111\u{07}")?.lowerBound),
            "Foreground reset must happen before background reset"
        )
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

    // MARK: - 24h cutoff boundary (L3)

    func testEnumerateActiveTTYsPrunesEntryAt24h01m() throws {
        // Boundary contract: an entry whose mtime is older than 24h is
        // pruned from active-ttys/ on the next enumeration. Long-idle
        // tmux/screen/SSH sessions get pruned predictably; the next
        // hook re-registers them naturally.
        let path = activeTTYsDir.appendingPathComponent("dev_ttys077").path
        FileManager.default.createFile(atPath: path, contents: nil)
        let oldDate = Date().addingTimeInterval(-86_460)  // 24h01m ago
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: path)

        // Force enumeration via a real broadcast call (writes nothing because
        // pending is empty, but does walk active-ttys/).
        broadcaster.broadcast()

        XCTAssertFalse(FileManager.default.fileExists(atPath: path),
                       "Entries older than 24h must be pruned")
    }

    func testEnumerateActiveTTYsKeepsEntryAt23h59m() throws {
        // Negative boundary: an entry just inside the 24h window survives.
        // Catches an off-by-one that would prune fresh-but-quiet sessions.
        let path = activeTTYsDir.appendingPathComponent("dev_ttys078").path
        FileManager.default.createFile(atPath: path, contents: nil)
        let oldDate = Date().addingTimeInterval(-86_340)  // 23h59m ago
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: path)

        broadcaster.broadcast()

        XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                      "Entries inside the 24h window must NOT be pruned")
    }

    // MARK: - TTY auto-discovery parser (M3)

    func testParseAgentTTYEntriesMatchesClaudeProcess() {
        let lines = [
            "ttys001 /usr/local/bin/claude --resume",
            "?? /sbin/launchd",
            "ttys002 -zsh"
        ]
        let entries = Broadcaster.parseAgentTTYEntries(from: lines)
        XCTAssertEqual(entries, ["_dev_ttys001"])
    }

    func testParseAgentTTYEntriesMatchesAllAgents() {
        let lines = [
            "ttys001 claude",
            "ttys002 gemini chat",
            "ttys003 /usr/bin/codex --version",
            "ttys004 bun /path/to/opencode/index.ts"
        ]
        let entries = Broadcaster.parseAgentTTYEntries(from: lines)
        XCTAssertEqual(entries, ["_dev_ttys001", "_dev_ttys002", "_dev_ttys003", "_dev_ttys004"])
    }

    func testParseAgentTTYEntriesSkipsNoTTYProcesses() {
        let lines = [
            "?? claude",
            "? gemini",
            "ttys001 codex"
        ]
        let entries = Broadcaster.parseAgentTTYEntries(from: lines)
        XCTAssertEqual(entries, ["_dev_ttys001"])
    }

    func testParseAgentTTYEntriesSkipsNonAgents() {
        let lines = [
            "ttys001 -zsh",
            "ttys002 vim README.md",
            "ttys003 git status"
        ]
        let entries = Broadcaster.parseAgentTTYEntries(from: lines)
        XCTAssertTrue(entries.isEmpty)
    }

    func testParseAgentTTYEntriesDeduplicatesSameTTY() {
        // A TTY can host multiple agent processes (claude + a tail in same
        // tab via job control). Both lines should produce one entry.
        let lines = [
            "ttys001 claude",
            "ttys001 codex --version"
        ]
        let entries = Broadcaster.parseAgentTTYEntries(from: lines)
        XCTAssertEqual(entries, ["_dev_ttys001"])
    }

    func testDiscoverWritesEntriesIntoActiveTTYsDir() throws {
        // End-to-end on the real process: invokes ps, parses, writes.
        // We can't predict what's running on the test host, so the contract
        // we verify is "the directory exists and contains zero or more
        // valid-format entries". Stronger assertions live in the parser tests.
        broadcaster.discoverAndRegisterActiveAgentTTYs()

        XCTAssertTrue(FileManager.default.fileExists(atPath: activeTTYsDir.path))
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: activeTTYsDir.path)) ?? []
        for entry in entries {
            XCTAssertTrue(entry.hasPrefix("_dev_tty"),
                          "Discovered entry '\(entry)' must follow _dev_tty* convention")
        }
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

        broadcaster.broadcastPaused(
            visual: PauseVisual(
                backgroundColor: "#3A3A3A",
                foregroundColor: "#F8F8F2",
                defaultBackgroundColor: UserConfStore.defaultPauseBgDark
            )
        )

        XCTAssertEqual(mockRunner.writtenDevices.count, 2, "Both TTYs written")
        XCTAssertEqual(mockRunner.writtenDevices[0].1, mockRunner.writtenDevices[1].1,
                       "Both TTYs received identical bytes")
    }

    func testBroadcastPausedSkipsStaleEntries() throws {
        let entryPath = activeTTYsDir.appendingPathComponent("dev_ttys001").path
        FileManager.default.createFile(atPath: entryPath, contents: nil)
        let oldDate = Date().addingTimeInterval(-25 * 3600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: entryPath)

        broadcaster.broadcastPaused(
            visual: PauseVisual(
                backgroundColor: "#3A3A3A",
                foregroundColor: "#F8F8F2",
                defaultBackgroundColor: UserConfStore.defaultPauseBgDark
            )
        )

        XCTAssertEqual(mockRunner.writtenDevices.count, 0, "Stale entry skipped")
        XCTAssertFalse(FileManager.default.fileExists(atPath: entryPath), "Stale entry pruned")
    }

    func testBroadcastPausedPrunesDeadTTY() {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        mockRunner.writeError = ProcessRunnerError.deviceNotWritable("/dev/ttys001")

        broadcaster.broadcastPaused(
            visual: PauseVisual(
                backgroundColor: "#3A3A3A",
                foregroundColor: "#F8F8F2",
                defaultBackgroundColor: UserConfStore.defaultPauseBgDark
            )
        )

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path
            ),
            "Dead TTY pruned from registry"
        )
    }

    // MARK: - Configurable pause visual

    func testBroadcastPausedUsesCallerSuppliedVisual() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        let visual = PauseVisual(
            backgroundColor: "#E8E8E8",
            foregroundColor: "#181818",
            defaultBackgroundColor: UserConfStore.defaultPauseBgDark
        )
        broadcaster.broadcastPaused(visual: visual)

        let written = try XCTUnwrap(String(data: mockRunner.writtenDevices[0].1, encoding: .utf8))
        XCTAssertTrue(written.contains("\u{1B}]10;#181818\u{07}"),
                      "OSC 10 must carry the caller-supplied foreground")
        XCTAssertTrue(written.contains("\u{1B}]11;#E8E8E8\u{07}"),
                      "OSC 11 must carry the caller-supplied background")
        XCTAssertFalse(written.contains("#3A3A3A"),
                       "Legacy hardcoded grey must not appear when caller overrides")
    }

    func testBroadcastPausedPreservesImageClear() throws {
        FileManager.default.createFile(
            atPath: activeTTYsDir.appendingPathComponent("dev_ttys001").path,
            contents: nil
        )

        let visual = PauseVisual(
            backgroundColor: "#3A3A3A",
            foregroundColor: "#F8F8F2",
            defaultBackgroundColor: UserConfStore.defaultPauseBgDark
        )
        broadcaster.broadcastPaused(visual: visual)

        let written = try XCTUnwrap(String(data: mockRunner.writtenDevices[0].1, encoding: .utf8))
        XCTAssertTrue(written.contains("\u{1B}]1337;SetBackgroundImageFile=\u{07}"),
                      "iTerm2 background image clear must be preserved")
    }
}
