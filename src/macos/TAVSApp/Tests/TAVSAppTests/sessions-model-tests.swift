import XCTest
import Combine
@testable import TAVSApp

final class SessionsModelTests: XCTestCase {
    private var directory: URL!
    private var store: URL { directory.appendingPathComponent("priorities.json") }
    private let instance = ProcessGeneration(pid: 43, startSeconds: 1, startMicroseconds: 1)

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func surface(_ id: String, application: ProcessGeneration? = nil, tab: String = "tab") -> GhosttySurface {
        GhosttySurface(id: GhosttySurfaceID(application: application ?? instance, terminalID: id),
                       windowID: "window", tabID: tab, title: "Duplicate title", directory: "/same",
                       tty: "/dev/ttys\(id)", foregroundPID: 43, tabSelected: true, mappingIssue: nil)
    }

    private func model(_ surfaces: [GhosttySurface], timers: TimerScheduler = MockTimerScheduler(),
                       navigate: @escaping (GhosttySurface, @escaping (Result<Void, Error>) -> Void) -> Void = { _, done in done(.success(())) }) -> SessionsModel {
        SessionsModel(prioritiesURL: store, refresh: { done in done(.success(surfaces)) },
                      navigate: navigate, timerScheduler: timers)
    }

    func testPrioritiesSurviveTAVSRestartAndSortStably() {
        let original = [surface("001"), surface("002"), surface("003")]
        let first = model(original)
        first.refresh()
        first.setPriority(.low, for: [original[0].id])
        first.setPriority(.high, for: [original[2].id])
        XCTAssertEqual(first.rows.map(\.id), [original[2].id, original[1].id, original[0].id])
        let restarted = model(original)
        restarted.refresh()
        XCTAssertEqual(restarted.priority(for: original[2].id), .high)
        XCTAssertEqual(restarted.priority(for: original[0].id), .low)
        XCTAssertEqual(restarted.rows.map(\.id), first.rows.map(\.id))
    }

    func testNewSurfacesAndNewGhosttyGenerationAreNormal() {
        let old = surface("001")
        let first = model([old]); first.refresh(); first.setPriority(.high, for: [old.id])
        let newer = ProcessGeneration(pid: 43, startSeconds: 2, startMicroseconds: 1)
        let replacement = surface("001", application: newer)
        let newSurface = surface("002", application: newer)
        let restarted = model([replacement, newSurface]); restarted.refresh()
        XCTAssertEqual(restarted.priority(for: replacement.id), .normal)
        XCTAssertEqual(restarted.priority(for: newSurface.id), .normal)
    }

