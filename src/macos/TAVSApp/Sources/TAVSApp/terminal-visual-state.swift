import Foundation
import Darwin

struct TerminalObservation: Codable, Equatable {
    var schema = 1
    var tty: String
    var device: UInt32?
    var producer: ProcessGeneration?
    var provider: String
    var verifiedAgent: Bool
    var state: String
    var event: String?
    var deliveryID: String
    var responseID: String?
    var observedAt: Double
}

struct OrdinaryBackgroundIntent: Codable, Equatable {
    var schema = 1
    var tty: String
    var device: UInt32?
    var producer: ProcessGeneration?
    var deliveryID: String
    var updatedAt: Double
    var background: String
}

struct TerminalVisualCoverage: Equatable {
    let observation: TerminalObservation?
    let intent: OrdinaryBackgroundIntent?
    let attentionEligible: Bool
    let status: String
}

enum TerminalVisualStateError: Error, CustomStringConvertible {
    case invalidRecord, storageUnavailable, lockUnavailable, staleDelivery, staleObservation, staleIntent

    var description: String {
        switch self {
        case .invalidRecord: return "Invalid organizer record."
        case .storageUnavailable: return "Organizer storage unavailable."
        case .lockUnavailable: return "Organizer writer busy."
        case .staleDelivery: return "Stale organizer delivery."
        case .staleObservation: return "Stale organizer observation."
        case .staleIntent: return "Stale organizer intent."
        }
    }
}

final class TerminalVisualStateStore {
    private let directory: URL
    private let clock: Clock
    private let lookup: (Int32) -> ProcessIdentity?
    private let device: (String) -> UInt32?
    private static let sizeLimit = 8_192
    private static let states: Set<String> = [
        "processing", "permission", "complete", "idle", "compacting", "reset", "subagent", "tool_error"
    ]
    private static let events: Set<String> = [
        "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest",
        "Notification", "Stop", "SessionStart", "SessionEnd", "PreCompact", "SubagentStart",
        "SubagentStop", "permission_prompt", "idle_prompt", "agent-turn-complete"
    ]

    init(runtimeDirectory: URL, clock: Clock = SystemClock(),
         lookup: @escaping (Int32) -> ProcessIdentity? = ProcessIdentity.inspect,
         device: @escaping (String) -> UInt32? = ProcessIdentity.deviceNumber) {
        directory = runtimeDirectory.appendingPathComponent("organizer", isDirectory: true)
        self.clock = clock
        self.lookup = lookup
        self.device = device
    }

    func publishObservation(_ record: TerminalObservation) throws {
        try validate(record)
        try withLock(record.tty) {
            let url = recordURL("observation", tty: record.tty)
            if let current: TerminalObservation = try readLatest(url, validating: validate, recoverInvalid: true) {
                guard record.observedAt >= current.observedAt else {
                    throw TerminalVisualStateError.staleObservation
                }
            }
            try write(record, to: url)
        }
    }

    func publishIntent(_ record: OrdinaryBackgroundIntent, synthetic: Bool = false,
                       intakeAt: Double? = nil) throws {
        try validate(record)
        if let intakeAt = intakeAt {
            guard intakeAt.isFinite, intakeAt > 0, intakeAt <= record.updatedAt else {
                throw TerminalVisualStateError.invalidRecord
            }
        }
        var normalized = record
        normalized.background = Self.normalizedBackground(record.background)!
        try withLock(record.tty) {
            var observation: TerminalObservation?
            do {
                observation = try read(recordURL("observation", tty: record.tty))
                if let observation = observation { try validate(observation) }
            } catch {
                if synthetic { throw error }
                observation = nil
            }
            if let intakeAt = intakeAt, let observation = observation,
               observation.observedAt > intakeAt {
                throw TerminalVisualStateError.staleDelivery
            }
            let matchesObservation = observation.map {
                $0.tty == record.tty && $0.deliveryID == record.deliveryID
                    && $0.producer == record.producer && $0.device == record.device
            } ?? false
            if synthetic {
                guard matchesObservation, validProducer(tty: record.tty,
                          device: record.device, producer: record.producer) else {
                    throw TerminalVisualStateError.staleDelivery
                }
            }
            let url = recordURL("intent", tty: record.tty)
            if let current: OrdinaryBackgroundIntent = try readLatest(url, validating: validate,
                                                                     recoverInvalid: !synthetic) {
                // A new intake wins over a later render time from the superseded delivery.
                let supersedesDelivery = matchesObservation && (current.deliveryID != record.deliveryID
                    || current.producer != record.producer || current.device != record.device)
                guard supersedesDelivery || record.updatedAt >= current.updatedAt else {
                    throw TerminalVisualStateError.staleIntent
                }
            }
            try write(normalized, to: url)
        }
    }

