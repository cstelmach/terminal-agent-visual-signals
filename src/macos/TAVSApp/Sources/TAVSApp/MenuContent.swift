import SwiftUI

struct MenuContent: View {
    @ObservedObject var scheduler: Scheduler
    @ObservedObject var sessions: SessionsModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("TAVS: Terminal Agent Visual Signals")
                .font(.headline)
            Divider()
            OpenSessionsButton()
            Text(sessions.focusStatus).font(.caption)
            Button("Focus Selected") { sessions.focusSelected() }.disabled(!sessions.canFocusSelected)
            Button("Automatic Focus") { sessions.enableAutomatic() }.disabled(!sessions.canEnableAutomatic)
            Button("Focus Off") { sessions.focusOff() }
                .disabled(sessions.focusMode == .off && sessions.focusCleanupError == nil)
            if let error = sessions.focusCleanupError { Text(error).font(.caption) }
            Text(scheduler.statusText)
                .foregroundColor(.secondary)
            if let issue = scheduler.terminalUpdateIssue { Text(issue).font(.caption) }
            Divider()
            Button(scheduler.masterActive ? "Pause TAVS" : "Resume TAVS") {
                let resuming = !scheduler.masterActive
                if resuming && scheduler.isHardLocked {
                    // Resume is challenge-gated while hard-locked (spec D7).
                    // Passing permits the resume; it does NOT create a grant.
                    ChallengeGate.present { passed in
                        if passed { scheduler.togglePause(force: true) }
                    }
                } else {
                    scheduler.togglePause()
                }
            }
            Button("Restore Visibility") { sessions.restoreVisibility() }
                .disabled(sessions.recovering)
            if scheduler.visualRestrictionsStatus.disablesRestrictions {
                Button("Re-enable Visual Restrictions") { sessions.restoreVisibility(resume: true) }
                    .disabled(sessions.recovering)
                Text("Saved schedules and locks may apply immediately. Focus stays Off.").font(.caption)
            }
            if let status = sessions.recoveryStatus { Text(status).font(.caption) }
            Button("Lock Now (1h)") {
                scheduler.lockNow()
            }
            if scheduler.visualRestrictionsStatus.disablesRestrictions {
                Text("New rules and locks are saved but remain visually inactive.")
                    .font(.caption).foregroundColor(.secondary)
            }
            if scheduler.isHardLocked {
                Button("Unlock…") {
                    ChallengeGate.present { passed in
                        guard passed, let until = ChallengeGate.pickGrantEnd() else { return }
                        scheduler.grantUnlock(untilEpoch: until)
                    }
                }
            }
            if #available(macOS 14.0, *) {
                PreferencesButtonsModern()
            } else {
                PreferencesButtonsLegacy()
            }
            Divider()
            Button("Quit TAVS") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

// MARK: - macOS 14+ path

@available(macOS 14.0, *)
private struct PreferencesButtonsModern: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Edit Schedule…") {
            UserDefaults.standard.set(0, forKey: "tavs_prefs_tab")
            open()
        }
        Button("Open Preferences…") {
            open()
        }
        .keyboardShortcut(",")
    }

    // Activate first (LSUIElement apps need foreground context), then defer
    // the openSettings call to the next runloop so MenuBarExtra can finish
    // dismissing its menu before the Settings scene presents.
    private func open() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            openSettings()
        }
    }
}

// MARK: - macOS 13 fallback

private struct PreferencesButtonsLegacy: View {
    var body: some View {
        Button("Edit Schedule…") {
            UserDefaults.standard.set(0, forKey: "tavs_prefs_tab")
            open()
        }
        Button("Open Preferences…") {
            open()
        }
        .keyboardShortcut(",")
    }

    private func open() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
