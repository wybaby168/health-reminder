import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        enforceSingleInstance()

        if Bundle.main.bundleURL.pathExtension == "app" {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            registerNotificationCategories(center: center)
        }
    }

    private func enforceSingleInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        for app in running {
            if app.processIdentifier != currentPID {
                app.terminate()
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        var options: UNNotificationPresentationOptions = [.banner]
        if notification.request.content.sound != nil {
            options.insert(.sound)
        }
        return options
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let typeRaw = response.notification.request.content.userInfo["reminder_type"] as? String
        let payload = NotificationActionPayload(actionIdentifier: response.actionIdentifier, typeRaw: typeRaw)
        await MainActor.run {
            AppCoordinator.shared.handleNotificationPayload(payload)
        }
    }

    private func registerNotificationCategories(center: UNUserNotificationCenter) {
        let snooze10 = UNNotificationAction(
            identifier: NotificationActionID.snooze10,
            title: L("notification.action.snooze10"),
            options: []
        )
        let openSettings = UNNotificationAction(
            identifier: NotificationActionID.openSettings,
            title: L("notification.action.openSettings"),
            options: [.foreground]
        )

        let waterDone = UNNotificationAction(
            identifier: NotificationActionID.waterDone,
            title: L("notification.action.waterDone"),
            options: []
        )
        let startStand = UNNotificationAction(
            identifier: NotificationActionID.startStand,
            title: L("notification.action.startStand"),
            options: [.foreground]
        )
        let startEyes = UNNotificationAction(
            identifier: NotificationActionID.startEyes,
            title: L("notification.action.startEyes"),
            options: [.foreground]
        )

        let waterCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.water,
            actions: [waterDone, snooze10, openSettings],
            intentIdentifiers: [],
            options: []
        )
        let standCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.stand,
            actions: [startStand, snooze10, openSettings],
            intentIdentifiers: [],
            options: []
        )
        let eyesCategory = UNNotificationCategory(
            identifier: NotificationCategoryID.eyes,
            actions: [startEyes, snooze10, openSettings],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([waterCategory, standCategory, eyesCategory])
    }
}
