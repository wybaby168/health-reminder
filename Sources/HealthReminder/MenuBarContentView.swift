import Combine
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel

    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            permissionBanner
            toastBanner
            statusCards
            actions
        }
        .padding(12)
        .onAppear {
            Task { await model.refreshAuthorization() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsWindow)) { _ in
            model.openSettingsWindow()
        }
        .onReceive(clock) { t in
            now = t
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "alarm.fill")
                        .foregroundStyle(Color(red: 0.35, green: 0.86, blue: 0.73))
                    Text("app.title")
                        .font(.headline)
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.sendTestNotification()
            } label: {
                Image(systemName: "paperplane")
            }
            .buttonStyle(.borderless)
            .help(L("app.menu.help.sendTest"))
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !model.notificationClientAvailable {
            bannerContainer {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("banner.notApp.title")
                            .font(.subheadline.weight(.semibold))
                        Text("banner.notApp.body")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        } else if model.authorization != .authorized {
            bannerContainer {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("banner.permission.title")
                            .font(.subheadline.weight(.semibold))
                        Text(model.authorization == .denied ? L("banner.permission.body.denied") : L("banner.permission.body.request"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.authorization == .denied {
                        Button(L("banner.permission.button.settings")) { model.openSystemNotificationSettings() }
                            .buttonStyle(.bordered)
                    } else {
                        Button(L("banner.permission.button.enable")) { model.requestNotificationPermission() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.35, green: 0.86, blue: 0.73))
                    }
                }
            }
        }
    }

    private func bannerContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(10)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var subtitle: String {
        if model.preferences.pauseUntil > Date() {
            return LF("menu.subtitle.pausedUntil", DateText.time(model.preferences.pauseUntil))
        }
        switch model.authorization {
        case .authorized:
            return L("menu.subtitle.authorized")
        case .denied:
            return L("menu.subtitle.denied")
        case .notDetermined:
            return L("menu.subtitle.notDetermined")
        case .unknown:
            return L("menu.subtitle.unknown")
        }
    }

    private var statusCards: some View {
        VStack(spacing: 8) {
            ForEach(ReminderType.allCases) { type in
                ReminderStatusRow(type: type, now: now)
            }
        }
    }

    private var toastBanner: some View {
        Group {
            if let toast = model.toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.tint == .water ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundStyle(toastColor(toast.tint))
                    Text(toast.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(toastColor(toast.tint).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func toastColor(_ tint: ToastMessage.Tint) -> Color {
        switch tint {
        case .water:
            return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .warning:
            return .orange
        }
    }


    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if model.preferences.pauseUntil > Date() {
                    Button(L("button.resume")) { model.resumeAll() }
                } else {
                    Button(L("button.pause60")) { model.pauseAll(minutes: 60) }
                }
                Button(L("button.openSettings")) {
                    model.openSettingsWindow()
                }
            }
            HStack(spacing: 8) {
                Button(L("button.quit")) {
                    NSApp.terminate(nil)
                }
                .foregroundStyle(.red)
                Spacer()
                if model.authorization == .denied {
                    Button(L("button.systemNotificationSettings")) { model.openSystemNotificationSettings() }
                }
            }
        }
        .buttonStyle(.bordered)
    }
}

private struct ReminderStatusRow: View {
    @EnvironmentObject private var model: AppModel
    let type: ReminderType
    let now: Date

    var body: some View {
        HStack {
            Image(systemName: type.systemImageName)
                .foregroundStyle(iconTint)
                .font(.system(size: 16))
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(type.titleKey))
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if type == .water {
                    ProgressView(value: waterProgress)
                        .progressViewStyle(.linear)
                        .tint(iconTint)
                }
            }
            Spacer()
            if type == .water {
                Button {
                    if model.markWaterDone() {
                        model.snooze(type, minutes: model.preferences.waterIntervalMinutes)
                    }
                } label: {
                    Label(waterButtonTitle, systemImage: waterButtonSymbol)
                }
                .buttonStyle(.borderless)
                .disabled(!isEnabled || !model.preferences.canLogWaterNow(now: now))
            }
            Button {
                model.snooze(type, minutes: 10)
            } label: {
                Label(L("action.later"), systemImage: "clock")
            }
            .buttonStyle(.borderless)
            .disabled(!isEnabled)
        }
        .padding(10)
        .background(backgroundTint)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var iconTint: Color {
        switch type {
        case .water:
            return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .stand:
            return Color(red: 0.35, green: 0.86, blue: 0.73)
        case .eyes:
            return Color(red: 0.62, green: 0.68, blue: 1.0)
        }
    }

    private var backgroundTint: Color {
        iconTint.opacity(0.10)
    }

    private var waterProgress: Double {
        let goal = max(1, model.preferences.dailyWaterGoalMl)
        let consumed = max(0, model.preferences.waterConsumedTodayMl)
        return min(1.0, Double(consumed) / Double(goal))
    }

    private var isEnabled: Bool {
        switch type {
        case .water: return model.preferences.waterEnabled
        case .stand: return model.preferences.standEnabled
        case .eyes: return model.preferences.eyesEnabled
        }
    }

    private var detail: String {
        if !isEnabled { return L("status.off") }
        if model.preferences.pauseUntil > Date() { return L("status.paused") }
        if let snooze = model.preferences.snoozeUntilByType[type.rawValue], snooze > Date() {
            return LF("status.snoozedUntil", DateText.time(snooze))
        }
        guard let next = model.nextTriggerByType[type] else { return L("status.unscheduled") }
        if type == .water {
            let remaining = model.preferences.waterTapRemainingSeconds(now: now)
            let gate = remaining > 0 ? LF("status.cooldownSuffix", remaining) : ""
            return LF(
                "status.nextWater",
                DateText.time(next),
                String(model.preferences.waterConsumedTodayMl),
                String(model.preferences.dailyWaterGoalMl),
                gate
            )
        }
        return LF("status.next", DateText.time(next))
    }

    private var waterButtonTitle: String {
        let remaining = model.preferences.waterTapRemainingSeconds(now: now)
        if remaining > 0 { return L("action.water.recorded") }
        return L("action.water.done")
    }

    private var waterButtonSymbol: String {
        let remaining = model.preferences.waterTapRemainingSeconds(now: now)
        if remaining > 0 { return "hourglass" }
        return "checkmark"
    }
}
