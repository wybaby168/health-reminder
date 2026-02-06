using HealthReminder.Windows.Models;
using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using System.Runtime.InteropServices;

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
            Text = "健康提醒",
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

        var title = new ToolStripMenuItem("健康提醒") { Enabled = false };
        m.Items.Add(title);
        m.Items.Add(new ToolStripSeparator());

        waterStatus = new ToolStripMenuItem("喝水：-") { Enabled = false };
        standStatus = new ToolStripMenuItem("站立：-") { Enabled = false };
        eyesStatus = new ToolStripMenuItem("护眼：-") { Enabled = false };
        m.Items.Add(waterStatus);
        m.Items.Add(standStatus);
        m.Items.Add(eyesStatus);

        m.Items.Add(new ToolStripSeparator());

        waterDone = new ToolStripMenuItem("我已喝完");
        waterDone.Click += (_, _) =>
        {
            if (model.TryLogWater(out _))
            {
                model.Snooze(ReminderType.Water, model.Preferences.State.WaterIntervalMinutes);
            }
        };
        m.Items.Add(waterDone);

        waterSnooze = new ToolStripMenuItem("喝水稍后 10 分钟");
        waterSnooze.Click += (_, _) => model.Snooze(ReminderType.Water, 10);
        m.Items.Add(waterSnooze);

        standSnooze = new ToolStripMenuItem("站立稍后 10 分钟");
        standSnooze.Click += (_, _) => model.Snooze(ReminderType.Stand, 10);
        m.Items.Add(standSnooze);

        eyesSnooze = new ToolStripMenuItem("护眼稍后 10 分钟");
        eyesSnooze.Click += (_, _) => model.Snooze(ReminderType.Eyes, 10);
        m.Items.Add(eyesSnooze);

        m.Items.Add(new ToolStripSeparator());

        var pause = new ToolStripMenuItem("暂停 60 分钟");
        pause.Click += (_, _) => model.PauseAll(60);
        m.Items.Add(pause);

        var resume = new ToolStripMenuItem("恢复");
        resume.Click += (_, _) => model.ResumeAll();
        m.Items.Add(resume);

        m.Items.Add(new ToolStripSeparator());

        var settings = new ToolStripMenuItem("打开设置");
        settings.Click += (_, _) => openSettings();
        m.Items.Add(settings);

        var quit = new ToolStripMenuItem("退出");
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

            if (waterStatus != null) waterStatus.Text = $"喝水：下次 {waterNext} · 今日 {model.Preferences.State.WaterConsumedTodayMl}/{model.Preferences.State.DailyWaterGoalMl} ml";
            if (standStatus != null) standStatus.Text = $"站立：下次 {standNext}";
            if (eyesStatus != null) eyesStatus.Text = $"护眼：下次 {eyesNext}";

            var waterCooldown = model.Preferences.WaterRemainingCooldownSeconds(now);
            if (waterDone != null) waterDone.Enabled = waterCooldown == 0;
            if (waterDone != null && waterCooldown > 0) waterDone.Text = $"我已喝完（{waterCooldown}s）";
            if (waterDone != null && waterCooldown == 0) waterDone.Text = "我已喝完";
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
