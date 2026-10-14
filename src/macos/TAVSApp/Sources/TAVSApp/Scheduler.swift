import AppKit
import Foundation

enum ScheduleEvaluator {
    struct Result: Equatable {
        let muted: Bool
        let reason: MuteReason
        // Hard mute: resuming is challenge-gated and the state projects to
        // lock.state (spec D7). masterPaused is NEVER hard: the manual master
        // toggle stays a soft pause; ad-hoc hard locking is `tavs lock now`.
        var hard: Bool = false
    }

    static func evaluate(at date: Date, rules: ScheduleConfig, calendar: Calendar) -> Result {
        if !rules.masterActive {
            return Result(muted: true, reason: .masterPaused)
        }

        let enabledWindows = rules.allowedWindows.filter { $0.enabled }
        if !isInsideAnyWindow(at: date, windows: enabledWindows, calendar: calendar) {
            // An allowed window marked hard means "outside my allowed hours,
            // resume is gated" — so ANY enabled hard window makes the
            // outside-windows mute hard.
            let hard = enabledWindows.contains { $0.hard == true }
            return Result(muted: true, reason: .scheduleWindow, hard: hard)
        }

        let enabledQuiets = rules.quietPeriods.filter { $0.enabled }
        let insideQuiets = enabledQuiets.filter {
            isInsideQuietPeriod(at: date, quiet: $0, calendar: calendar)
        }
        if !insideQuiets.isEmpty {
            let hard = insideQuiets.contains { $0.hard == true }
            return Result(muted: true, reason: .quietPeriod, hard: hard)
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
            // hard is part of the transition condition: a hard quiet period
            // ending while still outside allowed windows keeps muted=true but
            // must still release the lock projection at that minute.
            if nextResult.muted != currentResult.muted || nextResult.hard != currentResult.hard {
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

    private static func isInsideQuietPeriod(at date: Date, quiet: QuietPeriod, calendar: Calendar) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour!
        let minute = comps.minute!
        let timeMinutes = hour * 60 + minute

        switch quiet.kind {
        case .hourly:
            guard let startMin = quiet.startMinute, let endMin = quiet.endMinute else { return false }
            if startMin <= endMin {
                return minute >= startMin && minute <= endMin
            }
            return minute >= startMin || minute <= endMin

        case .fixedDaily:
            guard let startTime = quiet.start, let endTime = quiet.end else { return false }
            let startMins = parseTimeToMinutes(startTime)
            let endMins = parseTimeToMinutes(endTime)

            if startMins < endMins {
                return timeMinutes >= startMins && timeMinutes < endMins
            }
            return timeMinutes >= startMins || timeMinutes < endMins
        }
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
    var resultChanged: ((Bool, [VisualRecoveryItem]) -> Void)? { get set }
    func retryFailedRestrictions()
    func broadcast()
    func broadcastPaused(visual: PauseVisual)
    func broadcastLocked(visual: PauseVisual, untilText: String)
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
    @Published private(set) var visualRestrictionsStatus: VisualRestrictionsStatus = .active
    @Published private(set) var terminalUpdateIssue: String?
    @Published private(set) var masterActive = true
    // An enabled visual hard lock without an active grant gates UI resume paths.
    @Published private(set) var isHardLocked: Bool = false

    private let clock: Clock
    private let timerScheduler: TimerScheduler
    private let fileWatcher: FileWatcherProtocol
    private let broadcaster: BroadcasterProtocol
    private let muteStateURL: URL
    private let scheduleURL: URL
    private let lockStateURL: URL
    private let visualRestrictionsState: VisualRestrictionsStateStore
    private let runtimeWatcher: FileWatcherProtocol?
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
    private var lastPaintedWasLock: Bool = false
    // Last lock.state content seen on disk; the runtime-dir watcher compares
    // against it so active-ttys/pending churn does not re-trigger evaluation.
    private var lastReadLockState: LockStateData?

    init(
        clock: Clock,
        timerScheduler: TimerScheduler,
        fileWatcher: FileWatcherProtocol,
        broadcaster: BroadcasterProtocol,
        muteStateURL: URL,
        scheduleURL: URL,
        // Defaults derive lock.state next to mute.state so existing tests stay
        // hermetic; production (createDefault) passes the real runtime-dir URL.
        lockStateURL: URL? = nil,
        visualRestrictionsState: VisualRestrictionsStateStore? = nil,
        runtimeWatcher: FileWatcherProtocol? = nil,
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
        self.lockStateURL = lockStateURL
            ?? muteStateURL.deletingLastPathComponent().appendingPathComponent("lock.state")
        self.visualRestrictionsState = visualRestrictionsState ?? VisualRestrictionsStateStore(
            url: muteStateURL.deletingLastPathComponent().appendingPathComponent("visual-restrictions.state"))
        self.runtimeWatcher = runtimeWatcher
        self.calendar = calendar
        self.pauseVisualProvider = pauseVisualProvider
        broadcaster.resultChanged = { [weak self] catalogueAvailable, items in
            let count = items.filter { $0.status == .failed }.count
            var issue = count > 0 ? "Earlier terminal updates: \(count) failed. Restore Visibility is available." : ""
            if !catalogueAvailable { issue += " Native catalogue unavailable; cached targets only." }
            self?.terminalUpdateIssue = issue.isEmpty ? nil : issue.trimmingCharacters(in: .whitespaces)
        }
    }

    func start() {
        // Reconcile cached effects before discovering current native terminal
        // bindings, including when saved suspension disables restrictive paint.
        visualRestrictionsStatus = visualRestrictionsState.read()
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
        startRuntimeWatch()
        registerWakeNotification()
    }

    func stop() {
        timerScheduler.cancelAll()
        fileWatcher.stop()
        runtimeWatcher?.stop()
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            wakeObserver = nil
        }
    }

    func togglePause(force: Bool = false) {
        guard var cfg = config else { return }
        // Defense in depth under the UI gate: while hard-locked, resuming is
        // refused unless the caller passed the challenge (force). Pausing
        // MORE is always allowed (spec D7).
        let wouldResume = !cfg.masterActive
        if wouldResume && isHardLocked && !force {
            TAVSLog.scheduler.info("togglePause refused: hard lock active")
            return
        }
        cfg.masterActive.toggle()
        do {
            try ScheduleStore.save(cfg, to: scheduleURL)
        } catch {
            TAVSLog.scheduler.error("togglePause save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Menu-bar "Lock Now": manual hard lock, CLI merge semantics (keep the
    // later end of an existing lock; engaging cancels any grant). Never
    // challenge-gated (spec D7: engaging is one click).
    func lockNow(seconds: Int64 = 3600) {
        let now = Int64(clock.now().timeIntervalSince1970)
        var until = now + seconds
        if let existing = LockStateReader.read(at: lockStateURL),
           existing.locked, existing.lockUntilEpoch > until, existing.lockUntilEpoch > now {
            until = existing.lockUntilEpoch
        }
        let visual = pauseVisualProvider()
        let state = LockStateData(
            locked: true, reason: .manual,
            lockUntilEpoch: until, unlockUntilEpoch: 0,
            writtenEpoch: now,
            lockBg: visual.backgroundColor, lockFg: visual.foregroundColor
        )
        writeLockStateIfChanged(state, existing: nil)
        loadAndEvaluate()
    }

    // Called after the challenge was passed: writes the time-boxed unlock
    // grant (spec D5) and re-evaluates immediately.
    func grantUnlock(untilEpoch: Int64) {
        guard var state = LockStateReader.read(at: lockStateURL) else { return }
        state.unlockUntilEpoch = untilEpoch
        state.writtenEpoch = Int64(clock.now().timeIntervalSince1970)
        do {
            try LockStateWriter.write(state, to: lockStateURL)
        } catch {
            TAVSLog.muteState.error("grant write failed: \(error.localizedDescription, privacy: .public)")
        }
        loadAndEvaluate()
    }

    // MARK: - Core evaluation loop

    func loadAndEvaluate() {
        timerScheduler.cancelAll()
        var scheduleRejected = false
        do {
            let loaded = try ScheduleStore.load(from: scheduleURL)
            try ScheduleStore.validate(loaded)
            config = loaded
        } catch {
            // Reject invalid rules before the evaluator's validated-time parsing.
            scheduleRejected = error is ScheduleValidationError
            TAVSLog.scheduler.error("schedule.json load failed: \(error.localizedDescription, privacy: .public)")
            config = nil
        }
        masterActive = config?.masterActive ?? true

        let now = clock.now()
        guard let config = config else {
            // No schedule: nothing is schedule-muted, but a manual lock
            // written by the CLI must still project (hard lock implies mute).
            finishEvaluation(result: .init(muted: false, reason: .none), transition: nil, now: now)
            if scheduleRejected { statusText = "Schedule rejected: invalid configuration. " + statusText }
            return
        }

        let result = ScheduleEvaluator.evaluate(at: now, rules: config, calendar: calendar)
        let transition = ScheduleEvaluator.nextTransition(after: now, rules: config, calendar: calendar)
        finishEvaluation(result: result, transition: transition, now: now)
    }

    // Shared tail of the evaluation loop: merges the lock projection (spec
    // 2.2), derives the projected mute, writes both state files, broadcasts
    // transitions, and arms all wake timers.
    private func finishEvaluation(result: ScheduleEvaluator.Result, transition: Date?, now: Date) {
        let nowEpoch = Int64(now.timeIntervalSince1970)
        visualRestrictionsStatus = visualRestrictionsState.read()
        let restrictionsDisabled = visualRestrictionsStatus.disablesRestrictions

        let existingLock = LockStateReader.read(at: lockStateURL)
        let scheduleHard = result.muted && result.hard
        let visual = pauseVisualProvider()
        let scheduleUntil: Int64 = {
            guard scheduleHard, let t = transition else { return 0 }
            return Int64(t.timeIntervalSince1970)
        }()
        let mergedLock = LockStateMerge.merged(
            existing: existingLock,
            scheduleHardMuted: scheduleHard,
            scheduleUntilEpoch: scheduleUntil,
            now: nowEpoch,
            lockBg: visual.backgroundColor,
            lockFg: visual.foregroundColor
        )
        let effectiveLock = mergedLock.isEffectivelyLocked(now: nowEpoch)
        let grantActive = mergedLock.unlockUntilEpoch > nowEpoch

        // A hard lock implies mute; an active grant suspends HARD-caused mute
        // only (soft rules are never affected by grants, spec D5/D7).
        var projectedMuted: Bool
        var projectedReason: MuteReason
        if result.muted && !(scheduleHard && grantActive) {
            projectedMuted = true
            projectedReason = result.reason
        } else if effectiveLock {
            // Manual lock while the schedule itself would allow signals.
            projectedMuted = true
            projectedReason = .hardLock
        } else {
            projectedMuted = false
            projectedReason = .none
        }
        let requestedMuted = projectedMuted
        let requestedReason = projectedReason
        let hardCaused = scheduleHard || projectedReason == .hardLock
        if restrictionsDisabled {
            projectedMuted = false
            projectedReason = .none
            lastPaintedPauseVisual = nil
            lastPaintedWasLock = false
        }

        let wasMuted = previousMuted
        previousMuted = projectedMuted

        writeLockStateIfChanged(mergedLock, existing: existingLock)

        let untilEpoch: Int64
        if requestedMuted {
            if requestedReason == .hardLock {
                untilEpoch = mergedLock.lockUntilEpoch
            } else if let t = transition {
                untilEpoch = Int64(t.timeIntervalSince1970)
            } else {
                untilEpoch = 0
            }
        } else {
            untilEpoch = 0
        }

        writeMuteState(muted: projectedMuted, reason: projectedReason, untilEpoch: untilEpoch,
                       hardCaused: hardCaused, requestedMuted: requestedMuted)

        // Managed reconciliation must read the new rule projection, not the pause it clears.
        if wasMuted && !projectedMuted {
            clearPausedVisualAndReplayPending()
        }

        if !wasMuted && projectedMuted {
            paintMuted(visual: visual, effectiveLock: effectiveLock, lockUntil: mergedLock.lockUntilEpoch)
        } else if wasMuted && projectedMuted {
            // Still muted, but the visual may have changed (Preferences,
            // ./tavs set) or the state upgraded/downgraded between plain
            // pause and hard lock. Repaint only on an actual change.
            if visual != lastPaintedPauseVisual || effectiveLock != lastPaintedWasLock {
                paintMuted(visual: visual, effectiveLock: effectiveLock, lockUntil: mergedLock.lockUntilEpoch)
            }
        }

        isHardLocked = effectiveLock && !restrictionsDisabled
        updatePublishedState(
            muted: projectedMuted,
            reason: projectedReason,
            transitionDate: transition,
            lock: mergedLock,
            effectiveLock: effectiveLock,
            grantActive: grantActive
        )

        scheduleHeartbeat()
        scheduleTransitionTimer(transition, now: now)
        // One-shot wakes at lock expiry and grant expiry so re-lock/release
        // happens on the second, not at the next 60s heartbeat.
        if mergedLock.locked {
            scheduleEpochWake(mergedLock.lockUntilEpoch, now: nowEpoch)
        }
        scheduleEpochWake(mergedLock.unlockUntilEpoch, now: nowEpoch)

        lastReadLockState = LockStateReader.read(at: lockStateURL)
    }

    private func paintMuted(visual: PauseVisual, effectiveLock: Bool, lockUntil: Int64) {
        if effectiveLock {
            let untilText = formatTime(Date(timeIntervalSince1970: TimeInterval(lockUntil)))
            broadcaster.broadcastLocked(visual: visual, untilText: untilText)
        } else {
            broadcaster.broadcastPaused(visual: visual)
        }
        lastPaintedPauseVisual = visual
        lastPaintedWasLock = effectiveLock
    }

    private func clearPausedVisualAndReplayPending() {
        broadcaster.broadcastPausedClear()
        broadcaster.broadcast()
        lastPaintedPauseVisual = nil
    }

    // MARK: - Timers

    private func scheduleHeartbeat() {
        timerScheduler.scheduleRepeating(interval: 60, on: .main) { [weak self] in
            self?.heartbeatTick()
        }
    }

    private func heartbeatTick() {
        loadAndEvaluate()
        if isMuted && !visualRestrictionsStatus.disablesRestrictions {
            broadcaster.retryFailedRestrictions()
        }
    }

    private func scheduleTransitionTimer(_ transition: Date?, now: Date) {
        guard let transition = transition else { return }
        let delay = transition.timeIntervalSince(now)
        guard delay > 0 else { return }
        timerScheduler.scheduleOnce(after: delay, on: .main) { [weak self] in
            self?.loadAndEvaluate()
        }
    }

    private func scheduleEpochWake(_ epoch: Int64, now: Int64) {
        guard epoch > now else { return }
        timerScheduler.scheduleOnce(after: TimeInterval(epoch - now), on: .main) { [weak self] in
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

    // Watches the runtime dir so CLI-written lock.state changes (tavs lock
    // now / tavs unlock) propagate within the watcher debounce. The dir also
    // hosts active-ttys/ and pending/ churn from every shell open and muted
    // hook, so events re-evaluate ONLY when lock.state content changed.
    private func startRuntimeWatch() {
        guard let runtimeWatcher = runtimeWatcher else { return }
        let dir = lockStateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        runtimeWatcher.start(watching: dir) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let current = LockStateReader.read(at: self.lockStateURL)
                if current != self.lastReadLockState {
                    self.loadAndEvaluate()
                }
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

    // Persists lock.state only on semantic change (writtenEpoch excluded):
    // the runtime-dir watcher would otherwise feed our own heartbeat rewrite
    // back into re-evaluation. A machine that never uses locks never gets a
    // lock.state file at all.
    private func writeLockStateIfChanged(_ merged: LockStateData, existing: LockStateData?) {
        if existing == nil && !merged.locked && merged.unlockUntilEpoch == 0 {
            return
        }
        if var normalized = existing {
            normalized.writtenEpoch = merged.writtenEpoch
            if normalized == merged { return }
        }
        let dir = lockStateURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            let nsErr = error as NSError
            if nsErr.code != NSFileWriteFileExistsError {
                TAVSLog.muteState.error("lock.state dir create failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            try LockStateWriter.write(merged, to: lockStateURL)
        } catch {
            TAVSLog.muteState.error("lock.state write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func writeMuteState(muted: Bool, reason: MuteReason, untilEpoch: Int64,
                                hardCaused: Bool, requestedMuted: Bool) {
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

        // Keep the requested rule's resolved colors for independent resumption.
        let visual: PauseVisual? = requestedMuted ? pauseVisualProvider() : nil
        let state = MuteStateData(
            muted: muted,
            reason: reason,
            untilEpoch: untilEpoch,
            writtenEpoch: Int64(clock.now().timeIntervalSince1970),
            appPID: ProcessInfo.processInfo.processIdentifier,
            pauseBg: visual?.backgroundColor ?? "",
            pauseFg: visual?.foregroundColor ?? "",
            hardCaused: hardCaused,
            requestedMuted: requestedMuted
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

    private func updatePublishedState(
        muted: Bool,
        reason: MuteReason,
        transitionDate: Date?,
        lock: LockStateData? = nil,
        effectiveLock: Bool = false,
        grantActive: Bool = false
    ) {
        self.isMuted = muted
        self.reason = reason
        self.nextTransitionDate = transitionDate

        if visualRestrictionsStatus.disablesRestrictions {
            self.statusText = visualRestrictionsStatus.message
            return
        }

        if effectiveLock, let lock = lock {
            let until = Date(timeIntervalSince1970: TimeInterval(lock.lockUntilEpoch))
            self.statusText = "Locked until \(formatTime(until))"
            return
        }
        if grantActive, let lock = lock {
            let until = Date(timeIntervalSince1970: TimeInterval(lock.unlockUntilEpoch))
            self.statusText = "Unlocked until \(formatTime(until)) (grant)"
            return
        }
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
            case .hardLock:
                return "Locked"
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
