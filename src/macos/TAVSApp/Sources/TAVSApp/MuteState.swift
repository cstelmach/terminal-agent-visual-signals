import Foundation

enum MuteReason: String, Codable {
    case scheduleWindow = "schedule_window"
    case quietPeriod = "quiet_period"
    case masterPaused = "master_paused"
    case none = ""
}

struct MuteStateData {
    var muted: Bool
    var reason: MuteReason
    var untilEpoch: Int64
    var writtenEpoch: Int64
    var appPID: Int32

    func serialize() -> String {
        var lines: [String] = []
        lines.append("MUTED=\"\(muted ? "true" : "false")\"")
        lines.append("REASON=\"\(reason.rawValue)\"")
        lines.append("UNTIL_EPOCH=\"\(untilEpoch)\"")
        lines.append("WRITTEN_EPOCH=\"\(writtenEpoch)\"")
        lines.append("APP_PID=\"\(appPID)\"")
        lines.append("SCHEMA_VERSION=\"1\"")
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
