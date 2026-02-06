using HealthReminder.Windows.Models;
using System;
using System.IO;
using System.Text.Json;

namespace HealthReminder.Windows.Services;

public sealed class PreferencesStore
{
    public PreferencesState State { get; set; } = new();

    public int WaterDosePerTap => Math.Clamp(State.WaterDosePerTapMl, 80, 400);

    public void Load()
    {
        var path = FilePath;
        if (!File.Exists(path))
        {
            State = new PreferencesState();
            Save();
            return;
        }

        var json = File.ReadAllText(path);
        State = JsonSerializer.Deserialize<PreferencesState>(json) ?? new PreferencesState();
        RefreshDaily(DateTimeOffset.Now);
        EnsureSnoozeDictionary();
    }

    public void Save()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath) ?? "");
        var json = JsonSerializer.Serialize(State, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(FilePath, json);
    }

    public void RefreshDaily(DateTimeOffset now)
    {
        var stamp = now.ToString("yyyy-MM-dd");
        if (!string.Equals(State.DailyStamp, stamp, StringComparison.Ordinal))
        {
            State.DailyStamp = stamp;
            State.WaterConsumedTodayMl = 0;
            State.LastWaterTapAt = DateTimeOffset.MinValue;
        }
    }

    public bool IsWithinActiveHours(DateTimeOffset now)
    {
        var minutes = now.Hour * 60 + now.Minute;
        var start = State.ActiveStartMinutes;
        var end = State.ActiveEndMinutes;
        if (start == end)
        {
            return true;
        }
        if (start < end)
        {
            return minutes >= start && minutes < end;
        }
        return minutes >= start || minutes < end;
    }

    public DateTimeOffset NextActiveStart(DateTimeOffset now)
    {
        if (IsWithinActiveHours(now))
        {
            return now;
        }

        var date = now.Date;
        var start = date.AddMinutes(State.ActiveStartMinutes);
        if (start > now)
        {
            return start;
        }
        return start.AddDays(1);
    }

    public bool CanLogWater(DateTimeOffset now)
    {
        var cooldown = Math.Max(15, State.WaterTapCooldownSeconds);
        return now >= State.LastWaterTapAt.AddSeconds(cooldown);
    }

    public int WaterRemainingCooldownSeconds(DateTimeOffset now)
    {
        var cooldown = Math.Max(15, State.WaterTapCooldownSeconds);
        var remain = State.LastWaterTapAt.AddSeconds(cooldown) - now;
        return remain.TotalSeconds <= 0 ? 0 : (int)Math.Ceiling(remain.TotalSeconds);
    }

    private void EnsureSnoozeDictionary()
    {
        State.SnoozeUntilByType ??= new();
        foreach (var t in Enum.GetValues<ReminderType>())
        {
            if (!State.SnoozeUntilByType.ContainsKey(t))
            {
                State.SnoozeUntilByType[t] = DateTimeOffset.MinValue;
            }
        }
    }

    private static string FilePath
    {
        get
        {
            var baseDir = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            return Path.Combine(baseDir, "HealthReminder", "preferences.json");
        }
    }
}
