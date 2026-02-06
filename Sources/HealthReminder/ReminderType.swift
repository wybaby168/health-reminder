import Foundation

enum ReminderType: String, CaseIterable, Identifiable {
    case water
    case stand
    case eyes

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .water: return "reminder.water"
        case .stand: return "reminder.stand"
        case .eyes: return "reminder.eyes"
        }
    }

    var systemImageName: String {
        switch self {
        case .water: return "drop.fill"
        case .stand: return "figure.stand"
        case .eyes: return "eye.fill"
        }
    }
}
