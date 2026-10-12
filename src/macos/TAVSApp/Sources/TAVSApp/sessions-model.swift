import Foundation
import Combine

enum SurfacePriority: String, Codable, CaseIterable, Identifiable {
    case high = "High", normal = "Normal", low = "Low"
    var id: Self { self }
    var rank: Int { Self.allCases.firstIndex(of: self)! }
}

final class SessionsModel: ObservableObject {
    @Published var selection = Set<GhosttySurfaceID>() {
        didSet {
            guard selection != oldValue, isOpen, catalogueAvailable, !recovering else { return }
            focus?.preview(surfaces.filter { selection.contains($0.id) })
        }
    }
    @Published private(set) var surfaces: [GhosttySurface] = []
    @Published private(set) var priorities: [GhosttySurfaceID: SurfacePriority] = [:]
    @Published private(set) var visualCoverage: [GhosttySurfaceID: TerminalVisualCoverage] = [:]
    @Published private(set) var visualRestrictionsStatus: VisualRestrictionsStatus = .active
    @Published private(set) var catalogueAvailable = false
    @Published private(set) var status = "Open Sessions to read the native catalogue."
    @Published private(set) var priorityStorageError: String?
    @Published private(set) var refreshing = false
    @Published private(set) var navigating: GhosttySurfaceID?
    @Published private(set) var refreshedAt: Date?
    @Published private(set) var recovering = false
    @Published private(set) var recoveryStatus: String?
    private let prioritiesURL: URL
    private let readCatalogue: (@escaping (Result<[GhosttySurface], Error>) -> Void) -> Void
    private let navigate: (GhosttySurface, @escaping (Result<Void, Error>) -> Void) -> Void
    private let timerScheduler: TimerScheduler
    private let clock: Clock
    private let visualState: TerminalVisualStateStore?
    private let visualRestrictionsState: VisualRestrictionsStateStore
    private let focus: FocusController?
    private let recoverAction: ((Bool, @escaping (Result<VisualRecoveryReport, Error>) -> Void) -> Void)?
    private var focusObservation: AnyCancellable?
    private var modeObservation: AnyCancellable?
    private let visualQueue = DispatchQueue(label: "tavs.sessions.visual-state")
    private var isOpen = false
    private var polling = false

    var previewStatus: String { focus?.previewStatus ?? "Preview unavailable." }
    var previewActive: Bool { focus?.isPreviewActive ?? false }
    var previewCleanupError: String? { focus?.cleanupError }
    var focusMode: FocusMode { focus?.mode ?? .off }
    var focusStatus: String { focus?.focusStatus ?? "Focus: Off" }
    var focusCleanupError: String? { focus?.focusCleanupError }
    func isInWorkingSet(_ id: GhosttySurfaceID) -> Bool { focus?.workingSet.contains(id) == true }
    var canFocusSelected: Bool {
        focus != nil && !recovering && catalogueAvailable && !selection.isEmpty
            && !visualRestrictionsStatus.disablesRestrictions
    }

