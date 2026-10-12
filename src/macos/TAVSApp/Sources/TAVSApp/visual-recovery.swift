import Foundation
import Darwin

enum ManagedVisualOperation {
    case register
    case ordinary(OrdinaryBackgroundIntent, synthetic: Bool, intakeAt: Double)
    case forcedReset(OrdinaryBackgroundIntent, intakeAt: Double, title: String)
    case checkSynthetic(OrdinaryBackgroundIntent, intakeAt: Double)
    case currentRestriction
    case reconcile(resetLegacy: Bool, clearSelective: Bool)
    case emergencyReset
}

enum VisualRecoveryStatus: String, Codable { case restored, vanished, unaffected, failed }

struct VisualRecoveryItem: Codable {
    var target: TerminalTargetBinding?
    var tty: String?
    var status: VisualRecoveryStatus
    var reason: String?
}

struct VisualRecoveryReport: Codable {
    var stateSaved: Bool
    var catalogueAvailable: Bool
    var items: [VisualRecoveryItem]
    var hasFailures: Bool { !stateSaved || items.contains { $0.status == .failed } }
}

enum VisualRecoveryError: Error { case vanished, targetUnavailable, scopeUnavailable, policyChanged }

final class VisualRecovery {
    private let runtimeDirectory: URL
    private let restrictions: VisualRestrictionsStateStore
    private let state: TerminalVisualStateStore
    private let policy: VisualRestrictionPolicy
    private let processRunner: ProcessRunner
    private let clock: Clock
    private let controller: ProcessGeneration?
    private let allowedSurfaces: Set<GhosttySurfaceID>?
    private let nativeSnapshot: () throws -> [GhosttySurface]
    private static let reset = Data("\u{1B}]104\u{07}\u{1B}]110\u{07}\u{1B}]111\u{07}".utf8)

    init(runtimeDirectory: URL, restrictions: VisualRestrictionsStateStore,
         state: TerminalVisualStateStore, policy: VisualRestrictionPolicy,
         processRunner: ProcessRunner, clock: Clock, controller: ProcessGeneration?,
         allowedSurfaces: Set<GhosttySurfaceID>? = nil,
         nativeSnapshot: @escaping () throws -> [GhosttySurface]) {
        self.runtimeDirectory = runtimeDirectory
        self.restrictions = restrictions
        self.state = state
        self.policy = policy
        self.processRunner = processRunner
        self.clock = clock
        self.controller = controller
        self.allowedSurfaces = allowedSurfaces
        self.nativeSnapshot = nativeSnapshot
    }

