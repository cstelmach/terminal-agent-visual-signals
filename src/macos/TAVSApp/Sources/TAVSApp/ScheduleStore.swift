import Foundation

enum Day: String, Codable, CaseIterable, Equatable {
    case mon, tue, wed, thu, fri, sat, sun
}

enum QuietKind: String, Codable, Equatable {
    case hourly
    case fixedDaily = "fixed_daily"
}

struct TimeWindow: Codable, Equatable {
    var id: String
    var enabled: Bool
    var days: [Day]
    var start: String
    var end: String
    // Hard window: OUTSIDE this window's hours, resuming requires the unlock
    // challenge (spec D7). Optional so pre-hard schedule.json keeps parsing;
    // nil encodes as an absent key.
    var hard: Bool?
}

struct QuietPeriod: Codable, Equatable {
    var id: String
    var enabled: Bool
    var kind: QuietKind

    var startMinute: Int?
    var endMinute: Int?

    var start: String?
    var end: String?

    // Hard quiet period: while inside it, resuming requires the unlock
    // challenge (spec D7).
    var hard: Bool?

    enum CodingKeys: String, CodingKey {
        case id, enabled, kind
        case startMinute = "start_minute"
        case endMinute = "end_minute"
        case start, end, hard
    }
}

struct ScheduleConfig: Codable, Equatable {
    var version: Int
    var masterActive: Bool
    var allowedWindows: [TimeWindow]
    var quietPeriods: [QuietPeriod]

    enum CodingKeys: String, CodingKey {
        case version
        case masterActive = "master_active"
        case allowedWindows = "allowed_windows"
        case quietPeriods = "quiet_periods"
    }
}

enum ScheduleValidationError: Error, Equatable {
    case emptyAllowedWindows
    case emptyId
    case emptyDays(windowId: String)
    case invalidTime(id: String, value: String)
    case zeroLengthWindow(windowId: String)
    case invalidMinuteRange(quietId: String, value: Int)
}

enum ScheduleStore {
    static func load(from url: URL) throws -> ScheduleConfig {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ScheduleConfig.self, from: data)
    }

    static func save(_ config: ScheduleConfig, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    static func validate(_ config: ScheduleConfig) throws {
        let enabledWindows = config.allowedWindows.filter { $0.enabled }
        if config.masterActive && enabledWindows.isEmpty {
            throw ScheduleValidationError.emptyAllowedWindows
        }

        for window in config.allowedWindows where window.enabled {
            try validateWindow(window)
        }

        for quiet in config.quietPeriods where quiet.enabled {
            try validateQuietPeriod(quiet)
        }
    }

    private static func validateWindow(_ window: TimeWindow) throws {
        if window.id.isEmpty {
            throw ScheduleValidationError.emptyId
        }
        if window.days.isEmpty {
            throw ScheduleValidationError.emptyDays(windowId: window.id)
        }
        try validateTimeString(window.start, id: window.id)
        try validateTimeString(window.end, id: window.id)
        if window.start == window.end {
            throw ScheduleValidationError.zeroLengthWindow(windowId: window.id)
        }
    }

    private static func validateQuietPeriod(_ quiet: QuietPeriod) throws {
        if quiet.id.isEmpty {
            throw ScheduleValidationError.emptyId
        }

        switch quiet.kind {
        case .hourly:
            if let sm = quiet.startMinute {
                if sm < 0 || sm > 59 {
                    throw ScheduleValidationError.invalidMinuteRange(quietId: quiet.id, value: sm)
                }
            }
            if let em = quiet.endMinute {
                if em < 0 || em > 59 {
                    throw ScheduleValidationError.invalidMinuteRange(quietId: quiet.id, value: em)
                }
            }

        case .fixedDaily:
            if let s = quiet.start {
                try validateTimeString(s, id: quiet.id)
            }
            if let e = quiet.end {
                try validateTimeString(e, id: quiet.id)
            }
            if let s = quiet.start, let e = quiet.end, s == e {
                throw ScheduleValidationError.zeroLengthWindow(windowId: quiet.id)
            }
        }
    }

    private static func validateTimeString(_ time: String, id: String) throws {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              hour >= 0, hour <= 23,
              minute >= 0, minute <= 59,
              parts[0].count == 2,
              parts[1].count == 2
        else {
            throw ScheduleValidationError.invalidTime(id: id, value: time)
        }
    }
}
