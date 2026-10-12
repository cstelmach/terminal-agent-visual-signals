import XCTest
import Darwin
@testable import TAVSApp

final class ProcessRunnerTests: XCTestCase {
    func testBoundedRunDrainsBothPipes() throws {
        let data = try SystemProcessRunner().runBounded(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "dd if=/dev/zero bs=4096 count=64 2>/dev/null; dd if=/dev/zero bs=4096 count=64 2>/dev/null >&2"],
            timeout: 2
        )
        XCTAssertEqual(data.count, 262144)
        XCTAssertTrue(data.allSatisfy { $0 == 0 })
    }

    func testBoundedRunReportsNonzeroExitWithoutStderrContents() {
        XCTAssertThrowsError(try SystemProcessRunner().runBounded(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf PRIVATE_43 >&2; exit 7"], timeout: 1
        )) { error in
            guard case ProcessRunnerError.processExited(7) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertFalse(String(describing: error).contains("PRIVATE_43"))
        }
    }

    func testTimeoutKillsAndReapsOwnedProcessEvenAfterOutputCloses() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let pidFile = dir.appendingPathComponent("pid")
        let start = Date()
        XCTAssertThrowsError(try SystemProcessRunner().runBounded(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo $$ > \"$1\"; exec 1>&-; exec 2>&-; exec /bin/sleep 5", "owned-test", pidFile.path],
            timeout: 0.15
        )) { error in
            guard case ProcessRunnerError.processTimedOut = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.7)
        let pid = try XCTUnwrap(Int32(String(contentsOf: pidFile).trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertEqual(kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testUnboundedProducerCannotExhaustMemoryOrDeadline() {
        let start = Date()
        XCTAssertThrowsError(try SystemProcessRunner().runBounded(
            executableURL: URL(fileURLWithPath: "/usr/bin/yes"), arguments: [], timeout: 0.2
        ))
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.7)
    }

    func testRejectsInvalidTimeoutBeforeLaunching() {
        for timeout in [0.0, -.infinity, .nan] {
            XCTAssertThrowsError(try SystemProcessRunner().runBounded(
                executableURL: URL(fileURLWithPath: "/bin/echo"), arguments: [], timeout: timeout
            ))
        }
    }

    func testMissingExecutableReturnsAnErrorWithoutWaitingOnAnUnlaunchedProcess() {
        XCTAssertThrowsError(try SystemProcessRunner().runBounded(
            executableURL: URL(fileURLWithPath: "/nonexistent-tavs-phase1-executable"),
            arguments: [], timeout: 1
        ))
    }
}
