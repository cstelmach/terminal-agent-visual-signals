import Foundation

protocol TimerScheduler: AnyObject {
    func scheduleOnce(after delay: TimeInterval, on queue: DispatchQueue, handler: @escaping () -> Void)
    func scheduleRepeating(interval: TimeInterval, on queue: DispatchQueue, handler: @escaping () -> Void)
    func cancelAll()
}

final class SystemTimerScheduler: TimerScheduler {
    private var sources: [DispatchSourceTimer] = []

    func scheduleOnce(after delay: TimeInterval, on queue: DispatchQueue, handler: @escaping () -> Void) {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + delay)
        source.setEventHandler(handler: handler)
        sources.append(source)
        source.resume()
    }

    func scheduleRepeating(interval: TimeInterval, on queue: DispatchQueue, handler: @escaping () -> Void) {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + interval, repeating: interval)
        source.setEventHandler(handler: handler)
        sources.append(source)
        source.resume()
    }

    func cancelAll() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }

    deinit {
        cancelAll()
    }
}
