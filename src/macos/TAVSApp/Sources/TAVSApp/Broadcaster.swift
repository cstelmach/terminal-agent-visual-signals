import Foundation

final class Broadcaster: BroadcasterProtocol {
    private let runtimeDir: URL
    private let processRunner: ProcessRunner

    init(runtimeDir: URL, processRunner: ProcessRunner) {
        self.runtimeDir = runtimeDir
        self.processRunner = processRunner
    }

    func broadcast() {
        let activeTTYsDir = runtimeDir.appendingPathComponent("active-ttys")
        let pendingDir = runtimeDir.appendingPathComponent("pending")
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(atPath: activeTTYsDir.path) else { return }

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

        DispatchQueue.concurrentPerform(iterations: validTTYs.count) { index in
            let tty = validTTYs[index]
            let pendingFile = pendingDir.appendingPathComponent("\(tty.name).osc")

            guard let data = try? Data(contentsOf: pendingFile), !data.isEmpty else { return }

            do {
                try processRunner.writeToDevice(path: tty.devicePath, data: data)
                try? fm.removeItem(at: pendingFile)
            } catch {
                let entryURL = activeTTYsDir.appendingPathComponent(tty.name)
                try? fm.removeItem(at: entryURL)
                try? fm.removeItem(at: pendingFile)
            }
        }
    }
}
