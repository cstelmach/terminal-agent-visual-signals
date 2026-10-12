import XCTest
import Darwin
@testable import TAVSApp

final class TerminalVisualStateTests: XCTestCase {
    private var root: URL!
    private var records: [Int32: ProcessIdentity] = [:]
    private var devices: [String: UInt32] = [:]
    private var missingDevices = Set<String>()
    private var missingProcesses = Set<Int32>()
    private var descriptorDevices: [Int32: UInt32] = [:]
    private var clock: VirtualClock!
    private let tty = "/dev/ttys043"

    override func setUpWithError() throws {
        let isolated = try XCTUnwrap(ProcessInfo.processInfo.environment["TAVS_TEST_ROOT"])
        root = URL(fileURLWithPath: isolated).appendingPathComponent("records-\(UUID().uuidString)")
        clock = VirtualClock(startingAt: Date(timeIntervalSince1970: 1_000))
        records = [10: identity(10), 11: identity(11)]
        devices = [tty: 123]
        missingDevices = []
        missingProcesses = []
        descriptorDevices = [44: 123]
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

    func testCachedPlainShellBindingAndEffectPersistWithoutAgentObservations() throws {
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        XCTAssertNil(binding.nativeSurface)
        records[90] = identity(90)
        try store.cacheTargetUnlocked(binding, deadline: deadline())
        try store.saveEffectUnlocked(effect(binding), deadline: deadline())
        let cached = makeStore().cachedRecords()
        XCTAssertEqual(cached.bindings, [binding])
        XCTAssertEqual(cached.effects.first?.target, binding)
        XCTAssertTrue(cached.unreadable.isEmpty)
        XCTAssertEqual(store.validateTarget(binding), .valid)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordURL("observation").path))
    }

    func testFreshNativeBindingUsesContinuingParentAndRetainsBackgroundedOwner() throws {
        records[10] = ProcessIdentity(generation: generation(10), parentPID: 11, group: 10,
                                      device: 123, foregroundGroup: 10)
        records[43] = identity(43, device: UInt32.max)
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(for: surface()))
        XCTAssertEqual(binding.ttyOwner, generation(11))
        XCTAssertEqual(binding.nativeSurface, surface().id)
        records[11] = identity(11, group: 20, foreground: 30)
        XCTAssertEqual(store.validateTarget(binding, descriptor: 44), .valid)
        var ambiguous = surface(); ambiguous.mappingIssue = .ambiguousTTY
        XCTAssertNil(store.captureTarget(for: ambiguous))
    }

    func testCachedOwnerUncertaintyDiffersFromProvenEndedGeneration() throws {
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        records[11] = nil
        XCTAssertEqual(store.validateTarget(binding), .unavailable)
        missingProcesses.insert(11)
        XCTAssertEqual(store.validateTarget(binding), .vanished)
        records[11] = identity(11, startMicroseconds: 2)
        XCTAssertEqual(store.validateTarget(binding), .vanished)
        records[11] = identity(11, device: 456)
        XCTAssertEqual(store.validateTarget(binding), .unavailable)
        records[11] = identity(11)
        devices[tty] = nil
        XCTAssertEqual(store.validateTarget(binding), .unavailable)
        missingDevices.insert(tty)
        XCTAssertEqual(store.validateTarget(binding), .vanished)
        missingDevices = []
        devices[tty] = 456
        XCTAssertEqual(store.validateTarget(binding), .vanished)
    }

    func testProvenOwnerEndIsNotMaskedByUnavailableNativeOrDeviceMetadata() throws {
        records[43] = identity(43, device: UInt32.max)
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(for: surface(foreground: 11)))
        records[43] = nil
        records[11] = identity(11, startMicroseconds: 2)
        XCTAssertEqual(store.validateTarget(binding), .vanished)
        devices[tty] = nil
        XCTAssertEqual(store.validateTarget(binding), .vanished)
        records[11] = nil
        missingProcesses.insert(11)
        XCTAssertEqual(store.validateTarget(binding), .vanished)
        missingProcesses = []
        XCTAssertEqual(store.validateTarget(binding), .unavailable)
    }

    func testNativeAndApplicationReuseNeverRetargetsOldRequest() throws {
        records[43] = identity(43, device: UInt32.max)
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(for: surface()))
        XCTAssertEqual(store.validateTarget(binding, native: surface(terminal: "replacement")), .unavailable)
        XCTAssertEqual(store.validateTarget(binding, confirmedNativeAbsent: true), .vanished)
        records[43] = identity(43, device: UInt32.max, startMicroseconds: 2)
        XCTAssertEqual(store.validateTarget(binding), .vanished)
        records[43] = nil
        XCTAssertEqual(store.validateTarget(binding), .unavailable)
        missingProcesses.insert(43)
        XCTAssertEqual(store.validateTarget(binding), .vanished)
    }

    func testDescriptorCharacterDeviceAndNumberAreRequired() throws {
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        XCTAssertEqual(store.validateTarget(binding, descriptor: 44), .valid)
        descriptorDevices[44] = 456
        XCTAssertEqual(store.validateTarget(binding, descriptor: 44), .unavailable)
        descriptorDevices[44] = nil
        XCTAssertEqual(store.validateTarget(binding, descriptor: 44), .unavailable)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let regular = root.appendingPathComponent("regular-device-test")
        try Data().write(to: regular)
        let fd = open(regular.path, O_RDONLY | O_NOFOLLOW)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }
        let actualDescriptor = TerminalVisualStateStore(runtimeDirectory: root, clock: clock,
            lookup: { self.records[$0] }, device: { self.devices[$0] },
            deviceMissing: { _ in false }, processMissing: { _ in false })
        XCTAssertEqual(actualDescriptor.validateTarget(binding, descriptor: fd), .unavailable)
    }

    func testUnresolvedBindingsOnSameTTYRemainSeparateCurrentRecords() throws {
        records[43] = identity(43, device: UInt32.max)
        let store = makeStore()
        let first = try XCTUnwrap(store.captureTarget(for: surface()))
        let second = try XCTUnwrap(store.captureTarget(for: surface(terminal: "replacement")))
        records[90] = identity(90)
        try store.saveEffectUnlocked(effect(first), deadline: deadline())
        try store.saveEffectUnlocked(effect(second, id: "replacement-effect"), deadline: deadline())
        let cached = store.cachedRecords()
        XCTAssertEqual(Set(cached.bindings), [first, second])
        XCTAssertEqual(Set(cached.effects.map(\.target)), [first, second])
    }

    func testCanceledEffectCannotBeRecreatedByHeartbeatOrSameIDSave() throws {
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        records[90] = identity(90)
        let original = effect(binding)
        try store.saveEffectUnlocked(original, deadline: deadline())
        XCTAssertTrue(try store.cancelEffectUnlocked(binding, effectID: original.effectID,
                                                   controller: original.controller, deadline: deadline()))
        XCTAssertFalse(try store.refreshEffectUnlocked(binding, effectID: original.effectID,
                                                      controller: original.controller, deadline: deadline()))
        XCTAssertThrowsError(try store.saveEffectUnlocked(original, deadline: deadline()))
        XCTAssertNil(try store.matchingEffectUnlocked(binding, effectID: original.effectID,
                                                     controller: original.controller, deadline: deadline()))
        XCTAssertFalse(try XCTUnwrap(store.currentEffectUnlocked(binding, deadline: deadline())).active)
        XCTAssertEqual(store.cachedRecords().bindings, [binding])
        try store.saveEffectUnlocked(effect(binding, id: "deliberate-new-effect"), deadline: deadline())
        XCTAssertTrue(try XCTUnwrap(store.currentEffectUnlocked(binding, deadline: deadline())).active)
    }

    func testStrictEffectIDAndControllerMatchingPreservesNewEffect() throws {
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        records[90] = identity(90)
        try store.saveEffectUnlocked(effect(binding, id: "new-effect"), deadline: deadline())
        XCTAssertFalse(try store.cancelEffectUnlocked(binding, effectID: "old-effect",
                                                     controller: generation(90), deadline: deadline()))
        XCTAssertFalse(try store.refreshEffectUnlocked(binding, effectID: "new-effect",
            controller: generation(90, microseconds: 2), deadline: deadline()))
        XCTAssertEqual(try store.currentEffectUnlocked(binding, deadline: deadline())?.effectID, "new-effect")
        XCTAssertTrue(try store.refreshEffectUnlocked(binding, effectID: "new-effect",
                                                      controller: generation(90), deadline: deadline()))
    }

    func testSelectiveLeaseHasSixSecondBoundaryAndGlobalPolicyIsIndependent() throws {
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        records[90] = identity(90)
        let record = effect(binding)
        XCTAssertTrue(store.isSelectiveLeaseActive(record))
        clock.advance(by: 2)
        XCTAssertTrue(store.isSelectiveLeaseActive(record))
        clock.advance(by: 4)
        XCTAssertTrue(store.isSelectiveLeaseActive(record))
        clock.advance(by: 0.001)
        XCTAssertFalse(store.isSelectiveLeaseActive(record))
        clock.set(to: Date(timeIntervalSince1970: 1_000))
        records[90] = identity(90, startMicroseconds: 2)
        XCTAssertFalse(store.isSelectiveLeaseActive(record))
        var global = record; global.kind = .globalRestriction
        XCTAssertFalse(store.isSelectiveLeaseActive(global))
        try store.saveEffectUnlocked(global, deadline: deadline())
        XCTAssertEqual(try store.currentEffectUnlocked(binding, deadline: deadline())?.kind, .globalRestriction)
    }

    func testUnlockedHelpersUseOneHeldStableLockAndPreserveObservationIntent() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        try store.publishIntent(intent())
        let observed = try Data(contentsOf: recordURL("observation"))
        let intended = try Data(contentsOf: recordURL("intent"))
        let url = try store.lockURL(forTTY: tty)
        XCTAssertEqual(url.lastPathComponent, "writer-\(key(tty)).lock")
        let fd = open(url.path, O_RDWR | O_NOFOLLOW)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        var before = stat(); XCTAssertEqual(fstat(fd, &before), 0)
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        records[90] = identity(90)
        let budget = deadline()
        try store.cacheTargetUnlocked(binding, deadline: budget)
        try store.saveEffectUnlocked(effect(binding), deadline: budget)
        XCTAssertNotNil(try store.matchingEffectUnlocked(binding, effectID: "effect-43",
                                                        controller: generation(90), deadline: budget))
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for: binding, deadline: budget), "#123ABC")
        XCTAssertTrue(try store.refreshEffectUnlocked(binding, effectID: "effect-43",
                                                      controller: generation(90), deadline: budget))
        XCTAssertTrue(try store.cancelEffectUnlocked(binding, effectID: "effect-43",
                                                     controller: generation(90), deadline: budget))
        var after = stat(); XCTAssertEqual(lstat(url.path, &after), 0)
        XCTAssertEqual(before.st_ino, after.st_ino)
        XCTAssertEqual(observed, try Data(contentsOf: recordURL("observation")))
        XCTAssertEqual(intended, try Data(contentsOf: recordURL("intent")))
    }

    func testExpiredOriginalDeadlineCannotMutateCurrentEffect() throws {
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        records[90] = identity(90)
        try store.saveEffectUnlocked(effect(binding), deadline: deadline())
        let before = try XCTUnwrap(store.currentEffectUnlocked(binding, deadline: deadline()))
        let expired = DispatchTime.now().uptimeNanoseconds - 1
        XCTAssertThrowsError(try store.saveEffectUnlocked(effect(binding, id: "late"), deadline: expired))
        XCTAssertThrowsError(try store.cancelEffectUnlocked(binding, effectID: "effect-43",
                                                           controller: generation(90), deadline: expired))
        XCTAssertThrowsError(try store.refreshEffectUnlocked(binding, effectID: "effect-43",
                                                            controller: generation(90), deadline: expired))
        XCTAssertEqual(try store.currentEffectUnlocked(binding, deadline: deadline()), before)
    }

    func testEffectMetadataRejectsUnknownPayloadsFutureTimesAndColors() throws {
        let store = makeStore()
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        records[90] = identity(90)
        var bad = effect(binding); bad.heartbeatAt = 1_001
        XCTAssertThrowsError(try store.saveEffectUnlocked(bad, deadline: deadline()))
        bad = effect(binding); bad.background = "\u{1B}]11;BODY_SENTINEL\u{7}"
        XCTAssertThrowsError(try store.saveEffectUnlocked(bad, deadline: deadline()))
        try store.saveEffectUnlocked(effect(binding), deadline: deadline())
        let files = try XCTUnwrap(FileManager.default.enumerator(at: organizer.appendingPathComponent("targets"),
            includingPropertiesForKeys: nil)).allObjects.compactMap { $0 as? URL }
        let effectFile = try XCTUnwrap(files.first { $0.lastPathComponent == "effect.json" })
        var payload = try JSONSerialization.jsonObject(with: Data(contentsOf: effectFile)) as! [String: Any]
        payload["payload"] = "BODY_SENTINEL"
        let data = try JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try JSONDecoder().decode(TerminalEffectRecord.self, from: data)) { error in
            XCTAssertFalse(String(describing: error).contains("BODY_SENTINEL"))
        }
        try data.write(to: effectFile)
        let cached = store.cachedRecords()
        XCTAssertEqual(cached.bindings, [binding])
        XCTAssertTrue(cached.effects.isEmpty)
        XCTAssertEqual(cached.unreadable, [effectFile])
    }

    func testEmptyRegistryAndMissingTypedRecordsCannotAuthorizeTarget() throws {
        let registry = root.appendingPathComponent("active-ttys")
        try FileManager.default.createDirectory(at: registry, withIntermediateDirectories: true)
        try Data().write(to: registry.appendingPathComponent("_dev_ttys043"))
        let store = makeStore()
        XCTAssertTrue(store.cachedRecords().bindings.isEmpty)
        XCTAssertTrue(store.cachedRecords().effects.isEmpty)
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        XCTAssertNil(try store.ordinaryBackgroundUnlocked(for: binding, deadline: deadline()))
    }

    func testAdoptedNativeIntentSurvivesAgentExitOnContinuingShellWithoutCueOrRetargeting() throws {
        records[43] = identity(43, device: UInt32.max)
        records[12] = ProcessIdentity(generation: generation(12), parentPID: 11, group: 10,
                                      device: 123, foregroundGroup: 10)
        let store = makeStore()
        let row = surface(foreground: 12)
        try store.publishObservation(observation(pid: 12))
        try store.publishIntent(intent(pid: 12))
        XCTAssertNotNil(store.coverage(for: row).observation)
        let binding = try XCTUnwrap(store.captureTarget(for: row))
        XCTAssertEqual(binding.ttyOwner, generation(11))
        try store.cacheTargetUnlocked(binding, deadline: deadline())
        records[12] = nil
        XCTAssertEqual(store.validateTarget(binding), .valid)
        XCTAssertNil(store.coverage(for: surface(foreground: 11)).observation)
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for: binding, deadline: deadline()), "#123ABC")
        let replacement = try XCTUnwrap(store.captureTarget(for: surface(terminal: "replacement", foreground: 11)))
        XCTAssertThrowsError(try store.ordinaryBackgroundUnlocked(for: replacement, deadline: deadline()))
    }

    func testNativeAdoptionCannotRestoreDeadProducerIntentAfterContinuingOwnerReuse() throws {
        records[43] = identity(43, device: UInt32.max)
        records[12] = ProcessIdentity(generation: generation(12), parentPID: 11, group: 10,
                                     device: 123, foregroundGroup: 10)
        let store = makeStore()
        let row = surface(foreground: 12)
        try store.publishObservation(observation(pid: 12))
        try store.publishIntent(intent(pid: 12))
        XCTAssertNotNil(store.coverage(for: row).intent)
        let original = try XCTUnwrap(store.captureTarget(for: row))
        try store.cacheTargetUnlocked(original, deadline: deadline())
        records[12] = nil
        records[11] = identity(11, startMicroseconds: 2)
        let replacement = try XCTUnwrap(store.captureTarget(for: surface(foreground: 11)))
        XCTAssertNotEqual(original.ttyOwner, replacement.ttyOwner)
        try store.cacheTargetUnlocked(replacement, deadline: deadline())
        XCTAssertNil(try store.ordinaryBackgroundUnlocked(for: replacement, deadline: deadline()))
        XCTAssertTrue(store.cachedRecords().bindings.contains(original))
    }

    func testIntentPublicationAndBindingUseTheCallersHeldStableLock() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        try store.publishIntent(intent())
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        let observed = try Data(contentsOf: recordURL("observation"))
        let lockURL = try store.lockURL(forTTY: tty)
        let fd = open(lockURL.path, O_RDWR | O_NOFOLLOW)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        var before = stat(); XCTAssertEqual(fstat(fd, &before), 0)
        let budget = deadline()
        let value = intent(delivery: "new-delivery", color: "#abcdef", time: 999)
        try store.publishIntentUnlocked(value, intakeAt: 999, deadline: budget)
        try store.bindOrdinaryIntentUnlocked(value, to: binding, deadline: budget)
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for: binding, deadline: budget), "#ABCDEF")
        var after = stat(); XCTAssertEqual(lstat(lockURL.path, &after), 0)
        XCTAssertEqual(before.st_ino, after.st_ino)
        XCTAssertEqual(try Data(contentsOf: recordURL("observation")), observed)
    }

    func testTargetAwarePublicationBindsAcrossAliasesWithoutObservationMutation() throws {
        records[12] = ProcessIdentity(generation: generation(12), parentPID: 11, group: 10,
                                     device: 123, foregroundGroup: 10)
        records[43] = identity(43, device: UInt32.max)
        let store = makeStore()
        try store.publishObservation(observation(pid: 12))
        let observed = try Data(contentsOf: recordURL("observation"))
        let plain = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(12)))
        let native = try XCTUnwrap(store.captureTarget(for: surface(foreground: 11)))
        try store.cacheTargetUnlocked(native, deadline: deadline())
        try store.publishIntent(intent(color: "#abcdef", time: 999, pid: 12), to: plain,
                                synthetic: false, intakeAt: 999, deadline: deadline())
        let fd = open(try store.lockURL(forTTY: tty).path, O_RDWR | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { XCTFail("Fixture lock unavailable"); return }
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        XCTAssertEqual(flock(fd, LOCK_UN), 0)
        records[12] = nil
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for: plain, deadline: deadline()), "#ABCDEF")
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for: native, deadline: deadline()), "#ABCDEF")
        XCTAssertEqual(try Data(contentsOf: recordURL("observation")), observed)
    }

    func testTargetAwarePublicationCannotGetFreshBudgetForHeldLock() throws {
        let store = makeStore()
        try store.publishIntent(intent())
        let original = try Data(contentsOf: recordURL("intent"))
        let target = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        let lockURL = try store.lockURL(forTTY: tty)
        let fd = open(lockURL.path, O_RDWR | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { XCTFail("Fixture lock unavailable"); return }
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        let start = DispatchTime.now().uptimeNanoseconds
        XCTAssertThrowsError(try store.publishIntent(intent(color: "reset", time: 999), to: target,
            synthetic: false, intakeAt: 999, deadline: start + 25_000_000)) { error in
                XCTAssertEqual(String(describing: error), TerminalVisualStateError.deadlineExceeded.description)
            }
        XCTAssertLessThan(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9, 0.15)
        XCTAssertEqual(flock(fd, LOCK_UN), 0)
        XCTAssertEqual(try Data(contentsOf: recordURL("intent")), original)
        XCTAssertTrue(store.cachedRecords().bindings.isEmpty)
        XCTAssertThrowsError(try store.publishIntent(intent(color: "reset", time: 999), to: target,
            synthetic: false, intakeAt: 999, deadline: DispatchTime.now().uptimeNanoseconds - 1))
        XCTAssertEqual(try Data(contentsOf: recordURL("intent")), original)
    }

    func testTargetAwarePublicationRejectsStaleSyntheticAndWrongLifetimeBeforeMutation() throws {
        let store = makeStore()
        try store.publishObservation(observation(delivery: "latest-delivery", time: 999))
        try store.publishIntent(intent())
        let original = try Data(contentsOf: recordURL("intent"))
        let target = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        XCTAssertThrowsError(try store.publishIntent(intent(time: 1_000), to: target,
            synthetic: true, intakeAt: 999, deadline: deadline())) { error in
                XCTAssertEqual(String(describing: error), TerminalVisualStateError.staleDelivery.description)
            }
        let reused = TerminalTargetBinding(tty: tty, device: 123,
            ttyOwner: generation(11, microseconds: 2), nativeSurface: nil)
        for invalid in [reused, TerminalTargetBinding(tty: tty, device: 456, ttyOwner: generation(11), nativeSurface: nil)] {
            XCTAssertThrowsError(try store.publishIntent(intent(time: 1_000), to: invalid,
                synthetic: false, intakeAt: 1_000, deadline: deadline()))
        }
        records[43] = identity(43, device: UInt32.max)
        let native = try XCTUnwrap(store.captureTarget(for: surface(foreground: 11)))
        try store.cacheTargetUnlocked(native, deadline: deadline())
        records[43] = nil
        XCTAssertThrowsError(try store.publishIntent(intent(time: 1_000), to: target,
            synthetic: false, intakeAt: 1_000, deadline: deadline()))
        XCTAssertEqual(try Data(contentsOf: recordURL("intent")), original)
    }

    func testTargetAwarePublicationRejectsNonPrivateAndSymlinkStableLock() throws {
        let store = makeStore()
        try store.publishIntent(intent())
        let original = try Data(contentsOf: recordURL("intent"))
        let target = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        let lockURL = try store.lockURL(forTTY: tty)
        XCTAssertEqual(chmod(lockURL.path, 0o644), 0)
        XCTAssertThrowsError(try store.publishIntent(intent(color: "reset", time: 999), to: target,
            synthetic: false, intakeAt: 999, deadline: deadline()))
        XCTAssertEqual(try Data(contentsOf: recordURL("intent")), original)
        let linkedRoot = root.appendingPathComponent("linked")
        let linked = makeStore(directory: linkedRoot)
        let linkedLock = try linked.lockURL(forTTY: tty)
        try FileManager.default.createDirectory(at: linkedLock.deletingLastPathComponent(), withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("preserved-lock-target")
        try Data("preserved".utf8).write(to: destination)
        try FileManager.default.createSymbolicLink(at: linkedLock, withDestinationURL: destination)
        XCTAssertThrowsError(try linked.publishIntent(intent(color: "reset", time: 999), to: target,
            synthetic: false, intakeAt: 999, deadline: deadline()))
        XCTAssertEqual(try String(contentsOf: destination), "preserved")
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordURL("intent", directory: linkedRoot).path))
    }

    func testExpiredIntentDeadlineCannotReplaceLatestOrTargetBoundCopy() throws {
        let store = makeStore()
        try store.publishIntent(intent())
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        try store.bindOrdinaryIntentUnlocked(intent(), to: binding, deadline: deadline())
        let boundURL = try targetRecordURL("bound-intent.json")
        let latest = try Data(contentsOf: recordURL("intent"))
        let bound = try Data(contentsOf: boundURL)
        let expired = DispatchTime.now().uptimeNanoseconds - 1
        XCTAssertThrowsError(try store.publishIntentUnlocked(intent(color: "reset", time: 999), deadline: expired))
        XCTAssertThrowsError(try store.bindOrdinaryIntentUnlocked(intent(), to: binding, deadline: expired))
        XCTAssertEqual(try Data(contentsOf: recordURL("intent")), latest)
        XCTAssertEqual(try Data(contentsOf: boundURL), bound)
    }

    func testSyntheticContextValidationUnderHeldLockDoesNotPublish() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        try store.publishIntent(intent())
        let observed = try Data(contentsOf: recordURL("observation"))
        let ordinary = try Data(contentsOf: recordURL("intent"))
        let lockURL = try store.lockURL(forTTY: tty)
        let fd = open(lockURL.path, O_RDWR | O_NOFOLLOW)
        guard fd >= 0 else { XCTFail("Fixture lock unavailable"); return }
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        var before = stat(); XCTAssertEqual(fstat(fd, &before), 0)
        let files = try FileManager.default.contentsOfDirectory(atPath: organizer.path).sorted()
        try store.validateSyntheticUnlocked(intent(color: "reset", time: 1_000),
                                            intakeAt: 998, deadline: deadline())
        var after = stat(); XCTAssertEqual(lstat(lockURL.path, &after), 0)
        XCTAssertEqual(before.st_ino, after.st_ino)
        XCTAssertEqual(try Data(contentsOf: recordURL("observation")), observed)
        XCTAssertEqual(try Data(contentsOf: recordURL("intent")), ordinary)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: organizer.path).sorted(), files)
    }

    func testSyntheticContextRejectsFrozenIdentityAndNewerObservation() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        for stale in [intent(delivery: "old-delivery"), intent(pid: 12), intent(device: 456),
                      intent(path: "/dev/ttys044")] {
            XCTAssertThrowsError(try store.validateSyntheticUnlocked(stale, intakeAt: 998, deadline: deadline())) { error in
                XCTAssertEqual(String(describing: error), TerminalVisualStateError.staleDelivery.description)
            }
        }
        try store.publishObservation(observation(time: 999))
        XCTAssertThrowsError(try store.validateSyntheticUnlocked(intent(time: 1_000),
            intakeAt: 998, deadline: deadline())) { error in
            XCTAssertEqual(String(describing: error), TerminalVisualStateError.staleDelivery.description)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordURL("intent").path))
    }

    func testSyntheticContextRejectsMissingUnsupportedAndDeadProducer() throws {
        let store = makeStore()
        XCTAssertThrowsError(try store.validateSyntheticUnlocked(intent(), intakeAt: 998, deadline: deadline())) { error in
            XCTAssertEqual(String(describing: error), TerminalVisualStateError.staleDelivery.description)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: organizer.path))
        try store.publishObservation(observation())
        var unsupported = observation()
        unsupported.provider = "unsupported-provider"
        try JSONEncoder().encode(unsupported).write(to: recordURL("observation"))
        XCTAssertThrowsError(try store.validateSyntheticUnlocked(intent(), intakeAt: 998, deadline: deadline())) { error in
            XCTAssertEqual(String(describing: error), TerminalVisualStateError.staleDelivery.description)
        }
        try store.publishObservation(observation())
        for unavailable in [nil, identity(11, device: 456), identity(11, startMicroseconds: 2)] as [ProcessIdentity?] {
            records[11] = unavailable
            XCTAssertThrowsError(try store.validateSyntheticUnlocked(intent(), intakeAt: 998, deadline: deadline())) { error in
                XCTAssertEqual(String(describing: error), TerminalVisualStateError.staleDelivery.description)
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordURL("intent").path))
    }

    func testSyntheticContextRejectsInvalidInputAndExpiredOriginalDeadline() throws {
        let store = makeStore()
        try store.publishObservation(observation())
        let observed = try Data(contentsOf: recordURL("observation"))
        for intake in [Double.nan, 0, 999] {
            XCTAssertThrowsError(try store.validateSyntheticUnlocked(intent(), intakeAt: intake, deadline: deadline())) { error in
                XCTAssertEqual(String(describing: error), TerminalVisualStateError.invalidRecord.description)
            }
        }
        XCTAssertThrowsError(try store.validateSyntheticUnlocked(intent(color: "unsafe"),
            intakeAt: 998, deadline: deadline())) { error in
            XCTAssertEqual(String(describing: error), TerminalVisualStateError.invalidRecord.description)
        }
        XCTAssertThrowsError(try store.validateSyntheticUnlocked(intent(), intakeAt: 998,
            deadline: DispatchTime.now().uptimeNanoseconds - 1)) { error in
            XCTAssertEqual(String(describing: error), TerminalVisualStateError.deadlineExceeded.description)
        }
        XCTAssertEqual(try Data(contentsOf: recordURL("observation")), observed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordURL("intent").path))
    }

    func testUnlockedIntentPreservesSyntheticAndIntakeOrdering() throws {
        let store = makeStore()
        try store.publishObservation(observation(delivery: "new-delivery", time: 999))
        try store.publishIntent(intent(delivery: "new-delivery", color: "#ABCDEF", time: 999), intakeAt: 999)
        let latest = try Data(contentsOf: recordURL("intent"))
        XCTAssertThrowsError(try store.publishIntentUnlocked(intent(color: "reset", time: 1_000),
                                                            synthetic: true, deadline: deadline()))
        XCTAssertThrowsError(try store.publishIntentUnlocked(intent(color: "reset", time: 1_000),
                                                            intakeAt: 998, deadline: deadline()))
        XCTAssertEqual(try Data(contentsOf: recordURL("intent")), latest)
        try store.publishIntentUnlocked(intent(delivery: "new-delivery", color: "reset", time: 1_000),
                                         synthetic: true, deadline: deadline())
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for:
            XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11))), deadline: deadline()), "reset")
    }

    func testBoundPlainIntentSurvivesChildExitAndRejectsUnmatchedLatestDelivery() throws {
        records[12] = ProcessIdentity(generation: generation(12), parentPID: 11, group: 10,
                                      device: 123, foregroundGroup: 10)
        let store = makeStore()
        let value = intent(pid: 12)
        try store.publishIntent(value)
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(12)))
        XCTAssertEqual(binding.ttyOwner, generation(11))
        try store.bindOrdinaryIntentUnlocked(value, to: binding, deadline: deadline())
        records[12] = nil
        XCTAssertEqual(try makeStore().ordinaryBackgroundUnlocked(for: binding, deadline: deadline()), "#123ABC")
        let boundURL = try targetRecordURL("bound-intent.json")
        let bound = try Data(contentsOf: boundURL)
        let unmatched = intent(delivery: "unmatched", color: "reset", time: 999, pid: 12)
        try store.publishIntent(unmatched)
        XCTAssertThrowsError(try store.bindOrdinaryIntentUnlocked(unmatched, to: binding, deadline: deadline()))
        XCTAssertNil(try store.ordinaryBackgroundUnlocked(for: binding, deadline: deadline()))
        XCTAssertEqual(try Data(contentsOf: boundURL), bound)
    }

    func testBoundIntentCannotMigrateToDistinctOwnerOrNativeBinding() throws {
        records[12] = ProcessIdentity(generation: generation(12), parentPID: 11, group: 10,
                                      device: 123, foregroundGroup: 10)
        records[43] = identity(43, device: UInt32.max)
        records[13] = identity(13)
        let store = makeStore()
        let value = intent(pid: 12)
        try store.publishIntent(value)
        let plain = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(12)))
        try store.bindOrdinaryIntentUnlocked(value, to: plain, deadline: deadline())
        let otherOwner = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(13)))
        XCTAssertThrowsError(try store.bindOrdinaryIntentUnlocked(value, to: otherOwner, deadline: deadline()))
        let native = try XCTUnwrap(store.captureTarget(for: surface(foreground: 11)))
        try store.bindOrdinaryIntentUnlocked(value, to: native, deadline: deadline())
        records[12] = nil
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for: native, deadline: deadline()), "#123ABC")
        XCTAssertNil(try store.ordinaryBackgroundUnlocked(for: otherOwner, deadline: deadline()))
        let replacement = try XCTUnwrap(store.captureTarget(for: surface(terminal: "replacement", foreground: 11)))
        XCTAssertThrowsError(try store.ordinaryBackgroundUnlocked(for: replacement, deadline: deadline()))
    }

    func testEquivalentAliasesRestoreLatestBoundIntentAfterProducerExitWithoutAdoption() throws {
        records[12] = ProcessIdentity(generation: generation(12), parentPID: 11, group: 10,
                                     device: 123, foregroundGroup: 10)
        records[43] = identity(43, device: UInt32.max)
        let store = makeStore()
        let plain = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(12)))
        let native = try XCTUnwrap(store.captureTarget(for: surface(foreground: 11)))
        let old = intent(color: "#123ABC", time: 998, pid: 12)
        try store.publishIntent(old)
        try store.bindOrdinaryIntentUnlocked(old, to: plain, deadline: deadline())
        let latest = intent(delivery: "latest-delivery", color: "#ABCDEF", time: 999, pid: 12)
        try store.publishIntent(latest)
        try store.bindOrdinaryIntentUnlocked(latest, to: native, deadline: deadline())
        records[12] = nil
        XCTAssertEqual(Set(try store.equivalentBindingsUnlocked(for: plain, deadline: deadline())), Set([plain, native]))
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for: plain, deadline: deadline()), "#ABCDEF")
        XCTAssertEqual(try store.ordinaryBackgroundUnlocked(for: native, deadline: deadline()), "#ABCDEF")
        let unmatched = intent(delivery: "unbound-delivery", color: "reset", time: 1_000, pid: 12)
        try store.publishIntent(unmatched)
        XCTAssertNil(try store.ordinaryBackgroundUnlocked(for: plain, deadline: deadline()))
        XCTAssertNil(try store.ordinaryBackgroundUnlocked(for: native, deadline: deadline()))
    }

    func testEquivalentAliasLookupHonorsHeldLockDeadlineAndRejectsUnknownNativeMetadata() throws {
        records[43] = identity(43, device: UInt32.max)
        let store = makeStore()
        let plain = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        let native = try XCTUnwrap(store.captureTarget(for: surface(foreground: 11)))
        try store.cacheTargetUnlocked(plain, deadline: deadline())
        try store.cacheTargetUnlocked(native, deadline: deadline())
        let lockURL = try store.lockURL(forTTY: tty)
        let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { XCTFail("Fixture lock unavailable"); return }
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        XCTAssertEqual(Set(try store.equivalentBindingsUnlocked(for: native, deadline: deadline())), Set([plain, native]))
        XCTAssertThrowsError(try store.equivalentBindingsUnlocked(for: plain,
            deadline: DispatchTime.now().uptimeNanoseconds - 1)) { error in
            XCTAssertEqual(String(describing: error), TerminalVisualStateError.deadlineExceeded.description)
        }
        records[43] = nil
        XCTAssertThrowsError(try store.equivalentBindingsUnlocked(for: plain, deadline: deadline()))
    }

    func testBindingRequiresExactLatestRecordAndReportsCorruptBoundIntent() throws {
        let store = makeStore()
        try store.publishIntent(intent())
        let binding = try XCTUnwrap(store.captureTarget(tty: tty, owner: generation(11)))
        XCTAssertThrowsError(try store.bindOrdinaryIntentUnlocked(intent(color: "reset"), to: binding, deadline: deadline()))
        try store.bindOrdinaryIntentUnlocked(intent(), to: binding, deadline: deadline())
        let boundURL = try targetRecordURL("bound-intent.json")
        var invalid = try JSONSerialization.jsonObject(with: Data(contentsOf: boundURL)) as! [String: Any]
        invalid["payload"] = "BODY_SENTINEL"
        try JSONSerialization.data(withJSONObject: invalid).write(to: boundURL)
        XCTAssertThrowsError(try store.ordinaryBackgroundUnlocked(for: binding, deadline: deadline())) { error in
            XCTAssertFalse(String(describing: error).contains("BODY_SENTINEL"))
        }
        let snapshot = store.cachedRecords()
        XCTAssertEqual(snapshot.bindings, [binding])
        XCTAssertEqual(snapshot.unreadable, [boundURL])
    }

    func testBoundIntentFilenameAloneDoesNotAuthorizeACachedTarget() throws {
        let orphan = organizer.appendingPathComponent("targets/not-a-binding/bound-intent.json")
        try FileManager.default.createDirectory(at: orphan.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(intent()).write(to: orphan)
        let snapshot = makeStore().cachedRecords()
        XCTAssertTrue(snapshot.bindings.isEmpty)
        XCTAssertEqual(snapshot.unreadable.first?.resolvingSymlinksInPath(), orphan.resolvingSymlinksInPath())
    }

    private func targetRecordURL(_ filename: String) throws -> URL {
        let files = try XCTUnwrap(FileManager.default.enumerator(at: organizer.appendingPathComponent("targets"),
            includingPropertiesForKeys: nil)).allObjects.compactMap { $0 as? URL }
        return try XCTUnwrap(files.first { $0.lastPathComponent == filename })
    }

    private func deadline() -> UInt64 { DispatchTime.now().uptimeNanoseconds + 100_000_000 }

    private func effect(_ binding: TerminalTargetBinding, id: String = "effect-43") -> TerminalEffectRecord {
        TerminalEffectRecord(target: binding, controller: generation(90), effectID: id,
            kind: .selectiveBackground, background: "#123abc", heartbeatAt: 1_000)
    }

    private var organizer: URL { root.appendingPathComponent("organizer") }

    private func makeStore(directory: URL? = nil) -> TerminalVisualStateStore {
        TerminalVisualStateStore(runtimeDirectory: directory ?? root, clock: clock,
            lookup: { self.records[$0] }, device: { self.devices[$0] },
            deviceMissing: { self.missingDevices.contains($0) },
            processMissing: { self.missingProcesses.contains($0) },
            descriptorDevice: { self.descriptorDevices[$0] })
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
