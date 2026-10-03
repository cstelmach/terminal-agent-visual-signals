import Foundation
import Darwin

protocol ProcessRunner: AnyObject {
    @discardableResult
    func run(executableURL: URL, arguments: [String]) throws -> Data
    func writeToDevice(path: String, data: Data) throws
}

final class SystemProcessRunner: ProcessRunner {
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
        try Self.completeDeviceWrite(path: path) { deadline in
            try self.writeNonblockingToDevice(path: path, data: data, deadline: deadline)
        }
    }

    // Some wedged macOS TTYs stall inside open even with O_NONBLOCK.
    // The semaphore publishes the worker's result only after completion;
    // a timeout never reads it and lets the broadcaster prune that TTY.
    static func completeDeviceWrite(path: String, operation: @escaping (UInt64) throws -> Void) throws {
        let deadline = DispatchTime.now() + .milliseconds(100)
        let completion = DeviceWriteCompletion()
        DispatchQueue.global(qos: .userInitiated).async {
            completion.result = Result { try operation(deadline.uptimeNanoseconds) }
            completion.finished.signal()
        }
        guard completion.finished.wait(timeout: deadline) == .success else {
            TAVSLog.broadcaster.error("terminal I/O timed out: \(path, privacy: .public)")
            throw ProcessRunnerError.deviceWriteTimedOut(path)
        }
        try completion.result!.get()
    }

    private func writeNonblockingToDevice(path: String, data: Data, deadline: UInt64) throws {
        // A delayed worker must not open a device or repaint after timeout.
        guard DispatchTime.now().uptimeNanoseconds < deadline else {
            throw ProcessRunnerError.deviceWriteTimedOut(path)
        }
        var descriptor: Int32
        repeat {
            descriptor = Darwin.open(path, O_WRONLY | O_NONBLOCK | O_NOCTTY | O_CLOEXEC)
        } while descriptor < 0 && errno == EINTR && DispatchTime.now().uptimeNanoseconds < deadline
        guard descriptor >= 0 else {
            throw ProcessRunnerError.deviceNotWritable(path)
        }
        defer { Darwin.close(descriptor) }

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

private final class DeviceWriteCompletion {
    let finished = DispatchSemaphore(value: 0)
    var result: Result<Void, Error>?
}

enum ProcessRunnerError: Error {
    case deviceNotWritable(String)
    case deviceIOFailed(String, Int32)
    case deviceWriteTimedOut(String)
}
