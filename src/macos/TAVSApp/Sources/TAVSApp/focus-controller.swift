import Foundation
import Combine

enum FocusMode: String { case off = "Off", manual = "Manual", automatic = "Automatic" }

final class FocusController: ObservableObject {
    @Published private(set) var isPreviewActive = false
    @Published private(set) var previewed = Set<GhosttySurfaceID>()
    @Published private(set) var previewStatus = "No preview."
    @Published private(set) var cleanupError: String?
    @Published private(set) var mode: FocusMode = .off
    @Published private(set) var workingSet = Set<GhosttySurfaceID>()
    @Published private(set) var focusStatus = "Focus: Off"
    @Published private(set) var focusCleanupError: String?
    @Published private(set) var attentionCues: [GhosttySurfaceID: Set<AttentionOccurrence>] = [:]
    private let state: TerminalVisualStateStore
    private let recovery: VisualRecovery
    private let restrictions: VisualRestrictionsStateStore
    private let timers: TimerScheduler
    private let clock: Clock
    private let colors: (ProcessGeneration) throws -> TerminalRenderer.Colors
    private let nativeSnapshot: () throws -> [GhosttySurface]
    private let queue: DispatchQueue
    private let clearQueue: DispatchQueue
    private let focusClearQueue = DispatchQueue(label: "tavs.focus-clear")
    private let lock = NSLock()
    private var current: Run?
    private var pendingClear: [Run] = []
    private var previewClears: [TerminalTargetBinding: DispatchGroup] = [:]
    private var manual: Run?
    private var focusLeases: [TerminalTargetBinding: FocusLease] = [:]
    private var manualPending: ([GhosttySurface], Set<GhosttySurfaceID>, Double)?
    private var manualLatest: ([GhosttySurface], Set<GhosttySurfaceID>, Double)?
    private var manualWanted = Set<TerminalTargetBinding>()
    private var manualBlocked = Set<TerminalTargetBinding>()
    private var manualUpdating = false
    private var attention: AttentionState?
    private var automaticRevision: VisualRestrictionsRevision?
    private var automaticHigh = Set<GhosttySurfaceID>()
    private var automaticCatalogue: ([GhosttySurface], Set<GhosttySurfaceID>, Double)?

    init(state: TerminalVisualStateStore, recovery: VisualRecovery,
         restrictions: VisualRestrictionsStateStore, timers: TimerScheduler = SystemTimerScheduler(),
         clock: Clock = SystemClock(), queue: DispatchQueue = DispatchQueue(label: "tavs.preview-start"),
         clearQueue: DispatchQueue = DispatchQueue(label: "tavs.preview-clear", attributes: .concurrent),
         nativeSnapshot: @escaping () throws -> [GhosttySurface],
         colors: @escaping (ProcessGeneration) throws -> TerminalRenderer.Colors) {
        self.state = state; self.recovery = recovery; self.restrictions = restrictions
        self.timers = timers; self.clock = clock; self.queue = queue
        self.clearQueue = clearQueue; self.colors = colors; self.nativeSnapshot = nativeSnapshot
    }

