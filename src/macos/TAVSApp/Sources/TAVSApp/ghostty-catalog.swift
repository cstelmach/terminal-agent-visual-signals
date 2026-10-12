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
        queue.async {
            completion.result = Result { try self.enumerate() }
            completion.finished.signal()
        }
        completion.finished.wait()
        return try completion.result!.get()
    }

    private final class SnapshotCompletion {
        let finished = DispatchSemaphore(value: 0)
        var result: Result<[GhosttySurface], Error>?
    }

    private func enumerate() throws -> [GhosttySurface] {
        let instance = try application()
        return try request(["action": "enumerate", "pid": instance.pid], instance: instance).surfaces
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

    private func request(_ values: [String: Any], instance: ProcessGeneration) throws -> Reply {
        var values = values
        if let allowed = allowedSurfaces {
            values["allowedIDs"] = allowed.filter { $0.application == instance }.map(\.terminalID)
        }
        let json = try JSONSerialization.data(withJSONObject: values)
        let data = try processRunner.runBounded(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-l", "JavaScript", "-e", Self.script, String(decoding: json, as: UTF8.self)], timeout: 2
        )
        guard try application() == instance else { throw GhosttyCatalogError.staleApplication }
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
        function read(object, key) {
            var value = object.valueForKey(key);
            var error = object.lastError;
            var code = missing(error) ? 0 : Number(error.code);
            if (isFinite(code) && code !== 0) throw {errorNumber: code};
            return value;
        }
        function scalar(object, key) {
            var value = read(object, key);
            return missing(value) ? null : ObjC.unwrap(value);
        }
        function optional(object, key) {
            try { return scalar(object, key); } catch (error) {
                if (error.errorNumber === -1743) throw error;
                return null;
            }
        }
        function snapshot(app, allowedIDs) {
            var result = [], windows = read(app, 'windows');
            if (!windows || !isFinite(Number(windows.count))) throw {};
            for (var i = 0; i < Number(windows.count); i++) {
                var window = windows.objectAtIndex(i), tabs = read(window, 'tabs');
                if (!tabs || !isFinite(Number(tabs.count))) throw {};
                for (var j = 0; j < Number(tabs.count); j++) {
                    var tab = tabs.objectAtIndex(j), terminals = read(tab, 'terminals');
                    if (!terminals || !isFinite(Number(terminals.count))) throw {};
                    for (var k = 0; k < Number(terminals.count); k++) {
                        var id = scalar(terminals.objectAtIndex(k), 'id');
                        if (allowedIDs && allowedIDs.indexOf(id) === -1) continue;
                        var terminal = read(app, 'terminals').objectWithID(id);
                        result.push({terminalID: id, windowID: scalar(window, 'id'), tabID: scalar(tab, 'id'),
                            title: optional(terminal, 'name'), directory: optional(terminal, 'workingDirectory'),
                            tty: optional(terminal, 'tty'), pid: optional(terminal, 'pid'), selected: optional(tab, 'selected')});
                    }
                }
            }
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
            var rows = snapshot(app, request.allowedIDs);
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
