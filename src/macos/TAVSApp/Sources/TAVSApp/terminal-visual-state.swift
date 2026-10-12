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

struct TerminalTargetBinding: Codable, Hashable {
    let tty: String
    let device: UInt32
    let ttyOwner: ProcessGeneration
    let nativeSurface: GhosttySurfaceID?

    var physicalTarget: TerminalTargetBinding {
        TerminalTargetBinding(tty: tty, device: device, ttyOwner: ttyOwner, nativeSurface: nil)
    }
}

enum TerminalTargetValidation: Equatable { case valid, vanished, unavailable }
enum TerminalEffectKind: String, Codable { case globalRestriction, selectiveBackground }

struct TerminalEffectRecord: Codable, Equatable {
    var schema = 1
    var target: TerminalTargetBinding
    var controller: ProcessGeneration
    var effectID: String
    var kind: TerminalEffectKind
    var background: String
    var heartbeatAt: Double
    var active = true
}

struct TerminalCachedVisualRecords {
    let bindings: [TerminalTargetBinding]
    let effects: [TerminalEffectRecord]
    let unreadable: [URL]
}

enum TerminalVisualStateError: Error, CustomStringConvertible {
    case invalidRecord, storageUnavailable, lockUnavailable, staleDelivery, staleObservation, staleIntent
    case targetUnavailable, staleEffect, deadlineExceeded

    var description: String {
        switch self {
        case .invalidRecord: return "Invalid organizer record."
        case .storageUnavailable: return "Organizer storage unavailable."
        case .lockUnavailable: return "Organizer writer busy."
        case .staleDelivery: return "Stale organizer delivery."
        case .staleObservation: return "Stale organizer observation."
        case .staleIntent: return "Stale organizer intent."
        case .targetUnavailable: return "Organizer target unavailable."
        case .staleEffect: return "Stale organizer effect."
        case .deadlineExceeded: return "Organizer deadline exceeded."
        }
    }
}

