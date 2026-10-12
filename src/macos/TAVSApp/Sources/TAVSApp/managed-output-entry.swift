import Foundation
import Darwin

struct ManagedOutputResult {
    let code: Int32
    let output: String
    let error: String
}

enum ManagedOutputEntry {
    typealias Factory = (URL, URL, [String: String]) throws -> VisualRecovery
    private static let scopeKeys = ["TAVS_SESSIONS_TEST_ROOT", "TAVS_SESSIONS_TEST_TARGETS", "TAVS_SESSIONS_TEST_FIXTURE"]
    private enum Failure: Error { case unavailable, stale }

    static func handle(_ args: [String]) -> Bool {
        guard let result = run(args) else { return false }
        FileHandle.standardOutput.write(Data(result.output.utf8))
        FileHandle.standardError.write(Data(result.error.utf8))
        exit(result.code)
    }

    static func run(_ args: [String], environment: [String: String] = ProcessInfo.processInfo.environment,
                    factory: Factory = makeRecovery,
                    lookup: (Int32) -> ProcessIdentity? = ProcessIdentity.inspect,
                    renderInput: () throws -> Data = readRenderInput) -> ManagedOutputResult? {
        if args.count >= 3, args[1] == "--validate-config", args[2] == "--managed-output-capabilities" {
            return args.count == 3 ? ManagedOutputResult(code: 0, output: "tavs-managed-output-schema=1\n", error: "")
                : ManagedOutputResult(code: 1, output: "", error: "Managed output unavailable.\n")
        }
        guard args.count > 1, args[1].hasPrefix("--managed-") || args[1] == "--visual-recover" else { return nil }
        var persisted = false
        do {
            let verb = args[1]
            let count: Int
            switch verb {
            case "--visual-recover": count = 5
            case "--managed-register", "--managed-current", "--managed-reconcile", "--managed-check-context": count = 6
            case "--managed-background": count = 8
            case "--managed-forced-reset", "--managed-render": count = 7
            default: throw Failure.unavailable
            }
            guard args.count == count else { throw Failure.unavailable }
            let marker = try absoluteURL(args[2]), runtime = try absoluteURL(args[3])
            try validateRoot(marker: marker, runtime: runtime, environment: environment)
            if verb == "--visual-recover" {
                guard args[4] == "recover" || args[4] == "resume" else { throw Failure.unavailable }
                try VisualRestrictionsStateStore(url: marker).write(suspended: args[4] == "recover")
                persisted = true
                _ = try isolation(environment)
                let recovery = try factory(marker, runtime, environment)
                let operation: ManagedVisualOperation = args[4] == "recover"
                    ? .emergencyReset : .reconcile(resetLegacy: true, clearSelective: true)
                let applied = recovery.apply(operation)
                return report(VisualRecoveryReport(stateSaved: true, catalogueAvailable: applied.catalogueAvailable,
                                                   items: applied.items))
            }
            _ = try isolation(environment)
            let tty = args[4]
            guard let number = ProcessIdentity.deviceNumber(tty), tty != "/dev/tty",
                  tty.utf8.count <= 128, tty.rangeOfCharacter(from: .controlCharacters) == nil else {
                throw Failure.unavailable
            }
            let operation: ManagedVisualOperation
            let owner: ProcessGeneration
            var render: (TerminalRender, OrdinaryBackgroundIntent, Bool, Double)?
            if count == 6 && verb != "--managed-check-context" {
                guard let pid = Int32(args[5]), pid > 0 else { throw Failure.unavailable }
                owner = try ancestor(pid, device: verb == "--managed-reconcile" ? nil : number, lookup: lookup)
                switch verb {
                case "--managed-register": operation = .register
                case "--managed-current": operation = .currentRestriction
                default: operation = .reconcile(resetLegacy: true, clearSelective: false)
                }
            } else {
                let context = try OrganizerIntake.decodedContext(args[5])
                guard let producer = context.producer, let expected = context.device,
                      producer.pid > 0, producer.startSeconds > 0, producer.startMicroseconds < 1_000_000 else {
                    throw Failure.unavailable
                }
                guard expected == number, let live = lookup(producer.pid),
                      live.generation == producer, live.device == number else { throw Failure.stale }
                let synthetic: Bool
                let color: String
                if verb == "--managed-background" {
                    guard args[7] == "0" || args[7] == "1",
                          let normalized = TerminalVisualStateStore.normalizedBackground(args[6]) else {
                        throw Failure.unavailable
                    }
                    synthetic = args[7] == "1"
                    color = normalized
                } else if verb == "--managed-render" {
                    guard args[6] == "0" || args[6] == "1" else { throw Failure.unavailable }
                    synthetic = args[6] == "1"
                    color = "reset"
                } else if verb == "--managed-forced-reset" {
                    guard args[6].utf8.count <= 512, args[6].rangeOfCharacter(from: .controlCharacters) == nil else {
                        throw Failure.unavailable
                    }
                    synthetic = true
                    color = "reset"
                } else {
                    synthetic = true
                    color = "reset"
                }
                if !synthetic {
                    guard try ancestor(producer.pid, device: number, lookup: lookup) == producer else { throw Failure.stale }
                }
                owner = producer
                let intent = OrdinaryBackgroundIntent(tty: tty, device: number, producer: producer,
                    deliveryID: context.deliveryID, updatedAt: Date().timeIntervalSince1970, background: color)
                if verb == "--managed-render" {
                    let style = try TerminalRender(renderInput())
                    render = (style, intent, synthetic, context.observedAt)
                    operation = .render(style, intent, synthetic: synthetic, intakeAt: context.observedAt)
                } else if verb == "--managed-forced-reset" {
                    operation = .forcedReset(intent, intakeAt: context.observedAt, title: args[6])
                } else if verb == "--managed-check-context" {
                    operation = .checkSynthetic(intent, intakeAt: context.observedAt)
                } else {
                    operation = .ordinary(intent, synthetic: synthetic, intakeAt: context.observedAt)
                }
            }
            let recovery = try factory(marker, runtime, environment)
            let target = verb == "--managed-reconcile" ? try recovery.cachedTarget(tty: tty)
                : try recovery.target(tty: tty, owner: owner)
            if let (style, intent, synthetic, intakeAt) = render {
                let result = try recovery.render(style, intent: intent, synthetic: synthetic,
                    intakeAt: intakeAt, to: target)
                return ManagedOutputResult(code: 0, output: result.rawValue + "\n", error: "")
            }
            let wrote = try recovery.write(operation, to: target)
            return ManagedOutputResult(code: 0, output: wrote ? "restored\n" : "unaffected\n", error: "")
        } catch Failure.stale {
            return ManagedOutputResult(code: 3, output: "", error: "Managed output stale.\n")
        } catch TerminalVisualStateError.staleDelivery { return stale() }
        catch TerminalVisualStateError.staleIntent { return stale() }
        catch TerminalVisualStateError.staleObservation { return stale() }
        catch TerminalVisualStateError.staleEffect { return stale() }
        catch {
            if persisted {
                return report(VisualRecoveryReport(stateSaved: true, catalogueAvailable: false,
                    items: [VisualRecoveryItem(status: .failed, reason: "Managed restoration unavailable.")]))
            }
            return ManagedOutputResult(code: 1, output: "", error: "Managed output unavailable.\n")
        }
    }

