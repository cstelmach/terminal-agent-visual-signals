import Foundation
import ServiceManagement

protocol LoginItemManagerProtocol: AnyObject {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
    func registerIfNeeded() throws
    func unregisterIfNeeded() throws
}

// Thin wrapper around `SMAppService.mainApp` so tests can substitute a fake
// without touching the real Service Management database.
protocol LoginItemService {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItemService: LoginItemService {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

final class LoginItemManager: LoginItemManagerProtocol {
    private let service: LoginItemService

    init(service: LoginItemService = SystemLoginItemService()) {
        self.service = service
    }

    var isEnabled: Bool { service.isEnabled }

    func register() throws { try service.register() }

    func unregister() throws { try service.unregister() }

    // Idempotent: only registers when the SMAppService status is not already
    // `.enabled`. Called from the app's launch path so reboot-survival (SPEC
    // S6 / G9 / T6.7) works without manual user intervention. Errors propagate
    // so the caller can surface them.
    func registerIfNeeded() throws {
        if service.isEnabled { return }
        try service.register()
    }

    func unregisterIfNeeded() throws {
        if !service.isEnabled { return }
        try service.unregister()
    }
}

enum LoginItemRegistrationPolicy {
    static func allowsMainAppRegistration(executableURL: URL?) -> Bool {
        guard let executableURL else { return false }

        let components = executableURL.standardizedFileURL.pathComponents
        guard let appIndex = components.lastIndex(where: { $0.hasSuffix(".app") }) else {
            return false
        }

        let contentsIndex = appIndex + 1
        let macOSIndex = appIndex + 2
        let executableIndex = appIndex + 3

        return components.indices.contains(executableIndex)
            && components[contentsIndex] == "Contents"
            && components[macOSIndex] == "MacOS"
            && !components[executableIndex].isEmpty
    }
}
