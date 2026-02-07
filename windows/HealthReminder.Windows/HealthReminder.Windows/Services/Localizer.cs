using Microsoft.Windows.ApplicationModel.Resources;

namespace HealthReminder.Windows.Services;

public static class Localizer
{
    private static ResourceLoader loader = ResourceLoader.GetForViewIndependentUse();

    public static string Get(string key)
    {
        var value = loader.GetString(key);
        return string.IsNullOrWhiteSpace(value) ? key : value;
    }

    public static void Reload()
    {
        loader = ResourceLoader.GetForViewIndependentUse();
    }
}
