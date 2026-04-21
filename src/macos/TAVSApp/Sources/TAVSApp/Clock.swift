import Foundation

protocol Clock: AnyObject {
    func now() -> Date
}

final class SystemClock: Clock {
    func now() -> Date { Date() }
}

final class VirtualClock: Clock {
    private var current: Date

    init(startingAt date: Date) {
        self.current = date
    }

    func now() -> Date { current }

    func advance(by interval: TimeInterval) {
        current = current.addingTimeInterval(interval)
    }

    func set(to date: Date) {
        current = date
    }
}
