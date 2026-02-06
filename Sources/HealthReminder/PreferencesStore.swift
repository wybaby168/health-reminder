import Combine
import Foundation

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var waterEnabled: Bool { didSet { persist() } }
    @Published var standEnabled: Bool { didSet { persist() } }
    @Published var eyesEnabled: Bool { didSet { persist() } }

    @Published var waterIntervalMinutes: Int { didSet { persist() } }
    @Published var standIntervalMinutes: Int { didSet { persist() } }
    @Published var eyesIntervalMinutes: Int { didSet { persist() } }

    @Published var activeStartMinutes: Int { didSet { persist() } }
    @Published var activeEndMinutes: Int { didSet { persist() } }

    @Published var dailyWaterGoalMl: Int { didSet { persist() } }

    @Published var waterDosePerTapMl: Int { didSet { persist() } }
    @Published var waterTapCooldownSeconds: Int { didSet { persist() } }

    @Published var waterConsumedTodayMl: Int { didSet { persist() } }
    @Published var dailyStamp: String { didSet { persist() } }
    @Published var lastWaterTapAt: Date { didSet { persist() } }

    @Published var pauseUntil: Date { didSet { persist() } }
    @Published var launchAtLogin: Bool { didSet { persist() } }
    @Published var soundEnabled: Bool { didSet { persist() } }

    @Published var standForceOverlayEnabled: Bool { didSet { persist() } }
    @Published var eyesForceOverlayEnabled: Bool { didSet { persist() } }

    @Published var snoozeUntilByType: [String: Date] { didSet { persist() } }

    var anyEnabled: Bool { waterEnabled || standEnabled || eyesEnabled }

    init(userDefaults: UserDefaults = .standard) {
        let stored = StoredPreferences.load(from: userDefaults)
        waterEnabled = stored.waterEnabled
        standEnabled = stored.standEnabled
        eyesEnabled = stored.eyesEnabled
        waterIntervalMinutes = stored.waterIntervalMinutes
        standIntervalMinutes = stored.standIntervalMinutes
        eyesIntervalMinutes = stored.eyesIntervalMinutes
        activeStartMinutes = stored.activeStartMinutes
        activeEndMinutes = stored.activeEndMinutes
        dailyWaterGoalMl = stored.dailyWaterGoalMl
        waterDosePerTapMl = stored.waterDosePerTapMl
        waterTapCooldownSeconds = stored.waterTapCooldownSeconds
        waterConsumedTodayMl = stored.waterConsumedTodayMl
        dailyStamp = stored.dailyStamp
        lastWaterTapAt = stored.lastWaterTapAt
        pauseUntil = stored.pauseUntil
        launchAtLogin = stored.launchAtLogin
        soundEnabled = stored.soundEnabled
        standForceOverlayEnabled = stored.standForceOverlayEnabled
        eyesForceOverlayEnabled = stored.eyesForceOverlayEnabled
        snoozeUntilByType = stored.snoozeUntilByType

        self.userDefaults = userDefaults
        refreshDailyIfNeeded()
        persist()
    }

    func resetToDefaults() {
        let d = StoredPreferences.defaults
        waterEnabled = d.waterEnabled
        standEnabled = d.standEnabled
        eyesEnabled = d.eyesEnabled
        waterIntervalMinutes = d.waterIntervalMinutes
        standIntervalMinutes = d.standIntervalMinutes
        eyesIntervalMinutes = d.eyesIntervalMinutes
        activeStartMinutes = d.activeStartMinutes
        activeEndMinutes = d.activeEndMinutes
        dailyWaterGoalMl = d.dailyWaterGoalMl
        waterDosePerTapMl = d.waterDosePerTapMl
        waterTapCooldownSeconds = d.waterTapCooldownSeconds
        waterConsumedTodayMl = d.waterConsumedTodayMl
        dailyStamp = d.dailyStamp
        lastWaterTapAt = d.lastWaterTapAt
        pauseUntil = d.pauseUntil
        launchAtLogin = d.launchAtLogin
        soundEnabled = d.soundEnabled
        standForceOverlayEnabled = d.standForceOverlayEnabled
        eyesForceOverlayEnabled = d.eyesForceOverlayEnabled
        snoozeUntilByType = d.snoozeUntilByType
    }

    func incrementWaterIntake(calendar: Calendar = .current) {
        _ = tryLogWaterIntake(calendar: calendar)
    }

    func canLogWaterNow(now: Date = Date()) -> Bool {
        now >= nextWaterTapAllowedAt
    }

    var nextWaterTapAllowedAt: Date {
        lastWaterTapAt.addingTimeInterval(TimeInterval(max(15, waterTapCooldownSeconds)))
    }

    func waterTapRemainingSeconds(now: Date = Date()) -> Int {
        max(0, Int(nextWaterTapAllowedAt.timeIntervalSince(now).rounded(.up)))
    }

    @discardableResult
    func tryLogWaterIntake(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        refreshDailyIfNeeded(calendar: calendar)
        guard canLogWaterNow(now: now) else { return nil }
        let dose = max(80, min(400, waterDosePerTapMl))
        waterConsumedTodayMl = min(dailyWaterGoalMl, waterConsumedTodayMl + dose)
        lastWaterTapAt = now
        return dose
    }

    func refreshDailyIfNeeded(calendar: Calendar = .current) {
        let today = dailyKey(for: Date(), calendar: calendar)
        if dailyStamp != today {
            dailyStamp = today
            waterConsumedTodayMl = 0
            lastWaterTapAt = .distantPast
        }
    }

    private func dailyKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    func activeWindowContains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if activeStartMinutes == activeEndMinutes {
            return true
        }
        if activeStartMinutes < activeEndMinutes {
            return minutes >= activeStartMinutes && minutes < activeEndMinutes
        }
        return minutes >= activeStartMinutes || minutes < activeEndMinutes
    }

    func nextActiveWindowStart(after date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.date(bySettingHour: activeStartMinutes / 60, minute: activeStartMinutes % 60, second: 0, of: date) ?? date
        if activeWindowContains(date, calendar: calendar) {
            return date
        }
        if start > date {
            return start
        }
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date
    }

    func suggestedWaterDoseMl(calendar: Calendar = .current) -> Int {
        let durationMinutes = activeDurationMinutes
        guard durationMinutes > 0 else { return 200 }
        let reminders = max(1, durationMinutes / max(15, waterIntervalMinutes))
        let raw = Double(dailyWaterGoalMl) / Double(reminders)
        return max(120, min(350, Int(raw.rounded())))
    }

    var activeDurationMinutes: Int {
        if activeStartMinutes == activeEndMinutes { return 24 * 60 }
        if activeStartMinutes < activeEndMinutes { return activeEndMinutes - activeStartMinutes }
        return (24 * 60 - activeStartMinutes) + activeEndMinutes
    }

    private let userDefaults: UserDefaults
    private var isPersisting = false

    private func persist() {
        guard !isPersisting else { return }
        isPersisting = true
        defer { isPersisting = false }
        let stored = StoredPreferences(
            waterEnabled: waterEnabled,
            standEnabled: standEnabled,
            eyesEnabled: eyesEnabled,
            waterIntervalMinutes: waterIntervalMinutes,
            standIntervalMinutes: standIntervalMinutes,
            eyesIntervalMinutes: eyesIntervalMinutes,
            activeStartMinutes: activeStartMinutes,
            activeEndMinutes: activeEndMinutes,
            dailyWaterGoalMl: dailyWaterGoalMl,
            waterDosePerTapMl: waterDosePerTapMl,
            waterTapCooldownSeconds: waterTapCooldownSeconds,
            waterConsumedTodayMl: waterConsumedTodayMl,
            dailyStamp: dailyStamp,
            lastWaterTapAt: lastWaterTapAt,
            pauseUntil: pauseUntil,
            launchAtLogin: launchAtLogin,
            soundEnabled: soundEnabled,
            standForceOverlayEnabled: standForceOverlayEnabled,
            eyesForceOverlayEnabled: eyesForceOverlayEnabled,
            snoozeUntilByType: snoozeUntilByType
        )
        stored.save(to: userDefaults)
    }
}

