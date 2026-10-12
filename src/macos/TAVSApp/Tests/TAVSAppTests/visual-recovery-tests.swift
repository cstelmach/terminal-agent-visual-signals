import XCTest
import Darwin
@testable import TAVSApp

final class VisualRecoveryTests: XCTestCase {
    private var root: URL!
    private var restrictions: VisualRestrictionsStateStore!
    private var state: TerminalVisualStateStore!
    private var clock: VirtualClock!
    private var identities: [Int32: ProcessIdentity] = [:]
    private var devices: [String: UInt32] = [:]
    private var missing = Set<String>()
    private var missingProcesses = Set<Int32>()
    private var ptys: [(master: Int32, slave: Int32, path: String)] = []
    private let reset = Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{07}".utf8)

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"]))
            .appendingPathComponent("recovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("home"), withIntermediateDirectories: true)
        restrictions = VisualRestrictionsStateStore(url: root.appendingPathComponent("home/visual-restrictions.state"))
        clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
        state = TerminalVisualStateStore(runtimeDirectory: root, clock: clock,
            lookup: { self.identities[$0] },
            device: { self.missing.contains($0) ? nil : self.devices[$0] },
            deviceMissing: { self.missing.contains($0) }, processMissing: { self.missingProcesses.contains($0) })
        identities[80] = identity(80, device: UInt32.max)
        identities[90] = identity(90, device: UInt32.max)
    }

    override func tearDownWithError() throws {
        for tty in ptys { close(tty.master); close(tty.slave) }
        ptys = []
        try FileManager.default.removeItem(at: root)
    }

    private func generation(_ pid: Int32) -> ProcessGeneration {
        ProcessGeneration(pid: pid, startSeconds: 100, startMicroseconds: 1)
    }

    private func identity(_ pid: Int32, device: UInt32) -> ProcessIdentity {
        ProcessIdentity(generation: generation(pid), parentPID: 1, group: UInt32(pid),
                        device: device, foregroundGroup: UInt32(pid))
    }

    private func terminal(_ pid: Int32) throws -> TerminalTargetBinding {
        var master: Int32 = -1, slave: Int32 = -1
        var name = [CChar](repeating: 0, count: 1024)
        guard openpty(&master, &slave, &name, nil, nil) == 0 else { throw POSIXError(.EIO) }
        var attributes = termios()
        tcgetattr(slave, &attributes); cfmakeraw(&attributes); tcsetattr(slave, TCSANOW, &attributes)
        let path = String(cString: name)
        ptys.append((master, slave, path))
        let device = try XCTUnwrap(ProcessIdentity.deviceNumber(path))
        devices[path] = device
        identities[pid] = identity(pid, device: device)
        return try XCTUnwrap(state.captureTarget(tty: path, owner: generation(pid)))
    }

    private func cache(_ target: TerminalTargetBinding, effect: Bool = false) throws {
        _ = try SystemProcessRunner().writeManagedToDevice(path: target.tty,
            lockURL: state.lockURL(forTTY: target.tty)) { fd, deadline in
            XCTAssertEqual(self.state.validateTarget(target, descriptor: fd), .valid)
            try self.state.cacheTargetUnlocked(target, deadline: deadline)
            if effect {
                try self.state.saveEffectUnlocked(TerminalEffectRecord(target: target,
                    controller: self.generation(90), effectID: "old-effect", kind: .selectiveBackground,
                    background: "#AABBCC", heartbeatAt: 1_000), deadline: deadline)
            }
            return nil
        }
    }

    private func recovery(runner: ProcessRunner = SystemProcessRunner(),
                          allowed: Set<GhosttySurfaceID>? = nil,
                          native: @escaping () throws -> [GhosttySurface] = { [] }) -> VisualRecovery {
        let policy = VisualRestrictionPolicy(restrictions: restrictions,
            muteURL: root.appendingPathComponent("home/mute.state"), lockURL: root.appendingPathComponent("lock.state"),
            clock: clock, pidAlive: { $0 == 80 })
        return VisualRecovery(runtimeDirectory: root, restrictions: restrictions, state: state,
            policy: policy, processRunner: runner, clock: clock, controller: generation(90),
            allowedSurfaces: allowed, nativeSnapshot: native)
    }

    private func intent(_ target: TerminalTargetBinding, color: String = "#123456") -> OrdinaryBackgroundIntent {
        OrdinaryBackgroundIntent(tty: target.tty, device: target.device, producer: target.ttyOwner,
            deliveryID: "delivery-\(target.ttyOwner.pid)", updatedAt: clock.now().timeIntervalSince1970,
            background: color)
    }

    private func nativeAlias(_ plain: TerminalTargetBinding, id: String = "pane") -> TerminalTargetBinding {
        TerminalTargetBinding(tty: plain.tty, device: plain.device, ttyOwner: plain.ttyOwner,
            nativeSurface: GhosttySurfaceID(application: generation(80), terminalID: id))
    }

    private func pending(_ target: TerminalTargetBinding) -> URL {
        root.appendingPathComponent("pending/\(target.tty.replacingOccurrences(of: "/", with: "_")).osc")
    }

    private func render(background: String? = "#123456", title: String = "ORDINARY_TITLE") throws -> TerminalRender {
        var fields = [background ?? "", "set"] + ["#ABCDEF"] + Array(repeating: "", count: 15)
        fields += ["1", title, "iterm2-clear", "", "1"]
        return try TerminalRender(Data((fields.joined(separator: "\0") + "\0").utf8))
    }

    func testCompleteRenderUsesOneWriteAndCurrentSelectiveBackground() throws {
        let target = try terminal(10)
        try cache(target, effect: true)
        let style = try render()
        let result = try recovery().render(style, intent: intent(target), synthetic: false,
            intakeAt: 1_000, to: target)
        XCTAssertEqual(result, .rendered)
        var expected = style.beforeBackground
        expected.append(Data("\u{1B}]11;#AABBCC\u{1B}\\".utf8))
        expected.append(style.afterBackground(synthetic: false))
        XCTAssertEqual(try read(target), expected)
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#123456")
    }

