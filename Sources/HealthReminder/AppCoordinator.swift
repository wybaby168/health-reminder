import Foundation
import UserNotifications

@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private weak var model: AppModel?

    func attach(model: AppModel) {
        self.model = model
    }

    func handleNotificationPayload(_ payload: NotificationActionPayload) {
        let type = payload.typeRaw.flatMap(ReminderType.init(rawValue:))

        switch payload.actionIdentifier {
        case NotificationActionID.waterDone:
            if let model, model.markWaterDone() {
                model.snooze(.water, minutes: model.preferences.waterIntervalMinutes)
            }
        case NotificationActionID.startStand:
            model?.startStandBreak()
        case NotificationActionID.startEyes:
            model?.startEyesRest()
        case NotificationActionID.openSettings:
            model?.openSettingsWindow()
        case NotificationActionID.snooze10:
            if let type { model?.snooze(type, minutes: 10) }
        default:
            break
        }
    }
}

struct NotificationActionPayload: Sendable {
    let actionIdentifier: String
    let typeRaw: String?
}

enum NotificationCategoryID {
    static let water = "health_reminder_category_water"
    static let stand = "health_reminder_category_stand"
    static let eyes = "health_reminder_category_eyes"
}

enum NotificationActionID {
    static let waterDone = "health_reminder_action_water_done"
    static let startStand = "health_reminder_action_start_stand"
    static let startEyes = "health_reminder_action_start_eyes"
    static let snooze10 = "health_reminder_action_snooze_10"
    static let openSettings = "health_reminder_action_open_settings"
}

extension Notification.Name {
    static let openSettingsWindow = Notification.Name("health_reminder_open_settings_window")
}
