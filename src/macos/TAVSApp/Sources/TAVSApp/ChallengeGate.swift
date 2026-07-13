import AppKit
import Foundation

// ==============================================================================
// NSAlert-based challenge + duration UI for the menu bar app (spec section 3
// T4.5). LSUIElement apps must activate before presenting, and the alert is
// deferred to the next runloop so MenuBarExtra can finish dismissing its menu
// (same pattern as MenuContent's preferences buttons). NSAlert is used
// deliberately instead of SwiftUI sheets: sheets inside the menu popover have
// dismissal races.
// ==============================================================================

enum ChallengeGate {
    // Presents the configured challenge (3 attempts per kind, like the CLI).
    // The completion runs on the main thread with the pass/fail verdict.
    static func present(completion: @escaping (Bool) -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            completion(runChallengeModal())
        }
    }

    // Grant-duration picker (spec D5 presets). Returns the grant end epoch,
    // or nil when cancelled. Must be called on the main thread.
    static func pickGrantEnd(now: Date = Date(), calendar: Calendar = .current) -> Int64? {
        let alert = NSAlert()
        alert.messageText = "Unlock for how long?"
        alert.informativeText = "The lock re-engages automatically afterwards."
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 26), pullsDown: false)
        popup.addItems(withTitles: ["15 minutes", "1 hour", "4 hours", "Rest of day"])
        popup.selectItem(at: 1)
        alert.accessoryView = popup
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let nowEpoch = Int64(now.timeIntervalSince1970)
        switch popup.indexOfSelectedItem {
        case 0: return nowEpoch + 900
        case 1: return nowEpoch + 3600
        case 2: return nowEpoch + 14400
        default:
            let startOfToday = calendar.startOfDay(for: now)
            guard let midnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
                return nowEpoch + 3600
            }
            return Int64(midnight.timeIntervalSince1970)
        }
    }

    // MARK: - Internals

    private static func challengeConfigURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".tavs/challenge.conf")
    }

    private static func runChallengeModal() -> Bool {
        let config = ChallengeVerifier.loadConfig(at: challengeConfigURL())
        switch config.type {
        case .password:
            return passwordModal(config: config)
        case .puzzle:
            return puzzleModal(config: config)
        case .both:
            return passwordModal(config: config) && puzzleModal(config: config)
        }
    }

    private static func passwordModal(config: ChallengeConfig) -> Bool {
        for attempt in 1...3 {
            let alert = NSAlert()
            alert.messageText = "Unlock challenge"
            alert.informativeText = attempt == 1
                ? "Enter the unlock password."
                : "Wrong password (\(attempt - 1)/3). Try again."
            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            alert.accessoryView = field
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else { return false }
            if ChallengeVerifier.verifyPassword(field.stringValue, config: config) {
                return true
            }
        }
        return false
    }

    private static func puzzleModal(config: ChallengeConfig) -> Bool {
        for attempt in 1...3 {
            let sentence = ChallengeVerifier.randomSentence(config: config)
            let alert = NSAlert()
            alert.messageText = "Unlock challenge"
            var prompt = "Retype this sentence, moving each word's FIRST letter to its END:\n\n\(sentence)"
            if attempt > 1 {
                prompt = "Wrong (\(attempt - 1)/3). New sentence:\n\n\(sentence)"
            }
            alert.informativeText = prompt
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
            field.placeholderString = "transformed sentence"
            alert.accessoryView = field
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else { return false }
            if ChallengeVerifier.verifyPuzzle(answer: field.stringValue, sentence: sentence) {
                return true
            }
        }
        return false
    }
}
