using Microsoft.UI.Xaml;

namespace NovaMaui.WinUI;

// Windows 上 MAUI 跑在 WinUI 3 上：这是 WinUI 的 Application，再把控制权交给 MauiProgram
public partial class App : MauiWinUIApplication
{
    public App()
    {
        UnhandledException += (_, e) => MauiProgram.WriteCrash(e.Exception?.ToString());
        InitializeComponent();
    }

    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