private struct StoredPreferences: Codable {
    var waterEnabled: Bool
    var standEnabled: Bool
    var eyesEnabled: Bool

    var waterIntervalMinutes: Int
    var standIntervalMinutes: Int
    var eyesIntervalMinutes: Int

    var activeStartMinutes: Int
    var activeEndMinutes: Int

    var dailyWaterGoalMl: Int
    var waterDosePerTapMl: Int
    var waterTapCooldownSeconds: Int
    var waterConsumedTodayMl: Int
    var dailyStamp: String
    var lastWaterTapAt: Date

    var pauseUntil: Date
    var launchAtLogin: Bool
    var soundEnabled: Bool
    var standForceOverlayEnabled: Bool
    var eyesForceOverlayEnabled: Bool
    var snoozeUntilByType: [String: Date]

    static let defaults = StoredPreferences(
        waterEnabled: true,
        standEnabled: true,
        eyesEnabled: true,
        waterIntervalMinutes: 60,
        standIntervalMinutes: 30,
        eyesIntervalMinutes: 20,
        activeStartMinutes: 9 * 60,
        activeEndMinutes: 21 * 60,
        dailyWaterGoalMl: 2000,
        waterDosePerTapMl: 200,
        waterTapCooldownSeconds: 120,
        waterConsumedTodayMl: 0,
        dailyStamp: "",
        lastWaterTapAt: .distantPast,
        pauseUntil: .distantPast,
        launchAtLogin: false,
        soundEnabled: true,
        standForceOverlayEnabled: true,
        eyesForceOverlayEnabled: true,
        snoozeUntilByType: [:]
    )

