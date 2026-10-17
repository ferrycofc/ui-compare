using Microsoft.Maui.LifecycleEvents;

namespace NovaMaui;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        // 出错时把异常写到 exe 旁边的 crash.txt，方便在自动截图记录里排查
        AppDomain.CurrentDomain.UnhandledException += (_, e) => WriteCrash(e.ExceptionObject?.ToString());

        var builder = MauiApp.CreateBuilder();
        builder.UseMauiApp<App>();

#if WINDOWS
        // Windows 上 Switch 就是 WinUI 的 ToggleSwitch：去掉它默认 154 的最小宽度，让开关贴着右边
        Microsoft.Maui.Handlers.SwitchHandler.Mapper.AppendToMapping("NovaCompact", (handler, view) =>
        {
            handler.PlatformView.MinWidth = 0;
        });

        // 标题栏右上角的系统按钮也用深色（背景透明、图标白色）
        builder.ConfigureLifecycleEvents(events => events.AddWindows(w => w.OnWindowCreated(window =>
        {
            var bar = window.AppWindow.TitleBar;
            bar.ButtonBackgroundColor = Microsoft.UI.Colors.Transparent;
            bar.ButtonInactiveBackgroundColor = Microsoft.UI.Colors.Transparent;
            bar.ButtonForegroundColor = Microsoft.UI.Colors.White;
            bar.ButtonInactiveForegroundColor = Windows.UI.Color.FromArgb(0x80, 0xFF, 0xFF, 0xFF);
            bar.ButtonHoverBackgroundColor = Windows.UI.Color.FromArgb(0x15, 0xFF, 0xFF, 0xFF);
            bar.ButtonHoverForegroundColor = Microsoft.UI.Colors.White;
        })));
#endif

        return builder.Build();
    }

    internal static void WriteCrash(string? text)
    {
        try { File.AppendAllText(Path.Combine(AppContext.BaseDirectory, "crash.txt"), text + Environment.NewLine); }
        catch { }
    }
}
