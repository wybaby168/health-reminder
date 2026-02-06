using System;
using System.Threading.Tasks;
using Windows.ApplicationModel;

namespace HealthReminder.Windows.Services;

public static class StartupService
{
    public static async Task<bool> TrySetEnabledAsync(bool enabled)
    {
        try
        {
            var task = await StartupTask.GetAsync("HealthReminderStartup");
            if (enabled)
            {
                var state = await task.RequestEnableAsync();
                return state == StartupTaskState.Enabled;
            }
            task.Disable();
            return true;
        }
        catch
        {
            return false;
        }
    }
}

