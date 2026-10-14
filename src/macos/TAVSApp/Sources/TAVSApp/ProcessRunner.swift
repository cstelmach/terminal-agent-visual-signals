import Foundation
import Darwin

struct BoundedProcessOutput {
    let data: Data
    let exitCode: Int32
}

enum DeviceWriteStage: String {
    case queued, operation, storage, publication, admission, open, lock, prepare, write, cleanup, unavailable
}

protocol ProcessRunner: AnyObject {
    @discardableResult
    func run(executableURL: URL, arguments: [String]) throws -> Data
    func runBounded(executableURL: URL, arguments: [String], timeout: TimeInterval) throws -> Data
    func runBoundedOutput(executableURL: URL, arguments: [String], timeout: TimeInterval,
                          environment: [String: String]?) throws -> BoundedProcessOutput
    func writeToDevice(path: String, data: Data) throws
    // prepare runs under the stable lock; validate the opened fd and current policy there.
    // Honor the original deadline before state mutations after any delay; nil skips paint.
    func writeManagedToDevice(path: String, lockURL: URL,
                              prepare: @escaping (Int32, UInt64) throws -> Data?) throws -> Bool
    // beforeOpen may publish metadata under the same original deadline, then release its lock.
    func writeManagedToDevice(path: String, lockURL: URL, beforeOpen: ((UInt64) throws -> Void)?,
                              target: TerminalTargetBinding?, emergency: Bool,
                              prepare: @escaping (Int32, UInt64) throws -> Data?) throws -> Bool
}

extension ProcessRunner {
    func writeManagedToDevice(path: String, lockURL: URL, beforeOpen: ((UInt64) throws -> Void)?,
                              prepare: @escaping (Int32, UInt64) throws -> Data?) throws -> Bool {
        try writeManagedToDevice(path: path, lockURL: lockURL, beforeOpen: beforeOpen, target: nil,
                                 emergency: false, prepare: prepare)
    }

    func writeManagedToDevice(path: String, lockURL: URL,
                              prepare: @escaping (Int32, UInt64) throws -> Data?) throws -> Bool {
        try writeManagedToDevice(path: path, lockURL: lockURL, beforeOpen: nil, prepare: prepare)
    }
}

final class SystemProcessRunner: ProcessRunner {
    private let openDevice: (String, Int32) -> Int32
    private static let admissionLock = NSLock()
    private static var inFlight = Set<DeviceWriteKey>()

    private struct DeviceWriteKey: Hashable {
        let path: String
        let target: TerminalTargetBinding?
        let emergency: Bool
    }

    init(openDevice: @escaping (String, Int32) -> Int32 = { Darwin.open($0, $1) }) {
        self.openDevice = openDevice
    }

    func runBounded(executableURL: URL, arguments: [String], timeout: TimeInterval = 2) throws -> Data {
        guard timeout.isFinite, timeout > 0 else { throw ProcessRunnerError.invalidTimeout }
        let result = try runBoundedOutput(executableURL: executableURL, arguments: arguments,
                                         timeout: min(timeout, 2), environment: nil)
        guard result.exitCode == 0 else { throw ProcessRunnerError.processExited(result.exitCode) }
        return result.data
    }

    func runBoundedOutput(executableURL: URL, arguments: [String], timeout: TimeInterval,
                          environment: [String: String]?) throws -> BoundedProcessOutput {
        guard timeout.isFinite, timeout > 0 else { throw ProcessRunnerError.invalidTimeout }
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(min(timeout, 10) * 1_000_000_000)
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let pipes = [Pipe(), Pipe()]
        process.standardOutput = pipes[0]
        process.standardError = pipes[1]
        var launched = false
        defer {
            if launched {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
            }
            for pipe in pipes {
                try? pipe.fileHandleForReading.close()
                try? pipe.fileHandleForWriting.close()
            }
        }
        try process.run()
        launched = true
        var descriptors = pipes.map { pollfd(fd: $0.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0) }
        for descriptor in descriptors {
            let flags = fcntl(descriptor.fd, F_GETFL)
            guard flags >= 0, fcntl(descriptor.fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
                throw ProcessRunnerError.processIOFailed(errno)
            }
        }
        var output = Data()
        while process.isRunning || descriptors.contains(where: { $0.fd >= 0 }) {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else { throw ProcessRunnerError.processTimedOut }
            let remaining = Int32(min(20, (deadline - now + 999_999) / 1_000_000))
            let ready = poll(&descriptors, nfds_t(descriptors.count), remaining)
            if ready < 0 {
                if errno == EINTR { continue }
                throw ProcessRunnerError.processIOFailed(errno)
            }
            for index in descriptors.indices where descriptors[index].fd >= 0 && descriptors[index].revents != 0 {
                try drainProcessPipe(&descriptors[index], output: &output,
                                     collectingOutput: index == 0, deadline: deadline)
            }
        }
        return BoundedProcessOutput(data: output, exitCode: process.terminationStatus)
    }

