import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct TAVSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var scheduler = Scheduler.createDefault()

    var body: some Scene {
        MenuBarExtra("TAVS", systemImage: scheduler.isMuted ? "pause.circle.fill" : "circle.hexagongrid.fill") {
            MenuContent(scheduler: scheduler)
        }
    }
}

extension Scheduler {
    static func createDefault() -> Scheduler {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let runtimeDir = URL(fileURLWithPath: "/tmp/tavs-\(getuid())")
        let scheduler = Scheduler(
            clock: SystemClock(),
            timerScheduler: SystemTimerScheduler(),
            fileWatcher: FileWatcher(),
            broadcaster: Broadcaster(runtimeDir: runtimeDir, processRunner: SystemProcessRunner()),
            muteStateURL: homeDir.appendingPathComponent(".tavs/mute.state"),
            scheduleURL: homeDir.appendingPathComponent(".tavs/schedule.json")
        )
        DispatchQueue.main.async { scheduler.start() }
        return scheduler
    }
}
