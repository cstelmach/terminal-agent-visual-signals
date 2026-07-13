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

    // MARK: - Hard schedule projection

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
