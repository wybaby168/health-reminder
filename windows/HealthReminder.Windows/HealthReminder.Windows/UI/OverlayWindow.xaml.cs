using HealthReminder.Windows.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Win32;
using System;
using HealthReminder.Windows.Services;

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
                TitleText.Text = Localizer.Get("Overlay_StandTitle");
                SnoozeButton.Visibility = Visibility.Visible;
                DoneText.Text = Localizer.Get("Overlay_StandDone");
                SnoozeText.Text = Localizer.Get("Overlay_Snooze10");
                Root.Background = new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.Colors.Black);
                break;
            case OverlayKind.Eyes:
                TitleText.Text = Localizer.Get("Overlay_EyesTitle");
                SnoozeButton.Visibility = Visibility.Collapsed;
                DoneText.Text = Localizer.Get("Overlay_EyesDone");
                SnoozeText.Text = Localizer.Get("Overlay_Snooze10");
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
            var key = kind == OverlayKind.Stand ? "Overlay_Stand_Remaining" : "Overlay_Eyes_Remaining";
            SubtitleText.Text = string.Format(Localizer.Get(key), (int)remainingMin.TotalSeconds);
        }
        else
        {
            if (remainingMax > TimeSpan.Zero)
            {
                var key = kind == OverlayKind.Stand ? "Overlay_Stand_AutoClose" : "Overlay_Eyes_AutoClose";
                SubtitleText.Text = string.Format(Localizer.Get(key), (int)remainingMax.TotalSeconds);
            }
            else
            {
                SubtitleText.Text = Localizer.Get(kind == OverlayKind.Stand ? "Overlay_Stand_DoneText" : "Overlay_Eyes_DoneText");
            }
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
