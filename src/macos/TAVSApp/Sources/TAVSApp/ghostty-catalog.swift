import Foundation
import AppKit

struct GhosttySurfaceID: Codable, Hashable {
    let application: ProcessGeneration
    let terminalID: String
}

enum GhosttyMappingIssue: Equatable { case missingTTY, ambiguousTTY }

struct GhosttySurface: Identifiable, Equatable {
    let id: GhosttySurfaceID
    let windowID: String
    let tabID: String
    let title: String?
    let directory: String?
    let tty: String?
    let foregroundPID: Int32?
    let tabSelected: Bool?
    var mappingIssue: GhosttyMappingIssue?
}

enum GhosttyCatalogError: Error, Equatable {
    case applicationUnavailable, ambiguousApplication, staleApplication
    case malformedResponse, permissionDenied, nativeUnavailable, targetUnavailable, focusUnconfirmed
}

final class GhosttyCatalog {
    static let shared = GhosttyCatalog()
    private let processRunner: ProcessRunner
    private let application: () throws -> ProcessGeneration
    private let allowedSurfaces: Set<GhosttySurfaceID>?
    private let queue = DispatchQueue(label: "tavs.ghostty-native")
    private let lock = NSLock()
    private var refreshing = false
    private var pending: [(Result<[GhosttySurface], Error>) -> Void] = []

    init(processRunner: ProcessRunner = SystemProcessRunner(),
         application: @escaping () throws -> ProcessGeneration = currentApplication,
         allowedSurfaces: Set<GhosttySurfaceID>? = nil) {
        self.processRunner = processRunner
        self.application = application
        self.allowedSurfaces = allowedSurfaces
    }

    static func currentApplication() throws -> ProcessGeneration {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.mitchellh.ghostty")
            .filter { !$0.isTerminated }
        guard !apps.isEmpty else { throw GhosttyCatalogError.applicationUnavailable }
        guard apps.count == 1 else { throw GhosttyCatalogError.ambiguousApplication }
        guard let identity = ProcessIdentity.inspect(apps[0].processIdentifier) else {
            throw GhosttyCatalogError.applicationUnavailable
        }
        return identity.generation
    }

    static func executable(for generation: ProcessGeneration) throws -> URL {
        guard let application = NSRunningApplication(processIdentifier: generation.pid),
              !application.isTerminated, application.bundleIdentifier == "com.mitchellh.ghostty",
              ProcessIdentity.inspect(generation.pid)?.generation == generation,
              let executable = application.executableURL else { throw GhosttyCatalogError.staleApplication }
        return executable
    }

    func refresh(completion: @escaping (Result<[GhosttySurface], Error>) -> Void) {
        lock.lock()
        if refreshing { pending.append(completion); lock.unlock(); return }
        refreshing = true
        lock.unlock()
        queue.async { self.performRefresh([completion]) }
    }

    // Headless recovery cannot wait for refresh's main-thread completion callback.
    func snapshot() throws -> [GhosttySurface] {
        let completion = SnapshotCompletion()
        let deadline = DispatchTime.now() + .seconds(2)
        queue.async {
            completion.result = Result {
                guard DispatchTime.now() < deadline else { throw ProcessRunnerError.processTimedOut }
                return try self.enumerate(deadline: deadline.uptimeNanoseconds, includeMetadata: false)
            }
            completion.finished.signal()
        }
        guard completion.finished.wait(timeout: deadline) == .success, DispatchTime.now() < deadline else {
            throw ProcessRunnerError.processTimedOut
        }
        return try completion.result!.get()
    }

    private final class SnapshotCompletion {
        let finished = DispatchSemaphore(value: 0)
        var result: Result<[GhosttySurface], Error>?
    }

    private func enumerate(deadline: UInt64? = nil, includeMetadata: Bool = true) throws -> [GhosttySurface] {
        let instance = try application()
        return try request(["action": "enumerate", "pid": instance.pid, "includeMetadata": includeMetadata], instance: instance,
                           deadline: deadline).surfaces
    }

    private func performRefresh(_ completions: [(Result<[GhosttySurface], Error>) -> Void]) {
        let result = Result { try enumerate() }
        DispatchQueue.main.async { completions.forEach { $0(result) } }
        lock.lock()
        let next = pending
        pending.removeAll()
        if next.isEmpty { refreshing = false }
        lock.unlock()
        if !next.isEmpty { queue.async { self.performRefresh(next) } }
    }

