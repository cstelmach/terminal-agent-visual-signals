import Foundation
import Darwin

enum GlobalVisualRestriction: Equatable {
    case paused(PauseVisual)
    case locked(PauseVisual, untilEpoch: Int64)
}

enum VisualRestrictionPolicyError: Error { case unavailable, timedOut }

final class VisualRestrictionPolicy {
    private let restrictions: VisualRestrictionsStateStore
    private let muteURL: URL
    private let lockURL: URL
    private let clock: Clock
    private let pidAlive: (Int32) -> Bool

    init(restrictions: VisualRestrictionsStateStore, muteURL: URL, lockURL: URL,
         clock: Clock = SystemClock(), pidAlive: @escaping (Int32) -> Bool = { kill($0, 0) == 0 }) {
        self.restrictions = restrictions
        self.muteURL = muteURL
        self.lockURL = lockURL
        self.clock = clock
        self.pidAlive = pidAlive
    }

    func current(deadline: UInt64) throws -> GlobalVisualRestriction? {
        try check(deadline)
        let disabled = restrictions.read().disablesRestrictions
        try check(deadline)
        if disabled { return nil }
        let lockText = try readRule(lockURL, deadline: deadline)
        let now = Int64(clock.now().timeIntervalSince1970)
        try check(deadline)

        var selected: GlobalVisualRestriction?
        if let text = lockText, let fields = Self.fields(text),
           fields["LOCKED"] == "true" || fields["LOCKED"] == "false",
           Self.epoch(fields["LOCK_UNTIL_EPOCH"]) != nil,
           Self.epoch(fields["UNLOCK_UNTIL_EPOCH"] ?? "0") != nil,
           Self.epoch(fields["WRITTEN_EPOCH"] ?? "0") != nil,
           let state = LockStateReader.parse(text), state.isEffectivelyLocked(now: now) {
            selected = .locked(Self.visual(bg: state.lockBg, fg: state.lockFg), untilEpoch: state.lockUntilEpoch)
        } else if let text = try readRule(muteURL, deadline: deadline), let fields = Self.fields(text) {
            selected = try softRestriction(fields, deadline: deadline)
        }
        try check(deadline)
        let stillDisabled = restrictions.read().disablesRestrictions
        try check(deadline)
        return stillDisabled ? nil : selected
    }

    private func softRestriction(_ fields: [String: String], deadline: UInt64) throws -> GlobalVisualRestriction? {
        guard fields["MUTED"] == "true" || fields["MUTED"] == "false",
              fields["REQUESTED_MUTED"] ?? fields["MUTED"] == "true",
              let reason = MuteReason(rawValue: fields["REASON"] ?? "") else { return nil }
        switch fields["MUTE_LEVEL"] {
        case "hard": return nil
        case "soft": break
        case nil: if reason == .hardLock { return nil }
        default: return nil
        }
        guard let until = Self.epoch(fields["UNTIL_EPOCH"]), let written = Self.epoch(fields["WRITTEN_EPOCH"]),
              let pid = Self.epoch(fields["APP_PID"]), pid > 0, pid <= Int64(Int32.max) else { return nil }
        let alive = pidAlive(Int32(pid))
        try check(deadline)
        let now = Int64(clock.now().timeIntervalSince1970)
        try check(deadline)
        guard alive, until == 0 || now <= until, written <= now, now - written <= 120 else { return nil }
        return .paused(Self.visual(bg: fields["PAUSE_BG"], fg: fields["PAUSE_FG"]))
    }

    private static func visual(bg: String?, fg: String?) -> PauseVisual {
        PauseVisual(backgroundColor: bg, foregroundColor: fg,
                    defaultBackgroundColor: UserConfStore.defaultPauseBgDark)
    }

    private static func epoch(_ value: String?) -> Int64? {
        guard let value = value, !value.isEmpty,
              value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        return Int64(value)
    }

    private static func fields(_ contents: String) -> [String: String]? {
        guard !contents.contains("\0") else { return nil }
        var fields: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            guard let equal = line.firstIndex(of: "="), equal != line.startIndex else { return nil }
            let key = String(line[..<equal]), value = line[line.index(after: equal)...]
            guard fields[key] == nil, value.count >= 2, value.first == "\"", value.last == "\"" else { return nil }
            fields[key] = String(value.dropFirst().dropLast())
        }
        return fields["SCHEMA_VERSION"] ?? "1" == "1" ? fields : nil
    }

    private func check(_ deadline: UInt64) throws {
        guard DispatchTime.now().uptimeNanoseconds < deadline else { throw VisualRestrictionPolicyError.timedOut }
    }

    private func readRule(_ url: URL, deadline: UInt64) throws -> String? {
        try check(deadline)
        guard url.isFileURL else { throw VisualRestrictionPolicyError.unavailable }
        var before = stat()
        let inspected = lstat(url.path, &before), inspectError = errno
        try check(deadline)
        if inspected != 0 {
            if inspectError == ENOENT { return nil }
            throw VisualRestrictionPolicyError.unavailable
        }
        guard before.st_mode & S_IFMT == S_IFREG, before.st_size >= 0, before.st_size <= 8_192 else {
            throw VisualRestrictionPolicyError.unavailable
        }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { try check(deadline); throw VisualRestrictionPolicyError.unavailable }
        defer { close(fd) }
        try check(deadline)
        var opened = stat()
        let verified = fstat(fd, &opened)
        try check(deadline)
        guard verified == 0, opened.st_mode & S_IFMT == S_IFREG,
              opened.st_ino == before.st_ino, opened.st_dev == before.st_dev,
              opened.st_size >= 0, opened.st_size <= 8_192 else { throw VisualRestrictionPolicyError.unavailable }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 8_193)
        while true {
            try check(deadline)
            let count = Darwin.read(fd, &buffer, buffer.count), readError = errno
            try check(deadline)
            if count == 0 { break }
            if count < 0 {
                if readError == EINTR { continue }
                throw VisualRestrictionPolicyError.unavailable
            }
            guard result.count + count <= 8_192 else { throw VisualRestrictionPolicyError.unavailable }
            result.append(contentsOf: buffer.prefix(count))
        }
        return String(data: result, encoding: .utf8)
    }
}