    func testRestrictionActivatedDuringPrepareReplacesWholeOrdinaryRender() throws {
        let target = try terminal(10)
        let runner = MockProcessRunner()
        runner.managedBeforeOpenHandler = { path, lock, beforeOpen, prepare in
            try LockStateWriter.write(LockStateData(locked: true, reason: .manual, lockUntilEpoch: 1_500,
                unlockUntilEpoch: 0, writtenEpoch: 1_000, lockBg: "#667788", lockFg: "#EEEEFF"),
                to: self.root.appendingPathComponent("lock.state"))
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock,
                beforeOpen: beforeOpen, prepare: prepare)
        }
        XCTAssertEqual(try recovery(runner: runner).render(render(), intent: intent(target), synthetic: false,
            intakeAt: 1_000, to: target), .restricted)
        let bytes = try read(target), text = String(decoding: bytes, as: UTF8.self)
        XCTAssertTrue(text.contains("\u{1B}]10;#EEEEFF"))
        XCTAssertTrue(text.contains("\u{1B}]11;#667788"))
        XCTAssertFalse(text.contains("ORDINARY_TITLE"))
        XCTAssertFalse(text.contains("\u{1B}]4;"))
        XCTAssertFalse(text.contains("SetBackgroundImageFile=\u{07}\u{07}"))
    }

    func testStyleOnlyRenderDoesNotPublishBackgroundOrResetIt() throws {
        let target = try terminal(10), style = try render(background: nil)
        XCTAssertEqual(try recovery().render(style, intent: intent(target, color: "reset"), synthetic: false,
            intakeAt: 1_000, to: target), .rendered)
        var expected = style.beforeBackground; expected.append(style.afterBackground(synthetic: false))
        XCTAssertEqual(try read(target), expected)
        XCTAssertNil(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max))
    }

    func testStyleOnlyRenderDoesNotReadUnrequestedCorruptBackgroundIntent() throws {
        let target = try terminal(10)
        try state.publishIntent(intent(target))
        let files = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("organizer"),
            includingPropertiesForKeys: nil)
        let url = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("intent-") })
        try Data("invalid background record".utf8).write(to: url)
        let style = try render(background: nil)
        XCTAssertEqual(try recovery().render(style, intent: intent(target, color: "reset"), synthetic: false,
            intakeAt: 1_000, to: target), .rendered)
        var expected = style.beforeBackground; expected.append(style.afterBackground(synthetic: false))
        XCTAssertEqual(try read(target), expected)
        XCTAssertEqual(try String(contentsOf: url), "invalid background record")
    }

    func testSupersededSyntheticRenderRejectsEveryStyleAndIntent() throws {
        let target = try terminal(10), value = intent(target)
        try state.publishObservation(TerminalObservation(tty: target.tty, device: target.device,
            producer: target.ttyOwner, provider: "claude", verifiedAgent: false, state: "processing",
            event: nil, deliveryID: "newer", responseID: nil, observedAt: 1_000))
        XCTAssertThrowsError(try recovery().render(render(), intent: value, synthetic: true,
            intakeAt: 1_000, to: target))
        XCTAssertNil(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max))
        try noBytes(target)
    }

    func testFailedDeviceOpenRetainsOrdinaryColorAndResetWithoutClaimingPaint() throws {
        let target = try terminal(10)
        let failing = recovery(runner: SystemProcessRunner(openDevice: { _, _ in errno = EIO; return -1 }))
        for color in ["#ABCDEF", "reset"] {
            clock.advance(by: 1)
            XCTAssertThrowsError(try failing.write(.ordinary(intent(target, color: color),
                synthetic: false, intakeAt: clock.now().timeIntervalSince1970), to: target))
            XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), color)
            try noBytes(target)
            XCTAssertTrue(try recovery().write(.reconcile(resetLegacy: false, clearSelective: true), to: target))
            let expected = color == "reset" ? "\u{1B}]111\u{1B}\\" : "\u{1B}]11;\(color)\u{1B}\\"
            XCTAssertEqual(try read(target), Data(expected.utf8))
        }
    }

    func testRenderEntryFailureRetainsRequestedBackgroundButStyleOnlyLeavesItUntouched() throws {
        let target = try terminal(10)
        let failing = recovery(runner: SystemProcessRunner(openDevice: { _, _ in errno = EIO; return -1 }))
        XCTAssertThrowsError(try failing.render(render(background: "#654321"), intent: intent(target, color: "reset"),
            synthetic: false, intakeAt: 1_000, to: target))
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#654321")
        XCTAssertThrowsError(try failing.render(render(background: nil), intent: intent(target, color: "reset"),
            synthetic: false, intakeAt: 1_000, to: target))
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#654321")
        try noBytes(target)
    }

    func testStaleAndMalformedForcedResetCannotPrepublishBeforeDeviceFailure() throws {
        let target = try terminal(10)
        try recovery().write(.ordinary(intent(target, color: "#778899"), synthetic: false, intakeAt: 1_000), to: target)
        _ = try read(target)
        try state.publishObservation(TerminalObservation(tty: target.tty, device: target.device,
            producer: target.ttyOwner, provider: "claude", verifiedAgent: false, state: "processing",
            event: nil, deliveryID: "newer", responseID: nil, observedAt: 1_000))
        let failing = recovery(runner: SystemProcessRunner(openDevice: { _, _ in errno = EIO; return -1 }))
        XCTAssertThrowsError(try failing.write(.forcedReset(intent(target, color: "reset"),
            intakeAt: 1_000, title: "old title"), to: target)) { error in
            guard case TerminalVisualStateError.staleDelivery = error else { return XCTFail("Expected stale delivery, got \(error)") }
        }
        XCTAssertThrowsError(try failing.write(.forcedReset(intent(target, color: "reset"),
            intakeAt: 1_000, title: "\u{1B}BAD"), to: target)) { error in
            guard case TerminalVisualStateError.invalidRecord = error else { return XCTFail("Expected invalid record, got \(error)") }
        }
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#778899")
        try noBytes(target)
    }

    func testNewIntakeDuringOpenRejectsPrepublishedRenderWithoutReplacingLatestIntent() throws {
        let target = try terminal(10)
        let value = intent(target)
        let runner = SystemProcessRunner(openDevice: { path, flags in
            do {
                XCTAssertEqual(try self.state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#123456")
                self.clock.advance(by: 1)
                try self.state.publishObservation(TerminalObservation(tty: target.tty, device: target.device,
                    producer: target.ttyOwner, provider: "claude", verifiedAgent: false, state: "processing",
                    event: nil, deliveryID: "newer", responseID: nil, observedAt: 1_001))
                var newer = value
                newer.deliveryID = "newer"; newer.background = "#ABCDEF"; newer.updatedAt = 1_001
                try self.state.publishIntent(newer, to: target, synthetic: false, intakeAt: 1_001,
                    deadline: DispatchTime.now().uptimeNanoseconds + 20_000_000)
            } catch { XCTFail("New intake failed: \(error)"); errno = EIO; return -1 }
            return Darwin.open(path, flags)
        })
        XCTAssertThrowsError(try recovery(runner: runner).render(render(), intent: value,
            synthetic: false, intakeAt: 1_000, to: target)) { error in
            guard case TerminalVisualStateError.staleDelivery = error else { return XCTFail("Expected stale delivery, got \(error)") }
        }
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "#ABCDEF")
        try noBytes(target)
    }

    private func preview(_ target: TerminalTargetBinding, id: String = "preview") throws -> String {
        let colors = try XCTUnwrap(TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE"))
        var color = ""
        _ = try SystemProcessRunner().writeManagedToDevice(path: target.tty,
            lockURL: state.lockURL(forTTY: target.tty)) { _, deadline in
            color = try XCTUnwrap(TerminalRenderer.previewBackground(
                ordinary: self.state.ordinaryBackgroundUnlocked(for: target, deadline: deadline), colors: colors))
            try self.state.saveEffectUnlocked(TerminalEffectRecord(target: target,
                controller: self.generation(90), effectID: id, kind: .preview, background: color,
                heartbeatAt: self.clock.now().timeIntervalSince1970), deadline: deadline)
            return nil
        }
        return color
    }

    func testPreviewExpiryRestoresLatestIntentWithOnlyBackgroundBytes() throws {
        let target = try terminal(10)
        let color = try preview(target)
        XCTAssertTrue(try recovery().write(.ordinary(intent(target, color: "#ABCDEF"), synthetic: false,
            intakeAt: 1_000), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;\(color)\u{1B}\\".utf8))
        clock.advance(by: 2)
        XCTAssertTrue(try recovery().write(.reconcile(resetLegacy: false, clearSelective: false), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max)).active)
    }

    func testPreviewCancellationPreservesUnderlyingFocusAndIgnoresOldID() throws {
        let target = try terminal(10)
        try cache(target, effect: true)
        _ = try preview(target, id: "new-preview")
        _ = try SystemProcessRunner().writeManagedToDevice(path: target.tty,
            lockURL: state.lockURL(forTTY: target.tty)) { _, deadline in
            XCTAssertFalse(try self.state.cancelEffectUnlocked(target, effectID: "old-preview",
                controller: self.generation(90), kind: .preview, deadline: deadline))
            XCTAssertTrue(try self.state.cancelEffectUnlocked(target, effectID: "new-preview",
                controller: self.generation(90), kind: .preview, deadline: deadline))
            return nil
        }
        XCTAssertTrue(try XCTUnwrap(state.currentEffectUnlocked(target, deadline: .max)).active)
        XCTAssertTrue(try recovery().write(.reconcile(resetLegacy: false, clearSelective: false), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;#AABBCC\u{1B}\\".utf8))
        XCTAssertEqual(state.cachedRecords().effects.count, 2)
    }

    func testRecoveryCancelsPreviewButAllowsANewHarmlessPreviewDuringSuspension() throws {
        let target = try terminal(10)
        _ = try preview(target)
        let report = recovery().recover()
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(try read(target), reset)
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max)).active)
        let color = try preview(target, id: "after-recovery")
        XCTAssertTrue(try recovery().write(.ordinary(intent(target), synthetic: false, intakeAt: 1_000), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;\(color)\u{1B}\\".utf8))
        XCTAssertEqual(restrictions.read(), .suspended)
    }

    func testPreviewWithoutOrdinaryIntentExpiresToOnlyGhosttyBackgroundReset() throws {
        let target = try terminal(10)
        let color = try preview(target)
        XCTAssertTrue(try recovery().write(.reconcile(resetLegacy: false, clearSelective: false), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;\(color)\u{1B}\\".utf8))
        clock.advance(by: 2)
        XCTAssertTrue(try recovery().write(.reconcile(resetLegacy: false, clearSelective: false), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]111\u{1B}\\".utf8))
        XCTAssertNil(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max))
    }

    func testPreviewCannotRenewItsTwoSecondLeaseAndDeadControllerCannotOwnPaint() throws {
        let target = try terminal(10)
        _ = try preview(target)
        clock.advance(by: 1)
        _ = try SystemProcessRunner().writeManagedToDevice(path: target.tty,
            lockURL: state.lockURL(forTTY: target.tty)) { _, deadline in
            XCTAssertFalse(try self.state.refreshEffectUnlocked(target, effectID: "preview",
                controller: self.generation(90), kind: .preview, deadline: deadline))
            var renewal = try XCTUnwrap(self.state.currentEffectUnlocked(target, kind: .preview, deadline: deadline))
            renewal.heartbeatAt = 1_001
            XCTAssertThrowsError(try self.state.saveEffectUnlocked(renewal, deadline: deadline))
            return nil
        }
        XCTAssertEqual(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max)).heartbeatAt, 1_000)
        identities[90] = nil
        XCTAssertTrue(try recovery().write(.ordinary(intent(target), synthetic: false, intakeAt: 1_001), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;#123456\u{1B}\\".utf8))
    }

    func testNativePreviewAndPlainFocusRecoverOnceAndCancelBothRecords() throws {
        let plain = try terminal(10), native = nativeAlias(plain)
        try cache(plain, effect: true)
        _ = try preview(native)
        let report = recovery().recover()
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(try read(plain), reset)
        try noBytes(plain)
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(plain, deadline: .max)).active)
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(native, kind: .preview, deadline: .max)).active)
        XCTAssertTrue(state.cachedRecords().unreadable.isEmpty)
    }

    func testGlobalRuleWinsOverPreviewWithoutDestroyingItsSeparateRecord() throws {
        let target = try terminal(10)
        _ = try preview(target)
        try LockStateWriter.write(LockStateData(locked: true, reason: .manual, lockUntilEpoch: 1_500,
            unlockUntilEpoch: 0, writtenEpoch: 1_000, lockBg: "#667788", lockFg: "#EEEEFF"),
            to: root.appendingPathComponent("lock.state"))
        XCTAssertTrue(try recovery().write(.currentRestriction, to: target))
        let bytes = try read(target), text = String(decoding: bytes, as: UTF8.self)
        XCTAssertTrue(text.contains("\u{1B}]11;#667788"))
        XCTAssertEqual(try state.currentEffectUnlocked(target, deadline: .max)?.kind, .globalRestriction)
        XCTAssertTrue(try XCTUnwrap(state.currentEffectUnlocked(target, kind: .preview, deadline: .max)).active)
    }

    private func read(_ target: TerminalTargetBinding) throws -> Data {
        let tty = try XCTUnwrap(ptys.first { $0.path == target.tty })
        var ready = pollfd(fd: tty.master, events: Int16(POLLIN), revents: 0)
        guard poll(&ready, 1, 1_000) == 1 else { throw POSIXError(.ETIMEDOUT) }
        var bytes = [UInt8](repeating: 0, count: 4_096)
        let count = Darwin.read(tty.master, &bytes, bytes.count)
        guard count >= 0 else { throw POSIXError(.EIO) }
        return Data(bytes.prefix(count))
    }

    private func noBytes(_ target: TerminalTargetBinding) throws {
        let tty = try XCTUnwrap(ptys.first { $0.path == target.tty })
        var ready = pollfd(fd: tty.master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 10), 0)
    }

    func testRecoveryPersistsFirstClearsOwnershipAndNeverReplaysPendingBodies() throws {
        let target = try terminal(10)
        try cache(target, effect: true)
        try state.publishIntent(intent(target))
        let before = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("organizer"),
            includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix("intent-") }
        let intentURL = try XCTUnwrap(before)
        let intentBytes = try Data(contentsOf: intentURL)
        try FileManager.default.createDirectory(at: pending(target).deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("\u{1B}]0;OLD_TITLE\u{07}ALERT_SENTINEL\u{07}".utf8).write(to: pending(target))
        let definitions = root.appendingPathComponent("home/schedule.json")
        try Data("SAVED_DEFINITIONS".utf8).write(to: definitions)
        let report = recovery(native: {
            XCTAssertFalse(Thread.isMainThread)
            XCTAssertEqual(self.restrictions.read(), .suspended)
            return []
        }).recover()
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(report.items.map(\.status), [.restored])
        XCTAssertEqual(try read(target), reset)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending(target).path))
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, deadline: .max)).active)
        XCTAssertEqual(try Data(contentsOf: intentURL), intentBytes)
        XCTAssertEqual(try String(contentsOf: definitions), "SAVED_DEFINITIONS")
    }

    func testCachedPlainShellRestoresWithoutAutomation() throws {
        let target = try terminal(10)
        try cache(target)
        let report = recovery(native: { throw GhosttyCatalogError.permissionDenied }).recover()
        XCTAssertFalse(report.catalogueAvailable)
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(report.items.map(\.status), [.restored])
        XCTAssertEqual(try read(target), reset)
    }

    func testCachedHealthyRepaintDoesNotWaitForNativeDiscovery() throws {
        let target = try terminal(10)
        try cache(target)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0), result = RecoveryReportResult()
        defer { release.signal() }
        let service = recovery(native: {
            entered.signal(); release.wait(); throw GhosttyCatalogError.permissionDenied
        })
        DispatchQueue.global().async {
            result.value = service.recover()
            finished.signal()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(try read(target), reset)
        release.signal()
        XCTAssertEqual(finished.wait(timeout: .now() + 1), .success)
        XCTAssertFalse(try XCTUnwrap(result.value).hasFailures)
    }

    func testFailedPersistenceStartsNeitherDiscoveryNorDeviceOutput() throws {
        let target = try terminal(10)
        try cache(target)
        try FileManager.default.createDirectory(at: restrictions.url, withIntermediateDirectories: true)
        let runner = MockProcessRunner()
        let report = recovery(runner: runner, native: {
            XCTFail("Persistence precedes native discovery")
            return []
        }).recover()
        XCTAssertFalse(report.stateSaved)
        XCTAssertTrue(report.hasFailures)
        XCTAssertTrue(runner.managedCallLog.isEmpty)
        try noBytes(target)
    }

    func testGlobalEffectIsPersistedBeforeDeviceBytesAreWritten() throws {
        let target = try terminal(10)
        try cache(target)
        try LockStateWriter.write(LockStateData(locked: true, reason: .manual, lockUntilEpoch: 2_000,
            unlockUntilEpoch: 0, writtenEpoch: 1_000, lockBg: "#123456", lockFg: "#EEEEEE"),
            to: root.appendingPathComponent("lock.state"))
        let system = SystemProcessRunner(), runner = MockProcessRunner(), observed = RecoveryEffectResult()
        runner.managedHandler = { path, lock, prepare in
            try system.writeManagedToDevice(path: path, lockURL: lock) { fd, deadline in
                let bytes = try prepare(fd, deadline)
                observed.value = try self.state.currentEffectUnlocked(target, deadline: deadline)
                XCTAssertNotNil(observed.value, "Effect exists before the prepare callback returns paint bytes")
                return bytes
            }
        }
        XCTAssertTrue(try recovery(runner: runner).write(.currentRestriction, to: target))
        XCTAssertEqual(observed.value?.kind, .globalRestriction)
        XCTAssertEqual(observed.value?.background, "#123456")
        XCTAssertTrue(String(decoding: try read(target), as: UTF8.self).contains("\u{1B}]11;#123456\u{07}"))
    }

    func testFailuresRemainRetryableAndDoNotPreventHealthyFanout() throws {
        let healthy = try terminal(10), failed = try terminal(11)
        let uncertain = try terminal(12), vanished = try terminal(13)
        for target in [healthy, failed, uncertain, vanished] { try cache(target) }
        identities[12] = nil
        missing.insert(vanished.tty)
        let system = SystemProcessRunner(), runner = MockProcessRunner()
        runner.managedHandler = { path, lock, prepare in
            if path == failed.tty { throw ProcessRunnerError.deviceNotWritable(path) }
            return try system.writeManagedToDevice(path: path, lockURL: lock, prepare: prepare)
        }
        let report = recovery(runner: runner).recover()
        XCTAssertTrue(report.hasFailures)
        XCTAssertEqual(report.items.filter { $0.status == .restored }.count, 1)
        XCTAssertEqual(report.items.filter { $0.status == .failed }.count, 2)
        XCTAssertEqual(report.items.filter { $0.status == .vanished }.count, 1)
        XCTAssertEqual(try read(healthy), reset)
        try noBytes(failed); try noBytes(uncertain); try noBytes(vanished)
        XCTAssertEqual(state.cachedRecords().bindings.count, 4)
    }

    func testAvailableCatalogueIncludesUnregisteredPlainNativeSurface() throws {
        let target = try terminal(10)
        let surface = GhosttySurface(id: GhosttySurfaceID(application: generation(80), terminalID: "pane"),
            windowID: "window", tabID: "tab", title: "duplicate", directory: "/same", tty: target.tty,
            foregroundPID: 10, tabSelected: true, mappingIssue: nil)
        let report = recovery(native: { [surface] }).recover()
        XCTAssertFalse(report.hasFailures)
        XCTAssertTrue(report.catalogueAvailable)
        XCTAssertEqual(report.items.first?.target?.nativeSurface, surface.id)
        XCTAssertEqual(try read(target), reset)
        XCTAssertEqual(state.cachedRecords().bindings.first?.nativeSurface, surface.id)
    }

    func testQueuedRestrictionReadsSuspensionAfterIndependentRecovery() throws {
        let target = try terminal(10)
        try cache(target)
        try LockStateWriter.write(LockStateData(locked: true, reason: .manual, lockUntilEpoch: 2_000,
            unlockUntilEpoch: 0, writtenEpoch: 1_000, lockBg: "#123456", lockFg: "#EEEEEE"),
            to: root.appendingPathComponent("lock.state"))
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0), result = RecoveryWriteResult()
        defer { release.signal() }
        let queued = recovery(runner: SystemProcessRunner(openDevice: { path, flags in
            entered.signal(); release.wait(); return Darwin.open(path, flags)
        }))
        DispatchQueue.global().async {
            result.value = Result { try queued.write(.currentRestriction, to: target) }
            finished.signal()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 1), .success)
        XCTAssertFalse(recovery().recover().hasFailures)
        XCTAssertEqual(try read(target), reset)
        release.signal()
        XCTAssertEqual(finished.wait(timeout: .now() + 1), .success)
        XCTAssertFalse(try XCTUnwrap(result.value).get())
        try noBytes(target)
    }

    func testOrdinaryUpdatesRemainStoredWhileActiveSelectiveBackgroundWins() throws {
        let target = try terminal(10)
        try cache(target, effect: true)
        let renderer = recovery()
        XCTAssertTrue(try renderer.write(.ordinary(intent(target), synthetic: false, intakeAt: 1_000), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;#AABBCC\u{1B}\\".utf8))
        clock.advance(by: 7)
        XCTAssertTrue(try renderer.write(.reconcile(resetLegacy: false, clearSelective: false), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]11;#123456\u{1B}\\".utf8))
        XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(target, deadline: .max)).active)
    }

    func testResumePaintsCurrentRequestedSoftRuleAndDoesNotReviveOldSelectiveID() throws {
        let target = try terminal(10)
        try cache(target, effect: true)
        try restrictions.write(suspended: true)
        try MuteStateWriter.write(MuteStateData(muted: false, reason: .none, untilEpoch: 2_000,
            writtenEpoch: 1_000, appPID: 80, pauseBg: "#123456", pauseFg: "#EEEEEE",
            requestedMuted: true), to: root.appendingPathComponent("home/mute.state"))
        let report = recovery().recover(resume: true)
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(restrictions.read(), .active)
        let bytes = try read(target)
        XCTAssertEqual(bytes, Data("\u{1B}]104\u{07}\u{1B}]10;#EEEEEE\u{07}\u{1B}]11;#123456\u{07}\u{1B}]1337;SetBackgroundImageFile=\u{07}".utf8))
        let effect = try XCTUnwrap(state.currentEffectUnlocked(target, deadline: .max))
        XCTAssertEqual(effect.kind, .globalRestriction)
        XCTAssertNil(try state.matchingEffectUnlocked(target, effectID: "old-effect",
            controller: generation(90), deadline: .max))
    }

    func testEmptyUnverifiedRegistryEntryIsReportedAndNeverAuthorizesOutput() throws {
        let directory = root.appendingPathComponent("active-ttys")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entry = directory.appendingPathComponent("_dev_ttys888")
        try Data().write(to: entry)
        let runner = MockProcessRunner()
        let report = recovery(runner: runner).recover()
        XCTAssertTrue(report.hasFailures)
        XCTAssertEqual(report.items.map(\.status), [.failed])
        XCTAssertTrue(runner.managedCallLog.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: entry.path))
    }

    func testDedicatedScopeCannotPaintOwnerOnlyCachedTargets() throws {
        let target = try terminal(10)
        try cache(target)
        let runner = MockProcessRunner()
        let allowed = GhosttySurfaceID(application: generation(80), terminalID: "dedicated")
        let report = recovery(runner: runner, allowed: [allowed]).recover()
        XCTAssertTrue(report.hasFailures)
        XCTAssertEqual(report.items.map(\.status), [.failed])
        XCTAssertTrue(runner.managedCallLog.isEmpty)
        try noBytes(target)
    }

    func testOrdinaryBatchRegisterDoesNotChangeSuspensionOrPaint() throws {
        let target = try terminal(10)
        try restrictions.write(suspended: true)
        let before = try Data(contentsOf: restrictions.url)
        let surface = GhosttySurface(id: GhosttySurfaceID(application: generation(80), terminalID: "pane"),
            windowID: "window", tabID: "tab", title: nil, directory: nil, tty: target.tty,
            foregroundPID: 10, tabSelected: true, mappingIssue: nil)
        let batch = recovery(native: { [surface] }).apply(.register)
        XCTAssertTrue(batch.catalogueAvailable)
        XCTAssertEqual(batch.items.map(\.status), [.unaffected])
        XCTAssertEqual(try Data(contentsOf: restrictions.url), before)
        XCTAssertEqual(state.cachedRecords().bindings.first?.nativeSurface, surface.id)
        try noBytes(target)
    }

    func testForcedResetRejectsStaleDeliveryBeforePaletteOrTitleCanSpill() throws {
        let target = try terminal(10)
        try cache(target)
        try state.publishObservation(TerminalObservation(tty: target.tty, device: target.device,
            producer: target.ttyOwner, provider: "claude", verifiedAgent: false, state: "processing",
            event: nil, deliveryID: "new-delivery", responseID: nil, observedAt: 1_000))
        XCTAssertThrowsError(try recovery().write(.forcedReset(intent(target, color: "reset"),
            intakeAt: 1_000, title: "current directory"), to: target)) { error in
            guard case TerminalVisualStateError.staleDelivery = error else { return XCTFail("Unexpected error: \(error)") }
        }
        try noBytes(target)
    }

    func testForcedResetUsesCurrentSyntheticDeliveryAndPreservesSelectiveBackground() throws {
        let target = try terminal(10)
        try cache(target, effect: true)
        let value = intent(target, color: "reset")
        try state.publishObservation(TerminalObservation(tty: target.tty, device: target.device,
            producer: target.ttyOwner, provider: "claude", verifiedAgent: false, state: "complete",
            event: nil, deliveryID: value.deliveryID, responseID: nil, observedAt: 1_000))
        XCTAssertTrue(try recovery().write(.forcedReset(value, intakeAt: 1_000, title: "directory"), to: target))
        XCTAssertEqual(try read(target), Data("\u{1B}]104\u{07}\u{1B}]11;#AABBCC\u{1B}\\\u{1B}]0;directory\u{1B}\\".utf8))
    }

    func testScopedTargetResolutionReusesOnlyMatchingAllowedNativeBinding() throws {
        let plain = try terminal(10)
        let native = TerminalTargetBinding(tty: plain.tty, device: plain.device, ttyOwner: plain.ttyOwner,
            nativeSurface: GhosttySurfaceID(application: generation(80), terminalID: "pane"))
        try cache(native)
        let service = recovery(allowed: [try XCTUnwrap(native.nativeSurface)], native: {
            XCTFail("A verified cached binding does not need Automation")
            return []
        })
        XCTAssertEqual(try service.target(tty: plain.tty, owner: plain.ttyOwner), native)
        XCTAssertThrowsError(try recovery(allowed: []).target(tty: plain.tty, owner: plain.ttyOwner))
    }

    func testRelaunchReconciliationTouchesPriorEffectsOnly() throws {
        let unaffected = try terminal(10), affected = try terminal(11)
        try cache(unaffected)
        try cache(affected, effect: true)
        let items = recovery().reconcilePriorEffects()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.target, affected)
        XCTAssertEqual(try read(affected), Data("\u{1B}]111\u{1B}\\".utf8))
        try noBytes(unaffected)
        XCTAssertEqual(restrictions.read(), .active)
    }

    func testCachedTargetPrefersOneNativeAliasWithoutDiscovery() throws {
        let plain = try terminal(10)
        let native = TerminalTargetBinding(tty: plain.tty, device: plain.device, ttyOwner: plain.ttyOwner,
            nativeSurface: GhosttySurfaceID(application: generation(80), terminalID: "pane"))
        try cache(plain)
        try cache(native)
        let service = recovery(native: { XCTFail("Cached reconciliation must not discover targets"); return [] })
        XCTAssertEqual(try service.cachedTarget(tty: plain.tty), native)
        XCTAssertThrowsError(try recovery(allowed: []).cachedTarget(tty: plain.tty))
        try noBytes(plain)
    }

    func testSyntheticCheckValidatesWithoutPaintingOrCaching() throws {
        let target = try terminal(10), value = intent(target)
        try state.publishObservation(TerminalObservation(tty: target.tty, device: target.device,
            producer: target.ttyOwner, provider: "claude", verifiedAgent: false, state: "complete",
            event: nil, deliveryID: value.deliveryID, responseID: nil, observedAt: 1_000))
        XCTAssertFalse(try recovery().write(.checkSynthetic(value, intakeAt: 1_000), to: target))
        XCTAssertTrue(state.cachedRecords().bindings.isEmpty)
        XCTAssertNil(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max))
        clock.advance(by: 1)
        try state.publishObservation(TerminalObservation(tty: target.tty, device: target.device,
            producer: target.ttyOwner, provider: "claude", verifiedAgent: false, state: "processing",
            event: nil, deliveryID: "new-delivery", responseID: nil, observedAt: 1_001))
        XCTAssertThrowsError(try recovery().write(.checkSynthetic(value, intakeAt: 1_000), to: target))
        try noBytes(target)
    }

    func testSyntheticCheckAcceptsLiveAgentBelowContinuingShellOwner() throws {
        let shell = try terminal(10)
        identities[11] = ProcessIdentity(generation: generation(11), parentPID: 10,
            group: 10, device: shell.device, foregroundGroup: 10)
        let value = OrdinaryBackgroundIntent(tty: shell.tty, device: shell.device,
            producer: generation(11), deliveryID: "agent-delivery", updatedAt: 1_000, background: "reset")
        try state.publishObservation(TerminalObservation(tty: shell.tty, device: shell.device,
            producer: value.producer, provider: "claude", verifiedAgent: true, state: "complete",
            event: "Stop", deliveryID: value.deliveryID, responseID: nil, observedAt: 1_000))
        let service = recovery()
        let target = try service.target(tty: shell.tty, owner: generation(11))
        XCTAssertEqual(target.ttyOwner, shell.ttyOwner)
        XCTAssertFalse(try service.write(.checkSynthetic(value, intakeAt: 1_000), to: target))
        XCTAssertTrue(state.cachedRecords().bindings.isEmpty)
        try noBytes(shell)
    }

    func testCachedTargetRejectsAmbiguousNativeSurfacesAndReusedOwner() throws {
        let plain = try terminal(10)
        for id in ["pane-a", "pane-b"] {
            try cache(TerminalTargetBinding(tty: plain.tty, device: plain.device, ttyOwner: plain.ttyOwner,
                nativeSurface: GhosttySurfaceID(application: generation(80), terminalID: id)))
        }
        XCTAssertThrowsError(try recovery().cachedTarget(tty: plain.tty))
        identities[10] = ProcessIdentity(generation: ProcessGeneration(pid: 10, startSeconds: 101, startMicroseconds: 1),
            parentPID: 1, group: 10, device: plain.device, foregroundGroup: 10)
        XCTAssertThrowsError(try recovery().cachedTarget(tty: plain.tty))
        try noBytes(plain)
    }

    func testRelaunchClearsLegacyForegroundAfterCanceledGlobalPaintFailure() throws {
        let target = try terminal(10)
        try cache(target)
        _ = try SystemProcessRunner().writeManagedToDevice(path: target.tty,
            lockURL: state.lockURL(forTTY: target.tty)) { _, deadline in
            try self.state.saveEffectUnlocked(TerminalEffectRecord(target: target,
                controller: self.generation(90), effectID: "failed-global", kind: .globalRestriction,
                background: "#123456", heartbeatAt: 1_000, active: false), deadline: deadline)
            return nil
        }
        XCTAssertEqual(recovery().reconcilePriorEffects().first?.status, .restored)
        XCTAssertEqual(try read(target), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{1B}\\".utf8))
    }

    func testReconcileRestoresLatestBoundIntentOnceAcrossAliasesAfterAgentExit() throws {
        let plain = try terminal(10), native = nativeAlias(plain)
        try cache(plain); try cache(native)
        identities[11] = ProcessIdentity(generation: generation(11), parentPID: 10,
            group: 10, device: plain.device, foregroundGroup: 10)
        var old = intent(plain)
        old.producer = generation(11)
        old.updatedAt = 998
        try state.publishIntent(old)
        try state.bindOrdinaryIntentUnlocked(old, to: plain, deadline: .max)
        var latest = old
        latest.background = "#ABCDEF"
        latest.deliveryID = "latest-delivery"
        latest.updatedAt = 999
        try state.publishIntent(latest)
        try state.bindOrdinaryIntentUnlocked(latest, to: native, deadline: .max)
        identities[11] = nil
        let runner = MockProcessRunner()
        var writes = 0
        runner.managedHandler = { path, lock, prepare in
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock) { fd, deadline in
                let bytes = try prepare(fd, deadline)
                if bytes != nil { writes += 1 }
                return bytes
            }
        }
        let service = recovery(runner: runner, native: { throw GhosttyCatalogError.permissionDenied })
        let batch = service.apply(.reconcile(resetLegacy: false, clearSelective: false))
        XCTAssertEqual(batch.items.count, 1)
        XCTAssertEqual(batch.items.first?.target, native)
        XCTAssertEqual(batch.items.first?.status, .restored)
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(try read(plain), Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
        try noBytes(plain)
    }

    func testUnscopedHookComposesNativeLeaseAndRecoveryCancelsEveryAliasOnce() throws {
        let plain = try terminal(10), native = nativeAlias(plain)
        try cache(plain); try cache(native, effect: true)
        let service = recovery(native: { XCTFail("Unique cached hook target does not need native discovery"); return [] })
        let hook = try service.target(tty: plain.tty, owner: plain.ttyOwner)
        XCTAssertEqual(hook, native)
        XCTAssertTrue(try service.write(.ordinary(intent(plain), synthetic: false, intakeAt: 1_000), to: hook))
        XCTAssertEqual(try read(plain), Data("\u{1B}]11;#AABBCC\u{1B}\\".utf8))
        try cache(plain, effect: true)
        let report = recovery(native: { throw GhosttyCatalogError.permissionDenied }).recover()
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(try read(plain), reset)
        try noBytes(plain)
        for alias in [plain, native] {
            XCTAssertFalse(try XCTUnwrap(state.currentEffectUnlocked(alias, deadline: .max)).active)
        }
    }

    func testResumeCancelsAllAliasLeasesAndPaintsCurrentRuleOnce() throws {
        let plain = try terminal(10), native = nativeAlias(plain)
        try cache(plain, effect: true); try cache(native, effect: true)
        try restrictions.write(suspended: true)
        try MuteStateWriter.write(MuteStateData(muted: false, reason: .none, untilEpoch: 2_000,
            writtenEpoch: 1_000, appPID: 80, pauseBg: "#123456", pauseFg: "#EEEEEE",
            requestedMuted: true), to: root.appendingPathComponent("home/mute.state"))
        let report = recovery().recover(resume: true)
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(try read(plain), Data("\u{1B}]104\u{07}\u{1B}]10;#EEEEEE\u{07}\u{1B}]11;#123456\u{07}\u{1B}]1337;SetBackgroundImageFile=\u{07}".utf8))
        try noBytes(plain)
        for alias in [plain, native] {
            XCTAssertNil(try state.matchingEffectUnlocked(alias, effectID: "old-effect",
                controller: generation(90), deadline: .max))
        }
    }

    func testFreshNativeAliasRegistersWithoutRepaintingHandledPhysicalTarget() throws {
        let plain = try terminal(10)
        try cache(plain, effect: true)
        let alias = nativeAlias(plain)
        let row = GhosttySurface(id: try XCTUnwrap(alias.nativeSurface), windowID: "window", tabID: "tab",
            title: nil, directory: nil, tty: plain.tty, foregroundPID: plain.ttyOwner.pid,
            tabSelected: true, mappingIssue: nil)
        let runner = MockProcessRunner()
        var writes = 0
        runner.managedHandler = { path, lock, prepare in
            return try SystemProcessRunner().writeManagedToDevice(path: path, lockURL: lock) { fd, deadline in
                let bytes = try prepare(fd, deadline)
                if bytes != nil { writes += 1 }
                return bytes
            }
        }
        let report = recovery(runner: runner, native: { [row] }).recover()
        XCTAssertFalse(report.hasFailures)
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(try read(plain), reset)
        try noBytes(plain)
        XCTAssertEqual(Set(state.cachedRecords().bindings), Set([plain, alias]))
    }

    func testScopedResolutionRejectsConflictingLiveNativeAliasesWithoutPainting() throws {
        let plain = try terminal(10), first = nativeAlias(plain, id: "pane-a"), second = nativeAlias(plain, id: "pane-b")
        try cache(plain); try cache(first, effect: true); try cache(second, effect: true)
        let service = recovery(allowed: [try XCTUnwrap(first.nativeSurface)], native: {
            XCTFail("Conflicting cached aliases must not trigger native guessing"); return []
        })
        XCTAssertThrowsError(try service.target(tty: plain.tty, owner: plain.ttyOwner))
        let report = recovery(allowed: [try XCTUnwrap(first.nativeSurface)]).recover()
        XCTAssertTrue(report.hasFailures)
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(report.items.first?.status, .failed)
        try noBytes(plain)
    }

    func testProvenOwnerEndIsVanishedButUnknownMetadataRemainsFailedWithoutRetirement() throws {
        let reused = try terminal(10), ended = try terminal(11)
        try cache(reused); try cache(ended)
        identities[10] = ProcessIdentity(generation: ProcessGeneration(pid: 10, startSeconds: 101, startMicroseconds: 1),
            parentPID: 1, group: 10, device: reused.device, foregroundGroup: 10)
        identities[11] = nil
        missingProcesses.insert(11)
        let proved = recovery().recover()
        XCTAssertFalse(proved.hasFailures)
        XCTAssertEqual(proved.items.count, 2)
        XCTAssertTrue(proved.items.allSatisfy { $0.status == .vanished })
        let unknown = try terminal(12)
        try cache(unknown)
        identities[12] = nil
        let partial = recovery().recover()
        XCTAssertTrue(partial.hasFailures)
        XCTAssertEqual(partial.items.filter { $0.status == .vanished }.count, 2)
        XCTAssertEqual(partial.items.filter { $0.status == .failed }.count, 1)
        XCTAssertEqual(Set(state.cachedRecords().bindings), Set([reused, ended, unknown]))
        try noBytes(reused); try noBytes(ended); try noBytes(unknown)
    }

    func testConflictingLiveOwnersOnOneTTYAreReportedWithoutPaint() throws {
        let first = try terminal(10)
        identities[11] = identity(11, device: first.device)
        let second = try XCTUnwrap(state.captureTarget(tty: first.tty, owner: generation(11)))
        try cache(first); try cache(second)
        XCTAssertThrowsError(try recovery().target(tty: first.tty, owner: first.ttyOwner))
        let report = recovery().recover()
        XCTAssertTrue(report.hasFailures)
        XCTAssertEqual(report.items.count, 2)
        XCTAssertTrue(report.items.allSatisfy { $0.status == .failed })
        try noBytes(first)
    }

    func testUnknownNativeAliasMetadataRemainsFailureBesideHealthyCachedTTY() throws {
        let uncertain = try terminal(10), native = nativeAlias(uncertain), healthy = try terminal(11)
        try cache(uncertain); try cache(native, effect: true); try cache(healthy)
        identities[80] = nil
        let report = recovery().recover()
        XCTAssertTrue(report.hasFailures)
        XCTAssertEqual(report.items.count, 2)
        XCTAssertEqual(report.items.first { $0.tty == uncertain.tty }?.status, .failed)
        XCTAssertEqual(report.items.first { $0.tty == healthy.tty }?.status, .restored)
        try noBytes(uncertain)
        XCTAssertEqual(try read(healthy), reset)
        XCTAssertTrue(state.cachedRecords().bindings.contains(native))
    }
}

private final class RecoveryWriteResult { var value: Result<Bool, Error>? }
private final class RecoveryReportResult { var value: VisualRecoveryReport? }
private final class RecoveryEffectResult { var value: TerminalEffectRecord? }
