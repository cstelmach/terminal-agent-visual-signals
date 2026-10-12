import Foundation
import Combine

final class FocusController: ObservableObject {
    @Published private(set) var isPreviewActive = false
    @Published private(set) var previewed = Set<GhosttySurfaceID>()
    @Published private(set) var previewStatus = "No preview."
    @Published private(set) var cleanupError: String?
    private let state: TerminalVisualStateStore
    private let recovery: VisualRecovery
    private let restrictions: VisualRestrictionsStateStore
    private let timers: TimerScheduler
    private let clock: Clock
    private let colors: (ProcessGeneration) throws -> TerminalRenderer.Colors
    private let queue: DispatchQueue
    private let clearQueue = DispatchQueue(label: "tavs.preview-clear")
    private let lock = NSLock()
    private var current: Run?
    private var pendingClear: [Run] = []

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
        lock.lock(); let old = current; current = nil; lock.unlock()
        // Retain the pinned revision until pending metadata cancellation succeeds.
        if let old = old, !pendingClear.contains(where: { $0 === old }) { pendingClear.append(old) }
        timers.cancelAll()
        isPreviewActive = false; previewed.removeAll(); previewStatus = "No preview."
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
        init(startedAt: Double, revision: VisualRestrictionsRevision) {
            self.startedAt = startedAt; self.revision = revision
        }
    }
}