    // Call only with a fresh successful catalogue row; cached rows cannot authorize adoption.
    func coverage(for surface: GhosttySurface) -> TerminalVisualCoverage {
        guard surface.mappingIssue == nil, let tty = surface.tty, Self.concreteTTY(tty) else {
            return TerminalVisualCoverage(observation: nil, intent: nil, attentionEligible: false,
                                          status: "Native TTY mapping unavailable.")
        }
        do {
            return try withLock(tty) {
                var observation: TerminalObservation?
                var intent: OrdinaryBackgroundIntent?
                var invalid = false
                do {
                    if let record: TerminalObservation = try read(recordURL("observation", tty: tty)) {
                        try validate(record)
                        if record.tty == tty, try adopt(tty: tty, device: record.device, producer: record.producer,
                            delivery: record.deliveryID, observation: true, surface: surface) {
                            observation = record
                        } else { invalid = true }
                    }
                } catch { invalid = true }
                do {
                    if var record: OrdinaryBackgroundIntent = try read(recordURL("intent", tty: tty)) {
                        try validate(record)
                        if record.tty == tty, try adopt(tty: tty, device: record.device, producer: record.producer,
                            delivery: record.deliveryID, observation: false, surface: surface) {
                            record.background = Self.normalizedBackground(record.background)!
                            intent = record
                        } else { invalid = true }
                    }
                } catch { invalid = true }
                let status: String
                if let observation = observation {
                    if !observation.verifiedAgent { status = "Unverified agent observation." }
                    else if correlated(observation.producer!, device: observation.device!, surface: surface) {
                        status = "Agent observation."
                    } else { status = "Last-known agent observation." }
                } else if invalid { status = "Observation or intent unavailable." }
                else if intent != nil { status = "Ordinary background only; no agent observation." }
                else { status = "No agent observation or background intent." }
                return TerminalVisualCoverage(observation: observation, intent: intent,
                    attentionEligible: observation.map(Self.attentionEligible) ?? false, status: status)
            }
        } catch {
            return TerminalVisualCoverage(observation: nil, intent: nil, attentionEligible: false,
                                          status: "Organizer records unavailable.")
        }
    }

    fileprivate struct Adoption: Codable {
        let schema: Int
        let tty: String
        let device: UInt32
        let producer: ProcessGeneration
        let surface: GhosttySurfaceID
        var observationDeliveryID: String?
        var intentDeliveryID: String?
    }

    private func adopt(tty: String, device: UInt32?, producer: ProcessGeneration?, delivery: String,
                       observation: Bool, surface: GhosttySurface) throws -> Bool {
        guard let device = device, let producer = producer,
              validProducer(tty: tty, device: device, producer: producer) else { return false }
        let filename = "adoption-\(key(tty))-\(producer.pid)-\(producer.startSeconds)-\(producer.startMicroseconds).json"
        let url = directory.appendingPathComponent(filename)
        var binding: Adoption
        if let saved: Adoption = try read(url) {
            guard saved.schema == 1, saved.tty == tty, saved.device == device,
                  saved.producer == producer, saved.surface == surface.id,
                  saved.observationDeliveryID.map(Self.validID) ?? true,
                  saved.intentDeliveryID.map(Self.validID) ?? true else { return false }
            binding = saved
            if observation ? saved.observationDeliveryID == delivery
                : saved.intentDeliveryID == delivery || saved.observationDeliveryID == delivery {
                return true
            }
        } else {
            binding = Adoption(schema: 1, tty: tty, device: device, producer: producer,
                               surface: surface.id, observationDeliveryID: nil, intentDeliveryID: nil)
        }
        guard correlated(producer, device: device, surface: surface) else { return false }
        if observation { binding.observationDeliveryID = delivery } else { binding.intentDeliveryID = delivery }
        try write(binding, to: url)
        return true
    }

