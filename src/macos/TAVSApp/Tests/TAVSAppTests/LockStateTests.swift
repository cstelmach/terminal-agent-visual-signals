import XCTest
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
