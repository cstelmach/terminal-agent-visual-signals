import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let loginItem: LoginItemManagerProtocol

    override init() {
        self.loginItem = LoginItemManager()
        super.init()
    }

    init(loginItem: LoginItemManagerProtocol) {
        self.loginItem = loginItem
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // SPEC G9: register the app as a login item so it survives reboot.
        // Idempotent — skipped when already enabled. A throw here is not fatal:
        // the user can still operate TAVS for this session and approve the
        // login item later via System Settings → General → Login Items.
        do {
            try loginItem.registerIfNeeded()
        } catch {
            TAVSLog.appDelegate.error("login item registration failed: \(error.localizedDescription, privacy: .public)")
        }
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
            pauseVisualProvider: {
                PauseVisualResolver.resolveForCurrentAppearance(userConfURL: userConfURL)
            }
        )
        DispatchQueue.main.async { scheduler.start() }
        return scheduler
    }
}

// Resolves the paused-state visual from user.conf keyed by macOS appearance.
// Re-reads on every call so a Preferences edit takes effect on the next
// scheduler evaluation. Tests pass the appearance explicitly to avoid touching
// NSApplication.shared.
enum PauseVisualResolver {
    // Called from Scheduler.loadAndEvaluate, which always runs on the main
    // queue (heartbeat timer, file-watch callback, wake notification, and
    // explicit `start()`-time dispatch all target `.main`). Not marked
    // @MainActor so the Scheduler's non-isolated closure signature stays
    // simple; if callers change, audit.
    static func resolveForCurrentAppearance(userConfURL: URL) -> PauseVisual {
        resolve(userConfURL: userConfURL, isDarkAppearance: isEffectivelyDark())
    }

    static func resolve(userConfURL: URL, isDarkAppearance: Bool) -> PauseVisual {
        let store = try? UserConfStore(url: userConfURL)
        if isDarkAppearance {
            return PauseVisual(
                backgroundColor: store?.pauseBgDark,
                foregroundColor: store?.pauseFgDark,
                defaultBackgroundColor: UserConfStore.defaultPauseBgDark
            )
        } else {
            return PauseVisual(
                backgroundColor: store?.pauseBgLight,
                foregroundColor: store?.pauseFgLight,
                defaultBackgroundColor: UserConfStore.defaultPauseBgLight
            )
        }
    }

    private static func isEffectivelyDark() -> Bool {
        let appearance = NSApplication.shared.effectiveAppearance
        let best = appearance.bestMatch(from: [.darkAqua, .aqua])
        return best == .darkAqua
    }
}
