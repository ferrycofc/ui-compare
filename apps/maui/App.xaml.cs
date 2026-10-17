namespace NovaMaui;

public partial class App : Application
{
    public App()
    {
        InitializeComponent();
        UserAppTheme = AppTheme.Dark;
    }

    // MAUI 一个 App 可以有多个 Window；这里只开一个，外框 920 × 660
    protected override Window CreateWindow(IActivationState? activationState)
        => new Window(new MainPage())
        {
            Title = "Nova 设置 — .NET MAUI",
            Width = 920,
            Height = 660,
        };
}
