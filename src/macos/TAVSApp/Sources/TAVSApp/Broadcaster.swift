import Foundation

final class Broadcaster: BroadcasterProtocol {
    private let runtimeDir: URL
    private let processRunner: ProcessRunner

    init(runtimeDir: URL, processRunner: ProcessRunner) {
        self.runtimeDir = runtimeDir
        self.processRunner = processRunner
    }

    // Pause is signalled by grey background alone; no title emission. An empty
    // OSC 0 wipes user-set tab names, and a paused-title string would linger on
    // idle terminals that never fire a hook during the mute window. Dropping
    // the title entirely makes resume instant by construction.
    func broadcastPaused() {
        var data = Data()
        data.append(contentsOf: "\u{1B}]104\u{07}".utf8)
        data.append(contentsOf: "\u{1B}]11;#3A3A3A\u{07}".utf8)
        data.append(contentsOf: "\u{1B}]1337;SetBackgroundImageFile=\u{07}".utf8)
        writeToAllActiveTTYs(data)
    }

    func broadcastPausedClear() {
        var data = Data()
        data.append(contentsOf: "\u{1B}]104\u{07}".utf8)
        data.append(contentsOf: "\u{1B}]111\u{07}".utf8)
        // Intentionally do NOT emit OSC 0 here. An empty title sequence
        // (\x1B]0;\x07) blanks user-configured tab names in TAVS_TITLE_MODE
        // prefix-only, and leaves idle sessions stuck with no title until the
        // next hook fires. The next hook/idle-worker tick will repaint the
        // correct title naturally; leaving the paused title briefly in place
        // is the lesser evil.
        writeToAllActiveTTYs(data)
    }

    func clearPending() {
        let pendingDir = runtimeDir.appendingPathComponent("pending")
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: pendingDir.path) else { return }
        for entry in entries {
            try? fm.removeItem(atPath: pendingDir.appendingPathComponent(entry).path)
        }
    }

    func broadcast() {
        let pendingDir = runtimeDir.appendingPathComponent("pending")
        let fm = FileManager.default
        let validTTYs = enumerateActiveTTYs()

        DispatchQueue.concurrentPerform(iterations: validTTYs.count) { index in
            let tty = validTTYs[index]
            let pendingFile = pendingDir.appendingPathComponent("\(tty.name).osc")

            // Any missing/empty/unreadable pending file is cleaned up so it
            // does not accumulate across cycles.
            guard let data = try? Data(contentsOf: pendingFile), !data.isEmpty else {
                try? fm.removeItem(at: pendingFile)
                return
            }

            do {
                try processRunner.writeToDevice(path: tty.devicePath, data: data)
                try? fm.removeItem(at: pendingFile)
            } catch {
                let activeTTYsDir = runtimeDir.appendingPathComponent("active-ttys")
                let entryURL = activeTTYsDir.appendingPathComponent(tty.name)
                try? fm.removeItem(at: entryURL)
                try? fm.removeItem(at: pendingFile)
            }
        }
    }

    private func writeToAllActiveTTYs(_ data: Data) {
        let validTTYs = enumerateActiveTTYs()

        DispatchQueue.concurrentPerform(iterations: validTTYs.count) { index in
            let tty = validTTYs[index]
            do {
                try processRunner.writeToDevice(path: tty.devicePath, data: data)
            } catch {
                let activeTTYsDir = runtimeDir.appendingPathComponent("active-ttys")
                let entryURL = activeTTYsDir.appendingPathComponent(tty.name)
                try? FileManager.default.removeItem(at: entryURL)
            }
        }
    }

    // Shared enumeration: list active-ttys/, prune entries with unreadable
    // attributes or mtime older than 24h, reconstruct device paths.
    private func enumerateActiveTTYs() -> [(name: String, devicePath: String)] {
        let activeTTYsDir = runtimeDir.appendingPathComponent("active-ttys")
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(atPath: activeTTYsDir.path) else { return [] }

        let now = Date()
        let maxAge: TimeInterval = 24 * 3600
        var validTTYs: [(name: String, devicePath: String)] = []

        for entry in entries {
            let entryPath = activeTTYsDir.appendingPathComponent(entry).path
            guard let attrs = try? fm.attributesOfItem(atPath: entryPath),
                  let mtime = attrs[.modificationDate] as? Date else {
                try? fm.removeItem(atPath: entryPath)
                continue
            }

            if now.timeIntervalSince(mtime) >= maxAge {
                try? fm.removeItem(atPath: entryPath)
                continue
            }

            let devicePath = "/" + entry.replacingOccurrences(of: "_", with: "/")
            validTTYs.append((name: entry, devicePath: devicePath))
        }

        return validTTYs
    }
}
