import XCTest
import Darwin
@testable import TAVSApp

final class BroadcasterTests: XCTestCase {
    private let emergencyReset = Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{07}".utf8)
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

    private func recovery(runner: ProcessRunner = SystemProcessRunner(),
                          native: @escaping () throws -> [GhosttySurface] = { throw GhosttyCatalogError.permissionDenied }) -> VisualRecovery {
        let policy = VisualRestrictionPolicy(restrictions: restrictions, muteURL: root.appendingPathComponent("home/mute.state"),
            lockURL: root.appendingPathComponent("lock.state"), clock: clock, pidAlive: { $0 == 80 })
        return VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: policy, processRunner: runner, clock: clock, controller: generation(90), nativeSnapshot: native)
    }

    private func broadcaster(runner: ProcessRunner = SystemProcessRunner(),
                             native: @escaping () throws -> [GhosttySurface] = { throw GhosttyCatalogError.permissionDenied }) -> Broadcaster {
        Broadcaster(recovery: recovery(runner: runner, native: native))
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

    func testSuspendedSchedulerClearDoesNotReapplyRetainedThemeAfterRecovery() throws {
        let target = try terminal(10)
        try cache(target, color: "#456789")
        try writeMute(true)
        let service = recovery(), broadcaster = Broadcaster(recovery: service)
        broadcaster.broadcastPaused(visual: ignoredVisual)
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); _ = try read(target)
        XCTAssertFalse(service.recover().hasFailures)
        XCTAssertEqual(try read(target), emergencyReset)
        for _ in 0..<3 {
            broadcaster.broadcastPausedClear(); broadcaster.broadcast()
            XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
            try noBytes(target)
        }
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#456789")
        clock.advance(by: 1)
        let fresh = OrdinaryBackgroundIntent(tty: target.tty, device: target.device, producer: target.ttyOwner,
            deliveryID: "fresh-after-recovery", updatedAt: 1_001, background: "#ABCDEF")
        XCTAssertTrue(try service.write(.ordinary(fresh, synthetic: false, intakeAt: 1_001), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
        broadcaster.broadcastPausedClear(); broadcaster.broadcast()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        try noBytes(target)
    }

    func testSuspendedStartupRestoresDefaultsInsteadOfRetainedIntent() throws {
        let target = try terminal(10)
        try cache(target, color: "#456789", effectKind: .globalRestriction)
        try restrictions.write(suspended: true)
        let broadcaster = broadcaster(native: { [] })
        broadcaster.discoverAndRegisterActiveAgentTTYs()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(target), emergencyReset)
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#456789")
        XCTAssertNil(try state.currentEffectUnlocked(target, kind: .globalRestriction, deadline: .max))
        broadcaster.broadcastPausedClear(); broadcaster.broadcast()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(target)
    }

    func testDelayedSuspendedClearAndRelaunchPreserveFreshCompleteRender() throws {
        let plain = try terminal(10), row = surface(plain)
        let target = try XCTUnwrap(state.captureTarget(for: row))
        try cache(target, color: "#456789", effectKind: .globalRestriction)
        let service = recovery()
        XCTAssertFalse(service.recover().hasFailures); _ = try read(target)
        let entered = expectation(description: "Clear is waiting for native discovery")
        let release = DispatchSemaphore(value: 0), lock = NSLock()
        defer { release.signal() }
        var calls = 0
        let cachedClear = DispatchSemaphore(value: 0), runner = MockProcessRunner()
        runner.managedHandler = { path, outputLock, afterWrite, prepare in
            let wrote = try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: outputLock,
                beforeOpen: nil, target: target.physicalTarget, afterWrite: afterWrite, prepare: prepare)
            cachedClear.signal()
            return wrote
        }
        let broadcaster = broadcaster(runner: runner, native: {
            lock.lock(); calls += 1; let first = calls == 1; lock.unlock()
            if first { entered.fulfill(); release.wait() }
            return [row]
        })
        broadcaster.broadcastPausedClear()
        wait(for: [entered], timeout: 1)
        XCTAssertEqual(cachedClear.wait(timeout: .now() + 1), .success)
        try noBytes(target)
        clock.advance(by: 1)
        var fields = ["#ABCDEF", "set", "#123456"] + Array(repeating: "", count: 15)
        fields += ["1", "FRESH_TITLE", "iterm2-clear", "", "1"]
        let style = try TerminalRender(Data((fields.joined(separator: "\0") + "\0").utf8))
        let fresh = OrdinaryBackgroundIntent(tty: target.tty, device: target.device, producer: target.ttyOwner,
            deliveryID: "fresh-render", updatedAt: 1_001, background: "#ABCDEF")
        XCTAssertEqual(try service.render(style, intent: fresh, synthetic: false, intakeAt: 1_001, to: target), .rendered)
        var expected = style.beforeBackground
        expected.append(Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
        expected.append(style.afterBackground(synthetic: false))
        XCTAssertEqual(try read(target), expected)
        release.signal(); XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(target)
        broadcaster.discoverAndRegisterActiveAgentTTYs()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(target)
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#ABCDEF")
    }

    func testStartupDiscoversUncachedPlainShellWithoutPaintingItsBackground() throws {
        let plain = try terminal(10)
        let row = surface(plain)
        let runner = MockProcessRunner()
        var prepared: [Data?] = []
        runner.managedHandler = { path, lock, afterWrite, prepare in
            XCTAssertFalse(Thread.isMainThread)
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock, beforeOpen: nil, afterWrite: afterWrite) { fd, deadline in
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
            let expected = status.disablesRestrictions ? emergencyReset
                : Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{1B}\\".utf8)
            XCTAssertEqual(try read(target), expected)
            XCTAssertNil(try state.currentEffectUnlocked(target, kind: .globalRestriction, deadline: .max))
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
        runner.managedHandler = { path, lock, afterWrite, prepare in
            XCTAssertFalse(Thread.isMainThread)
            if path == failed.tty && fail { throw ProcessRunnerError.deviceIOFailed(path, EIO) }
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock, beforeOpen: nil, afterWrite: afterWrite, prepare: prepare)
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

    func testFailedRestrictionRetryTouchesOnlyFailedTargetAndReportsCompletion() throws {
        let healthy = try terminal(10), failed = try terminal(11)
        try cache(healthy); try cache(failed); try writeMute(true)
        let runner = MockProcessRunner(), lock = NSLock()
        var reject = true
        runner.managedHandler = { path, lockURL, afterWrite, prepare in
            lock.lock(); let fail = reject && path == failed.tty; lock.unlock()
            if fail { throw ProcessRunnerError.deviceIOFailed(path, EIO) }
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lockURL, beforeOpen: nil, afterWrite: afterWrite, prepare: prepare)
        }
        let broadcaster = broadcaster(runner: runner, native: { [] })
        let reported = expectation(description: "Partial failure published on main")
        broadcaster.resultChanged = { _, items in
            XCTAssertTrue(Thread.isMainThread)
            if items.contains(where: { $0.status == .failed }) { reported.fulfill() }
        }
        broadcaster.broadcastPaused(visual: ignoredVisual)
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); _ = try read(healthy)
        wait(for: [reported], timeout: 1)
        lock.lock(); reject = false; lock.unlock()
        let completed = expectation(description: "Failed target recovered")
        broadcaster.resultChanged = { _, items in
            XCTAssertTrue(Thread.isMainThread)
            if !items.contains(where: { $0.status == .failed }) { completed.fulfill() }
        }
        broadcaster.retryFailedRestrictions()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); _ = try read(failed)
        wait(for: [completed], timeout: 1); try noBytes(healthy)
        broadcaster.retryFailedRestrictions()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(failed)
    }

    func testSchedulerStorageRepairActuallyPaintsItsRequestedPauseOnce() throws {
        let target = try terminal(10); try cache(target, color: "#456789")
        let muteURL = root.appendingPathComponent("home/mute.state")
        let lockURL = root.appendingPathComponent("lock.state"), scheduleURL = root.appendingPathComponent("schedule.json")
        try ScheduleStore.save(ScheduleConfig(version: 1, masterActive: false,
            allowedWindows: [], quietPeriods: []), to: scheduleURL)
        try FileManager.default.createDirectory(at: muteURL, withIntermediateDirectories: true)
        let service = VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: VisualRestrictionPolicy(restrictions: restrictions, muteURL: muteURL,
                lockURL: lockURL, clock: clock),
            processRunner: SystemProcessRunner(), clock: clock, controller: generation(90), nativeSnapshot: { [] })
        let broadcaster = Broadcaster(recovery: service), timers = MockTimerScheduler()
        let scheduler = Scheduler(clock: clock, timerScheduler: timers, fileWatcher: MockFileWatcher(),
            broadcaster: broadcaster, muteStateURL: muteURL, scheduleURL: scheduleURL,
            lockStateURL: lockURL, visualRestrictionsState: restrictions,
            pauseVisualProvider: { PauseVisual(backgroundColor: "#123456", foregroundColor: "#ABCDEF",
                defaultBackgroundColor: "#123456") })
        defer { scheduler.stop() }
        scheduler.start(); XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertTrue(scheduler.statusText.contains("could not be saved")); try noBytes(target)
        try FileManager.default.moveItem(at: muteURL, to: root.appendingPathComponent("blocked-mute"))
        timers.scheduledTimers.first { $0.repeating }?.handler()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(try read(target), Data(("\u{1B}]104\u{07}\u{1B}]10;#ABCDEF\u{07}"
            + "\u{1B}]11;#123456\u{07}\u{1B}]1337;SetBackgroundImageFile=\u{07}").utf8))
        XCTAssertFalse(scheduler.statusText.contains("could not be saved"))
        timers.scheduledTimers.first { $0.repeating }?.handler()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(target)
    }

    func testRegistrationAndUnaffectedRetryCannotEraseFailedPaint() throws {
        let target = try terminal(10); try cache(target); try writeMute(true)
        let runner = MockProcessRunner()
        runner.managedHandler = { path, lock, afterWrite, prepare in
            try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock, beforeOpen: nil, afterWrite: afterWrite) { fd, deadline in
                let bytes = try prepare(fd, deadline)
                if bytes != nil { throw ProcessRunnerError.deviceIOFailed(path, EIO) }
                return nil
            }
        }
        let broadcaster = broadcaster(runner: runner, native: { [] })
        broadcaster.broadcastPaused(visual: ignoredVisual)
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        broadcaster.discoverAndRegisterActiveAgentTTYs()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(broadcaster.lastResult?.items.filter { $0.status == .failed }.count, 1)
        try restrictions.write(suspended: true)
        broadcaster.retryFailedRestrictions()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(target)
        XCTAssertEqual(broadcaster.lastResult?.items.filter { $0.status == .failed }.count, 1)
    }

    func testFailedReleaseRetryRestoresOnlyFailedTargetBeforePreparationFailure() throws {
        try failedReleaseRetry(afterPreparation: false)
    }

    func testFailedReleaseRetryRestoresCanceledLegacyRecordAfterPreparationFailure() throws {
        try failedReleaseRetry(afterPreparation: true)
    }

    private func failedReleaseRetry(afterPreparation: Bool) throws {
        let healthy = try terminal(10), failed = try terminal(11)
        try cache(healthy, color: "#456789"); try cache(failed, color: "#ABCDEF")
        try writeMute(true)
        let runner = MockProcessRunner(), guardLock = NSLock()
        var reject = false, paths: [String] = []
        runner.managedHandler = { path, lockURL, afterWrite, prepare in
            guardLock.lock(); paths.append(path); let fail = reject && path == failed.tty; guardLock.unlock()
            if fail && !afterPreparation { throw ProcessRunnerError.deviceIOFailed(path, EIO) }
            let target = path == failed.tty ? failed : healthy
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lockURL,
                beforeOpen: nil, target: target.physicalTarget, emergency: false, afterWrite: afterWrite) { fd, deadline in
                let bytes = try prepare(fd, deadline)
                if fail && bytes != nil { throw ProcessRunnerError.deviceIOFailed(path, EIO) }
                return bytes
            }
        }
        let broadcaster = broadcaster(runner: runner, native: { [] })
        broadcaster.broadcastPaused(visual: ignoredVisual)
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); _ = try read(healthy); _ = try read(failed)
        guardLock.lock(); reject = true; guardLock.unlock()
        try writeMute(false)
        broadcaster.broadcastPausedClear(); broadcaster.broadcast()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); _ = try read(healthy)
        XCTAssertEqual(try XCTUnwrap(state.currentEffectUnlocked(failed, deadline: .max)).active, !afterPreparation)
        XCTAssertEqual(broadcaster.lastResult?.items.filter { $0.status == .failed }.count, 1)
        try noBytes(failed)
        guardLock.lock(); reject = false; paths.removeAll(); guardLock.unlock()
        broadcaster.retryFailedRestrictions()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        guardLock.lock(); let retried = paths; guardLock.unlock()
        XCTAssertEqual(retried, [failed.tty])
        XCTAssertEqual(broadcaster.lastResult?.items.filter { $0.status == .failed }.count, 0)
        if broadcaster.lastResult?.items.contains(where: { $0.status == .failed }) == false {
            XCTAssertEqual(try read(failed), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
        }
        try noBytes(healthy)
        guardLock.lock(); paths.removeAll(); guardLock.unlock()
        broadcaster.retryFailedRestrictions()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        guardLock.lock(); let extra = paths; guardLock.unlock()
        XCTAssertTrue(extra.isEmpty)
    }

    func testActiveFailedReleaseRetryPreservesCompletedFreshPaletteWithoutTitleOrBellReplay() throws {
        try failedReleaseWithFreshRender(suspended: false)
    }

    func testSuspendedRetryPreservesFreshRenderAndRetainsUnconfirmedFailure() throws {
        try failedReleaseWithFreshRender(suspended: true)
    }

    private func failedReleaseWithFreshRender(suspended: Bool) throws {
        let target = try terminal(10)
        try cache(target, color: "#456789"); try writeMute(true)
        let runner = MockProcessRunner(), guardLock = NSLock()
        var reject = false
        runner.managedHandler = { path, lockURL, afterWrite, prepare in
            guardLock.lock(); let fail = reject; guardLock.unlock()
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lockURL,
                beforeOpen: nil, target: target.physicalTarget, emergency: false, afterWrite: afterWrite) { fd, deadline in
                let bytes = try prepare(fd, deadline)
                if fail && bytes != nil { throw ProcessRunnerError.deviceIOFailed(path, EIO) }
                return bytes
            }
        }
        let broadcaster = broadcaster(runner: runner, native: { [] })
        broadcaster.broadcastPaused(visual: ignoredVisual)
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); _ = try read(target)
        guardLock.lock(); reject = true; guardLock.unlock()
        try writeMute(false); broadcaster.broadcastPausedClear()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(target)
        guardLock.lock(); reject = false; guardLock.unlock()
        let service = recovery()
        if suspended {
            XCTAssertFalse(service.recover().hasFailures)
            XCTAssertEqual(try read(target), emergencyReset)
        }
        clock.advance(by: 1)
        var fields = ["#ABCDEF", "set", "#123456"] + Array(repeating: "", count: 15)
        fields += ["1", "FRESH_TITLE", "iterm2-clear", "", "1"]
        let style = try TerminalRender(Data((fields.joined(separator: "\0") + "\0").utf8))
        let fresh = OrdinaryBackgroundIntent(tty: target.tty, device: target.device, producer: target.ttyOwner,
            deliveryID: "fresh-render", updatedAt: 1_001, background: "#ABCDEF")
        XCTAssertEqual(try service.render(style, intent: fresh, synthetic: false, intakeAt: 1_001, to: target), .rendered)
        var expected = suspended ? Data() : Data("\u{1B}]104\u{07}\u{1B}]110\u{07}".utf8)
        expected.append(style.beforeBackground)
        expected.append(Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
        expected.append(style.afterBackground(synthetic: false))
        XCTAssertEqual(try read(target), expected)
        XCTAssertNil(try state.currentEffectUnlocked(target, kind: .globalRestriction, deadline: .max))
        broadcaster.retryFailedRestrictions(); XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        if suspended {
            try noBytes(target)
            XCTAssertEqual(broadcaster.lastResult?.items.filter { $0.status == .failed }.count, 1)
        } else {
            XCTAssertEqual(try read(target), Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
            XCTAssertEqual(broadcaster.lastResult?.items.filter { $0.status == .failed }.count, 0)
        }
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#ABCDEF")
    }

    func testQueuedRestrictionRetryIsCoalescedAndCannotPaintAfterSuspension() throws {
        let target = try terminal(10); try cache(target); try writeMute(true)
        let entered = expectation(description: "Retry is preparing"), release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let lock = NSLock(), runner = MockProcessRunner()
        var hold = false, attempts = 0
        runner.managedHandler = { path, lockURL, afterWrite, prepare in
            lock.lock(); attempts += 1; let waiting = hold; lock.unlock()
            if !waiting { throw ProcessRunnerError.deviceIOFailed(path, EIO) }
            entered.fulfill(); release.wait()
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lockURL, beforeOpen: nil, afterWrite: afterWrite, prepare: prepare)
        }
        let broadcaster = broadcaster(runner: runner, native: { [] })
        broadcaster.broadcastPaused(visual: ignoredVisual)
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        lock.lock(); let before = attempts; hold = true; lock.unlock()
        broadcaster.retryFailedRestrictions(); wait(for: [entered], timeout: 1)
        for _ in 0..<100 { broadcaster.retryFailedRestrictions() }
        try restrictions.write(suspended: true); release.signal()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(target)
        lock.lock(); let after = attempts; lock.unlock()
        XCTAssertEqual(after, before + 1)
        XCTAssertEqual(broadcaster.lastResult?.items.filter { $0.status == .failed }.count, 1)
    }

    func testUnboundNativeFailureRemainsVisibleWithoutBlindDiscoveryRetry() throws {
        let target = try terminal(10), row = surface(target)
        identities.removeValue(forKey: target.ttyOwner.pid)
        var calls = 0
        let broadcaster = broadcaster(native: { calls += 1; return [row] })
        broadcaster.broadcastPaused(visual: ignoredVisual)
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3))
        XCTAssertEqual(broadcaster.lastResult?.items.filter { $0.status == .failed && $0.target == nil }.count, 1)
        broadcaster.retryFailedRestrictions()
        XCTAssertTrue(broadcaster.waitUntilIdle(timeout: 3)); try noBytes(target)
        XCTAssertEqual(calls, 1)
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
