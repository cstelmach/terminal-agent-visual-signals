import XCTest
@testable import TAVSApp

// Lock-projection behavior of the Scheduler (spec D3/D7, section 2.2/2.3):
// hard schedule rules project lock.state, grants suspend hard-caused mute
// only, manual locks imply mute, and masterPaused is never hard.
final class SchedulerLockTests: XCTestCase {
    var tempDir: URL!
    var muteStateURL: URL!
    var scheduleURL: URL!
    var lockStateURL: URL!
    var clock: VirtualClock!
    var timerScheduler: MockTimerScheduler!
    var fileWatcher: MockFileWatcher!
    var broadcaster: MockBroadcaster!
    var scheduler: Scheduler!
    var cal: Calendar!
    // Monday 2026-04-20, 21:00 PT: outside the 08:00-20:00 weekday window.
    var outsideWindowDate: Date!
    // Monday 2026-04-20, 09:00 PT: inside the window, outside quiet periods.
    var insideWindowDate: Date!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-lock-scheduler-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        muteStateURL = tempDir.appendingPathComponent("mute.state")
        scheduleURL = tempDir.appendingPathComponent("schedule.json")
        lockStateURL = tempDir.appendingPathComponent("lock.state")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        cal = calendar

        outsideWindowDate = date(hour: 21, minute: 0)
        insideWindowDate = date(hour: 9, minute: 0)

        timerScheduler = MockTimerScheduler()
        fileWatcher = MockFileWatcher()
        broadcaster = MockBroadcaster()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func date(hour: Int, minute: Int) -> Date {
        cal.date(from: DateComponents(
            calendar: cal, timeZone: cal.timeZone,
            year: 2026, month: 4, day: 20, hour: hour, minute: minute, second: 0
        ))!
    }

    private func epoch(_ d: Date, offset: Int64 = 0) -> Int64 {
        Int64(d.timeIntervalSince1970) + offset
    }

    private func makeScheduler(at startDate: Date) {
        clock = VirtualClock(startingAt: startDate)
        scheduler = Scheduler(
            clock: clock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: cal
        )
    }

