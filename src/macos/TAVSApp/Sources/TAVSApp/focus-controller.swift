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
    private let queue: DispatchQueue
    private let clearQueue = DispatchQueue(label: "tavs.preview-clear")
    private let focusClearQueue = DispatchQueue(label: "tavs.focus-clear")
    private let lock = NSLock()
    private var current: Run?
    private var pendingClear: [Run] = []
    private var manual: Run?
    private var pendingFocusClear: [Run] = []
    private var manualPending: ([GhosttySurface], Set<GhosttySurfaceID>, Double)?
    private var manualUpdating = false
    private var attention: AttentionState?
    private var automaticRevision: VisualRestrictionsRevision?
    private var automaticHigh = Set<GhosttySurfaceID>()
    private var automaticCatalogue: ([GhosttySurface], Set<GhosttySurfaceID>, Double)?

    init(state: TerminalVisualStateStore, recovery: VisualRecovery,
         restrictions: VisualRestrictionsStateStore, timers: TimerScheduler = SystemTimerScheduler(),
         clock: Clock = SystemClock(), queue: DispatchQueue = DispatchQueue(label: "tavs.preview-start"),
         colors: @escaping (ProcessGeneration) throws -> TerminalRenderer.Colors) {
        self.state = state; self.recovery = recovery; self.restrictions = restrictions
        self.timers = timers; self.clock = clock; self.queue = queue; self.colors = colors
    }

    func preview(_ rows: [GhosttySurface]) {
        clearPreview()
        guard !rows.isEmpty else { return }
        let run: Run
        do { run = Run(startedAt: clock.now().timeIntervalSince1970,
                       revision: try restrictions.captureRevision()) }
        catch { previewStatus = "Preview unavailable: suspension state cannot be verified."; return }
        lock.lock(); current = run; lock.unlock()
        isPreviewActive = true; previewStatus = "Preparing preview."
        timers.scheduleOnce(after: 2, on: .main) { [weak self] in
            guard let self = self, self.matchesID(run) else { return }
            self.clearPreview()
        }
        queue.async { [weak self] in
            guard let self = self, self.isCurrent(run) else { return }
            do {
                let applications = Set(rows.map { $0.id.application })
                guard applications.count == 1, let application = applications.first else {
                    throw VisualRecoveryError.targetUnavailable
                }
                let colors = try self.colors(application)
                let targets = rows.compactMap { self.state.captureTarget(for: $0) }
                self.lock.lock()
                let accepted = self.current === run
                if accepted { run.targets = targets }
                self.lock.unlock()
                guard accepted, self.isCurrent(run) else { return }
                let request = TerminalPreviewRequest(effectID: run.id, startedAt: run.startedAt,
                    colors: colors, revision: run.revision, isCurrent: { [weak self] in self?.isCurrent(run) == true })
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
                    self.previewStatus = reason
                }
            }
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
            clearQueue.async { [weak self] in
                guard let self = self else { return }
                let failed = self.recovery.apply(.clearPreview(effectID: run.id, revision: run.revision), to: targets)
                    .contains { $0.status == .failed }
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

    func cancelForRecovery() {
        lock.lock(); let old = current; current = nil; let oldManual = manual; manual = nil; lock.unlock()
        // Retain the pinned revision until pending metadata cancellation succeeds.
        if let old = old, !pendingClear.contains(where: { $0 === old }) { pendingClear.append(old) }
        timers.cancelAll()
        isPreviewActive = false; previewed.removeAll(); previewStatus = "No preview."
        if let oldManual = oldManual { pendingFocusClear.append(oldManual) }
        attention = nil; attentionCues.removeAll(); automaticRevision = nil
        automaticHigh.removeAll(); automaticCatalogue = nil
        manualPending = nil; workingSet.removeAll(); mode = .off; focusStatus = "Focus: Off"
    }

    func focusSelected(_ selected: [GhosttySurface], catalogue: [GhosttySurface]) {
        guard restrictions.read() == .active else { return }
        let ids = Set(selected.map(\.id)).intersection(catalogue.map(\.id))
        guard !ids.isEmpty else { return }
        focusOff()
        do {
            let run = Run(startedAt: clock.now().timeIntervalSince1970, revision: try restrictions.captureRevision())
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
            if manual == nil { manual = Run(startedAt: now, revision: revision) }
            lock.unlock()
        }
        lock.lock(); let old = manual; let lastHeartbeat = old?.lastHeartbeat; lock.unlock()
        guard let old = old else { return }
        if restrictions.read() != .active || (try? restrictions.matches(old.revision, deadline: .max)) != true {
            focusOff(); return
        }
        lock.lock()
        if now - (lastHeartbeat ?? now) > 6 {
            manual = Run(startedAt: now, revision: old.revision)
            pendingFocusClear.append(old)
        }
        manual?.version += 1
        lock.unlock()
        manualPending = (rows, ids, now)
        updateManual()
    }

    private func currentCoverage(_ rows: [GhosttySurface],
                                 _ coverage: [GhosttySurfaceID: TerminalVisualCoverage]) -> [GhosttySurfaceID: TerminalVisualCoverage] {
        Dictionary(uniqueKeysWithValues: rows.map { ($0.id, coverage[$0.id] ?? TerminalVisualCoverage(
            observation: nil, intent: nil, attentionEligible: false, status: "Observation coverage unavailable.")) })
    }

    func catalogueUnavailable() {
        guard mode != .off else { return }
        lock.lock(); manual?.version += 1; lock.unlock()
        manualPending = nil
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
        lock.lock(); let old = manual; manual = nil; lock.unlock()
        manualPending = nil
        var runs = pendingFocusClear; pendingFocusClear.removeAll()
        if let old = old { runs.append(old) }
        clearManual(runs)
    }

    private func updateManual() {
        guard !manualUpdating, let (rows, ids, at) = manualPending else { return }
        lock.lock(); let run = manual; let version = run?.version; lock.unlock()
        guard let run = run, let version = version else { return }
        let cues = mode == .automatic ? attentionCues : nil
        manualPending = nil; manualUpdating = true
        focusStatus = mode == .automatic ? "Preparing automatic focus." : "Preparing manual focus."
        queue.async { [weak self] in
            guard let self = self else { return }
            let result: Result<(Int, Int, [VisualRecoveryItem], Bool), Error> = Result {
                guard self.matchesManual(run, version: version), self.clock.now().timeIntervalSince1970 <= at + 6 else {
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
                guard rows.contains(where: { ids.contains($0.id) && self.state.captureTarget(for: $0) != nil }) else {
                    throw VisualRecoveryError.targetUnavailable
                }
                guard Set(rows.map { $0.id.application }).count == 1, let instance = rows.first?.id.application else {
                    throw VisualRecoveryError.targetUnavailable
                }
                if run.colors == nil { run.colors = try self.colors(instance) }
                let colors = run.colors!
                let targets = outside.compactMap { self.state.captureTarget(for: $0) }
                self.lock.lock()
                let accepted = self.manual === run && run.version == version
                if accepted {
                    run.targets = Array(Set(run.targets + targets))
                    run.renewedTargets.removeAll()
                }
                self.lock.unlock()
                guard accepted else { throw VisualRecoveryError.policyChanged }
                let request = TerminalFocusRequest(effectID: run.id, heartbeatAt: at, colors: colors,
                    revision: run.revision, isCurrent: { [weak self] deadline in
                        guard let self = self else { return false }
                        guard self.matchesManual(run, version: version), self.clock.now().timeIntervalSince1970 <= at + 6 else { return false }
                        if let cues = cues,
                           !self.automaticSourcesCurrent(cues, targets: sources, run: run,
                               version: version, deadline: deadline) {
                            return false
                        }
                        return self.matchesManual(run, version: version)
                            && self.clock.now().timeIntervalSince1970 <= at + 6
                    }, didRenew: { [weak self] target in
                        guard let self = self else { return }
                        self.lock.lock(); defer { self.lock.unlock() }
                        if self.manual === run && run.version == version { run.renewedTargets.insert(target) }
                    })
                let items = self.recovery.apply(.focus(request), to: targets)
                self.lock.lock()
                let renewed = !targets.isEmpty && targets.count == outside.count && Set(targets) == run.renewedTargets
                if self.manual === run && run.version == version && renewed
                    && !items.contains(where: { $0.status == .failed }) {
                    run.lastHeartbeat = at
                }
                self.lock.unlock()
                return (targets.count, outside.count, items, renewed)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.manualUpdating = false
                if self.matchesManual(run, version: version) {
                    let pending = self.pendingFocusClear; self.pendingFocusClear.removeAll()
                    self.clearManual(pending)
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

    private func clearManual(_ runs: [Run]) {
        for run in runs {
            lock.lock(); let targets = run.targets; lock.unlock()
            guard !targets.isEmpty else { continue }
            focusClearQueue.async { [weak self] in
                guard let self = self else { return }
                let failed = self.recovery.apply(.clearFocus(effectID: run.id, revision: run.revision), to: targets)
                    .contains { $0.status == .failed }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if failed {
                        if !self.pendingFocusClear.contains(where: { $0 === run }) { self.pendingFocusClear.append(run) }
                        self.focusCleanupError = "Some focus effects could not be cleared. Restore Visibility is available."
                    } else if self.pendingFocusClear.isEmpty { self.focusCleanupError = nil }
                }
            }
        }
    }

    private func matchesID(_ run: Run) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return current === run
    }

    private func isCurrent(_ run: Run) -> Bool {
        matchesID(run) && clock.now().timeIntervalSince1970 < run.startedAt + 2
    }

    private final class Run {
        let id = UUID().uuidString
        let startedAt: Double
        let revision: VisualRestrictionsRevision
        var targets: [TerminalTargetBinding] = []
        var colors: TerminalRenderer.Colors?
        var version = 0
        var invalidSourcesVersion: Int?
        var lastHeartbeat: Double
        var renewedTargets = Set<TerminalTargetBinding>()
        init(startedAt: Double, revision: VisualRestrictionsRevision) {
            self.startedAt = startedAt; self.revision = revision; self.lastHeartbeat = startedAt
        }
    }
}
