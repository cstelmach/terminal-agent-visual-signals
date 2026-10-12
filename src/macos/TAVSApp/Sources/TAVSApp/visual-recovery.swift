import Foundation
import Darwin

enum ManagedVisualOperation {
    case register
    case ordinary(OrdinaryBackgroundIntent, synthetic: Bool, intakeAt: Double)
    case forcedReset(OrdinaryBackgroundIntent, intakeAt: Double, title: String)
    case checkSynthetic(OrdinaryBackgroundIntent, intakeAt: Double)
    case render(TerminalRender, OrdinaryBackgroundIntent, synthetic: Bool, intakeAt: Double)
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
enum TerminalRenderResult: String { case rendered, restricted, unaffected }

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
        try performWrite(operation, to: target, ordinaryRender: nil)
    }

    func render(_ render: TerminalRender, intent: OrdinaryBackgroundIntent, synthetic: Bool,
                intakeAt: Double, to target: TerminalTargetBinding) throws -> TerminalRenderResult {
        var ordinary = false
        let wrote = try performWrite(.render(render, intent, synthetic: synthetic, intakeAt: intakeAt),
            to: target, ordinaryRender: { ordinary = true })
        // The writer completion orders classification before a successful return.
        return wrote ? (ordinary ? .rendered : .restricted) : .unaffected
    }

    private func performWrite(_ operation: ManagedVisualOperation, to target: TerminalTargetBinding,
                              ordinaryRender: (() -> Void)?) throws -> Bool {
        if let allowed = allowedSurfaces {
            guard let id = target.nativeSurface, allowed.contains(id) else {
                throw VisualRecoveryError.scopeUnavailable
            }
        }
        try requireValid(target)

        var publication: (OrdinaryBackgroundIntent, Bool, Double)?
        var resetTitle: String?
        var render: TerminalRender?
        var syntheticRender = false
        switch operation {
        case .ordinary(let intent, let synthetic, let intakeAt):
            publication = (intent, synthetic, intakeAt)
        case .forcedReset(let intent, let intakeAt, let title):
            guard title.utf8.count <= 512, title.rangeOfCharacter(from: .controlCharacters) == nil,
                  intent.background == "reset" else { throw TerminalVisualStateError.invalidRecord }
            publication = (intent, true, intakeAt)
            resetTitle = title
        case .render(let style, var intent, let synthetic, let intakeAt):
            render = style; syntheticRender = synthetic
            if let background = style.background {
                intent.background = background
                publication = (intent, synthetic, intakeAt)
            }
        default: break
        }
        let beforeOpen: ((UInt64) throws -> Void)?
        if let (intent, synthetic, intakeAt) = publication {
            beforeOpen = { deadline in
                try self.state.publishIntent(intent, to: target, synthetic: synthetic,
                    intakeAt: intakeAt, deadline: deadline)
            }
        } else { beforeOpen = nil }
        return try processRunner.writeManagedToDevice(path: target.tty,
            lockURL: state.lockURL(forTTY: target.tty), beforeOpen: beforeOpen) { fd, deadline in
            try self.requireValid(target, descriptor: fd)
            if case .checkSynthetic(let intent, let intakeAt) = operation {
                guard intent.tty == target.tty, intent.device == target.device else {
                    throw TerminalVisualStateError.invalidRecord
                }
                try self.state.validateSyntheticUnlocked(intent, intakeAt: intakeAt, deadline: deadline)
                return nil
            }
            if case .render(_, let intent, let synthetic, let intakeAt) = operation {
                guard intent.tty == target.tty, intent.device == target.device else {
                    throw TerminalVisualStateError.invalidRecord
                }
                try self.state.validateRenderContextUnlocked(intent, synthetic: synthetic,
                    intakeAt: intakeAt, deadline: deadline)
            }
            try self.state.cacheTargetUnlocked(target, deadline: deadline)
            if case .register = operation {
                _ = try self.state.equivalentBindingsUnlocked(for: target, deadline: deadline)
                return nil
            }
            let effects = try self.effectsUnlocked(for: target, deadline: deadline)
            if case .emergencyReset = operation {
                guard self.restrictions.read().disablesRestrictions else { throw VisualRecoveryError.policyChanged }
                try self.cancelEffects(effects, deadline: deadline)
                try self.invalidatePending(target, deadline: deadline)
                return Self.reset
            }

            if let (intent, synthetic, intakeAt) = publication {
                try self.state.publishIntentUnlocked(intent, synthetic: synthetic,
                    intakeAt: intakeAt, deadline: deadline)
                try self.state.bindOrdinaryIntentUnlocked(intent, to: target, deadline: deadline)
            }
            let currentRule = try self.policy.current(deadline: deadline)
            if case .currentRestriction = operation, currentRule == nil { return nil }
            var clearSelective = false
            if case .reconcile(_, let clear) = operation { clearSelective = clear }
            if clearSelective { try self.cancelEffects(effects, deadline: deadline) }
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

            var resetLegacy = effects.contains { $0.kind == .globalRestriction && $0.active }
            if case .reconcile(let reset, let clear) = operation {
                resetLegacy = resetLegacy || reset || effects.contains { $0.kind == .globalRestriction }
                clearSelective = clear
                try self.invalidatePending(target, deadline: deadline)
            }
            let active = effects.filter { self.state.isSelectiveLeaseActive($0) }
            let previews = active.filter { $0.kind == .preview }
            let restrictionsDisabled = self.restrictions.read().disablesRestrictions
            let leases = previews.isEmpty
                ? active.filter { $0.kind == .selectiveBackground && !restrictionsDisabled }
                : previews
            let selective = !clearSelective && !leases.isEmpty
            if selective, let first = leases.first {
                guard leases.allSatisfy({ $0.effectID == first.effectID && $0.controller == first.controller
                    && $0.background == first.background }) else { throw TerminalVisualStateError.staleEffect }
            }
            let needsBackground = render == nil || render?.background != nil || selective
                || resetLegacy || effects.contains(where: { $0.active })
            let background = needsBackground ? (selective ? leases[0].background
                : try self.state.ordinaryBackgroundUnlocked(for: target, deadline: deadline) ?? "reset") : nil
            if !clearSelective {
                try self.cancelEffects(selective ? effects.filter { !self.state.isSelectiveLeaseActive($0) } : effects,
                                       deadline: deadline)
            }
            var bytes = resetLegacy ? Data("\u{1B}]104\u{07}\u{1B}]110\u{07}".utf8) : Data()
            if resetTitle != nil && !resetLegacy { bytes.append(Data("\u{1B}]104\u{07}".utf8)) }
            if let render = render { bytes.append(render.beforeBackground) }
            if let background = background {
                bytes.append(Self.backgroundBytes(background))
            }
            if let title = resetTitle { bytes.append(Data("\u{1B}]0;\(title)\u{1B}\\".utf8)) }
            if let render = render {
                bytes.append(render.afterBackground(synthetic: syntheticRender))
                ordinaryRender?()
            }
            return bytes.isEmpty ? nil : bytes
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
        var known = Set(initial.map(\.physicalTarget)), catalogueAvailable = false
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
                let handled = items.contains { $0.target?.physicalTarget == target.physicalTarget
                    && ($0.status == .restored || $0.status == .unaffected) }
                if handled {
                    do { _ = try write(.register, to: target) }
                    catch {
                        items.removeAll { $0.target?.physicalTarget == target.physicalTarget }
                        items.append(VisualRecoveryItem(target: target, tty: target.tty, status: .failed,
                            reason: "Native alias registration unavailable."))
                    }
                } else { additional.append(target) }
                known.insert(target.physicalTarget)
            }
            for item in fanout(additional, operation: operation) {
                items.removeAll { $0.target?.physicalTarget == item.target?.physicalTarget }
                items.append(item)
            }
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
        let cached = state.cachedRecords()
        let bindings = Set(cached.bindings + cached.effects.map(\.target)).filter {
            $0.tty == tty && state.validateTarget($0) == .valid
        }
        guard bindings.allSatisfy({ $0.physicalTarget == plain }) else { throw VisualRecoveryError.targetUnavailable }
        let natives = bindings.filter { $0.nativeSurface != nil }
        if !natives.isEmpty { return try preferredTarget(Array(natives)) }
        guard let allowed = allowedSurfaces else { return plain }
        let fresh = try nativeSnapshot().filter { $0.tty == tty && allowed.contains($0.id) }
            .compactMap { state.captureTarget(for: $0) }
            .filter { $0.device == plain.device && $0.ttyOwner == plain.ttyOwner }
        guard fresh.count == 1 else { throw VisualRecoveryError.scopeUnavailable }
        return try preferredTarget(fresh)
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
        }
        return try preferredTarget(Array(matches))
    }

    private func preferredTarget(_ matches: [TerminalTargetBinding]) throws -> TerminalTargetBinding {
        guard let first = matches.first, matches.allSatisfy({ $0.physicalTarget == first.physicalTarget }) else {
            throw VisualRecoveryError.targetUnavailable
        }
        let native = Set(matches.filter { $0.nativeSurface != nil })
        guard native.count <= 1 else { throw VisualRecoveryError.scopeUnavailable }
        let target = native.first ?? first
        if let allowed = allowedSurfaces {
            guard let id = target.nativeSurface, allowed.contains(id) else { throw VisualRecoveryError.scopeUnavailable }
        }
        return target
    }

    private func fanout(_ targets: [TerminalTargetBinding], operation: ManagedVisualOperation) -> [VisualRecoveryItem] {
        let groups = Dictionary(grouping: Set(targets), by: \.physicalTarget)
        let physical = Array(groups.keys)
        let live = Dictionary(grouping: targets.filter { state.validateTarget($0) == .valid }, by: \.tty)
        let conflicting = Set(live.filter { Set($0.value.map(\.physicalTarget)).count > 1 }.map(\.key))
        let lock = NSLock()
        var items: [VisualRecoveryItem] = []
        DispatchQueue.concurrentPerform(iterations: physical.count) { index in
            let aliases = groups[physical[index]]!
            var target = aliases[0]
            let status: VisualRecoveryStatus
            var reason: String?
            do {
                let validations = aliases.map { self.state.validateTarget($0) }
                guard !validations.contains(.unavailable) else { throw VisualRecoveryError.targetUnavailable }
                let valid = zip(aliases, validations).filter { $0.1 == .valid }.map(\.0)
                guard !valid.isEmpty else { throw VisualRecoveryError.vanished }
                guard !conflicting.contains(target.tty) else { throw VisualRecoveryError.targetUnavailable }
                target = try self.preferredTarget(valid)
                status = try self.write(operation, to: target) ? .restored : .unaffected
            }
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

    private func effectsUnlocked(for target: TerminalTargetBinding, deadline: UInt64) throws -> [TerminalEffectRecord] {
        let kinds: [TerminalEffectKind?] = [nil, .preview]
        return try state.equivalentBindingsUnlocked(for: target, deadline: deadline).flatMap { binding in
            try kinds.compactMap { try state.currentEffectUnlocked(binding, kind: $0, deadline: deadline) }
        }
    }

    private func cancelEffects(_ effects: [TerminalEffectRecord], deadline: UInt64) throws {
        for effect in effects where effect.active {
            _ = try state.cancelEffectUnlocked(effect.target, effectID: effect.effectID,
                controller: effect.controller, kind: effect.kind, deadline: deadline)
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
