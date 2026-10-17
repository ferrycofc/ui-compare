using System.Windows;

namespace Nova;

// 一行设置的数据；界面由 MainWindow.xaml 里的 RowTemplate 生成
public sealed class SettingRow
{
    public SettingRow(string text, bool gear, bool on)
    {
        Text = text;
        Gear = gear;
        On = on;
    }

    public string Text { get; }
    public bool Gear { get; }
    public bool On { get; set; }
    public string GearName => Text + "设置";
}

public partial class MainWindow : Window
{
    private static readonly SettingRow[] General =
    {
        new("开机自启", true, true), new("最小化到托盘", true, true), new("自动更新", true, false),
        new("硬件加速", true, true), new("垂直同步", true, false), new("显示帧率", true, false),
        new("低延迟模式", true, false), new("夜间模式", false, true), new("后台静音", false, false),
        new("发送使用统计", false, false),
    };

    private static readonly SettingRow[] Perf =
    {
        new("帧率限制", true, true), new("动态分辨率", true, false), new("预加载资源", true, false),
        new("多线程渲染", true, true), new("省电模式", true, false),
    };

    private static readonly SettingRow[] Display = { new("自动亮度", false, false), new("HDR", false, true) };

    public MainWindow()
    {
        InitializeComponent();
        GeneralRows.ItemsSource = General;
        PerfRows.ItemsSource = Perf;
        DisplayRows.ItemsSource = Display;
    }

    // 自绘标题栏上的两个按钮
    private void OnMinimize(object sender, RoutedEventArgs e) => SystemCommands.MinimizeWindow(this);

    private void OnClose(object sender, RoutedEventArgs e) => SystemCommands.CloseWindow(this);
}
