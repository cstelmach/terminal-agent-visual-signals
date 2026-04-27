import Foundation
import os

// SPEC §10 production-debug path: clients tail
//   `log show --predicate 'subsystem == "com.cstelmach.tavs"' --last 5m`
// to see TAVS internals when reproducing a beta-user issue.
//
// Each component uses its own category so signposts are easy to filter.
// Errors that we previously swallowed via `try?` should be funnelled here.
enum TAVSLog {
    private static let subsystem = "com.cstelmach.tavs"

    static let appDelegate    = Logger(subsystem: subsystem, category: "AppDelegate")
    static let scheduler      = Logger(subsystem: subsystem, category: "Scheduler")
    static let broadcaster    = Logger(subsystem: subsystem, category: "Broadcaster")
    static let muteState      = Logger(subsystem: subsystem, category: "MuteState")
    static let scheduleStore  = Logger(subsystem: subsystem, category: "ScheduleStore")
    static let userConfStore  = Logger(subsystem: subsystem, category: "UserConfStore")
    static let fileWatcher    = Logger(subsystem: subsystem, category: "FileWatcher")
    static let loginItem      = Logger(subsystem: subsystem, category: "LoginItem")
}
