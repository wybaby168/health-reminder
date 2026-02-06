using CommunityToolkit.WinUI.Notifications;
using HealthReminder.Windows.Models;
using System;

namespace HealthReminder.Windows.Services;

public static class ToastNotificationService
{
    private static AppModel? model;
    private static bool initialized;

    public static void Initialize(AppModel appModel)
    {
        if (initialized)
        {
            model = appModel;
            return;
        }

        model = appModel;
        initialized = true;

        ToastNotificationManagerCompat.OnActivated += toastArgs =>
        {
            var args = ToastArguments.Parse(toastArgs.Argument);
            var action = args.TryGetValue("action", out var a) ? a : "";
            var type = args.TryGetValue("type", out var t) ? t : "";
            Handle(action, type);
        };
    }

    public static void ShowReminderToast(ReminderType type, string title, string body, bool soundEnabled)
    {
        var icon = new Uri("ms-appx:///Assets/AppIcon.png");
        var builder = new ToastContentBuilder()
            .AddAppLogoOverride(icon, ToastGenericAppLogoCrop.Circle)
            .AddText(title)
            .AddText(body)
            .AddArgument("type", type.ToString().ToLowerInvariant());

        builder.AddButton(new ToastButton()
            .SetContent(type == ReminderType.Water ? "我已喝完" : type == ReminderType.Stand ? "开始 2 分钟站立" : "开始护眼休息")
            .AddArgument("action", type == ReminderType.Water ? "water_done" : type == ReminderType.Stand ? "start_stand" : "start_eyes")
            .AddArgument("type", type.ToString().ToLowerInvariant())
            .SetBackgroundActivation());

        builder.AddButton(new ToastButton()
            .SetContent("稍后 10 分钟")
            .AddArgument("action", "snooze10")
            .AddArgument("type", type.ToString().ToLowerInvariant())
            .SetBackgroundActivation());

        builder.AddButton(new ToastButton()
            .SetContent("打开设置")
            .AddArgument("action", "settings")
            .SetBackgroundActivation());

        if (!soundEnabled)
        {
            builder.AddAudio(new ToastAudio { Silent = true });
        }

        builder.Show();
    }

    private static void Handle(string action, string typeRaw)
    {
        if (model == null)
        {
            return;
        }

        if (string.Equals(action, "settings", StringComparison.OrdinalIgnoreCase))
        {
            App.RequestOpenSettings();
            return;
        }

        var type = ParseType(typeRaw);
        if (type == null)
        {
            return;
        }

        switch (action)
        {
            case "water_done":
                if (model.TryLogWater(out _))
                {
                    model.Snooze(ReminderType.Water, model.Preferences.State.WaterIntervalMinutes);
                }
                break;
            case "start_stand":
                model.Snooze(ReminderType.Stand, model.Preferences.State.StandIntervalMinutes);
                model.Overlay.ShowStand(minSeconds: 120, maxSeconds: 5 * 60);
                break;
            case "start_eyes":
                model.Snooze(ReminderType.Eyes, model.Preferences.State.EyesIntervalMinutes);
                model.Overlay.ShowEyes(minSeconds: 20, maxSeconds: 5 * 60);
                break;
            case "snooze10":
                model.Snooze(type.Value, 10);
                break;
        }
    }

    private static ReminderType? ParseType(string raw)
    {
        return raw switch
        {
            "water" => ReminderType.Water,
            "stand" => ReminderType.Stand,
            "eyes" => ReminderType.Eyes,
            _ => null
        };
    }
}