    func preview(_ rows: [GhosttySurface]) {
        clearPreview()
        guard !rows.isEmpty else { return }
        let run: Run
        do { run = Run(revision: try restrictions.captureRevision()) }
        catch { previewStatus = "Preview unavailable: suspension state cannot be verified."; return }
        lock.lock(); current = run; lock.unlock()
        isPreviewActive = true; previewStatus = "Preparing preview."
        queue.async { [weak self] in
            guard let self = self, self.isCurrent(run) else { return }
            do {
                let applications = Set(rows.map { $0.id.application })
                guard applications.count == 1, let application = applications.first else {
                    throw VisualRecoveryError.targetUnavailable
                }
                let colors = try self.colors(application)
                guard self.isCurrent(run) else { return }
                let fresh = try self.validatedNativeRows(rows)
                guard self.isCurrent(run) else { return }
                let targets = fresh.compactMap { self.state.captureTarget(for: $0) }
                guard !targets.isEmpty else { throw VisualRecoveryError.targetUnavailable }
                let startedAt = self.clock.now().timeIntervalSince1970
                self.lock.lock()
                let accepted = self.current === run
                if accepted { run.targets = targets; run.previewStartedAt = startedAt }
                self.lock.unlock()
                guard accepted else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.matchesID(run) else { return }
                    let remaining = max(0, startedAt + 2 - self.clock.now().timeIntervalSince1970)
                    self.timers.scheduleOnce(after: remaining, on: .main) { [weak self] in
                        guard let self = self, self.matchesID(run) else { return }
                        self.clearPreview()
                    }
                }
                guard self.isCurrent(run) else { return }
                let request = TerminalPreviewRequest(effectID: run.id, startedAt: startedAt,
                    colors: colors, revision: run.revision, isCurrent: { [weak self] in self?.isCurrent(run) == true },
                    awaitPriorClear: { [weak self] target, deadline in
                        guard let self = self, self.isCurrent(run) else { throw VisualRecoveryError.policyChanged }
                        self.lock.lock(); let clear = self.previewClears[target.physicalTarget]; self.lock.unlock()
                        if let clear = clear,
                           clear.wait(timeout: DispatchTime(uptimeNanoseconds: deadline)) != .success {
                            throw TerminalVisualStateError.deadlineExceeded
                        }
                        guard self.isCurrent(run) else { throw VisualRecoveryError.policyChanged }
                    })
                let items = self.recovery.apply(.preview(request), to: targets)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.isCurrent(run) else { return }
                    self.previewed = Set(items.filter { $0.status == .restored }.compactMap { $0.target?.nativeSurface })
                    self.previewStatus = "\(self.previewed.count) of \(rows.count) terminals previewed."
                    if let reason = items.first(where: { $0.status == .failed })?.reason {
                        self.previewStatus += " \(reason)"
                    }
                }
            } catch {
                let reason: String
                if case TerminalConfigurationError.unresolvedAppearance = error {
                    reason = "Preview unavailable: Ghostty's CLI cannot resolve the selected dual-theme appearance."
                } else { reason = "Preview unavailable: configured colors or native mapping cannot be resolved." }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.isCurrent(run) else { return }
                    self.isPreviewActive = false
                    self.previewStatus = reason
                }
            }
        }
    }

    private func validatedNativeRows(_ requested: [GhosttySurface]) throws -> [GhosttySurface] {
        let fresh = try nativeSnapshot()
        let byID = Dictionary(grouping: fresh, by: \.id)
        let byTTY = Dictionary(grouping: fresh, by: \.tty)
        return requested.compactMap { row in
            guard row.mappingIssue == nil, let tty = row.tty,
                  let matches = byID[row.id], matches.count == 1,
                  let current = matches.first, current.tty == tty, current.mappingIssue == nil,
                  byTTY[tty]?.count == 1 else { return nil }
            return current
        }
    }

    func clearPreview() {
        lock.lock(); let old = current; current = nil; lock.unlock()
        timers.cancelAll()
        isPreviewActive = false; previewed.removeAll(); previewStatus = "No preview."
        var runs = pendingClear; pendingClear.removeAll()
        if let old = old { runs.append(old) }
        for run in runs {
            lock.lock(); let targets = run.targets; lock.unlock()
            guard !targets.isEmpty else { continue }
            var clears: [TerminalTargetBinding: DispatchGroup] = [:]
            var prior: [TerminalTargetBinding: DispatchGroup] = [:]
            lock.lock()
            for target in Set(targets.map(\.physicalTarget)) {
                prior[target] = previewClears[target]
                let clear = DispatchGroup()
                clear.enter(); previewClears[target] = clear; clears[target] = clear
            }
            lock.unlock()
            let completions = clears, predecessors = prior
            clearQueue.async { [weak self] in
                guard let self = self else { for clear in completions.values { clear.leave() }; return }
                let operation = ManagedVisualOperation.clearPreview(effectID: run.id, revision: run.revision,
                    awaitPriorClear: { target, deadline in
                        if let prior = predecessors[target.physicalTarget],
                           prior.wait(timeout: DispatchTime(uptimeNanoseconds: deadline)) != .success {
                            throw TerminalVisualStateError.deadlineExceeded
                        }
                    })
                let items = self.recovery.apply(operation,
                    to: targets, didComplete: { target in
                        guard let clear = completions[target] else { return }
                        let finish = {
                            self.lock.lock()
                            clear.leave()
                            if self.previewClears[target] === clear {
                                self.previewClears.removeValue(forKey: target)
                            }
                            self.lock.unlock()
                        }
                        if let prior = predecessors[target] { prior.notify(queue: self.clearQueue, execute: finish) }
                        else { finish() }
                    })
                let failed = items.contains { $0.status == .failed }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if failed {
                        if !self.pendingClear.contains(where: { $0 === run }) { self.pendingClear.append(run) }
                        self.cleanupError = "Some previews could not be cleared. Restore Visibility is available."
                    } else if self.pendingClear.isEmpty { self.cleanupError = nil }
                }
            }
        }
    }

    @discardableResult
    func cancelForRecovery() -> (VisualRecoveryReport) -> Void {
        lock.lock(); let old = current; current = nil; manual = nil
        manualWanted.removeAll(); manualBlocked.removeAll()
        let canceled = Array(focusLeases.values)
        for lease in canceled { lease.retiring = true }
        lock.unlock()
        // Retain the pinned revision until pending metadata cancellation succeeds.
        if let old = old, !pendingClear.contains(where: { $0 === old }) { pendingClear.append(old) }
        timers.cancelAll()
        isPreviewActive = false; previewed.removeAll(); previewStatus = "No preview."
        attention = nil; attentionCues.removeAll(); automaticRevision = nil
        automaticHigh.removeAll(); automaticCatalogue = nil
        manualPending = nil; manualLatest = nil; workingSet.removeAll(); mode = .off; focusStatus = "Focus: Off"
        return { [weak self] report in
            guard let self = self, report.stateSaved else { return }
            let outcomes = Dictionary(grouping: report.items.filter { $0.target != nil },
                by: { $0.target!.physicalTarget })
            self.lock.lock()
            for lease in canceled {
                let key = lease.target.physicalTarget
                guard self.focusLeases[key] === lease, let items = outcomes[key],
                      items.allSatisfy({ $0.status == .restored || $0.status == .vanished }) else { continue }
                // Marker replacement and metadata cancellation alone do not prove repaint success.
                lease.ownershipResolved = true; lease.mayHavePainted = false
                self.focusLeases.removeValue(forKey: key)
            }
            let pending = self.focusLeases.values.contains { $0.retiring }
            self.lock.unlock()
            self.focusCleanupError = pending
                ? "Some focus effects could not be cleared. Restore Visibility is available." : nil
        }
    }

    func focusSelected(_ selected: [GhosttySurface], catalogue: [GhosttySurface]) {
        guard restrictions.read() == .active else { return }
        let ids = Set(selected.map(\.id)).intersection(catalogue.map(\.id))
        guard !ids.isEmpty else { return }
        focusOff()
        do {
            let run = Run(revision: try restrictions.captureRevision())
            lock.lock(); manual = run; lock.unlock()
            workingSet = ids; mode = .manual
            acceptCatalogue(catalogue)
        } catch { focusStatus = "Manual unavailable: suspension state cannot be verified." }
    }

    func enableAutomatic(rows: [GhosttySurface], high: Set<GhosttySurfaceID>,
                         coverage: [GhosttySurfaceID: TerminalVisualCoverage]) {
        guard mode != .automatic, !rows.isEmpty, restrictions.read() == .active else { return }
        focusOff()
        do {
            automaticRevision = try restrictions.captureRevision()
            automaticHigh = high.intersection(rows.map(\.id))
            attention = AttentionState(coverage: currentCoverage(rows, coverage), high: automaticHigh,
                enabledAt: clock.now().timeIntervalSince1970)
            mode = .automatic; focusStatus = "Automatic armed: no unacknowledged cues."
        } catch { focusStatus = "Automatic unavailable: suspension state cannot be verified." }
    }

    func cueSnapshot(for id: GhosttySurfaceID) -> Set<AttentionOccurrence> { attentionCues[id] ?? [] }

    func acknowledge(_ captured: Set<AttentionOccurrence>, for id: GhosttySurfaceID) {
        guard mode == .automatic else { return }
        attention?.acknowledge(captured, for: id)
        guard attentionCues != attention?.cues else { return }
        attentionCues = attention?.cues ?? [:]
        if attentionCues.isEmpty {
            retireFocus(); focusStatus = "Automatic armed: no unacknowledged cues."
        } else {
            lock.lock(); manual?.version += 1; lock.unlock()
            if manualUpdating { manualPending = automaticCatalogue }
        }
    }

    func acceptCatalogue(_ rows: [GhosttySurface], high: Set<GhosttySurfaceID> = [],
                         coverage: [GhosttySurfaceID: TerminalVisualCoverage] = [:]) {
        guard mode != .off else { return }
        let now = clock.now().timeIntervalSince1970
        let priorCues = attentionCues
        let ids: Set<GhosttySurfaceID>
        if mode == .manual {
            workingSet.formIntersection(rows.map(\.id))
            guard !workingSet.isEmpty else { focusOff(); return }
            ids = workingSet
        } else {
            guard let revision = automaticRevision, restrictions.read() == .active,
                  (try? restrictions.matches(revision, deadline: .max)) == true else { focusOff(); return }
            ids = high.intersection(rows.map(\.id))
            attention?.update(currentCoverage(rows, coverage), high: ids)
            attentionCues = attention?.cues ?? [:]
            if ids != automaticHigh { retireFocus() }
            automaticHigh = ids
            automaticCatalogue = (rows, ids, now)
            if attentionCues.isEmpty {
                retireFocus(); focusStatus = "Automatic armed: no unacknowledged cues."; return
            }
            lock.lock()
            if manual == nil { manual = Run(revision: revision) }
            lock.unlock()
        }
        lock.lock(); let old = manual; lock.unlock()
        guard let old = old else { return }
        if restrictions.read() != .active || (try? restrictions.matches(old.revision, deadline: .max)) != true {
            focusOff(); return
        }
        let sameInputs = manualUpdating && manualLatest.map { previous in
            previous.1 == ids && previous.0.count == rows.count
                && zip(previous.0, rows).allSatisfy {
                    $0.0.id == $0.1.id && $0.0.tty == $0.1.tty
                        && $0.0.foregroundPID == $0.1.foregroundPID && $0.0.mappingIssue == $0.1.mappingIssue
                }
        } == true
        lock.lock()
        if !sameInputs || priorCues != attentionCues { manual?.version += 1 }
        manual?.catalogueAt = now
        lock.unlock()
        manualPending = (rows, ids, now)
        manualLatest = manualPending
        updateManual()
    }

    private func currentCoverage(_ rows: [GhosttySurface],
                                 _ coverage: [GhosttySurfaceID: TerminalVisualCoverage]) -> [GhosttySurfaceID: TerminalVisualCoverage] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0.id, coverage[$0.id] ?? TerminalVisualCoverage(
            observation: nil, intent: nil, attentionEligible: false, status: "Observation coverage unavailable.")) })
    }

    func catalogueUnavailable() {
        guard mode != .off else { return }
        lock.lock(); manual?.version += 1; manualWanted.removeAll(); manualBlocked.removeAll(); lock.unlock()
        manualPending = nil
        manualLatest = nil
        automaticCatalogue = nil
        focusStatus = mode == .automatic ? "Automatic unavailable: native catalogue is stale; cues retained."
            : "Manual unavailable: native catalogue is stale; captured set retained."
    }

    func focusOff() {
        retireFocus()
        attention = nil; attentionCues.removeAll(); automaticRevision = nil
        automaticHigh.removeAll(); automaticCatalogue = nil
        workingSet.removeAll(); mode = .off; focusStatus = "Focus: Off"
    }

    private func retireFocus() {
        lock.lock(); manual = nil; manualWanted.removeAll(); manualBlocked.removeAll()
        for lease in focusLeases.values { lease.retiring = true }
        lock.unlock()
        manualPending = nil; manualLatest = nil
        clearManual()
    }

    private func updateManual() {
        guard !manualUpdating, let (rows, ids, _) = manualPending else { return }
        lock.lock(); let run = manual; let version = run?.version; lock.unlock()
        guard let run = run, let version = version else { return }
        let cues = mode == .automatic ? attentionCues : nil
        manualPending = nil; manualUpdating = true
        focusStatus = mode == .automatic ? "Preparing automatic focus." : "Preparing manual focus."
        queue.async { [weak self] in
            guard let self = self else { return }
            var attempted = Set<TerminalTargetBinding>()
            let result: Result<(Int, Int, [VisualRecoveryItem], Bool), Error> = Result {
                self.lock.lock()
                let currentCatalogue = self.manual === run && run.version == version
                    && self.clock.now().timeIntervalSince1970 <= run.catalogueAt + 6
                self.lock.unlock()
                guard currentCatalogue else {
                    throw VisualRecoveryError.policyChanged
                }
                let sourceDeadline = DispatchTime.now().uptimeNanoseconds + 100_000_000
                let sources = rows.reduce(into: [GhosttySurfaceID: TerminalTargetBinding]()) { targets, row in
                    if cues?[row.id] != nil, let target = self.state.captureTarget(for: row) { targets[row.id] = target }
                }
                if let cues = cues,
                   !self.automaticSourcesCurrent(cues, targets: sources, run: run, version: version,
                       deadline: sourceDeadline) {
                    throw VisualRecoveryError.targetUnavailable
                }
                let outside = rows.filter { !ids.contains($0.id) }
                guard !outside.isEmpty else { return (0, 0, [], false) }
                guard Set(rows.map { $0.id.application }).count == 1, let instance = rows.first?.id.application else {
                    throw VisualRecoveryError.targetUnavailable
                }
                let colors: TerminalRenderer.Colors
                do { colors = try self.colors(instance) }
                catch {
                    self.lock.lock()
                    if self.manual === run && run.version == version {
                        for lease in self.focusLeases.values where lease.owner === run { lease.retiring = true }
                    }
                    self.lock.unlock()
                    // Failed preparation must let existing cleanup retire the old recipe.
                    attempted.removeAll()
                    throw error
                }
                guard self.matchesManual(run, version: version) else { throw VisualRecoveryError.policyChanged }
                let fresh = try self.validatedNativeRows(rows)
                guard self.matchesManual(run, version: version) else { throw VisualRecoveryError.policyChanged }
                let freshSources = fresh.reduce(into: [GhosttySurfaceID: TerminalTargetBinding]()) { targets, row in
                    if cues?[row.id] != nil, let target = self.state.captureTarget(for: row) { targets[row.id] = target }
                }
                if let cues = cues, !self.automaticSourcesCurrent(cues, targets: freshSources, run: run,
                    version: version, deadline: DispatchTime.now().uptimeNanoseconds + 100_000_000) {
                    throw VisualRecoveryError.targetUnavailable
                }
                guard fresh.contains(where: { ids.contains($0.id) && self.state.captureTarget(for: $0) != nil }) else {
                    throw VisualRecoveryError.targetUnavailable
                }
                let targets = fresh.filter { !ids.contains($0.id) }.compactMap { self.state.captureTarget(for: $0) }
                attempted = Set(targets.map(\.physicalTarget))
                self.lock.lock()
                let accepted = self.manual === run && run.version == version
                if accepted {
                    if run.lastFocusColors != colors {
                        for lease in self.focusLeases.values where lease.owner === run { lease.retiring = true }
                        run.lastFocusColors = colors
                    }
                    run.renewedTargets.removeAll()
                    self.manualWanted = attempted
                    self.manualBlocked.removeAll()
                    for (key, lease) in self.focusLeases where lease.owner === run && !attempted.contains(key) {
                        lease.retiring = true
                    }
                }
                self.lock.unlock()
                guard accepted else { throw VisualRecoveryError.policyChanged }
                let preparedAt = self.clock.now().timeIntervalSince1970
                var requests: [TerminalTargetBinding: (FocusLease, Bool)] = [:]
                let items = self.recovery.applyFocus(to: targets) { target in
                    guard let lease = self.focusLease(target, owner: run, version: version, at: preparedAt) else {
                        self.lock.lock()
                        if self.manual === run && run.version == version { self.manualBlocked.insert(target.physicalTarget) }
                        self.lock.unlock()
                        throw VisualRecoveryError.targetUnavailable
                    }
                    self.lock.lock(); requests[target.physicalTarget] = (lease, lease.mayHavePainted); self.lock.unlock()
                    return TerminalFocusRequest(effectID: lease.id, heartbeatAt: preparedAt, colors: colors,
                    revision: lease.revision, isCurrent: { [weak self] deadline in
                        guard let self = self else { return false }
                        guard self.matchesFocusLease(lease, owner: run, version: version),
                              self.clock.now().timeIntervalSince1970 <= preparedAt + 6 else { return false }
                        if let cues = cues,
                           !self.automaticSourcesCurrent(cues, targets: freshSources, run: run,
                               version: version, deadline: deadline) {
                            return false
                        }
                        return self.matchesFocusLease(lease, owner: run, version: version)
                            && self.clock.now().timeIntervalSince1970 <= preparedAt + 6
                    }, didRenew: { [weak self] target in
                        guard let self = self else { return }
                        self.lock.lock(); defer { self.lock.unlock() }
                        // Record actual saves even when a newer catalogue invalidated this update.
                        lease.lastHeartbeat = preparedAt
                        lease.mayHavePainted = true
                        if self.manual === run && run.version == version
                            && self.focusLeases[target.physicalTarget] === lease && !lease.retiring {
                            run.renewedTargets.insert(target)
                        }
                    })
                }
                self.lock.lock()
                for item in items where item.status == .unaffected {
                    if let key = item.target?.physicalTarget, let (lease, priorPaint) = requests[key],
                       self.focusLeases[key] === lease, !lease.retiring {
                        // Retirement may already have issued a restoration whose outcome is unknown.
                        lease.mayHavePainted = priorPaint
                    }
                }
                let renewed = !targets.isEmpty && targets.count == outside.count && Set(targets) == run.renewedTargets
                self.lock.unlock()
                return (targets.count, outside.count, items, renewed)
            }
            let handled = attempted
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.manualUpdating = false
                if self.matchesManual(run, version: version) {
                    switch result {
                    case .success(let (mapped, count, items, renewed)):
                        let failures = items.filter { $0.status == .failed }.count
                        if count > 0 && !renewed && failures == 0 {
                            self.focusStatus = self.mode == .automatic
                                ? "Automatic unavailable: background effects were not renewed; cues retained."
                                : "Manual unavailable: background effects were not renewed; captured set retained."
                            break
                        }
                        let label = self.mode == .automatic ? "Automatic: \(ids.count) High emphasized"
                            : "Manual: \(self.workingSet.count) captured"
                        self.focusStatus = "\(label); \(mapped) of \(count) outside mapped; \(failures) failed. Preview/global rules may mask dimming."
                    case .failure:
                        self.focusStatus = self.mode == .automatic
                            ? "Automatic unavailable: cue sources, configured colors or native bindings cannot be verified."
                            : "Manual unavailable: configured colors or working binding cannot be verified."
                    }
                }
                self.clearManual(excluding: handled)
                self.updateManual()
            }
        }
    }

    private func matchesManual(_ run: Run, version: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return manual === run && run.version == version
    }

    private func automaticSourcesCurrent(_ cues: [GhosttySurfaceID: Set<AttentionOccurrence>],
                                         targets: [GhosttySurfaceID: TerminalTargetBinding],
                                         run: Run, version: Int, deadline: UInt64) -> Bool {
        var valid = false
        var vanished: [GhosttySurfaceID: Set<AttentionOccurrence>] = [:]
        do {
            for (id, values) in cues {
                guard let cue = values.first else { continue }
                switch try state.validateAttentionSource(cue, surface: id, target: targets[id], deadline: deadline) {
                case .valid: valid = true
                case .vanished: vanished[id] = values
                case .unavailable: break
                }
            }
        } catch {
            if !vanished.isEmpty { invalidateAutomaticSources(vanished, run: run, version: version) }
            return false
        }
        if !vanished.isEmpty { invalidateAutomaticSources(vanished, run: run, version: version) }
        return valid
    }

    private func invalidateAutomaticSources(_ cues: [GhosttySurfaceID: Set<AttentionOccurrence>],
                                            run: Run, version: Int) {
        lock.lock()
        guard manual === run, run.version == version, run.invalidSourcesVersion != version else { lock.unlock(); return }
        run.invalidSourcesVersion = version
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.mode == .automatic, self.matchesManual(run, version: version) else { return }
            for (id, values) in cues { self.acknowledge(values, for: id) }
        }
    }

    private func matchesFocusLease(_ lease: FocusLease, owner: Run, version: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return manual === owner && owner.version == version && !lease.retiring
            && focusLeases[lease.target.physicalTarget] === lease
            && clock.now().timeIntervalSince1970 <= owner.catalogueAt + 6
    }

    private func focusLease(_ target: TerminalTargetBinding, owner: Run, version: Int,
                            at: Double, waitingUntil: DispatchTime = .now() + .milliseconds(100)) -> FocusLease? {
        let key = target.physicalTarget
        var priorPaint = false
        lock.lock()
        guard manual === owner, owner.version == version else { lock.unlock(); return nil }
        if let old = focusLeases[key] {
            if old.owner === owner && !old.retiring && at - old.lastHeartbeat <= 6 {
                lock.unlock(); return old
            }
            old.retiring = true
            if old.clearing {
                lock.unlock()
                guard old.finished.wait(timeout: waitingUntil) == .success else { return nil }
                return focusLease(target, owner: owner, version: version, at: at, waitingUntil: waitingUntil)
            }
            if !old.ownershipResolved {
                old.clearing = true
                old.finished.enter()
                lock.unlock()
                _ = clearFocusLease(old)
                lock.lock()
            }
            guard manual === owner, owner.version == version,
                  focusLeases[key] == nil || (focusLeases[key] === old && old.ownershipResolved) else {
                lock.unlock(); return nil
            }
            // Transfer any remaining repaint obligation to this explicit current focus request.
            priorPaint = focusLeases[key] === old && old.mayHavePainted
        }
        let lease = FocusLease(target: target, owner: owner, at: at)
        lease.mayHavePainted = priorPaint
        focusLeases[key] = lease
        lock.unlock(); return lease
    }

    @discardableResult
    private func clearFocusLease(_ lease: FocusLease) -> Bool {
        let result = recovery.apply(.clearFocus(effectID: lease.id, revision: lease.revision,
            didCancel: { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock(); lease.ownershipResolved = true; self.lock.unlock()
            }, restoreBackground: { [weak self] in
                guard let self = self else { return false }
                self.lock.lock(); defer { self.lock.unlock() }
                return lease.mayHavePainted
            }), to: [lease.target])
        let restored = result.allSatisfy { $0.status == .restored || $0.status == .vanished }
        lock.lock()
        lease.clearing = false
        // Every focus paint follows didRenew; locked cancellation closes future publication.
        let unpainted = lease.ownershipResolved && !lease.mayHavePainted
        if (restored || unpainted) && focusLeases[lease.target.physicalTarget] === lease {
            focusLeases.removeValue(forKey: lease.target.physicalTarget)
        }
        lock.unlock()
        lease.finished.leave()
        return restored || unpainted
    }

    private func clearManual(excluding handled: Set<TerminalTargetBinding> = []) {
        lock.lock()
        let leases = focusLeases.filter { !handled.contains($0.key) && $0.value.retiring && !$0.value.clearing }
            .map(\.value)
        for lease in leases { lease.clearing = true; lease.finished.enter() }
        lock.unlock()
        guard !leases.isEmpty else { return }
        focusClearQueue.async { [weak self] in
            guard let self = self else {
                for lease in leases { lease.finished.leave() }
                return
            }
            DispatchQueue.concurrentPerform(iterations: leases.count) { index in
                _ = self.clearFocusLease(leases[index])
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                let pending = self.focusLeases.values.contains { $0.retiring }
                let progressed = leases.contains { self.manualWanted.contains($0.target.physicalTarget)
                    && self.manualBlocked.contains($0.target.physicalTarget)
                    && ($0.ownershipResolved || self.focusLeases[$0.target.physicalTarget] !== $0) }
                self.lock.unlock()
                self.focusCleanupError = pending ? "Some focus effects could not be cleared. Restore Visibility is available." : nil
                if progressed, let latest = self.manualLatest, self.manualPending == nil {
                    self.manualPending = latest
                    self.updateManual()
                }
            }
        }
    }

    private func matchesID(_ run: Run) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return current === run
    }

    private func isCurrent(_ run: Run) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard current === run else { return false }
        return run.previewStartedAt.map { clock.now().timeIntervalSince1970 < $0 + 2 } ?? true
    }

    private final class Run {
        let id = UUID().uuidString
        var previewStartedAt: Double?
        let revision: VisualRestrictionsRevision
        var targets: [TerminalTargetBinding] = []
        var lastFocusColors: TerminalRenderer.Colors?
        var version = 0
        var catalogueAt = 0.0
        var invalidSourcesVersion: Int?
        var renewedTargets = Set<TerminalTargetBinding>()
        init(revision: VisualRestrictionsRevision) { self.revision = revision }
    }

    private final class FocusLease {
        let id = UUID().uuidString
        let target: TerminalTargetBinding
        let owner: Run
        let revision: VisualRestrictionsRevision
        var lastHeartbeat: Double
        var retiring = false
        var ownershipResolved = false
        var clearing = false
        var mayHavePainted = false
        let finished = DispatchGroup()
        init(target: TerminalTargetBinding, owner: Run, at: Double) {
            self.target = target; self.owner = owner; self.revision = owner.revision; self.lastHeartbeat = at
        }
    }
}
