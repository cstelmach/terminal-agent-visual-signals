import Foundation
import Darwin

enum VisualRestrictionsStatus: String {
    case active, suspended, unavailable

    var disablesRestrictions: Bool { self != .active }

    var message: String {
        switch self {
        case .active: return "Visual restrictions active."
        case .suspended: return "Visual restrictions suspended. Saved rules apply after explicit resumption."
        case .unavailable: return "Suspension state unavailable. Visual restrictions disabled until repaired."
        }
    }
}

enum VisualRestrictionsStateError: Error { case storageUnavailable }

final class VisualRestrictionsStateStore {
    let url: URL

    init(url: URL) { self.url = url }

    func read() -> VisualRestrictionsStatus {
        guard url.isFileURL else { return .unavailable }
        var before = stat()
        if lstat(url.path, &before) != 0 { return errno == ENOENT ? missingStatus() : .unavailable }
        guard before.st_mode & S_IFMT == S_IFREG, before.st_size >= 0, before.st_size < 128 else {
            return .unavailable
        }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return .unavailable }
        defer { close(fd) }
        var current = stat()
        guard fstat(fd, &current) == 0, current.st_mode & S_IFMT == S_IFREG,
              current.st_ino == before.st_ino, current.st_dev == before.st_dev,
              current.st_size >= 0, current.st_size < 128 else { return .unavailable }
        var bytes = [UInt8](repeating: 0, count: 128)
        let count = Darwin.read(fd, &bytes, bytes.count)
        guard count >= 0, count < bytes.count,
              let text = String(bytes: bytes.prefix(count), encoding: .utf8) else { return .unavailable }
        if text == Self.serialized(suspended: true) { return .suspended }
        if text == Self.serialized(suspended: false) { return .active }
        return .unavailable
    }

    private func missingStatus() -> VisualRestrictionsStatus {
        var parent = url.deletingLastPathComponent()
        while true {
            var info = stat()
            if lstat(parent.path, &info) == 0 {
                return stat(parent.path, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR
                    && access(parent.path, X_OK) == 0 ? .active : .unavailable
            }
            guard errno == ENOENT else { return .unavailable }
            let next = parent.deletingLastPathComponent()
            guard next != parent else { return .unavailable }
            parent = next
        }
    }

    func write(suspended: Bool) throws {
        guard url.isFileURL else { throw VisualRestrictionsStateError.storageUnavailable }
        var info = stat()
        if lstat(url.path, &info) == 0, info.st_mode & S_IFMT != S_IFREG {
            throw VisualRestrictionsStateError.storageUnavailable
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try Data(Self.serialized(suspended: suspended).utf8).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { throw VisualRestrictionsStateError.storageUnavailable }
    }

    private static func serialized(suspended: Bool) -> String {
        "SCHEMA_VERSION=\"1\"\nSUSPENDED=\"\(suspended ? "true" : "false")\"\n"
    }

    static func handle(_ args: [String]) -> Bool {
        if args.count == 3, args[1] == "--validate-config", args[2] == "--visual-restrictions-capabilities" {
            print("tavs-visual-restrictions-schema=1")
            return true
        }
        guard args.count > 1, args[1].hasPrefix("--visual-restrictions-") else { return false }
        guard args.count >= 3, args[2].hasPrefix("/") else { fail() }
        let store = VisualRestrictionsStateStore(url: URL(fileURLWithPath: args[2]))
        switch args[1] {
        case "--visual-restrictions-read" where args.count == 3:
            let state = store.read()
            print(state.rawValue)
            if state == .unavailable { exit(1) }
        case "--visual-restrictions-write" where args.count == 4:
            guard args[3] == "true" || args[3] == "false" else { fail() }
            do { try store.write(suspended: args[3] == "true") } catch { fail() }
        default: fail()
        }
        return true
    }

    private static func fail() -> Never {
        fputs("Visual restriction state unavailable.\n", stderr)
        exit(1)
    }
}
