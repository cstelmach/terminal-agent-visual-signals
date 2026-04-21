import SwiftUI

struct MenuContent: View {
    @ObservedObject var scheduler: Scheduler

    var body: some View {
        VStack(alignment: .leading) {
            Text("TAVS — Terminal Agent Visual Signals")
                .font(.headline)
            Divider()
            Text(scheduler.statusText)
                .foregroundColor(.secondary)
            Divider()
            Button(scheduler.isMuted && scheduler.reason == .masterPaused
                   ? "Resume TAVS"
                   : "Pause TAVS") {
                scheduler.togglePause()
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
