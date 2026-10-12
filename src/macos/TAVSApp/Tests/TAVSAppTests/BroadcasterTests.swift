import XCTest
import Darwin
@testable import TAVSApp

final class BroadcasterTests: XCTestCase {
    private var root: URL!
    private var restrictions: VisualRestrictionsStateStore!
    private var state: TerminalVisualStateStore!
    private var clock: VirtualClock!
    private var identities: [Int32: ProcessIdentity] = [:]
    private var devices: [String: UInt32] = [:]
    private var ptys: [(master: Int32, slave: Int32, path: String)] = []

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"]))
            .appendingPathComponent("broadcaster-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("home"), withIntermediateDirectories: true)
        restrictions = VisualRestrictionsStateStore(url: root.appendingPathComponent("home/visual-restrictions.state"))
        try restrictions.write(suspended: false)
        clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
        identities = [90: identity(90, device: UInt32.max)]
        devices = [:]
        ptys = []
        state = TerminalVisualStateStore(runtimeDirectory: root, clock: clock,
            lookup: { self.identities[$0] }, device: { self.devices[$0] },
            deviceMissing: { _ in false }, processMissing: { _ in false })
    }

    override func tearDown() {
        for tty in ptys { close(tty.master); close(tty.slave) }
        ptys = []
        super.tearDown()
    }

    private func generation(_ pid: Int32) -> ProcessGeneration {
        ProcessGeneration(pid: pid, startSeconds: 100, startMicroseconds: 1)
    }

    private func identity(_ pid: Int32, device: UInt32) -> ProcessIdentity {
        ProcessIdentity(generation: generation(pid), parentPID: 1, group: UInt32(pid),
                        device: device, foregroundGroup: UInt32(pid))
    }

    private func terminal(_ pid: Int32) throws -> TerminalTargetBinding {
        let tty = try openTestPTY()
        ptys.append(tty)
        let device = try XCTUnwrap(ProcessIdentity.deviceNumber(tty.path))
        devices[tty.path] = device
        identities[pid] = identity(pid, device: device)
        return try XCTUnwrap(state.captureTarget(tty: tty.path, owner: generation(pid)))
    }

    private func surface(_ target: TerminalTargetBinding) -> GhosttySurface {
        GhosttySurface(id: GhosttySurfaceID(application: generation(90), terminalID: "terminal-\(target.ttyOwner.pid)"),
            windowID: "window", tabID: "tab", title: nil, directory: nil, tty: target.tty,
            foregroundPID: target.ttyOwner.pid, tabSelected: true, mappingIssue: nil)
    }

    private func cache(_ target: TerminalTargetBinding, selective: Bool = false, color: String? = nil,
                       effectKind: TerminalEffectKind? = nil) throws {
        if let color = color {
            try state.publishIntent(OrdinaryBackgroundIntent(tty: target.tty, device: target.device,
                producer: target.ttyOwner, deliveryID: "delivery-\(target.ttyOwner.pid)", updatedAt: 1_000,
                background: color))
        }
        _ = try SystemProcessRunner().writeManagedToDevice(path: target.tty,
            lockURL: state.lockURL(forTTY: target.tty)) { _, deadline in
            try self.state.cacheTargetUnlocked(target, deadline: deadline)
            if let color = color {
                try self.state.bindOrdinaryIntentUnlocked(OrdinaryBackgroundIntent(tty: target.tty,
                    device: target.device, producer: target.ttyOwner, deliveryID: "delivery-\(target.ttyOwner.pid)",
                    updatedAt: 1_000, background: color), to: target, deadline: deadline)
            }
            if selective || effectKind != nil {
                try self.state.saveEffectUnlocked(TerminalEffectRecord(target: target, controller: self.generation(90),
                    effectID: "previous-effect", kind: effectKind ?? .selectiveBackground,
                    background: "#AABBCC", heartbeatAt: 1_000),
                    deadline: deadline)
            }
            return nil
        }
    }

