import Foundation

final class Broadcaster: BroadcasterProtocol {
    var resultChanged: ((Bool, [VisualRecoveryItem]) -> Void)?
    private let recovery: VisualRecovery
    private let queue = DispatchQueue(label: "tavs.broadcaster")
    private let condition = NSCondition()
    private var running = false
    private var pendingRegistration = false
    private var pendingPriorEffects = false
    private var pendingOperation: ManagedVisualOperation?
    private var pendingRetry = false
    private var failures: [TerminalTargetBinding: VisualRecoveryItem] = [:]
    private var unboundItems: [VisualRecoveryItem] = []
    private var result: (catalogueAvailable: Bool, items: [VisualRecoveryItem])?

    init(recovery: VisualRecovery) {
        self.recovery = recovery
    }

    var lastResult: (catalogueAvailable: Bool, items: [VisualRecoveryItem])? {
        condition.lock()
        defer { condition.unlock() }
        return result
    }

    // Visuals and titles must be composed from current policy under the writer
    // lock, after queued native work completes. Caller snapshots are not kept.
    func broadcastPaused(visual: PauseVisual) {
        enqueue(.currentRestriction)
    }

    func broadcastLocked(visual: PauseVisual, untilText: String) {
        enqueue(.currentRestriction)
    }

    func broadcastPausedClear() {
        enqueue(.reconcile(resetLegacy: true, clearSelective: false))
    }

    func broadcast() {
        enqueue(.reconcile(resetLegacy: false, clearSelective: false))
    }

    func discoverAndRegisterActiveAgentTTYs() {
        enqueue(register: true, clearPriorEffects: true)
    }

    func retryFailedRestrictions() {
        condition.lock()
        defer { condition.unlock() }
        guard !running, !failures.isEmpty else { return }
        pendingRetry = true
        running = true
        queue.async { self.drain() }
    }

    // Used by isolated tests to await asynchronous routing without running a
    // native query or a device operation on the waiting thread.
    func waitUntilIdle(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while running {
            if !condition.wait(until: deadline) { return !running }
        }
        return true
    }

    private func enqueue(_ operation: ManagedVisualOperation? = nil,
                         register: Bool = false, clearPriorEffects: Bool = false) {
        condition.lock()
        pendingRegistration = pendingRegistration || register
        pendingPriorEffects = pendingPriorEffects || clearPriorEffects
        if let operation = operation {
            pendingRetry = false
            switch (pendingOperation, operation) {
            case let (.reconcile(oldReset, oldClear)?, .reconcile(reset, clear)):
                pendingOperation = .reconcile(resetLegacy: oldReset || reset, clearSelective: oldClear || clear)
            case (.reconcile?, .currentRestriction):
                // Reconciliation also reads fresh restrictions. Preserve required
                // clearing when a later scheduler tick asks for the current paint.
                break
            default:
                pendingOperation = operation
            }
        }
        if !running {
            running = true
            queue.async { self.drain() }
        }
        condition.unlock()
    }

    private func drain() {
        while true {
            condition.lock()
            let register = pendingRegistration
            let clearPriorEffects = pendingPriorEffects
            let operation = pendingOperation
            let retry = pendingRetry
            let retryTargets = retry ? failures.values.compactMap(\.target) : []
            let catalogueAvailable = result?.catalogueAvailable ?? false
            pendingRegistration = false
            pendingPriorEffects = false
            pendingOperation = nil
            pendingRetry = false
            guard register || clearPriorEffects || operation != nil || retry else {
                running = false
                condition.broadcast()
                condition.unlock()
                return
            }
            condition.unlock()

            // Saved effects must be cleared without waiting for native discovery.
            let priorEffects = clearPriorEffects ? recovery.reconcilePriorEffects() : []
            let registration = register ? recovery.apply(.register) : nil
            if let registration = registration {
                record((registration.catalogueAvailable, registration.items + priorEffects))
            } else if clearPriorEffects {
                record((false, priorEffects))
            }
            if let operation = operation { record(recovery.apply(operation)) }
            if retry {
                record((catalogueAvailable, recovery.apply(.reconcile(resetLegacy: false, clearSelective: false),
                    to: retryTargets)), targeted: true)
            }
        }
    }

    private func record(_ value: (catalogueAvailable: Bool, items: [VisualRecoveryItem]), targeted: Bool = false) {
        condition.lock()
        for item in value.items {
            guard let target = item.target?.physicalTarget else { continue }
            if item.status == .failed { failures[target] = item }
            else if item.status == .restored || item.status == .vanished { failures.removeValue(forKey: target) }
        }
        if !targeted { unboundItems = value.items.filter { $0.target == nil } }
        let items = value.items.filter {
            guard let target = $0.target?.physicalTarget else { return false }
            return failures[target] == nil
        } + Array(failures.values) + unboundItems
        result = (value.catalogueAvailable, items)
        let callback = resultChanged
        condition.unlock()
        let failedCount = items.filter { $0.status == .failed }.count
        if failedCount > 0 || !value.catalogueAvailable {
            TAVSLog.broadcaster.error("Terminal update failures: \(failedCount); native catalogue available: \(value.catalogueAvailable)")
        }
        DispatchQueue.main.async { callback?(value.catalogueAvailable, items) }
    }
}
