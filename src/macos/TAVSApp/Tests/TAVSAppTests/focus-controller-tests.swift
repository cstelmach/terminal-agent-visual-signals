import XCTest
import Combine
import Darwin
@testable import TAVSApp

final class FocusControllerTests: XCTestCase {
    private var root: URL!
    private var clock: VirtualClock!
    private var state: TerminalVisualStateStore!
    private var restrictions: VisualRestrictionsStateStore!
    private var recovery: VisualRecovery!
    private var identities: [Int32: ProcessIdentity] = [:]
    private var missingProcesses = Set<Int32>()
    private var ptys: [(master: Int32, slave: Int32, path: String)] = []
    private var subscriptions = Set<AnyCancellable>()
    private var nativeRows: [GhosttySurface] = []
    private var nativeError: Error?
    private func generation(_ pid: Int32) -> ProcessGeneration {
        ProcessGeneration(pid: pid, startSeconds: 100, startMicroseconds: 1)
    }

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"]))
            .appendingPathComponent("controller-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
        for pid: Int32 in [80, 90] {
            identities[pid] = ProcessIdentity(generation: generation(pid), parentPID: 1,
                group: UInt32(pid), device: UInt32.max, foregroundGroup: UInt32(pid))
        }
        restrictions = VisualRestrictionsStateStore(url: root.appendingPathComponent("visual-restrictions.state"))
        configureState()
    }

