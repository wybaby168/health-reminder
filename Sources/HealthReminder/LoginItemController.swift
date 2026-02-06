import Foundation
import ServiceManagement

@MainActor
final class LoginItemController {
    static let shared = LoginItemController()

    func setEnabled(_ enabled: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
