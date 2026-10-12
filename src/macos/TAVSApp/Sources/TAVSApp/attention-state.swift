import Foundation

struct AttentionOccurrence: Hashable {
    let provider: String
    let producer: ProcessGeneration
    let tty: String
    let device: UInt32
    let key: String
}

struct AttentionState {
    private(set) var cues: [GhosttySurfaceID: Set<AttentionOccurrence>] = [:]
    private let enabledAt: Double
    private var books: [GhosttySurfaceID: Book] = [:]

    init(coverage: [GhosttySurfaceID: TerminalVisualCoverage], high: Set<GhosttySurfaceID>, enabledAt: Double) {
        self.enabledAt = enabledAt
        reconcile(coverage, high: high, baseline: true)
    }

    mutating func update(_ coverage: [GhosttySurfaceID: TerminalVisualCoverage], high: Set<GhosttySurfaceID>) {
        reconcile(coverage, high: high, baseline: false)
    }

    func snapshot(for surface: GhosttySurfaceID) -> Set<AttentionOccurrence> { cues[surface] ?? [] }

    mutating func acknowledge(_ captured: Set<AttentionOccurrence>, for surface: GhosttySurfaceID) {
        let remaining = snapshot(for: surface).subtracting(captured)
        cues[surface] = remaining.isEmpty ? nil : remaining
    }

    private mutating func reconcile(_ coverage: [GhosttySurfaceID: TerminalVisualCoverage],
                                    high: Set<GhosttySurfaceID>, baseline: Bool) {
        books = books.filter { coverage[$0.key] != nil }
        cues = cues.filter { coverage[$0.key] != nil && high.contains($0.key) }
        for (surface, sample) in coverage {
            guard let record = sample.observation, record.verifiedAgent,
                  ["claude", "codex"].contains(record.provider),
                  let producer = record.producer, let device = record.device else {
                cues[surface] = nil
                continue
            }
            var book: Book
            if let previous = books[surface], Self.sameActor(previous.latest, record) {
                guard record.observedAt > previous.latest.observedAt,
                      record.deliveryID != previous.latest.deliveryID else { continue }
                book = previous
                book.latest = record
            } else {
                cues[surface] = nil
                book = Book(latest: record)
            }
            let canCreate = !baseline && record.observedAt > enabledAt && high.contains(surface)
                && sample.attentionEligible
            if Self.resumed(record) {
                cues[surface] = nil
                book.permission = nil
            } else if record.provider == "claude", record.state == "permission",
                      ["PermissionRequest", "permission_prompt"].contains(record.event) {
                // A prompt after a closed episode is ambiguous without a fresh request anchor.
                if book.permission == nil && (record.event == "PermissionRequest" || !book.permissionSeen) {
                    let cue = AttentionOccurrence(provider: record.provider, producer: producer,
                        tty: record.tty, device: device, key: "permission:\(record.deliveryID)")
                    book.permission = cue
                    book.permissionSeen = true
                    if canCreate { cues[surface, default: []].insert(cue) }
                }
            } else if let key = Self.completionKey(record), book.completions.insert(key).inserted {
                if canCreate {
                    cues[surface, default: []].insert(AttentionOccurrence(provider: record.provider,
                        producer: producer, tty: record.tty, device: device, key: key))
                }
            }
            books[surface] = book
        }
    }

    private static func sameActor(_ a: TerminalObservation, _ b: TerminalObservation) -> Bool {
        a.provider == b.provider && a.producer == b.producer && a.tty == b.tty && a.device == b.device
    }

    private static func completionKey(_ record: TerminalObservation) -> String? {
        guard record.state == "complete" else { return nil }
        if record.provider == "claude", record.event == "Stop" { return "delivery:\(record.deliveryID)" }
        if record.provider == "codex", record.event == "agent-turn-complete", let id = record.responseID {
            return "turn:\(id)"
        }
        return nil
    }

    private static func resumed(_ record: TerminalObservation) -> Bool {
        guard record.provider == "claude", let event = record.event else { return false }
        return record.state == "processing" && ["UserPromptSubmit", "PreToolUse", "PostToolUse"].contains(event)
            || record.state == "reset" && ["SessionStart", "SessionEnd"].contains(event)
    }

    private struct Book {
        var latest: TerminalObservation
        var completions = Set<String>()
        var permission: AttentionOccurrence?
        var permissionSeen = false
    }
}
