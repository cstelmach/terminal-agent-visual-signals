import XCTest
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

    func testActiveToMutedPaintsGrey() throws {
        try writeStandardConfig()
        scheduler.start()

        XCTAssertFalse(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 0)

        scheduler.togglePause()
        scheduler.loadAndEvaluate()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(broadcaster.broadcastPausedCallCount, 1)
        XCTAssertEqual(broadcaster.broadcastCallCount, 0)
    }

    func testMutedToActiveClearsAndReplays() throws {
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
                       "Startup into muted should paint grey")
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
        XCTAssertEqual(broadcaster.clearPendingCallCount, 1,
                       "Post-unmute clearPending must discard orphan bytes")
    }

    func testUnmuteTransitionCallsClearPending() throws {
        // H2: On unmute transition, clearPending() must be called AFTER
        // writeMuteState so bytes that hooks dropped into pending/ during the
        // tiny gap are discarded rather than replayed as stale state later.
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
        XCTAssertEqual(broadcaster.clearPendingCallCount, 0,
                       "clearPending must not fire on enter-mute")

        scheduler.togglePause()
        scheduler.loadAndEvaluate()

        XCTAssertFalse(scheduler.isMuted)
        XCTAssertEqual(broadcaster.clearPendingCallCount, 1,
                       "clearPending must fire once on unmute")
    }

    func testEnterMuteDoesNotCallClearPending() throws {
        // H2 negative: clearPending is exclusively a post-unmute cleanup;
        // it must not fire when going active→muted.
        try writeStandardConfig()
        scheduler.start()

        XCTAssertEqual(broadcaster.clearPendingCallCount, 0)

        scheduler.togglePause()
        scheduler.loadAndEvaluate()

        XCTAssertTrue(scheduler.isMuted)
        XCTAssertEqual(broadcaster.clearPendingCallCount, 0,
                       "clearPending must not fire on enter-mute")
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
        XCTAssertEqual(broadcaster.clearPendingCallCount, 0)
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
