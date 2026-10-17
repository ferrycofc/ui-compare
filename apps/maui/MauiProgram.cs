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
#endif

        return builder.Build();
    }

    internal static void WriteCrash(string? text)
    {
        try { File.AppendAllText(Path.Combine(AppContext.BaseDirectory, "crash.txt"), text + Environment.NewLine); }
        catch { }
    }
}
