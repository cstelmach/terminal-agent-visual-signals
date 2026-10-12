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
        // Only real .app bundle launches may self-register. SwiftPM debug
        // executables are raw Unix tools; registering one makes macOS reopen
        // it in Terminal at login, leaving a stuck `TAVSApp ; exit;` shell.
        guard LoginItemRegistrationPolicy.allowsMainAppRegistration(executableURL: Bundle.main.executableURL) else {
            TAVSLog.appDelegate.info("skipping login item registration outside app bundle")
            return
        }

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
        if OrganizerIntake.handle(args) { return }
        if ["TAVS_SESSIONS_TEST_ROOT", "TAVS_SESSIONS_TEST_FIXTURE", "TAVS_SESSIONS_TEST_TARGETS"]
            .contains(where: { ProcessInfo.processInfo.environment[$0] != nil }) {
            do {
                _ = try IsolatedSessionsLaunch.environment()
                IsolatedSessionsApp.main()
            } catch {
                fputs("Invalid isolated Sessions launch.\n", stderr)
                exit(1)
            }
            return
        }
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
        if args.count >= 4, args[1] == "--verify-password-hash" {
            // Contract-test hook for tests/integration/challenge-parity.bats:
            // prints the spec-2.4 digest for (saltHex, password).
            print(ChallengeVerifier.passwordHash(saltHex: args[2], password: args[3]))
            exit(0)
        }
        if args.contains("--reported-status") {
            let mgr = LoginItemManager()
            let status = mgr.isEnabled ? "enabled" : "not_enabled"
            print("login_item_status=\(status)")
            exit(mgr.isEnabled ? 0 : 1)
        }
        if args.contains("--unregister-login-item") {
            let mgr = LoginItemManager()
            do {
                try mgr.unregisterIfNeeded()
                print("login_item_status=unregistered")
                exit(0)
            } catch {
                fputs("unregister error: \(error)\n", stderr)
                exit(1)
            }
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
    @StateObject private var sessions = SessionsModel(prioritiesURL:
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".tavs/surface-priorities.json"))

    var body: some Scene {
        MenuBarExtra("TAVS", systemImage: scheduler.isMuted ? "pause.circle.fill" : "circle.hexagongrid.fill") {
            MenuContent(scheduler: scheduler)
        }
        Settings {
            PreferencesView(scheduler: scheduler)
        }
        Window("Sessions", id: "sessions") {
            SessionsView(model: sessions)
        }
        .defaultSize(width: 1100, height: 500)
    }
}

struct IsolatedSessionsLaunch {
    let root: URL
    let fixture: URL?
    let allowed: Set<GhosttySurfaceID>?

    static func environment(_ values: [String: String] = ProcessInfo.processInfo.environment) throws -> Self {
        guard let path = values["TAVS_SESSIONS_TEST_ROOT"], path.hasPrefix("/") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        let root = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let temporary = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path + "/"
        let systemTemporary = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path + "/"
        guard root.path.hasPrefix(temporary) || root.path.hasPrefix(systemTemporary) else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        if let file = values["TAVS_SESSIONS_TEST_FIXTURE"] {
            let url = URL(fileURLWithPath: file).resolvingSymlinksInPath()
            guard url.path.hasPrefix(root.path + "/"), FileManager.default.isReadableFile(atPath: url.path) else {
                throw CocoaError(.fileReadInvalidFileName)
            }
            return Self(root: root, fixture: url, allowed: nil)
        }
        guard let json = values["TAVS_SESSIONS_TEST_TARGETS"],
              let ids = try? JSONDecoder().decode([GhosttySurfaceID].self, from: Data(json.utf8)),
              !ids.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        return Self(root: root, fixture: nil, allowed: Set(ids))
    }

    func model() -> SessionsModel {
        let url = root.appendingPathComponent("surface-priorities.json")
        if let fixture = fixture {
            return SessionsModel(prioritiesURL: url, refresh: { done in
                done(Result {
                    let data = try Data(contentsOf: fixture)
                    let instance = try JSONDecoder().decode(FixtureInstance.self, from: data).application
                    return try GhosttyCatalog.decode(data, application: instance)
                })
            }, navigate: { _, done in done(.success(())) })
        }
        return SessionsModel(prioritiesURL: url, catalog: GhosttyCatalog(allowedSurfaces: allowed))
    }

    private struct FixtureInstance: Decodable { let application: ProcessGeneration }
}

private final class IsolatedSessionsDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.setActivationPolicy(.regular) }
}

private struct IsolatedSessionsApp: App {
    @NSApplicationDelegateAdaptor(IsolatedSessionsDelegate.self) var delegate
    @StateObject private var sessions: SessionsModel
    private let modeLabel: String

    init() {
        let launch = try! IsolatedSessionsLaunch.environment()
        _sessions = StateObject(wrappedValue: launch.model())
        modeLabel = launch.fixture == nil ? "Dedicated native catalogue" : "Fixture catalogue; Go To is simulated"
    }

    var body: some Scene {
        Window("TAVS Sessions Test", id: "sessions") {
            VStack(alignment: .leading) {
                Text(modeLabel).font(.caption).padding(.horizontal)
                SessionsView(model: sessions)
            }
        }
        .defaultSize(width: 1100, height: 500)
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
            lockStateURL: runtimeDir.appendingPathComponent("lock.state"),
            runtimeWatcher: FileWatcher(),
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
