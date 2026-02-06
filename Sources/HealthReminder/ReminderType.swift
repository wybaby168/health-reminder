import Foundation

enum ReminderType: String, CaseIterable, Identifiable {
    case water
    case stand
    case eyes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water: return "喝水"
        case .stand: return "站立"
        case .eyes: return "放松眼睛"
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

