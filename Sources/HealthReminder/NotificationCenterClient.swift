import Foundation
import UserNotifications

enum NotificationAuthorizationState: Equatable {
    case unknown
    case notDetermined
    case authorized
    case denied
}

actor NotificationCenterClient {
    static let shared = NotificationCenterClient()

    private let center: UNUserNotificationCenter?
    nonisolated let isAvailable: Bool

    init() {
        let ok = Bundle.main.bundleURL.pathExtension == "app"
        isAvailable = ok
        if ok {
            center = UNUserNotificationCenter.current()
        } else {
            center = nil
        }
    }

    func registerCategories() async {
        guard let center else { return }

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

    func authorizationStatus() async -> NotificationAuthorizationState {
        guard let center else { return .unknown }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .unknown
        }
    }

    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func sendNow(title: String, body: String, soundEnabled: Bool = true) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if soundEnabled {
            content.sound = .default
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "health_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    func sendReminder(type: ReminderType, title: String, body: String, soundEnabled: Bool) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = ["reminder_type": type.rawValue]

        switch type {
        case .water:
            content.categoryIdentifier = NotificationCategoryID.water
        case .stand:
            content.categoryIdentifier = NotificationCategoryID.stand
        case .eyes:
            content.categoryIdentifier = NotificationCategoryID.eyes
        }

        if soundEnabled {
            content.sound = .default
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "health_reminder_\(type.rawValue)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            return
        }
    }
}
