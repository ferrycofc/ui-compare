using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Windows.Graphics;
using Windows.UI;

namespace NovaWinUI;

public sealed partial class MainWindow : Window
{
    private sealed record Row(string Text, bool Gear, bool On);

    private static readonly Row[] General =
    [
        new("开机自启", true, true), new("最小化到托盘", true, true), new("自动更新", true, false),
        new("硬件加速", true, true), new("垂直同步", true, false), new("显示帧率", true, false),
        new("低延迟模式", true, false), new("夜间模式", false, true), new("后台静音", false, false),
        new("发送使用统计", false, false),
    ];

    private static readonly Row[] Perf =
    [
        new("帧率限制", true, true), new("动态分辨率", true, false), new("预加载资源", true, false),
        new("多线程渲染", true, true), new("省电模式", true, false),
    ];

    private static readonly Row[] Display = [new("自动亮度", false, false), new("HDR", false, true)];

    public MainWindow()
    {
        InitializeComponent();

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        var bar = AppWindow.TitleBar;
        bar.PreferredHeightOption = TitleBarHeightOption.Tall;
        bar.ButtonBackgroundColor = Colors.Transparent;
        bar.ButtonInactiveBackgroundColor = Colors.Transparent;
        bar.ButtonForegroundColor = Colors.White;
        bar.ButtonInactiveForegroundColor = Color.FromArgb(0x80, 0xFF, 0xFF, 0xFF);
        bar.ButtonHoverBackgroundColor = Color.FromArgb(0x15, 0xFF, 0xFF, 0xFF);
        bar.ButtonHoverForegroundColor = Colors.White;
        bar.ButtonPressedBackgroundColor = Color.FromArgb(0x0B, 0xFF, 0xFF, 0xFF);
        AppWindow.Resize(new SizeInt32(920, 660));

        Fill(GeneralRows, General);
        Fill(PerfRows, Perf);
        Fill(DisplayRows, Display);
        Nav.SelectedItem = Nav.MenuItems[0];

        Bright.ValueChanged += (_, e) => BrightText.Text = $"{e.NewValue:0}%";
        Contrast.ValueChanged += (_, e) => ContrastText.Text = $"{e.NewValue:0}%";
    }

    private static void Fill(StackPanel panel, Row[] rows)
    {
        var res = Application.Current.Resources;
        foreach (var r in rows)
        {
            var g = new Grid { Height = 38 };
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            g.Children.Add(new TextBlock { Text = r.Text, VerticalAlignment = VerticalAlignment.Center });

            if (r.Gear)
            {
                var gear = new Button
                {
                    Style = (Style)res["GearButtonStyle"],
                    Content = new FontIcon { Glyph = "", FontSize = 14 },
                };
                ToolTipService.SetToolTip(gear, $"{r.Text}设置");
                Grid.SetColumn(gear, 1);
                g.Children.Add(gear);
            }

            var toggle = new ToggleSwitch
            {
                Style = (Style)res["CompactToggleStyle"],
                IsOn = r.On,
                VerticalAlignment = VerticalAlignment.Center,
            };
            AutomationProperties.SetName(toggle, r.Text);
            Grid.SetColumn(toggle, 2);
            g.Children.Add(toggle);

            panel.Children.Add(g);
        }
    }
}
