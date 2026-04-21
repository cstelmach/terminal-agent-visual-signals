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
            Button("Open Preferences…") {
                // Phase 5: opens PreferencesView
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit TAVS") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