    func testMovementRetainsPriorityAndSelectionDoesNotNavigate() {
        let old = surface("001")
        var response = [old]; var calls = 0
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(.success(response)) },
                                  navigate: { _, done in calls += 1; done(.success(())) })
        model.refresh(); model.setPriority(.high, for: [old.id]); model.selection = [old.id]
        response = [surface("001", tab: "moved")]; model.refresh()
        XCTAssertEqual(model.priority(for: old.id), .high)
        XCTAssertEqual(model.selection, [old.id])
        XCTAssertEqual(calls, 0)
        model.goTo(old.id)
        XCTAssertEqual(calls, 1)
    }

    func testFailedRefreshPreservesDataButDisablesNavigation() throws {
        let row = surface("001"); var response: Result<[GhosttySurface], Error> = .success([row])
        var calls = 0
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(response) },
                                  navigate: { _, done in calls += 1; done(.success(())) })
        model.refresh(); model.setPriority(.high, for: [row.id])
        let saved = try Data(contentsOf: store)
        response = .failure(GhosttyCatalogError.permissionDenied); model.refresh(); model.goTo(row.id)
        XCTAssertEqual(model.rows.count, 1)
        XCTAssertFalse(model.catalogueAvailable)
        XCTAssertEqual(try Data(contentsOf: store), saved)
        XCTAssertEqual(model.priority(for: row.id), .high)
        XCTAssertEqual(calls, 0)
    }

    func testSuccessfulEmptyCatalogueClearsClosedRowsPrioritiesAndSelection() throws {
        let row = surface("001"); var response = [row]
        var navigation = 0
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(.success(response)) },
            navigate: { _, done in navigation += 1; done(.success(())) })
        model.refresh(); model.setPriority(.high, for: [row.id]); model.selection = [row.id]
        response = []; model.refresh(); model.goTo(row.id)
        XCTAssertTrue(model.catalogueAvailable)
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertTrue(model.selection.isEmpty)
        XCTAssertTrue(model.priorities.isEmpty)
        XCTAssertEqual(navigation, 0)
        let restarted = self.model([row]); restarted.refresh()
        XCTAssertEqual(restarted.priority(for: row.id), .normal)
    }

    private func focus(_ clock: VirtualClock) -> FocusController {
        let restrictions = VisualRestrictionsStateStore(url: directory.appendingPathComponent("visual-restrictions.state"))
        let state = TerminalVisualStateStore(runtimeDirectory: directory.appendingPathComponent("runtime"),
            clock: clock, lookup: { _ in nil }, device: { _ in nil })
        let recovery = VisualRecovery(runtimeDirectory: directory.appendingPathComponent("runtime"),
            restrictions: restrictions, state: state,
            policy: VisualRestrictionPolicy(restrictions: restrictions,
                muteURL: directory.appendingPathComponent("mute.state"),
                lockURL: directory.appendingPathComponent("lock.state"), clock: clock),
            processRunner: MockProcessRunner(), clock: clock, controller: instance, nativeSnapshot: { [] })
        return FocusController(state: state, recovery: recovery, restrictions: restrictions,
            timers: MockTimerScheduler(), clock: clock,
            colors: { _ in TerminalRenderer.Colors(background: "#171717", foreground: "#EEEEEE")! })
    }

    func testSuccessfulEmptyCatalogueEndsLastManualWorkingSet() {
        let clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000)), focus = focus(clock)
        let row = surface("001"); var response = [row]
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(.success(response)) },
            navigate: { _, done in done(.success(())) }, timerScheduler: MockTimerScheduler(),
            clock: clock, focus: focus)
        model.refresh(); model.selection = [row.id]; model.focusSelected()
        XCTAssertEqual(model.focusMode, .manual)
        XCTAssertTrue(model.isInWorkingSet(row.id))
        response = []; model.refresh()
        XCTAssertEqual(model.focusMode, .off)
        XCTAssertFalse(model.isInWorkingSet(row.id))
        XCTAssertFalse(model.canEnableAutomatic)
    }

    func testSuccessfulEmptyCatalogueClearsClosedCuesWhileAutomaticStaysArmed() {
        let clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000)), focus = focus(clock)
        let row = surface("001"); var response = [row]
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(.success(response)) },
            navigate: { _, done in done(.success(())) }, timerScheduler: MockTimerScheduler(),
            clock: clock, focus: focus)
        model.refresh(); model.setPriority(.high, for: [row.id]); model.enableAutomatic()
        clock.advance(by: 1)
        let record = TerminalObservation(tty: row.tty!, device: 123, producer: instance,
            provider: "claude", verifiedAgent: true, state: "complete", event: "Stop",
            deliveryID: "new-completion", responseID: nil, observedAt: 1_001)
        focus.acceptCatalogue([row], high: [row.id], coverage: [row.id: TerminalVisualCoverage(
            observation: record, intent: nil, attentionEligible: true, status: "Agent observation.")])
        XCTAssertEqual(model.cueCount(for: row.id), 1)
        response = []; model.refresh()
        XCTAssertEqual(model.cueCount(for: row.id), 0)
        XCTAssertEqual(model.focusMode, .automatic)
    }

    func testConfirmedClosureReconcilesStoredPriorityAndSelection() {
        let a = surface("001"), b = surface("002")
        var response = [a,b]
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(.success(response)) },
                                  navigate: { _, done in done(.success(())) })
        model.refresh(); model.setPriority(.high, for: [a.id]); model.selection = [a.id]
        response = [b]; model.refresh()
        XCTAssertEqual(model.rows.map(\.id), [b.id])
        XCTAssertEqual(model.priority(for: a.id), .normal)
        XCTAssertTrue(model.selection.isEmpty)
        response = [a,b]; model.refresh()
        XCTAssertEqual(model.priority(for: a.id), .normal)
    }

    func testMalformedPriorityFileIsPreservedAndEditsAreRejected() throws {
        let bytes = Data("not a priority record".utf8); try bytes.write(to: store)
        let row = surface("001"); let model = model([row]); model.refresh()
        model.setPriority(.high, for: [row.id])
        XCTAssertNotNil(model.priorityStorageError)
        XCTAssertEqual(model.priority(for: row.id), .normal)
        XCTAssertEqual(try Data(contentsOf: store), bytes)
    }

    func testFailedSaveDoesNotOptimisticallyChangePriority() throws {
        let file = directory.appendingPathComponent("not-directory"); try Data().write(to: file)
        let row = surface("001")
        let model = SessionsModel(prioritiesURL: file.appendingPathComponent("priorities"),
                                  refresh: { $0(.success([row])) }, navigate: { _, done in done(.success(())) })
        model.refresh(); model.setPriority(.high, for: [row.id])
        XCTAssertEqual(model.priority(for: row.id), .normal)
        XCTAssertNotNil(model.priorityStorageError)
    }

    func testRefreshTimerUsesItsOwnOwnerAndStopsWhenClosed() {
        let timers = MockTimerScheduler(), global = MockTimerScheduler()
        var calls = 0
        let model = SessionsModel(prioritiesURL: store,
                                  refresh: { calls += 1; $0(.success([self.surface("001")])) },
                                  navigate: { _, done in done(.success(())) }, timerScheduler: timers)
        model.opened(); model.opened()
        XCTAssertEqual(timers.scheduledTimers.count, 1)
        XCTAssertEqual(timers.scheduledTimers.first?.delay, 2)
        global.cancelAll(); timers.fireAll()
        XCTAssertEqual(calls, 2)
        model.closed()
        XCTAssertTrue(timers.scheduledTimers.isEmpty)
    }

    func testUnavailableMappingNeverNavigates() {
        var row = surface("001"); row.mappingIssue = .ambiguousTTY
        var calls = 0
        let model = model([row], navigate: { _, done in calls += 1; done(.success(())) })
        model.refresh(); model.goTo(row.id)
        XCTAssertEqual(calls, 0)
    }

    func testSuspensionStatusUpdatesBeforeInFlightNativeGuardAndSurvivesNativeFailure() throws {
        let row = surface("001")
        let restrictions = VisualRestrictionsStateStore(url: directory.appendingPathComponent("persistent/visual-restrictions.state"))
        var calls = 0
        var navigation = 0
        var finish: ((Result<[GhosttySurface], Error>) -> Void)?
        let model = SessionsModel(prioritiesURL: store, refresh: { calls += 1; finish = $0 },
            navigate: { _, done in navigation += 1; done(.success(())) }, visualRestrictionsState: restrictions)
        model.selection = [row.id]
        model.refresh()
        XCTAssertTrue(model.refreshing)
        XCTAssertEqual(model.visualRestrictionsStatus, .active)
        try restrictions.write(suspended: true)
        model.refresh()
        XCTAssertEqual(model.visualRestrictionsStatus, .suspended)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.selection, [row.id])
        XCTAssertTrue(model.visualCoverage.isEmpty)
        finish?(.failure(GhosttyCatalogError.permissionDenied))
        XCTAssertFalse(model.catalogueAvailable)
        XCTAssertEqual(model.visualRestrictionsStatus, .suspended)
        try restrictions.write(suspended: false)
        model.refresh()
        XCTAssertEqual(model.visualRestrictionsStatus, .active)
        XCTAssertEqual(calls, 2)
        finish?(.failure(GhosttyCatalogError.permissionDenied))
        try Data("SCHEMA_VERSION=\"77\"\nSUSPENDED=\"false\"\n".utf8).write(to: restrictions.url)
        model.refresh()
        XCTAssertEqual(model.visualRestrictionsStatus, .unavailable)
        XCTAssertEqual(model.selection, [row.id])
        XCTAssertEqual(navigation, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path))
        finish?(.success([]))
    }

    func testFreshCataloguePublishesCorrelatedCoverageOnMainAfterBackgroundReads() throws {
        let row = surface("001")
        let clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
        let producer = ProcessGeneration(pid: 44, startSeconds: 1, startMicroseconds: 1)
        let lookup: (Int32) -> ProcessIdentity? = { pid in
            XCTAssertFalse(Thread.isMainThread)
            let generation = pid == 43 ? self.instance : producer
            return ProcessIdentity(generation: generation, parentPID: 1, group: 43,
                                   device: 123, foregroundGroup: 43)
        }
        let visual = TerminalVisualStateStore(runtimeDirectory: directory.appendingPathComponent("runtime"),
                                              clock: clock, lookup: lookup, device: { _ in 123 })
        let observation = TerminalObservation(tty: row.tty!, device: 123, producer: producer,
            provider: "claude", verifiedAgent: true, state: "complete", event: "Stop",
            deliveryID: "delivery-44", responseID: nil, observedAt: 998)
        try visual.publishObservation(observation)
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(.success([row])) },
            navigate: { _, done in done(.success(())) }, clock: clock, visualState: visual)
        let finished = expectation(description: "Main coverage publication finished")
        let token = model.$refreshing.dropFirst().sink { refreshing in
            if !refreshing { XCTAssertTrue(Thread.isMainThread); finished.fulfill() }
        }
        model.refresh()
        XCTAssertTrue(model.refreshing)
        XCTAssertTrue(model.visualCoverage.isEmpty)
        wait(for: [finished], timeout: 2)
        withExtendedLifetime(token) {}
        XCTAssertFalse(model.refreshing)
        XCTAssertEqual(model.visualCoverage[row.id]?.observation, observation)
        XCTAssertTrue(model.visualCoverage[row.id]?.attentionEligible == true)
    }

    func testCatalogueFailureRetainsDisplayButDisablesAttentionAndDoesNotAdoptNewProducer() throws {
        let row = surface("001")
        let clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
        let producer = ProcessGeneration(pid: 44, startSeconds: 1, startMicroseconds: 1)
        let other = ProcessGeneration(pid: 45, startSeconds: 1, startMicroseconds: 1)
        let identities = [instance, producer, other].map {
            ProcessIdentity(generation: $0, parentPID: 1, group: 43, device: 123, foregroundGroup: 43)
        }
        let runtime = directory.appendingPathComponent("runtime")
        let visual = TerminalVisualStateStore(runtimeDirectory: runtime, clock: clock,
            lookup: { pid in identities.first { $0.generation.pid == pid } }, device: { _ in 123 })
        var observation = TerminalObservation(tty: row.tty!, device: 123, producer: producer,
            provider: "claude", verifiedAgent: true, state: "permission", event: "PermissionRequest",
            deliveryID: "permission-44", responseID: nil, observedAt: 998)
        try visual.publishObservation(observation)
        var response: Result<[GhosttySurface], Error> = .success([row])
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(response) },
            navigate: { _, done in done(.success(())) }, clock: clock, visualState: visual)
        let finished = expectation(description: "Initial coverage publication finished")
        let token = model.$refreshing.dropFirst().sink { refreshing in
            if !refreshing { finished.fulfill() }
        }
        model.refresh()
        wait(for: [finished], timeout: 2)
        token.cancel()
        XCTAssertTrue(model.visualCoverage[row.id]?.attentionEligible == true)
        observation.producer = other
        observation.deliveryID = "new-permission-45"
        observation.observedAt = 999
        try visual.publishObservation(observation)
        response = .failure(GhosttyCatalogError.permissionDenied)
        model.refresh()
        XCTAssertFalse(model.refreshing)
        XCTAssertFalse(model.catalogueAvailable)
        XCTAssertEqual(model.visualCoverage[row.id]?.observation?.deliveryID, "permission-44")
        XCTAssertFalse(model.visualCoverage[row.id]?.attentionEligible == true)
        XCTAssertTrue(model.visualCoverage[row.id]?.status.lowercased().contains("last-known") == true)
        let files = try FileManager.default.contentsOfDirectory(atPath: runtime.appendingPathComponent("organizer").path)
        XCTAssertEqual(files.filter { $0.hasPrefix("adoption-") }.count, 1)
    }

    func testFailedAndEmptyCatalogueDoNotReadOrAdoptRecords() throws {
        let row = surface("001")
        let clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
        var inspected = 0
        let runtime = directory.appendingPathComponent("runtime")
        let visual = TerminalVisualStateStore(runtimeDirectory: runtime, clock: clock,
            lookup: { _ in inspected += 1; return nil }, device: { _ in 123 })
        try visual.publishObservation(TerminalObservation(tty: row.tty!, device: 123, producer: instance,
            provider: "claude", verifiedAgent: true, state: "complete", event: "Stop",
            deliveryID: "unadopted-43", responseID: nil, observedAt: 998))
        for response in [Result<[GhosttySurface], Error>.failure(GhosttyCatalogError.permissionDenied), .success([])] {
            let model = SessionsModel(prioritiesURL: store, refresh: { $0(response) },
                navigate: { _, done in done(.success(())) }, clock: clock, visualState: visual)
            model.refresh()
            XCTAssertFalse(model.refreshing)
            if case .success = response { XCTAssertTrue(model.catalogueAvailable) }
            else { XCTAssertFalse(model.catalogueAvailable) }
            XCTAssertTrue(model.visualCoverage.isEmpty)
            XCTAssertEqual(inspected, 0)
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: runtime.appendingPathComponent("organizer").path)
        XCTAssertFalse(files.contains { $0.hasPrefix("adoption-") })
    }

    func testIsolatedLaunchRejectsIncompletePersonalAndEscapingRoots() throws {
        XCTAssertThrowsError(try IsolatedSessionsLaunch.environment([:]))
        XCTAssertThrowsError(try IsolatedSessionsLaunch.environment(["TAVS_SESSIONS_TEST_ROOT": "/Users/cs/.tavs"]))
        XCTAssertThrowsError(try IsolatedSessionsLaunch.environment(["TAVS_SESSIONS_TEST_ROOT": directory.path]))
        let outside = directory.deletingLastPathComponent().appendingPathComponent("outside-\(UUID().uuidString)")
        try Data().write(to: outside); defer { try? FileManager.default.removeItem(at: outside) }
        XCTAssertThrowsError(try IsolatedSessionsLaunch.environment([
            "TAVS_SESSIONS_TEST_ROOT": directory.path, "TAVS_SESSIONS_TEST_FIXTURE": outside.path
        ]))
    }

    func testIsolatedFixtureUsesOnlyPrivatePriorityStoreAndModel() throws {
        let fixture = directory.appendingPathComponent("fixture.json")
        let payload: [String: Any] = [
            "application": ["pid": 43, "startSeconds": 1, "startMicroseconds": 1],
            "surfaces": [["terminalID":"fixture", "tabID":"tab", "windowID":"window", "tty":"/dev/ttys900"]]
        ]
        try JSONSerialization.data(withJSONObject: payload).write(to: fixture)
        try VisualRestrictionsStateStore(url: directory.appendingPathComponent("home/.tavs/visual-restrictions.state"))
            .write(suspended: true)
        let launch = try IsolatedSessionsLaunch.environment([
            "TAVS_SESSIONS_TEST_ROOT": directory.path, "TAVS_SESSIONS_TEST_FIXTURE": fixture.path
        ])
        let model = launch.model()
        XCTAssertEqual(model.visualRestrictionsStatus, .suspended)
        let finished = expectation(description: "Private fixture coverage published")
        let token = model.$refreshing.dropFirst().sink { if !$0 { finished.fulfill() } }
        model.refresh()
        wait(for: [finished], timeout: 2)
        withExtendedLifetime(token) {}
        let id = try XCTUnwrap(model.rows.first?.id)
        model.setPriority(.high, for: [id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("surface-priorities.json").path))
        XCTAssertEqual(model.priority(for: id), .high)
    }

    func testIsolatedLaunchAcceptsTheSystemTemporaryAlias() throws {
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("tavs-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = root.appendingPathComponent("fixture.json")
        try Data("{}".utf8).write(to: fixture)
        let launch = try IsolatedSessionsLaunch.environment([
            "TAVS_SESSIONS_TEST_ROOT": root.path, "TAVS_SESSIONS_TEST_FIXTURE": fixture.path
        ])
        XCTAssertEqual(launch.root.path, root.resolvingSymlinksInPath().path)
    }

    func testFixtureRecoveryDerivesScopeAndPreservesExplicitAllowlist() throws {
        let fixture = directory.appendingPathComponent("fixture.json")
        let payload: [String: Any] = [
            "application": ["pid": 43, "startSeconds": 1, "startMicroseconds": 1],
            "surfaces": ["one", "two"].map { ["terminalID": $0, "tabID": "tab", "windowID": "window"] }
        ]
        try JSONSerialization.data(withJSONObject: payload).write(to: fixture)
        var values = ["TAVS_SESSIONS_TEST_ROOT": directory.path, "TAVS_SESSIONS_TEST_FIXTURE": fixture.path]
        let all = try IsolatedSessionsLaunch.environment(values).recoveryEnvironment(values)
        let decode: (String) throws -> Set<GhosttySurfaceID> = {
            Set(try JSONDecoder().decode([GhosttySurfaceID].self, from: Data($0.utf8)))
        }
        XCTAssertEqual(try decode(all["TAVS_SESSIONS_TEST_TARGETS"]!), [surface("one").id, surface("two").id])
        values["TAVS_SESSIONS_TEST_TARGETS"] = String(data: try JSONEncoder().encode([surface("one").id]), encoding: .utf8)
        let launch = try IsolatedSessionsLaunch.environment(values)
        XCTAssertEqual(try launch.fixtureSnapshot().map(\.id), [surface("one").id])
        XCTAssertEqual(try decode(launch.recoveryEnvironment(values)["TAVS_SESSIONS_TEST_TARGETS"]!), [surface("one").id])
        values["TAVS_SESSIONS_TEST_TARGETS"] = "[]"
        XCTAssertThrowsError(try IsolatedSessionsLaunch.environment(values))
    }

    func testMissingRecoveryActionStillPersistsSuspensionAndExplicitResume() {
        let restrictions = VisualRestrictionsStateStore(url: directory.appendingPathComponent("visual-restrictions.state"))
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(.success([])) },
            navigate: { _, done in done(.success(())) }, visualRestrictionsState: restrictions)
        model.selection = [surface("one").id]
        model.restoreVisibility()
        XCTAssertEqual(restrictions.read(), .suspended)
        XCTAssertEqual(model.visualRestrictionsStatus, .suspended)
        XCTAssertTrue(model.recoveryStatus?.contains("Recovery incomplete") == true)
        XCTAssertFalse(model.recovering)
        model.restoreVisibility(resume: true)
        XCTAssertEqual(restrictions.read(), .active)
        XCTAssertEqual(model.selection, [surface("one").id])
    }
}
