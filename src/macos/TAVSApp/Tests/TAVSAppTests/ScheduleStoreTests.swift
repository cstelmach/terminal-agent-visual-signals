import XCTest
@testable import TAVSApp

final class ScheduleStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavs-schedtest-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Parsing

    func testParseCanonicalFixture() throws {
        let url = Bundle.module.url(forResource: "schedule-canonical", withExtension: "json", subdirectory: "Fixtures")!
        let config = try ScheduleStore.load(from: url)

        XCTAssertEqual(config.version, 1)
        XCTAssertTrue(config.masterActive)
        XCTAssertEqual(config.allowedWindows.count, 2)
        XCTAssertEqual(config.quietPeriods.count, 2)

        let weekday = config.allowedWindows[0]
        XCTAssertEqual(weekday.id, "weekday-core-hours")
        XCTAssertTrue(weekday.enabled)
        XCTAssertEqual(weekday.days, [.mon, .tue, .wed, .thu, .fri])
        XCTAssertEqual(weekday.start, "08:00")
        XCTAssertEqual(weekday.end, "20:00")

        let hourly = config.quietPeriods[0]
        XCTAssertEqual(hourly.id, "top-of-hour-break")
        XCTAssertEqual(hourly.kind, .hourly)
        XCTAssertEqual(hourly.startMinute, 50)
        XCTAssertEqual(hourly.endMinute, 59)

        let lunch = config.quietPeriods[1]
        XCTAssertEqual(lunch.kind, .fixedDaily)
        XCTAssertEqual(lunch.start, "12:00")
        XCTAssertEqual(lunch.end, "13:00")
    }

    // MARK: - Round-trip (semantic equality)

    func testRoundTripSemanticEquality() throws {
        let url = Bundle.module.url(forResource: "schedule-canonical", withExtension: "json", subdirectory: "Fixtures")!
        let original = try ScheduleStore.load(from: url)

        let savePath = tempDir.appendingPathComponent("schedule.json")
        try ScheduleStore.save(original, to: savePath)

        let reloaded = try ScheduleStore.load(from: savePath)
        XCTAssertEqual(original, reloaded)
    }

    func testMutateAndRoundTrip() throws {
        let url = Bundle.module.url(forResource: "schedule-canonical", withExtension: "json", subdirectory: "Fixtures")!
        var config = try ScheduleStore.load(from: url)

        config.allowedWindows[0].start = "07:00"
        config.masterActive = false

        let savePath = tempDir.appendingPathComponent("schedule.json")
        try ScheduleStore.save(config, to: savePath)

        let reloaded = try ScheduleStore.load(from: savePath)
        XCTAssertEqual(reloaded.allowedWindows[0].start, "07:00")
        XCTAssertFalse(reloaded.masterActive)
        XCTAssertEqual(config, reloaded)
    }

    // MARK: - Validation: Valid configs

    func testValidCanonicalConfig() throws {
        let url = Bundle.module.url(forResource: "schedule-canonical", withExtension: "json", subdirectory: "Fixtures")!
        let config = try ScheduleStore.load(from: url)
        XCTAssertNoThrow(try ScheduleStore.validate(config))
    }

    func testValidMasterInactiveEmptyWindows() {
        let config = ScheduleConfig(
            version: 1, masterActive: false,
            allowedWindows: [], quietPeriods: []
        )
        XCTAssertNoThrow(try ScheduleStore.validate(config))
    }

    func testValidOvernightWindow() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "night-shift", enabled: true, days: [.fri], start: "22:00", end: "02:00")
            ],
            quietPeriods: []
        )
        XCTAssertNoThrow(try ScheduleStore.validate(config))
    }

    func testValidWrappingMinuteQuiet() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "all-week", enabled: true, days: Day.allCases, start: "00:00", end: "23:59")
            ],
            quietPeriods: [
                QuietPeriod(id: "wrap", enabled: true, kind: .hourly, startMinute: 55, endMinute: 5)
            ]
        )
        XCTAssertNoThrow(try ScheduleStore.validate(config))
    }

    // MARK: - Validation: Invalid configs

    func testInvalidEmptyWindowsWithMasterActive() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [], quietPeriods: []
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            XCTAssertEqual(e, .emptyAllowedWindows)
        }
    }

    func testInvalidEmptyWindowId() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "", enabled: true, days: [.mon], start: "08:00", end: "17:00")
            ],
            quietPeriods: []
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            XCTAssertEqual(e, .emptyId)
        }
    }

    func testInvalidEmptyDays() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "no-days", enabled: true, days: [], start: "08:00", end: "17:00")
            ],
            quietPeriods: []
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            XCTAssertEqual(e, .emptyDays(windowId: "no-days"))
        }
    }

    func testInvalidTimeFormat() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "bad-time", enabled: true, days: [.mon], start: "25:00", end: "17:00")
            ],
            quietPeriods: []
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            if case .invalidTime(let id, _) = e {
                XCTAssertEqual(id, "bad-time")
            } else {
                XCTFail("Expected invalidTime error")
            }
        }
    }

    func testInvalidTimeFormatBadMinute() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "bad-min", enabled: true, days: [.mon], start: "08:60", end: "17:00")
            ],
            quietPeriods: []
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            if case .invalidTime = e { } else { XCTFail("Expected invalidTime") }
        }
    }

    func testInvalidTimeFormatMalformed() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "no-colon", enabled: true, days: [.mon], start: "0800", end: "17:00")
            ],
            quietPeriods: []
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            if case .invalidTime = e { } else { XCTFail("Expected invalidTime") }
        }
    }

    func testInvalidZeroLengthWindow() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "zero", enabled: true, days: [.mon], start: "08:00", end: "08:00")
            ],
            quietPeriods: []
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            XCTAssertEqual(e, .zeroLengthWindow(windowId: "zero"))
        }
    }

    func testInvalidQuietPeriodMinuteRange() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "ok", enabled: true, days: [.mon], start: "08:00", end: "17:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "bad-range", enabled: true, kind: .hourly, startMinute: 60, endMinute: 59)
            ]
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            if case .invalidMinuteRange = e { } else { XCTFail("Expected invalidMinuteRange") }
        }
    }

    func testInvalidQuietPeriodEmptyId() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "ok", enabled: true, days: [.mon], start: "08:00", end: "17:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "", enabled: true, kind: .hourly, startMinute: 0, endMinute: 10)
            ]
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            XCTAssertEqual(e, .emptyId)
        }
    }

    func testInvalidFixedDailyQuietBadTime() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "ok", enabled: true, days: [.mon], start: "08:00", end: "17:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "bad-fixed", enabled: true, kind: .fixedDaily, start: "25:00", end: "13:00")
            ]
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            if case .invalidTime = e { } else { XCTFail("Expected invalidTime") }
        }
    }

    func testInvalidFixedDailyZeroLength() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "ok", enabled: true, days: [.mon], start: "08:00", end: "17:00")
            ],
            quietPeriods: [
                QuietPeriod(id: "zero-quiet", enabled: true, kind: .fixedDaily, start: "12:00", end: "12:00")
            ]
        )
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            guard let e = error as? ScheduleValidationError else {
                return XCTFail("Expected ScheduleValidationError")
            }
            if case .zeroLengthWindow = e { } else { XCTFail("Expected zeroLengthWindow") }
        }
    }

    // MARK: - Atomic save

    func testAtomicSaveCreatesFile() throws {
        let path = tempDir.appendingPathComponent("schedule.json")
        let config = ScheduleConfig(
            version: 1, masterActive: false,
            allowedWindows: [], quietPeriods: []
        )
        try ScheduleStore.save(config, to: path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
    }

    // MARK: - Phase 5: Draft workflow (add window → save → reload → validate)

    func testDraftAddWindowSaveReloadValidate() throws {
        let savePath = tempDir.appendingPathComponent("schedule.json")
        var config = ScheduleConfig(
            version: 1, masterActive: true, allowedWindows: [], quietPeriods: []
        )
        config.allowedWindows.append(
            TimeWindow(id: "work-hours", enabled: true,
                       days: [.mon, .tue, .wed, .thu, .fri],
                       start: "08:00", end: "20:00")
        )
        try ScheduleStore.save(config, to: savePath)
        let reloaded = try ScheduleStore.load(from: savePath)
        XCTAssertEqual(config, reloaded)
        XCTAssertNoThrow(try ScheduleStore.validate(reloaded))
    }

    func testDraftRemoveLastWindowInvalidatesWithMasterActive() {
        var config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "w1", enabled: true, days: [.mon], start: "08:00", end: "17:00")
            ],
            quietPeriods: []
        )
        XCTAssertNoThrow(try ScheduleStore.validate(config))

        config.allowedWindows.removeAll()
        XCTAssertThrowsError(try ScheduleStore.validate(config)) { error in
            XCTAssertEqual(error as? ScheduleValidationError, .emptyAllowedWindows)
        }
    }

    // MARK: - Disabled entries pass validation

    func testDisabledWindowsSkipValidation() {
        let config = ScheduleConfig(
            version: 1, masterActive: true,
            allowedWindows: [
                TimeWindow(id: "valid", enabled: true, days: [.mon], start: "08:00", end: "17:00"),
                TimeWindow(id: "", enabled: false, days: [], start: "bad", end: "bad"),
            ],
            quietPeriods: []
        )
        XCTAssertNoThrow(try ScheduleStore.validate(config))
    }
}
