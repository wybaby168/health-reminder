using Microsoft.UI.Xaml;
using System;
using System.Runtime.InteropServices;
using Windows.Graphics;

namespace HealthReminder.Windows.UI;

internal static class Win32InteropHelpers
{
    public static IntPtr GetHwnd(Window window)
    {
        return WinRT.Interop.WindowNative.GetWindowHandle(window);
    }

    public static RectInt32 GetVirtualScreenRect()
    {
        var x = GetSystemMetrics(SystemMetric.SM_XVIRTUALSCREEN);
        var y = GetSystemMetrics(SystemMetric.SM_YVIRTUALSCREEN);
        var w = GetSystemMetrics(SystemMetric.SM_CXVIRTUALSCREEN);
        var h = GetSystemMetrics(SystemMetric.SM_CYVIRTUALSCREEN);
        return new RectInt32(x, y, w, h);
    }

    public static void MakeTopMost(IntPtr hwnd)
    {
        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SetWindowPosFlags.SWP_NOMOVE | SetWindowPosFlags.SWP_NOSIZE | SetWindowPosFlags.SWP_SHOWWINDOW);
    }

    public static void MoveResize(IntPtr hwnd, RectInt32 rect)
    {
        SetWindowPos(hwnd, HWND_TOPMOST, rect.X, rect.Y, rect.Width, rect.Height, SetWindowPosFlags.SWP_SHOWWINDOW);
    }

    public static void BringToFront(IntPtr hwnd)
    {
        SetForegroundWindow(hwnd);
        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SetWindowPosFlags.SWP_NOMOVE | SetWindowPosFlags.SWP_NOSIZE | SetWindowPosFlags.SWP_SHOWWINDOW);
    }

    private enum SystemMetric
    {
        SM_XVIRTUALSCREEN = 76,
        SM_YVIRTUALSCREEN = 77,
        SM_CXVIRTUALSCREEN = 78,
        SM_CYVIRTUALSCREEN = 79
    }

    [Flags]
    private enum SetWindowPosFlags : uint
    {
        SWP_NOSIZE = 0x0001,
        SWP_NOMOVE = 0x0002,
        SWP_SHOWWINDOW = 0x0040
    }

    private static readonly IntPtr HWND_TOPMOST = new(-1);

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(SystemMetric smIndex);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, SetWindowPosFlags uFlags);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);
}

