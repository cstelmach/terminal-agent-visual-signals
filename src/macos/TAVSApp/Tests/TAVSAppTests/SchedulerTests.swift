import XCTest
import protocol Combine.Publisher
@testable import TAVSApp

// MARK: - Fixture types

private struct SchedulerFixtureFile: Codable {
    let configs: [String: ScheduleConfig]
    let cases: [SchedulerTestCase]
}

private struct SchedulerTestCase: Codable {
    let name: String
    let configName: String
    let timezone: String
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let second: Int
    let expectedMuted: Bool
    let expectedReason: String

    enum CodingKeys: String, CodingKey {
        case name, timezone, year, month, day, hour, minute, second
        case configName = "config_name"
        case expectedMuted = "expected_muted"
        case expectedReason = "expected_reason"
    }
}

// MARK: - Evaluator tests (pure function, fixture-driven)

final class ScheduleEvaluatorTests: XCTestCase {

    func testEvaluateFromFixtureMatrix() throws {
        let fixture = try loadFixture()

        for testCase in fixture.cases {
            guard let config = fixture.configs[testCase.configName] else {
                XCTFail("Config '\(testCase.configName)' not found for case '\(testCase.name)'")
                continue
            }

            let calendar = makeCalendar(timezone: testCase.timezone)
            let date = makeDate(from: testCase, calendar: calendar)

            let result = ScheduleEvaluator.evaluate(at: date, rules: config, calendar: calendar)

            let expectedReason: MuteReason
            if testCase.expectedReason.isEmpty {
                expectedReason = .none
            } else {
                expectedReason = MuteReason(rawValue: testCase.expectedReason)!
            }

            XCTAssertEqual(result.muted, testCase.expectedMuted,
                           "Case '\(testCase.name)': expected muted=\(testCase.expectedMuted), got \(result.muted)")
            XCTAssertEqual(result.reason, expectedReason,
                           "Case '\(testCase.name)': expected reason=\(testCase.expectedReason), got \(result.reason.rawValue)")
        }
    }

    // MARK: - nextTransition tests

