import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
enum TAVSAppMain {
    static func main() {
        let args = CommandLine.arguments
        if args.count >= 3, args[1] == "--validate-config" {
            let path = args[2]
            let url = URL(fileURLWithPath: path)
            do {
                let config = try ScheduleStore.load(from: url)
                try ScheduleStore.validate(config)
                exit(0)
            } catch {
                fputs("validation error: \(error)\n", stderr)
                exit(1)
            }
        }
        if args.contains("--reported-status") {
            let mgr = LoginItemManager()
            let status = mgr.isEnabled ? "enabled" : "not_enabled"
            print("login_item_status=\(status)")
            exit(mgr.isEnabled ? 0 : 1)
        }
        if args.contains("--dump-state") {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let muteURL = home.appendingPathComponent(".tavs/mute.state")
            let schedURL = home.appendingPathComponent(".tavs/schedule.json")
            if let data = try? String(contentsOf: muteURL, encoding: .utf8) {
                print("--- mute.state ---")
                print(data)
            }
            if let data = try? String(contentsOf: schedURL, encoding: .utf8) {
                print("--- schedule.json ---")
                print(data)
            }
            exit(0)
        }
        TAVSApp.main()
    }
}

struct TAVSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var scheduler = Scheduler.createDefault()

    var body: some Scene {
        MenuBarExtra("TAVS", systemImage: scheduler.isMuted ? "pause.circle.fill" : "circle.hexagongrid.fill") {
            MenuContent(scheduler: scheduler)
        }
        Settings {
            PreferencesView(scheduler: scheduler)
        }
    }
}

extension Scheduler {
    static func createDefault() -> Scheduler {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let runtimeDir = URL(fileURLWithPath: "/tmp/tavs-\(getuid())")
        let userConfURL = homeDir.appendingPathComponent(".tavs/user.conf")
        let scheduler = Scheduler(
            clock: SystemClock(),
            timerScheduler: SystemTimerScheduler(),
            fileWatcher: FileWatcher(),
            broadcaster: Broadcaster(runtimeDir: runtimeDir, processRunner: SystemProcessRunner()),
            muteStateURL: homeDir.appendingPathComponent(".tavs/mute.state"),
            scheduleURL: homeDir.appendingPathComponent(".tavs/schedule.json"),
            pauseColorProvider: {
                PauseColorResolver.resolve(userConfURL: userConfURL)
            }
        )
        DispatchQueue.main.async { scheduler.start() }
        return scheduler
    }
}

// Resolves the paused-state background colour from user.conf keyed by the
// macOS system appearance. Re-reads on every call so a Preferences edit takes
// effect on the next mute transition without needing the Scheduler to watch
// user.conf. Falls back to the documented defaults if a key is absent or the
// file cannot be read.
enum PauseColorResolver {
    // Called from Scheduler.loadAndEvaluate, which always runs on the main
    // queue (heartbeat timer, file-watch callback, wake notification, and
    // explicit `start()`-time dispatch all target `.main`). Not marked
    // @MainActor so the Scheduler's non-isolated closure signature stays
    // simple; if callers change, audit.
    static func resolve(userConfURL: URL) -> String {
        let store = try? UserConfStore(url: userConfURL)
        if isEffectivelyDark() {
            return store?.pauseBgDark ?? UserConfStore.defaultPauseBgDark
        } else {
            return store?.pauseBgLight ?? UserConfStore.defaultPauseBgLight
        }
    }

    private static func isEffectivelyDark() -> Bool {
        let appearance = NSApplication.shared.effectiveAppearance
        let best = appearance.bestMatch(from: [.darkAqua, .aqua])
        return best == .darkAqua
    }
}