    func goTo(_ target: GhosttySurface, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            let result = Result { () throws -> Void in
                guard target.mappingIssue == nil, let tty = target.tty else {
                    throw GhosttyCatalogError.targetUnavailable
                }
                guard self.allowedSurfaces?.contains(target.id) != false else {
                    throw GhosttyCatalogError.targetUnavailable
                }
                guard try self.application() == target.id.application else {
                    throw GhosttyCatalogError.staleApplication
                }
                let reply = try self.request(["action": "focus", "pid": target.id.application.pid,
                                              "terminalID": target.id.terminalID, "tty": tty],
                                             instance: target.id.application)
                guard let current = reply.surfaces.first(where: { $0.id == target.id }),
                      current.tty == tty, current.mappingIssue == nil else {
                    throw GhosttyCatalogError.targetUnavailable
                }
                guard reply.focused == true else { throw GhosttyCatalogError.focusUnconfirmed }
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func request(_ values: [String: Any], instance: ProcessGeneration, deadline: UInt64? = nil) throws -> Reply {
        var values = values
        if let allowed = allowedSurfaces {
            values["allowedIDs"] = allowed.filter { $0.application == instance }.map(\.terminalID)
        }
        let json = try JSONSerialization.data(withJSONObject: values)
        let now = DispatchTime.now().uptimeNanoseconds
        if let deadline = deadline, now >= deadline { throw ProcessRunnerError.processTimedOut }
        let timeout = deadline.map { min(2, Double($0 - now) / 1e9) } ?? 2
        let data = try processRunner.runBounded(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-l", "JavaScript", "-e", Self.script, String(decoding: json, as: UTF8.self)], timeout: timeout
        )
        guard try application() == instance else { throw GhosttyCatalogError.staleApplication }
        if let deadline = deadline, DispatchTime.now().uptimeNanoseconds >= deadline {
            throw ProcessRunnerError.processTimedOut
        }
        let surfaces = try Self.decode(data, application: instance).filter { allowedSurfaces?.contains($0.id) != false }
        let focused = try JSONDecoder().decode(Payload.self, from: data).focused
        return Reply(surfaces: surfaces, focused: focused)
    }

    static func decode(_ data: Data, application: ProcessGeneration) throws -> [GhosttySurface] {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw GhosttyCatalogError.malformedResponse
        }
        if let error = payload.error {
            switch error {
            case "permissionDenied": throw GhosttyCatalogError.permissionDenied
            case "targetUnavailable": throw GhosttyCatalogError.targetUnavailable
            case "applicationUnavailable": throw GhosttyCatalogError.applicationUnavailable
            default: throw GhosttyCatalogError.nativeUnavailable
            }
        }
        guard let rows = payload.surfaces else { throw GhosttyCatalogError.malformedResponse }
        var ids = Set<String>()
        var surfaces = try rows.map { row -> GhosttySurface in
            guard !row.terminalID.isEmpty, !row.tabID.isEmpty, !row.windowID.isEmpty,
                  ids.insert(row.terminalID).inserted else { throw GhosttyCatalogError.malformedResponse }
            let tty = row.tty.flatMap {
                $0.range(of: "^/dev/tty[sp][A-Za-z0-9]+\\z", options: .regularExpression) != nil ? $0 : nil
            }
            return GhosttySurface(id: GhosttySurfaceID(application: application, terminalID: row.terminalID),
                                  windowID: row.windowID, tabID: row.tabID, title: row.title,
                                  directory: row.directory, tty: tty, foregroundPID: row.pid,
                                  tabSelected: row.selected, mappingIssue: tty == nil ? .missingTTY : nil)
        }
        let groups = Dictionary(grouping: surfaces.compactMap(\.tty), by: { $0 })
        for index in surfaces.indices {
            if let tty = surfaces[index].tty, groups[tty]!.count > 1 {
                surfaces[index].mappingIssue = .ambiguousTTY
            }
        }
        return surfaces
    }

    private struct Reply { let surfaces: [GhosttySurface]; let focused: Bool? }
    private struct Payload: Decodable {
        let error: String?
        let surfaces: [Row]?
        let focused: Bool?
    }
    private struct Row: Decodable {
        let terminalID: String; let windowID: String; let tabID: String
        let title: String?; let directory: String?; let tty: String?
        let pid: Int32?; let selected: Bool?
    }

    // PID-bound proxies and objectWithID avoid bundle/name/index retargeting.
    static let script = """
    ObjC.import('ScriptingBridge');
    function run(argv) {
        function failure(name) { return JSON.stringify({error: name}); }
        function missing(value) {
            return value == null || (typeof value.isNil === 'function' && value.isNil());
        }
        function checkError(object) {
            var error = object.lastError;
            var code = missing(error) ? 0 : Number(error.code);
            if (isFinite(code) && code !== 0) throw {errorNumber: code};
        }
        function read(object, key) {
            var value = object.valueForKey(key);
            checkError(object);
            return value;
        }
        function scalar(object, key) {
            var value = read(object, key);
            return missing(value) ? null : ObjC.unwrap(value);
        }
        function column(app, objects, key) {
            // Use SBElementArray's bulk selector lookup instead of per-terminal metadata reads.
            var values = objects.arrayByApplyingSelector(key);
            checkError(app);
            values = ObjC.deepUnwrap(values);
            if (!Array.isArray(values)) throw {};
            return values;
        }
        function optionalColumn(app, objects, key, count) {
            try {
                var values = column(app, objects, key);
                if (values.length !== count) throw {};
                return values;
            } catch (error) {
                if (error.errorNumber === -1743) throw error;
                return Array(count).fill(null);
            }
        }
        function snapshot(app, allowedIDs, includeMetadata) {
            var result = [], all = read(app, 'terminals'), ids = column(app, all, 'id'), mapped = [];
            if (ids.some(function(id, i) { return typeof id !== 'string' || !id || ids.indexOf(id) !== i; })) throw {};
            var names = includeMetadata ? optionalColumn(app, all, 'name', ids.length) : Array(ids.length).fill(null);
            var directories = includeMetadata ? optionalColumn(app, all, 'workingDirectory', ids.length) : Array(ids.length).fill(null);
            var ttys = optionalColumn(app, all, 'tty', ids.length), pids = optionalColumn(app, all, 'pid', ids.length);
            var windows = read(app, 'windows'), windowIDs = column(app, windows, 'id');
            for (var i = 0; i < windowIDs.length; i++) {
                var tabs = read(windows.objectWithID(windowIDs[i]), 'tabs'), tabIDs = column(app, tabs, 'id');
                var selected = includeMetadata ? optionalColumn(app, tabs, 'selected', tabIDs.length) : Array(tabIDs.length).fill(null);
                for (var j = 0; j < tabIDs.length; j++) {
                    var terminalIDs = column(app, read(tabs.objectWithID(tabIDs[j]), 'terminals'), 'id');
                    for (var k = 0; k < terminalIDs.length; k++) {
                        var id = terminalIDs[k], index = ids.indexOf(id);
                        if (index === -1 || mapped.indexOf(id) !== -1) throw {};
                        mapped.push(id);
                        if (allowedIDs && allowedIDs.indexOf(id) === -1) continue;
                        result.push({terminalID: id, windowID: windowIDs[i], tabID: tabIDs[j],
                            title: names[index], directory: directories[index], tty: ttys[index],
                            pid: pids[index], selected: selected[j]});
                    }
                }
            }
            if (mapped.length !== ids.length || JSON.stringify(ids) !== JSON.stringify(column(app, all, 'id'))) throw {};
            return result;
        }
        function isFocused(app, request) {
            if (!scalar(app, 'frontmost')) return false;
            var window = read(app, 'frontWindow'), tab = read(window, 'selectedTab');
            var terminal = read(tab, 'focusedTerminal');
            return scalar(terminal, 'id') === request.terminalID && scalar(terminal, 'tty') === request.tty;
        }
        try {
            var request = JSON.parse(argv[0]);
            if (request.action !== 'enumerate' && request.action !== 'focus') return failure('nativeUnavailable');
            var app = $.SBApplication.applicationWithProcessIdentifier(request.pid);
            if (missing(app) || !app.isRunning) return failure('applicationUnavailable');
            app.timeout = 120;
            var rows = snapshot(app, request.allowedIDs, request.includeMetadata !== false);
            if (request.action === 'focus') {
                var matches = rows.filter(function(row){return row.tty === request.tty;});
                if (matches.length !== 1 || matches[0].terminalID !== request.terminalID)
                    return failure('targetUnavailable');
                var target = read(app, 'terminals').objectWithID(request.terminalID);
                if (missing(target)) return failure('targetUnavailable');
                if (scalar(target, 'id') !== request.terminalID || scalar(target, 'tty') !== request.tty)
                    return failure('targetUnavailable');
                if (!isFocused(app, request)) {
                    target.focus;
                    var error = target.lastError;
                    var code = missing(error) ? 0 : Number(error.code);
                    if (isFinite(code) && code !== 0) throw {errorNumber: code};
                }
            }
            var focused = false;
            if (request.action === 'focus') focused = isFocused(app, request);
            return JSON.stringify({surfaces: rows, focused: focused});
        } catch (error) {
            return failure(error.errorNumber === -1743 ? 'permissionDenied' : 'nativeUnavailable');
        }
    }
    """
}
