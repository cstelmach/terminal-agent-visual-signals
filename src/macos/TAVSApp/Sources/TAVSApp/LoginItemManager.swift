import Foundation

protocol LoginItemManagerProtocol: AnyObject {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

final class LoginItemManager: LoginItemManagerProtocol {
    var isEnabled: Bool {
        // Phase 6: check SMAppService.mainApp.status == .enabled
        false
    }

    func register() throws {
        // Phase 6: SMAppService.mainApp.register()
    }

    func unregister() throws {
        // Phase 6: SMAppService.mainApp.unregister()
    }
}
