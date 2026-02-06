import Combine
import Foundation

protocol Clock {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

@MainActor
final class ReminderEngine: ObservableObject {
    @Published private(set) var nextTriggerByType: [ReminderType: Date] = [:]
    @Published private(set) var lastTriggeredByType: [ReminderType: Date] = [:]

    private let clock: Clock
    private unowned let preferences: PreferencesStore
    private let notificationClient: NotificationCenterClient

    private var timerByType: [ReminderType: Timer] = [:]

    init(clock: Clock, preferences: PreferencesStore, notificationClient: NotificationCenterClient) {
        self.clock = clock
        self.preferences = preferences
        self.notificationClient = notificationClient
    }

    func stop() {
        for (_, t) in timerByType {
            t.invalidate()
        }
        timerByType = [:]
    }

    func recalculate() {
        stop()

        let now = clock.now
        if preferences.pauseUntil > now {
            nextTriggerByType = [:]
            scheduleResumeCheck()
            return
        }

        var next: [ReminderType: Date] = [:]

        for type in ReminderType.allCases {
            guard isEnabled(type) else { continue }
            if let snoozeUntil = preferences.snoozeUntilByType[type.rawValue], snoozeUntil > now {
                next[type] = snoozeUntil
                schedule(type, fireAt: snoozeUntil)
                continue
            }

            let fireAt = computeNextFire(type: type, now: now)
            next[type] = fireAt
            schedule(type, fireAt: fireAt)
        }

        nextTriggerByType = next
    }

    private func scheduleResumeCheck() {
        let now = clock.now
        let until = preferences.pauseUntil
        guard until > now else { return }
        let t = Timer(fire: until, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.recalculate()
            }
        }
        RunLoop.main.add(t, forMode: .common)
    }

    private func isEnabled(_ type: ReminderType) -> Bool {
        switch type {
        case .water: return preferences.waterEnabled
        case .stand: return preferences.standEnabled
        case .eyes: return preferences.eyesEnabled
        }
    }

    private func intervalMinutes(_ type: ReminderType) -> Int {
        switch type {
        case .water: return max(15, preferences.waterIntervalMinutes)
        case .stand: return max(25, preferences.standIntervalMinutes)
        case .eyes: return max(10, preferences.eyesIntervalMinutes)
        }
    }

    private func computeNextFire(type: ReminderType, now: Date) -> Date {
        let calendar = Calendar.current
        let activeStart = preferences.nextActiveWindowStart(after: now, calendar: calendar)
        guard preferences.activeWindowContains(now, calendar: calendar) else {
            return activeStart
        }

        let interval = TimeInterval(intervalMinutes(type) * 60)
        let next = now.addingTimeInterval(interval)
        if preferences.activeWindowContains(next, calendar: calendar) {
            return roundUpToMinute(next, calendar: calendar)
        }
        return preferences.nextActiveWindowStart(after: next, calendar: calendar)
    }

    private func roundUpToMinute(_ date: Date, calendar: Calendar) -> Date {
        let seconds = calendar.component(.second, from: date)
        if seconds == 0 { return date }
        return calendar.date(byAdding: .second, value: 60 - seconds, to: date) ?? date
    }

    private func schedule(_ type: ReminderType, fireAt: Date) {
        let t = Timer(fire: fireAt, interval: 0, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fire(type)
            }
        }
        timerByType[type] = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func fire(_ type: ReminderType) async {
        let now = clock.now
        guard preferences.pauseUntil <= now else {
            recalculate()
            return
        }
        guard isEnabled(type) else {
            recalculate()
            return
        }
        guard preferences.activeWindowContains(now) else {
            recalculate()
            return
        }

        lastTriggeredByType[type] = now
        preferences.snoozeUntilByType[type.rawValue] = .distantPast

        if type == .stand, preferences.standForceOverlayEnabled {
            BreakOverlayController.shared.presentStandBreak(minDurationSeconds: 120) { [weak self] in
                guard let self else { return }
                self.preferences.snoozeUntilByType[ReminderType.stand.rawValue] = Date().addingTimeInterval(10 * 60)
                self.recalculate()
            }
            await notificationClient.sendReminder(
                type: type,
                title: "站立与活动",
                body: "现在起身走动 2 分钟。",
                soundEnabled: preferences.soundEnabled
            )
            recalculate()
            return
        }

        if type == .eyes, preferences.eyesForceOverlayEnabled {
            BreakOverlayController.shared.presentEyesRest(minDurationSeconds: 20)
            await notificationClient.sendReminder(
                type: type,
                title: "护眼休息",
                body: "开始 20 秒闭眼/远眺放松。",
                soundEnabled: false
            )
            recalculate()
            return
        }

        let content = buildNotification(type: type)
        await notificationClient.sendReminder(
            type: type,
            title: content.title,
            body: content.body,
            soundEnabled: preferences.soundEnabled
        )
        recalculate()
    }

    private func buildNotification(type: ReminderType) -> (title: String, body: String) {
        switch type {
        case .water:
            let dose = preferences.waterDosePerTapMl
            return (
                title: "喝水提醒",
                body: "建议喝水约 \(dose) ml。喝完可点通知里的“我已喝完”自动记录。"
            )
        case .stand:
            return (
                title: "站立与活动提醒",
                body: "起身站立 2 分钟，走动一下并活动肩颈。"
            )
        case .eyes:
            return (
                title: "放松眼睛提醒",
                body: "遵循 20-20-20：看 6 米外物体 20 秒，眨眼放松。"
            )
        }
    }
}