    private func configureState(lookup: ((Int32) -> ProcessIdentity?)? = nil,
                                runner: ProcessRunner = SystemProcessRunner()) {
        state = TerminalVisualStateStore(runtimeDirectory: root, clock: clock,
            lookup: lookup ?? { self.identities[$0] }, processMissing: { self.missingProcesses.contains($0) })
        recovery = VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: VisualRestrictionPolicy(restrictions: restrictions, muteURL: root.appendingPathComponent("mute.state"),
                lockURL: root.appendingPathComponent("lock.state"), clock: clock),
            processRunner: runner, clock: clock, controller: generation(90), nativeSnapshot: { [] })
    }

    override func tearDownWithError() throws {
        subscriptions.removeAll()
        for tty in ptys { close(tty.master); close(tty.slave) }
        ptys.removeAll()
        try FileManager.default.removeItem(at: root)
    }

    private func surface(_ pid: Int32) throws -> GhosttySurface {
        var master: Int32 = -1, slave: Int32 = -1
        var name = [CChar](repeating: 0, count: 1_024)
        guard openpty(&master, &slave, &name, nil, nil) == 0 else { throw POSIXError(.EIO) }
        var attributes = termios(); tcgetattr(slave, &attributes); cfmakeraw(&attributes)
        tcsetattr(slave, TCSANOW, &attributes)
        let path = String(cString: name), device = try XCTUnwrap(ProcessIdentity.deviceNumber(path))
        ptys.append((master, slave, path))
        identities[pid] = ProcessIdentity(generation: generation(pid), parentPID: 1,
            group: UInt32(pid), device: device, foregroundGroup: UInt32(pid))
        let row = GhosttySurface(id: GhosttySurfaceID(application: generation(80), terminalID: String(pid)),
            windowID: "window", tabID: "tab", title: "same", directory: "/same", tty: path,
            foregroundPID: pid, tabSelected: true, mappingIssue: nil)
        nativeRows.removeAll { $0.id == row.id }; nativeRows.append(row)
        return row
    }

    private func controller(_ timers: MockTimerScheduler, queue: DispatchQueue = DispatchQueue(label: "test.preview"),
                            clearQueue: DispatchQueue = DispatchQueue(label: "test.preview-clear", attributes: .concurrent),
                            snapshot: (() throws -> [GhosttySurface])? = nil,
                            colors: ((ProcessGeneration) throws -> TerminalRenderer.Colors)? = nil) -> FocusController {
        FocusController(state: state, recovery: recovery, restrictions: restrictions, timers: timers,
            clock: clock, queue: queue, clearQueue: clearQueue, nativeSnapshot: snapshot ?? {
                if let error = self.nativeError { throw error }
                return self.nativeRows
            }, colors: colors ?? { _ in
                TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
            })
    }

    private func awaitPaint(_ controller: FocusController, count: Int) {
        let ready = expectation(description: "Selected targets painted")
        controller.$previewed.first { $0.count == count }.sink { _ in ready.fulfill() }.store(in: &subscriptions)
        wait(for: [ready], timeout: 1)
        XCTAssertEqual(controller.previewed.count, count, controller.previewStatus)
    }

    private func read(_ index: Int, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        var descriptor = pollfd(fd: ptys[index].master, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 1_000) == 1 else {
            XCTFail("PTY \(index) produced no expected bytes", file: file, line: line)
            throw POSIXError(.ETIMEDOUT)
        }
        var bytes = [UInt8](repeating: 0, count: 4_096)
        let count = Darwin.read(ptys[index].master, &bytes, bytes.count)
        guard count > 0 else { throw POSIXError(.EIO) }
        return Data(bytes.prefix(count))
    }

    private func awaitManual(_ focus: FocusController) {
        let done = expectation(description: "Manual update completed")
        focus.$focusStatus.first { $0.contains("outside") || $0.contains("unavailable") }
            .sink { _ in done.fulfill() }.store(in: &subscriptions)
        wait(for: [done], timeout: 2)
    }

    private func recordedWriter(_ target: TerminalTargetBinding,
                                openDevice: @escaping (String, Int32) -> Int32 = { Darwin.open($0, $1) })
        -> (MockProcessRunner, () -> [String]) {
        let runner = MockProcessRunner(), traceLock = NSLock()
        var trace: [String] = [], calls = 0
        runner.managedBeforeOpenHandler = { path, lock, beforeOpen, afterWrite, prepare in
            let start = DispatchTime.now().uptimeNanoseconds
            traceLock.lock(); calls += 1; let call = calls; traceLock.unlock()
            func record(_ stage: String, deadline: UInt64? = nil) {
                let now = DispatchTime.now().uptimeNanoseconds
                let remaining = deadline.map { "; remaining ns: \(Int64($0) - Int64(now))" } ?? ""
                traceLock.lock(); trace.append("\(call) \(stage); elapsed ns: \(now - start)\(remaining)")
                traceLock.unlock()
            }
            let system = SystemProcessRunner(openDevice: { path, flags in
                record("open entered")
                let fd = openDevice(path, flags), openError = errno
                record("open returned \(fd), errno \(openError)"); errno = openError
                return fd
            })
            let wrappedBeforeOpen = beforeOpen.map { callback in
                { (deadline: UInt64) throws -> Void in
                    record("beforeOpen entered", deadline: deadline)
                    do { try callback(deadline); record("beforeOpen returned", deadline: deadline) }
                    catch { record("beforeOpen threw \(error)", deadline: deadline); throw error }
                }
            }
            record("caller entered")
            do {
                let wrote = try system.writeManagedToDevice(path: path, lockURL: lock,
                    beforeOpen: wrappedBeforeOpen, target: target.physicalTarget, emergency: false, afterWrite: afterWrite) { fd, deadline in
                    record("prepare entered", deadline: deadline)
                    do {
                        let data = try prepare(fd, deadline)
                        record("prepare returned " + (data.map { "bytes \($0.count)" } ?? "nil"), deadline: deadline)
                        return data
                    } catch { record("prepare threw \(error)", deadline: deadline); throw error }
                }
                record("caller returned \(wrote)"); return wrote
            } catch { record("caller threw \(error)"); throw error }
        }
        return (runner, { traceLock.lock(); defer { traceLock.unlock() }; return trace })
    }

    private func attention(_ row: GhosttySurface, _ delivery: String, producer: Int32? = nil) -> TerminalVisualCoverage {
        TerminalVisualCoverage(observation: TerminalObservation(tty: row.tty!,
            device: identities[row.foregroundPID!]!.device, producer: generation(producer ?? row.foregroundPID!),
            provider: "claude", verifiedAgent: true, state: "complete", event: "Stop",
            deliveryID: delivery, observedAt: clock.now().timeIntervalSince1970),
            intent: nil, attentionEligible: true, status: "Test correlated completion")
    }

    private func refreshAndWait(_ model: SessionsModel) {
        let ready = expectation(description: "Fresh catalogue and coverage accepted")
        model.$refreshing.dropFirst().first { !$0 }.sink { _ in ready.fulfill() }.store(in: &subscriptions)
        model.refresh(); wait(for: [ready], timeout: 2)
    }

    func testPreviewRejectsNativeClosureAfterColorsEvenWithLivePhysicalOwner() throws {
        let row = try surface(10), timers = MockTimerScheduler()
        let focus = controller(timers, colors: { _ in
            self.nativeRows = []
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        focus.preview([row])
        let finished = expectation(description: "Fresh native closure reported")
        focus.$previewStatus.first { $0.contains("unavailable") || $0.contains("previewed") }
            .sink { _ in finished.fulfill() }.store(in: &subscriptions)
        wait(for: [finished], timeout: 2)
        XCTAssertTrue(focus.previewed.isEmpty, focus.previewStatus)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.clearPreview()
    }

    func testManualRejectsChangedNativeTTYAfterColorsWhileOldOwnerRemainsLive() throws {
        let a = try surface(10), b = try surface(20), replacement = try surface(30)
        let focus = controller(MockTimerScheduler(), colors: { _ in
            self.nativeRows = [a, GhosttySurface(id: b.id, windowID: b.windowID, tabID: b.tabID,
                title: b.title, directory: b.directory, tty: replacement.tty,
                foregroundPID: replacement.foregroundPID, tabSelected: true, mappingIssue: nil)]
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        for index in [1,2] {
            var ready = pollfd(fd: ptys[index].master, events: Int16(POLLIN), revents: 0)
            XCTAssertEqual(poll(&ready, 1, 20), 0)
        }
        focus.focusOff()
    }

    func testAutomaticRejectsFreshNativeLookupFailureWithoutLosingCue() throws {
        let a = try surface(10), b = try surface(20)
        let focus = controller(MockTimerScheduler(), colors: { _ in
            self.nativeError = GhosttyCatalogError.nativeUnavailable
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); clock.advance(by: 1)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: attention(a,"new-cue")]); awaitManual(focus)
        XCTAssertEqual(focus.mode, .automatic); XCTAssertEqual(focus.cueSnapshot(for: a.id).count, 1)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.focusOff()
    }

    func testFreshMovedPaneUsesItsCurrentForegroundProcessWithoutNavigation() throws {
        let row = try surface(10), device = identities[10]!.device
        let focus = controller(MockTimerScheduler(), colors: { _ in
            self.identities[10] = ProcessIdentity(generation: self.generation(10), parentPID: 1,
                group: 10, device: device, foregroundGroup: 11)
            self.identities[11] = ProcessIdentity(generation: self.generation(11), parentPID: 10,
                group: 11, device: device, foregroundGroup: 11)
            self.nativeRows = [GhosttySurface(id: row.id, windowID: "moved-window", tabID: "moved-tab",
                title: "new title", directory: row.directory, tty: row.tty, foregroundPID: 11,
                tabSelected: false, mappingIssue: nil)]
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        let cleared = expectation(description: "Moved preview cleaned up")
        focus.$cleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.clearPreview(); wait(for: [cleared], timeout: 2)
        XCTAssertEqual(try read(0), Data("\u{1B}]111\u{1B}\\".utf8))
    }

    func testFreshAmbiguousNativeIDsAndTTYsRejectPreview() throws {
        let a = try surface(10), b = try surface(20)
        let ambiguousTTY = GhosttySurface(id: b.id, windowID: b.windowID, tabID: b.tabID,
            title: b.title, directory: b.directory, tty: a.tty, foregroundPID: a.foregroundPID,
            tabSelected: true, mappingIssue: nil)
        for rows in [[a,a], [a,ambiguousTTY]] {
            nativeRows = rows
            let focus = controller(MockTimerScheduler())
            let finished = expectation(description: "Ambiguity reported")
            focus.$previewStatus.first { $0.contains("unavailable") }.sink { _ in finished.fulfill() }.store(in: &subscriptions)
            focus.preview([a]); wait(for: [finished], timeout: 2)
            XCTAssertTrue(focus.previewed.isEmpty); XCTAssertTrue(state.cachedRecords().effects.isEmpty)
            var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
            XCTAssertEqual(poll(&ready, 1, 20), 0)
            focus.clearPreview()
        }
    }

    func testRecoveryCancelsBlockedNativePreparationWithoutPublishingEffects() throws {
        let a = try surface(10), b = try surface(20)
        let queue = DispatchQueue(label: "blocked.native.focus"), entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let focus = controller(MockTimerScheduler(), queue: queue, snapshot: {
            entered.signal(); release.wait(); return [a,b]
        })
        focus.focusSelected([a], catalogue: [a,b])
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        focus.cancelForRecovery(); try restrictions.write(suspended: true); release.signal()
        let finished = expectation(description: "Cancelled native preparation returned")
        queue.async { DispatchQueue.main.async { finished.fulfill() } }
        wait(for: [finished], timeout: 2)
        XCTAssertEqual(focus.mode, .off); XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testFailedNativeRenewalRetainsRecoverableLeaseAndLogicalManualSet() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        let prior = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        nativeError = GhosttyCatalogError.permissionDenied
        clock.advance(by: 2)
        focus.acceptCatalogue([a,b]); awaitManual(focus)
        let unchanged = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertEqual(unchanged.effectID, prior.effectID); XCTAssertEqual(unchanged.heartbeatAt, prior.heartbeatAt)
        XCTAssertTrue(unchanged.active); XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(focus.workingSet, [a.id])
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        let cleared = expectation(description: "Retained lease explicitly cleared")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [cleared], timeout: 2)
        XCTAssertEqual(try read(1), Data("\u{1B}]111\u{1B}\\".utf8))
    }

    func testFreshNativeMismatchSkipsOnlyThatOutsideTarget() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30)
        nativeRows = [a,b]
        let focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b,c]); awaitManual(focus)
        _ = try read(1)
        XCTAssertNotNil(try state.currentEffectUnlocked(try XCTUnwrap(state.captureTarget(for: b)), kind: .focus, deadline: .max))
        XCTAssertNil(try state.currentEffectUnlocked(try XCTUnwrap(state.captureTarget(for: c)), kind: .focus, deadline: .max))
        var ready = pollfd(fd: ptys[2].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        let cleared = expectation(description: "Healthy partial focus cleared")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [cleared], timeout: 2); _ = try read(1)
    }

    func testMissingFreshNativeCueCannotAuthorizeOtherHighShellDimming() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30)
        nativeRows = [b,c]
        let focus = controller(MockTimerScheduler())
        focus.enableAutomatic(rows: [a,b,c], high: [a.id,b.id], coverage: [:]); clock.advance(by: 1)
        focus.acceptCatalogue([a,b,c], high: [a.id,b.id], coverage: [a.id: attention(a,"missing-native")]); awaitManual(focus)
        XCTAssertEqual(focus.cueSnapshot(for: a.id).count, 1)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[2].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.focusOff()
    }

    func testOnlyHighCueExitDuringPreparationClearsCueWithoutAnotherPoll() throws {
        let a = try surface(10), b = try surface(20)
        let focus = controller(MockTimerScheduler(), colors: { _ in
            self.identities.removeValue(forKey: 10); self.missingProcesses.insert(10)
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); clock.advance(by: 1)
        let cleared = expectation(description: "Only High cue cleared after source exit")
        focus.$attentionCues.dropFirst().first { $0.isEmpty }.sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: attention(a,"exiting")])
        wait(for: [cleared], timeout: 2)
        XCTAssertTrue(focus.attentionCues.isEmpty)
        XCTAssertEqual(focus.mode, .automatic); XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.focusOff()
    }

    func testOnlyHighCueExitDuringRenewalClearsExistingDimming() throws {
        let a = try surface(10), b = try surface(20)
        var queries = 0
        let focus = controller(MockTimerScheduler(), colors: { _ in
            queries += 1
            if queries == 2 { self.identities.removeValue(forKey: 10); self.missingProcesses.insert(10) }
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        let sample = attention(a,"exiting-renewal")
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); clock.advance(by: 1)
        var current = try XCTUnwrap(sample.observation); current.observedAt = clock.now().timeIntervalSince1970
        let coverage = TerminalVisualCoverage(observation: current, intent: nil, attentionEligible: true, status: "Current")
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: coverage]); awaitManual(focus); _ = try read(1)
        let cleared = expectation(description: "Exited only cue restores existing dimming")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        clock.advance(by: 2)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: coverage])
        wait(for: [cleared], timeout: 2)
        XCTAssertTrue(focus.attentionCues.isEmpty); XCTAssertEqual(focus.mode, .automatic)
        XCTAssertEqual(try read(1), Data("\u{1B}]111\u{1B}\\".utf8))
        focus.focusOff()
    }

    func testSessionsAutomaticNavigationAcknowledgesOnlyItsSnapshotAndKeepsPolling() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30)
        let focus = controller(MockTimerScheduler()), timers = MockTimerScheduler()
        var navigation: ((Result<Void, Error>) -> Void)?
        var navigations = 0
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([a,b,c])) }, navigate: { _, done in navigations += 1; navigation = done },
            timerScheduler: timers, clock: clock, visualState: state, visualRestrictionsState: restrictions, focus: focus)
        refreshAndWait(model); model.setPriority(.high, for: [a.id,b.id]); model.enableAutomatic()
        model.closed()
        XCTAssertEqual(model.focusMode, .automatic); XCTAssertEqual(timers.scheduledTimers.count, 1)
        XCTAssertFalse(model.canEnableAutomatic)
        clock.advance(by: 1)
        try state.publishObservation(try XCTUnwrap(attention(a,"first").observation))
        try state.publishObservation(try XCTUnwrap(attention(b,"other").observation))
        refreshAndWait(model); awaitManual(focus); _ = try read(2)
        XCTAssertEqual(navigations, 0); XCTAssertEqual(model.cueCount(for: a.id), 1)
        model.goTo(a.id); XCTAssertEqual(navigations, 1)
        clock.advance(by: 1)
        try state.publishObservation(try XCTUnwrap(attention(a,"later").observation))
        refreshAndWait(model); awaitManual(focus); _ = try read(2)
        navigation?(.success(()))
        XCTAssertEqual(model.cueCount(for: a.id), 1); XCTAssertEqual(model.cueCount(for: b.id), 1)
        model.goTo(b.id); navigation?(.success(()))
        XCTAssertEqual(model.cueCount(for: b.id), 0); XCTAssertEqual(model.cueCount(for: a.id), 1)
        model.goTo(a.id); navigation?(.success(())); _ = try read(2)
        XCTAssertEqual(model.focusMode, .automatic); XCTAssertEqual(timers.scheduledTimers.count, 1)
        model.focusOff(); XCTAssertTrue(timers.scheduledTimers.isEmpty)
    }

    func testSessionsFailedNavigationAndImmediatePriorityRecoveryTransitions() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([a,b])) }, navigate: { _, done in done(.failure(GhosttyCatalogError.focusUnconfirmed)) },
            clock: clock, visualState: state, visualRestrictionsState: restrictions, focus: focus)
        refreshAndWait(model); model.setPriority(.high, for: [a.id]); model.enableAutomatic()
        clock.advance(by: 1); try state.publishObservation(try XCTUnwrap(attention(a,"cue").observation))
        refreshAndWait(model); awaitManual(focus); _ = try read(1)
        model.goTo(a.id)
        XCTAssertEqual(model.cueCount(for: a.id), 1); XCTAssertTrue(model.status.contains("Go To unavailable"))
        model.setPriority(.normal, for: [a.id]); _ = try read(1)
        XCTAssertEqual(model.cueCount(for: a.id), 0); XCTAssertEqual(model.focusMode, .automatic)
        model.setPriority(.high, for: [a.id]); XCTAssertEqual(model.cueCount(for: a.id), 0)
        model.restoreVisibility()
        XCTAssertEqual(model.focusMode, .off); XCTAssertFalse(model.canEnableAutomatic)
        model.restoreVisibility(resume: true)
        XCTAssertEqual(model.focusMode, .off); XCTAssertEqual(model.visualRestrictionsStatus, .active)
        model.closed()
    }

    func testAutomaticBaselinesThenEmphasizesAllHighAndRemainsArmedAtZeroCues() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30)
        let rows = [a,b,c], high: Set<GhosttySurfaceID> = [a.id,b.id], focus = controller(MockTimerScheduler())
        focus.enableAutomatic(rows: rows, high: high, coverage: [a.id: attention(a,"baseline")])
        XCTAssertEqual(focus.mode, .automatic); XCTAssertTrue(focus.attentionCues.isEmpty)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        clock.advance(by: 1)
        let first = attention(a,"first")
        focus.acceptCatalogue(rows, high: high, coverage: [a.id: first]); awaitManual(focus); _ = try read(2)
        let target = try XCTUnwrap(state.captureTarget(for: c))
        let old = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        for index in 0...1 {
            var ready = pollfd(fd: ptys[index].master, events: Int16(POLLIN), revents: 0)
            XCTAssertEqual(poll(&ready, 1, 20), 0)
        }
        focus.acknowledge(focus.cueSnapshot(for: a.id), for: a.id)
        XCTAssertEqual(try read(2), Data("\u{1B}]111\u{1B}\\".utf8))
        XCTAssertEqual(focus.mode, .automatic); XCTAssertTrue(focus.attentionCues.isEmpty)
        focus.acceptCatalogue(rows, high: high, coverage: [a.id: first])
        XCTAssertTrue(focus.attentionCues.isEmpty)
        clock.advance(by: 1)
        focus.acceptCatalogue(rows, high: high, coverage: [a.id: attention(a,"second")])
        awaitManual(focus); _ = try read(2)
        let next = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertNotEqual(next.effectID, old.effectID)
        focus.focusOff(); _ = try read(2)
    }

    func testAcknowledgingOneAutomaticTargetPreservesOtherCuesAndDimming() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30), focus = controller(MockTimerScheduler())
        let rows = [a,b,c], high: Set<GhosttySurfaceID> = [a.id,b.id]
        focus.enableAutomatic(rows: rows, high: high, coverage: [:]); clock.advance(by: 1)
        focus.acceptCatalogue(rows, high: high, coverage: [a.id: attention(a,"one"), b.id: attention(b,"two")])
        awaitManual(focus); _ = try read(2)
        focus.acknowledge(focus.cueSnapshot(for: a.id), for: a.id)
        XCTAssertEqual(focus.attentionCues.count, 1)
        var ready = pollfd(fd: ptys[2].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.acknowledge(focus.cueSnapshot(for: b.id), for: b.id)
        _ = try read(2); XCTAssertEqual(focus.mode, .automatic)
    }

    func testAutomaticHighPromotionClearsThatTargetsPreviousDimming() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30), focus = controller(MockTimerScheduler())
        let rows = [a,b,c]
        focus.enableAutomatic(rows: rows, high: [a.id], coverage: [:]); clock.advance(by: 1)
        let coverage = [a.id: attention(a,"cue")]
        focus.acceptCatalogue(rows, high: [a.id], coverage: coverage); awaitManual(focus)
        _ = try read(1); _ = try read(2)
        focus.acceptCatalogue(rows, high: [a.id,c.id], coverage: coverage); awaitManual(focus)
        XCTAssertEqual(try read(2), Data("\u{1B}]111\u{1B}\\".utf8))
        _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: c))
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max)).active)
        XCTAssertEqual(focus.attentionCues.count, 1)
        focus.focusOff(); _ = try read(1)
    }

    func testLastAutomaticAcknowledgementInvalidatesBlockedPaintWithoutDisarming() throws {
        let a = try surface(10), b = try surface(20), queue = DispatchQueue(label: "blocked.automatic")
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let focus = controller(MockTimerScheduler(), queue: queue, colors: { _ in
            entered.signal(); release.wait()
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer { release.signal() }
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); clock.advance(by: 1)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: attention(a,"cue")])
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        focus.acknowledge(focus.cueSnapshot(for: a.id), for: a.id); release.signal()
        let drained = expectation(description: "Canceled automatic worker returned")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }; wait(for: [drained], timeout: 2)
        XCTAssertEqual(focus.mode, .automatic); XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.focusOff()
    }

    func testArmedAutomaticRejectsRecoveryReplacementAndSwitchesExplicitlyToManual() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:])
        try restrictions.write(suspended: true); try restrictions.write(suspended: false)
        clock.advance(by: 1)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: attention(a,"cue")])
        XCTAssertEqual(focus.mode, .off); XCTAssertTrue(focus.attentionCues.isEmpty)
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:])
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(focus.workingSet, [a.id])
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); _ = try read(1)
        XCTAssertEqual(focus.mode, .automatic); XCTAssertTrue(focus.workingSet.isEmpty)
        focus.cancelForRecovery(); XCTAssertEqual(focus.mode, .off)
    }

    func testExitedCueProducerCannotAuthorizePaintThroughAnotherHighShell() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30)
        let device = try XCTUnwrap(identities[10]).device
        identities[15] = ProcessIdentity(generation: generation(15), parentPID: 1,
            group: 15, device: device, foregroundGroup: 10)
        identities[10] = ProcessIdentity(generation: generation(10), parentPID: 15,
            group: 10, device: device, foregroundGroup: 10)
        let binding = try XCTUnwrap(state.captureTarget(for: a))
        XCTAssertEqual(binding.ttyOwner, generation(15))
        let queue = DispatchQueue(label: "automatic.producer-exit")
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let focus = controller(MockTimerScheduler(), queue: queue, colors: { _ in
            entered.signal(); release.wait()
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer { release.signal() }
        focus.enableAutomatic(rows: [a,b,c], high: [a.id,b.id], coverage: [:]); clock.advance(by: 1)
        focus.acceptCatalogue([a,b,c], high: [a.id,b.id], coverage: [a.id: attention(a,"cue")])
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        identities.removeValue(forKey: 10)
        missingProcesses.insert(10)
        XCTAssertEqual(state.validateTarget(binding), .valid)
        release.signal()
        let drained = expectation(description: "Cue source checked after lookup")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }; wait(for: [drained], timeout: 2)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        XCTAssertTrue(focus.attentionCues.isEmpty)
        XCTAssertNil(focus.focusCleanupError)
        var ready = pollfd(fd: ptys[2].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.focusOff()
    }

    func testUnavailableCueSourceRetainsSnapshotAndCannotAuthorizeDimming() throws {
        let a = try surface(10), b = try surface(20)
        let producer = ProcessIdentity(generation: generation(11), parentPID: 10,
            group: 10, device: identities[10]!.device, foregroundGroup: 10)
        identities[11] = producer
        let focus = controller(MockTimerScheduler())
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); clock.advance(by: 1)
        let sample = attention(a,"cue", producer: 11)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: sample]); awaitManual(focus)
        _ = try read(1)
        let captured = focus.cueSnapshot(for: a.id)
        identities[11] = nil
        clock.advance(by: 2)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [:]); awaitManual(focus)
        XCTAssertEqual(focus.cueSnapshot(for: a.id), captured)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        identities[11] = producer
        clock.advance(by: 2)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: sample]); awaitManual(focus)
        XCTAssertEqual(focus.cueSnapshot(for: a.id), captured)
        _ = try read(1)
        focus.focusOff(); _ = try read(1)
    }

    func testAllHighCatalogueResolvesOnlyConfirmedExitedCueWithoutDeviceFanout() throws {
        let a = try surface(10), b = try surface(20)
        for (pid,owner) in [(Int32(11),Int32(10)),(Int32(21),Int32(20))] {
            identities[pid] = ProcessIdentity(generation: generation(pid), parentPID: UInt32(owner),
                group: UInt32(owner), device: identities[owner]!.device, foregroundGroup: UInt32(owner))
        }
        let queue = DispatchQueue(label: "automatic.all-high")
        let focus = controller(MockTimerScheduler(), queue: queue)
        focus.enableAutomatic(rows: [a,b], high: [a.id,b.id], coverage: [:]); clock.advance(by: 1)
        let first = attention(a,"one", producer: 11), second = attention(b,"two", producer: 21)
        focus.acceptCatalogue([a,b], high: [a.id,b.id], coverage: [a.id: first,b.id: second]); awaitManual(focus)
        let retained = focus.cueSnapshot(for: b.id)
        identities[11] = nil; missingProcesses.insert(11); identities[21] = nil
        clock.advance(by: 2)
        focus.acceptCatalogue([a,b], high: [a.id,b.id], coverage: [a.id: first,b.id: second])
        let drained = expectation(description: "All-High source checks and resolution returned")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }; wait(for: [drained], timeout: 2)
        XCTAssertTrue(focus.cueSnapshot(for: a.id).isEmpty)
        XCTAssertEqual(focus.cueSnapshot(for: b.id), retained)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        for tty in ptys {
            var ready = pollfd(fd: tty.master, events: Int16(POLLIN), revents: 0)
            XCTAssertEqual(poll(&ready, 1, 20), 0)
        }
        focus.focusOff()
        let finished = expectation(description: "Unknown retained source worker drained")
        queue.async { DispatchQueue.main.async { finished.fulfill() } }; wait(for: [finished], timeout: 2)
    }

    func testRejectedFinalSourceChecksCannotRenewHeartbeatOrReuseExpiredEffect() throws {
        let a = try surface(10), b = try surface(20)
        identities[11] = ProcessIdentity(generation: generation(11), parentPID: 10,
            group: 10, device: identities[10]!.device, foregroundGroup: 10)
        var rejectFinal = false, inspections = 0
        configureState(lookup: { pid in
            if pid == 11 {
                inspections += 1
                if rejectFinal && inspections > 1 { return nil }
            }
            return self.identities[pid]
        })
        let focus = controller(MockTimerScheduler())
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); clock.advance(by: 1)
        let sample = attention(a,"cue", producer: 11)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: sample]); awaitManual(focus)
        _ = try read(1)
        let captured = focus.cueSnapshot(for: a.id), target = try XCTUnwrap(state.captureTarget(for: b))
        let original = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        rejectFinal = true
        for _ in 1...3 {
            inspections = 0; clock.advance(by: 2)
            focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: sample]); awaitManual(focus)
            XCTAssertEqual(focus.cueSnapshot(for: a.id), captured)
            XCTAssertTrue(focus.focusStatus.contains("unavailable"))
            XCTAssertEqual(try state.currentEffectUnlocked(target, kind: .focus, deadline: .max), original)
            var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
            XCTAssertEqual(poll(&ready, 1, 20), 0)
        }
        rejectFinal = false; inspections = 0; clock.advance(by: 2)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: sample]); awaitManual(focus)
        let fresh = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertNotEqual(fresh.effectID, original.effectID)
        XCTAssertEqual(fresh.heartbeatAt, clock.now().timeIntervalSince1970)
        XCTAssertEqual(focus.cueSnapshot(for: a.id), captured)
        XCTAssertTrue(focus.focusStatus.contains("0 failed"))
        _ = try read(1); focus.focusOff(); _ = try read(1)
    }

    func testMixedCueSourcesRemoveOnlyKnownExitAndContinueThroughAnotherValidSource() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30), d = try surface(40)
        for owner: Int32 in [10,20,30] {
            identities[owner+1] = ProcessIdentity(generation: generation(owner+1), parentPID: UInt32(owner),
                group: UInt32(owner), device: identities[owner]!.device, foregroundGroup: UInt32(owner))
        }
        let focus = controller(MockTimerScheduler()), rows = [a,b,c,d], high: Set = [a.id,b.id,c.id]
        focus.enableAutomatic(rows: rows, high: high, coverage: [:]); clock.advance(by: 1)
        let coverage = [a.id: attention(a,"one", producer: 11), b.id: attention(b,"two", producer: 21),
            c.id: attention(c,"three", producer: 31)]
        focus.acceptCatalogue(rows, high: high, coverage: coverage); awaitManual(focus); _ = try read(3)
        let second = focus.cueSnapshot(for: b.id), third = focus.cueSnapshot(for: c.id)
        identities[11] = nil; missingProcesses.insert(11); identities[21] = nil
        clock.advance(by: 2)
        focus.acceptCatalogue(rows, high: high, coverage: coverage); awaitManual(focus)
        XCTAssertTrue(focus.cueSnapshot(for: a.id).isEmpty)
        XCTAssertEqual(focus.cueSnapshot(for: b.id), second)
        XCTAssertEqual(focus.cueSnapshot(for: c.id), third)
        _ = try read(3)
        focus.acknowledge(third, for: c.id); awaitManual(focus)
        XCTAssertEqual(focus.cueSnapshot(for: b.id), second)
        var ready = pollfd(fd: ptys[3].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.focusOff(); _ = try read(3)
    }

    func testInspectionDeadlineStillResolvesAlreadyProvenExitAndRetainsOtherCue() throws {
        let a = try surface(10), b = try surface(20)
        for owner: Int32 in [10,20] {
            identities[owner+1] = ProcessIdentity(generation: generation(owner+1), parentPID: UInt32(owner),
                group: UInt32(owner), device: identities[owner]!.device, foregroundGroup: UInt32(owner))
        }
        var exited: Int32?, expired = false
        configureState(lookup: { pid in
            if pid == 11 || pid == 21 {
                if exited == nil {
                    exited = pid; self.missingProcesses.insert(pid); return nil
                }
                if pid == exited { return nil }
                if !expired { expired = true; Thread.sleep(forTimeInterval: 0.11) }
            }
            return self.identities[pid]
        })
        let queue = DispatchQueue(label: "automatic.partial-deadline"), focus = controller(MockTimerScheduler(), queue: queue)
        focus.enableAutomatic(rows: [a,b], high: [a.id,b.id], coverage: [:]); clock.advance(by: 1)
        let resolved = expectation(description: "Only previously proven exit was resolved")
        focus.$attentionCues.first { $0.count == 1 }.sink { _ in resolved.fulfill() }.store(in: &subscriptions)
        focus.acceptCatalogue([a,b], high: [a.id,b.id], coverage: [a.id: attention(a,"one", producer: 11),
            b.id: attention(b,"two", producer: 21)])
        wait(for: [resolved], timeout: 2)
        XCTAssertTrue(expired)
        let dead = exited == 11 ? a : b, retained = exited == 11 ? b : a
        XCTAssertTrue(focus.cueSnapshot(for: dead.id).isEmpty)
        XCTAssertEqual(focus.cueSnapshot(for: retained.id).count, 1)
        focus.focusOff()
        let drained = expectation(description: "Deadline and follow-up workers drained")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }; wait(for: [drained], timeout: 2)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
    }

    func testGlobalMaskedFocusRenewsItsMetadataWithoutRotatingTheEffect() throws {
        let a = try surface(10), b = try surface(20)
        let (runner, trace) = recordedWriter(try XCTUnwrap(state.captureTarget(for: b)))
        configureState(runner: runner)
        let focus = controller(MockTimerScheduler())
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); clock.advance(by: 1)
        let sample = attention(a,"cue")
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: sample]); awaitManual(focus)
        XCTAssertTrue(trace().contains { $0.contains("caller returned true") },
                      focus.focusStatus + "\n" + trace().joined(separator: "\n"))
        _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        let original = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        try "MUTED=\"true\"\nREASON=\"quiet_period\"\nUNTIL_EPOCH=\"0\"\nWRITTEN_EPOCH=\"1001\"\nAPP_PID=\"\(getpid())\"\nSCHEMA_VERSION=\"1\"\n"
            .write(to: root.appendingPathComponent("mute.state"), atomically: true, encoding: .utf8)
        for _ in 1...4 {
            clock.advance(by: 2)
            focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: sample]); awaitManual(focus)
            let renewed = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
            XCTAssertEqual(renewed.effectID, original.effectID)
            XCTAssertEqual(renewed.heartbeatAt, clock.now().timeIntervalSince1970)
            var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
            XCTAssertEqual(poll(&ready, 1, 20), 0)
        }
        try "MUTED=\"false\"\nSCHEMA_VERSION=\"1\"\n".write(to: root.appendingPathComponent("mute.state"),
            atomically: true, encoding: .utf8)
        clock.advance(by: 2)
        let releaseTraceStart = trace().count
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: sample]); awaitManual(focus)
        XCTAssertTrue(trace().dropFirst(releaseTraceStart).contains { $0.contains("caller returned true") },
                      focus.focusStatus + "\n" + trace().joined(separator: "\n"))
        XCTAssertEqual(try state.currentEffectUnlocked(target, kind: .focus, deadline: .max)?.effectID, original.effectID)
        XCTAssertEqual(try state.currentEffectUnlocked(target, kind: .focus, deadline: .max)?.heartbeatAt,
                       clock.now().timeIntervalSince1970, trace().joined(separator: "\n"))
        _ = try read(1)
        let cleared = expectation(description: "Masked focus cleanup completed")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [cleared], timeout: 2); _ = try read(1)
    }

    func testFocusOffDuringFinalCueMetadataCheckPreventsLatePaint() throws {
        let a = try surface(10), b = try surface(20), device = try XCTUnwrap(identities[10]).device
        identities[11] = ProcessIdentity(generation: generation(11), parentPID: 10,
            group: 10, device: device, foregroundGroup: 10)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        var inspections = 0
        state = TerminalVisualStateStore(runtimeDirectory: root, clock: clock, lookup: { pid in
            if pid == 11 {
                inspections += 1
                if inspections == 3 { entered.signal(); release.wait() }
            }
            return self.identities[pid]
        })
        recovery = VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: VisualRestrictionPolicy(restrictions: restrictions, muteURL: root.appendingPathComponent("mute.state"),
                lockURL: root.appendingPathComponent("lock.state"), clock: clock),
            processRunner: SystemProcessRunner(), clock: clock, controller: generation(90), nativeSnapshot: { [] })
        let queue = DispatchQueue(label: "automatic.final-source-check"), focus = controller(MockTimerScheduler(), queue: queue)
        defer { release.signal() }
        focus.enableAutomatic(rows: [a,b], high: [a.id], coverage: [:]); clock.advance(by: 1)
        var value = try XCTUnwrap(attention(a,"cue").observation); value.producer = generation(11)
        focus.acceptCatalogue([a,b], high: [a.id], coverage: [a.id: TerminalVisualCoverage(
            observation: value, intent: nil, attentionEligible: true, status: "Verified child producer")])
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        let cleared = expectation(description: "Focus Off cleanup completed")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); release.signal()
        let drained = expectation(description: "Final producer check returned")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }; wait(for: [drained,cleared], timeout: 2)
        XCTAssertEqual(focus.mode, .off)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testHealthyPreviewClearDoesNotWaitForUnrelatedFocusCleanup() throws {
        let a = try surface(10), b = try surface(20)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let runner = MockProcessRunner()
        runner.managedBeforeOpenHandler = { path, lock, beforeOpen, afterWrite, prepare in
            if path == b.tty && beforeOpen != nil { entered.signal(); release.wait() }
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock,
                beforeOpen: beforeOpen, afterWrite: afterWrite, prepare: prepare)
        }
        recovery = VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: VisualRestrictionPolicy(restrictions: restrictions, muteURL: root.appendingPathComponent("mute.state"),
                lockURL: root.appendingPathComponent("lock.state"), clock: clock),
            processRunner: runner, clock: clock, controller: generation(90), nativeSnapshot: { [] })
        let focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let focusCleared = expectation(description: "Blocked focus cleanup drained")
        focus.$focusCleanupError.dropFirst().first().sink { _ in focusCleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff()
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        focus.preview([a]); awaitPaint(focus, count: 1); _ = try read(0)
        let previewCleared = expectation(description: "Healthy preview clears before unrelated focus is released")
        focus.$cleanupError.dropFirst().first().sink { _ in previewCleared.fulfill() }.store(in: &subscriptions)
        focus.clearPreview()
        wait(for: [previewCleared], timeout: 0.5)
        release.signal()
        wait(for: [focusCleared], timeout: 2)
        XCTAssertEqual(try read(0), Data("\u{1B}]111\u{1B}\\".utf8))
        XCTAssertEqual(try read(1), Data("\u{1B}]111\u{1B}\\".utf8))
        let target = try XCTUnwrap(state.captureTarget(for: a))
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max)).active)
    }

    func testManualCapturedSetIsIndependentOfPreviewAndClearsLatestIntent() throws {
        let a = try surface(10), b = try surface(20)
        let expectedTarget = try XCTUnwrap(state.captureTarget(for: b))
        let (runner, trace) = recordedWriter(expectedTarget)
        configureState(runner: runner)
        let focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus)
        XCTAssertTrue(trace().contains { $0.contains("caller returned true") },
                      focus.focusStatus + "\n" + trace().joined(separator: "\n"))
        XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(focus.workingSet, [a.id])
        _ = try read(1)
        focus.preview([b]); awaitPaint(focus, count: 1); _ = try read(1)
        XCTAssertEqual(focus.workingSet, [a.id])
        let previewCleared = expectation(description: "Preview cleanup completed")
        focus.$cleanupError.dropFirst().first().sink { _ in previewCleared.fulfill() }.store(in: &subscriptions)
        focus.clearPreview(); wait(for: [previewCleared], timeout: 2); _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        try recovery.write(.ordinary(OrdinaryBackgroundIntent(tty: target.tty, device: target.device,
            producer: target.ttyOwner, deliveryID: "updated", updatedAt: 1_000, background: "#AA2200"),
            synthetic: false, intakeAt: 1_000), to: target)
        _ = try read(1)
        let focusCleared = expectation(description: "Manual cleanup completed")
        focus.$focusCleanupError.dropFirst().first().sink { _ in focusCleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [focusCleared], timeout: 2)
        XCTAssertEqual(focus.mode, .off); XCTAssertTrue(focus.workingSet.isEmpty)
        XCTAssertEqual(try read(1), Data("\u{1B}]11;#AA2200\u{1B}\\".utf8))
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testManualRefreshesChangedColorsOncePerUpdateAndRetainsUnchangedLeaseIDs() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30), rows = [a,b,c]
        let guardLock = NSLock()
        let dark = TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        let light = TerminalRenderer.Colors(background: "#FAFAFA", foreground: "#161616")!
        var pair = dark, calls = 0
        let focus = controller(MockTimerScheduler(), colors: { _ in
            guardLock.lock(); defer { guardLock.unlock() }
            calls += 1; return pair
        })
        let targets = try [b,c].map { try XCTUnwrap(state.captureTarget(for: $0)) }
        focus.focusSelected([a], catalogue: rows); awaitManual(focus)
        _ = try read(1); _ = try read(2)
        let old = try targets.map { try XCTUnwrap(state.currentEffectUnlocked($0, kind: .focus, deadline: .max)) }
        guardLock.lock(); pair = light; guardLock.unlock()
        clock.advance(by: 2); focus.acceptCatalogue(rows); awaitManual(focus)
        var changed: [TerminalEffectRecord] = []
        for (index, target) in targets.enumerated() {
            let current = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
            changed.append(current)
            XCTAssertEqual(current.focusColors, light)
            XCTAssertNotEqual(current.effectID, old[index].effectID)
            let bytes = try read(index + 1)
            let paint = Data("\u{1B}]11;#F1F1F1\u{1B}\\".utf8)
            XCTAssertEqual(bytes.suffix(paint.count), paint)
            XCTAssertNil(bytes.range(of: Data("\u{1B}]10;".utf8)))
            XCTAssertNil(bytes.range(of: Data("\u{1B}]104".utf8)))
        }
        XCTAssertGreaterThanOrEqual(PauseVisual.contrastRatio("#F1F1F1", light.foreground), 4.5)
        XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(focus.workingSet, [a.id])
        clock.advance(by: 2); focus.acceptCatalogue(rows); awaitManual(focus)
        for (index, target) in targets.enumerated() {
            XCTAssertEqual(try state.currentEffectUnlocked(target, kind: .focus, deadline: .max)?.effectID,
                changed[index].effectID)
            XCTAssertEqual(try read(index + 1), Data("\u{1B}]11;#F1F1F1\u{1B}\\".utf8))
        }
        guardLock.lock(); let count = calls; guardLock.unlock()
        XCTAssertEqual(count, 3)
        focus.focusOff(); _ = try read(1); _ = try read(2)
    }

    func testAutomaticRefreshesColorsUnderGlobalMaskWithoutLosingTheCue() throws {
        let a = try surface(10), b = try surface(20), rows = [a,b], high: Set<GhosttySurfaceID> = [a.id]
        let guardLock = NSLock(), light = TerminalRenderer.Colors(background: "#FAFAFA", foreground: "#161616")!
        var pair = TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!, calls = 0
        let focus = controller(MockTimerScheduler(), colors: { _ in
            guardLock.lock(); defer { guardLock.unlock() }
            calls += 1; return pair
        })
        focus.enableAutomatic(rows: rows, high: high, coverage: [:]); clock.advance(by: 1)
        let sample = attention(a,"cue"), target = try XCTUnwrap(state.captureTarget(for: b))
        focus.acceptCatalogue(rows, high: high, coverage: [a.id: sample]); awaitManual(focus); _ = try read(1)
        let original = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        let cues = focus.cueSnapshot(for: a.id)
        try "MUTED=\"true\"\nREASON=\"quiet_period\"\nUNTIL_EPOCH=\"0\"\nWRITTEN_EPOCH=\"1001\"\nAPP_PID=\"\(getpid())\"\nPAUSE_BG=\"#223344\"\nSCHEMA_VERSION=\"1\"\n"
            .write(to: root.appendingPathComponent("mute.state"), atomically: true, encoding: .utf8)
        guardLock.lock(); pair = light; guardLock.unlock()
        clock.advance(by: 2); focus.acceptCatalogue(rows, high: high, coverage: [a.id: sample]); awaitManual(focus)
        let current = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertEqual(current.focusColors, light); XCTAssertNotEqual(current.effectID, original.effectID)
        XCTAssertEqual(focus.mode, .automatic); XCTAssertEqual(focus.cueSnapshot(for: a.id), cues)
        XCTAssertEqual(try read(1), Data("\u{1B}]11;#223344\u{1B}\\".utf8))
        try "MUTED=\"false\"\nSCHEMA_VERSION=\"1\"\n".write(to: root.appendingPathComponent("mute.state"),
            atomically: true, encoding: .utf8)
        clock.advance(by: 2); focus.acceptCatalogue(rows, high: high, coverage: [a.id: sample]); awaitManual(focus)
        XCTAssertEqual(try read(1), Data("\u{1B}]11;#F1F1F1\u{1B}\\".utf8))
        XCTAssertEqual(try state.currentEffectUnlocked(target, kind: .focus, deadline: .max)?.effectID, current.effectID)
        guardLock.lock(); let count = calls; guardLock.unlock(); XCTAssertEqual(count, 3)
        focus.focusOff(); _ = try read(1)
    }

    func testUnavailableRenewalColorsClearOldFocusAndRecoverWithoutChangingTheWorkingSet() throws {
        let a = try surface(10), b = try surface(20), rows = [a,b], guardLock = NSLock()
        let light = TerminalRenderer.Colors(background: "#FAFAFA", foreground: "#161616")!
        var unavailable = false, pair = TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        var calls = 0
        let focus = controller(MockTimerScheduler(), colors: { _ in
            guardLock.lock(); defer { guardLock.unlock() }
            calls += 1
            if unavailable { throw TerminalConfigurationError.unresolvedAppearance }
            return pair
        })
        focus.focusSelected([a], catalogue: rows); awaitManual(focus); _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        let old = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        guardLock.lock(); unavailable = true; guardLock.unlock()
        clock.advance(by: 2); focus.acceptCatalogue(rows); awaitManual(focus)
        XCTAssertTrue(focus.focusStatus.contains("unavailable"))
        XCTAssertEqual(try read(1), Data("\u{1B}]111\u{1B}\\".utf8))
        let inactive = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        guardLock.lock(); let count = calls; guardLock.unlock()
        XCTAssertEqual(count, 2)
        XCTAssertEqual(inactive.effectID, old.effectID)
        XCTAssertFalse(inactive.active)
        XCTAssertEqual(inactive.heartbeatAt, old.heartbeatAt)
        XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(focus.workingSet, [a.id])
        guardLock.lock(); unavailable = false; pair = light; guardLock.unlock()
        clock.advance(by: 2); focus.acceptCatalogue(rows); awaitManual(focus)
        let replacement = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertNotEqual(replacement.effectID, old.effectID); XCTAssertEqual(replacement.focusColors, light)
        let paint = Data("\u{1B}]11;#F1F1F1\u{1B}\\".utf8), bytes = try read(1)
        XCTAssertEqual(bytes.suffix(paint.count), paint)
        focus.focusOff(); _ = try read(1)
    }

    func testFocusOffDuringBlockedRenewalColorLookupPreventsLatePaint() throws {
        let a = try surface(10), b = try surface(20), queue = DispatchQueue(label: "blocked.renewal.colors")
        let guardLock = NSLock(), entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        var calls = 0
        let focus = controller(MockTimerScheduler(), queue: queue, colors: { _ in
            guardLock.lock(); calls += 1; let second = calls == 2; guardLock.unlock()
            if second { entered.signal(); release.wait() }
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer { release.signal() }
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        let original = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        clock.advance(by: 2); focus.acceptCatalogue([a,b])
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        focus.focusOff(); XCTAssertEqual(try read(1), Data("\u{1B}]111\u{1B}\\".utf8)); release.signal()
        let drained = expectation(description: "Cancelled renewal preparation drained")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }
        wait(for: [drained], timeout: 2)
        let effect = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertEqual(effect.effectID, original.effectID); XCTAssertFalse(effect.active)
        XCTAssertEqual(effect.heartbeatAt, original.heartbeatAt)
        XCTAssertEqual(focus.mode, .off); XCTAssertTrue(focus.workingSet.isEmpty)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testUnchangedManualPollsDoNotStarveSlowPreparationAndUseFreshHeartbeat() throws {
        try unchangedPollsDuringSlowFocus(automatic: false)
    }

    func testUnchangedAutomaticPollsRetainCueAndDoNotStarveSlowPreparation() throws {
        try unchangedPollsDuringSlowFocus(automatic: true)
    }

    func testNewAutomaticCueStillInvalidatesBlockedPreparationOnIdenticalSurfaces() throws {
        try unchangedPollsDuringSlowFocus(automatic: true, changingCue: true)
    }

    func testForegroundProcessChangeStillInvalidatesBlockedPreparationWithSameSurfaceCount() throws {
        try unchangedPollsDuringSlowFocus(automatic: false, changingForeground: true)
    }

    private func unchangedPollsDuringSlowFocus(automatic: Bool, changingCue: Bool = false,
                                             changingForeground: Bool = false) throws {
        let a = try surface(10), b = try surface(20), rows = [a,b]
        let target = try XCTUnwrap(state.captureTarget(for: b)), (runner, trace) = recordedWriter(target)
        configureState(runner: runner)
        let queue = DispatchQueue(label: "slow.focus.polls"), guardLock = NSLock()
        let firstEntered = DispatchSemaphore(value: 0), releaseFirst = DispatchSemaphore(value: 0)
        let secondEntered = expectation(description: "Coalesced next lookup held")
        let releaseSecond = DispatchSemaphore(value: 0)
        var queries = 0
        let focus = controller(MockTimerScheduler(), queue: queue, colors: { _ in
            guardLock.lock(); queries += 1; let call = queries; guardLock.unlock()
            if call == 1 { firstEntered.signal(); releaseFirst.wait() }
            if call == 2 { secondEntered.fulfill(); releaseSecond.wait() }
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer { releaseFirst.signal(); releaseSecond.signal() }
        var coverage: [GhosttySurfaceID: TerminalVisualCoverage]
        if automatic {
            focus.enableAutomatic(rows: rows, high: [a.id], coverage: [:]); clock.advance(by: 1)
            coverage = [a.id: attention(a,"slow-cue")]
            focus.acceptCatalogue(rows, high: [a.id], coverage: coverage)
        } else {
            coverage = [:]; focus.focusSelected([a], catalogue: rows)
        }
        XCTAssertEqual(firstEntered.wait(timeout: .now() + 1), .success)
        let initialCues = focus.cueSnapshot(for: a.id)
        var displayedRows = rows
        for tick in 1...4 {
            clock.advance(by: 2)
            if changingForeground && tick == 1 {
                identities[21] = ProcessIdentity(generation: generation(21), parentPID: 1,
                    group: 21, device: identities[20]!.device, foregroundGroup: 21)
            }
            displayedRows[1] = GhosttySurface(id: b.id, windowID: b.windowID, tabID: b.tabID,
                title: "spinner \(tick)", directory: b.directory, tty: b.tty,
                foregroundPID: changingForeground ? 21 : b.foregroundPID,
                tabSelected: b.tabSelected, mappingIssue: b.mappingIssue)
            if changingCue && tick == 1 { coverage[a.id] = attention(a,"new-cue") }
            focus.acceptCatalogue(displayedRows, high: automatic ? [a.id] : [], coverage: coverage)
        }
        let finishedAt = clock.now().timeIntervalSince1970
        releaseFirst.signal(); wait(for: [secondEntered], timeout: 2)
        let first = try state.currentEffectUnlocked(target, kind: .focus, deadline: .max)
        if changingCue || changingForeground { XCTAssertNil(first, "Changed input failed to invalidate old preparation") }
        else { XCTAssertNotNil(first, "Unchanged polling discarded the completed preparation\n" + trace().joined(separator: "\n")) }
        if let first = first {
            XCTAssertTrue(first.active); XCTAssertEqual(first.heartbeatAt, finishedAt)
            _ = try read(1)
        }
        XCTAssertEqual(focus.mode, automatic ? .automatic : .manual)
        if changingCue { XCTAssertNotEqual(focus.cueSnapshot(for: a.id), initialCues) }
        else { XCTAssertEqual(focus.cueSnapshot(for: a.id), initialCues) }
        if !automatic { XCTAssertEqual(focus.workingSet, [a.id]) }
        releaseSecond.signal(); awaitManual(focus); _ = try read(1)
        let cleared = expectation(description: "Coalescing fixture cleanup returned")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [cleared], timeout: 2)
        XCTAssertEqual(try read(1), Data("\u{1B}]111\u{1B}\\".utf8))
    }

    func testSlowPreparationCannotPaintWithoutFreshCatalogueCoverage() throws {
        let a = try surface(10), b = try surface(20)
        let focus = controller(MockTimerScheduler(), colors: { _ in
            self.clock.advance(by: 7)
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus)
        XCTAssertTrue(focus.focusStatus.contains("unavailable"))
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(focus.workingSet, [a.id])
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        let cleared = expectation(description: "Unpainted stale lease cleanup finished")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [cleared], timeout: 2)
    }

    func testNewOutsideSurfaceAndConfirmedLastClosureEndManualFocus() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let c = try surface(30)
        focus.acceptCatalogue([a,b,c]); awaitManual(focus); _ = try read(1); _ = try read(2)
        XCTAssertEqual(focus.workingSet, [a.id])
        let cleared = expectation(description: "Closed working set's focus cleanup finished")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.acceptCatalogue([b,c])
        XCTAssertEqual(focus.mode, .off)
        _ = try read(1)
        XCTAssertEqual(try read(2), Data("\u{1B}]111\u{1B}\\".utf8))
        wait(for: [cleared], timeout: 2)
    }

    func testFailedTargetRetirementKeepsHealthyIdentityAndBoundsRetries() throws {
        let a = try surface(10), h = try surface(20), f = try surface(30)
        let guardLock = NSLock(), runner = MockProcessRunner()
        var failing = false, failedClears = 0
        runner.managedBeforeOpenHandler = { path, lock, beforeOpen, afterWrite, prepare in
            guardLock.lock()
            let reject = failing && path == f.tty
            if reject && beforeOpen != nil { failedClears += 1 }
            guardLock.unlock()
            if reject { throw ProcessRunnerError.deviceNotWritable(path) }
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock,
                beforeOpen: beforeOpen, afterWrite: afterWrite, prepare: prepare)
        }
        recovery = VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: VisualRestrictionPolicy(restrictions: restrictions, muteURL: root.appendingPathComponent("mute.state"),
                lockURL: root.appendingPathComponent("lock.state"), clock: clock),
            processRunner: runner, clock: clock, controller: generation(90), nativeSnapshot: { [] })
        let focus = controller(MockTimerScheduler()), rows = [a,h,f]
        defer {
            guardLock.lock(); failing = false; guardLock.unlock()
            if focus.mode != .off {
                let done = expectation(description: "Failed test's owned cleanup drained")
                focus.$focusCleanupError.dropFirst().first().sink { _ in done.fulfill() }.store(in: &subscriptions)
                focus.focusOff(); wait(for: [done], timeout: 2)
            }
        }
        focus.focusSelected([a], catalogue: rows); awaitManual(focus); _ = try read(1); _ = try read(2)
        let healthy = try XCTUnwrap(state.captureTarget(for: h)), failed = try XCTUnwrap(state.captureTarget(for: f))
        let h0 = try XCTUnwrap(state.currentEffectUnlocked(healthy, kind: .focus, deadline: .max))
        let f0 = try XCTUnwrap(state.currentEffectUnlocked(failed, kind: .focus, deadline: .max))
        guardLock.lock(); failing = true; guardLock.unlock()
        for _ in 1...12 {
            clock.advance(by: 2); focus.acceptCatalogue(rows); awaitManual(focus); _ = try read(1)
            let current = try XCTUnwrap(state.currentEffectUnlocked(healthy, kind: .focus, deadline: .max))
            XCTAssertEqual(current.effectID, h0.effectID)
            XCTAssertEqual(current.heartbeatAt, clock.now().timeIntervalSince1970)
            XCTAssertEqual(try state.currentEffectUnlocked(failed, kind: .focus, deadline: .max), f0)
        }
        guardLock.lock(); let attempts = failedClears; failing = false; guardLock.unlock()
        XCTAssertLessThanOrEqual(attempts, 9)
        clock.advance(by: 2); focus.acceptCatalogue(rows); awaitManual(focus)
        _ = try read(1); _ = try read(2)
        let recovered = try XCTUnwrap(state.currentEffectUnlocked(failed, kind: .focus, deadline: .max))
        XCTAssertNotEqual(recovered.effectID, f0.effectID)
        XCTAssertEqual(recovered.heartbeatAt, clock.now().timeIntervalSince1970)
        XCTAssertEqual(try state.currentEffectUnlocked(healthy, kind: .focus, deadline: .max)?.effectID, h0.effectID)
        XCTAssertEqual(focus.workingSet, [a.id])
        focus.focusOff(); _ = try read(1); _ = try read(2)
    }

    func testRepeatedModeChangesCannotReplaceUnresolvedTargetOwnership() throws {
        let a = try surface(10), h = try surface(20), f = try surface(30)
        let runner = MockProcessRunner(), guardLock = NSLock()
        var failing = false, newFocusAttempts = 0
        runner.managedBeforeOpenHandler = { path, lock, beforeOpen, afterWrite, prepare in
            guardLock.lock()
            let reject = failing && path == f.tty
            if reject && beforeOpen == nil { newFocusAttempts += 1 }
            guardLock.unlock()
            if reject { throw ProcessRunnerError.deviceNotWritable(path) }
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock,
                beforeOpen: beforeOpen, afterWrite: afterWrite, prepare: prepare)
        }
        configureState(runner: runner)
        let focus = controller(MockTimerScheduler()), rows = [a,h,f]
        defer {
            guardLock.lock(); failing = false; guardLock.unlock()
            if focus.mode != .off {
                let done = expectation(description: "Owned mode-change cleanup drained")
                focus.$focusCleanupError.dropFirst().first().sink { _ in done.fulfill() }.store(in: &subscriptions)
                focus.focusOff(); wait(for: [done], timeout: 2)
            }
        }
        focus.focusSelected([a], catalogue: rows); awaitManual(focus); _ = try read(1); _ = try read(2)
        let target = try XCTUnwrap(state.captureTarget(for: f))
        let original = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        guardLock.lock(); failing = true; guardLock.unlock()
        for _ in 0..<6 {
            clock.advance(by: 2); focus.focusSelected([a], catalogue: rows); awaitManual(focus)
            _ = try read(1)
            XCTAssertEqual(try state.currentEffectUnlocked(target, kind: .focus, deadline: .max), original)
        }
        guardLock.lock(); let attempts = newFocusAttempts; failing = false; guardLock.unlock()
        XCTAssertEqual(attempts, 0)
        clock.advance(by: 2); focus.acceptCatalogue(rows); awaitManual(focus); _ = try read(1); _ = try read(2)
        let fresh = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertNotEqual(fresh.effectID, original.effectID)
        XCTAssertEqual(fresh.heartbeatAt, clock.now().timeIntervalSince1970)
        XCTAssertEqual(focus.workingSet, [a.id])
        focus.focusOff(); _ = try read(1); _ = try read(2)
    }

    func testCatalogueFailureRetainsLogicalSetAndExpiredOwnershipGetsANewID() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        let old = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        focus.catalogueUnavailable()
        XCTAssertEqual(focus.workingSet, [a.id]); XCTAssertEqual(focus.mode, .manual)
        clock.advance(by: 10)
        focus.acceptCatalogue([a,b]); awaitManual(focus); _ = try read(1)
        let next = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertNotEqual(next.effectID, old.effectID)
        XCTAssertEqual(next.heartbeatAt, 1_010)
        focus.focusOff(); _ = try read(1)
    }

    func testNoVerifiedWorkingBindingCannotDimTheWholeCatalogue() throws {
        var a = try surface(10); a.mappingIssue = .missingTTY
        let b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus)
        XCTAssertEqual(focus.workingSet, [a.id])
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.focusOff()
    }

    func testUnmappedOutsideSurfaceCannotKeepAnExpiredPaintIDFresh() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        let old = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        var unavailable = b; unavailable.mappingIssue = .missingTTY
        for _ in 0..<4 {
            clock.advance(by: 2); focus.acceptCatalogue([a,unavailable]); awaitManual(focus)
        }
        clock.advance(by: 2); focus.acceptCatalogue([a,b]); awaitManual(focus)
        let next = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertNotEqual(next.effectID, old.effectID)
        XCTAssertTrue(state.isSelectiveLeaseActive(next))
        let cleared = expectation(description: "Renewed focus cleanup completed before fixture removal")
        focus.$focusCleanupError.dropFirst().first { $0 == nil }
            .sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [cleared], timeout: 2)
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max)).active)
    }

    func testRecoveryEndsManualWithoutPaintingAndRestartStartsOff() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        focus.cancelForRecovery()
        XCTAssertEqual(focus.mode, .off); XCTAssertTrue(focus.workingSet.isEmpty)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        XCTAssertFalse(recovery.recover().hasFailures); _ = try read(1)
        let restarted = controller(MockTimerScheduler())
        XCTAssertEqual(restarted.mode, .off)
        restarted.focusSelected([a], catalogue: [a,b])
        XCTAssertEqual(restarted.mode, .off)
    }

    func testSessionsConfirmedRecoveryRetiresOldFocusBeforeResumeAndRefocus() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([a,b])) }, navigate: { _, _ in },
            visualRestrictionsState: restrictions, focus: focus, recover: { resume, done in
                done(.success(self.recovery.recover(resume: resume)))
            })
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let recovered = expectation(description: "Physical recovery report accepted")
        model.$recovering.dropFirst().first { !$0 }.sink { _ in recovered.fulfill() }.store(in: &subscriptions)
        model.restoreVisibility(); wait(for: [recovered], timeout: 2)
        XCTAssertEqual(try read(1), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{07}".utf8))
        let noFailure = expectation(description: "Confirmed restoration needs no old lease retry")
        noFailure.isInverted = true
        focus.$focusCleanupError.first { $0 != nil }.sink { _ in noFailure.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [noFailure], timeout: 0.2)
        XCTAssertNil(focus.focusCleanupError)
        let resumed = expectation(description: "Explicit resumption accepted")
        model.$recovering.dropFirst().first { !$0 }.sink { _ in resumed.fulfill() }.store(in: &subscriptions)
        model.restoreVisibility(resume: true); wait(for: [resumed], timeout: 2); _ = try read(1)
        focus.focusSelected([b], catalogue: [a,b]); awaitManual(focus); _ = try read(0)
        XCTAssertEqual(focus.workingSet, [b.id]); XCTAssertNil(focus.focusCleanupError)
        var unchanged = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&unchanged, 1, 20), 0)
        let cleared = expectation(description: "Fresh focus cleanup completed")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [cleared], timeout: 2); _ = try read(0)
        XCTAssertNil(focus.focusCleanupError)
    }

    func testSessionsPartialRecoveryRetainsFailedFocusUntilConfirmedRetry() throws {
        let a = try surface(10), healthy = try surface(20), failed = try surface(30), guardLock = NSLock()
        var reject = false, opens: [String] = []
        configureState(runner: SystemProcessRunner(openDevice: { path, flags in
            guardLock.lock(); opens.append(path); let unavailable = reject && path == failed.tty; guardLock.unlock()
            if unavailable { errno = EACCES; return -1 }
            return Darwin.open(path, flags)
        }))
        let focus = controller(MockTimerScheduler()), rows = [a,healthy,failed]
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success(rows)) }, navigate: { _, _ in },
            visualRestrictionsState: restrictions, focus: focus, recover: { resume, done in
                done(.success(self.recovery.recover(resume: resume)))
            })
        focus.focusSelected([a], catalogue: rows); awaitManual(focus); _ = try read(1); _ = try read(2)
        guardLock.lock(); reject = true; guardLock.unlock()
        let recovered = expectation(description: "Partial physical recovery accepted")
        model.$recovering.dropFirst().first { !$0 }.sink { _ in recovered.fulfill() }.store(in: &subscriptions)
        model.restoreVisibility(); wait(for: [recovered], timeout: 2); _ = try read(1)
        XCTAssertTrue(try XCTUnwrap(model.recoveryStatus).contains("1 failed"))
        guardLock.lock(); opens.removeAll(); guardLock.unlock()
        let incomplete = expectation(description: "Failed target still needs physical cleanup")
        focus.$focusCleanupError.dropFirst().first().sink { _ in incomplete.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [incomplete], timeout: 2)
        XCTAssertNotNil(focus.focusCleanupError)
        guardLock.lock(); let retryPaths = opens; reject = false; guardLock.unlock()
        XCTAssertEqual(retryPaths, [failed.tty!])
        let retried = expectation(description: "Previously failed recovery confirmed")
        model.$recovering.dropFirst().first { !$0 }.sink { _ in retried.fulfill() }.store(in: &subscriptions)
        model.restoreVisibility(); wait(for: [retried], timeout: 2); _ = try read(1); _ = try read(2)
        XCTAssertNil(focus.focusCleanupError)
        let noFailure = expectation(description: "Confirmed retry releases remaining old lease")
        noFailure.isInverted = true
        focus.$focusCleanupError.first { $0 != nil }.sink { _ in noFailure.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [noFailure], timeout: 0.2)
        XCTAssertNil(focus.focusCleanupError)
    }

    func testSessionsUnconfirmedRecoveryReportCannotReleasePaintedFocus() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        let target = try XCTUnwrap(state.captureTarget(for: b))
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([a,b])) }, navigate: { _, _ in },
            visualRestrictionsState: restrictions, focus: focus, recover: { _, done in
                do { try self.restrictions.write(suspended: true) }
                catch { done(.failure(error)); return }
                done(.success(VisualRecoveryReport(stateSaved: true, catalogueAvailable: false,
                    items: [VisualRecoveryItem(target: target, tty: target.tty, status: .unaffected)])))
            })
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let recovered = expectation(description: "Unconfirmed report displayed")
        model.$recovering.dropFirst().first { !$0 }.sink { _ in recovered.fulfill() }.store(in: &subscriptions)
        model.restoreVisibility(); wait(for: [recovered], timeout: 2)
        let incomplete = expectation(description: "Unconfirmed paint obligation retained")
        focus.$focusCleanupError.dropFirst().first().sink { _ in incomplete.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [incomplete], timeout: 2)
        XCTAssertNotNil(focus.focusCleanupError)
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testRecoveryConfirmationRejectsMissingConflictingAndUnpersistedOutcomes() throws {
        let a = try surface(10), b = try surface(20), other = try surface(30)
        let focus = controller(MockTimerScheduler()), target = try XCTUnwrap(state.captureTarget(for: b))
        let otherTarget = try XCTUnwrap(state.captureTarget(for: other))
        let reused = TerminalTargetBinding(tty: target.tty, device: target.device,
            ttyOwner: generation(40), nativeSurface: target.nativeSurface)
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let confirm = focus.cancelForRecovery()
        try restrictions.write(suspended: true)
        let restored = VisualRecoveryItem(target: target, tty: target.tty, status: .restored)
        let failed = VisualRecoveryItem(target: target, tty: target.tty, status: .failed)
        let reports = [
            VisualRecoveryReport(stateSaved: false, catalogueAvailable: true, items: [restored]),
            VisualRecoveryReport(stateSaved: true, catalogueAvailable: false, items: []),
            VisualRecoveryReport(stateSaved: true, catalogueAvailable: true, items: [restored,failed]),
            VisualRecoveryReport(stateSaved: true, catalogueAvailable: true,
                items: [VisualRecoveryItem(tty: target.tty, status: .restored)]),
            VisualRecoveryReport(stateSaved: true, catalogueAvailable: true,
                items: [VisualRecoveryItem(target: otherTarget, tty: target.tty, status: .restored)]),
            VisualRecoveryReport(stateSaved: true, catalogueAvailable: true,
                items: [VisualRecoveryItem(target: reused, tty: target.tty, status: .restored)])
        ]
        for report in reports {
            confirm(report)
            let retained = expectation(description: "Unconfirmed outcome retains exact painted lease")
            focus.$focusCleanupError.dropFirst().first().sink { _ in retained.fulfill() }.store(in: &subscriptions)
            focus.focusOff(); wait(for: [retained], timeout: 2)
            XCTAssertNotNil(focus.focusCleanupError)
        }
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testLateRecoveryConfirmationCannotReleaseAReplacementFocusLease() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        let target = try XCTUnwrap(state.captureTarget(for: b))
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let original = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        let confirm = focus.cancelForRecovery(), report = recovery.recover(); _ = try read(1)
        XCTAssertFalse(report.hasFailures)
        try restrictions.write(suspended: false)
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let replacement = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        XCTAssertNotEqual(replacement.effectID, original.effectID)
        confirm(report)
        XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(focus.workingSet, [a.id])
        XCTAssertTrue(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max)).active)
        let cleared = expectation(description: "Replacement lease still owns its cleanup")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [cleared], timeout: 2)
        XCTAssertNil(focus.focusCleanupError)
        XCTAssertEqual(try read(1), Data("\u{1B}]111\u{1B}\\".utf8))
    }

    func testConfirmedRecoveryDoesNotOverwriteFreshOrdinaryOutput() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        let target = try XCTUnwrap(state.captureTarget(for: b))
        var completion: ((Result<VisualRecoveryReport, Error>) -> Void)?
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([a,b])) }, navigate: { _, _ in },
            visualRestrictionsState: restrictions, focus: focus, recover: { _, done in completion = done })
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        model.restoreVisibility()
        let report = recovery.recover(); XCTAssertFalse(report.hasFailures); _ = try read(1)
        clock.advance(by: 1)
        try recovery.write(.ordinary(OrdinaryBackgroundIntent(tty: target.tty, device: target.device,
            producer: target.ttyOwner, deliveryID: "fresh", updatedAt: 1_001, background: "#ABCDEF"),
            synthetic: false, intakeAt: 1_001), to: target)
        XCTAssertEqual(try read(1), Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
        let recovered = expectation(description: "Delayed recovery confirmation accepted")
        model.$recovering.dropFirst().first { !$0 }.sink { _ in recovered.fulfill() }.store(in: &subscriptions)
        completion?(.success(report)); wait(for: [recovered], timeout: 2)
        let noFailure = expectation(description: "Settled lease cannot attempt another reset")
        noFailure.isInverted = true
        focus.$focusCleanupError.first { $0 != nil }.sink { _ in noFailure.fulfill() }.store(in: &subscriptions)
        focus.focusOff(); wait(for: [noFailure], timeout: 0.2)
        XCTAssertNil(focus.focusCleanupError)
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#ABCDEF")
        var ready = pollfd(fd: ptys[1].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testConfirmedVanishedTargetReleasesCanceledFocusLease() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let confirm = focus.cancelForRecovery()
        close(ptys[1].master); close(ptys[1].slave)
        ptys[1] = (-1, -1, ptys[1].path)
        identities.removeValue(forKey: 20); missingProcesses.insert(20)
        let report = recovery.recover()
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(report.items.map(\.status), [.vanished])
        confirm(report); XCTAssertNil(focus.focusCleanupError)
        focus.focusOff(); XCTAssertNil(focus.focusCleanupError)
    }

    func testCatalogueFailureInvalidatesBlockedAndCoalescedManualUpdates() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30)
        let queue = DispatchQueue(label: "blocked.manual")
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        var first = true
        let focus = controller(MockTimerScheduler(), queue: queue, colors: { _ in
            if first { first = false; entered.signal(); release.wait() }
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer { release.signal() }
        focus.focusSelected([a], catalogue: [a,b])
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        focus.acceptCatalogue([a,b,c]); focus.catalogueUnavailable(); release.signal()
        let drained = expectation(description: "Invalidated manual worker returned")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }
        wait(for: [drained], timeout: 2)
        XCTAssertEqual(focus.workingSet, [a.id]); XCTAssertEqual(focus.mode, .manual)
        XCTAssertTrue(focus.focusStatus.contains("stale"))
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        for index in 1...2 {
            var ready = pollfd(fd: ptys[index].master, events: Int16(POLLIN), revents: 0)
            XCTAssertEqual(poll(&ready, 1, 20), 0)
        }
        focus.acceptCatalogue([a,b,c]); awaitManual(focus)
        _ = try read(1); _ = try read(2)
        focus.focusOff(); _ = try read(1); _ = try read(2)
    }

    func testSessionsKeepOneCatalogueTimerThroughManualWindowCloseAndBrowsing() throws {
        let a = try surface(10), b = try surface(20), timers = MockTimerScheduler()
        let focus = controller(MockTimerScheduler())
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([a,b])) }, navigate: { _, _ in XCTFail("Focus must not navigate") },
            timerScheduler: timers, clock: clock, visualRestrictionsState: restrictions, focus: focus)
        model.opened(); model.selection = [a.id]; awaitPaint(focus, count: 1); _ = try read(0)
        model.clearPreview(); _ = try read(0)
        model.focusSelected(); awaitManual(focus); _ = try read(1)
        XCTAssertEqual(timers.scheduledTimers.count, 1)
        model.selection = [b.id]; awaitPaint(focus, count: 1); _ = try read(1)
        model.setPriority(.high, for: [b.id])
        XCTAssertEqual(focus.workingSet, [a.id])
        model.closed(); _ = try read(1)
        XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(timers.scheduledTimers.count, 1)
        clock.advance(by: 2); timers.fireAll(); _ = try read(1)
        model.opened()
        XCTAssertEqual(timers.scheduledTimers.count, 1)
        model.closed(); model.focusOff(); _ = try read(1)
        XCTAssertTrue(timers.scheduledTimers.isEmpty)
        XCTAssertEqual(model.selection, [b.id])
    }

    func testSessionsExternalRecoveryEndsManualAndCannotResumeIt() throws {
        let a = try surface(10), b = try surface(20), timers = MockTimerScheduler()
        let focus = controller(MockTimerScheduler())
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([a,b])) }, navigate: { _, _ in },
            timerScheduler: timers, visualRestrictionsState: restrictions, focus: focus)
        model.opened(); model.selection = [a.id]; awaitPaint(focus, count: 1); _ = try read(0)
        model.clearPreview(); _ = try read(0)
        model.focusSelected(); awaitManual(focus); _ = try read(1)
        let cleared = expectation(description: "External recovery cleanup completed")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        try restrictions.write(suspended: true); model.refresh()
        XCTAssertEqual(focus.mode, .off)
        wait(for: [cleared], timeout: 2)
        model.focusSelected(); XCTAssertEqual(focus.mode, .off)
        try restrictions.write(suspended: false); model.refresh()
        XCTAssertEqual(focus.mode, .off)
        model.closed()
    }

    func testMultiselectionUsesOneExpiryAndClearOnlyResetsBackground() throws {
        let rows = [try surface(10), try surface(20)], timers = MockTimerScheduler(), focus = controller(timers)
        focus.preview(rows); awaitPaint(focus, count: 2)
        XCTAssertEqual(timers.scheduledTimers.count, 1)
        XCTAssertEqual(timers.scheduledTimers.first?.delay, 2)
        XCTAssertFalse(try XCTUnwrap(timers.scheduledTimers.first).repeating)
        for index in 0..<2 { XCTAssertTrue(String(decoding: try read(index), as: UTF8.self).hasPrefix("\u{1B}]11;")) }
        focus.clearPreview()
        XCTAssertFalse(focus.isPreviewActive)
        for index in 0..<2 { XCTAssertEqual(try read(index), Data("\u{1B}]111\u{1B}\\".utf8)) }
    }

    func testSlowColorPreparationDoesNotConsumeTheTwoSecondPreviewLease() throws {
        let rows = [try surface(10), try surface(20)], timers = MockTimerScheduler()
        var queries = 0
        let focus = controller(timers, colors: { _ in
            queries += 1; self.clock.advance(by: 3)
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        focus.preview(rows); awaitPaint(focus, count: 2)
        XCTAssertEqual(queries, 1)
        XCTAssertEqual(timers.scheduledTimers.count, 1)
        XCTAssertEqual(timers.scheduledTimers.first?.delay, 2)
        let target = try XCTUnwrap(state.captureTarget(for: rows[0]))
        let effect = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max))
        XCTAssertEqual(effect.heartbeatAt, 1_003)
        for index in 0..<2 { _ = try read(index) }
        clock.advance(by: 1.9)
        XCTAssertTrue(state.isSelectiveLeaseActive(effect))
        clock.advance(by: 0.1); timers.fireAll()
        XCTAssertFalse(focus.isPreviewActive)
        for index in 0..<2 { XCTAssertEqual(try read(index), Data("\u{1B}]111\u{1B}\\".utf8)) }
    }

    func testSelectionWaitingBehindSlowPreparationPaintsOnlyTheLatestRows() throws {
        let first = try surface(10), skipped = try surface(20), latest = try surface(30)
        let timers = MockTimerScheduler(), queue = DispatchQueue(label: "preview.preparation-replacement")
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        var queries = 0
        let focus = controller(timers, queue: queue, colors: { _ in
            queries += 1
            if queries == 1 { entered.signal(); release.wait() }
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer { release.signal() }
        focus.preview([first]); XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        XCTAssertTrue(timers.scheduledTimers.isEmpty)
        focus.preview([skipped]); focus.preview([latest])
        clock.advance(by: 3); release.signal()
        awaitPaint(focus, count: 1)
        XCTAssertEqual(focus.previewed, [latest.id])
        XCTAssertEqual(queries, 2)
        XCTAssertEqual(timers.scheduledTimers.count, 1)
        for index in 0..<2 {
            var ready = pollfd(fd: ptys[index].master, events: Int16(POLLIN), revents: 0)
            XCTAssertEqual(poll(&ready, 1, 20), 0)
        }
        _ = try read(2)
        focus.clearPreview(); _ = try read(2)
    }

    func testFailedColorPreparationReportsUnavailableWithoutAnExpiryOrPaint() throws {
        let row = try surface(10), timers = MockTimerScheduler()
        let focus = controller(timers, colors: { _ in
            self.clock.advance(by: 3)
            throw TerminalConfigurationError.unresolvedAppearance
        })
        let failed = expectation(description: "Preparation failure is visible")
        focus.$previewStatus.first { $0.contains("dual-theme") }
            .sink { _ in failed.fulfill() }.store(in: &subscriptions)
        focus.preview([row]); wait(for: [failed], timeout: 1)
        XCTAssertFalse(focus.isPreviewActive)
        XCTAssertTrue(timers.scheduledTimers.isEmpty)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.clearPreview()
    }

    func testLatePreviewTimerSchedulingUsesTheRemainingDisplayLifetime() throws {
        let row = try surface(10), timers = MockTimerScheduler()
        let entered = DispatchSemaphore(value: 0), advance = DispatchSemaphore(value: 1)
        let target = try XCTUnwrap(state.captureTarget(for: row))
        let (runner, trace) = recordedWriter(target, openDevice: { path, flags in
            if advance.wait(timeout: .now()) == .success {
                self.clock.advance(by: 1.25); entered.signal()
            }
            return Darwin.open(path, flags)
        })
        configureState(runner: runner)
        let focus = controller(timers)
        focus.preview([row])
        // Keep main-queue timer setup pending until the writer has consumed part of the lease.
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        awaitPaint(focus, count: 1)
        XCTAssertTrue(trace().contains { $0.contains("caller returned true") },
                      focus.previewStatus + "\n" + trace().joined(separator: "\n"))
        _ = try read(0)
        XCTAssertEqual(try XCTUnwrap(timers.scheduledTimers.first).delay, 0.75, accuracy: 0.001)
        let cleared = expectation(description: "Expired preview cleanup completed")
        focus.$cleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        clock.advance(by: 0.75); timers.fireAll(); wait(for: [cleared], timeout: 2)
        XCTAssertFalse(focus.isPreviewActive)
        XCTAssertEqual(try read(0), Data("\u{1B}]111\u{1B}\\".utf8))
    }

    func testExpiredPreparedStartStillSchedulesCleanupWithoutPainting() throws {
        let row = try surface(10), timers = MockTimerScheduler()
        let queue = DispatchQueue(label: "preview.expired-start")
        let delayedClock = PreviewExpiryBoundaryClock(clock)
        let focus = FocusController(state: state, recovery: recovery, restrictions: restrictions,
            timers: timers, clock: delayedClock, queue: queue, nativeSnapshot: { [row] }, colors: { _ in
                TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
            })
        focus.preview([row])
        let drained = expectation(description: "Expired start and main-queue timer setup returned")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }
        wait(for: [drained], timeout: 1)
        XCTAssertEqual(try XCTUnwrap(timers.scheduledTimers.first).delay, 0)
        timers.fireAll()
        XCTAssertFalse(focus.isPreviewActive)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testExpiryRestoresIntentChangedDuringPreview() throws {
        let row = try surface(10), timers = MockTimerScheduler(), focus = controller(timers)
        focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        let target = try XCTUnwrap(state.captureTarget(for: row))
        clock.advance(by: 1)
        try recovery.write(.ordinary(OrdinaryBackgroundIntent(tty: target.tty, device: target.device,
            producer: target.ttyOwner, deliveryID: "new", updatedAt: 1_001, background: "#ABCDEF"),
            synthetic: false, intakeAt: 1_001), to: target)
        _ = try read(0)
        clock.advance(by: 1); timers.fireAll()
        XCTAssertFalse(focus.isPreviewActive)
        XCTAssertEqual(try read(0), Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
    }

    func testOldTimerCannotClearRestartedPreview() throws {
        let row = try surface(10), timers = MockTimerScheduler(), focus = controller(timers)
        focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        let oldHandler = try XCTUnwrap(timers.scheduledTimers.first?.handler)
        clock.advance(by: 1); focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        oldHandler()
        XCTAssertTrue(focus.isPreviewActive)
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.clearPreview(); _ = try read(0)
    }

    func testReplacementPreviewWaitsForItsOwnFiniteCleanupBeforeAdmission() throws {
        let row = try surface(10), target = try XCTUnwrap(state.captureTarget(for: row))
        let held = DispatchGroup(), pause = DispatchSemaphore(value: 0), lock = NSLock()
        held.enter()
        var opens = 0, busy = 0, queries = 0
        let native = SystemProcessRunner(openDevice: { path, flags in
            lock.lock(); opens += 1; let ordinal = opens; lock.unlock()
            if ordinal == 2 {
                held.leave()
                _ = pause.wait(timeout: .now() + .milliseconds(40))
            }
            return Darwin.open(path, flags)
        })
        let runner = MockProcessRunner()
        runner.managedBeforeOpenHandler = { path, outputLock, beforeOpen, afterWrite, prepare in
            do {
                return try native.writeManagedToDevice(path: path, lockURL: outputLock,
                    beforeOpen: beforeOpen, target: target.physicalTarget, afterWrite: afterWrite, prepare: prepare)
            } catch ProcessRunnerError.deviceIOFailed(_, EBUSY) {
                lock.lock(); busy += 1; lock.unlock()
                throw ProcessRunnerError.deviceIOFailed(path, EBUSY)
            }
        }
        configureState(runner: runner)
        let focus = controller(MockTimerScheduler(), colors: { _ in
            queries += 1
            if queries == 2 {
                XCTAssertEqual(held.wait(timeout: .now() + 1), .success)
            }
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        let old = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max))
        focus.preview([row]); awaitPaint(focus, count: 1)
        lock.lock(); let failures = busy; lock.unlock()
        XCTAssertEqual(failures, 0)
        let latest = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max))
        XCTAssertNotEqual(latest.effectID, old.effectID)
        XCTAssertTrue(latest.active)
        XCTAssertTrue(String(decoding: try read(0), as: UTF8.self).contains("\u{1B}]11;"))
        focus.clearPreview(); _ = try read(0)
    }

    func testSuccessivePreviewClearsDoNotBlockAnUnrelatedReplacement() throws {
        let a = try surface(10), b = try surface(20)
        let bTarget = try XCTUnwrap(state.captureTarget(for: b))
        let bindings = Dictionary(uniqueKeysWithValues: try [a,b].map {
            (try XCTUnwrap($0.tty), try XCTUnwrap(state.captureTarget(for: $0)).physicalTarget)
        })
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let runner = MockProcessRunner(), native = SystemProcessRunner(), lock = NSLock()
        var block = false
        runner.managedBeforeOpenHandler = { path, outputLock, beforeOpen, afterWrite, prepare in
            lock.lock(); let held = block && path == a.tty && beforeOpen != nil; lock.unlock()
            if held { entered.signal(); _ = release.wait(timeout: .now() + 3) }
            return try native.writeManagedToDevice(path: path, lockURL: outputLock,
                beforeOpen: beforeOpen, target: bindings[path], afterWrite: afterWrite, prepare: prepare)
        }
        configureState(runner: runner)
        let focus = controller(MockTimerScheduler())
        let cleared = expectation(description: "Both prior cleanup batches completed")
        cleared.expectedFulfillmentCount = 2
        focus.$cleanupError.dropFirst().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        defer { release.signal(); wait(for: [cleared], timeout: 2) }
        focus.preview([a]); awaitPaint(focus, count: 1); _ = try read(0)
        lock.lock(); block = true; lock.unlock()
        focus.preview([b]); XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        awaitPaint(focus, count: 1); _ = try read(1)
        let old = try XCTUnwrap(state.currentEffectUnlocked(bTarget, kind: .preview, deadline: .max))
        focus.preview([b]); awaitPaint(focus, count: 1)
        XCTAssertEqual(focus.previewed, [b.id])
        let latest = try XCTUnwrap(state.currentEffectUnlocked(bTarget, kind: .preview, deadline: .max))
        XCTAssertNotEqual(latest.effectID, old.effectID)
        XCTAssertTrue(latest.active)
        XCTAssertTrue(String(decoding: try read(1), as: UTF8.self).contains("\u{1B}]11;"))
    }

    func testCancelReplacementWaitingForPriorCleanupCannotPaintLate() throws {
        let row = try surface(10), target = try XCTUnwrap(state.captureTarget(for: row))
        let entered = DispatchGroup(), attempted = DispatchSemaphore(value: 0)
        entered.enter()
        let release = DispatchSemaphore(value: 0), lock = NSLock()
        let runner = MockProcessRunner(), native = SystemProcessRunner()
        var calls = 0, queries = 0
        runner.managedBeforeOpenHandler = { path, outputLock, beforeOpen, afterWrite, prepare in
            lock.lock(); calls += 1; let ordinal = calls; lock.unlock()
            if ordinal == 2 { entered.leave(); release.wait() }
            if ordinal == 3 { attempted.signal() }
            return try native.writeManagedToDevice(path: path, lockURL: outputLock,
                beforeOpen: beforeOpen, target: target.physicalTarget, afterWrite: afterWrite, prepare: prepare)
        }
        configureState(runner: runner)
        let queue = DispatchQueue(label: "preview.cancel-cleanup-wait")
        let clearQueue = DispatchQueue(label: "preview.cancel-clear", attributes: .concurrent)
        let focus = controller(MockTimerScheduler(), queue: queue, clearQueue: clearQueue, colors: { _ in
            queries += 1
            // Hold replacement preparation until the old cleanup owns the second call.
            if queries == 2, entered.wait(timeout: .now() + 1) != .success {
                throw VisualRecoveryError.targetUnavailable
            }
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer {
            focus.cancelForRecovery(); release.signal()
            let done = expectation(description: "Canceled preview and all queued cleanup returned")
            queue.async {
                clearQueue.async(flags: .barrier) { DispatchQueue.main.async { done.fulfill() } }
            }
            wait(for: [done], timeout: 2)
        }
        focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        let old = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max))
        focus.preview([row])
        guard entered.wait(timeout: .now() + 1) == .success else {
            XCTFail("Old cleanup did not enter"); return
        }
        guard attempted.wait(timeout: .now() + 1) == .success else {
            XCTFail("Replacement did not attempt its bounded wait"); return
        }
        focus.clearPreview(); release.signal()
        let drained = expectation(description: "Canceled replacement and main callbacks returned")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }
        wait(for: [drained], timeout: 2)
        XCTAssertFalse(focus.isPreviewActive)
        XCTAssertTrue(focus.previewed.isEmpty)
        XCTAssertEqual(try read(0), Data("\u{1B}]111\u{1B}\\".utf8))
        let remaining = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max))
        XCTAssertEqual(remaining.effectID, old.effectID)
        XCTAssertFalse(remaining.active)
    }

    func testTimedOutCleanupCannotHideItsOutstandingPredecessor() throws {
        let row = try surface(10), target = try XCTUnwrap(state.captureTarget(for: row))
        let entered = DispatchGroup(), release = DispatchSemaphore(value: 0)
        entered.enter()
        let lock = NSLock()
        let runner = MockProcessRunner(), native = SystemProcessRunner()
        var calls = 0, queries = 0
        runner.managedBeforeOpenHandler = { path, outputLock, beforeOpen, afterWrite, prepare in
            lock.lock(); calls += 1; let ordinal = calls; lock.unlock()
            if ordinal == 2 {
                entered.leave(); release.wait()
            }
            return try native.writeManagedToDevice(path: path, lockURL: outputLock,
                beforeOpen: beforeOpen, target: target.physicalTarget, afterWrite: afterWrite, prepare: prepare)
        }
        configureState(runner: runner)
        let queue = DispatchQueue(label: "preview.transitive-start")
        let clearQueue = DispatchQueue(label: "preview.transitive-clear", attributes: .concurrent)
        let focus = controller(MockTimerScheduler(), queue: queue, clearQueue: clearQueue, colors: { _ in
            queries += 1
            // Hold replacement preparation until the old cleanup owns the second call.
            if queries == 2, entered.wait(timeout: .now() + 1) != .success {
                throw VisualRecoveryError.targetUnavailable
            }
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer {
            focus.cancelForRecovery(); release.signal()
            let done = expectation(description: "Transitive preview and all queued cleanup returned")
            queue.async {
                clearQueue.async(flags: .barrier) { DispatchQueue.main.async { done.fulfill() } }
            }
            wait(for: [done], timeout: 2)
        }
        focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        let old = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max))
        let firstFailure = expectation(description: "Replacement reports its bounded predecessor wait")
        focus.$previewStatus.first { $0.contains("0 of 1") }
            .sink { _ in firstFailure.fulfill() }.store(in: &subscriptions)
        focus.preview([row])
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        guard XCTWaiter.wait(for: [firstFailure], timeout: 1) == .completed else {
            XCTFail("Replacement did not report its bounded predecessor wait"); return
        }
        let failedClear = expectation(description: "Newer cleanup reports its bounded predecessor wait")
        focus.$cleanupError.first { $0 != nil }
            .sink { _ in failedClear.fulfill() }.store(in: &subscriptions)
        focus.clearPreview()
        guard XCTWaiter.wait(for: [failedClear], timeout: 1) == .completed else {
            XCTFail("Newer cleanup did not report its bounded predecessor wait"); return
        }
        let retried = expectation(description: "Fresh selection reports its outcome")
        focus.$previewStatus.first { $0.contains("terminals previewed") }
            .sink { _ in retried.fulfill() }.store(in: &subscriptions)
        focus.preview([row])
        guard XCTWaiter.wait(for: [retried], timeout: 1) == .completed else {
            XCTFail("Fresh selection did not report its outcome"); return
        }
        XCTAssertTrue(focus.previewed.isEmpty)
        XCTAssertEqual(try state.currentEffectUnlocked(target, kind: .preview, deadline: .max)?.effectID, old.effectID)
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        release.signal()
        XCTAssertEqual(try read(0), Data("\u{1B}]111\u{1B}\\".utf8))
        focus.preview([row]); awaitPaint(focus, count: 1)
        XCTAssertNotEqual(try state.currentEffectUnlocked(target, kind: .preview, deadline: .max)?.effectID, old.effectID)
        _ = try read(0); focus.clearPreview(); _ = try read(0)
    }

    func testClearDuringBlockedColorLookupPreventsEveryQueuedPaint() throws {
        let row = try surface(10), timers = MockTimerScheduler(), queue = DispatchQueue(label: "blocked.preview")
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let focus = controller(timers, queue: queue, colors: { _ in
            entered.signal(); release.wait()
            return TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
        })
        defer { release.signal() }
        focus.preview([row]); XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        focus.clearPreview(); release.signal()
        let done = expectation(description: "Canceled lookup worker returned")
        queue.async { DispatchQueue.main.async { done.fulfill() } }; wait(for: [done], timeout: 1)
        XCTAssertFalse(focus.isPreviewActive)
        XCTAssertTrue(timers.scheduledTimers.isEmpty)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testRecoveryCancellationDoesNotRepaintBeforeIndependentReset() throws {
        let row = try surface(10), timers = MockTimerScheduler(), focus = controller(timers)
        focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        focus.cancelForRecovery()
        XCTAssertFalse(focus.isPreviewActive)
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        XCTAssertFalse(recovery.recover().hasFailures)
        XCTAssertEqual(try read(0), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{07}".utf8))
    }

    func testRecoveryRetainsPreviewRevisionUntilMetadataCleanupAfterReplacement() throws {
        let row = try surface(10), focus = controller(MockTimerScheduler())
        try restrictions.write(suspended: false)
        focus.preview([row]); awaitPaint(focus, count: 1); _ = try read(0)
        let target = try XCTUnwrap(state.captureTarget(for: row))
        let identity = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max)?.revision)
        focus.cancelForRecovery()
        for _ in 0..<8 {
            try restrictions.write(suspended: true); try restrictions.write(suspended: false)
            XCTAssertFalse(try restrictions.matches(identity, deadline: .max))
        }
        focus.clearPreview()
        let deadline = Date(timeIntervalSinceNow: 1)
        while Date() < deadline,
              try state.currentEffectUnlocked(target, kind: .preview, deadline: .max)?.active == true {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max)).active)
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testSessionsSelectionRefreshAndCloseUseSeparateTimerOwners() throws {
        let row = try surface(10), previewTimers = MockTimerScheduler(), catalogueTimers = MockTimerScheduler()
        let focus = controller(previewTimers)
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([row])) }, navigate: { _, _ in XCTFail("Selection must not navigate") },
            timerScheduler: catalogueTimers, visualRestrictionsState: restrictions, focus: focus)
        model.opened(); model.selection = [row.id]
        awaitPaint(focus, count: 1); _ = try read(0)
        let cancellations = previewTimers.cancelAllCallCount
        model.refresh(); model.setPriority(.high, for: [row.id])
        XCTAssertEqual(previewTimers.cancelAllCallCount, cancellations)
        XCTAssertEqual(catalogueTimers.scheduledTimers.count, 1)
        model.clearPreview(); XCTAssertEqual(model.selection, [row.id])
        XCTAssertEqual(try read(0), Data("\u{1B}]111\u{1B}\\".utf8))
        XCTAssertEqual(catalogueTimers.scheduledTimers.count, 1)
        model.closed(); XCTAssertTrue(catalogueTimers.scheduledTimers.isEmpty)
        XCTAssertTrue(previewTimers.scheduledTimers.isEmpty)
    }

    func testSessionsRecoveryCancelsWithoutPaintingAndPreservesPartialReport() throws {
        let row = try surface(10), focus = controller(MockTimerScheduler())
        var completion: ((Result<VisualRecoveryReport, Error>) -> Void)?
        let model = SessionsModel(prioritiesURL: root.appendingPathComponent("priorities.json"),
            refresh: { $0(.success([row])) }, navigate: { _, _ in XCTFail("Recovery must not navigate") },
            visualRestrictionsState: restrictions, focus: focus, recover: { resume, done in
                XCTAssertFalse(resume)
                completion = done
            })
        model.opened(); model.selection = [row.id]; awaitPaint(focus, count: 1); _ = try read(0)
        model.restoreVisibility()
        XCTAssertTrue(model.recovering)
        XCTAssertFalse(focus.isPreviewActive)
        XCTAssertEqual(model.selection, [row.id])
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        let done = expectation(description: "Recovery report displayed")
        model.$recovering.dropFirst().first { !$0 }.sink { _ in done.fulfill() }.store(in: &subscriptions)
        try restrictions.write(suspended: true)
        completion?(.success(VisualRecoveryReport(stateSaved: true, catalogueAvailable: false,
            items: [VisualRecoveryItem(status: .restored), VisualRecoveryItem(status: .failed, reason: "Unavailable target.")])))
        wait(for: [done], timeout: 1)
        XCTAssertEqual(model.visualRestrictionsStatus, .suspended)
        XCTAssertTrue(try XCTUnwrap(model.recoveryStatus).contains("1 failed"))
        XCTAssertTrue(try XCTUnwrap(model.recoveryStatus).contains("Native catalogue unavailable"))
    }
}

private final class PreviewExpiryBoundaryClock: Clock {
    private let clock: VirtualClock
    private let lock = NSLock()
    private var reads = 0
    init(_ clock: VirtualClock) { self.clock = clock }
    func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        reads += 1
        if reads == 2 { clock.advance(by: 3) }
        return clock.now()
    }
}