    @discardableResult
    func write(_ operation: ManagedVisualOperation, to target: TerminalTargetBinding) throws -> Bool {
        if let allowed = allowedSurfaces {
            guard let id = target.nativeSurface, allowed.contains(id) else {
                throw VisualRecoveryError.scopeUnavailable
            }
        }
        try requireValid(target)
        return try processRunner.writeManagedToDevice(path: target.tty,
            lockURL: state.lockURL(forTTY: target.tty)) { fd, deadline in
            try self.requireValid(target, descriptor: fd)
            if case .checkSynthetic(let intent, let intakeAt) = operation {
                guard intent.tty == target.tty, intent.device == target.device else {
                    throw TerminalVisualStateError.invalidRecord
                }
                try self.state.validateSyntheticUnlocked(intent, intakeAt: intakeAt, deadline: deadline)
                return nil
            }
            try self.state.cacheTargetUnlocked(target, deadline: deadline)
            if case .register = operation { return nil }
            if case .emergencyReset = operation {
                guard self.restrictions.read().disablesRestrictions else { throw VisualRecoveryError.policyChanged }
                try self.cancelCurrentEffect(target, deadline: deadline)
                try self.invalidatePending(target, deadline: deadline)
                return Self.reset
            }

            var publication: (OrdinaryBackgroundIntent, Bool, Double)?
            var resetTitle: String?
            switch operation {
            case .ordinary(let intent, let synthetic, let intakeAt):
                publication = (intent, synthetic, intakeAt)
            case .forcedReset(let intent, let intakeAt, let title):
                guard title.utf8.count <= 512, title.rangeOfCharacter(from: .controlCharacters) == nil,
                      intent.background == "reset" else { throw TerminalVisualStateError.invalidRecord }
                publication = (intent, true, intakeAt)
                resetTitle = title
            default: break
            }
            if let (intent, synthetic, intakeAt) = publication {
                try self.state.publishIntentUnlocked(intent, synthetic: synthetic,
                    intakeAt: intakeAt, deadline: deadline)
                try self.state.bindOrdinaryIntentUnlocked(intent, to: target, deadline: deadline)
            }
            let currentRule = try self.policy.current(deadline: deadline)
            if case .currentRestriction = operation, currentRule == nil { return nil }
            if let rule = currentRule {
                guard let controller = self.controller else { throw VisualRecoveryError.targetUnavailable }
                let visual: PauseVisual
                switch rule {
                case .paused(let value), .locked(let value, untilEpoch: _): visual = value
                }
                try self.state.saveEffectUnlocked(TerminalEffectRecord(target: target,
                    controller: controller, effectID: UUID().uuidString, kind: .globalRestriction,
                    background: visual.backgroundColor, heartbeatAt: self.clock.now().timeIntervalSince1970),
                    deadline: deadline)
                return Self.restrictionBytes(rule)
            }

            let effect = try self.state.currentEffectUnlocked(target, deadline: deadline)
            var resetLegacy = effect?.kind == .globalRestriction && effect?.active == true
            var clearSelective = false
            if case .reconcile(let reset, let clear) = operation {
                resetLegacy = resetLegacy || reset || effect?.kind == .globalRestriction
                clearSelective = clear
                try self.invalidatePending(target, deadline: deadline)
            }
            let selective = !clearSelective && !self.restrictions.read().disablesRestrictions
                && effect.map { self.state.isSelectiveLeaseActive($0) } == true
            let background = selective ? effect!.background
                : try self.state.ordinaryBackgroundUnlocked(for: target, deadline: deadline) ?? "reset"
            if !selective { try self.cancelCurrentEffect(target, deadline: deadline) }
            var bytes = resetLegacy ? Data("\u{1B}]104\u{07}\u{1B}]110\u{07}".utf8) : Data()
            if resetTitle != nil && !resetLegacy { bytes.append(Data("\u{1B}]104\u{07}".utf8)) }
            bytes.append(Self.backgroundBytes(background))
            if let title = resetTitle { bytes.append(Data("\u{1B}]0;\(title)\u{1B}\\".utf8)) }
            return bytes
        }
    }

    func recover(resume: Bool = false) -> VisualRecoveryReport {
        do { try restrictions.write(suspended: !resume) }
        catch {
            return VisualRecoveryReport(stateSaved: false, catalogueAvailable: false,
                items: [VisualRecoveryItem(status: .failed, reason: "Restriction state could not be saved.")])
        }

        let operation: ManagedVisualOperation = resume
            ? .reconcile(resetLegacy: true, clearSelective: true) : .emergencyReset
        let batch = apply(operation)
        return VisualRecoveryReport(stateSaved: true, catalogueAvailable: batch.catalogueAvailable, items: batch.items)
    }

