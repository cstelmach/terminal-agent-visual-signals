import Foundation
@testable import TAVSApp

final class MockProcessRunner: ProcessRunner {
    var runResults: [URL: Data] = [:]
    var runCallLog: [(URL, [String])] = []
    var boundedResults: [Result<Data, Error>] = []
    var boundedHandler: ((URL, [String], TimeInterval) throws -> Data)?
    private let lock = NSLock()
    private var _writtenDevices: [(String, Data)] = []
    var writtenDevices: [(String, Data)] {
        lock.lock()
        defer { lock.unlock() }
        return _writtenDevices
    }
    var writeError: Error?

    @discardableResult
    func run(executableURL: URL, arguments: [String]) throws -> Data {
        runCallLog.append((executableURL, arguments))
        return runResults[executableURL] ?? Data()
    }

    func runBounded(executableURL: URL, arguments: [String], timeout: TimeInterval) throws -> Data {
        runCallLog.append((executableURL, arguments))
        if let handler = boundedHandler { return try handler(executableURL, arguments, timeout) }
        guard !boundedResults.isEmpty else { throw ProcessRunnerError.processTimedOut }
        return try boundedResults.removeFirst().get()
    }

    func writeToDevice(path: String, data: Data) throws {
        if let error = writeError {
            throw error
        }
        lock.lock()
        _writtenDevices.append((path, data))
        lock.unlock()
    }

    // Test helper: clear the captured writes so a single test can run
    // multiple invocations and inspect each independently.
    func resetWrittenDevices() {
        lock.lock()
        _writtenDevices.removeAll()
        lock.unlock()
    }
}
