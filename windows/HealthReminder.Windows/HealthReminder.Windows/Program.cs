using Microsoft.Windows.AppLifecycle;
using System;
using System.Threading.Tasks;

namespace HealthReminder.Windows;

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        var instance = AppInstance.FindOrRegisterForKey("main");
        if (!instance.IsCurrent)
        {
            RedirectTo(instance).GetAwaiter().GetResult();
            return;
        }

        Microsoft.UI.Xaml.Application.Start(_ =>
        {
            var app = new App();
        });
    }

    private static async Task RedirectTo(AppInstance instance)
    {
        var current = AppInstance.GetCurrent();
        var activationArgs = current.GetActivatedEventArgs();
        await instance.RedirectActivationToAsync(activationArgs);
    }
}

