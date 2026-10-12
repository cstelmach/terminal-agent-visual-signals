import Foundation
import Darwin

struct OrganizerMetadata {
    let fields: [String: String]
    let event: String?
    let responseID: String?
}

struct OrganizerContext: Codable {
    var schema = 1
    let deliveryID: String
    let observedAt: Double
    let provider: String
    let verifiedAgent: Bool
    let producer: ProcessGeneration?
    let device: UInt32?
    let event: String?
    let responseID: String?
}

enum OrganizerIntakeError: Error { case unavailable }

enum OrganizerIntake {
    private static let providers: Set<String> = ["claude", "codex", "gemini", "opencode", "unknown"]
    private static let modes: Set<String> = ["default", "plan", "acceptEdits", "dontAsk", "bypassPermissions"]
    private static let events: Set<String> = [
        "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest",
        "Stop", "SessionStart", "SessionEnd", "PreCompact", "SubagentStart", "SubagentStop"
    ]

    static func decode(_ data: Data, provider: String) throws -> OrganizerMetadata {
        guard providers.contains(provider), data.count <= 1_048_576,
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OrganizerIntakeError.unavailable
        }
        func string(_ key: String, limit: Int = 4096) throws -> String? {
            guard let value = values[key], !(value is NSNull) else { return nil }
            guard let text = value as? String, text.utf8.count <= limit, !text.contains("\0") else {
                throw OrganizerIntakeError.unavailable
            }
            if ["session_id", "thread-id"].contains(key),
               text.rangeOfCharacter(from: .controlCharacters) != nil {
                throw OrganizerIntakeError.unavailable
            }
            return text.isEmpty ? nil : text
        }
        var fields: [String: String] = ["TAVS_PERMISSION_MODE": "default"]
        var event: String?, responseID: String?
        if provider == "codex" {
            if try string("type", limit: 128) == "agent-turn-complete" { event = "agent-turn-complete" }
            fields["TAVS_SESSION_ID"] = try string("thread-id", limit: 512)
            fields["TAVS_CWD"] = try string("cwd")
            responseID = try string("turn-id", limit: 256)
        } else {
            let mode = try string("permission_mode", limit: 128)
            if let mode = mode, modes.contains(mode) { fields["TAVS_PERMISSION_MODE"] = mode }
            fields["TAVS_SESSION_ID"] = try string("session_id", limit: 512)
            fields["TAVS_CWD"] = try string("cwd")
            fields["TAVS_TRANSCRIPT_PATH"] = try string("transcript_path")
            let hook = try string("hook_event_name", limit: 128)
            if let hook = hook, events.contains(hook) { event = hook }
            if hook == "Notification" {
                let kind = try string("notification_type", limit: 128)
                if kind == "permission_prompt" || kind == "idle_prompt" { event = kind }
            }
        }
        return OrganizerMetadata(fields: fields, event: event, responseID: responseID)
    }

    static func handle(_ args: [String]) -> Bool {
        if args.count >= 3, args[1] == "--validate-config", args[2] == "--organizer-capabilities" {
            guard args.count == 3 else { fail() }
            print("tavs-organizer-schema=1")
            return true
        }
        guard args.count >= 2, args[1].hasPrefix("--organizer-") else { return false }
        do {
            switch args[1] {
            case "--organizer-intake", "--organizer-context":
                guard args.count == 4, providers.contains(args[2]), let caller = Int32(args[3]), caller > 0 else {
                    throw OrganizerIntakeError.unavailable
                }
                let metadata = args[1] == "--organizer-intake"
                    ? try decode(readInput(), provider: args[2])
                    : OrganizerMetadata(fields: [:], event: nil, responseID: nil)
                let identity = producer(provider: args[2], caller: caller)
                let context = OrganizerContext(deliveryID: UUID().uuidString,
                    observedAt: Date().timeIntervalSince1970, provider: args[2],
                    verifiedAgent: identity.verified, producer: identity.generation,
                    device: identity.device, event: metadata.event, responseID: metadata.responseID)
                let token = try JSONEncoder().encode(context).base64EncodedString()
                if args[1] == "--organizer-context" { print(token) }
                else {
                    for key in ["TAVS_PERMISSION_MODE", "TAVS_TRANSCRIPT_PATH", "TAVS_SESSION_ID", "TAVS_CWD"] {
                        output(key, metadata.fields[key] ?? "")
                    }
                    output("TAVS_ORGANIZER_CONTEXT", token)
                    output("TAVS_ORGANIZER_INTAKE", "1")
                }
            case "--organizer-observe":
                guard args.count == 5 else { throw OrganizerIntakeError.unavailable }
                let context = try decodedContext(args[3])
                let record = TerminalObservation(tty: args[2], device: context.device,
                    producer: context.producer, provider: context.provider,
                    verifiedAgent: context.verifiedAgent, state: args[4], event: context.event,
                    deliveryID: context.deliveryID, responseID: context.responseID,
                    observedAt: context.observedAt)
                try store().publishObservation(record)
            case "--organizer-intent":
                guard args.count == 6, args[5] == "0" || args[5] == "1" else {
                    throw OrganizerIntakeError.unavailable
                }
                let context = try decodedContext(args[3])
                let record = OrdinaryBackgroundIntent(tty: args[2], device: context.device,
                    producer: context.producer, deliveryID: context.deliveryID,
                    updatedAt: Date().timeIntervalSince1970, background: args[4])
                try store().publishIntent(record, synthetic: args[5] == "1", intakeAt: context.observedAt)
            default: throw OrganizerIntakeError.unavailable
            }
        } catch TerminalVisualStateError.staleDelivery { exit(3) }
        catch TerminalVisualStateError.staleObservation { exit(3) }
        catch TerminalVisualStateError.staleIntent { exit(3) }
        catch { fail() }
        return true
    }

    static func decodedContext(_ token: String) throws -> OrganizerContext {
        guard token.utf8.count <= 8192, let data = Data(base64Encoded: token),
              let context = try? JSONDecoder().decode(OrganizerContext.self, from: data),
              context.schema == 1, providers.contains(context.provider) else {
            throw OrganizerIntakeError.unavailable
        }
        return context
    }

    private static func store() -> TerminalVisualStateStore {
        let path = ProcessInfo.processInfo.environment["TAVS_RUNTIME_DIR"] ?? "/tmp/tavs-\(getuid())"
        return TerminalVisualStateStore(runtimeDirectory: URL(fileURLWithPath: path))
    }

    private static func output(_ key: String, _ value: String) {
        FileHandle.standardOutput.write(Data((key + "\0" + value + "\0").utf8))
    }

    private static func fail() -> Never {
        fputs("Organizer metadata unavailable.\n", stderr)
        exit(1)
    }

    private static func readInput() throws -> Data {
        let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
        let flags = fcntl(STDIN_FILENO, F_GETFL)
        guard flags >= 0, fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw OrganizerIntakeError.unavailable
        }
        defer { _ = fcntl(STDIN_FILENO, F_SETFL, flags) }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 16384)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, 20)
            if ready < 0 { if errno == EINTR { continue }; throw OrganizerIntakeError.unavailable }
            if ready == 0 { continue }
            let count = read(STDIN_FILENO, &buffer, buffer.count)
            if count == 0 { return result }
            if count < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                throw OrganizerIntakeError.unavailable
            }
            guard result.count + count <= 1_048_576 else { throw OrganizerIntakeError.unavailable }
            result.append(contentsOf: buffer.prefix(count))
        }
        throw OrganizerIntakeError.unavailable
    }

    private static func producer(provider: String, caller: Int32) ->
        (generation: ProcessGeneration?, device: UInt32?, verified: Bool) {
        let commands = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":")
            .filter { $0.hasPrefix("/") }.map { String($0) + "/" + provider }
        var pid = caller, owner: ProcessIdentity?
        for _ in 0..<16 {
            guard let info = ProcessIdentity.inspect(pid) else { break }
            if info.device != UInt32.max, info.foregroundGroup > 0,
               info.foregroundGroup <= UInt32(Int32.max),
               let foreground = ProcessIdentity.inspect(Int32(info.foregroundGroup)),
               ProcessIdentity.foregroundFamilyContains(producer: info.generation,
                    foreground: foreground.generation, device: info.device) {
                owner = owner ?? foreground
                var path = [CChar](repeating: 0, count: 4096)
                if proc_pidpath(pid, &path, UInt32(path.count)) > 0,
                   matchesProviderExecutable(provider: provider, path: String(cString: path), commands: commands) {
                    return (info.generation, info.device, true)
                }
            }
            guard info.parentPID > 0, info.parentPID <= UInt32(Int32.max), info.parentPID != UInt32(pid) else { break }
            pid = Int32(info.parentPID)
        }
        // The foreground owner can bind ordinary intent without claiming an agent identity.
        return (owner?.generation, owner?.device, false)
    }

    static func matchesProviderExecutable(provider: String, path: String, commands: [String]) -> Bool {
        guard ["claude", "codex"].contains(provider), path.hasPrefix("/") else { return false }
        let executable = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let name = executable.lastPathComponent.lowercased()
        guard !["node", "nodejs", "bun", "bash", "zsh", "sh", "dash"].contains(name),
              !name.hasPrefix("python") else { return false }
        if name == provider { return true }
        // Native installers may use a version filename behind the provider command symlink.
        return commands.contains { URL(fileURLWithPath: $0).resolvingSymlinksInPath() == executable }
    }
}