    func testNextTransitionActiveToHourlyQuiet() {
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "hourly", enabled: true, kind: .hourly,
                            startMinute: 50, endMinute: 59)
            ]
        )

        let calendar = makeCalendar(timezone: "America/Los_Angeles")
        // Mon Apr 20 2026 at 09:00 → active; next mute at 09:50
        let date = makeDateFromComponents(year: 2026, month: 4, day: 20, hour: 9, minute: 0, calendar: calendar)

        let next = ScheduleEvaluator.nextTransition(after: date, rules: config, calendar: calendar)

        XCTAssertNotNil(next)
        let comps = calendar.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 50)
    }

    func testNextTransitionHourlyQuietToActive() {
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "hourly", enabled: true, kind: .hourly,
                            startMinute: 50, endMinute: 59)
            ]
        )

        let calendar = makeCalendar(timezone: "America/Los_Angeles")
        // Mon Apr 20 2026 at 09:55 → muted (quiet); next active at 10:00
        let date = makeDateFromComponents(year: 2026, month: 4, day: 20, hour: 9, minute: 55, calendar: calendar)

        let next = ScheduleEvaluator.nextTransition(after: date, rules: config, calendar: calendar)

        XCTAssertNotNil(next)
        let comps = calendar.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 0)
    }

    func testNextTransitionWindowEndToMuted() {
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )

        let calendar = makeCalendar(timezone: "America/Los_Angeles")
        // Mon Apr 20 2026 at 19:30 → active; next mute at 20:00 (window ends)
        let date = makeDateFromComponents(year: 2026, month: 4, day: 20, hour: 19, minute: 30, calendar: calendar)

        let next = ScheduleEvaluator.nextTransition(after: date, rules: config, calendar: calendar)

        XCTAssertNotNil(next)
        let comps = calendar.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(comps.hour, 20)
        XCTAssertEqual(comps.minute, 0)
    }

    func testNextTransitionMasterPausedNoTransition() {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )

        let calendar = makeCalendar(timezone: "America/Los_Angeles")
        let date = makeDateFromComponents(year: 2026, month: 4, day: 20, hour: 9, minute: 0, calendar: calendar)

        let next = ScheduleEvaluator.nextTransition(after: date, rules: config, calendar: calendar)

        XCTAssertNil(next, "Master paused has no automatic transition")
    }

    func testNextTransitionOutsideWindowToActive() {
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )

        let calendar = makeCalendar(timezone: "America/Los_Angeles")
        // Mon Apr 20 2026 at 21:00 → muted; next active at 08:00 Tue
        let date = makeDateFromComponents(year: 2026, month: 4, day: 20, hour: 21, minute: 0, calendar: calendar)

        let next = ScheduleEvaluator.nextTransition(after: date, rules: config, calendar: calendar)

        XCTAssertNotNil(next)
        let comps = calendar.dateComponents([.month, .day, .hour, .minute], from: next!)
        XCTAssertEqual(comps.day, 21)
        XCTAssertEqual(comps.hour, 8)
        XCTAssertEqual(comps.minute, 0)
    }

    // MARK: - DST transition tests

    func testNextTransitionAcrossSpringForward() {
        // 2026-03-08: spring forward at 02:00 PST → 03:00 PDT
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "sun", enabled: true, days: [.sun],
                           start: "01:00", end: "04:00")
            ],
            quietPeriods: []
        )

        let calendar = makeCalendar(timezone: "America/Los_Angeles")
        // Sun Mar 8 2026 at 01:30 PST → active; window ends at 04:00 PDT
        let date = makeDateFromComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 30, calendar: calendar)

        let next = ScheduleEvaluator.nextTransition(after: date, rules: config, calendar: calendar)

        XCTAssertNotNil(next, "Should find transition even across DST gap")
        let comps = calendar.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(comps.hour, 4, "Window ends at 04:00 PDT despite spring-forward gap")
        XCTAssertEqual(comps.minute, 0)
    }

    func testNextTransitionAcrossFallBack() {
        // 2026-11-01: fall back at 02:00 PDT → 01:00 PST
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "sun", enabled: true, days: [.sun],
                           start: "00:00", end: "03:00")
            ],
            quietPeriods: []
        )

        let calendar = makeCalendar(timezone: "America/Los_Angeles")
        // Sun Nov 1 2026 at 00:30 → active; window ends at 03:00 PST
        let date = makeDateFromComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 30, calendar: calendar)

        let next = ScheduleEvaluator.nextTransition(after: date, rules: config, calendar: calendar)

        XCTAssertNotNil(next, "Should find transition across fall-back")
        let comps = calendar.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(comps.hour, 3, "Window ends at 03:00 PST despite fall-back")
        XCTAssertEqual(comps.minute, 0)
    }

    // MARK: - Helpers

    private func loadFixture() throws -> SchedulerFixtureFile {
        let url = Bundle.module.url(forResource: "scheduler-matrix", withExtension: "json", subdirectory: "Fixtures")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SchedulerFixtureFile.self, from: data)
    }

    private func makeCalendar(timezone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone)!
        return calendar
    }

    private func makeDate(from tc: SchedulerTestCase, calendar: Calendar) -> Date {
        return makeDateFromComponents(
            year: tc.year, month: tc.month, day: tc.day,
            hour: tc.hour, minute: tc.minute, second: tc.second,
            calendar: calendar
        )
    }

    private func makeDateFromComponents(
        year: Int, month: Int, day: Int,
        hour: Int, minute: Int, second: Int = 0,
        calendar: Calendar
    ) -> Date {
        let comps = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second
        )
        return calendar.date(from: comps)!
    }
}

// MARK: - Scheduler lifecycle tests (with mocks)

final class SchedulerLifecycleTests: XCTestCase {
    private var tempDir: URL!
    private var muteStateURL: URL!
    private var scheduleURL: URL!
    private var clock: VirtualClock!
    private var timerScheduler: MockTimerScheduler!
    private var fileWatcher: MockFileWatcher!
    private var broadcaster: MockBroadcaster!
    private var scheduler: Scheduler!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-scheduler-test-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        muteStateURL = tempDir.appendingPathComponent("mute.state")
        scheduleURL = tempDir.appendingPathComponent("schedule.json")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let startDate = {
            let comps = DateComponents(
                calendar: cal, timeZone: cal.timeZone,
                year: 2026, month: 4, day: 20, hour: 9, minute: 0, second: 0
            )
            return cal.date(from: comps)!
        }()