    private func validProducer(tty: String, device expected: UInt32?, producer: ProcessGeneration?) -> Bool {
        guard Self.concreteTTY(tty), let expected = expected, let producer = producer,
              device(tty) == expected, let identity = lookup(producer.pid),
              identity.generation == producer, identity.device == expected else { return false }
        return true
    }

    private func correlated(_ producer: ProcessGeneration, device: UInt32, surface: GhosttySurface) -> Bool {
        guard let pid = surface.foregroundPID, let foreground = lookup(pid) else { return false }
        return ProcessIdentity.foregroundFamilyContains(producer: producer, foreground: foreground.generation,
                                                       device: device, lookup: lookup)
    }

    private static func attentionEligible(_ record: TerminalObservation) -> Bool {
        guard record.verifiedAgent, let event = record.event else { return false }
        if record.provider == "codex" {
            return record.state == "complete" && event == "agent-turn-complete" && record.responseID != nil
        }
        return record.state == "complete" && event == "Stop"
            || record.state == "permission" && ["PermissionRequest", "Notification", "permission_prompt"].contains(event)
    }

    private func validate(_ record: TerminalObservation) throws {
        guard record.schema == 1, ["claude", "codex"].contains(record.provider),
              Self.states.contains(record.state), record.event.map(Self.events.contains) ?? true,
              record.responseID.map(Self.validID) ?? true else { throw TerminalVisualStateError.invalidRecord }
        try validate(tty: record.tty, device: record.device, producer: record.producer,
                     delivery: record.deliveryID, timestamp: record.observedAt)
    }

    private func validate(_ record: OrdinaryBackgroundIntent) throws {
        guard record.schema == 1, Self.normalizedBackground(record.background) != nil else {
            throw TerminalVisualStateError.invalidRecord
        }
        try validate(tty: record.tty, device: record.device, producer: record.producer,
                     delivery: record.deliveryID, timestamp: record.updatedAt)
    }

