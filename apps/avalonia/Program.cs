using Avalonia;

namespace NovaAvalonia;

internal static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        try
        {
            BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
        }
        catch (Exception ex)
        {
            // 出错时把异常写到 exe 旁边的 crash.txt，方便在自动截图记录里排查
            try { File.AppendAllText(Path.Combine(AppContext.BaseDirectory, "crash.txt"), ex + Environment.NewLine); }
            catch { }
            throw;
        }
    }

    // 同一份代码在 Windows / macOS / Linux 上都这样启动
    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .LogToTrace();
}
