using HealthReminder.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Win32;
using System;

namespace HealthReminder.Windows.UI;

public sealed partial class OverlayWindow : Window
{
    private readonly AppModel model;
    private readonly OverlayKind kind;
    private readonly TimeSpan minDuration;
    private readonly TimeSpan maxDuration;
    private readonly DispatcherTimer timer;
    private readonly DateTimeOffset start;

    public OverlayWindow(AppModel model, OverlayKind kind, TimeSpan minDuration, TimeSpan maxDuration)
    {
        this.model = model;
        this.kind = kind;
        this.minDuration = minDuration;
        this.maxDuration = maxDuration;

        InitializeComponent();

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(null);

        start = DateTimeOffset.Now;
        ApplyKindUI();

        timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        timer.Tick += (_, _) => Update();
        timer.Start();

        Loaded += (_, _) =>
        {
            UpdateWindowBounds();
            var hwnd = Win32InteropHelpers.GetHwnd(this);
            Win32InteropHelpers.MakeTopMost(hwnd);
        };

        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
        Closed += (_, _) =>
        {
            SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;
            timer.Stop();
        };
    }

    public void BringToFront()
    {
        var hwnd = Win32InteropHelpers.GetHwnd(this);
        Win32InteropHelpers.BringToFront(hwnd);
    }

    private void OnDisplaySettingsChanged(object? sender, EventArgs e)
    {
        UpdateWindowBounds();
        BringToFront();
    }

    private void UpdateWindowBounds()
    {
        var rect = Win32InteropHelpers.GetVirtualScreenRect();
        var hwnd = Win32InteropHelpers.GetHwnd(this);
        Win32InteropHelpers.MoveResize(hwnd, rect);
    }

    private void ApplyKindUI()
    {
        switch (kind)
        {
            case OverlayKind.Stand:
                TitleText.Text = "站起来走动";
                SnoozeButton.Visibility = Visibility.Visible;
                DoneText.Text = "我已站立 2 分钟";
                Root.Background = new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.Colors.Black);
                break;
            case OverlayKind.Eyes:
                TitleText.Text = "闭眼休息";
                SnoozeButton.Visibility = Visibility.Collapsed;
                DoneText.Text = "结束休息";
                Root.Background = new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.Colors.Black);
                break;
        }
    }

    private void Update()
    {
        var now = DateTimeOffset.Now;
        var elapsed = now - start;

        var remainingMin = minDuration - elapsed;
        if (remainingMin < TimeSpan.Zero) remainingMin = TimeSpan.Zero;

        var remainingMax = maxDuration - elapsed;
        if (remainingMax < TimeSpan.Zero) remainingMax = TimeSpan.Zero;

        DoneButton.IsEnabled = remainingMin <= TimeSpan.Zero;

        if (remainingMin > TimeSpan.Zero)
        {
            SubtitleText.Text = kind == OverlayKind.Stand
                ? $"强制中断一下：站立并活动至少 2 分钟。\n剩余 {(int)remainingMin.TotalSeconds} 秒"
                : $"屏幕用眼休息，减少干涩与疲劳。\n剩余 {(int)remainingMin.TotalSeconds} 秒";
        }
        else
        {
            SubtitleText.Text = remainingMax > TimeSpan.Zero
                ? $"最小时间已完成。\n如无操作，将在 {(int)remainingMax.TotalSeconds} 秒后自动结束。"
                : "本次休息结束。";
        }

        if (elapsed >= maxDuration)
        {
            Close();
        }
    }

    private void OnSnooze(object sender, RoutedEventArgs e)
    {
        model.Snooze(ReminderType.Stand, 10);
        Close();
    }

    private void OnDone(object sender, RoutedEventArgs e)
    {
        if (!DoneButton.IsEnabled)
        {
            return;
        }
        Close();
    }
}