final class TerminalVisualStateStore {
    private let directory: URL
    private let clock: Clock
    private let lookup: (Int32) -> ProcessIdentity?
    private let device: (String) -> UInt32?
    private let deviceMissing: (String) -> Bool
    private let processMissing: (Int32) -> Bool
    private let descriptorDevice: (Int32) -> UInt32?
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
         device: @escaping (String) -> UInt32? = ProcessIdentity.deviceNumber,
         deviceMissing: @escaping (String) -> Bool = TerminalVisualStateStore.knownDeviceMissing,
         processMissing: @escaping (Int32) -> Bool = TerminalVisualStateStore.knownProcessMissing,
         descriptorDevice: @escaping (Int32) -> UInt32? = TerminalVisualStateStore.characterDevice) {
        directory = runtimeDirectory.appendingPathComponent("organizer", isDirectory: true)
        self.clock = clock
        self.lookup = lookup
        self.device = device
        self.deviceMissing = deviceMissing
        self.processMissing = processMissing
        self.descriptorDevice = descriptorDevice
    }

    func lockURL(forTTY tty: String) throws -> URL {
        guard directory.isFileURL, tty.hasPrefix("/"), tty.utf8.count <= 128,
              !tty.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }),
              tty.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw TerminalVisualStateError.invalidRecord
        }
        return directory.appendingPathComponent("writer-\(key(tty)).lock")
    }

    func captureTarget(for surface: GhosttySurface) -> TerminalTargetBinding? {
        guard surface.mappingIssue == nil, let tty = surface.tty, Self.concreteTTY(tty),
              let number = device(tty), let pid = surface.foregroundPID, let foreground = lookup(pid),
              ProcessIdentity.foregroundFamilyContains(producer: foreground.generation,
                foreground: foreground.generation, device: number, lookup: lookup),
              let owner = continuingOwner(foreground.generation, device: number) else { return nil }
        let binding = TerminalTargetBinding(tty: tty, device: number, ttyOwner: owner, nativeSurface: surface.id)
        return validateTarget(binding) == .valid ? binding : nil
    }

    func captureTarget(tty: String, owner: ProcessGeneration) -> TerminalTargetBinding? {
        guard Self.concreteTTY(tty), let number = device(tty),
              let continuing = continuingOwner(owner, device: number) else { return nil }
        let binding = TerminalTargetBinding(tty: tty, device: number, ttyOwner: continuing, nativeSurface: nil)
        return validateTarget(binding) == .valid ? binding : nil
    }

    func validateTarget(_ target: TerminalTargetBinding, descriptor: Int32? = nil,
                        native: GhosttySurface? = nil, confirmedNativeAbsent: Bool = false) -> TerminalTargetValidation {
        do { try validate(target) } catch { return .unavailable }
        let owner = lookup(target.ttyOwner.pid)
        if let owner = owner, owner.generation != target.ttyOwner { return .vanished }
        if owner == nil && processMissing(target.ttyOwner.pid) { return .vanished }
        if confirmedNativeAbsent { return target.nativeSurface == nil ? .unavailable : .vanished }
        if let number = device(target.tty) {
            if number != target.device { return .vanished }
        } else { return deviceMissing(target.tty) ? .vanished : .unavailable }
        if let surface = target.nativeSurface {
            if let application = lookup(surface.application.pid) {
                if application.generation != surface.application { return .vanished }
            } else { return processMissing(surface.application.pid) ? .vanished : .unavailable }
            if let native = native,
               native.mappingIssue != nil || native.id != surface || native.tty != target.tty {
                return .unavailable
            }
        }
        guard let owner = owner else { return .unavailable }
        guard owner.device == target.device else { return .unavailable }
        if let descriptor = descriptor, descriptorDevice(descriptor) != target.device { return .unavailable }
        return .valid
    }

    // Global lock/mute policy must be recomputed separately; it is not a selective lease.
    func isSelectiveLeaseActive(_ effect: TerminalEffectRecord) -> Bool {
        guard effect.kind == .selectiveBackground, effect.active,
              (try? validate(effect)) != nil,
              clock.now().timeIntervalSince1970 - effect.heartbeatAt <= 6,
              lookup(effect.controller.pid)?.generation == effect.controller else { return false }
        return true
    }

    // These helpers require the caller's existing writer lock and original deadline.
    func cacheTargetUnlocked(_ target: TerminalTargetBinding, deadline: UInt64) throws {
        try checkDeadline(deadline)
        try validate(target)
        guard validateTarget(target) == .valid else { throw TerminalVisualStateError.targetUnavailable }
        try checkDeadline(deadline)
        let url = targetURL(target, filename: "target.json")
        if let saved: CachedTarget = try read(url, deadline: deadline) {
            guard saved.schema == 1, saved.target == target else { throw TerminalVisualStateError.invalidRecord }
            return
        }
        try prepareTargetDirectory(url.deletingLastPathComponent(), deadline: deadline)
        try write(CachedTarget(target: target), to: url, deadline: deadline)
    }

    func currentEffectUnlocked(_ target: TerminalTargetBinding, deadline: UInt64) throws -> TerminalEffectRecord? {
        try validate(target)
        let record: TerminalEffectRecord? = try read(targetURL(target, filename: "effect.json"), deadline: deadline)
        if let record = record {
            try validate(record)
            guard record.target == target else { throw TerminalVisualStateError.invalidRecord }
        }
        try checkDeadline(deadline)
        return record
    }

    func saveEffectUnlocked(_ effect: TerminalEffectRecord, deadline: UInt64) throws {
        try checkDeadline(deadline)
        try validate(effect)
        if let current = try currentEffectUnlocked(effect.target, deadline: deadline),
           current.effectID == effect.effectID {
            guard current.controller == effect.controller, current.active || !effect.active else {
                throw TerminalVisualStateError.staleEffect
            }
        }
        try cacheTargetUnlocked(effect.target, deadline: deadline)
        var normalized = effect
        normalized.background = Self.normalizedBackground(effect.background)!
        try write(normalized, to: targetURL(effect.target, filename: "effect.json"), deadline: deadline)
    }

    func matchingEffectUnlocked(_ target: TerminalTargetBinding, effectID: String,
                                controller: ProcessGeneration, deadline: UInt64) throws -> TerminalEffectRecord? {
        guard let effect = try currentEffectUnlocked(target, deadline: deadline), effect.active,
              effect.effectID == effectID, effect.controller == controller else { return nil }
        return effect
    }

    func refreshEffectUnlocked(_ target: TerminalTargetBinding, effectID: String,
                               controller: ProcessGeneration, deadline: UInt64) throws -> Bool {
        guard var effect = try matchingEffectUnlocked(target, effectID: effectID,
            controller: controller, deadline: deadline), lookup(controller.pid)?.generation == controller,
              validateTarget(target) == .valid else { try checkDeadline(deadline); return false }
        effect.heartbeatAt = clock.now().timeIntervalSince1970
        try write(effect, to: targetURL(target, filename: "effect.json"), deadline: deadline)
        return true
    }

    func cancelEffectUnlocked(_ target: TerminalTargetBinding, effectID: String,
                              controller: ProcessGeneration, deadline: UInt64) throws -> Bool {
        guard var effect = try matchingEffectUnlocked(target, effectID: effectID,
            controller: controller, deadline: deadline) else { return false }
        effect.active = false
        try write(effect, to: targetURL(target, filename: "effect.json"), deadline: deadline)
        return true
    }

    // Reads only this verified TTY-owner lifetime under the caller's held lock.
    // A plain binding and one native binding may share state; live native ambiguity cannot.
    func equivalentBindingsUnlocked(for target: TerminalTargetBinding,
                                    deadline: UInt64) throws -> [TerminalTargetBinding] {
        try checkDeadline(deadline)
        let validation = validateTarget(target)
        try checkDeadline(deadline)
        guard validation == .valid else { throw TerminalVisualStateError.targetUnavailable }
        let root = targetURL(target.physicalTarget, filename: "target.json")
            .deletingLastPathComponent().deletingLastPathComponent()
        var info = stat()
        if lstat(root.path, &info) != 0 {
            let absent = errno == ENOENT
            try checkDeadline(deadline)
            if absent { return [target] }
            throw TerminalVisualStateError.storageUnavailable
        }
        guard info.st_mode & S_IFMT == S_IFDIR else { throw TerminalVisualStateError.storageUnavailable }
        var unavailable = false
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles], errorHandler: { _, _ in unavailable = true; return false })
        try checkDeadline(deadline)
        guard let enumerator = enumerator else { throw TerminalVisualStateError.storageUnavailable }
        var aliases: Set<TerminalTargetBinding> = [target]
        for case let url as URL in enumerator {
            try checkDeadline(deadline)
            guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT != S_IFLNK else {
                throw TerminalVisualStateError.storageUnavailable
            }
            if url.lastPathComponent != "target.json" { continue }
            guard let saved: CachedTarget = try read(url, deadline: deadline), saved.schema == 1,
                  saved.target.physicalTarget == target.physicalTarget,
                  targetURL(saved.target, filename: "target.json").resolvingSymlinksInPath()
                    == url.resolvingSymlinksInPath() else { throw TerminalVisualStateError.invalidRecord }
            try validate(saved.target)
            let status = validateTarget(saved.target)
            try checkDeadline(deadline)
            if status == .unavailable { throw TerminalVisualStateError.targetUnavailable }
            if status == .valid { aliases.insert(saved.target) }
        }
        try checkDeadline(deadline)
        guard !unavailable else { throw TerminalVisualStateError.storageUnavailable }
        guard Set(aliases.compactMap(\.nativeSurface)).count <= 1 else {
            throw TerminalVisualStateError.targetUnavailable
        }
        return Array(aliases)
    }

    func ordinaryBackgroundUnlocked(for target: TerminalTargetBinding, deadline: UInt64) throws -> String? {
        try checkDeadline(deadline)
        guard validateTarget(target) == .valid else { try checkDeadline(deadline); return nil }
        let latest: OrdinaryBackgroundIntent? = try read(recordURL("intent", tty: target.tty), deadline: deadline)
        let aliases = try equivalentBindingsUnlocked(for: target, deadline: deadline)
        let bound = try aliases.compactMap { try boundIntent(for: $0, deadline: deadline) }
        guard let intent = latest else { return nil }
        try validate(intent)
        guard intent.tty == target.tty, intent.device == target.device, let producer = intent.producer else {
            try checkDeadline(deadline); return nil
        }
        if bound.contains(intent) {
            try checkDeadline(deadline)
            return Self.normalizedBackground(intent.background)
        }
        guard validProducer(tty: target.tty, device: target.device, producer: producer),
              continuingOwner(producer, device: target.device) == target.ttyOwner else {
            try checkDeadline(deadline); return nil
        }
        if let surface = target.nativeSurface {
            let url = adoptionURL(tty: target.tty, producer: producer)
            guard let binding: Adoption = try read(url, deadline: deadline), binding.schema == 1,
                  binding.surface == surface, binding.tty == target.tty, binding.device == target.device,
                  binding.producer == producer,
                  binding.intentDeliveryID == intent.deliveryID || binding.observationDeliveryID == intent.deliveryID
            else { return nil }
        }
        try checkDeadline(deadline)
        return Self.normalizedBackground(intent.background)
    }

    func bindOrdinaryIntentUnlocked(_ intent: OrdinaryBackgroundIntent, to target: TerminalTargetBinding,
                                    deadline: UInt64) throws {
        try checkDeadline(deadline)
        try validate(intent)
        guard validateTarget(target) == .valid, intent.tty == target.tty, intent.device == target.device,
              let producer = intent.producer, validProducer(tty: target.tty, device: target.device, producer: producer),
              continuingOwner(producer, device: target.device) == target.ttyOwner else {
            try checkDeadline(deadline)
            throw TerminalVisualStateError.targetUnavailable
        }
        var normalized = intent
        normalized.background = Self.normalizedBackground(intent.background)!
        guard let latest: OrdinaryBackgroundIntent = try read(recordURL("intent", tty: target.tty), deadline: deadline)
        else { throw TerminalVisualStateError.staleIntent }
        try validate(latest)
        guard latest == normalized else { throw TerminalVisualStateError.staleIntent }
        _ = try boundIntent(for: target, deadline: deadline)
        try cacheTargetUnlocked(target, deadline: deadline)
        try write(normalized, to: targetURL(target, filename: "bound-intent.json"), deadline: deadline)
    }

    private func boundIntent(for target: TerminalTargetBinding, deadline: UInt64? = nil) throws -> OrdinaryBackgroundIntent? {
        guard let intent: OrdinaryBackgroundIntent = try read(targetURL(target, filename: "bound-intent.json"),
                                                             deadline: deadline) else { return nil }
        try validate(intent)
        guard let saved: CachedTarget = try read(targetURL(target, filename: "target.json"), deadline: deadline),
              saved.schema == 1, saved.target == target, intent.tty == target.tty,
              intent.device == target.device, intent.producer != nil else {
            throw TerminalVisualStateError.invalidRecord
        }
        try checkDeadline(deadline)
        return intent
    }

    func cachedRecords() -> TerminalCachedVisualRecords {
        let root = directory.appendingPathComponent("targets", isDirectory: true)
        var info = stat()
        if lstat(root.path, &info) != 0 {
            return TerminalCachedVisualRecords(bindings: [], effects: [], unreadable: errno == ENOENT ? [] : [root])
        }
        guard info.st_mode & S_IFMT == S_IFDIR else {
            return TerminalCachedVisualRecords(bindings: [], effects: [], unreadable: [root])
        }
        var bindings: [TerminalTargetBinding] = [], effects: [TerminalEffectRecord] = [], unreadable: [URL] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles], errorHandler: { url, _ in unreadable.append(url); return true })
        guard let enumerator = enumerator else {
            return TerminalCachedVisualRecords(bindings: [], effects: [], unreadable: [root])
        }
        for case let url as URL in enumerator {
            guard lstat(url.path, &info) == 0 else { unreadable.append(url); continue }
            if info.st_mode & S_IFMT == S_IFLNK {
                enumerator.skipDescendants(); unreadable.append(url); continue
            }
            guard ["target.json", "effect.json", "bound-intent.json"].contains(url.lastPathComponent) else { continue }
            do {
                if url.lastPathComponent == "target.json" {
                    guard let saved: CachedTarget = try read(url), saved.schema == 1 else {
                        throw TerminalVisualStateError.invalidRecord
                    }
                    try validate(saved.target)
                    guard targetURL(saved.target, filename: "target.json").resolvingSymlinksInPath()
                        == url.resolvingSymlinksInPath() else {
                        throw TerminalVisualStateError.invalidRecord
                    }
                    bindings.append(saved.target)
                } else if url.lastPathComponent == "effect.json" {
                    guard let effect: TerminalEffectRecord = try read(url) else {
                        throw TerminalVisualStateError.invalidRecord
                    }
                    try validate(effect)
                    guard targetURL(effect.target, filename: "effect.json").resolvingSymlinksInPath()
                        == url.resolvingSymlinksInPath() else {
                        throw TerminalVisualStateError.invalidRecord
                    }
                    effects.append(effect)
                } else {
                    guard let saved: CachedTarget = try read(url.deletingLastPathComponent().appendingPathComponent("target.json")),
                          saved.schema == 1 else { throw TerminalVisualStateError.invalidRecord }
                    try validate(saved.target)
                    guard targetURL(saved.target, filename: "bound-intent.json").resolvingSymlinksInPath()
                        == url.resolvingSymlinksInPath(), try boundIntent(for: saved.target) != nil else {
                        throw TerminalVisualStateError.invalidRecord
                    }
                }
            } catch { unreadable.append(url) }
        }
        return TerminalCachedVisualRecords(bindings: bindings, effects: effects, unreadable: unreadable)
    }

    fileprivate struct CachedTarget: Codable {
        var schema = 1
        let target: TerminalTargetBinding
    }

    private func continuingOwner(_ seed: ProcessGeneration, device: UInt32) -> ProcessGeneration? {
        guard var owner = lookup(seed.pid), owner.generation == seed, owner.device == device else { return nil }
        var visited: Set<Int32> = [seed.pid]
        for _ in 0..<16 {
            if owner.parentPID <= 1 { break }
            guard owner.parentPID <= UInt32(Int32.max), !visited.contains(Int32(owner.parentPID)),
                  let parent = lookup(Int32(owner.parentPID)) else { return nil }
            if parent.device != device { break }
            visited.insert(parent.generation.pid)
            owner = parent
        }
        guard lookup(owner.generation.pid)?.generation == owner.generation else { return nil }
        return owner.generation
    }

    private func validate(_ target: TerminalTargetBinding) throws {
        guard Self.concreteTTY(target.tty), target.tty.utf8.count <= 128, target.device != UInt32.max,
              validGeneration(target.ttyOwner) else { throw TerminalVisualStateError.invalidRecord }
        if let native = target.nativeSurface {
            guard validGeneration(native.application), !native.terminalID.isEmpty, native.terminalID.utf8.count <= 128,
                  native.terminalID.rangeOfCharacter(from: .controlCharacters) == nil else {
                throw TerminalVisualStateError.invalidRecord
            }
        }
    }

    private func validate(_ effect: TerminalEffectRecord) throws {
        try validate(effect.target)
        guard effect.schema == 1, validGeneration(effect.controller), Self.validID(effect.effectID),
              Self.normalizedBackground(effect.background) != nil, effect.heartbeatAt.isFinite,
              effect.heartbeatAt > 0, effect.heartbeatAt <= clock.now().timeIntervalSince1970 else {
            throw TerminalVisualStateError.invalidRecord
        }
    }

    private func validGeneration(_ generation: ProcessGeneration) -> Bool {
        generation.pid > 0 && generation.startSeconds > 0 && generation.startMicroseconds < 1_000_000
    }

    private func targetURL(_ target: TerminalTargetBinding, filename: String) -> URL {
        let owner = target.ttyOwner
        var result = directory.appendingPathComponent("targets").appendingPathComponent(key(target.tty))
            .appendingPathComponent("\(owner.pid)-\(owner.startSeconds)-\(owner.startMicroseconds)")
        if let native = target.nativeSurface {
            let app = native.application
            result = result.appendingPathComponent("\(app.pid)-\(app.startSeconds)-\(app.startMicroseconds)")
                .appendingPathComponent(key(native.terminalID))
        } else { result = result.appendingPathComponent("plain") }
        return result.appendingPathComponent(filename)
    }

    private func adoptionURL(tty: String, producer: ProcessGeneration) -> URL {
        directory.appendingPathComponent("adoption-\(key(tty))-\(producer.pid)-\(producer.startSeconds)-\(producer.startMicroseconds).json")
    }

    private func prepareTargetDirectory(_ url: URL, deadline: UInt64) throws {
        try checkDeadline(deadline)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch { throw TerminalVisualStateError.storageUnavailable }
        try checkDeadline(deadline)
        var current = directory, info = stat()
        guard lstat(current.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
            throw TerminalVisualStateError.storageUnavailable
        }
        for component in url.pathComponents.dropFirst(directory.pathComponents.count) {
            current.appendPathComponent(component)
            try checkDeadline(deadline)
            if lstat(current.path, &info) != 0 {
                guard errno == ENOENT else { throw TerminalVisualStateError.storageUnavailable }
                do {
                    try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false,
                                                            attributes: [.posixPermissions: 0o700])
                } catch { throw TerminalVisualStateError.storageUnavailable }
            }
            guard lstat(current.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
                throw TerminalVisualStateError.storageUnavailable
            }
        }
        try checkDeadline(deadline)
    }

    private static func knownDeviceMissing(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) != 0 && (errno == ENOENT || errno == ENXIO)
    }

    private static func knownProcessMissing(_ pid: Int32) -> Bool {
        pid > 0 && kill(pid, 0) != 0 && errno == ESRCH
    }

    private static func characterDevice(_ descriptor: Int32) -> UInt32? {
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFCHR else { return nil }
        return UInt32(bitPattern: info.st_rdev)
    }

    private func checkDeadline(_ deadline: UInt64?) throws {
        if let deadline = deadline, DispatchTime.now().uptimeNanoseconds >= deadline {
            throw TerminalVisualStateError.deadlineExceeded
        }
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
        try withLock(record.tty) {
            // Preserve legacy non-device publication timing; managed callers pass their original deadline.
            try publishIntentUnlocked(record, synthetic: synthetic, intakeAt: intakeAt, deadline: .max)
        }
    }

    func publishIntent(_ record: OrdinaryBackgroundIntent, to target: TerminalTargetBinding,
                       synthetic: Bool, intakeAt: Double, deadline: UInt64) throws {
        try checkDeadline(deadline)
        try validate(record)
        guard record.tty == target.tty, record.device == target.device,
              intakeAt.isFinite, intakeAt > 0, intakeAt <= record.updatedAt else {
            throw TerminalVisualStateError.invalidRecord
        }
        try withLock(record.tty, deadline: deadline) {
            _ = try equivalentBindingsUnlocked(for: target, deadline: deadline)
            let producerValid = validProducer(tty: record.tty, device: record.device, producer: record.producer)
                && record.producer.map { continuingOwner($0, device: target.device) == target.ttyOwner } == true
            try checkDeadline(deadline)
            guard producerValid else { throw TerminalVisualStateError.targetUnavailable }
            try publishIntentUnlocked(record, synthetic: synthetic, intakeAt: intakeAt, deadline: deadline)
            try bindOrdinaryIntentUnlocked(record, to: target, deadline: deadline)
        }
    }

    // Checks frozen render context under the caller's writer lock without
    // publishing an ordinary background or changing current effect ownership.
    func validateSyntheticUnlocked(_ record: OrdinaryBackgroundIntent, intakeAt: Double,
                                   deadline: UInt64) throws {
        try checkDeadline(deadline)
        try validate(record)
        guard intakeAt.isFinite, intakeAt > 0, intakeAt <= record.updatedAt else {
            throw TerminalVisualStateError.invalidRecord
        }
        let observation: TerminalObservation
        do {
            guard let latest: TerminalObservation = try read(recordURL("observation", tty: record.tty),
                                                            deadline: deadline) else {
                throw TerminalVisualStateError.staleDelivery
            }
            try validate(latest)
            observation = latest
        } catch TerminalVisualStateError.invalidRecord {
            throw TerminalVisualStateError.staleDelivery
        }
        try checkDeadline(deadline)
        guard observation.observedAt <= intakeAt, observation.tty == record.tty,
              observation.deliveryID == record.deliveryID, observation.producer == record.producer,
              observation.device == record.device else {
            throw TerminalVisualStateError.staleDelivery
        }
        let live = validProducer(tty: record.tty, device: record.device, producer: record.producer)
        try checkDeadline(deadline)
        guard live else { throw TerminalVisualStateError.staleDelivery }
    }

    func publishIntentUnlocked(_ record: OrdinaryBackgroundIntent, synthetic: Bool = false,
                               intakeAt: Double? = nil, deadline: UInt64) throws {
        try checkDeadline(deadline)
        try validate(record)
        if let intakeAt = intakeAt {
            guard intakeAt.isFinite, intakeAt > 0, intakeAt <= record.updatedAt else {
                throw TerminalVisualStateError.invalidRecord
            }
        }
        var normalized = record
        normalized.background = Self.normalizedBackground(record.background)!
        var observation: TerminalObservation?
        do {
            observation = try read(recordURL("observation", tty: record.tty), deadline: deadline)
            if let observation = observation { try validate(observation) }
        } catch TerminalVisualStateError.deadlineExceeded { throw TerminalVisualStateError.deadlineExceeded }
        catch {
            if synthetic { throw error }
            observation = nil
        }
        try checkDeadline(deadline)
        if let intakeAt = intakeAt, let observation = observation, observation.observedAt > intakeAt {
            throw TerminalVisualStateError.staleDelivery
        }
        let matchesObservation = observation.map {
            $0.tty == record.tty && $0.deliveryID == record.deliveryID
                && $0.producer == record.producer && $0.device == record.device
        } ?? false
        if synthetic {
            guard matchesObservation, validProducer(tty: record.tty,
                device: record.device, producer: record.producer) else { throw TerminalVisualStateError.staleDelivery }
        }
        let url = recordURL("intent", tty: record.tty)
        if let current: OrdinaryBackgroundIntent = try readLatest(url, validating: validate,
            recoverInvalid: !synthetic, deadline: deadline) {
            // A new intake wins over a later render time from the superseded delivery.
            let supersedesDelivery = matchesObservation && (current.deliveryID != record.deliveryID
                || current.producer != record.producer || current.device != record.device)
            guard supersedesDelivery || record.updatedAt >= current.updatedAt else {
                throw TerminalVisualStateError.staleIntent
            }
        }
        try write(normalized, to: url, deadline: deadline)
    }

    func validateRenderContextUnlocked(_ record: OrdinaryBackgroundIntent, synthetic: Bool,
                                       intakeAt: Double, deadline: UInt64) throws {
        if synthetic {
            try validateSyntheticUnlocked(record, intakeAt: intakeAt, deadline: deadline)
            return
        }
        try checkDeadline(deadline)
        try validate(record)
        guard intakeAt.isFinite, intakeAt > 0, intakeAt <= record.updatedAt else {
            throw TerminalVisualStateError.invalidRecord
        }
        if let observation: TerminalObservation = try read(recordURL("observation", tty: record.tty), deadline: deadline) {
            try validate(observation)
            guard observation.observedAt <= intakeAt else { throw TerminalVisualStateError.staleDelivery }
        }
        let live = validProducer(tty: record.tty, device: record.device, producer: record.producer)
        try checkDeadline(deadline)
        guard live else { throw TerminalVisualStateError.staleDelivery }
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
                            if let target = captureTarget(for: surface), let producer = record.producer,
                               continuingOwner(producer, device: target.device) == target.ttyOwner,
                               try boundIntent(for: target) != record {
                                // Consumer adoption is metadata publication, not a device write.
                                try bindOrdinaryIntentUnlocked(record, to: target, deadline: .max)
                            }
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
        let url = adoptionURL(tty: tty, producer: producer)
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

    private func withLock<T>(_ tty: String, deadline suppliedDeadline: UInt64? = nil,
                             body: () throws -> T) throws -> T {
        try checkDeadline(suppliedDeadline)
        guard directory.isFileURL else { throw TerminalVisualStateError.storageUnavailable }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch { throw TerminalVisualStateError.storageUnavailable }
        try checkDeadline(suppliedDeadline)
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
            throw TerminalVisualStateError.storageUnavailable
        }
        try checkDeadline(suppliedDeadline)
        let url = try lockURL(forTTY: tty)
        var fd: Int32
        repeat {
            try checkDeadline(suppliedDeadline)
            fd = open(url.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        } while fd < 0 && errno == EINTR
            && suppliedDeadline.map { DispatchTime.now().uptimeNanoseconds < $0 } == true
        guard fd >= 0 else { throw TerminalVisualStateError.storageUnavailable }
        defer { close(fd) }
        try checkDeadline(suppliedDeadline)
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_mode & 0o777 == 0o600 else {
            throw TerminalVisualStateError.storageUnavailable
        }
        try checkDeadline(suppliedDeadline)
        let deadline = suppliedDeadline ?? DispatchTime.now().uptimeNanoseconds + 100_000_000
        while true {
            try checkDeadline(suppliedDeadline)
            if flock(fd, LOCK_EX | LOCK_NB) == 0 { break }
            let lockError = errno
            guard lockError == EWOULDBLOCK || lockError == EAGAIN || lockError == EINTR else {
                throw TerminalVisualStateError.storageUnavailable
            }
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else {
                try checkDeadline(suppliedDeadline)
                throw TerminalVisualStateError.lockUnavailable
            }
            usleep(useconds_t(min(1_000, max(1, (deadline - now) / 1_000))))
        }
        defer { flock(fd, LOCK_UN) }
        try checkDeadline(suppliedDeadline)
        let result: T
        do { result = try body() }
        catch { try checkDeadline(suppliedDeadline); throw error }
        try checkDeadline(suppliedDeadline)
        return result
    }

    private func read<T: Decodable>(_ url: URL, deadline: UInt64? = nil) throws -> T? {
        try checkDeadline(deadline)
        var before = stat()
        if lstat(url.path, &before) != 0 {
            if errno == ENOENT { try checkDeadline(deadline); return nil }
            throw TerminalVisualStateError.storageUnavailable
        }
        guard before.st_mode & S_IFMT == S_IFREG, before.st_size >= 0,
              before.st_size <= Self.sizeLimit else { throw TerminalVisualStateError.invalidRecord }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw TerminalVisualStateError.storageUnavailable }
        defer { close(fd) }
        try checkDeadline(deadline)
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
        try checkDeadline(deadline)
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            try checkDeadline(deadline)
            return result
        }
        catch TerminalVisualStateError.deadlineExceeded { throw TerminalVisualStateError.deadlineExceeded }
        catch { throw TerminalVisualStateError.invalidRecord }
    }

    private func readLatest<T: Decodable>(_ url: URL, validating validate: (T) throws -> Void,
                                         recoverInvalid: Bool, deadline: UInt64? = nil) throws -> T? {
        do {
            let record: T? = try read(url, deadline: deadline)
            if let record = record { try validate(record) }
            try checkDeadline(deadline)
            return record
        } catch TerminalVisualStateError.invalidRecord {
            try checkDeadline(deadline)
            var info = stat()
            guard recoverInvalid, lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
                throw TerminalVisualStateError.invalidRecord
            }
            try checkDeadline(deadline)
            return nil
        }
    }

    private func write<T: Encodable>(_ record: T, to url: URL, deadline: UInt64? = nil) throws {
        do {
            try checkDeadline(deadline)
            let data = try JSONEncoder().encode(record)
            guard data.count <= Self.sizeLimit else { throw TerminalVisualStateError.invalidRecord }
            try checkDeadline(deadline)
            let temporary = url.deletingLastPathComponent().appendingPathComponent(".record-\(UUID().uuidString).tmp")
            let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard fd >= 0 else { throw TerminalVisualStateError.storageUnavailable }
            defer { close(fd); unlink(temporary.path) }
            try checkDeadline(deadline)
            try data.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    try checkDeadline(deadline)
                    let written = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                    if written < 0, errno == EINTR { continue }
                    guard written > 0 else { throw TerminalVisualStateError.storageUnavailable }
                    offset += written
                }
            }
            try checkDeadline(deadline)
            guard rename(temporary.path, url.path) == 0 else { throw TerminalVisualStateError.storageUnavailable }
            try checkDeadline(deadline)
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

