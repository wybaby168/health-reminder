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

    private ToolStripMenuItem? titleItem;
    private ToolStripMenuItem? pauseItem;
    private ToolStripMenuItem? resumeItem;
    private ToolStripMenuItem? settingsItem;
    private ToolStripMenuItem? quitItem;

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

        titleItem = new ToolStripMenuItem(Localizer.Get("AppTitle")) { Enabled = false };
        m.Items.Add(titleItem);
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

        pauseItem = new ToolStripMenuItem(Localizer.Get("Menu_Pause60"));
        pauseItem.Click += (_, _) => model.PauseAll(60);
        m.Items.Add(pauseItem);

        resumeItem = new ToolStripMenuItem(Localizer.Get("Menu_Resume"));
        resumeItem.Click += (_, _) => model.ResumeAll();
        m.Items.Add(resumeItem);

        m.Items.Add(new ToolStripSeparator());

        settingsItem = new ToolStripMenuItem(Localizer.Get("Menu_OpenSettings"));
        settingsItem.Click += (_, _) => openSettings();
        m.Items.Add(settingsItem);

        quitItem = new ToolStripMenuItem(Localizer.Get("Menu_Quit"));
        quitItem.Click += (_, _) => exit();
        m.Items.Add(quitItem);

        m.Opening += (_, _) =>
        {
            ReloadLocalizedText();
            var now = DateTimeOffset.Now;
            var paused = model.Preferences.State.PauseUntil > now;
            if (pauseItem != null) pauseItem.Enabled = !paused;
            if (resumeItem != null) resumeItem.Enabled = paused;

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

    public void ReloadLocalizedText()
    {
        if (notifyIcon != null)
        {
            notifyIcon.Text = Localizer.Get("AppTitle");
        }
        if (titleItem != null) titleItem.Text = Localizer.Get("AppTitle");
        if (pauseItem != null) pauseItem.Text = Localizer.Get("Menu_Pause60");
        if (resumeItem != null) resumeItem.Text = Localizer.Get("Menu_Resume");
        if (settingsItem != null) settingsItem.Text = Localizer.Get("Menu_OpenSettings");
        if (quitItem != null) quitItem.Text = Localizer.Get("Menu_Quit");

        if (waterSnooze != null) waterSnooze.Text = Localizer.Get("Menu_WaterSnooze10");
        if (standSnooze != null) standSnooze.Text = Localizer.Get("Menu_StandSnooze10");
        if (eyesSnooze != null) eyesSnooze.Text = Localizer.Get("Menu_EyesSnooze10");
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
