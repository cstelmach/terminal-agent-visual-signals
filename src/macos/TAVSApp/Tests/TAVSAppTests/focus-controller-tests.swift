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
    private var ptys: [(master: Int32, slave: Int32, path: String)] = []
    private var subscriptions = Set<AnyCancellable>()
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
        state = TerminalVisualStateStore(runtimeDirectory: root, clock: clock, lookup: { self.identities[$0] })
        restrictions = VisualRestrictionsStateStore(url: root.appendingPathComponent("visual-restrictions.state"))
        recovery = VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: VisualRestrictionPolicy(restrictions: restrictions, muteURL: root.appendingPathComponent("mute.state"),
                lockURL: root.appendingPathComponent("lock.state"), clock: clock),
            processRunner: SystemProcessRunner(), clock: clock, controller: generation(90), nativeSnapshot: { [] })
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
        return GhosttySurface(id: GhosttySurfaceID(application: generation(80), terminalID: String(pid)),
            windowID: "window", tabID: "tab", title: "same", directory: "/same", tty: path,
            foregroundPID: pid, tabSelected: true, mappingIssue: nil)
    }

    private func controller(_ timers: MockTimerScheduler, queue: DispatchQueue = DispatchQueue(label: "test.preview"),
                            colors: ((ProcessGeneration) throws -> TerminalRenderer.Colors)? = nil) -> FocusController {
        FocusController(state: state, recovery: recovery, restrictions: restrictions, timers: timers,
            clock: clock, queue: queue, colors: colors ?? { _ in
                TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")!
            })
    }

    private func awaitPaint(_ controller: FocusController, count: Int) {
        let ready = expectation(description: "Selected targets painted")
        controller.$previewed.first { $0.count == count }.sink { _ in ready.fulfill() }.store(in: &subscriptions)
        wait(for: [ready], timeout: 1)
    }

    private func read(_ index: Int) throws -> Data {
        var descriptor = pollfd(fd: ptys[index].master, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 1_000) == 1 else { throw POSIXError(.ETIMEDOUT) }
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

    private func attention(_ row: GhosttySurface, _ delivery: String) -> TerminalVisualCoverage {
        TerminalVisualCoverage(observation: TerminalObservation(tty: row.tty!,
            device: identities[row.foregroundPID!]!.device, producer: generation(row.foregroundPID!),
            provider: "claude", verifiedAgent: true, state: "complete", event: "Stop",
            deliveryID: delivery, observedAt: clock.now().timeIntervalSince1970),
            intent: nil, attentionEligible: true, status: "Test correlated completion")
    }

    private func refreshAndWait(_ model: SessionsModel) {
        let ready = expectation(description: "Fresh catalogue and coverage accepted")
        model.$refreshing.dropFirst().first { !$0 }.sink { _ in ready.fulfill() }.store(in: &subscriptions)
        model.refresh(); wait(for: [ready], timeout: 2)
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
        let cleared = expectation(description: "Invalid source cleanup completed")
        focus.$focusCleanupError.dropFirst().first().sink { _ in cleared.fulfill() }.store(in: &subscriptions)
        identities.removeValue(forKey: 10)
        XCTAssertEqual(state.validateTarget(binding), .valid)
        release.signal()
        let drained = expectation(description: "Cue source checked after lookup")
        queue.async { DispatchQueue.main.async { drained.fulfill() } }; wait(for: [drained,cleared], timeout: 2)
        XCTAssertTrue(state.cachedRecords().effects.isEmpty)
        XCTAssertTrue(focus.attentionCues.isEmpty)
        var ready = pollfd(fd: ptys[2].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
        focus.focusOff()
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

    func testManualCapturedSetIsIndependentOfPreviewAndClearsLatestIntent() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus)
        XCTAssertEqual(focus.mode, .manual); XCTAssertEqual(focus.workingSet, [a.id])
        _ = try read(1)
        focus.preview([b]); awaitPaint(focus, count: 1); _ = try read(1)
        XCTAssertEqual(focus.workingSet, [a.id])
        focus.clearPreview(); _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        try recovery.write(.ordinary(OrdinaryBackgroundIntent(tty: target.tty, device: target.device,
            producer: target.ttyOwner, deliveryID: "updated", updatedAt: 1_000, background: "#AA2200"),
            synthetic: false, intakeAt: 1_000), to: target)
        _ = try read(1)
        focus.focusOff()
        XCTAssertEqual(focus.mode, .off); XCTAssertTrue(focus.workingSet.isEmpty)
        XCTAssertEqual(try read(1), Data("\u{1B}]11;#AA2200\u{1B}\\".utf8))
        var ready = pollfd(fd: ptys[0].master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 20), 0)
    }

    func testNewOutsideSurfaceAndConfirmedLastClosureEndManualFocus() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let c = try surface(30)
        focus.acceptCatalogue([a,b,c]); _ = try read(2)
        XCTAssertEqual(focus.workingSet, [a.id])
        focus.acceptCatalogue([b,c])
        XCTAssertEqual(focus.mode, .off)
        _ = try read(1)
        XCTAssertEqual(try read(2), Data("\u{1B}]111\u{1B}\\".utf8))
    }

    func testCatalogueFailureRetainsLogicalSetAndExpiredOwnershipGetsANewID() throws {
        let a = try surface(10), b = try surface(20), focus = controller(MockTimerScheduler())
        focus.focusSelected([a], catalogue: [a,b]); awaitManual(focus); _ = try read(1)
        let target = try XCTUnwrap(state.captureTarget(for: b))
        let old = try XCTUnwrap(state.currentEffectUnlocked(target, kind: .focus, deadline: .max))
        focus.catalogueUnavailable()
        XCTAssertEqual(focus.workingSet, [a.id]); XCTAssertEqual(focus.mode, .manual)
        clock.advance(by: 10)
        focus.acceptCatalogue([a,b]); _ = try read(1)
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
        focus.focusOff()
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

    func testCatalogueFailureInvalidatesBlockedAndCoalescedManualUpdates() throws {
        let a = try surface(10), b = try surface(20), c = try surface(30)
        let queue = DispatchQueue(label: "blocked.manual")
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let focus = controller(MockTimerScheduler(), queue: queue, colors: { _ in
            entered.signal(); release.wait()
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
        queue.async { done.fulfill() }; wait(for: [done], timeout: 1)
        XCTAssertFalse(focus.isPreviewActive)
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
