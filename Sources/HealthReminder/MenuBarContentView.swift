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
                    Text("健康提醒")
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
            .help("发送测试通知")
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
                        Text("当前不是 .app 进程")
                            .font(.subheadline.weight(.semibold))
                        Text("通知与开机启动需要以打包后的应用运行。")
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
                        Text("开启通知，才能按时提醒")
                            .font(.subheadline.weight(.semibold))
                        Text(model.authorization == .denied ? "你已拒绝通知，请在系统设置中开启。" : "点击按钮请求通知权限。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.authorization == .denied {
                        Button("系统设置") { model.openSystemNotificationSettings() }
                            .buttonStyle(.bordered)
                    } else {
                        Button("立即开启") { model.requestNotificationPermission() }
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
            return "已暂停至 \(DateText.time(model.preferences.pauseUntil))"
        }
        switch model.authorization {
        case .authorized:
            return "通知已启用"
        case .denied:
            return "通知被禁用（点击设置开启）"
        case .notDetermined:
            return "等待通知授权"
        case .unknown:
            return "通知状态未知"
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
                    Button("恢复") { model.resumeAll() }
                } else {
                    Button("暂停 60 分钟") { model.pauseAll(minutes: 60) }
                }
                Button("打开设置") {
                    model.openSettingsWindow()
                }
            }
            HStack(spacing: 8) {
                Button("退出") {
                    NSApp.terminate(nil)
                }
                .foregroundStyle(.red)
                Spacer()
                if model.authorization == .denied {
                    Button("系统通知设置") { model.openSystemNotificationSettings() }
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
                Text(type.displayName)
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
                Label("稍后", systemImage: "clock")
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
        if !isEnabled { return "已关闭" }
        if model.preferences.pauseUntil > Date() { return "已暂停" }
        if let snooze = model.preferences.snoozeUntilByType[type.rawValue], snooze > Date() {
            return "已延后至 \(DateText.time(snooze))"
        }
        guard let next = model.nextTriggerByType[type] else { return "未计划" }
        if type == .water {
            let remaining = model.preferences.waterTapRemainingSeconds(now: now)
            let gate = remaining > 0 ? "  ·  \(remaining)s" : ""
            return "下次：\(DateText.time(next))  ·  今日 \(model.preferences.waterConsumedTodayMl)/\(model.preferences.dailyWaterGoalMl) ml\(gate)"
        }
        return "下次：\(DateText.time(next))"
    }

    private var waterButtonTitle: String {
        let remaining = model.preferences.waterTapRemainingSeconds(now: now)
        if remaining > 0 { return "已记录" }
        return "已喝"
    }

    private var waterButtonSymbol: String {
        let remaining = model.preferences.waterTapRemainingSeconds(now: now)
        if remaining > 0 { return "hourglass" }
        return "checkmark"
    }
}
