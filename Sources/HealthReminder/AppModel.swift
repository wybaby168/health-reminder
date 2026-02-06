import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var preferences = PreferencesStore()
    @Published private(set) var authorization: NotificationAuthorizationState = .unknown
    @Published private(set) var nextTriggerByType: [ReminderType: Date] = [:]
    @Published private(set) var lastTriggeredByType: [ReminderType: Date] = [:]
    @Published var toast: ToastMessage?

    private let notifications = NotificationCenterClient.shared
    private let loginItem = LoginItemController.shared
    private var engine: ReminderEngine?
    private var cancellables: Set<AnyCancellable> = []

    var menuBarSymbolName: String {
        if preferences.pauseUntil > Date() {
            return "pause.circle.fill"
        }
        if !preferences.anyEnabled {
            return "bell.slash.fill"
        }
        return "heart.text.square.fill"
    }

    var notificationClientAvailable: Bool {
        notifications.isAvailable
    }

    init() {
        AppCoordinator.shared.attach(model: self)
        Task { await refreshAuthorization() }
        Task { await requestAuthorizationIfNeeded() }

        let engine = ReminderEngine(
            clock: SystemClock(),
            preferences: preferences,
            notificationClient: notifications
        )
        self.engine = engine

        engine.$nextTriggerByType
            .receive(on: RunLoop.main)
            .assign(to: &$nextTriggerByType)

        engine.$lastTriggeredByType
            .receive(on: RunLoop.main)
            .assign(to: &$lastTriggeredByType)

        preferences.objectWillChange
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.engine?.recalculate()
            }
            .store(in: &cancellables)

        observeSystemSleepWake()
        engine.recalculate()
    }

    func requestAuthorizationIfNeeded() async {
        let current = await notifications.authorizationStatus()
        await MainActor.run { authorization = current }
        guard current == .notDetermined else { return }
        NSApp.activate(ignoringOtherApps: true)
        let granted = await notifications.requestAuthorization()
        await MainActor.run { authorization = granted ? .authorized : .denied }
    }

    func refreshAuthorization() async {
        let current = await notifications.authorizationStatus()
        await MainActor.run { authorization = current }
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    func openSettingsWindow() {
        SettingsWindowController.shared.show(model: self)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        preferences.launchAtLogin = enabled
        loginItem.setEnabled(enabled)
    }

    func sendTestNotification() {
        Task {
            await notifications.sendNow(
                title: L("notification.test.title"),
                body: L("notification.test.body")
            )
        }
    }

    func requestNotificationPermission() {
        Task { await requestAuthorizationIfNeeded() }
    }

    @discardableResult
    func markWaterDone() -> Bool {
        if let dose = preferences.tryLogWaterIntake() {
            toast = ToastMessage(text: LF("toast.water.recorded", dose), tint: .water)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                if toast?.tint == .water {
                    toast = nil
                }
            }
            return true
        } else {
            let remaining = preferences.waterTapRemainingSeconds()
            toast = ToastMessage(text: LF("toast.water.cooldown", remaining), tint: .warning)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if toast?.tint == .warning {
                    toast = nil
                }
            }
            return false
        }
    }

    func startStandBreak() {
        snooze(.stand, minutes: preferences.standIntervalMinutes)
        BreakOverlayController.shared.presentStandBreak(minDurationSeconds: 120) { [weak self] in
            self?.snooze(.stand, minutes: 10)
        }
    }

    func startEyesRest() {
        snooze(.eyes, minutes: preferences.eyesIntervalMinutes)
        BreakOverlayController.shared.presentEyesRest(minDurationSeconds: 20)
    }

    func pauseAll(minutes: Int) {
        let until = Date().addingTimeInterval(TimeInterval(minutes) * 60)
        preferences.pauseUntil = until
    }

    func resumeAll() {
        preferences.pauseUntil = .distantPast
    }

    func snooze(_ type: ReminderType, minutes: Int) {
        let until = Date().addingTimeInterval(TimeInterval(minutes) * 60)
        preferences.snoozeUntilByType[type.rawValue] = until
    }

    private func observeSystemSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.engine?.stop()
            }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.engine?.recalculate()
            }
        }
    }
}

struct ToastMessage: Equatable {
    enum Tint: Equatable {
        case water
        case warning
    }

    let text: String
    let tint: Tint
}