    private func drainProcessPipe(_ descriptor: inout pollfd, output: inout Data,
                                  collectingOutput: Bool, deadline: UInt64) throws {
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            guard DispatchTime.now().uptimeNanoseconds < deadline else {
                throw ProcessRunnerError.processTimedOut
            }
            let count = read(descriptor.fd, &buffer, buffer.count)
            if count == 0 { descriptor.fd = -1; return }
            if count < 0 {
                if errno == EINTR { continue }
                if errno == EAGAIN { return }
                throw ProcessRunnerError.processIOFailed(errno)
            }
            if collectingOutput {
                // shortcut: stdout is capped at 1 MiB, raise only for a measured larger catalogue.
                guard output.count + count <= 1_048_576 else {
                    throw ProcessRunnerError.processOutputTooLarge
                }
                output.append(contentsOf: buffer.prefix(count))
            }
        }
    }

    @discardableResult
    func run(executableURL: URL, arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        return pipe.fileHandleForReading.readDataToEndOfFile()
    }

    func writeToDevice(path: String, data: Data) throws {
        guard !data.isEmpty else { return }
        try Self.completeDeviceWrite(path: path) { deadline, stage in
            try self.writeNonblockingToDevice(path: path, data: data, deadline: deadline, stage: stage)
        }
    }

    func writeManagedToDevice(path: String, lockURL: URL, beforeOpen: ((UInt64) throws -> Void)?,
                              target: TerminalTargetBinding?, emergency: Bool = false,
                              prepare: @escaping (Int32, UInt64) throws -> Data?) throws -> Bool {
        try Self.completeDeviceWrite(path: path) { deadline, stage in
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            stage(.storage)
            guard lockURL.isFileURL else { throw ProcessRunnerError.deviceIOFailed(path, EINVAL) }
            let directory = lockURL.deletingLastPathComponent()
            do { try RuntimeDirectoryTrust.check(directory, deadline: deadline) }
            catch { try self.checkDeviceDeadline(path: path, deadline: deadline)
                throw ProcessRunnerError.deviceIOFailed(path, EACCES) }
            if let beforeOpen = beforeOpen {
                try self.checkDeviceDeadline(path: path, deadline: deadline)
                stage(.publication)
                try beforeOpen(deadline)
            }
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            stage(.storage)
            do { try RuntimeDirectoryTrust.check(directory, create: true, deadline: deadline) }
            catch { try self.checkDeviceDeadline(path: path, deadline: deadline)
                throw ProcessRunnerError.deviceIOFailed(path, EACCES) }
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            stage(.admission)
            let admission = try Self.admitDevice(path: path, target: target, emergency: emergency)
            defer { Self.releaseDevice(admission) }
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            stage(.open)
            let device = try self.openNonblockingDevice(path: path, deadline: deadline)
            defer { Darwin.close(device) }
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            stage(.storage)
            do { try RuntimeDirectoryTrust.check(directory, deadline: deadline) }
            catch { try self.checkDeviceDeadline(path: path, deadline: deadline)
                throw ProcessRunnerError.deviceIOFailed(path, EACCES) }
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            var info = stat()
            guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
                throw ProcessRunnerError.deviceIOFailed(path, EINVAL)
            }
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            stage(.lock)
            var lockFD: Int32
            repeat {
                lockFD = Darwin.open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
            } while lockFD < 0 && errno == EINTR && DispatchTime.now().uptimeNanoseconds < deadline
            guard lockFD >= 0 else { throw ProcessRunnerError.deviceIOFailed(path, errno) }
            defer { Darwin.close(lockFD) }
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            guard fstat(lockFD, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
                  info.st_uid == geteuid(), info.st_mode & 0o777 == 0o600 else {
                throw ProcessRunnerError.deviceIOFailed(path, EINVAL)
            }
            while true {
                try self.checkDeviceDeadline(path: path, deadline: deadline)
                if flock(lockFD, LOCK_EX | LOCK_NB) == 0 { break }
                let lockError = errno
                guard lockError == EWOULDBLOCK || lockError == EAGAIN || lockError == EINTR else {
                    throw ProcessRunnerError.deviceIOFailed(path, lockError)
                }
                let now = DispatchTime.now().uptimeNanoseconds
                guard now < deadline else { throw ProcessRunnerError.deviceWriteTimedOut(path) }
                usleep(useconds_t(min(1_000, max(1, (deadline - now) / 1_000))))
            }
            defer { flock(lockFD, LOCK_UN) }
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            stage(.prepare)
            let data = try prepare(device, deadline)
            try self.checkDeviceDeadline(path: path, deadline: deadline)
            guard let data = data else { stage(.cleanup); return false }
            stage(.write)
            try self.writeToDescriptor(device, path: path, data: data, deadline: deadline)
            stage(.cleanup)
            return true
        }
    }

    // Some wedged macOS TTYs stall inside open even with O_NONBLOCK.
    // The semaphore publishes the worker's result only after completion;
    // a timeout reports failure without reading an incomplete result.
    static func completeDeviceWrite<T>(path: String,
        completionTime: () -> UInt64 = { DispatchTime.now().uptimeNanoseconds },
        operation: @escaping (UInt64) throws -> T) throws -> T {
        try completeDeviceWrite(path: path, completionTime: completionTime) { deadline, stage in
            stage(.operation)
            return try operation(deadline)
        }
    }

    private static func completeDeviceWrite<T>(path: String,
        completionTime: () -> UInt64 = { DispatchTime.now().uptimeNanoseconds },
        operation: @escaping (UInt64, (DeviceWriteStage) -> Void) throws -> T) throws -> T {
        let deadline = DispatchTime.now() + .milliseconds(100)
        let completion = DeviceWriteCompletion<T>()
        DispatchQueue.global(qos: .userInitiated).async {
            completion.result = Result {
                try operation(deadline.uptimeNanoseconds, { completion.enter($0, before: deadline.uptimeNanoseconds) })
            }
            completion.finished.signal()
        }
        // A ready signal does not prove the caller resumed before its deadline.
        guard completion.finished.wait(timeout: deadline) == .success,
              completionTime() < deadline.uptimeNanoseconds else {
            TAVSLog.broadcaster.error("terminal I/O timed out: \(path, privacy: .public)")
            throw ProcessRunnerError.deviceWriteTimedOut(path, completion.snapshot())
        }
        do { return try completion.result!.get() }
        catch ProcessRunnerError.deviceWriteTimedOut(let failedPath, let stage) {
            throw ProcessRunnerError.deviceWriteTimedOut(failedPath, stage ?? completion.snapshot())
        }
    }

    private func writeNonblockingToDevice(path: String, data: Data, deadline: UInt64,
                                         stage: (DeviceWriteStage) -> Void) throws {
        try checkDeviceDeadline(path: path, deadline: deadline)
        stage(.admission)
        let admission = try Self.admitDevice(path: path, target: nil, emergency: false)
        defer { Self.releaseDevice(admission) }
        try checkDeviceDeadline(path: path, deadline: deadline)
        stage(.open)
        let descriptor = try openNonblockingDevice(path: path, deadline: deadline)
        defer { Darwin.close(descriptor) }
        try checkDeviceDeadline(path: path, deadline: deadline)
        stage(.write)
        try writeToDescriptor(descriptor, path: path, data: data, deadline: deadline)
        stage(.cleanup)
    }

    private static func admitDevice(path: String, target: TerminalTargetBinding?,
                                    emergency: Bool) throws -> DeviceWriteKey {
        guard target == nil || target?.tty == path else { throw ProcessRunnerError.deviceIOFailed(path, EINVAL) }
        let key = DeviceWriteKey(path: URL(fileURLWithPath: path).standardizedFileURL.path,
                                 target: target?.physicalTarget, emergency: emergency)
        admissionLock.lock(); defer { admissionLock.unlock() }
        // Reserve one independent reset attempt so a stuck ordinary open cannot exclude recovery.
        guard !inFlight.contains(where: {
            $0.path == key.path && $0.emergency == key.emergency
                && (key.target == nil || $0.target == nil || $0.target == key.target)
        }) else { throw ProcessRunnerError.deviceIOFailed(path, EBUSY) }
        inFlight.insert(key)
        return key
    }

    private static func releaseDevice(_ key: DeviceWriteKey) {
        admissionLock.lock(); defer { admissionLock.unlock() }
        inFlight.remove(key)
    }

    private func checkDeviceDeadline(path: String, deadline: UInt64) throws {
        guard DispatchTime.now().uptimeNanoseconds < deadline else {
            throw ProcessRunnerError.deviceWriteTimedOut(path)
        }
    }

    private func openNonblockingDevice(path: String, deadline: UInt64) throws -> Int32 {
        // A delayed worker must not open a device or repaint after timeout.
        try checkDeviceDeadline(path: path, deadline: deadline)
        var descriptor: Int32
        repeat {
            descriptor = openDevice(path, O_WRONLY | O_NONBLOCK | O_NOCTTY | O_CLOEXEC)
        } while descriptor < 0 && errno == EINTR && DispatchTime.now().uptimeNanoseconds < deadline
        guard descriptor >= 0 else {
            throw ProcessRunnerError.deviceNotWritable(path)
        }
        guard DispatchTime.now().uptimeNanoseconds < deadline else {
            Darwin.close(descriptor)
            throw ProcessRunnerError.deviceWriteTimedOut(path)
        }
        return descriptor
    }

    private func writeToDescriptor(_ descriptor: Int32, path: String, data: Data, deadline: UInt64) throws {
        // Both opening and writing a disconnected or backed-up TTY can block.
        // Bound all retries so one terminal cannot stall the scheduler.
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                guard DispatchTime.now().uptimeNanoseconds < deadline else {
                    throw ProcessRunnerError.deviceWriteTimedOut(path)
                }
                let written = Darwin.write(
                    descriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset
                )
                if written > 0 {
                    offset += written
                    continue
                }
                if written == 0 {
                    throw ProcessRunnerError.deviceIOFailed(path, EIO)
                }
                let writeError = errno
                if writeError == EINTR { continue }
                guard writeError == EAGAIN else {
                    throw ProcessRunnerError.deviceIOFailed(path, writeError)
                }

                let now = DispatchTime.now().uptimeNanoseconds
                guard now < deadline else {
                    throw ProcessRunnerError.deviceWriteTimedOut(path)
                }
                let remainingMS = Int32((deadline - now + 999_999) / 1_000_000)
                var pending = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
                let ready = Darwin.poll(&pending, 1, remainingMS)
                if ready == 0 {
                    throw ProcessRunnerError.deviceWriteTimedOut(path)
                }
                if ready < 0 {
                    let pollError = errno
                    if pollError == EINTR { continue }
                    throw ProcessRunnerError.deviceIOFailed(path, pollError)
                }
                if pending.revents & Int16(POLLERR | POLLHUP | POLLNVAL) != 0 {
                    throw ProcessRunnerError.deviceIOFailed(path, EIO)
                }
            }
        }
    }
}

private final class DeviceWriteCompletion<T> {
    let finished = DispatchSemaphore(value: 0)
    var result: Result<T, Error>?
    private let stageLock = NSLock()
    private var stage = DeviceWriteStage.queued

    func enter(_ stage: DeviceWriteStage, before deadline: UInt64) {
        stageLock.lock()
        if DispatchTime.now().uptimeNanoseconds < deadline { self.stage = stage }
        stageLock.unlock()
    }

    // Timeout diagnostics must neither wait for the worker nor read its unfinished result.
    func snapshot() -> DeviceWriteStage {
        guard stageLock.try() else { return .unavailable }
        defer { stageLock.unlock() }
        return stage
    }
}

enum ProcessRunnerError: Error {
    case invalidTimeout
    case processTimedOut
    case processExited(Int32)
    case processIOFailed(Int32)
    case processOutputTooLarge
    case deviceNotWritable(String)
    case deviceIOFailed(String, Int32)
    case deviceWriteTimedOut(String, DeviceWriteStage? = nil)
}
