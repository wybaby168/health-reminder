using HealthReminder.Windows.Models;
using Microsoft.UI.Dispatching;
using System;
using System.Collections.Generic;

namespace HealthReminder.Windows.Services;

public sealed class ReminderEngine
{
    private readonly AppModel model;
    private readonly DispatcherQueue dispatcher;
    private readonly DispatcherQueueTimer timer;

    public Dictionary<ReminderType, DateTimeOffset> NextTriggerByType { get; } = new();

    public ReminderEngine(AppModel model)
    {
        this.model = model;
        dispatcher = DispatcherQueue.GetForCurrentThread();
        timer = dispatcher.CreateTimer();
        timer.Interval = TimeSpan.FromSeconds(1);
        timer.Tick += (_, _) => Tick();
    }

    public void Start()
    {
        foreach (var t in Enum.GetValues<ReminderType>())
        {
            NextTriggerByType[t] = DateTimeOffset.MinValue;
        }
        Recalculate();
        timer.Start();
    }

    public void Stop()
    {
        timer.Stop();
    }

    public void Recalculate()
    {
        var now = DateTimeOffset.Now;
        var prefs = model.Preferences;
        prefs.RefreshDaily(now);

        foreach (var type in Enum.GetValues<ReminderType>())
        {
            NextTriggerByType[type] = ComputeNext(type, now);
        }
    }

    private void Tick()
    {
        var now = DateTimeOffset.Now;
        var prefs = model.Preferences.State;
        if (prefs.PauseUntil > now)
        {
            return;
        }

        foreach (var type in Enum.GetValues<ReminderType>())
        {
            var next = NextTriggerByType[type];
            if (next != DateTimeOffset.MinValue && next <= now)
            {
                Fire(type);
                return;
            }
        }
    }

    private void Fire(ReminderType type)
    {
        var now = DateTimeOffset.Now;
        var state = model.Preferences.State;
        if (state.PauseUntil > now)
        {
            Recalculate();
            return;
        }

        if (!model.Preferences.IsWithinActiveHours(now))
        {
            Recalculate();
            return;
        }

        var snoozeUntil = state.SnoozeUntilByType.TryGetValue(type, out var s) ? s : DateTimeOffset.MinValue;
        if (snoozeUntil > now)
        {
            Recalculate();
            return;
        }

        var content = BuildReminder(type);
        ToastNotificationService.ShowReminderToast(type, content.title, content.body, state.SoundEnabled);

        if (type == ReminderType.Stand && state.StandForceOverlayEnabled)
        {
            model.Overlay.ShowStand(minSeconds: 120, maxSeconds: 5 * 60);
        }
        if (type == ReminderType.Eyes && state.EyesForceOverlayEnabled)
        {
            model.Overlay.ShowEyes(minSeconds: 20, maxSeconds: 5 * 60);
        }

        NextTriggerByType[type] = now.AddMinutes(IntervalMinutes(type));
        state.SnoozeUntilByType[type] = DateTimeOffset.MinValue;
        model.Preferences.Save();
    }

    private DateTimeOffset ComputeNext(ReminderType type, DateTimeOffset now)
    {
        var s = model.Preferences.State;
        if (s.PauseUntil > now)
        {
            return s.PauseUntil;
        }

        var enabled = type switch
        {
            ReminderType.Water => s.WaterEnabled,
            ReminderType.Stand => s.StandEnabled,
            ReminderType.Eyes => s.EyesEnabled,
            _ => true
        };

        if (!enabled)
        {
            return DateTimeOffset.MinValue;
        }

        var next = now.AddMinutes(IntervalMinutes(type));
        if (!model.Preferences.IsWithinActiveHours(next))
        {
            next = model.Preferences.NextActiveStart(next);
        }

        if (s.SnoozeUntilByType.TryGetValue(type, out var snooze) && snooze > next)
        {
            next = snooze;
        }
        return next;
    }

    private int IntervalMinutes(ReminderType type)
    {
        var s = model.Preferences.State;
        return type switch
        {
            ReminderType.Water => Math.Clamp(s.WaterIntervalMinutes, 15, 180),
            ReminderType.Stand => Math.Clamp(s.StandIntervalMinutes, 20, 120),
            ReminderType.Eyes => Math.Clamp(s.EyesIntervalMinutes, 10, 60),
            _ => 60
        };
    }

    private (string title, string body) BuildReminder(ReminderType type)
    {
        var s = model.Preferences.State;
        return type switch
        {
            ReminderType.Water => (Localizer.Get("Toast_WaterTitle"), string.Format(Localizer.Get("Toast_WaterBody"), Math.Clamp(s.WaterDosePerTapMl, 80, 400))),
            ReminderType.Stand => (Localizer.Get("Toast_StandTitle"), Localizer.Get("Toast_StandBody")),
            ReminderType.Eyes => (Localizer.Get("Toast_EyesTitle"), Localizer.Get("Toast_EyesBody")),
            _ => (Localizer.Get("AppTitle"), "")
        };
    }
}
