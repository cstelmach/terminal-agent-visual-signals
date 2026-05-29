import AppKit
import Foundation

enum ScheduleEvaluator {
    struct Result: Equatable {
        let muted: Bool
        let reason: MuteReason
    }

    static func evaluate(at date: Date, rules: ScheduleConfig, calendar: Calendar) -> Result {
        if !rules.masterActive {
            return Result(muted: true, reason: .masterPaused)
        }

        let enabledWindows = rules.allowedWindows.filter { $0.enabled }
        if !isInsideAnyWindow(at: date, windows: enabledWindows, calendar: calendar) {
            return Result(muted: true, reason: .scheduleWindow)
        }

        let enabledQuiets = rules.quietPeriods.filter { $0.enabled }
        if isInsideAnyQuietPeriod(at: date, quietPeriods: enabledQuiets, calendar: calendar) {
            return Result(muted: true, reason: .quietPeriod)
        }

        return Result(muted: false, reason: .none)
    }

    static func nextTransition(after date: Date, rules: ScheduleConfig, calendar: Calendar) -> Date? {
        let currentResult = evaluate(at: date, rules: rules, calendar: calendar)

        let truncated = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard var checkDate = calendar.date(from: truncated) else { return nil }
        // Apple's Gregorian Calendar empirically never returns nil here, even
        // across DST gaps (it skips them). Use safe unwrap anyway so a future
        // Calendar swap (custom plug-in calendar, non-Gregorian locale) cannot
        // crash the entire scheduler instead of just returning "no transition".
        guard let firstStep = calendar.date(byAdding: .minute, value: 1, to: checkDate) else { return nil }
        checkDate = firstStep

        guard let maxDate = calendar.date(byAdding: .hour, value: 48, to: date) else { return nil }

        while checkDate <= maxDate {
            let nextResult = evaluate(at: checkDate, rules: rules, calendar: calendar)
            if nextResult.muted != currentResult.muted {
                return checkDate
            }
            guard let nextStep = calendar.date(byAdding: .minute, value: 1, to: checkDate) else { return nil }
            checkDate = nextStep
        }

        return nil
    }

    // MARK: - Window evaluation

    private static func isInsideAnyWindow(at date: Date, windows: [TimeWindow], calendar: Calendar) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let timeMinutes = comps.hour! * 60 + comps.minute!
        let currentDay = dayFromWeekday(comps.weekday!)
        let yesterdayWeekday = comps.weekday! == 1 ? 7 : comps.weekday! - 1
        let yesterdayDay = dayFromWeekday(yesterdayWeekday)

