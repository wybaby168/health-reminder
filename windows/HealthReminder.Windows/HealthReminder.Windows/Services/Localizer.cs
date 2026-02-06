using Microsoft.Windows.ApplicationModel.Resources;

namespace HealthReminder.Windows.Services;

public static class Localizer
{
    private static readonly ResourceLoader Loader = ResourceLoader.GetForViewIndependentUse();

    public static string Get(string key)
    {
        var value = Loader.GetString(key);
        return string.IsNullOrWhiteSpace(value) ? key : value;
    }
}

