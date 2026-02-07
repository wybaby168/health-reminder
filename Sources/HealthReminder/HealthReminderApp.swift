import SwiftUI

@main
struct HealthReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appModel)
                .frame(width: 320)
        } label: {
            Label(L("app.title"), systemImage: appModel.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(minWidth: 520, minHeight: 520)
        }
    }
}
