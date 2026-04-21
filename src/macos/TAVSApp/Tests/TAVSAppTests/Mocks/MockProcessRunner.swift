import Foundation
@testable import TAVSApp

final class MockProcessRunner: ProcessRunner {
    var runResults: [URL: Data] = [:]
    var runCallLog: [(URL, [String])] = []
    var writtenDevices: [(String, Data)] = []
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
        writtenDevices.append((path, data))
    }
}
