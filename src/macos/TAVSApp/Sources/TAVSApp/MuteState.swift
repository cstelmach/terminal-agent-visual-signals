import Foundation

enum MuteReason: String, Codable {
    case scheduleWindow = "schedule_window"
    case quietPeriod = "quiet_period"
    case masterPaused = "master_paused"
    // Manual hard lock (tavs lock now) muting outside any schedule cause.
    case hardLock = "hard_lock"
    case none = ""
}

struct MuteStateData {
    var muted: Bool
    var reason: MuteReason
    var untilEpoch: Int64
    var writtenEpoch: Int64
    var appPID: Int32
    // Resolved pause visual at write time, so the shell integration can paint
    // soft pauses at shell open without any theme resolution. Additive fields;
    // shell readers parse known keys only, so SCHEMA_VERSION stays 1.
    var pauseBg: String = ""
    var pauseFg: String = ""
    var hardCaused: Bool = false
    var requestedMuted: Bool? = nil

    func serialize() -> String {
        var lines: [String] = []
        lines.append("MUTED=\"\(muted ? "true" : "false")\"")
        lines.append("REASON=\"\(reason.rawValue)\"")
        lines.append("UNTIL_EPOCH=\"\(untilEpoch)\"")
        lines.append("WRITTEN_EPOCH=\"\(writtenEpoch)\"")
        lines.append("APP_PID=\"\(appPID)\"")
        lines.append("PAUSE_BG=\"\(pauseBg)\"")
        lines.append("PAUSE_FG=\"\(pauseFg)\"")
        lines.append("SCHEMA_VERSION=\"1\"")
        lines.append("MUTE_LEVEL=\"\(hardCaused ? "hard" : "soft")\"")
        lines.append("REQUESTED_MUTED=\"\((requestedMuted ?? muted) ? "true" : "false")\"")
        return lines.joined(separator: "\n") + "\n"
    }
}

enum MuteStateWriter {
    static func write(_ state: MuteStateData, to url: URL) throws {
        let data = Data(state.serialize().utf8)
        try data.write(to: url, options: .atomic)
    }

    static func delete(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

enum MuteStateReader {
    /// Best-effort read of the persisted MUTED flag. Returns nil when the file
    /// is absent or malformed; callers should treat nil as "no prior state".
    /// Used by Scheduler.start() to seed `previousMuted` so restart-after-crash
    /// does not miss a muted→unmuted transition.
    static func readMutedFlag(at url: URL) -> Bool? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in contents.split(separator: "\n") {
            guard line.hasPrefix("MUTED=") else { continue }
            let value = line.dropFirst("MUTED=".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if value == "true" { return true }
            if value == "false" { return false }
            return nil
        }
        return nil
    }
}
