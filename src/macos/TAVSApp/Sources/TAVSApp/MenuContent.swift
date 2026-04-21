import SwiftUI

struct MenuContent: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("TAVS — Terminal Agent Visual Signals")
                .font(.headline)
            Divider()
            Text("Status: Active")
                .foregroundColor(.secondary)
            Divider()
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
