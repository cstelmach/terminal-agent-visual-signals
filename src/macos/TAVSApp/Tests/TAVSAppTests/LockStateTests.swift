import XCTest
import Darwin
@testable import TAVSApp

final class LockStateTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-lock-test-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeState(
        locked: Bool = true,
        reason: LockReason = .manual,
        lockUntil: Int64 = 2_000_000,
        unlockUntil: Int64 = 0,
        written: Int64 = 1_000_000
    ) -> LockStateData {
        LockStateData(
            locked: locked, reason: reason, lockUntilEpoch: lockUntil,
            unlockUntilEpoch: unlockUntil, writtenEpoch: written,
            lockBg: "#3A3A3A", lockFg: "#CCCCCC"
        )
    }

    // MARK: - Serialization format

    func testSerializeLineOrder() {
        let lines = makeState().serialize().split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 8)
        XCTAssertTrue(lines[0].hasPrefix("LOCKED="))
        XCTAssertTrue(lines[1].hasPrefix("REASON="))
        XCTAssertTrue(lines[2].hasPrefix("LOCK_UNTIL_EPOCH="))
        XCTAssertTrue(lines[3].hasPrefix("UNLOCK_UNTIL_EPOCH="))
        XCTAssertTrue(lines[4].hasPrefix("WRITTEN_EPOCH="))
        XCTAssertTrue(lines[5].hasPrefix("LOCK_BG="))
        XCTAssertTrue(lines[6].hasPrefix("LOCK_FG="))
        XCTAssertTrue(lines[7].hasPrefix("SCHEMA_VERSION=\"1\""))
    }

    func testWriteReadRoundTrip() throws {
        let url = tempDir.appendingPathComponent("lock.state")
        let state = makeState(reason: .schedule, unlockUntil: 1_500_000)
        try LockStateWriter.write(state, to: url)
        XCTAssertEqual(LockStateReader.read(at: url), state)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int, 0o600)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tempDir.path).sorted(),
                       [url.lastPathComponent, url.lastPathComponent + ".lock"])
    }

    func testWriterCannotReplaceStateWhileAnotherMutationHoldsTheLock() throws {
        let url = tempDir.appendingPathComponent("lock.state")
        try LockStateWriter.write(makeState(), to: url)
        let original = try Data(contentsOf: url)
        let fd = open(url.path + ".lock", O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        XCTAssertThrowsError(try LockStateWriter.write(makeState(unlockUntil: 1_500_000), to: url)) {
            XCTAssertEqual(($0 as? POSIXError)?.code, .ETIMEDOUT)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testUpdateReadsAndMergesWhileHoldingTheStableMutex() throws {
        let url = tempDir.appendingPathComponent("lock.state")
        try LockStateWriter.write(makeState(lockUntil: 4_000_000, unlockUntil: 1_500_000), to: url)
        let state = try LockStateWriter.update(at: url) { existing in
            let fd = open(url.path + ".lock", O_RDWR | O_NOFOLLOW)
            defer { close(fd) }
            XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), -1)
            XCTAssertEqual(errno, EWOULDBLOCK)
            return LockStateMerge.merged(existing: existing, scheduleHardMuted: true,
                scheduleUntilEpoch: 3_000_000, now: 1_000_000, lockBg: "#123456", lockFg: "")
        }
        XCTAssertEqual(state.lockUntilEpoch, 4_000_000)
        XCTAssertEqual(state.unlockUntilEpoch, 1_500_000)
        XCTAssertEqual(try LockStateReader.readChecked(at: url), state)
    }

    func testUpdateDoesNotRewriteEquivalentStateOrPublishAfterItsDeadline() throws {
        let url = tempDir.appendingPathComponent("lock.state")
        try LockStateWriter.write(makeState(), to: url)
        let original = try Data(contentsOf: url)
        let accepted = try LockStateWriter.update(at: url) { existing in
            var state = try XCTUnwrap(existing); state.writtenEpoch += 1
            return state
        }
        XCTAssertEqual(try LockStateReader.readChecked(at: url), accepted)
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertThrowsError(try LockStateWriter.update(at: url) { existing in
            usleep(110_000)
            return try XCTUnwrap(existing)
        }) { XCTAssertEqual(($0 as? POSIXError)?.code, .ETIMEDOUT) }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testUnsafeMutexObjectsCannotAuthorizeMutation() throws {
        let url = tempDir.appendingPathComponent("linked.state")
        let other = tempDir.appendingPathComponent("other")
        try Data().write(to: other)
        try FileManager.default.createSymbolicLink(at: URL(fileURLWithPath: url.path + ".lock"),
                                                   withDestinationURL: other)
        XCTAssertThrowsError(try LockStateWriter.write(makeState(), to: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let fifo = tempDir.appendingPathComponent("fifo.state")
        XCTAssertEqual(mkfifo(fifo.path + ".lock", 0o600), 0)
        XCTAssertThrowsError(try LockStateWriter.write(makeState(), to: fifo))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fifo.path))
    }

    func testHeadlessEntryCanonicalizesColorsBeforeSerializingFields() throws {
        let url = tempDir.appendingPathComponent("lock.state")
        let until = Int64(Date().timeIntervalSince1970) + 3600
        let args = ["TAVSApp", "--lock-state-update", url.path, "now", String(until), " #123abc\n", ""]
        XCTAssertEqual(try LockStateEntry.update(args), until)
        XCTAssertEqual(try LockStateReader.readChecked(at: url)?.lockBg, "#123ABC")
        XCTAssertEqual(try String(contentsOf: url).split(separator: "\n").count, 8)
        var injected = args; injected[5] = "#123abc\nLOCKED=\"false\""
        XCTAssertThrowsError(try LockStateEntry.update(injected))
        XCTAssertEqual(try LockStateReader.readChecked(at: url)?.locked, true)
    }

    func testWriterRejectsUnsafeParentAndLeafWithoutReplacingState() throws {
        let parent = tempDir.appendingPathComponent("unsafe")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        let url = parent.appendingPathComponent("lock.state"), state = makeState()
        try LockStateWriter.write(state, to: url)
        let original = try Data(contentsOf: url)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: parent.path)
        XCTAssertThrowsError(try LockStateWriter.write(makeState(locked: false), to: url))
        XCTAssertEqual(try Data(contentsOf: url), original)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: url.path)
        XCTAssertThrowsError(try LockStateWriter.write(makeState(locked: false), to: url))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testCheckedReadSeparatesTrustedAbsenceFromUnparseableOrOversizedFiles() throws {
        let url = tempDir.appendingPathComponent("checked.state")
        XCTAssertNil(try LockStateReader.readChecked(at: url))
        for data in [Data("invalid-lock".utf8), Data([0xFF]), Data(repeating: 0x61, count: 8_193)] {
            try data.write(to: url, options: .atomic)
            XCTAssertThrowsError(try LockStateReader.readChecked(at: url))
            XCTAssertNil(LockStateReader.read(at: url))
            XCTAssertEqual(try Data(contentsOf: url), data)
            XCTAssertThrowsError(try LockStateWriter.write(makeState(), to: url))
        }
    }

    func testCheckedReadRejectsLinksFIFOsAndExpiredDeadlineBeforeUnsafeIO() throws {
        let target = tempDir.appendingPathComponent("target.state")
        try LockStateWriter.write(makeState(), to: target)
        let link = tempDir.appendingPathComponent("link"), fifo = tempDir.appendingPathComponent("fifo")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        XCTAssertThrowsError(try LockStateReader.readChecked(at: link))
        XCTAssertThrowsError(try LockStateReader.readChecked(at: fifo))
        XCTAssertThrowsError(try LockStateReader.readChecked(at: target,
            deadline: DispatchTime.now().uptimeNanoseconds - 1)) { error in
                XCTAssertEqual((error as? POSIXError)?.code, .ETIMEDOUT)
            }
        XCTAssertEqual(try LockStateReader.readChecked(at: target), makeState())
    }

    func testWriterRejectsOversizedOutputWithoutChangingExistingState() throws {
        let url = tempDir.appendingPathComponent("lock.state")
        try LockStateWriter.write(makeState(), to: url)
        let original = try Data(contentsOf: url)
        var oversized = makeState(); oversized.lockBg = String(repeating: "A", count: 8_193)
        XCTAssertThrowsError(try LockStateWriter.write(oversized, to: url)) { error in
            XCTAssertEqual((error as? POSIXError)?.code, .EFBIG)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tempDir.path).sorted(),
                       [url.lastPathComponent, url.lastPathComponent + ".lock"])
    }

    // MARK: - Reader robustness (absent/malformed = nil = not locked, D3)

    func testReadAbsentFileReturnsNil() {
        XCTAssertNil(LockStateReader.read(at: tempDir.appendingPathComponent("nope")))
    }

    func testParseMissingLockedReturnsNil() {
        XCTAssertNil(LockStateReader.parse("LOCK_UNTIL_EPOCH=\"100\"\n"))
    }

    func testParseNonNumericLockUntilReturnsNil() {
        XCTAssertNil(LockStateReader.parse("LOCKED=\"true\"\nLOCK_UNTIL_EPOCH=\"soon\"\n"))
        XCTAssertNil(LockStateReader.parse("LOCKED=\"true\"\n"))
    }

    func testParseUnknownSchemaReturnsNil() {
        XCTAssertNil(LockStateReader.parse(
            "LOCKED=\"true\"\nLOCK_UNTIL_EPOCH=\"100\"\nSCHEMA_VERSION=\"2\"\n"))
    }

    // MARK: - Effective-lock predicate (spec 2.2)

    func testEffectiveWhenUnexpiredWithoutGrant() {
        XCTAssertTrue(makeState(lockUntil: 1000, unlockUntil: 0).isEffectivelyLocked(now: 999))
    }

    func testNotEffectiveAtExpiry() {
        XCTAssertFalse(makeState(lockUntil: 1000).isEffectivelyLocked(now: 1000))
    }

    func testNotEffectiveWhileGrantActive() {
        XCTAssertFalse(makeState(lockUntil: 1000, unlockUntil: 900).isEffectivelyLocked(now: 800))
    }

    func testEffectiveAgainAfterGrantExpires() {
        XCTAssertTrue(makeState(lockUntil: 1000, unlockUntil: 900).isEffectivelyLocked(now: 950))
    }

    func testNotEffectiveWhenUnlockedFlag() {
        XCTAssertFalse(makeState(locked: false, lockUntil: 1000).isEffectivelyLocked(now: 1))
    }

    // MARK: - Merge (spec 2.2 writer rules)

    func testMergeScheduleHardFromNothing() {
        let merged = LockStateMerge.merged(
            existing: nil, scheduleHardMuted: true, scheduleUntilEpoch: 5000,
            now: 1000, lockBg: "#111111", lockFg: "")
        XCTAssertTrue(merged.locked)
        XCTAssertEqual(merged.reason, .schedule)
        XCTAssertEqual(merged.lockUntilEpoch, 5000)
        XCTAssertEqual(merged.unlockUntilEpoch, 0)
    }

    func testMergeScheduleHardUnknownTransitionCapped24h() {
        let merged = LockStateMerge.merged(
            existing: nil, scheduleHardMuted: true, scheduleUntilEpoch: 0,
            now: 1000, lockBg: "", lockFg: "")
        XCTAssertEqual(merged.lockUntilEpoch, 1000 + LockStateMerge.scheduleUntilCap)
    }

    func testMergeLaterManualLockSurvivesScheduleRewrite() {
        let manual = makeState(reason: .manual, lockUntil: 9000)
        let merged = LockStateMerge.merged(
            existing: manual, scheduleHardMuted: true, scheduleUntilEpoch: 5000,
            now: 1000, lockBg: "", lockFg: "")
        XCTAssertEqual(merged.reason, .manual)
        XCTAssertEqual(merged.lockUntilEpoch, 9000)
    }

    func testMergeEarlierManualLockYieldsToSchedule() {
        let manual = makeState(reason: .manual, lockUntil: 3000)
        let merged = LockStateMerge.merged(
            existing: manual, scheduleHardMuted: true, scheduleUntilEpoch: 5000,
            now: 1000, lockBg: "", lockFg: "")
        XCTAssertEqual(merged.reason, .schedule)
        XCTAssertEqual(merged.lockUntilEpoch, 5000)
    }

    func testMergePreservesUnexpiredGrant() {
        let existing = makeState(reason: .schedule, lockUntil: 9000, unlockUntil: 4000)
        let merged = LockStateMerge.merged(
            existing: existing, scheduleHardMuted: true, scheduleUntilEpoch: 9000,
            now: 1000, lockBg: "", lockFg: "")
        XCTAssertEqual(merged.unlockUntilEpoch, 4000)
    }

    func testMergeDropsExpiredGrant() {
        let existing = makeState(reason: .schedule, lockUntil: 9000, unlockUntil: 500)
        let merged = LockStateMerge.merged(
            existing: existing, scheduleHardMuted: true, scheduleUntilEpoch: 9000,
            now: 1000, lockBg: "", lockFg: "")
        XCTAssertEqual(merged.unlockUntilEpoch, 0)
    }

    func testMergeManualOnlyWhenScheduleNotHard() {
        let manual = makeState(reason: .manual, lockUntil: 9000)
        let merged = LockStateMerge.merged(
            existing: manual, scheduleHardMuted: false, scheduleUntilEpoch: 0,
            now: 1000, lockBg: "", lockFg: "")
        XCTAssertTrue(merged.locked)
        XCTAssertEqual(merged.reason, .manual)
        XCTAssertEqual(merged.lockUntilEpoch, 9000)
    }

    func testMergeExpiredManualUnlocks() {
        let manual = makeState(reason: .manual, lockUntil: 900)
        let merged = LockStateMerge.merged(
            existing: manual, scheduleHardMuted: false, scheduleUntilEpoch: 0,
            now: 1000, lockBg: "", lockFg: "")
        XCTAssertFalse(merged.locked)
    }
}
