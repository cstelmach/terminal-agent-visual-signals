import Foundation
import Darwin

// POSIX integrity checks at use, without adopting or repairing existing directories.
enum RuntimeDirectoryTrust {
    static func owned(_ info: stat) -> Bool {
        info.st_uid == geteuid() && info.st_mode & 0o022 == 0
    }

    static func check(_ directory: URL, create: Bool = false, deadline: UInt64? = nil) throws {
        guard directory.isFileURL, directory.path.hasPrefix("/"), directory.path.utf8.count <= 4096 else {
            throw POSIXError(.EINVAL)
        }
        let parts = directory.pathComponents.dropFirst()
        guard !parts.isEmpty, !parts.contains(".."), !parts.contains(".") else { throw POSIXError(.EINVAL) }
        var current = URL(fileURLWithPath: "/", isDirectory: true)
        for (index, part) in parts.enumerated() {
            try checkDeadline(deadline)
            current.appendPathComponent(part, isDirectory: true)
            var info = stat()
            if lstat(current.path, &info) != 0 {
                guard errno == ENOENT else { throw POSIXError(.EACCES) }
                if !create { try checkDeadline(deadline); return }
                try checkDeadline(deadline)
                guard mkdir(current.path, 0o700) == 0 || errno == EEXIST else { throw POSIXError(.EACCES) }
                try checkDeadline(deadline)
                guard lstat(current.path, &info) == 0 else { throw POSIXError(.EACCES) }
            }
            let leaf = index == parts.count - 1
            if info.st_mode & S_IFMT == S_IFLNK {
                // macOS supplies these root-owned aliases; user/runtime links stay unavailable.
                let aliases = ["/tmp": "/private/tmp", "/var": "/private/var"]
                guard !leaf, info.st_uid == 0, let target = aliases[current.path] else {
                    throw POSIXError(.EACCES)
                }
                var bytes = [UInt8](repeating: 0, count: 128)
                let count = readlink(current.path, &bytes, bytes.count)
                guard count > 0, count < bytes.count,
                      let link = String(bytes: bytes.prefix(count), encoding: .utf8),
                      link == target || link == String(target.dropFirst()) else { throw POSIXError(.EACCES) }
                var parent = stat()
                guard lstat("/private", &parent) == 0, parent.st_mode & S_IFMT == S_IFDIR,
                      parent.st_uid == 0, parent.st_mode & 0o022 == 0 else { throw POSIXError(.EACCES) }
                current = URL(fileURLWithPath: target, isDirectory: true)
                guard lstat(current.path, &info) == 0 else { throw POSIXError(.EACCES) }
            }
            try checkDeadline(deadline)
            guard info.st_mode & S_IFMT == S_IFDIR else { throw POSIXError(.EACCES) }
            if leaf {
                guard owned(info) else { throw POSIXError(.EACCES) }
            } else {
                let sharedTemporary = info.st_uid == 0 && info.st_mode & S_ISVTX != 0
                    && ["/private/tmp", "/private/var/tmp"].contains(current.path)
                guard info.st_uid == 0 || info.st_uid == geteuid(),
                      info.st_mode & 0o022 == 0 || sharedTemporary else {
                    throw POSIXError(.EACCES)
                }
            }
        }
        try checkDeadline(deadline)
    }

    private static func checkDeadline(_ deadline: UInt64?) throws {
        if let deadline = deadline, DispatchTime.now().uptimeNanoseconds >= deadline {
            throw POSIXError(.ETIMEDOUT)
        }
    }
}
