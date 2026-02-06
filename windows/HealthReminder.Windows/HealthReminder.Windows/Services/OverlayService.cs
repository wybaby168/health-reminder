using HealthReminder.Windows.UI;
using System;

namespace HealthReminder.Windows.Services;

public sealed class OverlayService
{
    private readonly AppModel model;
    private OverlayWindow? window;

    public OverlayService(AppModel model)
    {
        this.model = model;
    }

    public void ShowStand(int minSeconds, int maxSeconds)
    {
        Show(OverlayKind.Stand, minSeconds, maxSeconds);
    }

    public void ShowEyes(int minSeconds, int maxSeconds)
    {
        Show(OverlayKind.Eyes, minSeconds, maxSeconds);
    }

    private void Show(OverlayKind kind, int minSeconds, int maxSeconds)
    {
        Close();
        window = new OverlayWindow(model, kind, TimeSpan.FromSeconds(minSeconds), TimeSpan.FromSeconds(maxSeconds));
        window.Closed += (_, _) => window = null;
        window.Activate();
        window.BringToFront();
    }

    private void Close()
    {
        if (window != null)
        {
            window.Close();
            window = null;
        }
    }
}

