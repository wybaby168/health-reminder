import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingResetAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            permissionBanner
            Form {
                Section {
                    Toggle(isOn: $model.preferences.waterEnabled) {
                        Label(L("settings.toggle.water"), systemImage: "drop.fill")
                    }
                    Toggle(isOn: $model.preferences.standEnabled) {
                        Label(L("settings.toggle.stand"), systemImage: "figure.stand")
                    }
                    Toggle(isOn: $model.preferences.eyesEnabled) {
                        Label(L("settings.toggle.eyes"), systemImage: "eye.fill")
                    }
                } header: {
                    Text(L("settings.section.reminders"))
                }

                Section {
                    Stepper(value: $model.preferences.waterIntervalMinutes, in: 15...180, step: 5) {
                        HStack {
                            Text(L("settings.stepper.waterInterval"))
                            Spacer()
                            Text(LF("settings.unit.minutes", String(model.preferences.waterIntervalMinutes)))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $model.preferences.standIntervalMinutes, in: 20...120, step: 5) {
                        HStack {
                            Text(L("settings.stepper.standInterval"))
                            Spacer()
                            Text(LF("settings.unit.minutes", String(model.preferences.standIntervalMinutes)))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $model.preferences.eyesIntervalMinutes, in: 10...60, step: 5) {
                        HStack {
                            Text(L("settings.stepper.eyesInterval"))
                            Spacer()
                            Text(LF("settings.unit.minutes", String(model.preferences.eyesIntervalMinutes)))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(L("settings.section.defaults"))
                }

                Section {
                    Toggle(isOn: $model.preferences.standForceOverlayEnabled) {
                        Label(L("settings.toggle.forceStand"), systemImage: "rectangle.inset.filled.and.person.filled")
                    }
                    Toggle(isOn: $model.preferences.eyesForceOverlayEnabled) {
                        Label(L("settings.toggle.forceEyes"), systemImage: "moon.fill")
                    }

                    HStack(spacing: 10) {
                        Button {
                            model.startStandBreak()
                        } label: {
                            Label(L("settings.button.startStand"), systemImage: "figure.stand")
                        }
                        Button {
                            model.startEyesRest()
                        } label: {
                            Label(L("settings.button.startEyes"), systemImage: "eye.slash")
                        }
                        Spacer()
                    }
                } header: {
                    Text(L("settings.section.force"))
                }

                Section {
                    ActiveHoursPicker(
                        startMinutes: $model.preferences.activeStartMinutes,
                        endMinutes: $model.preferences.activeEndMinutes
                    )
                } header: {
                    Text(L("settings.section.activeHours"))
                }

                Section {
                    Stepper(value: $model.preferences.dailyWaterGoalMl, in: 1200...4000, step: 100) {
                        HStack {
                            Text(L("settings.water.goal"))
                            Spacer()
                            Text(LF("settings.unit.ml", String(model.preferences.dailyWaterGoalMl)))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $model.preferences.waterDosePerTapMl, in: 80...400, step: 20) {
                        HStack {
                            Text(L("settings.water.dose"))
                            Spacer()
                            Text(LF("settings.unit.ml", String(model.preferences.waterDosePerTapMl)))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $model.preferences.waterTapCooldownSeconds, in: 30...600, step: 30) {
                        HStack {
                            Text(L("settings.water.cooldown"))
                            Spacer()
                            Text(LF("settings.unit.seconds", String(model.preferences.waterTapCooldownSeconds)))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text(L("settings.water.suggested"))
                        Spacer()
                        Text(LF("settings.unit.ml", String(model.preferences.suggestedWaterDoseMl())))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(L("settings.water.today"))
                        Spacer()
                        Text(LF("settings.unit.ml", String(model.preferences.waterConsumedTodayMl)))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if model.markWaterDone() {
                                model.snooze(.water, minutes: model.preferences.waterIntervalMinutes)
                            }
                        } label: {
                            Label(L("settings.water.button.log"), systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.40, green: 0.70, blue: 1.0))
                        .disabled(!model.preferences.canLogWaterNow())
                        Spacer()
                    }
                } header: {
                    Text(L("settings.section.water"))
                }

                Section {
                    Toggle(L("settings.system.sound"), isOn: $model.preferences.soundEnabled)
                    Toggle(L("settings.system.launchAtLogin"), isOn: Binding(
                        get: { model.preferences.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))

                    HStack {
                        Text(L("settings.system.permission"))
                        Spacer()
                        Text(authorizationText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button(L("settings.system.sendTest")) { model.sendTestNotification() }
                        Spacer()
                        Button(L("settings.system.openNotificationSettings")) { model.openSystemNotificationSettings() }
                    }
                } header: {
                    Text(L("settings.section.system"))
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
        .alert(L("settings.reset.alert.title"), isPresented: $showingResetAlert) {
            Button(L("settings.reset.alert.cancel"), role: .cancel) {}
            Button(L("settings.reset.alert.confirm"), role: .destructive) {
                model.preferences.resetToDefaults()
            }
        } message: {
            Text(L("settings.reset.alert.message"))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.title"))
                    .font(.largeTitle.weight(.semibold))
                Text(L("settings.header.subtitle"))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L("settings.reset")) {
                showingResetAlert = true
            }
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !model.notificationClientAvailable {
            bannerContainer {
                Label(L("settings.permission.notApp"), systemImage: "shippingbox.fill")
                    .foregroundStyle(.secondary)
            }
        } else if model.authorization != .authorized {
            bannerContainer {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("settings.permission.notGranted.title"))
                            .font(.headline)
                        Text(model.authorization == .denied ? L("settings.permission.notGranted.body.denied") : L("settings.permission.notGranted.body.request"))
                            .font(.callout)
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
            .padding(12)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("tips.title"))
                .font(.headline)
            Text(L("tips.water"))
            Text(L("tips.stand"))
            Text(L("tips.eyes"))
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private var authorizationText: String {
        switch model.authorization {
        case .authorized:
            return L("settings.system.permission.authorized")
        case .denied:
            return L("settings.system.permission.denied")
        case .notDetermined:
            return L("settings.system.permission.notDetermined")
        case .unknown:
            return L("settings.system.permission.unknown")
        }
    }
}

private struct ActiveHoursPicker: View {
    @Binding var startMinutes: Int
    @Binding var endMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("settings.active.current"))
                Spacer()
                Text(summaryText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Text(L("settings.active.start"))
                Spacer()
                DatePicker("", selection: startDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: 160, alignment: .trailing)
            }
            HStack {
                Text(L("settings.active.end"))
                Spacer()
                DatePicker("", selection: endDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: 160, alignment: .trailing)
            }
            HStack(spacing: 8) {
                Button(L("settings.active.preset.allDay")) { setAllDay() }
                Button(L("settings.active.preset.workday")) { setRange(start: 9 * 60, end: 18 * 60) }
                Button(L("settings.active.preset.daytime")) { setRange(start: 9 * 60, end: 21 * 60) }
                Button(L("settings.active.preset.night")) { setRange(start: 22 * 60, end: 6 * 60) }
                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(L("settings.active.hint"))
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
            return L("settings.active.summary.allDay")
        }
        var text = LF("settings.active.summary.format", "\(timeText(startMinutes))–\(timeText(endMinutes))", durationText(activeDurationMinutes))
        if startMinutes > endMinutes {
            text += " · " + L("settings.active.summary.overnight")
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
        if remain == 0 { return LF("settings.duration.hours", hours) }
        if hours == 0 { return LF("settings.duration.minutes", remain) }
        return LF("settings.duration.hoursMinutes", hours, remain)
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
