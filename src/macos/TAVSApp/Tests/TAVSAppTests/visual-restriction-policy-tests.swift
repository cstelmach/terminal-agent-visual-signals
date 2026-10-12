import XCTest
import Darwin
@testable import TAVSApp

final class VisualRestrictionPolicyTests: XCTestCase {
    private var root: URL!
    private var restrictions: VisualRestrictionsStateStore!
    private var muteURL: URL!
    private var lockURL: URL!
    private var clock: VirtualClock!
    private let pause = PauseVisual(backgroundColor: "#123456", foregroundColor: "#EEEEEE",
                                    defaultBackgroundColor: UserConfStore.defaultPauseBgDark)

    override func setUpWithError() throws {
        let testRoot = try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"])
        root = URL(fileURLWithPath: testRoot).appendingPathComponent("current-policy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        restrictions = VisualRestrictionsStateStore(url: root.appendingPathComponent("suspension.state"))
        muteURL = root.appendingPathComponent("mute.state")
        lockURL = root.appendingPathComponent("lock.state")
        clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func policy(pidAlive: @escaping (Int32) -> Bool = { $0 == 43 }) -> VisualRestrictionPolicy {
        VisualRestrictionPolicy(restrictions: restrictions, muteURL: muteURL, lockURL: lockURL,
                                clock: clock, pidAlive: pidAlive)
    }

    private func current(_ reader: VisualRestrictionPolicy? = nil) throws -> GlobalVisualRestriction? {
        try (reader ?? policy()).current(deadline: DispatchTime.now().uptimeNanoseconds + 100_000_000)
    }

    private func writeMute(reason: MuteReason = .quietPeriod, hard: Bool = false, until: Int64 = 0,
                           written: Int64 = 1_000, pid: Int32 = 43, legacy: Bool = false) throws {
        let state = MuteStateData(muted: true, reason: reason, untilEpoch: until, writtenEpoch: written,
                                  appPID: pid, pauseBg: pause.backgroundColor, pauseFg: pause.foregroundColor,
                                  hardCaused: hard)
        let text = legacy ? state.serialize().split(separator: "\n")
            .filter { !$0.hasPrefix("MUTE_LEVEL=") && !$0.hasPrefix("REQUESTED_MUTED=") }
            .joined(separator: "\n") + "\n" : state.serialize()
        try Data(text.utf8).write(to: muteURL, options: .atomic)
    }

    private func writeLock(until: Int64 = 2_000, grant: Int64 = 0) throws {
        try LockStateWriter.write(LockStateData(locked: true, reason: .manual, lockUntilEpoch: until,
            unlockUntilEpoch: grant, writtenEpoch: 0, lockBg: pause.backgroundColor,
            lockFg: pause.foregroundColor), to: lockURL)
    }

    func testMissingRulesHaveNoRestriction() throws { XCTAssertNil(try current()) }

    func testSuspensionAndUnavailableMarkerOverrideEveryRuleBeforeUnsafeReads() throws {
        try writeLock()
        try writeMute()
        try restrictions.write(suspended: true)
        XCTAssertNil(try current())
        try Data("MARKER_BODY_SENTINEL\n".utf8).write(to: restrictions.url, options: .atomic)
        XCTAssertNil(try current())
        try restrictions.write(suspended: false)
        XCTAssertEqual(try current(), .locked(pause, untilEpoch: 2_000))

        let fifo = root.appendingPathComponent("unsafe-mute")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        let reader = VisualRestrictionPolicy(restrictions: restrictions, muteURL: fifo, lockURL: fifo,
                                              clock: clock, pidAlive: { _ in false })
        try restrictions.write(suspended: true)
        XCTAssertNil(try current(reader))
    }

    func testFiniteHardLockWinsWithoutSoftHeartbeatOrGUILiveness() throws {
        try writeMute(written: 0, pid: 0)
        try writeLock()
        let reader = policy { _ in XCTFail("A finite hard lock does not depend on soft PID liveness"); return false }
        XCTAssertEqual(try current(reader), .locked(pause, untilEpoch: 2_000))
        clock.set(to: Date(timeIntervalSince1970: 2_000))
        XCTAssertNil(try current(reader))
    }

    func testHardGrantReleasesOnlyHardCauseWhileIndependentSoftMutePersists() throws {
        try writeLock(grant: 1_500)
        try writeMute()
        XCTAssertEqual(try current(), .paused(pause))
        clock.set(to: Date(timeIntervalSince1970: 1_500))
        XCTAssertEqual(try current(), .locked(pause, untilEpoch: 2_000))
    }

    func testRequestedSoftRuleSurvivesEffectiveSuspensionOverrideAndResumesFreshly() throws {
        try writeMute()
        var lines = try String(contentsOf: muteURL).split(separator: "\n")
            .filter { !$0.hasPrefix("REQUESTED_MUTED=") }.map(String.init)
        lines[0] = "MUTED=\"false\""
        lines.append("REQUESTED_MUTED=\"true\"")
        let text = lines.joined(separator: "\n") + "\n"
        try Data(text.utf8).write(to: muteURL, options: .atomic)
        try restrictions.write(suspended: true)
        XCTAssertNil(try current())
        try restrictions.write(suspended: false)
        XCTAssertEqual(try current(), .paused(pause))
        XCTAssertEqual(try String(contentsOf: muteURL), text, "Reading policy preserves the saved projection")
    }

    func testRequestedFalseOrMalformedFlagDefeatsStaleEffectiveMutedTrue() throws {
        try writeMute()
        let original = try String(contentsOf: muteURL).split(separator: "\n")
            .filter { !$0.hasPrefix("REQUESTED_MUTED=") }.joined(separator: "\n") + "\n"
        for requested in ["false", "unknown"] {
            try Data((original + "REQUESTED_MUTED=\"\(requested)\"\n").utf8).write(to: muteURL, options: .atomic)
            XCTAssertNil(try current())
        }
    }

    func testHardMirrorCannotRemainPausedAfterGrantOrExpiry() throws {
        try writeMute(reason: .quietPeriod, hard: true)
        XCTAssertNil(try current())
        try writeLock(grant: 1_500)
        XCTAssertNil(try current())
        try writeLock(until: 1_000)
        XCTAssertNil(try current())
        try writeLock()
        XCTAssertEqual(try current(), .locked(pause, untilEpoch: 2_000))
    }

    func testLegacyHardReasonAndOtherKnownLegacySoftReasons() throws {
        try writeMute(reason: .hardLock, legacy: true)
        XCTAssertNil(try current())
        for reason in [MuteReason.scheduleWindow, .quietPeriod, .masterPaused, .none] {
            try writeMute(reason: reason, legacy: true)
            XCTAssertEqual(try current(), .paused(pause))
        }
        let text = try String(contentsOf: muteURL).replacingOccurrences(of: "SCHEMA_VERSION=\"1\"\n", with: "")
        try Data(text.utf8).write(to: muteURL, options: .atomic)
        XCTAssertEqual(try current(), .paused(pause), "Missing legacy schema retains schema 1")
        try writeLock()
        let lock = try String(contentsOf: lockURL).replacingOccurrences(of: "SCHEMA_VERSION=\"1\"\n", with: "")
        try Data(lock.utf8).write(to: lockURL, options: .atomic)
        XCTAssertEqual(try current(), .locked(pause, untilEpoch: 2_000))
    }

    func testSoftPIDHeartbeatAndExpiryBoundariesMatchShellReaders() throws {
        try writeMute(written: 880)
        XCTAssertEqual(try current(), .paused(pause))
        for written in [Int64(879), 1_001] {
            try writeMute(written: written)
            XCTAssertNil(try current())
        }
        for pid in [Int32(0), -43, 44] {
            try writeMute(pid: pid)
            XCTAssertNil(try current())
        }
        try writeMute(until: 1_000)
        XCTAssertEqual(try current(), .paused(pause))
        clock.advance(by: 1)
        XCTAssertNil(try current())
        try writeMute(until: 0, written: 1_001)
        XCTAssertEqual(try current(), .paused(pause))
    }

    func testMalformedKnownSoftFieldsNeverEnableRestriction() throws {
        try writeMute()
        let original = try String(contentsOf: muteURL)
        let replacements = [
            ("MUTED=\"true\"", "MUTED=\"yes\""),
            ("APP_PID=\"43\"", "APP_PID=\"PID_BODY_SENTINEL\""),
            ("UNTIL_EPOCH=\"0\"", "UNTIL_EPOCH=\"soon\""),
            ("UNTIL_EPOCH=\"0\"", "UNTIL_EPOCH=\"-1\""),
            ("WRITTEN_EPOCH=\"1000\"", "WRITTEN_EPOCH=\"future\""),
            ("SCHEMA_VERSION=\"1\"", "SCHEMA_VERSION=\"9\""),
            ("MUTE_LEVEL=\"soft\"", "MUTE_LEVEL=\"unknown\""),
            ("REASON=\"quiet_period\"", "REASON=\"unknown\"")
        ]
        for (before, after) in replacements {
            try Data(original.replacingOccurrences(of: before, with: after).utf8).write(to: muteURL, options: .atomic)
            XCTAssertNil(try current(), after)
        }
        for text in [original + "MUTED=\"true\"\n", original + "TRAILING_BODY_SENTINEL\n",
                     original + "\0", "MUTED=\"true\"\n"] {
            try Data(text.utf8).write(to: muteURL, options: .atomic)
            XCTAssertNil(try current())
        }
    }

    func testMalformedGrantAndOtherHardFieldsDoNotCreateAnEffectiveLock() throws {
        try writeLock()
        let original = try String(contentsOf: lockURL)
        for (before, after) in [
            ("LOCKED=\"true\"", "LOCKED=\"yes\""),
            ("LOCK_UNTIL_EPOCH=\"2000\"", "LOCK_UNTIL_EPOCH=\"forever\""),
            ("UNLOCK_UNTIL_EPOCH=\"0\"", "UNLOCK_UNTIL_EPOCH=\"bad\""),
            ("WRITTEN_EPOCH=\"0\"", "WRITTEN_EPOCH=\"bad\""),
            ("SCHEMA_VERSION=\"1\"", "SCHEMA_VERSION=\"9\"")
        ] {
            try Data(original.replacingOccurrences(of: before, with: after).utf8).write(to: lockURL, options: .atomic)
            XCTAssertNil(try current(), after)
        }
        try writeMute()
        XCTAssertEqual(try current(), .paused(pause), "Malformed hard state does not erase an independent valid soft cause")
    }

    func testInvalidColorsUseExistingPauseVisualDefaultsAndReadableForeground() throws {
        try MuteStateWriter.write(MuteStateData(muted: true, reason: .quietPeriod, untilEpoch: 0,
            writtenEpoch: 1_000, appPID: 43, pauseBg: "COLOR_BODY_SENTINEL", pauseFg: "invalid"), to: muteURL)
        let expected = PauseVisual(backgroundColor: nil, foregroundColor: nil,
                                   defaultBackgroundColor: UserConfStore.defaultPauseBgDark)
        XCTAssertEqual(try current(), .paused(expected))
    }

    func testUnsafeOversizedAndUnreadableFilesReportFixedUnavailableErrors() throws {
        let target = root.appendingPathComponent("target")
        try Data("PRIVATE_BODY_SENTINEL".utf8).write(to: target)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let fifo = root.appendingPathComponent("fifo")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        let oversized = root.appendingPathComponent("oversized")
        try Data(repeating: 0x61, count: 8_193).write(to: oversized)
        let unreadable = root.appendingPathComponent("unreadable")
        try Data("PRIVATE_BODY_SENTINEL".utf8).write(to: unreadable)
        XCTAssertEqual(chmod(unreadable.path, 0), 0)
        defer { chmod(unreadable.path, 0o600) }
        for url in [link, fifo, oversized, unreadable, root!] {
            for hardFile in [false, true] {
                let reader = VisualRestrictionPolicy(restrictions: restrictions,
                    muteURL: hardFile ? muteURL : url, lockURL: hardFile ? url : lockURL,
                    clock: clock, pidAlive: { _ in true })
                XCTAssertThrowsError(try current(reader)) { error in
                    guard case VisualRestrictionPolicyError.unavailable = error else {
                        return XCTFail("Unexpected error: \(error)")
                    }
                    XCTAssertFalse(String(describing: error).contains(root.path))
                    XCTAssertFalse(String(describing: error).contains("BODY_SENTINEL"))
                }
            }
        }
    }

    func testExpiredOriginalDeadlineAndDelayedLivenessCannotReturnARestriction() throws {
        try writeMute()
        XCTAssertThrowsError(try policy().current(deadline: DispatchTime.now().uptimeNanoseconds - 1)) { error in
            guard case VisualRestrictionPolicyError.timedOut = error else { return XCTFail("Unexpected error: \(error)") }
        }
        let reader = policy { _ in usleep(20_000); return true }
        XCTAssertThrowsError(try reader.current(deadline: DispatchTime.now().uptimeNanoseconds + 10_000_000)) { error in
            guard case VisualRestrictionPolicyError.timedOut = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    func testSoftTimeIsFreshAfterTheLivenessCheck() throws {
        let cases: [(TimeInterval, Int64)] = [(121, 0), (1, 1_000), (-1, 0)]
        for (advance, until) in cases {
            clock.set(to: Date(timeIntervalSince1970: 1_000))
            try writeMute(until: until)
            let reader = policy { _ in self.clock.advance(by: advance); return true }
            XCTAssertNil(try current(reader), "A stale initial time cannot authorize soft paint")
        }
    }

    func testSuspensionPersistedAtLivenessBarrierIsRecheckedBeforeReturningPolicy() throws {
        try writeMute()
        let entered = DispatchSemaphore(value: 0)
        let finished = expectation(description: "Fresh policy honors new suspension")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let reader = policy { _ in entered.signal(); release.wait(); return true }
        DispatchQueue.global().async {
            do {
                let selected = try reader.current(deadline: DispatchTime.now().uptimeNanoseconds + 100_000_000)
                XCTAssertNil(selected)
            }
            catch { XCTFail("Unexpected policy error: \(error)") }
            finished.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        try restrictions.write(suspended: true)
        release.signal()
        wait(for: [finished], timeout: 1)
    }
}