        for window in windows {
            let startMinutes = parseTimeToMinutes(window.start)
            let endMinutes = parseTimeToMinutes(window.end)

            if startMinutes < endMinutes {
                if window.days.contains(currentDay)
                    && timeMinutes >= startMinutes
                    && timeMinutes < endMinutes {
                    return true
                }
            } else {
                // Overnight window (e.g., 22:00-02:00)
                if window.days.contains(currentDay) && timeMinutes >= startMinutes {
                    return true
                }
                if window.days.contains(yesterdayDay) && timeMinutes < endMinutes {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Quiet period evaluation

    private static func isInsideAnyQuietPeriod(at date: Date, quietPeriods: [QuietPeriod], calendar: Calendar) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour!
        let minute = comps.minute!
        let timeMinutes = hour * 60 + minute

        for quiet in quietPeriods {
            switch quiet.kind {
            case .hourly:
                guard let startMin = quiet.startMinute, let endMin = quiet.endMinute else { continue }
                if startMin <= endMin {
                    if minute >= startMin && minute <= endMin {
                        return true
                    }
                } else {
                    if minute >= startMin || minute <= endMin {
                        return true
                    }
                }

            case .fixedDaily:
                guard let startTime = quiet.start, let endTime = quiet.end else { continue }
                let startMins = parseTimeToMinutes(startTime)
                let endMins = parseTimeToMinutes(endTime)

                if startMins < endMins {
                    if timeMinutes >= startMins && timeMinutes < endMins {
                        return true
                    }
                } else {
                    if timeMinutes >= startMins || timeMinutes < endMins {
                        return true
                    }
                }
            }
        }

        return false
    }

    // MARK: - Helpers

    private static func dayFromWeekday(_ weekday: Int) -> Day {
        switch weekday {
        case 1: return .sun
        case 2: return .mon
        case 3: return .tue
        case 4: return .wed
        case 5: return .thu
        case 6: return .fri
        case 7: return .sat
        default: fatalError("Invalid weekday: \(weekday)")
        }
    }

    private static func parseTimeToMinutes(_ time: String) -> Int {
        let parts = time.split(separator: ":")
        return Int(parts[0])! * 60 + Int(parts[1])!
    }
}

// MARK: - Scheduler lifecycle manager

protocol BroadcasterProtocol: AnyObject {
    func broadcast()
    func broadcastPaused(visual: PauseVisual)
    func broadcastPausedClear()
    // Called once at Scheduler.start to pre-register TTYs hosting running
    // agent processes (claude / gemini / codex / opencode). Closes the
    // first-login-after-reboot gap where active-ttys/ is otherwise empty
    // until each terminal fires its first hook.
    func discoverAndRegisterActiveAgentTTYs()
}

final class Scheduler: ObservableObject {
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var reason: MuteReason = .none
    @Published private(set) var statusText: String = "Starting…"

    private let clock: Clock
    private let timerScheduler: TimerScheduler
    private let fileWatcher: FileWatcherProtocol
    private let broadcaster: BroadcasterProtocol
    private let muteStateURL: URL
    private let scheduleURL: URL
    private let calendar: Calendar
    private let pauseVisualProvider: () -> PauseVisual

    private var config: ScheduleConfig?
    private var previousMuted: Bool = false
    private var nextTransitionDate: Date?
    private var wakeObserver: NSObjectProtocol?

    // Tracks the pause visual we most recently broadcast on enter-mute. Lets
    // the file-watch / heartbeat path re-emit the paused paint when the user
    // changes pause colours (Preferences or `./tavs set`) while currently
    // muted, instead of waiting for the next mute cycle.
    private var lastPaintedPauseVisual: PauseVisual?

    init(
        clock: Clock,
        timerScheduler: TimerScheduler,
        fileWatcher: FileWatcherProtocol,
        broadcaster: BroadcasterProtocol,
        muteStateURL: URL,
        scheduleURL: URL,
        calendar: Calendar = .current,
        pauseVisualProvider: @escaping () -> PauseVisual = {
            PauseVisual(
                backgroundColor: UserConfStore.defaultPauseBgDark,
                foregroundColor: nil,
                defaultBackgroundColor: UserConfStore.defaultPauseBgDark
            )
        }
    ) {
        self.clock = clock
        self.timerScheduler = timerScheduler
        self.fileWatcher = fileWatcher
        self.broadcaster = broadcaster
        self.muteStateURL = muteStateURL
        self.scheduleURL = scheduleURL
        self.calendar = calendar
        self.pauseVisualProvider = pauseVisualProvider
    }

    func start() {
        // Pre-populate active-ttys/ from running agent processes. After a
        // reboot, /tmp/tavs-$UID is wiped and the touch-based registry is
        // empty until each terminal fires a hook. With this, the very first
        // mute transition after login already covers all live agent sessions.
        broadcaster.discoverAndRegisterActiveAgentTTYs()

        // Seed previousMuted from the on-disk mute.state so a restart-after-crash
        // correctly detects a muted→unmuted transition. Without this, a crash
        // while muted followed by a relaunch while the schedule is active
        // would leave terminals painted grey forever (no transition fires).
        if let persisted = MuteStateReader.readMutedFlag(at: muteStateURL) {
            previousMuted = persisted
        }
        loadAndEvaluate()
        startFileWatch()
        registerWakeNotification()
    }

    func stop() {
        timerScheduler.cancelAll()
        fileWatcher.stop()
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            wakeObserver = nil
        }
    }

    func togglePause() {
        guard var cfg = config else { return }
        cfg.masterActive.toggle()
        do {
            try ScheduleStore.save(cfg, to: scheduleURL)
        } catch {
            TAVSLog.scheduler.error("togglePause save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Core evaluation loop

    func loadAndEvaluate() {
        timerScheduler.cancelAll()

        do {
            config = try ScheduleStore.load(from: scheduleURL)
        } catch {
            // Schedule unparseable / missing — fall through to the no-config
            // unmuted branch below. Logging here surfaces the cause for
            // SPEC §10 debugging without coupling this loop to error handling.
            TAVSLog.scheduler.error("schedule.json load failed: \(error.localizedDescription, privacy: .public)")
            config = nil
        }
        guard let config = config else {
            writeMuteState(muted: false, reason: .none, untilEpoch: 0)
            updatePublishedState(muted: false, reason: .none, transitionDate: nil)
            scheduleHeartbeat()
            return
        }

        let now = clock.now()
        let result = ScheduleEvaluator.evaluate(at: now, rules: config, calendar: calendar)
        let transition = ScheduleEvaluator.nextTransition(after: now, rules: config, calendar: calendar)

        let wasMuted = previousMuted
        previousMuted = result.muted

        if wasMuted && !result.muted {
            broadcaster.broadcastPausedClear()
            broadcaster.broadcast()
            lastPaintedPauseVisual = nil
        }

        let untilEpoch: Int64
        if result.muted, let t = transition {
            untilEpoch = Int64(t.timeIntervalSince1970)
        } else {
            untilEpoch = 0
        }

        writeMuteState(muted: result.muted, reason: result.reason, untilEpoch: untilEpoch)

        // Note on the race window between broadcast()'s drain above and
        // writeMuteState(): a hook firing in this gap reads MUTED=true from
        // disk and buffers its OSC bytes into pending/. We deliberately do
        // NOT delete those bytes — they reflect the hook's *current* intent,
        // not stale state. Earlier code called `broadcaster.clearPending()`
        // here, which silently dropped the byte and made the user miss a
        // visual response. Race-window captures are now picked up on the
        // next mute→unmute cycle, or overwritten by the next hook from the
        // same TTY. Reordering broadcast/writeMuteState would trade this
        // missed-paint for a stale-over-correct flicker, which is worse.

        if !wasMuted && result.muted {
            let visual = pauseVisualProvider()
            broadcaster.broadcastPaused(visual: visual)
            lastPaintedPauseVisual = visual
        } else if wasMuted && result.muted {
            // Still muted, but the user may have changed the pause visual
            // (Preferences ColorPicker, ./tavs set, external user.conf edit).
            // FileWatcher fires loadAndEvaluate on any change inside ~/.tavs/,
            // and the heartbeat re-evaluates every 60s. If the visual changed,
            // re-paint; otherwise no-op so we don't churn the TTYs.
            let visual = pauseVisualProvider()
            if visual != lastPaintedPauseVisual {
                broadcaster.broadcastPaused(visual: visual)
                lastPaintedPauseVisual = visual
            }
        }
        updatePublishedState(muted: result.muted, reason: result.reason, transitionDate: transition)

        scheduleHeartbeat()
        scheduleTransitionTimer(transition, now: now)
    }

    // MARK: - Timers

    private func scheduleHeartbeat() {
        timerScheduler.scheduleRepeating(interval: 60, on: .main) { [weak self] in
            self?.heartbeatTick()
        }
    }

    private func heartbeatTick() {
        loadAndEvaluate()
    }

    private func scheduleTransitionTimer(_ transition: Date?, now: Date) {
        guard let transition = transition else { return }
        let delay = transition.timeIntervalSince(now)
        guard delay > 0 else { return }
        timerScheduler.scheduleOnce(after: delay, on: .main) { [weak self] in
            self?.loadAndEvaluate()
        }
    }

    // MARK: - File watch

    private func startFileWatch() {
        let dir = scheduleURL.deletingLastPathComponent()
        fileWatcher.start(watching: dir) { [weak self] in
            DispatchQueue.main.async {
                self?.loadAndEvaluate()
            }
        }
    }

    // MARK: - System wake

    private func registerWakeNotification() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadAndEvaluate()
        }
    }

    // MARK: - State writing

    private func writeMuteState(muted: Bool, reason: MuteReason, untilEpoch: Int64) {
        let dir = muteStateURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            // .alreadyExists is the common path; only log surprising errors.
            let nsErr = error as NSError
            if nsErr.code != NSFileWriteFileExistsError {
                TAVSLog.muteState.error("mute.state dir create failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let state = MuteStateData(
            muted: muted,
            reason: reason,
            untilEpoch: untilEpoch,
            writtenEpoch: Int64(clock.now().timeIntervalSince1970),
            appPID: ProcessInfo.processInfo.processIdentifier
        )
        do {
            try MuteStateWriter.write(state, to: muteStateURL)
        } catch {
            // The shell side will eventually treat us as dead via the 120s
            // staleness window if writes keep failing — see mute-gate.sh.
            TAVSLog.muteState.error("mute.state write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - UI state

    private func updatePublishedState(muted: Bool, reason: MuteReason, transitionDate: Date?) {
        self.isMuted = muted
        self.reason = reason
        self.nextTransitionDate = transitionDate
        self.statusText = formatStatusText(muted: muted, reason: reason, transitionDate: transitionDate)
    }

    private func formatStatusText(muted: Bool, reason: MuteReason, transitionDate: Date?) -> String {
        if muted {
            switch reason {
            case .masterPaused:
                return "Paused — click to resume"
            case .scheduleWindow:
                if let next = transitionDate {
                    return "Muted until \(formatTime(next))"
                }
                return "Muted — outside schedule"
            case .quietPeriod:
                if let next = transitionDate {
                    return "Muted until \(formatTime(next))"
                }
                return "Muted — quiet period"
            case .none:
                return "Active"
            }
        } else {
            if let next = transitionDate {
                let interval = next.timeIntervalSince(clock.now())
                if interval > 0 {
                    let minutes = Int(interval / 60)
                    if minutes < 1 {
                        // Render sub-minute transitions in seconds so the
                        // status no longer reads "next mute in 0 min".
                        let seconds = max(1, Int(interval))
                        return "Active — next mute in \(seconds) sec"
                    }
                    if minutes < 60 {
                        return "Active — next mute in \(minutes) min"
                    }
                    return "Active — next mute at \(formatTime(next))"
                }
            }
            return "Active"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.calendar = calendar
        fmt.timeZone = calendar.timeZone
        return fmt.string(from: date)
    }
}
