import XCTest
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

    func testEmptyAndFailedRefreshPreserveDataButDisableNavigation() throws {
        let row = surface("001"); var response: Result<[GhosttySurface], Error> = .success([row])
        var calls = 0
        let model = SessionsModel(prioritiesURL: store, refresh: { $0(response) },
                                  navigate: { _, done in calls += 1; done(.success(())) })
        model.refresh(); model.setPriority(.high, for: [row.id])
        let saved = try Data(contentsOf: store)
        response = .success([]); model.refresh(); model.goTo(row.id)
        XCTAssertEqual(model.rows.count, 1)
        XCTAssertFalse(model.catalogueAvailable)
        XCTAssertEqual(try Data(contentsOf: store), saved)
        response = .failure(GhosttyCatalogError.permissionDenied); model.refresh()
        XCTAssertFalse(model.catalogueAvailable)
        XCTAssertEqual(model.priority(for: row.id), .high)
        XCTAssertEqual(calls, 0)
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
        let launch = try IsolatedSessionsLaunch.environment([
            "TAVS_SESSIONS_TEST_ROOT": directory.path, "TAVS_SESSIONS_TEST_FIXTURE": fixture.path
        ])
        let model = launch.model(); model.refresh()
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
}
