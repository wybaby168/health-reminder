using HealthReminder.Windows.Models;
using HealthReminder.Windows.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;
using Windows.Foundation;

namespace HealthReminder.Windows.UI;

public sealed partial class SettingsWindow : Window
{
    private readonly AppModel model;

    public SettingsWindow(AppModel model)
    {
        this.model = model;
        InitializeComponent();

        Title = "设置";
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(null);

        LoadFromState();
        HookEvents();
        UpdateWaterUI();
    }

    public void BringToFront()
    {
        var hwnd = Win32InteropHelpers.GetHwnd(this);
        Win32InteropHelpers.BringToFront(hwnd);
    }

    private void LoadFromState()
    {
        var s = model.Preferences.State;
        WaterToggle.IsOn = s.WaterEnabled;
        StandToggle.IsOn = s.StandEnabled;
        EyesToggle.IsOn = s.EyesEnabled;

        WaterInterval.Value = s.WaterIntervalMinutes;
        StandInterval.Value = s.StandIntervalMinutes;
        EyesInterval.Value = s.EyesIntervalMinutes;

        ActiveStart.Time = TimeSpan.FromMinutes(s.ActiveStartMinutes);
        ActiveEnd.Time = TimeSpan.FromMinutes(s.ActiveEndMinutes);

        DailyGoal.Value = s.DailyWaterGoalMl;
        DosePerTap.Value = s.WaterDosePerTapMl;
        TapCooldown.Value = s.WaterTapCooldownSeconds;

        StandOverlayToggle.IsOn = s.StandForceOverlayEnabled;
        EyesOverlayToggle.IsOn = s.EyesForceOverlayEnabled;

        SoundToggle.IsOn = s.SoundEnabled;
        LaunchToggle.IsOn = s.LaunchAtLogin;
    }

    private void HookEvents()
    {
        WaterToggle.Toggled += (_, _) => Save(s => s.WaterEnabled = WaterToggle.IsOn);
        StandToggle.Toggled += (_, _) => Save(s => s.StandEnabled = StandToggle.IsOn);
        EyesToggle.Toggled += (_, _) => Save(s => s.EyesEnabled = EyesToggle.IsOn);

        WaterInterval.ValueChanged += (_, _) => SaveInt(WaterInterval, v => model.Preferences.State.WaterIntervalMinutes = v);
        StandInterval.ValueChanged += (_, _) => SaveInt(StandInterval, v => model.Preferences.State.StandIntervalMinutes = v);
        EyesInterval.ValueChanged += (_, _) => SaveInt(EyesInterval, v => model.Preferences.State.EyesIntervalMinutes = v);

        ActiveStart.TimeChanged += (_, _) => SaveMinutes(ActiveStart, v => model.Preferences.State.ActiveStartMinutes = v);
        ActiveEnd.TimeChanged += (_, _) => SaveMinutes(ActiveEnd, v => model.Preferences.State.ActiveEndMinutes = v);

        DailyGoal.ValueChanged += (_, _) => SaveInt(DailyGoal, v => model.Preferences.State.DailyWaterGoalMl = v);
        DosePerTap.ValueChanged += (_, _) => SaveInt(DosePerTap, v => model.Preferences.State.WaterDosePerTapMl = v);
        TapCooldown.ValueChanged += (_, _) => SaveInt(TapCooldown, v => model.Preferences.State.WaterTapCooldownSeconds = v);

        StandOverlayToggle.Toggled += (_, _) => Save(s => s.StandForceOverlayEnabled = StandOverlayToggle.IsOn);
        EyesOverlayToggle.Toggled += (_, _) => Save(s => s.EyesForceOverlayEnabled = EyesOverlayToggle.IsOn);

        SoundToggle.Toggled += (_, _) => Save(s => s.SoundEnabled = SoundToggle.IsOn);
        LaunchToggle.Toggled += OnLaunchToggle;
    }

    private async void OnLaunchToggle(object sender, RoutedEventArgs e)
    {
        var desired = LaunchToggle.IsOn;
        var ok = await StartupService.TrySetEnabledAsync(desired);
        if (!ok)
        {
            LaunchToggle.IsOn = !desired;
            return;
        }
        Save(s => s.LaunchAtLogin = desired);
    }

    private void Save(Action<PreferencesState> apply)
    {
        apply(model.Preferences.State);
        model.Preferences.Save();
        model.Engine.Recalculate();
        UpdateWaterUI();
    }

    private void SaveInt(NumberBox box, Action<int> apply)
    {
        var value = (int)Math.Round(box.Value);
        apply(value);
        model.Preferences.Save();
        model.Engine.Recalculate();
        UpdateWaterUI();
    }

    private void SaveMinutes(TimePicker picker, Action<int> apply)
    {
        apply((int)picker.Time.TotalMinutes);
        model.Preferences.Save();
        model.Engine.Recalculate();
    }

    private void UpdateWaterUI()
    {
        var now = DateTimeOffset.Now;
        model.Preferences.RefreshDaily(now);
        var s = model.Preferences.State;
        var remaining = model.Preferences.WaterRemainingCooldownSeconds(now);
        WaterProgress.Text = $"今日已喝 {s.WaterConsumedTodayMl}/{s.DailyWaterGoalMl} ml" + (remaining > 0 ? $" · {remaining}s" : "");
        LogWaterButton.IsEnabled = model.Preferences.CanLogWater(now);
    }

    private void OnLogWater(object sender, RoutedEventArgs e)
    {
        if (model.TryLogWater(out _))
        {
            model.Snooze(ReminderType.Water, model.Preferences.State.WaterIntervalMinutes);
        }
        UpdateWaterUI();
    }

    private void OnStartStand(object sender, RoutedEventArgs e)
    {
        model.Snooze(ReminderType.Stand, model.Preferences.State.StandIntervalMinutes);
        model.Overlay.ShowStand(minSeconds: 120, maxSeconds: 5 * 60);
    }

    private void OnStartEyes(object sender, RoutedEventArgs e)
    {
        model.Snooze(ReminderType.Eyes, model.Preferences.State.EyesIntervalMinutes);
        model.Overlay.ShowEyes(minSeconds: 20, maxSeconds: 5 * 60);
    }

    private void OnTestToast(object sender, RoutedEventArgs e)
    {
        ToastNotificationService.ShowReminderToast(ReminderType.Water, "健康提醒测试", "如果你看到了这条通知，说明通知机制工作正常。", model.Preferences.State.SoundEnabled);
    }

    private void OnReset(object sender, RoutedEventArgs e)
    {
        model.Preferences.State = new PreferencesState();
        model.Preferences.Save();
        LoadFromState();
        model.Engine.Recalculate();
        UpdateWaterUI();
    }
}