    var rows: [GhosttySurface] {
        surfaces.enumerated().sorted {
            let a = priority(for: $0.element.id).rank, b = priority(for: $1.element.id).rank
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
    }

    init(prioritiesURL: URL,
         refresh: @escaping (@escaping (Result<[GhosttySurface], Error>) -> Void) -> Void,
         navigate: @escaping (GhosttySurface, @escaping (Result<Void, Error>) -> Void) -> Void,
         timerScheduler: TimerScheduler = SystemTimerScheduler(), clock: Clock = SystemClock(),
         visualState: TerminalVisualStateStore? = nil,
         visualRestrictionsState: VisualRestrictionsStateStore? = nil, focus: FocusController? = nil,
         recover: ((Bool, @escaping (Result<VisualRecoveryReport, Error>) -> Void) -> Void)? = nil) {
        self.prioritiesURL = prioritiesURL
        self.readCatalogue = refresh
        self.navigate = navigate
        self.timerScheduler = timerScheduler
        self.clock = clock
        self.visualState = visualState
        self.focus = focus
        self.recoverAction = recover
        let restrictions = visualRestrictionsState ?? VisualRestrictionsStateStore(
            url: prioritiesURL.deletingLastPathComponent().appendingPathComponent("visual-restrictions.state"))
        self.visualRestrictionsState = restrictions
        self.visualRestrictionsStatus = restrictions.read()
        self.focusObservation = focus?.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        self.modeObservation = focus?.$mode.sink { [weak self] mode in self?.updatePolling(mode) }
        if FileManager.default.fileExists(atPath: prioritiesURL.path) {
            do {
                let saved = try JSONDecoder().decode(SavedPriorities.self, from: Data(contentsOf: prioritiesURL))
                guard saved.schema == 1, Set(saved.entries.map(\.id)).count == saved.entries.count else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                priorities = Dictionary(uniqueKeysWithValues: saved.entries.map { ($0.id, $0.priority) })
            } catch { priorityStorageError = "Priority storage is unreadable. The existing file was preserved." }
        }
    }

    convenience init(prioritiesURL: URL, catalog: GhosttyCatalog = .shared,
                     visualState: TerminalVisualStateStore? = nil,
                     visualRestrictionsState: VisualRestrictionsStateStore? = nil, focus: FocusController? = nil,
                     recover: ((Bool, @escaping (Result<VisualRecoveryReport, Error>) -> Void) -> Void)? = nil) {
        self.init(prioritiesURL: prioritiesURL, refresh: catalog.refresh, navigate: catalog.goTo,
                  visualState: visualState, visualRestrictionsState: visualRestrictionsState, focus: focus, recover: recover)
    }

    func priority(for id: GhosttySurfaceID) -> SurfacePriority { priorities[id] ?? .normal }

    func setPriority(_ priority: SurfacePriority, for ids: Set<GhosttySurfaceID>) {
        guard catalogueAvailable, priorityStorageError == nil else { return }
        let valid = Set(surfaces.map(\.id))
        var next = priorities
        for id in ids.intersection(valid) {
            if priority == .normal { next.removeValue(forKey: id) } else { next[id] = priority }
        }
        save(next)
    }

    private func save(_ next: [GhosttySurfaceID: SurfacePriority]) {
        guard next != priorities else { return }
        do {
            let entries = next.map { Entry(id: $0.key, priority: $0.value) }
            let data = try JSONEncoder().encode(SavedPriorities(schema: 1, entries: entries))
            try FileManager.default.createDirectory(at: prioritiesURL.deletingLastPathComponent(),
                                                   withIntermediateDirectories: true)
            try data.write(to: prioritiesURL, options: .atomic)
            priorities = next
        } catch { priorityStorageError = "Priority changes could not be saved." }
    }

    func opened() {
        guard !isOpen else { return }
        isOpen = true
        refresh()
        updatePolling(focusMode)
    }

    func closed() { isOpen = false; clearPreview(); updatePolling(focusMode) }

    private func updatePolling(_ mode: FocusMode) {
        let needed = isOpen || mode != .off
        guard needed != polling else { return }
        polling = needed
        timerScheduler.cancelAll()
        if needed { timerScheduler.scheduleRepeating(interval: 2, on: .main) { [weak self] in self?.refresh() } }
    }

    func focusSelected() {
        guard canFocusSelected else { return }
        focus?.focusSelected(surfaces.filter { selection.contains($0.id) }, catalogue: surfaces)
    }

    func focusOff() { focus?.focusOff() }

    func clearPreview() { focus?.clearPreview() }

    func restoreVisibility(resume: Bool = false) {
        guard !recovering else { return }
        focus?.cancelForRecovery()
        recovering = true
        recoveryStatus = resume ? "Re-enabling saved visual rules; focus remains Off." : "Restoring visibility."
        guard let action = recoverAction else {
            do { try visualRestrictionsState.write(suspended: !resume) }
            catch { finishRecovery(.failure(error)); return }
            finishRecovery(.failure(HeadlessRecoveryError.helperUnavailable))
            return
        }
        action(resume) { [weak self] result in
            DispatchQueue.main.async { self?.finishRecovery(result) }
        }
    }

    private func finishRecovery(_ result: Result<VisualRecoveryReport, Error>) {
        visualRestrictionsStatus = visualRestrictionsState.read()
        switch result {
        case .success(let report):
            let counts = Dictionary(grouping: report.items, by: \.status).mapValues(\.count)
            recoveryStatus = "\(counts[.restored, default: 0]) restored, \(counts[.vanished, default: 0]) vanished, "
                + "\(counts[.unaffected, default: 0]) unaffected, \(counts[.failed, default: 0]) failed."
            if !report.catalogueAvailable { recoveryStatus! += " Native catalogue unavailable; only known targets checked." }
            if let reason = report.items.first(where: { $0.status == .failed })?.reason { recoveryStatus! += " \(reason)" }
        case .failure:
            recoveryStatus = "Recovery incomplete: helper unavailable or failed. \(visualRestrictionsStatus.message)"
        }
        recovering = false
    }

    func refresh() {
        visualRestrictionsStatus = visualRestrictionsState.read()
        if visualRestrictionsStatus.disablesRestrictions, focusMode != .off { focusOff() }
        guard !refreshing else { return }
        refreshing = true
        readCatalogue { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let rows) where !rows.isEmpty:
                if let visualState = self.visualState {
                    self.visualQueue.async { [weak self] in
                        var coverage: [GhosttySurfaceID: TerminalVisualCoverage] = [:]
                        for row in rows { coverage[row.id] = visualState.coverage(for: row) }
                        let result = coverage
                        DispatchQueue.main.async { self?.acceptCatalogue(rows, coverage: result) }
                    }
                } else { self.acceptCatalogue(rows, coverage: [:]) }
            case .success:
                self.catalogueAvailable = false
                self.status = "No surfaces reported. Native access may be unavailable; retained priorities are preserved."
                self.markCoverageStale()
            case .failure(let error):
                self.catalogueAvailable = false
                self.status = "Native catalogue unavailable: \(error). Last-known rows are retained."
                self.markCoverageStale()
            }
        }
    }

    private func acceptCatalogue(_ rows: [GhosttySurface], coverage: [GhosttySurfaceID: TerminalVisualCoverage]) {
        surfaces = rows
        catalogueAvailable = true
        refreshedAt = clock.now()
        status = "\(rows.count) native terminal surfaces"
        let ids = Set(rows.map(\.id))
        selection.formIntersection(ids)
        if priorityStorageError == nil { save(priorities.filter { ids.contains($0.key) }) }
        visualCoverage = coverage
        focus?.acceptCatalogue(rows)
        refreshing = false
    }

    private func markCoverageStale() {
        clearPreview()
        focus?.catalogueUnavailable()
        visualCoverage = visualCoverage.mapValues {
            TerminalVisualCoverage(observation: $0.observation, intent: $0.intent, attentionEligible: false,
                                   status: "Last-known coverage; native catalogue unavailable.")
        }
        refreshing = false
    }

    func goTo(_ id: GhosttySurfaceID) {
        guard catalogueAvailable, navigating == nil,
              let target = surfaces.first(where: { $0.id == id }), target.mappingIssue == nil else { return }
        navigating = id
        navigate(target) { [weak self] result in
            guard let self = self else { return }
            self.navigating = nil
            if case .failure(let error) = result { self.status = "Go To unavailable: \(error)" }
        }
    }

    private struct Entry: Codable { let id: GhosttySurfaceID; let priority: SurfacePriority }
    private struct SavedPriorities: Codable { let schema: Int; let entries: [Entry] }
}
