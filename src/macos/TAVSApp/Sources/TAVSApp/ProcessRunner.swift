import Foundation

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
        guard let fh = FileHandle(forWritingAtPath: path) else {
            throw ProcessRunnerError.deviceNotWritable(path)
        }
        defer { try? fh.close() }
        // write(contentsOf:) throws on I/O errors (EIO, EPIPE, hung tty, etc.).
        // The non-throwing FileHandle.write(Data) silently swallows them,
        // which breaks dead-TTY pruning in Broadcaster.
        try fh.write(contentsOf: data)
    }
}

enum ProcessRunnerError: Error {
    case deviceNotWritable(String)
}
