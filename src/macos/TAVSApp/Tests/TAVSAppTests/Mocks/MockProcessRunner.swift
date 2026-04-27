import Foundation
@testable import TAVSApp

final class MockProcessRunner: ProcessRunner {
    var runResults: [URL: Data] = [:]
    var runCallLog: [(URL, [String])] = []
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
