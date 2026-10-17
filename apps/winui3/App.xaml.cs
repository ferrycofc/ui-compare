using Microsoft.UI.Xaml;

namespace NovaWinUI;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        // 出错时把异常写到 exe 旁边的 crash.txt，方便在自动截图记录里排查
        UnhandledException += (_, e) => WriteCrash(e.Exception);
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            _window = new MainWindow();
            _window.Activate();
        }
        catch (Exception ex)
        {
            WriteCrash(ex);
            throw;
        }
    }

    private static void WriteCrash(Exception ex)
    {
        try { File.AppendAllText(Path.Combine(AppContext.BaseDirectory, "crash.txt"), ex + Environment.NewLine); }
        catch { }
    }
}