    private static func stale() -> ManagedOutputResult {
        ManagedOutputResult(code: 3, output: "", error: "Managed output stale.\n")
    }

    private static func readRenderInput() throws -> Data {
        var info = stat()
        guard fstat(STDIN_FILENO, &info) == 0,
              info.st_mode & S_IFMT == S_IFIFO || info.st_mode & S_IFMT == S_IFREG else {
            throw Failure.unavailable
        }
        let flags = fcntl(STDIN_FILENO, F_GETFL)
        guard flags >= 0, fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 else { throw Failure.unavailable }
        defer { _ = fcntl(STDIN_FILENO, F_SETFL, flags) }
        let deadline = DispatchTime.now().uptimeNanoseconds + 100_000_000
        var data = Data(), bytes = [UInt8](repeating: 0, count: 4_096)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let count = Darwin.read(STDIN_FILENO, &bytes, bytes.count)
            if count == 0 { return data }
            if count > 0 {
                guard data.count + count <= 16_384 else { throw Failure.unavailable }
                data.append(contentsOf: bytes.prefix(count)); continue
            }
            if errno == EINTR { continue }
            guard errno == EAGAIN || errno == EWOULDBLOCK else { throw Failure.unavailable }
            var ready = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            _ = poll(&ready, 1, 5)
        }
        throw Failure.unavailable
    }

    private static func report(_ report: VisualRecoveryReport) -> ManagedOutputResult {
        guard let data = try? JSONEncoder().encode(report), let output = String(data: data, encoding: .utf8) else {
            return ManagedOutputResult(code: 1, output: "", error: "Managed report unavailable.\n")
        }
        return ManagedOutputResult(code: report.hasFailures ? 1 : 0, output: output + "\n", error: "")
    }

    private static func absoluteURL(_ value: String) throws -> URL {
        guard value.hasPrefix("/"), value.utf8.count <= 4096,
              value.rangeOfCharacter(from: .controlCharacters) == nil else { throw Failure.unavailable }
        return URL(fileURLWithPath: value)
    }

    private static func validateRoot(marker: URL, runtime: URL, environment: [String: String]) throws {
        guard scopeKeys.contains(where: { environment[$0] != nil }) else { return }
        guard let path = environment["TAVS_SESSIONS_TEST_ROOT"] else { throw Failure.unavailable }
        let root = try absoluteURL(path).resolvingSymlinksInPath()
        let temporary = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path + "/"
        let systemTemporary = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path + "/"
        guard root.path.hasPrefix(temporary) || root.path.hasPrefix(systemTemporary),
              marker.resolvingSymlinksInPath().path.hasPrefix(root.path + "/"),
              runtime.resolvingSymlinksInPath().path.hasPrefix(root.path + "/") else { throw Failure.unavailable }
    }

    private static func isolation(_ environment: [String: String]) throws -> (launch: IsolatedSessionsLaunch, allowed: Set<GhosttySurfaceID>)? {
        guard scopeKeys.contains(where: { environment[$0] != nil }) else { return nil }
        let launch = try IsolatedSessionsLaunch.environment(environment)
        guard let text = environment["TAVS_SESSIONS_TEST_TARGETS"], text.utf8.count <= 65_536,
              let ids = try? JSONDecoder().decode([GhosttySurfaceID].self, from: Data(text.utf8)), !ids.isEmpty else {
            throw Failure.unavailable
        }
        return (launch, Set(ids))
    }

    private static func ancestor(_ pid: Int32, device: UInt32?,
                                 lookup: (Int32) -> ProcessIdentity?) throws -> ProcessGeneration {
        let deadline = DispatchTime.now().uptimeNanoseconds + 100_000_000
        var current = getpid(), seen = Set<Int32>()
        for _ in 0..<16 {
            guard DispatchTime.now().uptimeNanoseconds < deadline, seen.insert(current).inserted,
                  let info = lookup(current), info.generation.pid == current,
                  info.generation.startSeconds > 0, info.generation.startMicroseconds < 1_000_000 else {
                throw Failure.unavailable
            }
            guard DispatchTime.now().uptimeNanoseconds < deadline else { throw Failure.unavailable }
            if current == pid {
                guard device == nil || info.device == device, let again = lookup(pid), again.generation == info.generation,
                      again.device == info.device, DispatchTime.now().uptimeNanoseconds < deadline else { throw Failure.unavailable }
                return info.generation
            }
            guard info.parentPID > 1, info.parentPID <= UInt32(Int32.max) else { throw Failure.unavailable }
            current = Int32(info.parentPID)
        }
        throw Failure.unavailable
    }

    private static func makeRecovery(_ marker: URL, _ runtime: URL, _ environment: [String: String]) throws -> VisualRecovery {
        let scope = try isolation(environment)
        let restrictions = VisualRestrictionsStateStore(url: marker)
        let clock = SystemClock(), runner = SystemProcessRunner()
        let state = TerminalVisualStateStore(runtimeDirectory: runtime, clock: clock)
        let policy = VisualRestrictionPolicy(restrictions: restrictions,
            muteURL: marker.deletingLastPathComponent().appendingPathComponent("mute.state"),
            lockURL: runtime.appendingPathComponent("lock.state"), clock: clock)
        let snapshot: () throws -> [GhosttySurface]
        if let fixture = scope?.launch.fixture {
            let allowed = scope!.allowed
            snapshot = {
                let data = try fixtureData(fixture)
                let instance = try JSONDecoder().decode(FixtureInstance.self, from: data).application
                return try GhosttyCatalog.decode(data, application: instance).filter { allowed.contains($0.id) }
            }
        } else {
            let catalog = scope.map { GhosttyCatalog(allowedSurfaces: $0.allowed) } ?? GhosttyCatalog.shared
            snapshot = { try catalog.snapshot() }
        }
        return VisualRecovery(runtimeDirectory: runtime, restrictions: restrictions, state: state, policy: policy,
            processRunner: runner, clock: clock, controller: ProcessIdentity.inspect(getpid())?.generation,
            allowedSurfaces: scope?.allowed, nativeSnapshot: snapshot)
    }

    private struct FixtureInstance: Decodable { let application: ProcessGeneration }

    private static func fixtureData(_ url: URL) throws -> Data {
        var info = stat()
        guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_size >= 0, info.st_size <= 1_048_576 else { throw Failure.unavailable }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.unavailable }
        defer { close(fd) }
        let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw Failure.unavailable }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 16_384)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count == 0 { return result }
            if count < 0 { if errno == EINTR { continue }; throw Failure.unavailable }
            guard result.count + count <= 1_048_576 else { throw Failure.unavailable }
            result.append(contentsOf: buffer.prefix(count))
        }
        throw Failure.unavailable
    }
}
