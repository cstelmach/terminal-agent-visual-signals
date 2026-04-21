import Foundation
@testable import TAVSApp

final class MockTimerScheduler: TimerScheduler {
    struct ScheduledTimer {
        let delay: TimeInterval
        let repeating: Bool
        let handler: () -> Void
    }

    private(set) var scheduledTimers: [ScheduledTimer] = []
    private(set) var cancelAllCallCount = 0

    func scheduleOnce(after delay: TimeInterval, on queue: DispatchQueue, handler: @escaping () -> Void) {
        scheduledTimers.append(ScheduledTimer(delay: delay, repeating: false, handler: handler))
    }

    func scheduleRepeating(interval: TimeInterval, on queue: DispatchQueue, handler: @escaping () -> Void) {
        scheduledTimers.append(ScheduledTimer(delay: interval, repeating: true, handler: handler))
    }

    func cancelAll() {
        cancelAllCallCount += 1
        scheduledTimers.removeAll()
    }

    func fireAll() {
        for timer in scheduledTimers {
            timer.handler()
        }
    }
}
