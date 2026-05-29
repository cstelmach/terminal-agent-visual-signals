import Foundation

final class Broadcaster: BroadcasterProtocol {
    private let runtimeDir: URL
    private let processRunner: ProcessRunner

    init(runtimeDir: URL, processRunner: ProcessRunner) {
        self.runtimeDir = runtimeDir
        self.processRunner = processRunner
    }

    // Pause owns the terminal default foreground/background only while muted.
    // It intentionally avoids OSC 0 so user-set tab names survive pause and
    // resume unchanged. PauseVisual is already sanitized before serialization.
    func broadcastPaused(visual: PauseVisual) {
        var data = Data()
        data.append(contentsOf: "\u{1B}]104\u{07}".utf8)
        data.append(contentsOf: "\u{1B}]10;\(visual.foregroundColor)\u{07}".utf8)
        data.append(contentsOf: "\u{1B}]11;\(visual.backgroundColor)\u{07}".utf8)
        data.append(contentsOf: "\u{1B}]1337;SetBackgroundImageFile=\u{07}".utf8)
        writeToAllActiveTTYs(data)
    }

    func broadcastPausedClear() {
        var data = Data()
        data.append(contentsOf: "\u{1B}]104\u{07}".utf8)
        data.append(contentsOf: "\u{1B}]110\u{07}".utf8)
        data.append(contentsOf: "\u{1B}]111\u{07}".utf8)
        // Intentionally do NOT emit OSC 0 here. An empty title sequence
        // (\x1B]0;\x07) blanks user-configured tab names in TAVS_TITLE_MODE
        // prefix-only, and leaves idle sessions stuck with no title until the
        // next hook fires. The next hook/idle-worker tick will repaint the
        // correct title naturally; leaving the paused title briefly in place
        // is the lesser evil.
        writeToAllActiveTTYs(data)
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

    // MARK: - TTY auto-discovery (M3)

    // Pre-populates active-ttys/ from running agent processes. Without this,
    // /tmp/tavs-$UID/active-ttys/ is empty after a reboot until each terminal
    // fires its first hook — so the very first mute transition after login
    // paints zero terminals even though Claude/Gemini/Codex sessions are
    // already open.
    //
    // Invoked from Scheduler.start(). Idempotent: re-creating the same entry
    // file is harmless and refreshes its mtime, which is what the existing
    // touch-based shell registration also does.
    func discoverAndRegisterActiveAgentTTYs() {
        let lines: [String]
        do {
            lines = try Self.runPsForAgentTTYs()
        } catch {
            TAVSLog.broadcaster.error("ps invocation failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        let entries = Self.parseAgentTTYEntries(from: lines)
        let dir = runtimeDir.appendingPathComponent("active-ttys")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for entry in entries {
            let url = dir.appendingPathComponent(entry)
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }

    // Pure parser exposed for unit testing. Input is a list of "<tty> <command>"
    // lines (output of `ps -axo tty=,command=`); output is a deduplicated,
    // sorted list of active-ttys/ entry names matching the shell's TTY_SAFE
    // convention (leading "_dev_", e.g., "_dev_ttys001").
    static func parseAgentTTYEntries(from psLines: [String]) -> [String] {
        let agentNames = ["claude", "gemini", "codex", "opencode"]
        var entries = Set<String>()
        for raw in psLines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let tty = String(parts[0])
            let command = String(parts[1])
            // Skip processes without a real TTY (kernel daemons, headless
            // services, etc.) — ps reports "??" or "?" for those.
            guard tty.hasPrefix("ttys") || tty.hasPrefix("ttyp") else { continue }
            // Permissive substring match over the full command line. False
            // positives (a process whose argv happens to contain "claude")
            // are harmless: we just touch one extra registry entry and the
            // 24h cutoff in enumerateActiveTTYs prunes it eventually.
            let isAgent = agentNames.contains { command.contains($0) }
            guard isAgent else { continue }
            entries.insert("_dev_\(tty)")
        }
        return Array(entries).sorted()
    }

    private static func runPsForAgentTTYs() throws -> [String] {
        let process = Process()
        process.launchPath = "/bin/ps"
        process.arguments = ["-axo", "tty=,command="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        // CRITICAL: read BEFORE waitUntilExit. ps -axo on a busy host can
        // emit >64KB which would fill the pipe buffer and block the child;
        // waitUntilExit would then deadlock waiting for an exit that the
        // child can't reach because it's blocked on write. readDataToEndOfFile
        // drains as data arrives; waitUntilExit returns immediately after.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output.split(separator: "\n").map(String.init)
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
