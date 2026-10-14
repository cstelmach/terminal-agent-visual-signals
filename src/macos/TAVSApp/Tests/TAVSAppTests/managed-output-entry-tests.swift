import XCTest
import Darwin
@testable import TAVSApp

final class ManagedOutputEntryTests: XCTestCase {
    private var root: URL!
    private var runtime: URL!
    private var marker: URL!
    private var state: TerminalVisualStateStore!
    private var identities: [Int32: ProcessIdentity] = [:]
    private var master: Int32 = -1
    private var slave: Int32 = -1
    private var tty = ""
    private var device: UInt32 = 0
    private var rows: [GhosttySurface] = []
    private var factoryCalls = 0
    private var nativeCalls = 0
    private var failFactory = false
    private var processRunner: ProcessRunner = SystemProcessRunner()

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TMPDIR"]))
            .appendingPathComponent("headless-\(UUID().uuidString)")
        runtime = root.appendingPathComponent("runtime")
        marker = root.appendingPathComponent("home/visual-restrictions.state")
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        var name = [CChar](repeating: 0, count: 1024)
        guard openpty(&master, &slave, &name, nil, nil) == 0 else { throw POSIXError(.EIO) }
        var attributes = termios()
        tcgetattr(slave, &attributes); cfmakeraw(&attributes); tcsetattr(slave, TCSANOW, &attributes)
        tty = String(cString: name)
        device = try XCTUnwrap(ProcessIdentity.deviceNumber(tty))
        identities[10] = identity(10, parent: 1, device: device)
        identities[20] = identity(20, parent: 10, device: device)
        identities[getpid()] = identity(getpid(), parent: 20, device: UInt32.max)
        identities[80] = identity(80, parent: 1, device: UInt32.max)
        identities[90] = identity(90, parent: 1, device: UInt32.max)
        state = TerminalVisualStateStore(runtimeDirectory: runtime, lookup: { self.identities[$0] })
    }

    override func tearDownWithError() throws {
        close(master); close(slave)
        try FileManager.default.removeItem(at: root)
    }

    private func generation(_ pid: Int32) -> ProcessGeneration {
        ProcessGeneration(pid: pid, startSeconds: 1, startMicroseconds: 1)
    }

    private func identity(_ pid: Int32, parent: UInt32, device: UInt32) -> ProcessIdentity {
        ProcessIdentity(generation: generation(pid), parentPID: parent, group: 10,
                        device: device, foregroundGroup: 10)
    }

    private func surface() -> GhosttySurface {
        GhosttySurface(id: GhosttySurfaceID(application: generation(80), terminalID: "dedicated"),
            windowID: "window", tabID: "tab", title: "same", directory: "/fixture", tty: tty,
            foregroundPID: 10, tabSelected: true, mappingIssue: nil)
    }

    private func factory(_ marker: URL, _ runtime: URL, _ env: [String: String]) throws -> VisualRecovery {
        factoryCalls += 1
        if failFactory { throw VisualRecoveryError.targetUnavailable }
        XCTAssertEqual(marker.path, self.marker.path)
        XCTAssertEqual(runtime.path, self.runtime.path)
        let restrictions = VisualRestrictionsStateStore(url: marker)
        let policy = VisualRestrictionPolicy(restrictions: restrictions,
            muteURL: marker.deletingLastPathComponent().appendingPathComponent("mute.state"),
            lockURL: runtime.appendingPathComponent("lock.state"), pidAlive: { _ in false })
        let allowed = try env["TAVS_SESSIONS_TEST_TARGETS"].map {
            Set(try JSONDecoder().decode([GhosttySurfaceID].self, from: Data($0.utf8)))
        }
        return VisualRecovery(runtimeDirectory: runtime, restrictions: restrictions, state: state,
            policy: policy, processRunner: processRunner, clock: SystemClock(),
            controller: generation(90), allowedSurfaces: allowed, nativeSnapshot: {
                self.nativeCalls += 1
                return self.rows
            })
    }

    private func args(_ verb: String, _ rest: String...) -> [String] {
        ["TAVSApp", verb, marker.path, runtime.path] + rest
    }

    private func run(_ args: [String], env: [String: String] = [:]) -> ManagedOutputResult? {
        ManagedOutputEntry.run(args, environment: env, factory: factory, lookup: { self.identities[$0] })
    }

    private func context(pid: Int32 = 10, delivery: String = "delivery-1") -> OrganizerContext {
        OrganizerContext(deliveryID: delivery, observedAt: Date().timeIntervalSince1970 - 1,
            provider: "claude", verifiedAgent: true, producer: generation(pid), device: device,
            event: "Stop", responseID: nil)
    }

    private func token(_ context: OrganizerContext) throws -> String {
        try JSONEncoder().encode(context).base64EncodedString()
    }

    private func renderData(_ background: String = "", title: String = "BATCH_TITLE") -> Data {
        let fields = [background, "reset"] + Array(repeating: "", count: 16)
            + ["1", title, "", "", "0"]
        return Data((fields.joined(separator: "\0") + "\0").utf8)
    }

    func testTypedRenderUsesAuthenticatedEntryAndStyleOnlyLeavesIntentAbsent() throws {
        let command = args("--managed-render", tty, try token(context()), "0")
        let result = ManagedOutputEntry.run(command, factory: factory,
            lookup: { self.identities[$0] }, renderInput: { self.renderData() })
        XCTAssertEqual(result?.code, 0)
        XCTAssertEqual(result?.output, "rendered\n")
        XCTAssertEqual(try read(), Data("\u{1B}]104\u{1B}\\\u{1B}]0;BATCH_TITLE\u{1B}\\".utf8))
        XCTAssertNil(try state.ordinaryBackgroundUnlocked(for: try XCTUnwrap(state.cachedRecords().bindings.first), deadline: .max))
        XCTAssertEqual(nativeCalls, 0)
    }

    func testTypedRenderRejectsMalformedInputAndSupersededSyntheticWithoutBytes() throws {
        let current = context(), text = try token(current)
        var command = args("--managed-render", tty, text, "0")
        let malformed = ManagedOutputEntry.run(command, factory: factory,
            lookup: { self.identities[$0] }, renderInput: { Data("BODY_SENTINEL".utf8) })
        XCTAssertEqual(malformed?.code, 1)
        XCTAssertFalse((malformed?.error ?? "").contains("BODY_SENTINEL"))
        command[6] = "1"
        let stale = ManagedOutputEntry.run(command, factory: factory,
            lookup: { self.identities[$0] }, renderInput: { self.renderData("#123456") })
        XCTAssertEqual(stale?.code, 3)
        noBytes()
    }

    func testInputFailureReportsFixedStageWithoutExceptionDetails() throws {
        let command = args("--managed-render", tty, try token(context()), "0")
        let result = ManagedOutputEntry.run(command, factory: factory,
            lookup: { self.identities[$0] }, renderInput: {
                throw NSError(domain: "BODY_SENTINEL", code: 43,
                              userInfo: [NSLocalizedDescriptionKey: "BODY_SENTINEL"])
            })
        XCTAssertEqual(result?.code, 1)
        XCTAssertEqual(result?.output, "")
        XCTAssertEqual(result?.error, "Managed output unavailable. stage=input failure=other.\n")
        XCTAssertEqual(factoryCalls, 0)
        noBytes()
    }

    func testDeviceFailureReportsStageAndBoundedCodeWithoutItsPrivatePath() throws {
        let runner = MockProcessRunner()
        runner.managedBeforeOpenHandler = { _, _, _, _ in
            throw ProcessRunnerError.deviceIOFailed("BODY_SENTINEL", EIO)
        }
        processRunner = runner
        let command = args("--managed-render", tty, try token(context()), "0")
        let result = ManagedOutputEntry.run(command, factory: factory,
            lookup: { self.identities[$0] }, renderInput: { self.renderData() })
        XCTAssertEqual(result?.code, 1)
        XCTAssertEqual(result?.output, "")
        XCTAssertEqual(result?.error, "Managed output unavailable. stage=write failure=device-io-5.\n")
        noBytes()
    }

    func testCallerTimeoutReportsTheLastEnteredWriterStageWithoutWaitingForTheWorker() throws {
        for phase in ["publication", "open", "prepare"] {
            let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
            let drained = expectation(description: "Expired worker leaves its gated stage")
            let block = {
                entered.signal(); release.wait(); drained.fulfill()
            }
            let actual = SystemProcessRunner(openDevice: { path, flags in
                if phase == "open" { block() }
                return Darwin.open(path, flags)
            })
            let runner = MockProcessRunner()
            runner.managedBeforeOpenHandler = { path, lock, _, _ in
                try actual.writeManagedToDevice(path: path, lockURL: lock,
                    beforeOpen: { _ in if phase == "publication" { block() } }) { _, _ in
                    if phase == "prepare" { block() }
                    return nil
                }
            }
            processRunner = runner
            let command = args("--managed-render", tty, try token(context()), "0")
            let result = ManagedOutputEntry.run(command, factory: factory,
                lookup: { self.identities[$0] }, renderInput: { self.renderData() })
            XCTAssertEqual(entered.wait(timeout: .now()), .success, phase)
            XCTAssertEqual(result?.code, 1)
            XCTAssertEqual(result?.output, "")
            XCTAssertEqual(result?.error,
                "Managed output unavailable. stage=write failure=device-deadline-\(phase).\n")
            release.signal()
            wait(for: [drained], timeout: 1)
            // Observe admission release after late descriptor/lock cleanup, not only callback release.
            try waitForAdmissionRelease()
            noBytes()
        }
    }

    private func waitForAdmissionRelease() throws {
        let until = DispatchTime.now().uptimeNanoseconds + 1_000_000_000
        let lock = try state.lockURL(forTTY: tty)
        while DispatchTime.now().uptimeNanoseconds < until {
            do {
                let painted = try SystemProcessRunner().writeManagedToDevice(path: tty, lockURL: lock) { _, _ in nil }
                XCTAssertFalse(painted)
                return
            } catch ProcessRunnerError.deviceIOFailed(_, EBUSY) { usleep(1_000) }
            catch ProcessRunnerError.deviceWriteTimedOut { usleep(1_000) }
            catch { XCTFail("Admission cleanup failed: \(error)"); return }
        }
        XCTFail("Expired worker did not release admission")
    }

    private func observe(_ context: OrganizerContext) throws {
        try state.publishObservation(TerminalObservation(tty: tty, device: device,
            producer: context.producer, provider: context.provider, verifiedAgent: true,
            state: "complete", event: "Stop", deliveryID: context.deliveryID,
            responseID: nil, observedAt: context.observedAt))
    }

    private func read() throws -> Data {
        var ready = pollfd(fd: master, events: Int16(POLLIN), revents: 0)
        guard poll(&ready, 1, 1_000) == 1 else { throw POSIXError(.ETIMEDOUT) }
        var bytes = [UInt8](repeating: 0, count: 4_096)
        let count = Darwin.read(master, &bytes, bytes.count)
        guard count >= 0 else { throw POSIXError(.EIO) }
        return Data(bytes.prefix(count))
    }

    private func noBytes() {
        var ready = pollfd(fd: master, events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&ready, 1, 10), 0)
    }

    func testUnrelatedFlagsDoNotCreateFactory() {
        XCTAssertNil(run(["TAVSApp", "--validate-config", "--unknown-capabilities"]))
        XCTAssertNil(run(["TAVSApp", "--other"]))
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertEqual(nativeCalls, 0)
    }

    func testExactCapabilityQueryIsSafeBeforeIsolatedEnvironmentOrFactory() {
        let query = ["TAVSApp", "--validate-config", "--managed-output-capabilities"]
        let result = run(query, env: ["TAVS_SESSIONS_TEST_ROOT": "INVALID_BODY_SENTINEL"])
        XCTAssertEqual(result?.code, 0)
        XCTAssertEqual(result?.output, "tavs-managed-output-schema=1\n")
        XCTAssertEqual(result?.error, "")
        XCTAssertEqual(run(query + ["BODY_SENTINEL"])?.code, 1)
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertEqual(nativeCalls, 0)
    }

    func testMalformedManagedArgumentsUseFixedPrivateErrors() {
        for command in [args("--managed-unknown", "BODY_SENTINEL"),
                        args("--managed-register", tty, "BODY_SENTINEL"),
                        args("--managed-background", tty, "BODY_SENTINEL", "#123456", "2"),
                        ["TAVSApp", "--visual-recover", "BODY_SENTINEL", runtime.path, "recover"]] {
            let result = run(command)
            XCTAssertEqual(result?.code, 1)
            XCTAssertFalse((result?.output ?? "").contains("BODY_SENTINEL"))
            XCTAssertFalse((result?.error ?? "").contains("BODY_SENTINEL"))
        }
        XCTAssertEqual(factoryCalls, 0)
        noBytes()
    }

    func testPrivateRootSafetyPrecedesPersistenceButScopeFailureFollowsIt() throws {
        let unsafe = ["TAVS_SESSIONS_TEST_ROOT": root.appendingPathComponent("other-root").path,
                      "TAVS_SESSIONS_TEST_TARGETS": "[]"]
        XCTAssertEqual(run(args("--visual-recover", "recover"), env: unsafe)?.code, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        let scopeMissing = ["TAVS_SESSIONS_TEST_ROOT": root.path]
        let result = run(args("--visual-recover", "recover"), env: scopeMissing)
        XCTAssertEqual(result?.code, 1)
        XCTAssertEqual(VisualRestrictionsStateStore(url: marker).read(), .suspended)
        XCTAssertEqual(factoryCalls, 0)
        noBytes()
    }

    func testFactoryFailureStillReportsSavedSuspension() throws {
        failFactory = true
        let result = try XCTUnwrap(run(args("--visual-recover", "recover")))
        XCTAssertEqual(result.code, 1)
        XCTAssertEqual(VisualRestrictionsStateStore(url: marker).read(), .suspended)
        let report = try JSONDecoder().decode(VisualRecoveryReport.self, from: Data(result.output.utf8))
        XCTAssertTrue(report.stateSaved)
        XCTAssertTrue(report.hasFailures)
        XCTAssertEqual(report.items.first?.reason,
                       "Managed restoration unavailable. stage=setup failure=target.")
        XCTAssertEqual(nativeCalls, 0)
        noBytes()
    }

    func testRegisterAuthenticatesAncestryCachesWithoutPaintAndCurrentDoesNotChangeMarker() throws {
        try VisualRestrictionsStateStore(url: marker).write(suspended: false)
        let saved = try Data(contentsOf: marker)
        XCTAssertEqual(run(args("--managed-register", tty, "20"))?.code, 0)
        XCTAssertEqual(state.cachedRecords().bindings.count, 1)
        noBytes()
        XCTAssertEqual(run(args("--managed-current", tty, "20"))?.code, 0)
        XCTAssertEqual(try Data(contentsOf: marker), saved)
        noBytes()
    }

    func testUnrelatedCallerAndMismatchedDeviceCannotCreateFactory() {
        identities[30] = identity(30, parent: 1, device: device)
        XCTAssertEqual(run(args("--managed-register", tty, "30"))?.code, 1)
        identities[20] = identity(20, parent: 10, device: UInt32.max)
        XCTAssertEqual(run(args("--managed-register", tty, "20"))?.code, 1)
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertTrue(state.cachedRecords().bindings.isEmpty)
        noBytes()
    }

    func testLiveOrdinaryContextProducesOnlyTypedBackground() throws {
        XCTAssertEqual(run(args("--managed-background", tty, try token(context()), "#abcdef", "0"))?.code, 0)
        XCTAssertEqual(try read(), Data("\u{1B}]11;#ABCDEF\u{1B}\\".utf8))
        XCTAssertEqual(nativeCalls, 0)
    }

    func testReusedContextGenerationIsStaleAndNeverPaints() throws {
        let token = try token(context())
        identities[10] = ProcessIdentity(generation: ProcessGeneration(pid: 10, startSeconds: 2,
            startMicroseconds: 1), parentPID: 1, group: 10, device: device, foregroundGroup: 10)
        XCTAssertEqual(run(args("--managed-background", tty, token, "#123456", "0"))?.code, 3)
        XCTAssertEqual(factoryCalls, 0)
        noBytes()
    }

    func testSyntheticOrphanNeedsCurrentMatchingObservation() throws {
        let context = context(), token = try token(context)
        identities[getpid()] = identity(getpid(), parent: 1, device: UInt32.max)
        XCTAssertEqual(run(args("--managed-background", tty, token, "#123456", "0"))?.code, 1)
        XCTAssertEqual(run(args("--managed-background", tty, token, "#123456", "1"))?.code, 3)
        noBytes()
        try observe(context)
        XCTAssertEqual(run(args("--managed-background", tty, token, "#123456", "1"))?.code, 0)
        XCTAssertEqual(try read(), Data("\u{1B}]11;#123456\u{1B}\\".utf8))
    }

    func testForcedResetIsTypedSyntheticAndRejectsUnsafeTitle() throws {
        let context = context(), token = try token(context)
        XCTAssertEqual(run(args("--managed-forced-reset", tty, token, "fixture title"))?.code, 3)
        noBytes()
        try observe(context)
        XCTAssertEqual(run(args("--managed-forced-reset", tty, token, "fixture title"))?.code, 0)
        let bytes = try read()
        XCTAssertTrue(bytes.starts(with: Data("\u{1B}]104\u{07}".utf8)))
        XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains("fixture title"))
        let result = run(args("--managed-forced-reset", tty, token, "\u{1B}BODY_SENTINEL"))
        XCTAssertEqual(result?.code, 1)
        XCTAssertFalse((result?.error ?? "").contains("BODY_SENTINEL"))
        noBytes()
    }

    func testForcedResetClearsExitedProducerThroughItsContinuingOwner() throws {
        let value = context(pid: 20)
        let text = try token(value)
        try observe(value)
        XCTAssertEqual(run(args("--managed-background", tty, text, "#123456", "1"))?.code, 0)
        _ = try read()
        XCTAssertEqual(state.cachedRecords().bindings.first?.ttyOwner, generation(10))
        identities.removeValue(forKey: 20)
        XCTAssertEqual(run(args("--managed-forced-reset", tty, text, "fixture directory"))?.code, 0)
        XCTAssertEqual(try read(), Data("\u{1B}]104\u{07}\u{1B}]111\u{1B}\\\u{1B}]0;fixture directory\u{1B}\\".utf8))
        let target = try XCTUnwrap(state.cachedRecords().bindings.first)
        XCTAssertEqual(try state.ordinaryBackgroundUnlocked(for: target, deadline: .max), "reset")
    }

    func testExitedProducerResetCannotOverrideNewDeliveryOrReusedOwner() throws {
        let value = context(pid: 20)
        let text = try token(value)
        try observe(value)
        XCTAssertEqual(run(args("--managed-background", tty, text, "#123456", "1"))?.code, 0)
        _ = try read()
        identities.removeValue(forKey: 20)
        identities[10] = ProcessIdentity(generation: ProcessGeneration(pid: 10, startSeconds: 2,
            startMicroseconds: 1), parentPID: 1, group: 10, device: device, foregroundGroup: 10)
        XCTAssertNotEqual(run(args("--managed-forced-reset", tty, text, "old directory"))?.code, 0)
        noBytes()
        identities[10] = identity(10, parent: 1, device: device)
        let latest = context(delivery: "new-delivery")
        try observe(latest)
        XCTAssertEqual(run(args("--managed-forced-reset", tty, text, "old directory"))?.code, 3)
        noBytes()
    }

    func testExitedProducerResetRequiresItsPreviouslyBoundIntent() throws {
        let value = context(pid: 20), text = try token(value)
        try observe(value)
        XCTAssertEqual(run(args("--managed-register", tty, "20"))?.code, 0)
        identities.removeValue(forKey: 20)
        XCTAssertEqual(run(args("--managed-forced-reset", tty, text, "old directory"))?.code, 3)
        noBytes()
        identities[getpid()] = identity(getpid(), parent: 10, device: UInt32.max)
        let fresh = try token(context(delivery: "standalone-background"))
        XCTAssertEqual(run(args("--managed-background", tty, fresh, "#778899", "0"))?.code, 0)
        _ = try read()
        XCTAssertEqual(run(args("--managed-forced-reset", tty, text, "old directory"))?.code, 3)
        noBytes()
    }

    func testCheckContextValidatesWithoutPublishingIntentOrPainting() throws {
        let context = context(), token = try token(context)
        identities[getpid()] = identity(getpid(), parent: 1, device: UInt32.max)
        XCTAssertEqual(run(args("--managed-check-context", tty, token))?.code, 3)
        try observe(context)
        let existing = try FileManager.default.contentsOfDirectory(atPath: runtime.appendingPathComponent("organizer").path)
        XCTAssertEqual(run(args("--managed-check-context", tty, token))?.code, 0)
        let final = try FileManager.default.contentsOfDirectory(atPath: runtime.appendingPathComponent("organizer").path)
        XCTAssertEqual(final.filter { $0.hasPrefix("intent-") }, existing.filter { $0.hasPrefix("intent-") })
        noBytes()
    }

    func testReconcileUsesExactCachedOtherTTYWithoutGuessingNativeTargets() throws {
        XCTAssertEqual(run(args("--managed-register", tty, "20"))?.code, 0)
        identities[20] = identity(20, parent: 10, device: 7)
        nativeCalls = 0
        XCTAssertEqual(run(args("--managed-reconcile", tty, "20"))?.code, 0)
        XCTAssertEqual(nativeCalls, 0)
        XCTAssertEqual(try read(), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{1B}\\".utf8))
    }

    func testExplicitScopedCachedNativeBindingDoesNotBroadenToOwnerOnly() throws {
        let row = surface()
        let env = ["TAVS_SESSIONS_TEST_ROOT": root.path,
                   "TAVS_SESSIONS_TEST_TARGETS": String(decoding: try JSONEncoder().encode([row.id]), as: UTF8.self)]
        XCTAssertEqual(run(args("--managed-register", tty, "20"), env: env)?.code, 1)
        noBytes()
        let target = try XCTUnwrap(state.captureTarget(for: row))
        _ = try SystemProcessRunner().writeManagedToDevice(path: tty, lockURL: state.lockURL(forTTY: tty)) { _, deadline in
            try self.state.cacheTargetUnlocked(target, deadline: deadline)
            return nil
        }
        nativeCalls = 0
        XCTAssertEqual(run(args("--managed-register", tty, "20"), env: env)?.code, 0)
        XCTAssertEqual(nativeCalls, 0)
        noBytes()
    }

    func testFixtureStillRequiresExplicitAllowlistBeforeFactoryAndCannotReachRealCatalogue() throws {
        let fixture = root.appendingPathComponent("fixture.json")
        try Data("{}".utf8).write(to: fixture)
        let env = ["TAVS_SESSIONS_TEST_ROOT": root.path, "TAVS_SESSIONS_TEST_FIXTURE": fixture.path]
        XCTAssertEqual(run(args("--managed-register", tty, "20"), env: env)?.code, 1)
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertEqual(nativeCalls, 0)
        noBytes()
    }

    func testRecoverReturnsHonestReportAndDoesNotReplayTitles() throws {
        XCTAssertEqual(run(args("--managed-register", tty, "20"))?.code, 0)
        let result = try XCTUnwrap(run(args("--visual-recover", "recover")))
        let report = try JSONDecoder().decode(VisualRecoveryReport.self, from: Data(result.output.utf8))
        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(report.stateSaved)
        XCTAssertEqual(report.items.filter { $0.status == .restored }.count, 1)
        XCTAssertEqual(try read(), Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{07}".utf8))
        XCTAssertEqual(VisualRestrictionsStateStore(url: marker).read(), .suspended)
        XCTAssertEqual(run(args("--visual-recover", "resume"))?.code, 0)
        _ = try read()
        XCTAssertEqual(VisualRestrictionsStateStore(url: marker).read(), .active)
    }
}