    func apply(_ operation: ManagedVisualOperation) -> (catalogueAvailable: Bool, items: [VisualRecoveryItem]) {
        let native = NativeCompletion()
        DispatchQueue.global(qos: .userInitiated).async {
            native.result = Result { try self.nativeSnapshot() }
            native.finished.signal()
        }
        let cached = state.cachedRecords()
        let initial = Array(Set(cached.bindings + cached.effects.map(\.target)))
        var items = fanout(initial, operation: operation)
        items += cached.unreadable.map { _ in VisualRecoveryItem(status: .failed, reason: "Cached visual record unavailable.") }
        var known = Set(initial), catalogueAvailable = false
        if native.finished.wait(timeout: .now() + 2.2) == .success,
           case .success(let rows) = native.result {
            catalogueAvailable = true
            var additional: [TerminalTargetBinding] = []
            for row in rows {
                if allowedSurfaces?.contains(row.id) == false { continue }
                guard let target = state.captureTarget(for: row) else {
                    items.append(VisualRecoveryItem(tty: row.tty, status: .failed, reason: "Native target binding unavailable."))
                    continue
                }
                if known.insert(target).inserted { additional.append(target) }
            }
            items += fanout(additional, operation: operation)
        }
        let registry = registryHints()
        let knownTTYs = Set(known.map(\.tty))
        for tty in registry.ttys where !knownTTYs.contains(tty) {
            items.append(VisualRecoveryItem(tty: tty, status: .failed, reason: "Registry target is unverified."))
        }
        if registry.unavailable {
            items.append(VisualRecoveryItem(status: .failed, reason: "Active terminal registry unavailable."))
        }
        return (catalogueAvailable, items)
    }

    func target(tty: String, owner: ProcessGeneration) throws -> TerminalTargetBinding {
        guard let plain = state.captureTarget(tty: tty, owner: owner) else { throw VisualRecoveryError.targetUnavailable }
        guard let allowed = allowedSurfaces else { return plain }
        let cached = state.cachedRecords()
        let bindings = Set(cached.bindings + cached.effects.map(\.target)).filter {
            $0.tty == tty && $0.device == plain.device && $0.ttyOwner == plain.ttyOwner
                && $0.nativeSurface.map { allowed.contains($0) } == true && state.validateTarget($0) == .valid
        }
        if bindings.count == 1 { return bindings.first! }
        guard bindings.isEmpty else { throw VisualRecoveryError.scopeUnavailable }
        let fresh = try nativeSnapshot().filter { $0.tty == tty && allowed.contains($0.id) }
            .compactMap { state.captureTarget(for: $0) }
            .filter { $0.device == plain.device && $0.ttyOwner == plain.ttyOwner }
        guard fresh.count == 1 else { throw VisualRecoveryError.scopeUnavailable }
        return fresh[0]
    }

    func reconcilePriorEffects() -> [VisualRecoveryItem] {
        let cached = state.cachedRecords()
        let targets = Array(Set(cached.effects.map(\.target)))
        let items = fanout(targets, operation: .reconcile(resetLegacy: false, clearSelective: true))
        return items + cached.unreadable.map { _ in
            VisualRecoveryItem(status: .failed, reason: "Cached visual record unavailable.")
        }
    }

    func cachedTarget(tty: String) throws -> TerminalTargetBinding {
        let cached = state.cachedRecords()
        let matches = Set(cached.bindings + cached.effects.map(\.target)).filter {
            $0.tty == tty && state.validateTarget($0) == .valid
                && (allowedSurfaces == nil || $0.nativeSurface.map { allowedSurfaces!.contains($0) } == true)
        }
        guard let first = matches.first,
              matches.allSatisfy({ $0.device == first.device && $0.ttyOwner == first.ttyOwner }) else {
            throw VisualRecoveryError.targetUnavailable
        }
        let native = matches.filter { $0.nativeSurface != nil }
        if native.count == 1 { return native.first! }
        guard native.isEmpty, matches.count == 1 else { throw VisualRecoveryError.scopeUnavailable }
        return first
    }

    private func fanout(_ targets: [TerminalTargetBinding], operation: ManagedVisualOperation) -> [VisualRecoveryItem] {
        let lock = NSLock()
        var items: [VisualRecoveryItem] = []
        DispatchQueue.concurrentPerform(iterations: targets.count) { index in
            let target = targets[index]
            let status: VisualRecoveryStatus
            var reason: String?
            do { status = try write(operation, to: target) ? .restored : .unaffected }
            catch VisualRecoveryError.vanished { status = .vanished }
            catch { status = .failed; reason = "Managed restoration unavailable." }
            lock.lock()
            items.append(VisualRecoveryItem(target: target, tty: target.tty, status: status, reason: reason))
            lock.unlock()
        }
        return items
    }