    private static let storageKey = "health_reminder_preferences_v1"

    init(
        waterEnabled: Bool,
        standEnabled: Bool,
        eyesEnabled: Bool,
        waterIntervalMinutes: Int,
        standIntervalMinutes: Int,
        eyesIntervalMinutes: Int,
        activeStartMinutes: Int,
        activeEndMinutes: Int,
        dailyWaterGoalMl: Int,
        waterDosePerTapMl: Int,
        waterTapCooldownSeconds: Int,
        waterConsumedTodayMl: Int,
        dailyStamp: String,
        lastWaterTapAt: Date,
        pauseUntil: Date,
        launchAtLogin: Bool,
        soundEnabled: Bool,
        standForceOverlayEnabled: Bool,
        eyesForceOverlayEnabled: Bool,
        snoozeUntilByType: [String: Date]
    ) {
        self.waterEnabled = waterEnabled
        self.standEnabled = standEnabled
        self.eyesEnabled = eyesEnabled
        self.waterIntervalMinutes = waterIntervalMinutes
        self.standIntervalMinutes = standIntervalMinutes
        self.eyesIntervalMinutes = eyesIntervalMinutes
        self.activeStartMinutes = activeStartMinutes
        self.activeEndMinutes = activeEndMinutes
        self.dailyWaterGoalMl = dailyWaterGoalMl
        self.waterDosePerTapMl = waterDosePerTapMl
        self.waterTapCooldownSeconds = waterTapCooldownSeconds
        self.waterConsumedTodayMl = waterConsumedTodayMl
        self.dailyStamp = dailyStamp
        self.lastWaterTapAt = lastWaterTapAt
        self.pauseUntil = pauseUntil
        self.launchAtLogin = launchAtLogin
        self.soundEnabled = soundEnabled
        self.standForceOverlayEnabled = standForceOverlayEnabled
        self.eyesForceOverlayEnabled = eyesForceOverlayEnabled
        self.snoozeUntilByType = snoozeUntilByType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = StoredPreferences.defaults
        waterEnabled = try c.decodeIfPresent(Bool.self, forKey: .waterEnabled) ?? d.waterEnabled
        standEnabled = try c.decodeIfPresent(Bool.self, forKey: .standEnabled) ?? d.standEnabled
        eyesEnabled = try c.decodeIfPresent(Bool.self, forKey: .eyesEnabled) ?? d.eyesEnabled
        waterIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .waterIntervalMinutes) ?? d.waterIntervalMinutes
        standIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .standIntervalMinutes) ?? d.standIntervalMinutes
        eyesIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .eyesIntervalMinutes) ?? d.eyesIntervalMinutes
        activeStartMinutes = try c.decodeIfPresent(Int.self, forKey: .activeStartMinutes) ?? d.activeStartMinutes
        activeEndMinutes = try c.decodeIfPresent(Int.self, forKey: .activeEndMinutes) ?? d.activeEndMinutes
        dailyWaterGoalMl = try c.decodeIfPresent(Int.self, forKey: .dailyWaterGoalMl) ?? d.dailyWaterGoalMl
        waterDosePerTapMl = try c.decodeIfPresent(Int.self, forKey: .waterDosePerTapMl) ?? d.waterDosePerTapMl
        waterTapCooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .waterTapCooldownSeconds) ?? d.waterTapCooldownSeconds
        waterConsumedTodayMl = try c.decodeIfPresent(Int.self, forKey: .waterConsumedTodayMl) ?? d.waterConsumedTodayMl
        dailyStamp = try c.decodeIfPresent(String.self, forKey: .dailyStamp) ?? d.dailyStamp
        lastWaterTapAt = try c.decodeIfPresent(Date.self, forKey: .lastWaterTapAt) ?? d.lastWaterTapAt
        pauseUntil = try c.decodeIfPresent(Date.self, forKey: .pauseUntil) ?? d.pauseUntil
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        standForceOverlayEnabled = try c.decodeIfPresent(Bool.self, forKey: .standForceOverlayEnabled) ?? d.standForceOverlayEnabled
        eyesForceOverlayEnabled = try c.decodeIfPresent(Bool.self, forKey: .eyesForceOverlayEnabled) ?? d.eyesForceOverlayEnabled
        snoozeUntilByType = try c.decodeIfPresent([String: Date].self, forKey: .snoozeUntilByType) ?? d.snoozeUntilByType
    }

    static func load(from userDefaults: UserDefaults) -> StoredPreferences {
        guard let data = userDefaults.data(forKey: storageKey) else { return defaults }
        return (try? JSONDecoder().decode(StoredPreferences.self, from: data)) ?? defaults
    }

    func save(to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