private func decodeVisualSurface(_ decoder: Decoder) throws -> GhosttySurfaceID {
    try requireVisualKeys(decoder, ["application", "terminalID"])
    let container = try decoder.container(keyedBy: VisualRecordKey.self)
    guard try decodeVisualProducer(container, VisualRecordKey(stringValue: "application")!) != nil else {
        throw TerminalVisualStateError.invalidRecord
    }
    return try GhosttySurfaceID(from: decoder)
}

extension TerminalTargetBinding {
    init(from decoder: Decoder) throws {
        try requireVisualKeys(decoder, ["tty", "device", "ttyOwner", "nativeSurface"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tty = try c.decode(String.self, forKey: .tty)
        device = try c.decode(UInt32.self, forKey: .device)
        guard let owner = try decodeVisualProducer(c, .ttyOwner) else { throw TerminalVisualStateError.invalidRecord }
        ttyOwner = owner
        if c.contains(.nativeSurface), try !c.decodeNil(forKey: .nativeSurface) {
            nativeSurface = try decodeVisualSurface(c.superDecoder(forKey: .nativeSurface))
        } else { nativeSurface = nil }
    }
}

extension TerminalEffectRecord {
    init(from decoder: Decoder) throws {
        try requireVisualKeys(decoder, ["schema", "target", "controller", "effectID", "kind", "background", "heartbeatAt", "active"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(Int.self, forKey: .schema)
        target = try c.decode(TerminalTargetBinding.self, forKey: .target)
        guard let generation = try decodeVisualProducer(c, .controller),
              let decodedKind = TerminalEffectKind(rawValue: try c.decode(String.self, forKey: .kind)) else {
            throw TerminalVisualStateError.invalidRecord
        }
        controller = generation
        kind = decodedKind
        effectID = try c.decode(String.self, forKey: .effectID)
        background = try c.decode(String.self, forKey: .background)
        heartbeatAt = try c.decode(Double.self, forKey: .heartbeatAt)
        active = try c.decode(Bool.self, forKey: .active)
    }
}

extension TerminalVisualStateStore.CachedTarget {
    init(from decoder: Decoder) throws {
        try requireVisualKeys(decoder, ["schema", "target"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(Int.self, forKey: .schema)
        target = try c.decode(TerminalTargetBinding.self, forKey: .target)
    }
}
