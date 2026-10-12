import XCTest
@testable import TAVSApp

final class MuteStateTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-test-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Format Stability

    func testSerializeMutedState() {
        let state = MuteStateData(
            muted: true,
            reason: .quietPeriod,
            untilEpoch: 1713624000,
            writtenEpoch: 1713623400,
            appPID: 12345
        )
        let kvString = state.serialize()

        XCTAssertTrue(kvString.contains("MUTED=\"true\""))
        XCTAssertTrue(kvString.contains("REASON=\"quiet_period\""))
        XCTAssertTrue(kvString.contains("UNTIL_EPOCH=\"1713624000\""))
        XCTAssertTrue(kvString.contains("WRITTEN_EPOCH=\"1713623400\""))
        XCTAssertTrue(kvString.contains("APP_PID=\"12345\""))
        XCTAssertTrue(kvString.contains("SCHEMA_VERSION=\"1\""))
    }

    func testSerializeUnmutedState() {
        let state = MuteStateData(
            muted: false,
            reason: .none,
            untilEpoch: 0,
            writtenEpoch: 1713623400,
            appPID: 12345
        )
        let kvString = state.serialize()

        XCTAssertTrue(kvString.contains("MUTED=\"false\""))
        XCTAssertTrue(kvString.contains("REASON=\"\""))
        XCTAssertTrue(kvString.contains("UNTIL_EPOCH=\"0\""))
    }

    func testSerializeAllReasons() {
        let reasons: [(MuteReason, String)] = [
            (.scheduleWindow, "schedule_window"),
            (.quietPeriod, "quiet_period"),
            (.masterPaused, "master_paused"),
            (.none, ""),
        ]
        for (reason, expected) in reasons {
            let state = MuteStateData(muted: true, reason: reason, untilEpoch: 0, writtenEpoch: 0, appPID: 0)
            XCTAssertTrue(state.serialize().contains("REASON=\"\(expected)\""),
                          "Expected reason \(expected)")
        }
    }

    func testSerializeFormatHasTrailingNewline() {
        let state = MuteStateData(muted: false, reason: .none, untilEpoch: 0, writtenEpoch: 0, appPID: 0)
        let kvString = state.serialize()
        XCTAssertTrue(kvString.hasSuffix("\n"))
    }

    func testSerializeLineOrder() {
        let state = MuteStateData(muted: true, reason: .quietPeriod, untilEpoch: 100, writtenEpoch: 200, appPID: 300)
        let lines = state.serialize().split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 10)
        XCTAssertTrue(lines[0].hasPrefix("MUTED="))
        XCTAssertTrue(lines[1].hasPrefix("REASON="))
        XCTAssertTrue(lines[2].hasPrefix("UNTIL_EPOCH="))
        XCTAssertTrue(lines[3].hasPrefix("WRITTEN_EPOCH="))
        XCTAssertTrue(lines[4].hasPrefix("APP_PID="))
        XCTAssertTrue(lines[5].hasPrefix("PAUSE_BG="))
        XCTAssertTrue(lines[6].hasPrefix("PAUSE_FG="))
        XCTAssertTrue(lines[7].hasPrefix("SCHEMA_VERSION="))
        XCTAssertEqual(lines[8], "MUTE_LEVEL=\"soft\"")
        XCTAssertEqual(lines[9], "REQUESTED_MUTED=\"true\"")
    }

    func testSerializeDistinguishesHardCauseWithoutChangingSchema() {
        var state = MuteStateData(muted: true, reason: .quietPeriod, untilEpoch: 100,
                                  writtenEpoch: 200, appPID: 43)
        XCTAssertFalse(state.hardCaused)
        XCTAssertTrue(state.serialize().contains("MUTE_LEVEL=\"soft\""))
        state.hardCaused = true
        XCTAssertTrue(state.serialize().contains("MUTE_LEVEL=\"hard\""))
        XCTAssertTrue(state.serialize().contains("SCHEMA_VERSION=\"1\""))
    }

    func testSerializeRequestedProjectionPreservesEffectiveMutedFlag() {
        var state = MuteStateData(muted: false, reason: .quietPeriod, untilEpoch: 100,
                                  writtenEpoch: 200, appPID: 43)
        XCTAssertTrue(state.serialize().contains("REQUESTED_MUTED=\"false\""))
        state.requestedMuted = true
        XCTAssertTrue(state.serialize().contains("MUTED=\"false\"\n"))
        XCTAssertTrue(state.serialize().contains("REQUESTED_MUTED=\"true\""))
        XCTAssertTrue(state.serialize().contains("SCHEMA_VERSION=\"1\""))
    }

    func testSerializePauseVisualFields() {
        let state = MuteStateData(
            muted: true, reason: .quietPeriod, untilEpoch: 0, writtenEpoch: 0, appPID: 0,
            pauseBg: "#3A3A3A", pauseFg: "#CCCCCC"
        )
        let kvString = state.serialize()
        XCTAssertTrue(kvString.contains("PAUSE_BG=\"#3A3A3A\""))
        XCTAssertTrue(kvString.contains("PAUSE_FG=\"#CCCCCC\""))
        // Additive fields must not bump the schema: shell readers key on 1.
        XCTAssertTrue(kvString.contains("SCHEMA_VERSION=\"1\""))
    }

    func testSerializePauseVisualFieldsDefaultEmpty() {
        let state = MuteStateData(muted: false, reason: .none, untilEpoch: 0, writtenEpoch: 0, appPID: 0)
        let kvString = state.serialize()
        XCTAssertTrue(kvString.contains("PAUSE_BG=\"\""))
        XCTAssertTrue(kvString.contains("PAUSE_FG=\"\""))
    }

    // MARK: - Atomic Write

    func testAtomicWriteCreatesFile() throws {
        let path = tempDir.appendingPathComponent("mute.state")
        let state = MuteStateData(muted: true, reason: .scheduleWindow, untilEpoch: 100, writtenEpoch: 200, appPID: 42)

        try MuteStateWriter.write(state, to: path)

        let content = try String(contentsOf: path, encoding: .utf8)
        XCTAssertTrue(content.contains("MUTED=\"true\""))
        XCTAssertTrue(content.contains("REASON=\"schedule_window\""))
    }

    func testAtomicWriteOverwritesExisting() throws {
        let path = tempDir.appendingPathComponent("mute.state")

        let state1 = MuteStateData(muted: true, reason: .quietPeriod, untilEpoch: 100, writtenEpoch: 200, appPID: 1)
        try MuteStateWriter.write(state1, to: path)

        let state2 = MuteStateData(muted: false, reason: .none, untilEpoch: 0, writtenEpoch: 300, appPID: 1)
        try MuteStateWriter.write(state2, to: path)

        let content = try String(contentsOf: path, encoding: .utf8)
        XCTAssertTrue(content.contains("MUTED=\"false\""))
        XCTAssertTrue(content.contains("WRITTEN_EPOCH=\"300\""))
    }

    func testConcurrentReaderSeesCompleteFile() throws {
        let path = tempDir.appendingPathComponent("mute.state")
        let iterations = 100
        let expectation = XCTestExpectation(description: "concurrent reads complete")
        expectation.expectedFulfillmentCount = iterations

        for i in 0..<iterations {
            let state = MuteStateData(
                muted: i % 2 == 0,
                reason: i % 2 == 0 ? .quietPeriod : .none,
                untilEpoch: Int64(i * 1000),
                writtenEpoch: Int64(i * 100),
                appPID: Int32(i)
            )
            try MuteStateWriter.write(state, to: path)

            DispatchQueue.global().async {
                if let content = try? String(contentsOf: path, encoding: .utf8) {
                    let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
                    // Schema 1 retains its old fields and adds the explicit mute cause.
                    XCTAssertTrue(lines.count == 10 || lines.isEmpty,
                                  "Partial read detected: \(lines.count) lines")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Delete

    func testDeleteRemovesFile() throws {
        let path = tempDir.appendingPathComponent("mute.state")
        let state = MuteStateData(muted: false, reason: .none, untilEpoch: 0, writtenEpoch: 0, appPID: 0)
        try MuteStateWriter.write(state, to: path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))

        try MuteStateWriter.delete(at: path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
    }

    func testDeleteNonexistentIsNoOp() {
        let path = tempDir.appendingPathComponent("nonexistent.state")
        XCTAssertNoThrow(try MuteStateWriter.delete(at: path))
    }
}
