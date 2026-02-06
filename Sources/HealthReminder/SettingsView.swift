import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingResetAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            permissionBanner
            Form {
                Section("提醒项目") {
                    Toggle(isOn: $model.preferences.waterEnabled) {
                        Label("喝水提醒", systemImage: "drop.fill")
                    }
                    Toggle(isOn: $model.preferences.standEnabled) {
                        Label("站立提醒", systemImage: "figure.stand")
                    }
                    Toggle(isOn: $model.preferences.eyesEnabled) {
                        Label("放松眼睛提醒", systemImage: "eye.fill")
                    }
                }

                Section("推荐默认（可自行调整）") {
                    Stepper(value: $model.preferences.waterIntervalMinutes, in: 15...180, step: 5) {
                        HStack {
                            Text("喝水间隔")
                            Spacer()
                            Text("\(model.preferences.waterIntervalMinutes) 分钟")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $model.preferences.standIntervalMinutes, in: 20...120, step: 5) {
                        HStack {
                            Text("站立间隔")
                            Spacer()
                            Text("\(model.preferences.standIntervalMinutes) 分钟")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $model.preferences.eyesIntervalMinutes, in: 10...60, step: 5) {
                        HStack {
                            Text("眼睛休息间隔")
                            Spacer()
                            Text("\(model.preferences.eyesIntervalMinutes) 分钟")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("强制休息") {
                    Toggle(isOn: $model.preferences.standForceOverlayEnabled) {
                        Label("站立时全屏遮罩（至少 2 分钟）", systemImage: "rectangle.inset.filled.and.person.filled")
                    }
                    Toggle(isOn: $model.preferences.eyesForceOverlayEnabled) {
                        Label("护眼时黑屏休息（至少 20 秒）", systemImage: "moon.fill")
                    }

                    HStack(spacing: 10) {
                        Button {
                            model.startStandBreak()
                        } label: {
                            Label("立即开始站立", systemImage: "figure.stand")
                        }
                        Button {
                            model.startEyesRest()
                        } label: {
                            Label("立即开始护眼", systemImage: "eye.slash")
                        }
                        Spacer()
                    }
                }

                Section("活跃时段") {
                    ActiveHoursPicker(
                        startMinutes: $model.preferences.activeStartMinutes,
                        endMinutes: $model.preferences.activeEndMinutes
                    )
                }

                Section("喝水用量") {
                    Stepper(value: $model.preferences.dailyWaterGoalMl, in: 1200...4000, step: 100) {
                        HStack {
                            Text("每日目标")
                            Spacer()
                            Text("\(model.preferences.dailyWaterGoalMl) ml")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $model.preferences.waterDosePerTapMl, in: 80...400, step: 20) {
                        HStack {
                            Text("每次记录")
                            Spacer()
                            Text("\(model.preferences.waterDosePerTapMl) ml")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $model.preferences.waterTapCooldownSeconds, in: 30...600, step: 30) {
                        HStack {
                            Text("防连点间隔")
                            Spacer()
                            Text("\(model.preferences.waterTapCooldownSeconds) 秒")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("建议每次")
                        Spacer()
                        Text("约 \(model.preferences.suggestedWaterDoseMl()) ml")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("今日已喝")
                        Spacer()
                        Text("\(model.preferences.waterConsumedTodayMl) ml")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if model.markWaterDone() {
                                model.snooze(.water, minutes: model.preferences.waterIntervalMinutes)
                            }
                        } label: {
                            Label("我已喝完一杯", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.40, green: 0.70, blue: 1.0))
                        .disabled(!model.preferences.canLogWaterNow())
                        Spacer()
                    }
                }

                Section("系统") {
                    Toggle("通知声音", isOn: $model.preferences.soundEnabled)
                    Toggle("开机启动", isOn: Binding(
                        get: { model.preferences.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))

                    HStack {
                        Text("通知权限")
                        Spacer()
                        Text(authorizationText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("发送测试通知") { model.sendTestNotification() }
                        Spacer()
                        Button("打开系统通知设置") { model.openSystemNotificationSettings() }
                    }
                }
            }
            .formStyle(.grouped)
            footer
        }
        .padding(16)
        .task {
            await model.refreshAuthorization()
            model.setLaunchAtLogin(model.preferences.launchAtLogin)
        }
        .alert("恢复默认设置？", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("恢复默认", role: .destructive) {
                model.preferences.resetToDefaults()
            }
        } message: {
            Text("将恢复到健康最佳实践的推荐默认值，你仍可随时再调整。")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("设置")
                    .font(.largeTitle.weight(.semibold))
                Text("默认参考：分次补水、久坐不超过 30–60 分钟、20-20-20 规则。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("恢复默认") {
                showingResetAlert = true
            }
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !model.notificationClientAvailable {
            bannerContainer {
                Label("请用打包后的 .app 运行，才能显示通知图标并正常提醒。", systemImage: "shippingbox.fill")
                    .foregroundStyle(.secondary)
            }
        } else if model.authorization != .authorized {
            bannerContainer {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("通知权限未开启")
                            .font(.headline)
                        Text(model.authorization == .denied ? "你已拒绝通知，请到系统设置中开启。" : "点击按钮请求通知权限。")
                            .font(.callout)
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
            .padding(12)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("小贴士")
                .font(.headline)
            Text("喝水：多数成年人建议 1.5–2.5L/天，按口渴与尿色调整；运动/高温/咖啡因需额外补水。")
            Text("站立：每 30–60 分钟起身走动能降低久坐相关风险；可顺便做肩颈与小腿拉伸。")
            Text("眼睛：20-20-20 有助缓解屏幕用眼疲劳；别忘了眨眼与调整屏幕亮度。")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private var authorizationText: String {
        switch model.authorization {
        case .authorized:
            return "已允许"
        case .denied:
            return "已拒绝"
        case .notDetermined:
            return "未选择"
        case .unknown:
            return "未知"
        }
    }
}

private struct ActiveHoursPicker: View {
    @Binding var startMinutes: Int
    @Binding var endMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("当前时段")
                Spacer()
                Text(summaryText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Text("开始")
                Spacer()
                DatePicker("", selection: startDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: 160, alignment: .trailing)
            }
            HStack {
                Text("结束")
                Spacer()
                DatePicker("", selection: endDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: 160, alignment: .trailing)
            }
            HStack(spacing: 8) {
                Button("全天") { setAllDay() }
                Button("工作日") { setRange(start: 9 * 60, end: 18 * 60) }
                Button("日间") { setRange(start: 9 * 60, end: 21 * 60) }
                Button("夜间") { setRange(start: 22 * 60, end: 6 * 60) }
                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("仅在活跃时段内发送提醒，结束早于开始表示跨夜。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var startDate: Binding<Date> {
        Binding(
            get: { dateFromMinutes(startMinutes) },
            set: { startMinutes = minutesFromDate($0) }
        )
    }

    private var endDate: Binding<Date> {
        Binding(
            get: { dateFromMinutes(endMinutes) },
            set: { endMinutes = minutesFromDate($0) }
        )
    }

    private var summaryText: String {
        if startMinutes == endMinutes {
            return "全天 · 24 小时"
        }
        var text = "\(timeText(startMinutes))–\(timeText(endMinutes)) · \(durationText(activeDurationMinutes))"
        if startMinutes > endMinutes {
            text += " · 跨夜"
        }
        return text
    }

    private var activeDurationMinutes: Int {
        if startMinutes == endMinutes { return 24 * 60 }
        if startMinutes < endMinutes { return endMinutes - startMinutes }
        return (24 * 60 - startMinutes) + endMinutes
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remain = minutes % 60
        if remain == 0 { return "\(hours) 小时" }
        if hours == 0 { return "\(remain) 分钟" }
        return "\(hours) 小时 \(remain) 分钟"
    }

    private func timeText(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let base = Calendar.current.startOfDay(for: Date())
        let clamped = (minutes % (24 * 60) + (24 * 60)) % (24 * 60)
        return Calendar.current.date(byAdding: .minute, value: clamped, to: base) ?? base
    }

    private func minutesFromDate(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private func setAllDay() {
        endMinutes = startMinutes
    }

    private func setRange(start: Int, end: Int) {
        startMinutes = start
        endMinutes = end
    }
}
