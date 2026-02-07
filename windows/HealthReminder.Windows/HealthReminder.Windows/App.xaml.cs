using HealthReminder.Windows.Services;
using HealthReminder.Windows.UI;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;
using System;
using Microsoft.UI.Dispatching;

namespace HealthReminder.Windows;

public sealed partial class App : Application
{
    public static AppModel Model { get; } = new();
    public static DispatcherQueue? UiDispatcher { get; private set; }

    private SettingsWindow? settingsWindow;
    private TrayIconService? tray;

    public App()
    {
        InitializeComponent();

        AppInstance.GetCurrent().Activated += OnActivated;
        ToastNotificationService.Initialize(Model);
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        UiDispatcher = DispatcherQueue.GetForCurrentThread();
        tray = new TrayIconService(Model, RequestOpenSettings, Exit);
        tray.Start();
        Model.Start();
    }

    private void OnActivated(object? sender, AppActivationArguments e)
    {
        OpenSettings();
    }

    private void OpenSettings()
    {
        if (settingsWindow == null)
        {
            settingsWindow = new SettingsWindow(Model);
            settingsWindow.Closed += (_, _) => settingsWindow = null;
        }
        settingsWindow.Activate();
        settingsWindow.BringToFront();
    }

    public static void RequestOpenSettings()
    {
        UiDispatcher?.TryEnqueue(() =>
        {
            if (Current is App app)
            {
                app.OpenSettings();
            }
        });
    }

    private void Exit()
    {
        tray?.Stop();
        Model.Stop();
        Environment.Exit(0);
    }

    public static void RequestReloadStrings()
    {
        UiDispatcher?.TryEnqueue(() =>
        {
            if (Current is App app)
            {
                app.tray?.ReloadLocalizedText();
                app.settingsWindow?.ReloadLocalizedText();
            }
        });
    }
}
