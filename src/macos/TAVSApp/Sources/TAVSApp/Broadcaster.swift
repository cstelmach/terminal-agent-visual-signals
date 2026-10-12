import Foundation

final class Broadcaster: BroadcasterProtocol {
    private let recovery: VisualRecovery
    private let queue = DispatchQueue(label: "tavs.broadcaster")
    private let condition = NSCondition()
    private var running = false
    private var pendingRegistration = false
    private var pendingPriorEffects = false
    private var pendingOperation: ManagedVisualOperation?
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
            pendingRegistration = false
            pendingPriorEffects = false
            pendingOperation = nil
            guard register || clearPriorEffects || operation != nil else {
                running = false
                condition.broadcast()
                condition.unlock()
                return
            }
            condition.unlock()

            let registration = register ? recovery.apply(.register) : nil
            let priorEffects = clearPriorEffects ? recovery.reconcilePriorEffects() : []
            if let registration = registration {
                record((registration.catalogueAvailable, registration.items + priorEffects))
            } else if clearPriorEffects {
                record((false, priorEffects))
            }
            if let operation = operation { record(recovery.apply(operation)) }
        }
    }

    private func record(_ value: (catalogueAvailable: Bool, items: [VisualRecoveryItem])) {
        condition.lock()
        result = value
        condition.unlock()
    }
}
