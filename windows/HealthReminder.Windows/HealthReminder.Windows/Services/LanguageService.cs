using System;
using System.Globalization;
using Windows.Globalization;

namespace HealthReminder.Windows.Services;

public static class LanguageService
{
    public static void ApplyPreference(string preference)
    {
        var normalized = (preference ?? "system").Trim();
        var overrideValue = normalized switch
        {
            "en" => "en-US",
            "en-us" => "en-US",
            "zh" => "zh-CN",
            "zh-cn" => "zh-CN",
            "zh-hans" => "zh-CN",
            "system" => ResolveForSystem(),
            _ => normalized
        };

        ApplicationLanguages.PrimaryLanguageOverride = overrideValue;
        ApplyCultureOverride(overrideValue);

        try
        {
            Windows.ApplicationModel.Resources.Core.ResourceContext.GetForViewIndependentUse().Reset();
        }
        catch
        {
        }

        Localizer.Reload();
    }

    private static void ApplyCultureOverride(string languageTag)
    {
        try
        {
            var culture = CultureInfo.GetCultureInfo(languageTag);
            CultureInfo.DefaultThreadCurrentCulture = culture;
            CultureInfo.DefaultThreadCurrentUICulture = culture;
            CultureInfo.CurrentCulture = culture;
            CultureInfo.CurrentUICulture = culture;
        }
        catch
        {
        }
    }

    private static string ResolveForSystem()
    {
        var first = ApplicationLanguages.Languages.Count > 0 ? ApplicationLanguages.Languages[0] : "en-US";
        return first.StartsWith("zh", StringComparison.OrdinalIgnoreCase) ? "zh-CN" : "en-US";
    }
}