    private func requireValid(_ target: TerminalTargetBinding, descriptor: Int32? = nil) throws {
        switch state.validateTarget(target, descriptor: descriptor) {
        case .valid: return
        case .vanished: throw VisualRecoveryError.vanished
        case .unavailable: throw VisualRecoveryError.targetUnavailable
        }
    }

    private func cancelCurrentEffect(_ target: TerminalTargetBinding, deadline: UInt64) throws {
        if let effect = try state.currentEffectUnlocked(target, deadline: deadline), effect.active {
            _ = try state.cancelEffectUnlocked(target, effectID: effect.effectID,
                controller: effect.controller, deadline: deadline)
        }
    }

    private func invalidatePending(_ target: TerminalTargetBinding, deadline: UInt64) throws {
        guard DispatchTime.now().uptimeNanoseconds < deadline else { throw TerminalVisualStateError.deadlineExceeded }
        let directory = runtimeDirectory.appendingPathComponent("pending")
        var info = stat()
        if lstat(directory.path, &info) != 0 {
            if errno == ENOENT { return }
            throw TerminalVisualStateError.storageUnavailable
        }
        guard info.st_mode & S_IFMT == S_IFDIR else { throw TerminalVisualStateError.storageUnavailable }
        let url = directory.appendingPathComponent(target.tty.replacingOccurrences(of: "/", with: "_") + ".osc")
        if lstat(url.path, &info) != 0 {
            if errno == ENOENT { return }
            throw TerminalVisualStateError.storageUnavailable
        }
        guard info.st_mode & S_IFMT == S_IFREG else { throw TerminalVisualStateError.storageUnavailable }
        guard DispatchTime.now().uptimeNanoseconds < deadline else { throw TerminalVisualStateError.deadlineExceeded }
        guard unlink(url.path) == 0 else { throw TerminalVisualStateError.storageUnavailable }
    }

    private func registryHints() -> (ttys: [String], unavailable: Bool) {
        let directory = runtimeDirectory.appendingPathComponent("active-ttys")
        var info = stat()
        if lstat(directory.path, &info) != 0 { return ([], errno != ENOENT) }
        guard info.st_mode & S_IFMT == S_IFDIR,
              let entries = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return ([], true) }
        var ttys: [String] = [], unavailable = false
        for entry in entries {
            guard entry.range(of: "^_dev_tty[sp][A-Za-z0-9]+\\z", options: .regularExpression) != nil,
                  lstat(directory.appendingPathComponent(entry).path, &info) == 0,
                  info.st_mode & S_IFMT == S_IFREG else { unavailable = true; continue }
            ttys.append(entry.replacingOccurrences(of: "_", with: "/"))
        }
        return (ttys, unavailable)
    }

    private static func backgroundBytes(_ background: String) -> Data {
        Data((background == "reset" ? "\u{1B}]111\u{1B}\\" : "\u{1B}]11;\(background)\u{1B}\\").utf8)
    }

    private static func restrictionBytes(_ rule: GlobalVisualRestriction) -> Data {
        let visual: PauseVisual
        var title = ""
        switch rule {
        case .paused(let value): visual = value
        case .locked(let value, let until):
            visual = value
            let date = Date(timeIntervalSince1970: TimeInterval(until)), calendar = Calendar.current
            let text = String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
            title = "\u{1B}]0;🔒 locked until \(text)\u{07}"
        }
        return Data(("\u{1B}]104\u{07}\u{1B}]10;\(visual.foregroundColor)\u{07}\u{1B}]11;\(visual.backgroundColor)\u{07}"
            + "\u{1B}]1337;SetBackgroundImageFile=\u{07}" + title).utf8)
    }

    private final class NativeCompletion {
        let finished = DispatchSemaphore(value: 0)
        var result: Result<[GhosttySurface], Error>?
    }
}
