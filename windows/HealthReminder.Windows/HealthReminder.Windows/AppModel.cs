using HealthReminder.Windows.Models;
using HealthReminder.Windows.Services;
using System;

namespace HealthReminder.Windows;

public sealed class AppModel
{
    public PreferencesStore Preferences { get; } = new();
    public ReminderEngine Engine { get; }
    public OverlayService Overlay { get; }

    public AppModel()
    {
        Overlay = new OverlayService(this);
        Engine = new ReminderEngine(this);
    }

    public void Start()
    {
        Preferences.Load();
        LanguageService.ApplyPreference(Preferences.State.LanguagePreference);
        Engine.Start();
    }

    public void Stop()
    {
        Engine.Stop();
        Preferences.Save();
    }

    public void PauseAll(int minutes)
    {
        Preferences.State.PauseUntil = DateTimeOffset.Now.AddMinutes(minutes);
        Preferences.Save();
        Engine.Recalculate();
    }

    public void ResumeAll()
    {
        Preferences.State.PauseUntil = DateTimeOffset.MinValue;
        Preferences.Save();
        Engine.Recalculate();
    }

    public void Snooze(ReminderType type, int minutes)
    {
        Preferences.State.SnoozeUntilByType[type] = DateTimeOffset.Now.AddMinutes(minutes);
        Preferences.Save();
        Engine.Recalculate();
    }

    public bool TryLogWater(out int dose)
    {
        dose = 0;
        var now = DateTimeOffset.Now;
        Preferences.RefreshDaily(now);
        if (!Preferences.CanLogWater(now))
        {
            return false;
        }

        dose = Preferences.WaterDosePerTap;
        Preferences.State.WaterConsumedTodayMl = Math.Min(Preferences.State.DailyWaterGoalMl, Preferences.State.WaterConsumedTodayMl + dose);
        Preferences.State.LastWaterTapAt = now;
        Preferences.Save();
        return true;
    }
}
