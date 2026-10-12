import Foundation
import Combine

enum SurfacePriority: String, Codable, CaseIterable, Identifiable {
    case high = "High", normal = "Normal", low = "Low"
    var id: Self { self }
    var rank: Int { Self.allCases.firstIndex(of: self)! }
}

final class SessionsModel: ObservableObject {
    @Published var selection = Set<GhosttySurfaceID>()
    @Published private(set) var surfaces: [GhosttySurface] = []
    @Published private(set) var priorities: [GhosttySurfaceID: SurfacePriority] = [:]
    @Published private(set) var catalogueAvailable = false
    @Published private(set) var status = "Open Sessions to read the native catalogue."
    @Published private(set) var priorityStorageError: String?
    @Published private(set) var refreshing = false
    @Published private(set) var navigating: GhosttySurfaceID?
    @Published private(set) var refreshedAt: Date?
    private let prioritiesURL: URL
    private let readCatalogue: (@escaping (Result<[GhosttySurface], Error>) -> Void) -> Void
    private let navigate: (GhosttySurface, @escaping (Result<Void, Error>) -> Void) -> Void
    private let timerScheduler: TimerScheduler
    private let clock: Clock
    private var isOpen = false

    var rows: [GhosttySurface] {
        surfaces.enumerated().sorted {
            let a = priority(for: $0.element.id).rank, b = priority(for: $1.element.id).rank
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
    }

    init(prioritiesURL: URL,
         refresh: @escaping (@escaping (Result<[GhosttySurface], Error>) -> Void) -> Void,
         navigate: @escaping (GhosttySurface, @escaping (Result<Void, Error>) -> Void) -> Void,
         timerScheduler: TimerScheduler = SystemTimerScheduler(), clock: Clock = SystemClock()) {
        self.prioritiesURL = prioritiesURL
        self.readCatalogue = refresh
        self.navigate = navigate
        self.timerScheduler = timerScheduler
        self.clock = clock
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

    convenience init(prioritiesURL: URL, catalog: GhosttyCatalog = GhosttyCatalog()) {
        self.init(prioritiesURL: prioritiesURL, refresh: catalog.refresh, navigate: catalog.goTo)
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
        timerScheduler.scheduleRepeating(interval: 2, on: .main) { [weak self] in self?.refresh() }
    }

    func closed() { isOpen = false; timerScheduler.cancelAll() }

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        readCatalogue { [weak self] result in
            guard let self = self else { return }
            self.refreshing = false
            switch result {
            case .success(let rows) where !rows.isEmpty:
                self.surfaces = rows
                self.catalogueAvailable = true
                self.refreshedAt = self.clock.now()
                self.status = "\(rows.count) native terminal surfaces"
                let ids = Set(rows.map(\.id))
                self.selection.formIntersection(ids)
                if self.priorityStorageError == nil { self.save(self.priorities.filter { ids.contains($0.key) }) }
            case .success:
                self.catalogueAvailable = false
                self.status = "No surfaces reported. Native access may be unavailable; retained priorities are preserved."
            case .failure(let error):
                self.catalogueAvailable = false
                self.status = "Native catalogue unavailable: \(error). Last-known rows are retained."
            }
        }
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