    private func validate(tty: String, device: UInt32?, producer: ProcessGeneration?,
                          delivery: String, timestamp: Double) throws {
        guard tty.utf8.count <= 128, tty.hasPrefix("/"),
              URL(fileURLWithPath: tty).standardizedFileURL.path != "/dev/tty",
              !tty.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }),
              tty.rangeOfCharacter(from: .controlCharacters) == nil, Self.validID(delivery),
              device != UInt32.max, timestamp.isFinite, timestamp > 0,
              timestamp <= clock.now().timeIntervalSince1970 else { throw TerminalVisualStateError.invalidRecord }
        if let producer = producer {
            guard producer.pid > 0, producer.startSeconds > 0, producer.startMicroseconds < 1_000_000,
                  Double(producer.startSeconds) + Double(producer.startMicroseconds) / 1_000_000 <= timestamp else {
                throw TerminalVisualStateError.invalidRecord
            }
        }
    }

    private static func concreteTTY(_ tty: String) -> Bool {
        tty.hasPrefix("/dev/tty") && tty != "/dev/tty" && tty.dropFirst(5).allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber)
        }
    }

    private static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                || [45, 46, 58, 95].contains($0)
        }
    }

    static func normalizedBackground(_ raw: String) -> String? {
        guard raw.utf8.count <= 32 else { return nil }
        if raw == "reset" { return raw }
        if let hex = PauseVisual.normalizedHexColor(raw) { return hex }
        guard raw.hasPrefix("rgb:"), raw.utf8.count <= 18 else { return nil }
        let pieces = raw.dropFirst(4).split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 3 else { return nil }
        var result = "#"
        for component in pieces {
            guard (1...4).contains(component.count), component.utf8.allSatisfy({
                (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
            }), let value = UInt32(component, radix: 16) else { return nil }
            let maximum = UInt32((1 << (component.count * 4)) - 1)
            result += String(format: "%02X", (value * 255 + maximum / 2) / maximum)
        }
        return result
    }

    private func key(_ tty: String) -> String {
        Data(tty.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private func recordURL(_ kind: String, tty: String) -> URL {
        directory.appendingPathComponent("\(kind)-\(key(tty)).json")
    }

    private func withLock<T>(_ tty: String, body: () throws -> T) throws -> T {
        guard directory.isFileURL else { throw TerminalVisualStateError.storageUnavailable }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch { throw TerminalVisualStateError.storageUnavailable }
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
            throw TerminalVisualStateError.storageUnavailable
        }
        let url = directory.appendingPathComponent("writer-\(key(tty)).lock")
        let fd = open(url.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw TerminalVisualStateError.storageUnavailable }
        defer { close(fd) }
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
            throw TerminalVisualStateError.storageUnavailable
        }
        let deadline = DispatchTime.now().uptimeNanoseconds + 100_000_000
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR else {
                throw TerminalVisualStateError.storageUnavailable
            }
            guard DispatchTime.now().uptimeNanoseconds < deadline else {
                throw TerminalVisualStateError.lockUnavailable
            }
            usleep(1_000)
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    private func read<T: Decodable>(_ url: URL) throws -> T? {
        var before = stat()
        if lstat(url.path, &before) != 0 {
            if errno == ENOENT { return nil }
            throw TerminalVisualStateError.storageUnavailable
        }
        guard before.st_mode & S_IFMT == S_IFREG, before.st_size >= 0,
              before.st_size <= Self.sizeLimit else { throw TerminalVisualStateError.invalidRecord }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw TerminalVisualStateError.storageUnavailable }
        defer { close(fd) }
        var current = stat()
        guard fstat(fd, &current) == 0, current.st_mode & S_IFMT == S_IFREG,
              current.st_ino == before.st_ino, current.st_dev == before.st_dev,
              current.st_size >= 0, current.st_size <= Self.sizeLimit else {
            throw TerminalVisualStateError.invalidRecord
        }
        var buffer = [UInt8](repeating: 0, count: Self.sizeLimit + 1)
        var data = Data()
        while data.count <= Self.sizeLimit {
            let count = Darwin.read(fd, &buffer, buffer.count - data.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw TerminalVisualStateError.storageUnavailable
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        guard data.count <= Self.sizeLimit else { throw TerminalVisualStateError.invalidRecord }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw TerminalVisualStateError.invalidRecord }
    }

    private func readLatest<T: Decodable>(_ url: URL, validating validate: (T) throws -> Void,
                                         recoverInvalid: Bool) throws -> T? {
        do {
            let record: T? = try read(url)
            if let record = record { try validate(record) }
            return record
        } catch TerminalVisualStateError.invalidRecord {
            var info = stat()
            guard recoverInvalid, lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
                throw TerminalVisualStateError.invalidRecord
            }
            return nil
        }
    }

    private func write<T: Encodable>(_ record: T, to url: URL) throws {
        do {
            let data = try JSONEncoder().encode(record)
            guard data.count <= Self.sizeLimit else { throw TerminalVisualStateError.invalidRecord }
            let temporary = directory.appendingPathComponent(".record-\(UUID().uuidString).tmp")
            let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard fd >= 0 else { throw TerminalVisualStateError.storageUnavailable }
            defer { close(fd); unlink(temporary.path) }
            try data.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    let written = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                    if written < 0, errno == EINTR { continue }
                    guard written > 0 else { throw TerminalVisualStateError.storageUnavailable }
                    offset += written
                }
            }
            guard rename(temporary.path, url.path) == 0 else { throw TerminalVisualStateError.storageUnavailable }
        } catch let error as TerminalVisualStateError { throw error }
        catch { throw TerminalVisualStateError.storageUnavailable }
    }
}

