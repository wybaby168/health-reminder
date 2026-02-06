using System;
using System.Collections.Generic;

namespace HealthReminder.Windows.Models;

public sealed class PreferencesState
{
    public bool WaterEnabled { get; set; } = true;
    public bool StandEnabled { get; set; } = true;
    public bool EyesEnabled { get; set; } = true;

    public int WaterIntervalMinutes { get; set; } = 60;
    public int StandIntervalMinutes { get; set; } = 30;
    public int EyesIntervalMinutes { get; set; } = 20;

    public int ActiveStartMinutes { get; set; } = 9 * 60;
    public int ActiveEndMinutes { get; set; } = 21 * 60;

    public int DailyWaterGoalMl { get; set; } = 2000;
    public int WaterDosePerTapMl { get; set; } = 200;
    public int WaterTapCooldownSeconds { get; set; } = 120;

    public int WaterConsumedTodayMl { get; set; } = 0;
    public string DailyStamp { get; set; } = "";
    public DateTimeOffset LastWaterTapAt { get; set; } = DateTimeOffset.MinValue;

    public bool SoundEnabled { get; set; } = true;
    public bool StandForceOverlayEnabled { get; set; } = true;
    public bool EyesForceOverlayEnabled { get; set; } = true;

    public bool LaunchAtLogin { get; set; } = false;

    public DateTimeOffset PauseUntil { get; set; } = DateTimeOffset.MinValue;

    public Dictionary<ReminderType, DateTimeOffset> SnoozeUntilByType { get; set; } = new();
}