    private func writeConfig(windowHard: Bool? = nil, quietHard: Bool? = nil, masterActive: Bool = true) throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: masterActive,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00", hard: windowHard)
            ],
            quietPeriods: [
                QuietPeriod(id: "hourly", enabled: true, kind: .hourly,
                            startMinute: 50, endMinute: 59, hard: quietHard)
            ]
        )
        try ScheduleStore.save(config, to: scheduleURL)
    }

    private func muteStateContents() -> String {
        (try? String(contentsOf: muteStateURL, encoding: .utf8)) ?? ""
    }

    func testSuspensionPreservesMergedHardLockGrantAndOriginalExpiryTimers() throws {
        let now = date(hour: 9, minute: 55)
        try writeConfig(windowHard: true, quietHard: true)
        let manual = LockStateData(locked: true, reason: .manual,
            lockUntilEpoch: epoch(now, offset: 7_200), unlockUntilEpoch: epoch(now, offset: 900),
            writtenEpoch: epoch(now))
        try LockStateWriter.write(manual, to: lockStateURL)
        makeScheduler(at: now)
        scheduler.start()
        let savedLock = try Data(contentsOf: lockStateURL)
        let savedSchedule = try Data(contentsOf: scheduleURL)
        let calls = broadcaster.callOrder
        let restrictions = VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state"))
        try restrictions.write(suspended: true)
        scheduler.loadAndEvaluate()
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertEqual(scheduler.statusText, VisualRestrictionsStatus.suspended.message)
        XCTAssertEqual(try Data(contentsOf: lockStateURL), savedLock)
        XCTAssertEqual(try Data(contentsOf: scheduleURL), savedSchedule)
        XCTAssertTrue(timerScheduler.scheduledTimers.contains { !$0.repeating && $0.delay == 900 })
        XCTAssertTrue(timerScheduler.scheduledTimers.contains { !$0.repeating && $0.delay == 7_200 })
        clock.advance(by: 901)
        scheduler.loadAndEvaluate()
        XCTAssertEqual(LockStateReader.read(at: lockStateURL)?.lockUntilEpoch, manual.lockUntilEpoch)
        XCTAssertEqual(LockStateReader.read(at: lockStateURL)?.unlockUntilEpoch, 0)
        XCTAssertEqual(broadcaster.callOrder, calls)
        XCTAssertEqual(try Data(contentsOf: scheduleURL), savedSchedule)
        try restrictions.write(suspended: false)
        scheduler.loadAndEvaluate()
        XCTAssertTrue(scheduler.isMuted)
        XCTAssertTrue(scheduler.isHardLocked)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastCallCount, 0)
    }

    func testSuspensionOverridesSoftRuleWithManualLockAndGrantWithoutChangingDefinitions() throws {
        try writeConfig()
        let manual = LockStateData(locked: true, reason: .manual,
            lockUntilEpoch: epoch(outsideWindowDate, offset: 7_200),
            unlockUntilEpoch: epoch(outsideWindowDate, offset: 900), writtenEpoch: epoch(outsideWindowDate))
        try LockStateWriter.write(manual, to: lockStateURL)
        makeScheduler(at: outsideWindowDate)
        scheduler.start()
        XCTAssertTrue(scheduler.isMuted)
        let saved = try Data(contentsOf: lockStateURL)
        let calls = broadcaster.callOrder
        let restrictions = VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state"))
        try restrictions.write(suspended: true)
        scheduler.loadAndEvaluate()
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertEqual(scheduler.statusText, VisualRestrictionsStatus.suspended.message)
        XCTAssertEqual(try Data(contentsOf: lockStateURL), saved)
        XCTAssertEqual(broadcaster.callOrder, calls)
    }

    func testNewManualLockIsSavedButVisuallyInertUntilExplicitResume() throws {
        try writeConfig()
        let restrictions = VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state"))
        try restrictions.write(suspended: true)
        makeScheduler(at: insideWindowDate)
        scheduler.start()
        let savedSchedule = try Data(contentsOf: scheduleURL)
        scheduler.lockNow(seconds: 3_600)
        let lock = try XCTUnwrap(LockStateReader.read(at: lockStateURL))
        XCTAssertTrue(lock.locked)
        XCTAssertEqual(lock.reason, .manual)
        XCTAssertEqual(lock.lockUntilEpoch, epoch(insideWindowDate, offset: 3_600))
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertEqual(scheduler.statusText, VisualRestrictionsStatus.suspended.message)
        XCTAssertEqual(try Data(contentsOf: scheduleURL), savedSchedule)
        XCTAssertTrue(broadcaster.callOrder.isEmpty)
        try restrictions.write(suspended: false)
        scheduler.loadAndEvaluate()
        XCTAssertTrue(scheduler.isHardLocked)
        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 1)
    }

    func testConfiguredMasterCanResumeWithoutChallengeWhileVisualLockIsSuspended() throws {
        try writeConfig(masterActive: false)
        let manual = LockStateData(locked: true, reason: .manual,
            lockUntilEpoch: epoch(insideWindowDate, offset: 3_600), unlockUntilEpoch: 0,
            writtenEpoch: epoch(insideWindowDate))
        try LockStateWriter.write(manual, to: lockStateURL)
        try VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state"))
            .write(suspended: true)
        makeScheduler(at: insideWindowDate)
        scheduler.start()
        XCTAssertFalse(scheduler.masterActive)
        XCTAssertFalse(scheduler.isHardLocked)
        scheduler.togglePause()
        scheduler.loadAndEvaluate()
        XCTAssertTrue(try ScheduleStore.load(from: scheduleURL).masterActive)
        XCTAssertTrue(scheduler.masterActive)
        XCTAssertEqual(scheduler.visualRestrictionsStatus, .suspended)
        XCTAssertEqual(LockStateReader.read(at: lockStateURL)?.lockUntilEpoch, manual.lockUntilEpoch)
        XCTAssertTrue(broadcaster.callOrder.isEmpty)
    }

    func testManualLockAndGrantExpireDuringSuspensionWithoutScheduleOrReplay() throws {
        let manual = LockStateData(locked: true, reason: .manual,
            lockUntilEpoch: epoch(insideWindowDate, offset: 30), unlockUntilEpoch: epoch(insideWindowDate, offset: 15),
            writtenEpoch: epoch(insideWindowDate))
        try LockStateWriter.write(manual, to: lockStateURL)
        let restrictions = VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state"))
        try restrictions.write(suspended: true)
        makeScheduler(at: insideWindowDate)
        scheduler.start()
        XCTAssertTrue(timerScheduler.scheduledTimers.contains { !$0.repeating && $0.delay == 15 })
        XCTAssertTrue(timerScheduler.scheduledTimers.contains { !$0.repeating && $0.delay == 30 })
        clock.advance(by: 31)
        scheduler.loadAndEvaluate()
        XCTAssertEqual(LockStateReader.read(at: lockStateURL)?.locked, false)
        XCTAssertEqual(LockStateReader.read(at: lockStateURL)?.unlockUntilEpoch, 0)
        try restrictions.write(suspended: false)
        scheduler.loadAndEvaluate()
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertTrue(broadcaster.callOrder.isEmpty)
    }

    // MARK: - Hard schedule projection

    func testRequestedProjectionRetainsHardAndSoftCausesDuringSuspension() throws {
        let restrictions = VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state"))
        try restrictions.write(suspended: true)
        for hard in [true, false] {
            try writeConfig(windowHard: hard)
            makeScheduler(at: outsideWindowDate)
            scheduler.start()
            XCTAssertFalse(scheduler.isMuted)
            XCTAssertTrue(muteStateContents().contains("MUTED=\"false\""))
            XCTAssertTrue(muteStateContents().contains("REQUESTED_MUTED=\"true\""))
            XCTAssertTrue(muteStateContents().contains("MUTE_LEVEL=\"\(hard ? "hard" : "soft")\""))
            XCTAssertTrue(muteStateContents().contains("UNTIL_EPOCH=\"\(epoch(outsideWindowDate, offset: 11 * 3600))\""))
            XCTAssertTrue(muteStateContents().contains("PAUSE_BG=\"#3A3A3A\""))
            scheduler.stop()
        }
    }

    func testUnmutedProjectionIsSavedBeforeVisualReconciliation() throws {
        try writeConfig()
        makeScheduler(at: outsideWindowDate)
        scheduler.start()
        var cleared = false
        broadcaster.onPausedClear = { [unowned self] in
            cleared = true
            XCTAssertTrue(self.muteStateContents().contains("MUTED=\"false\""))
            XCTAssertTrue(self.muteStateContents().contains("REQUESTED_MUTED=\"false\""))
        }
        clock.set(to: outsideWindowDate.addingTimeInterval(11 * 3600))
        scheduler.loadAndEvaluate()
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertTrue(cleared)
    }

    func testHardWindowProjectsLockStateAndBroadcastsLocked() throws {
        try writeConfig(windowHard: true)
        makeScheduler(at: outsideWindowDate)
        scheduler.start()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertTrue(scheduler.isHardLocked)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 0)

        let lock = LockStateReader.read(at: lockStateURL)
        XCTAssertNotNil(lock)
        XCTAssertTrue(lock!.locked)
        XCTAssertEqual(lock!.reason, .schedule)
        XCTAssertGreaterThan(lock!.lockUntilEpoch, epoch(outsideWindowDate))
        XCTAssertTrue(scheduler.statusText.hasPrefix("Locked until"))
    }

    func testSoftWindowCreatesNoLockState() throws {
        try writeConfig()
        makeScheduler(at: outsideWindowDate)
        scheduler.start()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: lockStateURL.path))
    }

    func testHardQuietPeriodIsHard() throws {
        try writeConfig(quietHard: true)
        makeScheduler(at: date(hour: 9, minute: 55))
        scheduler.start()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertTrue(scheduler.isHardLocked)
    }

    func testMasterPausedIsNeverHard() throws {
        try writeConfig(windowHard: true, masterActive: false)
        makeScheduler(at: insideWindowDate)
        scheduler.start()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 0)
    }

    // MARK: - Grants

    func testActiveGrantSuspendsHardMute() throws {
        try writeConfig(windowHard: true)
        let existing = LockStateData(
            locked: true, reason: .schedule,
            lockUntilEpoch: epoch(outsideWindowDate, offset: 7200),
            unlockUntilEpoch: epoch(outsideWindowDate, offset: 900),
            writtenEpoch: epoch(outsideWindowDate)
        )
        try LockStateWriter.write(existing, to: lockStateURL)

        makeScheduler(at: outsideWindowDate)
        scheduler.start()

        XCTAssertFalse(scheduler.isMuted, "Grant unmutes hard-caused mute")
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertTrue(muteStateContents().contains("MUTED=\"false\""))
        XCTAssertTrue(scheduler.statusText.hasPrefix("Unlocked until"))
        // Grant survives the rewrite (spec 2.2 merge).
        XCTAssertEqual(LockStateReader.read(at: lockStateURL)?.unlockUntilEpoch,
                       existing.unlockUntilEpoch)
    }

    func testGrantDoesNotAffectSoftMute() throws {
        try writeConfig()
        let existing = LockStateData(
            locked: true, reason: .manual,
            lockUntilEpoch: epoch(outsideWindowDate, offset: 7200),
            unlockUntilEpoch: epoch(outsideWindowDate, offset: 900),
            writtenEpoch: epoch(outsideWindowDate)
        )
        try LockStateWriter.write(existing, to: lockStateURL)

        makeScheduler(at: outsideWindowDate)
        scheduler.start()

        XCTAssertTrue(scheduler.isMuted, "Soft schedule mute is never suspended by a grant")
        XCTAssertFalse(scheduler.isHardLocked)
    }

    // MARK: - Manual lock

    func testManualLockImpliesMuteInsideAllowedWindow() throws {
        try writeConfig()
        let manual = LockStateData(
            locked: true, reason: .manual,
            lockUntilEpoch: epoch(insideWindowDate, offset: 3600),
            unlockUntilEpoch: 0,
            writtenEpoch: epoch(insideWindowDate)
        )
        try LockStateWriter.write(manual, to: lockStateURL)

        makeScheduler(at: insideWindowDate)
        scheduler.start()

        XCTAssertTrue(scheduler.isMuted, "Hard lock implies mute")
        XCTAssertTrue(scheduler.isHardLocked)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 1)
        XCTAssertTrue(muteStateContents().contains("REASON=\"hard_lock\""))
    }

    func testExpiredManualLockReleases() throws {
        try writeConfig()
        let manual = LockStateData(
            locked: true, reason: .manual,
            lockUntilEpoch: epoch(insideWindowDate, offset: -10),
            unlockUntilEpoch: 0,
            writtenEpoch: epoch(insideWindowDate, offset: -3600)
        )
        try LockStateWriter.write(manual, to: lockStateURL)

        makeScheduler(at: insideWindowDate)
        scheduler.start()

        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertEqual(LockStateReader.read(at: lockStateURL)?.locked, false)
    }

    // MARK: - togglePause gate (defense in depth)

    func testPausingMoreIsAllowedWhileHardLocked() throws {
        try writeConfig(windowHard: true)
        makeScheduler(at: outsideWindowDate)
        scheduler.start()
        XCTAssertTrue(scheduler.isHardLocked)

        // masterActive true → toggling would pause, which is ALWAYS allowed.
        scheduler.togglePause()
        let reloaded = try ScheduleStore.load(from: scheduleURL)
        XCTAssertFalse(reloaded.masterActive, "Pausing more is never gated")
    }

    func testTogglePauseResumeRefusedWhileManuallyLocked() throws {
        // masterPaused itself is never hard, so the refusal path engages when
        // a MANUAL lock is active while the master toggle sits on paused.
        try writeConfig(masterActive: false)
        let manual = LockStateData(
            locked: true, reason: .manual,
            lockUntilEpoch: epoch(insideWindowDate, offset: 3600),
            unlockUntilEpoch: 0,
            writtenEpoch: epoch(insideWindowDate)
        )
        try LockStateWriter.write(manual, to: lockStateURL)

        makeScheduler(at: insideWindowDate)
        scheduler.start()
        XCTAssertTrue(scheduler.isHardLocked)

        scheduler.togglePause()
        let reloaded = try ScheduleStore.load(from: scheduleURL)
        XCTAssertFalse(reloaded.masterActive, "Resume is refused while hard-locked")
    }
}
