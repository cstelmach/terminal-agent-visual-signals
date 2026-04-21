import Foundation
import ServiceManagement

protocol LoginItemManagerProtocol: AnyObject {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

final class LoginItemManager: LoginItemManagerProtocol {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}