        clock = VirtualClock(startingAt: startDate)
        timerScheduler = MockTimerScheduler()
        fileWatcher = MockFileWatcher()
        broadcaster = MockBroadcaster()

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

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeStandardConfig() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "hourly", enabled: true, kind: .hourly,
                            startMinute: 50, endMinute: 59)
            ]
        )
        try ScheduleStore.save(config, to: scheduleURL)
    }

    func testStartupRejectsDecodableInvalidScheduleWithoutPaintingOrChangingIt() throws {
        try writeStandardConfig()
        var invalid = try ScheduleStore.load(from: scheduleURL)
        invalid.allowedWindows[0].start = "bad"
        try ScheduleStore.save(invalid, to: scheduleURL)
        let original = try Data(contentsOf: scheduleURL)
        scheduler.start()
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 0)
        XCTAssertTrue(scheduler.statusText.contains("Schedule rejected"), scheduler.statusText)
        XCTAssertEqual(try Data(contentsOf: scheduleURL), original)
        scheduler.stop()
    }

    func testWatcherRejectsInvalidScheduleAndAcceptsLaterValidReplacement() throws {
        try writeStandardConfig(); scheduler.start()
        var invalid = try ScheduleStore.load(from: scheduleURL)
        invalid.allowedWindows[0].start = "09"
        try ScheduleStore.save(invalid, to: scheduleURL)
        let original = try Data(contentsOf: scheduleURL)
        let rejected = expectation(description: "Invalid reload reported")
        let rejection = scheduler.$statusText.first { $0.contains("Schedule rejected") }
            .sink { _ in rejected.fulfill() }
        defer { rejection.cancel(); scheduler.stop() }
        fileWatcher.simulateChange(); wait(for: [rejected], timeout: 2)
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 0)
        XCTAssertEqual(try Data(contentsOf: scheduleURL), original)
        try writeStandardConfig()
        let accepted = expectation(description: "Valid replacement evaluated")
        let replacement = scheduler.$statusText.first { $0.hasPrefix("Active") }
            .sink { _ in accepted.fulfill() }
        defer { replacement.cancel() }
        fileWatcher.simulateChange(); wait(for: [accepted], timeout: 2)
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertTrue(scheduler.statusText.hasPrefix("Active"), scheduler.statusText)
        XCTAssertEqual(timerScheduler.scheduledTimers.filter { $0.repeating }.count, 1)
    }

    func testInvalidScheduleStillProjectsAnExistingManualLock() throws {
        try writeStandardConfig()
        var invalid = try ScheduleStore.load(from: scheduleURL)
        invalid.allowedWindows[0].start = "bad"
        try ScheduleStore.save(invalid, to: scheduleURL)
        let now = Int64(clock.now().timeIntervalSince1970)
        try LockStateWriter.write(LockStateData(locked: true, reason: .manual,
            lockUntilEpoch: now + 120, unlockUntilEpoch: 0, writtenEpoch: now,
            lockBg: "#112233", lockFg: "#EEEEEE"), to: tempDir.appendingPathComponent("lock.state"))
        scheduler.start(); defer { scheduler.stop() }
        XCTAssertTrue(scheduler.isMuted); XCTAssertTrue(scheduler.isHardLocked)
        XCTAssertEqual(scheduler.reason, .hardLock)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 1)
        XCTAssertTrue(scheduler.statusText.contains("Schedule rejected"), scheduler.statusText)
        XCTAssertEqual(try ScheduleStore.load(from: scheduleURL), invalid)
    }

    func testSuspensionClearsPriorPaintAndSuppressesTicksThenResumeRepaintsCurrentPause() throws {
        try writeStandardConfig()
        var config = try ScheduleStore.load(from: scheduleURL)
        config.masterActive = false
        try ScheduleStore.save(config, to: scheduleURL)
        scheduler.start()
        XCTAssertTrue(scheduler.isMuted)
        let calls = broadcaster.callOrder
        let saved = try Data(contentsOf: scheduleURL)
        let restrictions = VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state"))
        try restrictions.write(suspended: true)
        scheduler.loadAndEvaluate()
        XCTAssertEqual(scheduler.visualRestrictionsStatus, .suspended)
        XCTAssertEqual(scheduler.statusText, VisualRestrictionsStatus.suspended.message)
        XCTAssertFalse(scheduler.masterActive)
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertEqual(scheduler.reason, .none)
        XCTAssertEqual(broadcaster.callOrder, calls + ["broadcastPausedClear", "broadcast"])
        let cleanupCalls = broadcaster.callOrder
        XCTAssertEqual(try Data(contentsOf: scheduleURL), saved)
        clock.advance(by: 60)
        timerScheduler.scheduledTimers.first { $0.repeating }?.handler()
        fileWatcher.simulateChange()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(broadcaster.callOrder, cleanupCalls)
        XCTAssertTrue(try String(contentsOf: muteStateURL).contains("MUTED=\"false\""))
        try restrictions.write(suspended: false)
        scheduler.loadAndEvaluate()
        XCTAssertEqual(scheduler.visualRestrictionsStatus, .active)
        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 2)
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastCallCount, 1)
    }

    func testHeartbeatRetriesFailedUpdatesAfterReleaseButNotDuringSuspension() throws {
        try writeStandardConfig()
        var config = try ScheduleStore.load(from: scheduleURL); config.masterActive = false
        try ScheduleStore.save(config, to: scheduleURL); scheduler.start()
        broadcaster.resultChanged?(false, [VisualRecoveryItem(status: .failed, reason: "test failure")])
        XCTAssertTrue(scheduler.terminalUpdateIssue?.contains("1 failed") == true)
        timerScheduler.scheduledTimers.first { $0.repeating }?.handler()
        XCTAssertEqual(broadcaster.retryCallCount, 1)
        try VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state")).write(suspended: true)
        timerScheduler.scheduledTimers.first { $0.repeating }?.handler()
        XCTAssertEqual(broadcaster.retryCallCount, 1)
        try VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("visual-restrictions.state")).write(suspended: false)
        config.masterActive = true; try ScheduleStore.save(config, to: scheduleURL)
        timerScheduler.scheduledTimers.first { $0.repeating }?.handler()
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertEqual(broadcaster.retryCallCount, 2)
        broadcaster.resultChanged?(false, [])
        XCTAssertTrue(scheduler.terminalUpdateIssue?.contains("Native catalogue unavailable") == true)
        broadcaster.resultChanged?(true, [])
        XCTAssertNil(scheduler.terminalUpdateIssue)
    }

    func testSuspendedStartupWithExplicitPersistentStoreIgnoresOldMutedProjection() throws {
        let restrictions = VisualRestrictionsStateStore(url: tempDir.appendingPathComponent("persistent/visual-restrictions.state"))
        try restrictions.write(suspended: true)
        try MuteStateWriter.write(MuteStateData(muted: true, reason: .masterPaused, untilEpoch: 0,
            writtenEpoch: Int64(clock.now().timeIntervalSince1970), appPID: 43), to: muteStateURL)
        let restarted = Scheduler(clock: clock, timerScheduler: timerScheduler, fileWatcher: fileWatcher,
            broadcaster: broadcaster, muteStateURL: muteStateURL, scheduleURL: scheduleURL,
            visualRestrictionsState: restrictions)
        restarted.start()
        XCTAssertEqual(restarted.visualRestrictionsStatus, .suspended)
        XCTAssertFalse(restarted.isMuted)
        XCTAssertFalse(restarted.isHardLocked)
        XCTAssertEqual(broadcaster.callOrder, ["discover", "broadcastPausedClear", "broadcast"])
        XCTAssertTrue(try String(contentsOf: muteStateURL).contains("MUTED=\"false\""))
        restarted.stop()
        let next = Scheduler(clock: clock, timerScheduler: timerScheduler, fileWatcher: fileWatcher,
            broadcaster: broadcaster, muteStateURL: muteStateURL, scheduleURL: scheduleURL,
            visualRestrictionsState: restrictions)
        next.start()
        XCTAssertEqual(next.visualRestrictionsStatus, .suspended)
        XCTAssertEqual(broadcaster.discoverCallCount, 2)
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 0)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 0)
        next.stop()
    }

    func testUnknownSuspensionStateDisablesVisualsWithoutChangingMaster() throws {
        try writeStandardConfig()
        var config = try ScheduleStore.load(from: scheduleURL)
        config.masterActive = false
        try ScheduleStore.save(config, to: scheduleURL)
        let path = tempDir.appendingPathComponent("visual-restrictions.state")
        try Data("SCHEMA_VERSION=\"77\"\nSUSPENDED=\"false\"\n".utf8).write(to: path)
        scheduler.start()
        XCTAssertEqual(scheduler.visualRestrictionsStatus, .unavailable)
        XCTAssertEqual(scheduler.statusText, VisualRestrictionsStatus.unavailable.message)
        XCTAssertFalse(scheduler.masterActive)
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.isHardLocked)
        XCTAssertEqual(broadcaster.callOrder, ["discover"])
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 0)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 0)
    }

    func testUnavailableStartupReconcilesPersistedMutedStateWithoutChangingMarkerOrRules() throws {
        try writeStandardConfig()
        var config = try ScheduleStore.load(from: scheduleURL)
        config.masterActive = false
        try ScheduleStore.save(config, to: scheduleURL)
        let saved = try Data(contentsOf: scheduleURL)
        try MuteStateWriter.write(MuteStateData(muted: true, reason: .masterPaused, untilEpoch: 0,
            writtenEpoch: Int64(clock.now().timeIntervalSince1970), appPID: 43), to: muteStateURL)
        let markerURL = tempDir.appendingPathComponent("visual-restrictions.state")
        let marker = Data("SCHEMA_VERSION=\"77\"\nSUSPENDED=\"false\"\n".utf8)
        try marker.write(to: markerURL)
        scheduler.start()
        XCTAssertEqual(scheduler.visualRestrictionsStatus, .unavailable)
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.masterActive)
        XCTAssertEqual(broadcaster.callOrder, ["discover", "broadcastPausedClear", "broadcast"])
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 0)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 0)
        XCTAssertEqual(try Data(contentsOf: markerURL), marker)
        XCTAssertEqual(try Data(contentsOf: scheduleURL), saved)
    }

    func testUnavailableMarkerTransitionClearsOnceAndPreservesRequestedPause() throws {
        try writeStandardConfig()
        var config = try ScheduleStore.load(from: scheduleURL)
        config.masterActive = false
        try ScheduleStore.save(config, to: scheduleURL)
        let saved = try Data(contentsOf: scheduleURL)
        scheduler.start()
        XCTAssertTrue(scheduler.isMuted)
        let calls = broadcaster.callOrder
        let markerURL = tempDir.appendingPathComponent("visual-restrictions.state")
        let marker = Data("SCHEMA_VERSION=\"77\"\nSUSPENDED=\"false\"\n".utf8)
        try marker.write(to: markerURL)
        scheduler.loadAndEvaluate()
        scheduler.loadAndEvaluate()
        XCTAssertEqual(scheduler.visualRestrictionsStatus, .unavailable)
        XCTAssertFalse(scheduler.isMuted)
        XCTAssertFalse(scheduler.masterActive)
        XCTAssertEqual(broadcaster.callOrder, calls + ["broadcastPausedClear", "broadcast"])
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastLockedCallCount, 0)
        XCTAssertEqual(try Data(contentsOf: markerURL), marker)
        XCTAssertEqual(try Data(contentsOf: scheduleURL), saved)
        XCTAssertTrue(try String(contentsOf: muteStateURL).contains("REQUESTED_MUTED=\"true\""))
    }

    func testStartWithConfigWritesMuteState() throws {
        try writeStandardConfig()
        scheduler.start()

        XCTAssertTrue(FileManager.default.fileExists(atPath: muteStateURL.path))
        let content = try String(contentsOf: muteStateURL)
        XCTAssertTrue(content.contains("MUTED=\"false\""))
        XCTAssertTrue(content.contains("SCHEMA_VERSION=\"1\""))
    }

    func testStartWithConfigSchedulesTimers() throws {
        try writeStandardConfig()
        scheduler.start()

        let repeating = timerScheduler.scheduledTimers.filter { $0.repeating }
        let oneShot = timerScheduler.scheduledTimers.filter { !$0.repeating }

        XCTAssertEqual(repeating.count, 1, "Heartbeat timer")
        XCTAssertEqual(repeating.first?.delay, 60, "Heartbeat interval")
        XCTAssertEqual(oneShot.count, 1, "Boundary timer for next quiet period")
    }

    func testStartWithoutConfigWritesUnmuted() throws {
        scheduler.start()

        XCTAssertTrue(FileManager.default.fileExists(atPath: muteStateURL.path))
        let content = try String(contentsOf: muteStateURL)
        XCTAssertTrue(content.contains("MUTED=\"false\""))
    }

    func testStartStartsFileWatch() throws {
        try writeStandardConfig()
        scheduler.start()

        XCTAssertEqual(fileWatcher.startCallCount, 1)
    }

    func testFileWatchTriggersReevaluation() throws {
        try writeStandardConfig()
        scheduler.start()

        let content1 = try String(contentsOf: muteStateURL)
        let epoch1 = extractWrittenEpoch(from: content1)

        clock.advance(by: 5)
        fileWatcher.simulateChange()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let content2 = try String(contentsOf: muteStateURL)
        let epoch2 = extractWrittenEpoch(from: content2)

        XCTAssertGreaterThan(epoch2, epoch1, "File change triggers re-evaluation with updated epoch")
    }

    func testHeartbeatUpdatesWrittenEpoch() throws {
        try writeStandardConfig()
        scheduler.start()

        let content1 = try String(contentsOf: muteStateURL)
        let epoch1 = extractWrittenEpoch(from: content1)

        clock.advance(by: 60)
        let heartbeat = timerScheduler.scheduledTimers.first { $0.repeating }
        heartbeat?.handler()

        let content2 = try String(contentsOf: muteStateURL)
        let epoch2 = extractWrittenEpoch(from: content2)

        XCTAssertGreaterThan(epoch2, epoch1, "Heartbeat advances WRITTEN_EPOCH")
    }

    func testMutedToUnmutedCallsBroadcaster() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "short-quiet", enabled: true, kind: .hourly,
                            startMinute: 0, endMinute: 0)
            ]
        )
        try ScheduleStore.save(config, to: scheduleURL)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let mutedDate = {
            let comps = DateComponents(
                calendar: cal, timeZone: cal.timeZone,
                year: 2026, month: 4, day: 20, hour: 9, minute: 0
            )
            return cal.date(from: comps)!
        }()

        let mutedClock = VirtualClock(startingAt: mutedDate)
        let mutedScheduler = Scheduler(
            clock: mutedClock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: cal
        )

        mutedScheduler.start()
        XCTAssertTrue(mutedScheduler.isMuted, "Should be muted at minute 0")
        XCTAssertEqual(broadcaster.broadcastCallCount, 0)

        mutedClock.set(to: {
            let comps = DateComponents(
                calendar: cal, timeZone: cal.timeZone,
                year: 2026, month: 4, day: 20, hour: 9, minute: 1
            )
            return cal.date(from: comps)!
        }())
        mutedScheduler.loadAndEvaluate()

        XCTAssertFalse(mutedScheduler.isMuted, "Should be unmuted at minute 1")
        XCTAssertEqual(broadcaster.broadcastCallCount, 1, "Broadcaster fires on muted→unmuted")
    }

    func testTogglePauseSavesConfig() throws {
        try writeStandardConfig()
        scheduler.start()

        XCTAssertFalse(scheduler.isMuted)

        scheduler.togglePause()

        let reloaded = try ScheduleStore.load(from: scheduleURL)
        XCTAssertFalse(reloaded.masterActive, "togglePause sets master_active=false")
    }

    func testStatusTextActiveWithNextMute() throws {
        try writeStandardConfig()
        scheduler.start()

        XCTAssertTrue(scheduler.statusText.hasPrefix("Active"), "Status should start with 'Active'")
        XCTAssertTrue(scheduler.statusText.contains("min"), "Status should mention minutes to next mute")
    }

    func testStatusTextSubMinuteRendersInSeconds() throws {
        // Reviewer N2: previously rendered "next mute in 0 min" for any
        // transition under 60 seconds. Now uses seconds for that range so
        // the menu reads cleanly through the final minute before mute.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let nowDate = cal.date(from: DateComponents(
            calendar: cal, timeZone: cal.timeZone,
            year: 2026, month: 4, day: 20, hour: 9, minute: 0, second: 30
        ))!

        let subMinClock = VirtualClock(startingAt: nowDate)
        let subMinScheduler = Scheduler(
            clock: subMinClock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: cal
        )

        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "soon", enabled: true, kind: .fixedDaily,
                            startMinute: nil, endMinute: nil,
                            start: "09:01", end: "09:02")
            ]
        )
        try ScheduleStore.save(config, to: scheduleURL)

        subMinScheduler.start()

        XCTAssertFalse(subMinScheduler.isMuted, "Should be unmuted at 09:00:30")
        XCTAssertTrue(subMinScheduler.statusText.contains("sec"),
                      "Sub-minute transition should render seconds, got: \(subMinScheduler.statusText)")
        XCTAssertFalse(subMinScheduler.statusText.contains("0 min"),
                       "Must not render '0 min' for sub-minute transitions")
    }

    func testStatusTextMuted() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "w", enabled: true, days: [.mon], start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)
        scheduler.start()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(scheduler.statusText, "Paused — click to resume")
    }

    // MARK: - Paused visual transition tests

    func testActiveToMutedPaintsPauseVisual() throws {
        try writeStandardConfig()
        let expectedVisual = makePauseVisual(background: "#123456", foreground: "#ABCDEF")
        let visualScheduler = Scheduler(
            clock: clock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: testCalendar,
            pauseVisualProvider: { expectedVisual }
        )

        visualScheduler.start()

        XCTAssertFalse(visualScheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 0)

        visualScheduler.togglePause()
        visualScheduler.loadAndEvaluate()

        XCTAssertTrue(visualScheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)
        XCTAssertEqual(broadcaster.lastPausedVisual, expectedVisual)
        XCTAssertEqual(broadcaster.broadcastCallCount, 0)
    }

    func testMutedToActiveClearsBeforePendingReplay() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        scheduler.start()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)

        scheduler.togglePause()
        scheduler.loadAndEvaluate()

        XCTAssertFalse(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastCallCount, 1)
        XCTAssertEqual(Array(broadcaster.callOrder.suffix(2)), ["broadcastPausedClear", "broadcast"])
    }

    func testMissingConfigWhileMutedClearsPauseVisualOnce() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        scheduler.start()
        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)

        try FileManager.default.removeItem(at: scheduleURL)
        scheduler.loadAndEvaluate()

        XCTAssertFalse(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastCallCount, 1)
        XCTAssertEqual(Array(broadcaster.callOrder.suffix(2)), ["broadcastPausedClear", "broadcast"])

        scheduler.loadAndEvaluate()
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 1,
                       "Repeated no-config evaluations must not replay the unmute transition")
        XCTAssertEqual(broadcaster.broadcastCallCount, 1)
    }

    private var testCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    private func makePauseVisual(background: String = "#3A3A3A", foreground: String = "#F2F2F2") -> PauseVisual {
        PauseVisual(
            backgroundColor: background,
            foregroundColor: foreground,
            defaultBackgroundColor: UserConfStore.defaultPauseBgDark
        )
    }

    func testForegroundOnlyChangeWhileMutedRepaints() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        var currentVisual = makePauseVisual(background: "#3A3A3A", foreground: "#F2F2F2")
        let dynScheduler = Scheduler(
            clock: clock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: testCalendar,
            pauseVisualProvider: { currentVisual }
        )

        dynScheduler.start()
        XCTAssertTrue(dynScheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)
        XCTAssertEqual(broadcaster.lastPausedVisual, currentVisual)

        currentVisual = makePauseVisual(background: "#3A3A3A", foreground: "#101010")
        dynScheduler.loadAndEvaluate()

        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 2,
                       "Foreground-only visual change while muted must trigger re-paint")
        XCTAssertEqual(broadcaster.lastPausedVisual, currentVisual)
    }

    func testBackgroundOnlyChangeWhileMutedRepaints() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        var currentVisual = makePauseVisual(background: "#3A3A3A", foreground: "#F2F2F2")
        let dynScheduler = Scheduler(
            clock: clock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: testCalendar,
            pauseVisualProvider: { currentVisual }
        )

        dynScheduler.start()
        XCTAssertTrue(dynScheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)
        XCTAssertEqual(broadcaster.lastPausedVisual, currentVisual)

        currentVisual = makePauseVisual(background: "#FF0000", foreground: "#F2F2F2")
        dynScheduler.loadAndEvaluate()

        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 2,
                       "Background-only visual change while muted must trigger re-paint")
        XCTAssertEqual(broadcaster.lastPausedVisual, currentVisual)
    }

    func testUnchangedPauseVisualIsIdempotent() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        let stableVisual = makePauseVisual(background: "#3A3A3A", foreground: "#F2F2F2")
        let stableScheduler = Scheduler(
            clock: clock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: testCalendar,
            pauseVisualProvider: { stableVisual }
        )

        stableScheduler.start()
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)

        // Three back-to-back re-evaluations (heartbeat, fs-watch, wake).
        stableScheduler.loadAndEvaluate()
        stableScheduler.loadAndEvaluate()
        stableScheduler.loadAndEvaluate()

        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1,
                       "Same visual across re-evals must NOT trigger re-paint")
    }

    func testAppearanceDerivedVisualChangeRepaintsOnEvaluation() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        let userConfURL = tempDir.appendingPathComponent("user.conf")
        try """
        TAVS_PAUSE_BG_DARK="#112233"
        TAVS_PAUSE_FG_DARK="#E0E0E0"
        TAVS_PAUSE_BG_LIGHT="#DDEEFF"
        TAVS_PAUSE_FG_LIGHT="#202020"
        """.write(to: userConfURL, atomically: true, encoding: .utf8)

        var isDark = true
        let appearanceScheduler = Scheduler(
            clock: clock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: testCalendar,
            pauseVisualProvider: {
                PauseVisualResolver.resolve(userConfURL: userConfURL, isDarkAppearance: isDark)
            }
        )

        appearanceScheduler.start()
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)
        XCTAssertEqual(broadcaster.lastPausedVisual,
                       makePauseVisual(background: "#112233", foreground: "#E0E0E0"))

        isDark = false
        appearanceScheduler.loadAndEvaluate()

        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 2,
                       "Appearance-driven visual changes must repaint on the next evaluation")
        XCTAssertEqual(broadcaster.lastPausedVisual,
                       PauseVisual(
                           backgroundColor: "#DDEEFF",
                           foregroundColor: "#202020",
                           defaultBackgroundColor: UserConfStore.defaultPauseBgLight
                       ))
    }

    func testHeartbeatDuringMuteIsStable() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        scheduler.start()

        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)

        clock.advance(by: 60)
        let heartbeat = timerScheduler.scheduledTimers.first { $0.repeating }
        heartbeat?.handler()

        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1,
                       "Heartbeat during mute should not re-trigger broadcastPaused")
    }

    func testAppStartupIntoMuted() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        scheduler.start()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1,
                       "Startup into muted should paint the pause visual")
        XCTAssertEqual(broadcaster.lastPausedVisual, makePauseVisual())
    }

    func testScheduleUnmuteClearsAndReplays() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "hourly", enabled: true, kind: .hourly,
                            startMinute: 50, endMinute: 59)
            ]
        )
        try ScheduleStore.save(config, to: scheduleURL)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let mutedDate = {
            let comps = DateComponents(
                calendar: cal, timeZone: cal.timeZone,
                year: 2026, month: 4, day: 20, hour: 9, minute: 55
            )
            return cal.date(from: comps)!
        }()

        let quietClock = VirtualClock(startingAt: mutedDate)
        let quietScheduler = Scheduler(
            clock: quietClock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: cal
        )

        quietScheduler.start()
        XCTAssertTrue(quietScheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)

        quietClock.set(to: {
            let comps = DateComponents(
                calendar: cal, timeZone: cal.timeZone,
                year: 2026, month: 4, day: 20, hour: 10, minute: 0
            )
            return cal.date(from: comps)!
        }())
        quietScheduler.loadAndEvaluate()

        XCTAssertFalse(quietScheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastCallCount, 1)
    }

    func testMutedToMutedReasonChangeNoRetrigger() throws {
        let config = ScheduleConfig(
            version: 1,
            masterActive: true,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "hourly", enabled: true, kind: .hourly,
                            startMinute: 50, endMinute: 59)
            ]
        )
        try ScheduleStore.save(config, to: scheduleURL)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let startDate = {
            let comps = DateComponents(
                calendar: cal, timeZone: cal.timeZone,
                year: 2026, month: 4, day: 20, hour: 19, minute: 55
            )
            return cal.date(from: comps)!
        }()

        let reasonClock = VirtualClock(startingAt: startDate)
        let reasonScheduler = Scheduler(
            clock: reasonClock,
            timerScheduler: timerScheduler,
            fileWatcher: fileWatcher,
            broadcaster: broadcaster,
            muteStateURL: muteStateURL,
            scheduleURL: scheduleURL,
            calendar: cal
        )

        reasonScheduler.start()
        XCTAssertTrue(reasonScheduler.isMuted)
        XCTAssertEqual(reasonScheduler.reason, .quietPeriod)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)

        reasonClock.set(to: {
            let comps = DateComponents(
                calendar: cal, timeZone: cal.timeZone,
                year: 2026, month: 4, day: 20, hour: 20, minute: 0
            )
            return cal.date(from: comps)!
        }())
        reasonScheduler.loadAndEvaluate()

        XCTAssertTrue(reasonScheduler.isMuted)
        XCTAssertEqual(reasonScheduler.reason, .scheduleWindow)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1,
                       "Reason change without mute change should not retrigger")
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 0)
        XCTAssertEqual(broadcaster.broadcastCallCount, 0)
    }

    // MARK: - B3 and H2 transition tests

    func testStartCallsTTYDiscoveryOnce() throws {
        // Startup requests cached-effect cleanup and native terminal binding
        // discovery exactly once, including when restrictions are disabled.
        try writeStandardConfig()

        XCTAssertEqual(broadcaster.discoverCallCount, 0)

        scheduler.start()

        XCTAssertEqual(broadcaster.discoverCallCount, 1,
                       "discoverAndRegisterActiveAgentTTYs must run on start")
    }

    func testStartupSeedsPreviousMutedFromDisk() throws {
        // B3: A pre-existing mute.state on disk (from a prior app run that
        // crashed while muted) must seed `previousMuted=true`, so a restart
        // into an UNMUTED schedule correctly fires the unmute transition.
        // Without this, terminals painted grey would be stuck forever.
        let staleState = MuteStateData(
            muted: true,
            reason: .masterPaused,
            untilEpoch: 0,
            writtenEpoch: Int64(Date().timeIntervalSince1970 - 60),
            appPID: 12345
        )
        try MuteStateWriter.write(staleState, to: muteStateURL)

        // Schedule is active (unmuted) — so start() must detect muted→unmuted.
        try writeStandardConfig()

        scheduler.start()

        XCTAssertFalse(scheduler.isMuted, "Schedule is active, so now unmuted")
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 1,
                       "Restart with stale muted state must fire clear transition")
        XCTAssertEqual(broadcaster.broadcastCallCount, 1,
                       "Restart with stale muted state must replay pending")
    }

    func testUnmuteTransitionDoesNotPurgePending() throws {
        // Race-window contract: a hook firing in the narrow gap between
        // broadcast()'s drain and writeMuteState(false) writes its OSC bytes
        // to pending/. The Scheduler must NOT delete those bytes — they
        // reflect the hook's current intent, not stale state. Earlier code
        // called `broadcaster.clearPending()` here, which silently dropped
        // the byte and made the user miss a paint. We verify the broadcaster
        // protocol no longer exposes a destructive clear method, so the
        // drift cannot regress without a compile error first.
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)

        scheduler.start()
        XCTAssertTrue(scheduler.isMuted)

        scheduler.togglePause()
        scheduler.loadAndEvaluate()

        XCTAssertFalse(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 1,
                       "Unmute fires the clear-paused paint exactly once")
        XCTAssertEqual(broadcaster.broadcastCallCount, 1,
                       "Unmute drains pending exactly once")
    }

    func testStartupWithNoMuteStateFileDefaultsToUnmuted() throws {
        // B3 boundary: fresh install / no mute.state on disk → previousMuted
        // remains its init default (false). Existing "App startup into muted"
        // behavior (paints grey on first muted eval) must not regress.
        let config = ScheduleConfig(
            version: 1,
            masterActive: false,
            allowedWindows: [
                TimeWindow(id: "weekday", enabled: true,
                           days: [.mon, .tue, .wed, .thu, .fri],
                           start: "08:00", end: "20:00")
            ],
            quietPeriods: []
        )
        try ScheduleStore.save(config, to: scheduleURL)
        // Ensure mute.state does NOT exist.
        try? FileManager.default.removeItem(at: muteStateURL)

        scheduler.start()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1,
                       "Startup into muted still fires paint")
        XCTAssertEqual(broadcaster.broadcastPausedClearCallCount, 0,
                       "No spurious clear when seed is absent")
    }

    // MARK: - Helpers

    private func extractWrittenEpoch(from content: String) -> Int64 {
        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("WRITTEN_EPOCH=") {
                let raw = line.replacingOccurrences(of: "WRITTEN_EPOCH=\"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                return Int64(raw) ?? 0
            }
        }
        return 0
    }
}
