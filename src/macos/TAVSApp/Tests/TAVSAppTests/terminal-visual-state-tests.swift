import XCTest
import Darwin
@testable import TAVSApp

final class TerminalVisualStateTests: XCTestCase {
    private var root: URL!
    private var records: [Int32: ProcessIdentity] = [:]
    private var devices: [String: UInt32] = [:]
    private var clock: VirtualClock!
    private let tty = "/dev/ttys043"

    override func setUpWithError() throws {
        let isolated = try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"])
        root = URL(fileURLWithPath: isolated).appendingPathComponent("records-\(UUID().uuidString)")
        clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
        records = [10: identity(10), 11: identity(11)]
        devices = [tty: 123]
    }

    func testExactAdoptionPersistsAcrossStoreRestart() throws {
        let store = makeStore()
        let observed = observation()
        try store.publishObservation(observed)
        try store.publishIntent(intent())
        let coverage = store.coverage(for: surface())
        XCTAssertEqual(coverage.observation, observed)
        XCTAssertEqual(coverage.intent?.background, "#123ABC")
        XCTAssertTrue(coverage.attentionEligible)
        XCTAssertEqual(makeStore().coverage(for: surface()).observation, observed)
    }

    func testMissingAndAmbiguousNativeMappingCannotAdopt() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        var missing = surface()
        missing.mappingIssue = .missingTTY
        var ambiguous = surface()
        ambiguous.mappingIssue = .ambiguousTTY
        for row in [missing, ambiguous, surface(path: "/dev/ttys044")] {
            XCTAssertNil(store.coverage(for: row).observation)
            XCTAssertFalse(store.coverage(for: row).attentionEligible)
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: organizer.path)
        XCTAssertFalse(files.contains { $0.hasPrefix("adoption-") })
    }

    func testRetainedDeliverySurvivesBackgroundingButNewDeliveryNeedsCurrentCorrelation() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        XCTAssertTrue(store.coverage(for: surface()).attentionEligible)
        records[10] = identity(10, group: 20, foreground: 20)
        records[11] = identity(11, group: 10, foreground: 20)
        let retained = store.coverage(for: surface())
        XCTAssertEqual(retained.observation?.deliveryID, "delivery-43")
        XCTAssertTrue(retained.attentionEligible)
        XCTAssertTrue(retained.status.lowercased().contains("last-known"))
        try store.publishObservation(observation(delivery: "delivery-44", time: 999))
        XCTAssertNil(store.coverage(for: surface()).observation)
        records[11] = identity(11, group: 20, foreground: 20)
        XCTAssertEqual(store.coverage(for: surface()).observation?.deliveryID, "delivery-44")
    }

    func testExitPIDGenerationAndControllingDeviceAreRevalidatedEvenAfterAdoption() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        XCTAssertNotNil(store.coverage(for: surface()).observation)
        records[11] = nil
        XCTAssertNil(store.coverage(for: surface()).observation)
        records[11] = identity(11, startMicroseconds: 2)
        XCTAssertNil(store.coverage(for: surface()).observation)
        records[11] = identity(11, device: 456)
        XCTAssertNil(store.coverage(for: surface()).observation)
        records[11] = identity(11)
        devices[tty] = 456
        XCTAssertNil(store.coverage(for: surface()).observation)
        devices[tty] = nil
        XCTAssertNil(store.coverage(for: surface()).observation)
    }

    func testNativeTerminalAndApplicationReuseCannotAcquireOldBindingAfterRestart() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        try store.publishIntent(intent())
        XCTAssertNotNil(store.coverage(for: surface()).observation)
        let restarted = makeStore()
        XCTAssertNil(restarted.coverage(for: surface(terminal: "replacement")).observation)
        XCTAssertNil(restarted.coverage(for: surface(terminal: "replacement")).intent)
        XCTAssertNil(restarted.coverage(for: surface(applicationStart: 101)).observation)
        try restarted.publishObservation(observation(delivery: "late-old-producer", time: 999))
        XCTAssertNil(restarted.coverage(for: surface(terminal: "replacement")).observation)
        XCTAssertNotNil(restarted.coverage(for: surface()).observation)
    }

    func testNewProducerCanAdoptSurvivingSurfaceWithoutReplacingOldProducerBinding() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        XCTAssertNotNil(store.coverage(for: surface()).observation)
        records[12] = identity(12)
        try store.publishObservation(observation(delivery: "new-producer", time: 999, pid: 12))
        XCTAssertEqual(store.coverage(for: surface()).observation?.producer, generation(12))
        let bindings = try FileManager.default.contentsOfDirectory(atPath: organizer.path)
            .filter { $0.hasPrefix("adoption-") }
        XCTAssertEqual(bindings.count, 2)
    }

    func testUnverifiedAgentNeverBecomesAttentionEligible() throws {
        let store = makeStore()
        var value = observation()
        value.verifiedAgent = false
        try store.publishObservation(value)
        XCTAssertFalse(store.coverage(for: surface()).attentionEligible)
    }

    func testIntentOnlyCanAdoptButDoesNotInventObservation() throws {
        let store = makeStore()
        try store.publishIntent(intent())
        let result = store.coverage(for: surface())
        XCTAssertNil(result.observation)
        XCTAssertEqual(result.intent?.background, "#123ABC")
        XCTAssertFalse(result.attentionEligible)
    }

    func testFakeTTYAndUnavailableProducerRemainDiagnosticRecordsOnly() throws {
        let store = makeStore()
        let fake = root.deletingLastPathComponent().appendingPathComponent("fake-tty").path
        devices[fake] = 123
        try store.publishObservation(observation(path: fake))
        try store.publishIntent(intent(path: fake))
        XCTAssertNil(store.coverage(for: surface(path: fake)).observation)
        XCTAssertNil(store.coverage(for: surface(path: fake)).intent)
        var value = observation()
        value.producer = nil
        value.device = nil
        value.verifiedAgent = false
        try store.publishObservation(value)
        XCTAssertNil(store.coverage(for: surface()).observation)
        XCTAssertThrowsError(try store.publishObservation(observation(path: "/dev/tty")))
    }

    func testSyntheticIntentPreservesMeaningfulObservationBytesAndIdentity() throws {
        let store = makeStore()
        let observed = observation()
        try store.publishObservation(observed)
        let before = try Data(contentsOf: recordURL("observation"))
        XCTAssertNotNil(store.coverage(for: surface()).observation)
        records[10] = identity(10, group: 20, foreground: 20)
        records[11] = identity(11, group: 10, foreground: 20)
        try store.publishIntent(intent(color: "reset", time: 999), synthetic: true)
        XCTAssertEqual(try Data(contentsOf: recordURL("observation")), before)
        XCTAssertEqual(store.coverage(for: surface()).observation, observed)
        XCTAssertEqual(store.coverage(for: surface()).intent?.background, "reset")
    }

    func testSyntheticIntentRejectsFrozenDeliveryProducerAndDeviceMismatch() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        try store.publishIntent(intent())
        let before = try Data(contentsOf: recordURL("intent"))
        for stale in [intent(delivery: "old-delivery"), intent(pid: 12), intent(device: 456)] {
            XCTAssertThrowsError(try store.publishIntent(stale, synthetic: true))
        }
        try store.publishObservation(observation(delivery: "new-delivery", time: 999))
        XCTAssertThrowsError(try store.publishIntent(intent(time: 1_000), synthetic: true))
        XCTAssertEqual(try Data(contentsOf: recordURL("intent")), before)
    }

    func testSyntheticIntentRejectsDeadProducerAndMissingObservation() throws {
        let store = makeStore()
        XCTAssertThrowsError(try store.publishIntent(intent(), synthetic: true))
        try store.publishObservation(observation())
        records[11] = nil
        XCTAssertThrowsError(try store.publishIntent(intent(), synthetic: true))
    }

    func testOlderPublicationsCannotReplaceLatestObservationOrIntent() throws {
        let store = makeStore()
        try store.publishObservation(observation(time: 999))
        try store.publishIntent(intent(time: 999))
        XCTAssertThrowsError(try store.publishObservation(observation(delivery: "old", time: 998)))
        XCTAssertThrowsError(try store.publishIntent(intent(color: "reset", time: 998)))
        XCTAssertEqual(store.coverage(for: surface()).observation?.observedAt, 999)
        XCTAssertEqual(store.coverage(for: surface()).intent?.background, "#123ABC")
    }

    func testNewMeaningfulDeliverySupersedesOldSyntheticRenderTimestamp() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        try store.publishIntent(intent(color: "reset", time: 1_000), synthetic: true)
        try store.publishObservation(observation(delivery: "new-delivery", time: 999))
        try store.publishIntent(intent(delivery: "new-delivery", color: "#ABCDEF", time: 999))
        XCTAssertEqual(store.coverage(for: surface()).intent?.deliveryID, "new-delivery")
        XCTAssertEqual(store.coverage(for: surface()).intent?.background, "#ABCDEF")
        XCTAssertThrowsError(try store.publishIntent(intent(color: "reset", time: 1_000), synthetic: true))
    }

    func testLateOrdinaryWriteCannotReplaceANewerHookIntake() throws {
        let store = makeStore()
        try store.publishObservation(observation(delivery: "new-delivery", time: 999))
        try store.publishIntent(intent(delivery: "new-delivery", color: "#ABCDEF", time: 999), intakeAt: 999)
        XCTAssertThrowsError(try store.publishIntent(intent(color: "reset", time: 1_000), intakeAt: 998))
        XCTAssertEqual(store.coverage(for: surface()).intent?.background, "#ABCDEF")
        XCTAssertThrowsError(try store.publishIntent(intent(time: 999), intakeAt: 1_000))
    }

    func testFreshPublicationsRepairMalformedLatestRecordsButSyntheticCannot() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        try store.publishIntent(intent())
        for data in [Data("broken".utf8), Data(#"{"schema":43}"#.utf8)] {
            try data.write(to: recordURL("observation"))
            XCTAssertThrowsError(try store.publishIntent(intent(time: 999), synthetic: true))
            XCTAssertEqual(try Data(contentsOf: recordURL("observation")), data)
            try store.publishObservation(observation(time: 999))
            try data.write(to: recordURL("intent"))
            XCTAssertThrowsError(try store.publishIntent(intent(time: 999), synthetic: true))
            XCTAssertEqual(try Data(contentsOf: recordURL("intent")), data)
            try store.publishIntent(intent(color: "#ABCDEF", time: 999))
            XCTAssertEqual(store.coverage(for: surface()).intent?.background, "#ABCDEF")
        }
    }

    func testSameTTYConcurrentSyntheticAndNewDeliveryCannotLeaveOldIntent() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        let lock = NSLock()
        var errors: [Error] = []
        DispatchQueue.concurrentPerform(iterations: 2) { index in
            do {
                if index == 0 {
                    try store.publishIntent(intent(color: "reset", time: 1_000), synthetic: true)
                } else {
                    try store.publishObservation(observation(delivery: "new-delivery", time: 999))
                    try store.publishIntent(intent(delivery: "new-delivery", color: "#ABCDEF", time: 999))
                }
            } catch TerminalVisualStateError.staleDelivery where index == 0 {
                // The new observation won the shared writer lock first.
            } catch { lock.lock(); errors.append(error); lock.unlock() }
        }
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(store.coverage(for: surface()).intent?.deliveryID, "new-delivery")
    }

    func testResponseIdentityRetainsSupportedIDAndDoesNotInventMissingID() throws {
        let store = makeStore()
        var value = observation()
        value.provider = "codex"
        value.event = "agent-turn-complete"
        value.responseID = "turn-43"
        try store.publishObservation(value)
        XCTAssertEqual(store.coverage(for: surface()).observation?.responseID, "turn-43")
        value.deliveryID = "next-completion"
        value.responseID = nil
        value.observedAt = 999
        try store.publishObservation(value)
        XCTAssertNil(store.coverage(for: surface()).observation?.responseID)
        XCTAssertFalse(store.coverage(for: surface()).attentionEligible)
    }

    func testManualAndUnsupportedEventStateAssociationsCannotCreateAttention() throws {
        let store = makeStore()
        for (state, event) in [("complete", nil), ("complete", "Notification"),
                               ("permission", "Stop"), ("processing", "UserPromptSubmit")] as [(String, String?)] {
            var value = observation()
            value.state = state
            value.event = event
            try store.publishObservation(value)
            XCTAssertNotNil(store.coverage(for: surface()).observation)
            XCTAssertFalse(store.coverage(for: surface()).attentionEligible)
        }
        var permission = observation()
        permission.state = "permission"
        permission.event = "PermissionRequest"
        try store.publishObservation(permission)
        XCTAssertTrue(store.coverage(for: surface()).attentionEligible)
    }

    func testColorNormalizationAcceptsHexRGBAndResetOnly() throws {
        let store = makeStore()
        for (raw, normalized) in [("#123abc", "#123ABC"), ("rgb:1/2/3", "#112233"),
                                  ("rgb:ffff/8000/0000", "#FF8000"), ("reset", "reset")] {
            try store.publishIntent(intent(color: raw))
            XCTAssertEqual(store.coverage(for: surface()).intent?.background, normalized)
        }
        for raw in ["red", "#123", "#12345G", "rgb:12345/0/0", "rgb:0/0", "rgb:/0/0",
                    String(repeating: " ", count: 100) + "#123ABC",
                    "reset\nBODY_SENTINEL", "#123ABC;echo BODY_SENTINEL", "\u{1B}]11;red\u{7}"] {
            XCTAssertThrowsError(try store.publishIntent(intent(color: raw))) { error in
                XCTAssertFalse(String(describing: error).contains("BODY_SENTINEL"))
            }
        }
    }

    func testInvalidObservationBoundsFailWithoutPayloadDiagnostics() throws {
        let store = makeStore()
        var invalid: [TerminalObservation] = []
        var value = observation(); value.schema = 2; invalid.append(value)
        value = observation(); value.provider = "unknown"; invalid.append(value)
        value = observation(); value.state = "BODY_SENTINEL"; invalid.append(value)
        value = observation(); value.event = "BODY_SENTINEL"; invalid.append(value)
        value = observation(); value.deliveryID = "$(BODY_SENTINEL)"; invalid.append(value)
        value = observation(); value.responseID = String(repeating: "a", count: 129); invalid.append(value)
        value = observation(); value.tty = "/dev/../dev/ttys043"; invalid.append(value)
        value = observation(); value.observedAt = 1_001; invalid.append(value)
        value = observation(); value.observedAt = .nan; invalid.append(value)
        value = observation(); value.observedAt = .infinity; invalid.append(value)
        value = observation(); value.producer = generation(-1); invalid.append(value)
        value = observation(); value.producer = generation(11, start: 0); invalid.append(value)
        value = observation(); value.producer = generation(11, microseconds: 1_000_000); invalid.append(value)
        value = observation(); value.device = UInt32.max; invalid.append(value)
        for record in invalid {
            XCTAssertThrowsError(try store.publishObservation(record)) { error in
                XCTAssertFalse(String(describing: error).contains("BODY_SENTINEL"))
            }
        }
    }

    func testUnknownFieldsMalformedAndFutureRecordsAreUnavailable() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        let baseline = try JSONSerialization.jsonObject(with: Data(contentsOf: recordURL("observation")))
            as! [String: Any]
        var unknown = baseline; unknown["prompt"] = "BODY_SENTINEL"
        var nested = baseline
        var producer = nested["producer"] as! [String: Any]
        producer["argv"] = "BODY_SENTINEL"; nested["producer"] = producer
        var future = baseline; future["observedAt"] = 1_001
        var unsupported = baseline; unsupported["schema"] = 2
        for payload in [unknown, nested, future, unsupported] {
            let data = try JSONSerialization.data(withJSONObject: payload)
            try data.write(to: recordURL("observation"))
            XCTAssertNil(store.coverage(for: surface()).observation)
            XCTAssertFalse(store.coverage(for: surface()).status.contains("BODY_SENTINEL"))
        }
        try Data("$(BODY_SENTINEL)".utf8).write(to: recordURL("observation"))
        XCTAssertNil(store.coverage(for: surface()).observation)
        XCTAssertThrowsError(try JSONDecoder().decode(TerminalObservation.self,
            from: JSONSerialization.data(withJSONObject: unknown)))
    }

    func testCorruptObservationDoesNotPreventIndependentOrdinaryIntentPublication() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        try Data("BODY_SENTINEL".utf8).write(to: recordURL("observation"))
        try store.publishIntent(intent())
        let result = store.coverage(for: surface())
        XCTAssertNil(result.observation)
        XCTAssertEqual(result.intent?.background, "#123ABC")
        XCTAssertThrowsError(try store.publishIntent(intent(time: 999), synthetic: true))
    }

    func testOversizedSymlinkAndDirectoryRecordsAreRejectedWithoutReadingTargets() throws {
        for kind in ["oversized", "symlink", "directory"] {
            let store = makeStore(directory: root.appendingPathComponent(kind))
            try store.publishIntent(intent())
            let target = recordURL("observation", directory: root.appendingPathComponent(kind))
            if kind == "oversized" {
                try Data(repeating: 65, count: 8_193).write(to: target)
            } else if kind == "symlink" {
                let payload = root.appendingPathComponent("symlink-payload")
                try JSONEncoder().encode(observation()).write(to: payload)
                try FileManager.default.createSymbolicLink(at: target, withDestinationURL: payload)
            } else {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            }
            XCTAssertNil(store.coverage(for: surface()).observation)
        }
    }

    func testCorruptPersistedAdoptionCannotSilentlyRebind() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        XCTAssertNotNil(store.coverage(for: surface()).observation)
        let names = try FileManager.default.contentsOfDirectory(atPath: organizer.path)
        let name = try XCTUnwrap(names.first { $0.hasPrefix("adoption-") })
        try Data("BODY_SENTINEL".utf8).write(to: organizer.appendingPathComponent(name))
        let result = makeStore().coverage(for: surface(terminal: "replacement"))
        XCTAssertNil(result.observation)
        XCTAssertFalse(result.status.contains("BODY_SENTINEL"))
    }

    func testBoundedLockDoesNotBlockAnotherTTY() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        let lockedURL = organizer.appendingPathComponent("writer-\(key(tty)).lock")
        let fd = open(lockedURL.path, O_RDWR | O_NOFOLLOW)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        let other = "/dev/ttys044"
        try store.publishObservation(observation(path: other))
        let started = DispatchTime.now().uptimeNanoseconds
        XCTAssertThrowsError(try store.publishObservation(observation(time: 999)))
        let duration = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000
        XCTAssertLessThan(duration, 0.3)
        XCTAssertGreaterThanOrEqual(duration, 0.09)
    }

    func testTenConcurrentTTYsKeepIndependentObservationAndIntent() throws {
        let store = makeStore()
        for index in 0..<10 {
            let path = "/dev/ttys\(100 + index)"
            devices[path] = UInt32(200 + index)
            records[Int32(100 + index)] = identity(Int32(100 + index), device: UInt32(200 + index),
                                                 group: UInt32(100 + index), foreground: UInt32(100 + index))
        }
        let lock = NSLock()
        var errors: [Error] = []
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            do {
                let path = "/dev/ttys\(100 + index)"
                try store.publishObservation(observation(path: path, pid: Int32(100 + index),
                                                         device: UInt32(200 + index)))
                try store.publishIntent(intent(path: path, pid: Int32(100 + index),
                                               device: UInt32(200 + index)))
            } catch { lock.lock(); errors.append(error); lock.unlock() }
        }
        XCTAssertTrue(errors.isEmpty)
        for index in 0..<10 {
            let path = "/dev/ttys\(100 + index)"
            let result = store.coverage(for: surface(path: path, foreground: Int32(100 + index)))
            XCTAssertEqual(result.observation?.tty, path)
            XCTAssertEqual(result.intent?.tty, path)
            XCTAssertTrue(result.attentionEligible)
        }
    }

    private var organizer: URL { root.appendingPathComponent("organizer") }

    private func makeStore(directory: URL? = nil) -> TerminalVisualStateStore {
        TerminalVisualStateStore(runtimeDirectory: directory ?? root, clock: clock,
                                 lookup: { self.records[$0] }, device: { self.devices[$0] })
    }

    private func generation(_ pid: Int32, start: UInt64 = 100,
                            microseconds: UInt64 = 1) -> ProcessGeneration {
        ProcessGeneration(pid: pid, startSeconds: start, startMicroseconds: microseconds)
    }

    private func identity(_ pid: Int32, device: UInt32 = 123, group: UInt32 = 10,
                          foreground: UInt32 = 10, startMicroseconds: UInt64 = 1) -> ProcessIdentity {
        ProcessIdentity(generation: generation(pid, microseconds: startMicroseconds), parentPID: 1,
                        group: group, device: device, foregroundGroup: foreground)
    }

    private func surface(path: String? = nil, terminal: String = "terminal-43",
                         applicationStart: UInt64 = 100, foreground: Int32 = 10) -> GhosttySurface {
        GhosttySurface(id: GhosttySurfaceID(application: generation(43, start: applicationStart),
                                            terminalID: terminal), windowID: "window-43", tabID: "tab-43",
                       title: nil, directory: nil, tty: path ?? tty, foregroundPID: foreground,
                       tabSelected: true, mappingIssue: nil)
    }

    private func observation(path: String? = nil, delivery: String = "delivery-43", time: Double = 998,
                             pid: Int32 = 11, device: UInt32 = 123) -> TerminalObservation {
        TerminalObservation(tty: path ?? tty, device: device, producer: generation(pid), provider: "claude",
                            verifiedAgent: true, state: "complete", event: "Stop", deliveryID: delivery,
                            responseID: nil, observedAt: time)
    }

    private func intent(path: String? = nil, delivery: String = "delivery-43", color: String = "#123abc",
                        time: Double = 998, pid: Int32 = 11, device: UInt32 = 123) -> OrdinaryBackgroundIntent {
        OrdinaryBackgroundIntent(tty: path ?? tty, device: device, producer: generation(pid),
                                 deliveryID: delivery, updatedAt: time, background: color)
    }

    private func key(_ path: String) -> String {
        Data(path.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private func recordURL(_ kind: String, directory: URL? = nil) -> URL {
        (directory ?? root).appendingPathComponent("organizer")
            .appendingPathComponent("\(kind)-\(key(tty)).json")
    }
}