    private func broadcaster(runner: ProcessRunner = SystemProcessRunner(),
                             native: @escaping () throws -> [GhosttySurface] = { throw GhosttyCatalogError.permissionDenied }) -> Broadcaster {
        let policy = VisualRestrictionPolicy(restrictions: restrictions, muteURL: root.appendingPathComponent("home/mute.state"),
            lockURL: root.appendingPathComponent("lock.state"), clock: clock, pidAlive: { $0 == 80 })
        let recovery = VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: policy, processRunner: runner, clock: clock, controller: generation(90), nativeSnapshot: native)
        return Broadcaster(recovery: recovery)
    }

    private func writeMute(_ muted: Bool) throws {
        try MuteStateWriter.write(MuteStateData(muted: muted, reason: muted ? .masterPaused : .none,
            untilEpoch: 0, writtenEpoch: 1_000, appPID: 80, pauseBg: "#123456", pauseFg: "#ABCDEF"),
            to: root.appendingPathComponent("home/mute.state"))
    }

    private var ignoredVisual: PauseVisual {
        PauseVisual(backgroundColor: "#FFFFFF", foregroundColor: "#000000", defaultBackgroundColor: "#FFFFFF")
    }

    private func read(_ target: TerminalTargetBinding) throws -> Data {
        let tty = try XCTUnwrap(ptys.first { $0.path == target.tty })
        return try readTestPTY(tty.master, count: 4_096)
    }

    private func noBytes(_ target: TerminalTargetBinding) throws {
        let tty = try XCTUnwrap(ptys.first { $0.path == target.tty })
        var ready = pollfd(fd: tty.master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 10), 0)
    }

    func testPauseUsesCurrentPolicyBytesWithoutChangingSuspension() throws {
        let target = try terminal(10)
        try cache(target)
        try writeMute(true)
        let marker = try Data(contentsOf: restrictions.url)
        let broadcaster = broadcaster(native: {
            XCTAssertFalse(Thread.isMainThread)
            throw GhosttyCatalogError.permissionDenied
        })
        broadcaster.broadcastPaused(visual: ignoredVisual)
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(target), Data(("\u{1B}]104\u{07}\u{1B}]10;#ABCDEF\u{07}"
            + "\u{1B}]11;#123456\u{07}\u{1B}]1337;SetBackgroundImageFile=\u{07}").utf8))
        XCTAssertEqual(try Data(contentsOf: restrictions.url), marker)
        XCTAssertEqual(broadcaster.lastResult?.catalogueAvailable, false)
        XCTAssertEqual(broadcaster.lastResult?.items.first?.status, .restored)
    }

    func testLockedRequestUsesCurrentFiniteLockRatherThanQueuedVisualOrTitle() throws {
        let target = try terminal(10)
        try cache(target)
        try LockStateWriter.write(LockStateData(locked: true, reason: .manual, lockUntilEpoch: 1_500,
            unlockUntilEpoch: 0, writtenEpoch: 1_000, lockBg: "#667788", lockFg: "#EEEEFF"),
            to: root.appendingPathComponent("lock.state"))
        let broadcaster = broadcaster()
        broadcaster.broadcastLocked(visual: ignoredVisual, untilText: "QUEUED_TITLE_SENTINEL")
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        let date = Date(timeIntervalSince1970: 1_500), calendar = Calendar.current
        let until = String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
        XCTAssertEqual(try read(target), Data(("\u{1B}]104\u{07}\u{1B}]10;#EEEEFF\u{07}\u{1B}]11;#667788\u{07}"
            + "\u{1B}]1337;SetBackgroundImageFile=\u{07}\u{1B}]0;🔒 locked until \(until)\u{07}").utf8))
    }

    func testCachedPlainClearUsesLatestIntentAndNeverReplaysHistoricalTitleOrAlert() throws {
        let target = try terminal(10)
        try cache(target, color: "#456789")
        let pending = root.appendingPathComponent("pending/\(target.tty.replacingOccurrences(of: "/", with: "_")).osc")
        try FileManager.default.createDirectory(at: pending.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("\u{1B}]0;OLD_TITLE\u{07}ALERT_SENTINEL\u{07}".utf8).write(to: pending)
        let broadcaster = broadcaster()
        broadcaster.broadcastPausedClear()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(target), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]11;#456789\u{1B}\\".utf8))
        broadcaster.broadcast()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;#456789\u{1B}\\".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
    }

    func testStartupRegistersNativePlainShellAndClearsPreviousSelectiveEffect() throws {
        let plain = try terminal(10)
        let row = surface(plain)
        let target = try XCTUnwrap(state.captureTarget(for: row))
        try cache(target, selective: true, color: "#456789")
        let marker = try Data(contentsOf: restrictions.url)
        let broadcaster = broadcaster(native: { XCTAssertFalse(Thread.isMainThread); return [row] })
        broadcaster.discoverAndRegisterActiveAgentTTYs()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;#456789\u{1B}\\".utf8))
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, deadline: .max)).active)
        XCTAssertEqual(try Data(contentsOf: restrictions.url), marker)
        XCTAssertEqual(state.cachedRecords().bindings, [target])
    }

    func testStartupDiscoversUncachedPlainShellWithoutPaintingItsBackground() throws {
        let plain = try terminal(10)
        let row = surface(plain)
        let runner = MockProcessRunner()
        var prepared: [Data?] = []
        runner.managedHandler = { path, lock, prepare in
            XCTAssertFalse(Thread.isMainThread)
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock) { fd, deadline in
                let bytes = try prepare(fd, deadline)
                prepared.append(bytes)
                return bytes
            }
        }
        let broadcaster = broadcaster(runner: runner, native: { return [row] })
        XCTAssertTrue(state.cachedRecords().bindings.isEmpty)
        broadcaster.discoverAndRegisterActiveAgentTTYs()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(prepared.count, 1)
        if prepared.count == 1 {
            XCTAssertNil(prepared[0])
        }
        try noBytes(plain)
        XCTAssertEqual(state.cachedRecords().bindings.first?.nativeSurface, row.id)
        XCTAssertTrue(runner.writtenDevices.isEmpty)
        XCTAssertEqual(broadcaster.lastResult?.catalogueAvailable, true)
        XCTAssertEqual(broadcaster.lastResult?.items.first?.status, .unaffected)
    }

    func testStartupRestoresCachedEffectBeforeBlockedNativeForEveryRestrictionStatus() throws {
        for (index, status) in [VisualRestrictionsStatus.active, .suspended, .unavailable].enumerated() {
            let target = try terminal(Int32(10 + index))
            try cache(target, effectKind: .globalRestriction)
            try writeMute(status.disablesRestrictions)
            if status == .unavailable {
                try Data("SCHEMA_VERSION=\"77\"\nSUSPENDED=\"false\"\n".utf8).write(to: restrictions.url)
            } else {
                try restrictions.write(suspended: status == .suspended)
            }
            let marker = try Data(contentsOf: restrictions.url)
            let entered = DispatchSemaphore(value: 0)
            let release = DispatchSemaphore(value: 0)
            defer { release.signal() }
            let broadcaster = broadcaster(native: {
                XCTAssertFalse(Thread.isMainThread)
                entered.signal()
                release.wait()
                return []
            })
            broadcaster.discoverAndRegisterActiveAgentTTYs()
            XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
            XCTAssertEqual(try read(target), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{1B}\\".utf8))
            XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, deadline: .max)).active)
            XCTAssertEqual(try Data(contentsOf: restrictions.url), marker)
            release.signal()
            XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
            try noBytes(target)
            XCTAssertEqual(restrictions.read(), status)
        }
    }

    func testQueuedPauseReadsSuspensionAfterEarlierNativeWork() throws {
        let plain = try terminal(10)
        let row = surface(plain)
        try writeMute(true)
        let entered = expectation(description: "First native request is pending")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let lock = NSLock()
        var calls = 0
        let broadcaster = broadcaster(native: {
            XCTAssertFalse(Thread.isMainThread)
            lock.lock(); calls += 1; let first = calls == 1; lock.unlock()
            if first { entered.fulfill(); release.wait() }
            return [row]
        })
        broadcaster.broadcast()
        wait(for: [entered], timeout: 1)
        broadcaster.broadcastPaused(visual: ignoredVisual)
        try restrictions.write(suspended: true)
        release.signal()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(plain), Data("\u{1B}]111\u{1B}\\".utf8))
        try noBytes(plain)
        XCTAssertEqual(restrictions.read(), .suspended)
    }

    func testCoalescingRetainsResetFlagsAndDoesNotBuildNativeBacklog() throws {
        let target = try terminal(10)
        try cache(target)
        let entered = expectation(description: "Registration is waiting for native")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let lock = NSLock()
        var calls = 0
        let broadcaster = broadcaster(native: {
            lock.lock(); calls += 1; let first = calls == 1; lock.unlock()
            if first { entered.fulfill(); release.wait() }
            return []
        })
        broadcaster.discoverAndRegisterActiveAgentTTYs()
        wait(for: [entered], timeout: 1)
        broadcaster.broadcastPausedClear()
        broadcaster.broadcast()
        for _ in 0..<100 { broadcaster.broadcastPaused(visual: ignoredVisual) }
        release.signal()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(try read(target), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{1B}\\".utf8))
        try noBytes(target)
    }

    func testGenericFailureRetainsOldRegistryAndBindingForRetryBesideHealthyTarget() throws {
        let healthy = try terminal(10), failed = try terminal(11)
        try cache(healthy); try cache(failed)
        let registry = root.appendingPathComponent("active-ttys/\(failed.tty.replacingOccurrences(of: "/", with: "_"))")
        try FileManager.default.createDirectory(at: registry.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: registry)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: registry.path)
        let runner = MockProcessRunner()
        var fail = true
        runner.managedHandler = { path, lock, prepare in
            XCTAssertFalse(Thread.isMainThread)
            if path == failed.tty && fail { throw ProcessRunnerError.deviceIOFailed(path, EIO) }
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock, prepare: prepare)
        }
        let broadcaster = broadcaster(runner: runner)
        broadcaster.broadcastPausedClear()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(healthy), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{1B}\\".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: registry.path))
        XCTAssertTrue(state.cachedRecords().bindings.contains(failed))
        XCTAssertTrue(broadcaster.lastResult?.items.contains { $0.target == failed && $0.status == .failed } == true)
        XCTAssertTrue(runner.writtenDevices.isEmpty)
        fail = false
        broadcaster.broadcast()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(failed), Data("\u{1B}]111\u{1B}\\".utf8))
        XCTAssertFalse(broadcaster.lastResult?.items.contains { $0.status == .failed } == true)
    }

    private func openTestPTY() throws -> (master: Int32, slave: Int32, path: String) {
        var master: Int32 = -1, slave: Int32 = -1
        var name = [CChar](repeating: 0, count: 1_024)
        guard openpty(&master, &slave, &name, nil, nil) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        var attributes = termios()
        tcgetattr(slave, &attributes); cfmakeraw(&attributes); tcsetattr(slave, TCSANOW, &attributes)
        return (master, slave, String(cString: name))
    }

    private func readTestPTY(_ master: Int32, count: Int) throws -> Data {
        var descriptor = pollfd(fd: master, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 1_000) == 1 else { throw POSIXError(.ETIMEDOUT) }
        var bytes = [UInt8](repeating: 0, count: count)
        let received = Darwin.read(master, &bytes, bytes.count)
        guard received >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        return Data(bytes.prefix(received))
    }

    func testSystemProcessRunnerThrowsOnUnwritablePath() {
        XCTAssertThrowsError(try SystemProcessRunner().writeToDevice(path: "/nonexistent/device-xyz", data: Data([1])))
    }

    func testSystemProcessRunnerDeliversExactPTYBytes() throws {
        let tty = try openTestPTY(); defer { close(tty.master); close(tty.slave) }
        let bytes = Data("\u{1B}]110\u{07}\u{1B}]111\u{07}".utf8)
        try SystemProcessRunner().writeToDevice(path: tty.path, data: bytes)
        XCTAssertEqual(try readTestPTY(tty.master, count: bytes.count), bytes)
    }

    func testSystemProcessRunnerDeliversLargePTYWriteWhileReaderDrains() throws {
        let tty = try openTestPTY(); defer { close(tty.master); close(tty.slave) }
        let bytes = Data((0..<(64 * 1_024)).map { UInt8(truncatingIfNeeded: $0) })
        let finished = expectation(description: "Writer completes partial writes")
        DispatchQueue.global().async {
            do { try SystemProcessRunner().writeToDevice(path: tty.path, data: bytes) }
            catch { XCTFail("PTY writer failed: \(error)") }
            finished.fulfill()
        }
        var received = Data()
        while received.count < bytes.count { received.append(try readTestPTY(tty.master, count: 4_096)) }
        wait(for: [finished], timeout: 1)
        XCTAssertEqual(received, bytes)
    }

    func testSystemProcessRunnerDisconnectedPTYFailsPromptly() throws {
        let tty = try openTestPTY(); close(tty.master); defer { close(tty.slave) }
        let start = DispatchTime.now().uptimeNanoseconds
        XCTAssertThrowsError(try SystemProcessRunner().writeToDevice(path: tty.path, data: Data([1])))
        XCTAssertLessThan(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9, 1)
    }

    func testDeviceWriteDeadlineDoesNotWaitForWedgedOperation() {
        let release = DispatchSemaphore(value: 0); defer { release.signal() }
        let start = DispatchTime.now().uptimeNanoseconds
        XCTAssertThrowsError(try SystemProcessRunner.completeDeviceWrite(path: "wedged-test-device") { _ in release.wait() })
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
        XCTAssertGreaterThanOrEqual(elapsed, 0.08)
        XCTAssertLessThan(elapsed, 1)
    }

    func testSystemProcessRunnerFullPTYQueueRespectsDeadline() throws {
        let tty = try openTestPTY(); defer { close(tty.master); close(tty.slave) }
        let start = DispatchTime.now().uptimeNanoseconds
        XCTAssertThrowsError(try SystemProcessRunner().writeToDevice(path: tty.path,
            data: Data(repeating: 0x61, count: 1_024 * 1_024)))
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
        XCTAssertGreaterThanOrEqual(elapsed, 0.08)
        XCTAssertLessThan(elapsed, 1)
    }
}
