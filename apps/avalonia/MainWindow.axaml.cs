using Avalonia;
using Avalonia.Automation;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;

namespace NovaAvalonia;

public partial class MainWindow : Window
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

    // 图标栏和顶部标签（Segoe Fluent Icons 码位）
    private static readonly (string Glyph, string Text)[] RailItems =
    [
        ("", "常规"), ("", "画面"), ("", "音频"), ("", "网络"),
        ("", "快捷键"), ("", "列表"), ("", "文件夹"),
    ];

    // 字体图标：Win11 用 Segoe Fluent Icons，Win10 回退到 Segoe MDL2 Assets
    private static readonly FontFamily IconFont = new("Segoe Fluent Icons, Segoe MDL2 Assets");

    public MainWindow()
    {
        InitializeComponent();

        // 先试 Mica，再试亚克力；都不行时用 TransparencyBackgroundFallback 的纯色
        TransparencyLevelHint = new[]
        {
            WindowTransparencyLevel.Mica, WindowTransparencyLevel.AcrylicBlur, WindowTransparencyLevel.None,
        };

        foreach (var (glyph, text) in RailItems)
        {
            var cell = new Grid();
            // 选中项左边的强调色小竖条（样式里控制显示）
            var pill = new Border
            {
                Width = 3,
                Height = 16,
                CornerRadius = new CornerRadius(1.5),
                HorizontalAlignment = HorizontalAlignment.Left,
                VerticalAlignment = VerticalAlignment.Center,
            };
            pill.Classes.Add("pill");
            cell.Children.Add(pill);
            cell.Children.Add(new TextBlock
            {
                Text = glyph,
                FontFamily = IconFont,
                FontSize = 16,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
            });
            var item = new ListBoxItem { Content = cell };
            ToolTip.SetTip(item, text);
            AutomationProperties.SetName(item, text);
            Rail.Items.Add(item);
        }
        Rail.SelectedIndex = 0;

        for (var i = 0; i < 5; i++)
        {
            var (glyph, text) = RailItems[i];
            var content = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            content.Children.Add(new TextBlock
            {
                Text = glyph,
                FontFamily = IconFont,
                FontSize = 16,
                VerticalAlignment = VerticalAlignment.Center,
            });
            content.Children.Add(new TextBlock { Text = text, VerticalAlignment = VerticalAlignment.Center });
            var tab = new TabStripItem { Content = content };
            AutomationProperties.SetName(tab, text);
            Tabs.Items.Add(tab);
        }
        Tabs.SelectedIndex = 0;

        Fill(GeneralRows, General);
        Fill(PerfRows, Perf);
        Fill(DisplayRows, Display);

        // 滑块拖动时实时更新百分比
        Bright.ValueChanged += (_, e) => BrightText.Text = $"{e.NewValue:0}%";
        Contrast.ValueChanged += (_, e) => ContrastText.Text = $"{e.NewValue:0}%";
    }

    private static void Fill(StackPanel panel, Row[] rows)
    {
        foreach (var r in rows)
        {
            var g = new Grid { Height = 38, ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto") };

            g.Children.Add(new TextBlock { Text = r.Text, VerticalAlignment = VerticalAlignment.Center });

            if (r.Gear)
            {
                var gear = new Button
                {
                    Content = new TextBlock
                    {
                        Text = "",
                        FontFamily = IconFont,
                        FontSize = 14,
                        HorizontalAlignment = HorizontalAlignment.Center,
                        VerticalAlignment = VerticalAlignment.Center,
                    },
                    VerticalAlignment = VerticalAlignment.Center,
                };
                gear.Classes.Add("gear");
                ToolTip.SetTip(gear, $"{r.Text}设置");
                AutomationProperties.SetName(gear, $"{r.Text}设置");
                Grid.SetColumn(gear, 1);
                g.Children.Add(gear);
            }

            var toggle = new ToggleSwitch
            {
                IsChecked = r.On,
                OnContent = null,
                OffContent = null,
                // 模板里开关右边留了 12 的空列（给 On/Off 文字），抵消掉让开关贴右
                Margin = new Thickness(0, 0, -12, 0),
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center,
            };
            AutomationProperties.SetName(toggle, r.Text);
            Grid.SetColumn(toggle, 2);
            g.Children.Add(toggle);

            panel.Children.Add(g);
        }
    }
}
