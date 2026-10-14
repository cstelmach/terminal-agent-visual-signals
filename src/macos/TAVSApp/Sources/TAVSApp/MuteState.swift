import Foundation
import Darwin

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
        let deadline = DispatchTime.now().uptimeNanoseconds + 100_000_000
        func checkDeadline() throws {
            guard DispatchTime.now().uptimeNanoseconds < deadline else { throw POSIXError(.ETIMEDOUT) }
        }
        try RuntimeDirectoryTrust.check(url.deletingLastPathComponent(), create: true, deadline: deadline)
        _ = try validateDestination(url)
        let data = Data(state.serialize().utf8)
        guard data.count <= 8_192 else { throw POSIXError(.EFBIG) }
        try checkDeadline()
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".mute-state-\(UUID().uuidString).tmp")
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw POSIXError(.EACCES) }
        defer { close(fd); unlink(temporary.path) }
        guard fchmod(fd, 0o600) == 0 else { throw POSIXError(.EACCES) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                try checkDeadline()
                let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw POSIXError(.EIO) }
                offset += count
            }
        }
        try checkDeadline()
        guard rename(temporary.path, url.path) == 0 else { throw POSIXError(.EIO) }
    }

    static func delete(at url: URL) throws {
        try RuntimeDirectoryTrust.check(url.deletingLastPathComponent())
        guard try validateDestination(url) else { return }
        guard unlink(url.path) == 0 else { throw POSIXError(.EIO) }
    }

    // Generated projections may replace trusted malformed bytes, never unsafe objects.
    private static func validateDestination(_ url: URL) throws -> Bool {
        var info = stat()
        if lstat(url.path, &info) != 0 {
            if errno == ENOENT { return false }
            throw POSIXError(.EACCES)
        }
        guard info.st_mode & S_IFMT == S_IFREG, RuntimeDirectoryTrust.owned(info) else {
            throw POSIXError(.EINVAL)
        }
        return true
    }
}

enum MuteStateReader {
    /// Best-effort read of the persisted MUTED flag. Returns nil when the file
    /// is absent or malformed; callers should treat nil as "no prior state".
    /// Used by Scheduler.start() to seed `previousMuted` so restart-after-crash
    /// does not miss a muted→unmuted transition.
    static func readMutedFlag(at url: URL) -> Bool? {
        try? readMutedFlagChecked(at: url)
    }

    static func readMutedFlagChecked(at url: URL,
                                    deadline: UInt64 = DispatchTime.now().uptimeNanoseconds + 100_000_000) throws -> Bool? {
        func checkDeadline() throws {
            guard DispatchTime.now().uptimeNanoseconds < deadline else { throw POSIXError(.ETIMEDOUT) }
        }
        try checkDeadline()
        try RuntimeDirectoryTrust.check(url.deletingLastPathComponent(), deadline: deadline)
        var before = stat()
        if lstat(url.path, &before) != 0 {
            let error = errno
            try checkDeadline()
            if error == ENOENT { return nil }
            throw POSIXError(.EACCES)
        }
        guard before.st_mode & S_IFMT == S_IFREG, RuntimeDirectoryTrust.owned(before),
              before.st_size >= 0, before.st_size <= 8_192 else { throw POSIXError(.EINVAL) }
        try checkDeadline()
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { try checkDeadline(); throw POSIXError(.EACCES) }
        defer { close(fd) }
        try checkDeadline()
        var current = stat()
        guard fstat(fd, &current) == 0, current.st_mode & S_IFMT == S_IFREG,
              RuntimeDirectoryTrust.owned(current), current.st_dev == before.st_dev,
              current.st_ino == before.st_ino, current.st_size >= 0, current.st_size <= 8_192 else {
            throw POSIXError(.EINVAL)
        }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 8_193)
        while true {
            try checkDeadline()
            let count = Darwin.read(fd, &buffer, buffer.count - data.count), error = errno
            try checkDeadline()
            if count == 0 { break }
            if count < 0 {
                if error == EINTR { continue }
                throw POSIXError(.EIO)
            }
            guard data.count + count <= 8_192 else { throw POSIXError(.EFBIG) }
            data.append(contentsOf: buffer.prefix(count))
        }
        guard let contents = String(data: data, encoding: .utf8) else { throw POSIXError(.EINVAL) }
        for line in contents.split(separator: "\n") {
            guard line.hasPrefix("MUTED=") else { continue }
            let value = line.dropFirst("MUTED=".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            try checkDeadline()
            if value == "true" { return true }
            if value == "false" { return false }
            throw POSIXError(.EINVAL)
        }
        throw POSIXError(.EINVAL)
    }
}