private struct VisualRecordKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private func requireVisualKeys(_ decoder: Decoder, _ allowed: Set<String>) throws {
    let keys = try decoder.container(keyedBy: VisualRecordKey.self).allKeys.map(\.stringValue)
    guard Set(keys).isSubset(of: allowed) else { throw TerminalVisualStateError.invalidRecord }
}

private func decodeVisualProducer<K: CodingKey>(_ container: KeyedDecodingContainer<K>,
                                               _ key: K) throws -> ProcessGeneration? {
    guard container.contains(key), try !container.decodeNil(forKey: key) else { return nil }
    let decoder = try container.superDecoder(forKey: key)
    try requireVisualKeys(decoder, ["pid", "startSeconds", "startMicroseconds"])
    return try ProcessGeneration(from: decoder)
}

extension TerminalObservation {
    init(from decoder: Decoder) throws {
        try requireVisualKeys(decoder, ["schema", "tty", "device", "producer", "provider", "verifiedAgent",
                                       "state", "event", "deliveryID", "responseID", "observedAt"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(Int.self, forKey: .schema)
        tty = try c.decode(String.self, forKey: .tty)
        device = try c.decodeIfPresent(UInt32.self, forKey: .device)
        producer = try decodeVisualProducer(c, .producer)
        provider = try c.decode(String.self, forKey: .provider)
        verifiedAgent = try c.decode(Bool.self, forKey: .verifiedAgent)
        state = try c.decode(String.self, forKey: .state)
        event = try c.decodeIfPresent(String.self, forKey: .event)
        deliveryID = try c.decode(String.self, forKey: .deliveryID)
        responseID = try c.decodeIfPresent(String.self, forKey: .responseID)
        observedAt = try c.decode(Double.self, forKey: .observedAt)
    }
}

extension OrdinaryBackgroundIntent {
    init(from decoder: Decoder) throws {
        try requireVisualKeys(decoder, ["schema", "tty", "device", "producer", "deliveryID", "updatedAt", "background"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(Int.self, forKey: .schema)
        tty = try c.decode(String.self, forKey: .tty)
        device = try c.decodeIfPresent(UInt32.self, forKey: .device)
        producer = try decodeVisualProducer(c, .producer)
        deliveryID = try c.decode(String.self, forKey: .deliveryID)
        updatedAt = try c.decode(Double.self, forKey: .updatedAt)
        background = try c.decode(String.self, forKey: .background)
    }
}

extension TerminalVisualStateStore.Adoption {
    init(from decoder: Decoder) throws {
        try requireVisualKeys(decoder, ["schema", "tty", "device", "producer", "surface",
                                       "observationDeliveryID", "intentDeliveryID"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(Int.self, forKey: .schema)
        tty = try c.decode(String.self, forKey: .tty)
        device = try c.decode(UInt32.self, forKey: .device)
        guard let decoded = try decodeVisualProducer(c, .producer) else { throw TerminalVisualStateError.invalidRecord }
        producer = decoded
        let surfaceDecoder = try c.superDecoder(forKey: .surface)
        try requireVisualKeys(surfaceDecoder, ["application", "terminalID"])
        let surfaceContainer = try surfaceDecoder.container(keyedBy: VisualRecordKey.self)
        let applicationKey = VisualRecordKey(stringValue: "application")!
        guard try decodeVisualProducer(surfaceContainer, applicationKey) != nil else {
            throw TerminalVisualStateError.invalidRecord
        }
        surface = try GhosttySurfaceID(from: surfaceDecoder)
        observationDeliveryID = try c.decodeIfPresent(String.self, forKey: .observationDeliveryID)
        intentDeliveryID = try c.decodeIfPresent(String.self, forKey: .intentDeliveryID)
    }
}
