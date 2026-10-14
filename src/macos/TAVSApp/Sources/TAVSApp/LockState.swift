import Foundation
import Darwin

// ==============================================================================
// Hard-lock state: /tmp/tavs-$UID/lock.state (runtime dir, cleared by reboot).
// ==============================================================================
// Written by BOTH the app (schedule projection, LockStateMerge) and the CLI
// (tavs lock now / tavs unlock). Deliberately carries NO APP_PID and NO
// heartbeat semantics: the shell honors an unexpired lock regardless of app
// liveness (fail-closed, spec D3). Every writer sets a FINITE lockUntilEpoch;
// there is no indefinite lock. Absent or malformed file means NOT locked.
// ==============================================================================

enum LockReason: String {
    case manual
    case schedule
}

struct LockStateData: Equatable {
    var locked: Bool
    var reason: LockReason
    var lockUntilEpoch: Int64
    var unlockUntilEpoch: Int64
    var writtenEpoch: Int64
    var lockBg: String = ""
    var lockFg: String = ""

    // effective := LOCKED && now < LOCK_UNTIL && !(now < UNLOCK_UNTIL)
    // (single predicate definition shared with shellrc/mute-gate/cmd-lock;
    // unlockUntilEpoch == 0 means "no grant" and the comparison handles it).
    func isEffectivelyLocked(now: Int64) -> Bool {
        locked && now < lockUntilEpoch && !(now < unlockUntilEpoch)
    }

    func serialize() -> String {
        var lines: [String] = []
        lines.append("LOCKED=\"\(locked ? "true" : "false")\"")
        lines.append("REASON=\"\(reason.rawValue)\"")
        lines.append("LOCK_UNTIL_EPOCH=\"\(lockUntilEpoch)\"")
        lines.append("UNLOCK_UNTIL_EPOCH=\"\(unlockUntilEpoch)\"")
        lines.append("WRITTEN_EPOCH=\"\(writtenEpoch)\"")
        lines.append("LOCK_BG=\"\(lockBg)\"")
        lines.append("LOCK_FG=\"\(lockFg)\"")
        lines.append("SCHEMA_VERSION=\"1\"")
        return lines.joined(separator: "\n") + "\n"
    }
}

enum LockStateWriter {
    static func write(_ state: LockStateData, to url: URL) throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + 100_000_000
        func checkDeadline() throws {
            guard DispatchTime.now().uptimeNanoseconds < deadline else { throw POSIXError(.ETIMEDOUT) }
        }
        try RuntimeDirectoryTrust.check(url.deletingLastPathComponent(), create: true, deadline: deadline)
        _ = try LockStateReader.readChecked(at: url, deadline: deadline)
        let data = Data(state.serialize().utf8)
        guard data.count <= 8_192 else { throw POSIXError(.EFBIG) }
        try checkDeadline()
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".lock-state-\(UUID().uuidString).tmp")
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
        // A successful rename commits complete private bytes; no fallible permission step follows.
    }
}

enum LockStateReader {
    // Returns nil for absent, unreadable, or malformed content (missing/non-
    // numeric LOCK_UNTIL_EPOCH, unknown schema). nil always means "not locked".
    static func read(at url: URL) -> LockStateData? {
        try? readChecked(at: url)
    }

    // Mutation decisions distinguish trusted absence from unavailable existing storage.
    static func readChecked(at url: URL,
                            deadline: UInt64 = DispatchTime.now().uptimeNanoseconds + 100_000_000) throws -> LockStateData? {
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
        guard let text = String(data: data, encoding: .utf8), let result = parse(text) else {
            throw POSIXError(.EINVAL)
        }
        try checkDeadline()
        return result
    }

    static func parse(_ contents: String) -> LockStateData? {
        var fields: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<eq])
            var value = String(line[line.index(after: eq)...])
            if value.hasPrefix("\"") { value.removeFirst() }
            if value.hasSuffix("\"") { value.removeLast() }
            fields[key] = value
        }

        guard let lockedRaw = fields["LOCKED"] else { return nil }
        guard fields["SCHEMA_VERSION"] ?? "1" == "1" else { return nil }
        guard let lockUntil = Int64(fields["LOCK_UNTIL_EPOCH"] ?? "") else { return nil }

        return LockStateData(
            locked: lockedRaw == "true",
            reason: LockReason(rawValue: fields["REASON"] ?? "") ?? .manual,
            lockUntilEpoch: lockUntil,
            unlockUntilEpoch: Int64(fields["UNLOCK_UNTIL_EPOCH"] ?? "") ?? 0,
            writtenEpoch: Int64(fields["WRITTEN_EPOCH"] ?? "") ?? 0,
            lockBg: fields["LOCK_BG"] ?? "",
            lockFg: fields["LOCK_FG"] ?? ""
        )
    }
}

// ==============================================================================
// Pure merge for the app's schedule projection (spec 2.2 writer merge rules).
// The app's 60s heartbeat rewrite must never clobber CLI state: an unexpired
// manual lock survives (max of the two ends wins, manual keeps its reason when
// later), and an unexpired unlock grant is always preserved.
// ==============================================================================

enum LockStateMerge {
    // scheduleUntilEpoch: next schedule transition, or 0 when unknown (capped
    // at now+24h; the heartbeat refreshes it long before that).
    static let scheduleUntilCap: Int64 = 24 * 3600

    static func merged(
        existing: LockStateData?,
        scheduleHardMuted: Bool,
        scheduleUntilEpoch: Int64,
        now: Int64,
        lockBg: String,
        lockFg: String
    ) -> LockStateData {
        let manualActive = existing.map {
            $0.locked && $0.reason == .manual && now < $0.lockUntilEpoch
        } ?? false
        let grantUntil: Int64 = existing.map {
            $0.unlockUntilEpoch > now ? $0.unlockUntilEpoch : 0
        } ?? 0

        if scheduleHardMuted {
            let scheduleUntil = scheduleUntilEpoch > 0
                ? scheduleUntilEpoch
                : now + Self.scheduleUntilCap
            let manualUntil = manualActive ? existing!.lockUntilEpoch : 0
            let manualWins = manualUntil > scheduleUntil
            return LockStateData(
                locked: true,
                reason: manualWins ? .manual : .schedule,
                lockUntilEpoch: max(scheduleUntil, manualUntil),
                unlockUntilEpoch: grantUntil,
                writtenEpoch: now,
                lockBg: lockBg,
                lockFg: lockFg
            )
        }

        if manualActive {
            return LockStateData(
                locked: true,
                reason: .manual,
                lockUntilEpoch: existing!.lockUntilEpoch,
                unlockUntilEpoch: grantUntil,
                writtenEpoch: now,
                lockBg: lockBg,
                lockFg: lockFg
            )
        }

        return LockStateData(
            locked: false,
            reason: .schedule,
            lockUntilEpoch: 0,
            unlockUntilEpoch: grantUntil,
            writtenEpoch: now,
            lockBg: lockBg,
            lockFg: lockFg
        )
    }
}
