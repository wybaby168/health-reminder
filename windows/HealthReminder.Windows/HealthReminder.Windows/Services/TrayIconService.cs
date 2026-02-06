using HealthReminder.Windows.Models;
using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using HealthReminder.Windows.Services;

namespace HealthReminder.Windows.Services;

public sealed class TrayIconService
{
    private readonly AppModel model;
    private readonly Action openSettings;
    private readonly Action exit;

    private NotifyIcon? notifyIcon;
    private ContextMenuStrip? menu;

    private ToolStripMenuItem? waterStatus;
    private ToolStripMenuItem? standStatus;
    private ToolStripMenuItem? eyesStatus;
    private ToolStripMenuItem? waterDone;
    private ToolStripMenuItem? waterSnooze;
    private ToolStripMenuItem? standSnooze;
    private ToolStripMenuItem? eyesSnooze;

    public TrayIconService(AppModel model, Action openSettings, Action exit)
    {
        this.model = model;
        this.openSettings = openSettings;
        this.exit = exit;
    }

    public void Start()
    {
        menu = BuildMenu();

        notifyIcon = new NotifyIcon
        {
            Text = Localizer.Get("AppTitle"),
            Visible = true,
            ContextMenuStrip = menu
        };

        var icon = TryLoadIcon();
        if (icon != null)
        {
            notifyIcon.Icon = icon;
        }

        notifyIcon.DoubleClick += (_, _) => openSettings();
    }

    public void Stop()
    {
        if (notifyIcon != null)
        {
            notifyIcon.Visible = false;
            notifyIcon.Dispose();
            notifyIcon = null;
        }
        if (menu != null)
        {
            menu.Dispose();
            menu = null;
        }
    }

    private ContextMenuStrip BuildMenu()
    {
        var m = new ContextMenuStrip();

        var title = new ToolStripMenuItem(Localizer.Get("AppTitle")) { Enabled = false };
        m.Items.Add(title);
        m.Items.Add(new ToolStripSeparator());

        waterStatus = new ToolStripMenuItem(string.Format(Localizer.Get("Menu_WaterStatus"), "-", 0, 0)) { Enabled = false };
        standStatus = new ToolStripMenuItem(string.Format(Localizer.Get("Menu_StandStatus"), "-")) { Enabled = false };
        eyesStatus = new ToolStripMenuItem(string.Format(Localizer.Get("Menu_EyesStatus"), "-")) { Enabled = false };
        m.Items.Add(waterStatus);
        m.Items.Add(standStatus);
        m.Items.Add(eyesStatus);

        m.Items.Add(new ToolStripSeparator());

        waterDone = new ToolStripMenuItem(Localizer.Get("Menu_WaterDone"));
        waterDone.Click += (_, _) =>
        {
            if (model.TryLogWater(out _))
            {
                model.Snooze(ReminderType.Water, model.Preferences.State.WaterIntervalMinutes);
            }
        };
        m.Items.Add(waterDone);

        waterSnooze = new ToolStripMenuItem(Localizer.Get("Menu_WaterSnooze10"));
        waterSnooze.Click += (_, _) => model.Snooze(ReminderType.Water, 10);
        m.Items.Add(waterSnooze);

        standSnooze = new ToolStripMenuItem(Localizer.Get("Menu_StandSnooze10"));
        standSnooze.Click += (_, _) => model.Snooze(ReminderType.Stand, 10);
        m.Items.Add(standSnooze);

        eyesSnooze = new ToolStripMenuItem(Localizer.Get("Menu_EyesSnooze10"));
        eyesSnooze.Click += (_, _) => model.Snooze(ReminderType.Eyes, 10);
        m.Items.Add(eyesSnooze);

        m.Items.Add(new ToolStripSeparator());

        var pause = new ToolStripMenuItem(Localizer.Get("Menu_Pause60"));
        pause.Click += (_, _) => model.PauseAll(60);
        m.Items.Add(pause);

        var resume = new ToolStripMenuItem(Localizer.Get("Menu_Resume"));
        resume.Click += (_, _) => model.ResumeAll();
        m.Items.Add(resume);

        m.Items.Add(new ToolStripSeparator());

        var settings = new ToolStripMenuItem(Localizer.Get("Menu_OpenSettings"));
        settings.Click += (_, _) => openSettings();
        m.Items.Add(settings);

        var quit = new ToolStripMenuItem(Localizer.Get("Menu_Quit"));
        quit.Click += (_, _) => exit();
        m.Items.Add(quit);

        m.Opening += (_, _) =>
        {
            var now = DateTimeOffset.Now;
            var paused = model.Preferences.State.PauseUntil > now;
            pause.Enabled = !paused;
            resume.Enabled = paused;

            var waterNext = model.Engine.NextTriggerByType.TryGetValue(ReminderType.Water, out var wn) && wn != DateTimeOffset.MinValue
                ? wn.ToLocalTime().ToString("HH:mm")
                : "-";
            var standNext = model.Engine.NextTriggerByType.TryGetValue(ReminderType.Stand, out var sn) && sn != DateTimeOffset.MinValue
                ? sn.ToLocalTime().ToString("HH:mm")
                : "-";
            var eyesNext = model.Engine.NextTriggerByType.TryGetValue(ReminderType.Eyes, out var en) && en != DateTimeOffset.MinValue
                ? en.ToLocalTime().ToString("HH:mm")
                : "-";

            if (waterStatus != null) waterStatus.Text = string.Format(Localizer.Get("Menu_WaterStatus"), waterNext, model.Preferences.State.WaterConsumedTodayMl, model.Preferences.State.DailyWaterGoalMl);
            if (standStatus != null) standStatus.Text = string.Format(Localizer.Get("Menu_StandStatus"), standNext);
            if (eyesStatus != null) eyesStatus.Text = string.Format(Localizer.Get("Menu_EyesStatus"), eyesNext);

            var waterCooldown = model.Preferences.WaterRemainingCooldownSeconds(now);
            if (waterDone != null) waterDone.Enabled = waterCooldown == 0;
            if (waterDone != null && waterCooldown > 0) waterDone.Text = string.Format(Localizer.Get("Menu_WaterDoneCooldown"), waterCooldown);
            if (waterDone != null && waterCooldown == 0) waterDone.Text = Localizer.Get("Menu_WaterDone");
        };

        return m;
    }

    private Icon? TryLoadIcon()
    {
        try
        {
            var pngPath = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.png");
            if (!File.Exists(pngPath))
            {
                return null;
            }
            using var bmp = new Bitmap(pngPath);
            var handle = bmp.GetHicon();
            using var tmp = Icon.FromHandle(handle);
            var icon = (Icon)tmp.Clone();
            DestroyIcon(handle);
            return icon;
        }
        catch
        {
            return null;
        }
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr hIcon);
}
