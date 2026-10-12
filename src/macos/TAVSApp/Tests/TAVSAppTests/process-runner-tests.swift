import XCTest
import Darwin
@testable import TAVSApp

final class ProcessRunnerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        let testRoot = try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"])
        root = URL(fileURLWithPath: testRoot).appendingPathComponent("managed-writer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

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

    func testManagedWriteDeliversExactBytesAndKeepsPrivateStableLock() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let lockURL = root.appendingPathComponent("locks/writer.lock")
        let runner = SystemProcessRunner()
        let bytes = Data("\u{1B}]111\u{07}".utf8)
        XCTAssertTrue(try runner.writeManagedToDevice(path: tty.path, lockURL: lockURL) { fd, deadline in
            var info = stat()
            XCTAssertEqual(fstat(fd, &info), 0)
            XCTAssertEqual(info.st_mode & S_IFMT, S_IFCHR)
            let now = DispatchTime.now().uptimeNanoseconds
            XCTAssertGreaterThan(deadline, now)
            if deadline > now { XCTAssertLessThanOrEqual(deadline - now, 100_000_000) }
            return bytes
        })
        XCTAssertEqual(try readPTY(tty.master, count: bytes.count), bytes)
        var before = stat(), parent = stat()
        XCTAssertEqual(lstat(lockURL.path, &before), 0)
        XCTAssertEqual(before.st_mode & S_IFMT, S_IFREG)
        XCTAssertEqual(before.st_mode & 0o777, 0o600)
        XCTAssertEqual(lstat(lockURL.deletingLastPathComponent().path, &parent), 0)
        XCTAssertEqual(parent.st_mode & 0o777, 0o700)

        XCTAssertFalse(try runner.writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in nil })
        var after = stat()
        XCTAssertEqual(lstat(lockURL.path, &after), 0)
        XCTAssertEqual(after.st_ino, before.st_ino)
        assertNoPTYBytes(tty.master)
    }

    func testPausedOpenDoesNotHoldLockAndPolicyReadsNewSuspension() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let lockURL = root.appendingPathComponent("writer.lock")
        let lockFD = try openLock(lockURL)
        defer { close(lockFD) }
        let store = VisualRestrictionsStateStore(url: root.appendingPathComponent("suspension.state"))
        try store.write(suspended: false)
        let entered = DispatchSemaphore(value: 0)
        let finished = expectation(description: "Current policy skips paint")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let result = ManagedWriteResult()
        let runner = SystemProcessRunner(openDevice: { path, flags in
            entered.signal()
            release.wait()
            return Darwin.open(path, flags)
        })
        DispatchQueue.global().async {
            result.set(Result {
                try runner.writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in
                    store.read().disablesRestrictions ? nil : Data([0x61])
                }
            })
            finished.fulfill()
        }
        // Do not spend the writer's real 100 ms budget polling XCTest's main run loop.
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(flock(lockFD, LOCK_EX | LOCK_NB), 0, "Opening a device cannot hold output serialization")
        try store.write(suspended: true)
        XCTAssertEqual(flock(lockFD, LOCK_UN), 0)
        release.signal()
        wait(for: [finished], timeout: 1)
        XCTAssertFalse(try result.get())
        assertNoPTYBytes(tty.master)
    }

    func testPolicyRunsUnderLockAndReadsSuspensionPersistedDuringBarrier() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let lockURL = root.appendingPathComponent("writer.lock")
        let lockFD = try openLock(lockURL)
        defer { close(lockFD) }
        let store = VisualRestrictionsStateStore(url: root.appendingPathComponent("suspension.state"))
        try store.write(suspended: false)
        let entered = expectation(description: "Policy holds output lock")
        let finished = expectation(description: "Policy finishes without stale paint")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let result = ManagedWriteResult()
        DispatchQueue.global().async {
            result.set(Result {
                try SystemProcessRunner().writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in
                    entered.fulfill()
                    release.wait()
                    return store.read().disablesRestrictions ? nil : Data([0x61])
                }
            })
            finished.fulfill()
        }
        wait(for: [entered], timeout: 1)
        XCTAssertEqual(flock(lockFD, LOCK_EX | LOCK_NB), -1)
        XCTAssertEqual(errno, EWOULDBLOCK)
        try store.write(suspended: true)
        release.signal()
        wait(for: [finished], timeout: 1)
        XCTAssertFalse(try result.get())
        let reset = Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{07}".utf8)
        XCTAssertTrue(try SystemProcessRunner().writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in reset })
        XCTAssertEqual(try readPTY(tty.master, count: reset.count), reset)
        assertNoPTYBytes(tty.master)
    }

    func testLateOpenClosesDescriptorWithoutLockPolicyOrPaint() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let lockURL = root.appendingPathComponent("writer.lock")
        let entered = expectation(description: "Open has started")
        let opened = expectation(description: "Late open returns its owned fd")
        let finished = expectation(description: "Caller deadline expires")
        let policy = expectation(description: "No late policy")
        policy.isInverted = true
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let result = ManagedWriteResult()
        let runner = SystemProcessRunner(openDevice: { path, flags in
            entered.fulfill()
            release.wait()
            let fd = Darwin.open(path, flags)
            result.descriptor = fd
            opened.fulfill()
            return fd
        })
        let start = DispatchTime.now().uptimeNanoseconds
        DispatchQueue.global().async {
            result.set(Result {
                try runner.writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in
                    policy.fulfill()
                    return Data([0x61])
                }
            })
            finished.fulfill()
        }
        wait(for: [entered, finished], timeout: 1)
        assertTimedOut(result, since: start)
        release.signal()
        wait(for: [opened], timeout: 1)
        assertDescriptorClosed(result.descriptor)
        wait(for: [policy], timeout: 0.02)
        XCTAssertFalse(FileManager.default.fileExists(atPath: lockURL.path))
        assertNoPTYBytes(tty.master)
    }

    func testLatePolicyResultCannotWriteAndReleasesLock() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let lockURL = root.appendingPathComponent("writer.lock")
        let entered = expectation(description: "Policy has started")
        let finished = expectation(description: "Caller deadline expires")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let result = ManagedWriteResult()
        let start = DispatchTime.now().uptimeNanoseconds
        DispatchQueue.global().async {
            result.set(Result {
                try SystemProcessRunner().writeManagedToDevice(path: tty.path, lockURL: lockURL) { fd, _ in
                    result.descriptor = fd
                    entered.fulfill()
                    release.wait()
                    return Data([0x61])
                }
            })
            finished.fulfill()
        }
        wait(for: [entered, finished], timeout: 1)
        assertTimedOut(result, since: start)
        release.signal()
        assertDescriptorClosed(result.descriptor)
        assertNoPTYBytes(tty.master)
        XCTAssertTrue(try SystemProcessRunner().writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in Data([0x62]) })
        XCTAssertEqual(try readPTY(tty.master, count: 1), Data([0x62]))
    }

    func testBusyStableLockUsesOriginalDeadlineAndNeverCallsPolicyLate() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let lockURL = root.appendingPathComponent("writer.lock")
        let fd = try openLock(lockURL)
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        var before = stat()
        XCTAssertEqual(fstat(fd, &before), 0)
        let result = ManagedWriteResult()
        let runner = SystemProcessRunner(openDevice: { path, flags in
            let opened = Darwin.open(path, flags)
            result.descriptor = opened
            return opened
        })
        let start = DispatchTime.now().uptimeNanoseconds
        result.set(Result {
            try runner.writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in
                XCTFail("Busy output lock must not call policy")
                return Data([0x61])
            }
        })
        assertTimedOut(result, since: start)
        assertDescriptorClosed(result.descriptor)
        var after = stat()
        XCTAssertEqual(lstat(lockURL.path, &after), 0)
        XCTAssertEqual(after.st_ino, before.st_ino)
        assertNoPTYBytes(tty.master)
    }

    func testPolicyErrorClosesDescriptorAndUnlocksStableFile() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let lockURL = root.appendingPathComponent("writer.lock")
        let result = ManagedWriteResult()
        XCTAssertThrowsError(try SystemProcessRunner().writeManagedToDevice(path: tty.path, lockURL: lockURL) { fd, _ in
            result.descriptor = fd
            throw ManagedPolicyError.rejected
        }) { error in
            guard case ManagedPolicyError.rejected = error else { return XCTFail("Unexpected error: \(error)") }
        }
        assertDescriptorClosed(result.descriptor)
        assertNoPTYBytes(tty.master)
        XCTAssertTrue(try SystemProcessRunner().writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in Data([0x62]) })
        XCTAssertEqual(try readPTY(tty.master, count: 1), Data([0x62]))
    }

    func testSymlinkAndSpecialLockCannotReachPolicy() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let target = root.appendingPathComponent("target")
        try Data("preserved".utf8).write(to: target)
        let symlink = root.appendingPathComponent("symlink.lock")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)
        let fifo = root.appendingPathComponent("fifo.lock")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        for lockURL in [symlink, fifo] {
            XCTAssertThrowsError(try SystemProcessRunner().writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in
                XCTFail("Invalid lock must not reach policy")
                return Data([0x61])
            })
        }
        XCTAssertEqual(try String(contentsOf: target), "preserved")
        assertNoPTYBytes(tty.master)
    }

    func testManagedBackpressureDoesNotDelayHealthyIndependentWrite() throws {
        let blocked = try openPTY(), healthy = try openPTY()
        defer { close(blocked.master); close(blocked.slave); close(healthy.master); close(healthy.slave) }
        let entered = expectation(description: "Backpressured writer starts")
        let finished = expectation(description: "Backpressured writer times out")
        let result = ManagedWriteResult()
        let blockedLock = root.appendingPathComponent("blocked.lock")
        let start = DispatchTime.now().uptimeNanoseconds
        DispatchQueue.global().async {
            result.set(Result {
                try SystemProcessRunner().writeManagedToDevice(path: blocked.path, lockURL: blockedLock) { _, _ in
                    entered.fulfill()
                    return Data(repeating: 0x61, count: 1024 * 1024)
                }
            })
            finished.fulfill()
        }
        wait(for: [entered], timeout: 1)
        let bytes = Data("\u{1B}]111\u{07}".utf8)
        XCTAssertTrue(try SystemProcessRunner().writeManagedToDevice(path: healthy.path,
            lockURL: root.appendingPathComponent("healthy.lock")) { _, _ in bytes })
        XCTAssertEqual(try readPTY(healthy.master, count: bytes.count), bytes)
        wait(for: [finished], timeout: 1)
        assertTimedOut(result, since: start)
    }

    func testManagedMockNeedsExplicitOwnedDescriptorAndExecutesFreshPolicy() throws {
        let tty = try openPTY()
        defer { close(tty.master); close(tty.slave) }
        let runner = MockProcessRunner()
        let lockURL = root.appendingPathComponent("writer.lock")
        XCTAssertThrowsError(try runner.writeManagedToDevice(path: tty.path, lockURL: lockURL) { _, _ in
            XCTFail("An unconfigured mock cannot guess a managed descriptor")
            return Data([0x61])
        })
        let store = VisualRestrictionsStateStore(url: root.appendingPathComponent("suspension.state"))
        try store.write(suspended: true)
        runner.managedHandler = { path, url, prepare in
            XCTAssertEqual(path, tty.path)
            XCTAssertEqual(url, lockURL)
            return try prepare(tty.slave, DispatchTime.now().uptimeNanoseconds + 100_000_000) != nil
        }
        XCTAssertFalse(try runner.writeManagedToDevice(path: tty.path, lockURL: lockURL) { fd, _ in
            XCTAssertEqual(fd, tty.slave)
            return store.read().disablesRestrictions ? nil : Data([0x61])
        })
        XCTAssertEqual(runner.managedCallLog.count, 2)
        XCTAssertTrue(runner.writtenDevices.isEmpty)
    }

    private func openPTY() throws -> (master: Int32, slave: Int32, path: String) {
        var master: Int32 = -1, slave: Int32 = -1
        var name = [CChar](repeating: 0, count: 1024)
        guard openpty(&master, &slave, &name, nil, nil) == 0 else { throw POSIXError(.EIO) }
        var attributes = termios()
        tcgetattr(slave, &attributes)
        cfmakeraw(&attributes)
        tcsetattr(slave, TCSANOW, &attributes)
        return (master, slave, String(cString: name))
    }

    private func openLock(_ url: URL) throws -> Int32 {
        let fd = Darwin.open(url.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw POSIXError(.EIO) }
        return fd
    }

    private func readPTY(_ master: Int32, count: Int) throws -> Data {
        var descriptor = pollfd(fd: master, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 1000) == 1 else { throw POSIXError(.ETIMEDOUT) }
        var bytes = [UInt8](repeating: 0, count: count)
        let received = Darwin.read(master, &bytes, bytes.count)
        guard received >= 0 else { throw POSIXError(.EIO) }
        return Data(bytes.prefix(received))
    }

    private func assertNoPTYBytes(_ master: Int32, file: StaticString = #filePath, line: UInt = #line) {
        var descriptor = pollfd(fd: master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&descriptor, 1, 10), 0, file: file, line: line)
    }

    private func assertDescriptorClosed(_ fd: Int32, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(fd, 0, file: file, line: line)
        let deadline = DispatchTime.now().uptimeNanoseconds + 200_000_000
        while fcntl(fd, F_GETFD) >= 0 && DispatchTime.now().uptimeNanoseconds < deadline { usleep(1_000) }
        XCTAssertEqual(fcntl(fd, F_GETFD), -1, file: file, line: line)
        XCTAssertEqual(errno, EBADF, file: file, line: line)
    }

    private func assertTimedOut(_ result: ManagedWriteResult, since start: UInt64,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try result.get(), file: file, line: line) { error in
            guard case ProcessRunnerError.deviceWriteTimedOut = error else {
                return XCTFail("Unexpected error: \(error)", file: file, line: line)
            }
        }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
        XCTAssertGreaterThanOrEqual(elapsed, 0.08, file: file, line: line)
        XCTAssertLessThan(elapsed, 0.5, file: file, line: line)
    }
}

private enum ManagedPolicyError: Error { case rejected }

private final class ManagedWriteResult {
    private let lock = NSLock()
    private var result: Result<Bool, Error>?
    private var fd: Int32 = -1

    var descriptor: Int32 {
        get { lock.lock(); defer { lock.unlock() }; return fd }
        set { lock.lock(); fd = newValue; lock.unlock() }
    }

    func set(_ result: Result<Bool, Error>) {
        lock.lock(); self.result = result; lock.unlock()
    }

    func get() throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        return try XCTUnwrap(result).get()
    }
}
