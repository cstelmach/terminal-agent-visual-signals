import Foundation
@testable import TAVSApp

final class MockProcessRunner: ProcessRunner {
    var runResults: [URL: Data] = [:]
    var runCallLog: [(URL, [String])] = []
    var boundedResults: [Result<Data, Error>] = []
    var boundedHandler: ((URL, [String], TimeInterval) throws -> Data)?
    var managedHandler: ((String, URL, @escaping (Int32, UInt64) throws -> Data?) throws -> Bool)?
    private let lock = NSLock()
    private var _writtenDevices: [(String, Data)] = []
    private var _managedCallLog: [(String, URL)] = []
    var managedCallLog: [(String, URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _managedCallLog
    }
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

    func writeManagedToDevice(path: String, lockURL: URL,
                              prepare: @escaping (Int32, UInt64) throws -> Data?) throws -> Bool {
        lock.lock()
        _managedCallLog.append((path, lockURL))
        lock.unlock()
        if let error = writeError { throw error }
        guard let handler = managedHandler else { throw ProcessRunnerError.deviceNotWritable(path) }
        return try handler(path, lockURL, prepare)
    }

    // Test helper: clear the captured writes so a single test can run
    // multiple invocations and inspect each independently.
    func resetWrittenDevices() {
        lock.lock()
        _writtenDevices.removeAll()
        lock.unlock()
    }
}
