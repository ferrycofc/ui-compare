using Windows.ApplicationModel.Core;
using Windows.UI;
using Windows.UI.ViewManagement;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Automation;
using Windows.UI.Xaml.Controls;

namespace NovaUWP
{
    public sealed partial class MainPage : Page
    {
        private sealed class Row
        {
            public Row(string text, bool gear, bool on) { Text = text; Gear = gear; On = on; }
            public string Text { get; }
            public bool Gear { get; }
            public bool On { get; }
        }

        private static readonly Row[] General =
        {
            new Row("开机自启", true, true), new Row("最小化到托盘", true, true), new Row("自动更新", true, false),
            new Row("硬件加速", true, true), new Row("垂直同步", true, false), new Row("显示帧率", true, false),
            new Row("低延迟模式", true, false), new Row("夜间模式", false, true), new Row("后台静音", false, false),
            new Row("发送使用统计", false, false),
        };

        private static readonly Row[] Perf =
        {
            new Row("帧率限制", true, true), new Row("动态分辨率", true, false), new Row("预加载资源", true, false),
            new Row("多线程渲染", true, true), new Row("省电模式", true, false),
        };

        private static readonly Row[] Display = { new Row("自动亮度", false, false), new Row("HDR", false, true) };

        public MainPage()
        {
            InitializeComponent();

            // 视图延伸到标题栏，AppTitleBar 这一行当作拖动区域
            CoreApplication.GetCurrentView().TitleBar.ExtendViewIntoTitleBar = true;
            Window.Current.SetTitleBar(AppTitleBar);

            // 右上角系统按钮：背景透明，白色图标
            var bar = ApplicationView.GetForCurrentView().TitleBar;
            bar.ButtonBackgroundColor = Colors.Transparent;
            bar.ButtonInactiveBackgroundColor = Colors.Transparent;
            bar.ButtonForegroundColor = Colors.White;
            bar.ButtonInactiveForegroundColor = ColorHelper.FromArgb(0x80, 0xFF, 0xFF, 0xFF);
            bar.ButtonHoverBackgroundColor = ColorHelper.FromArgb(0x15, 0xFF, 0xFF, 0xFF);
            bar.ButtonHoverForegroundColor = Colors.White;
            bar.ButtonPressedBackgroundColor = ColorHelper.FromArgb(0x0B, 0xFF, 0xFF, 0xFF);
            bar.ButtonPressedForegroundColor = Colors.White;

            Fill(GeneralRows, General);
            Fill(PerfRows, Perf);
            Fill(DisplayRows, Display);
            Nav.SelectedItem = Nav.MenuItems[0];

            // 滑块拖动时实时更新百分比
            Bright.ValueChanged += (s, e) => BrightText.Text = $"{e.NewValue:0}%";
            Contrast.ValueChanged += (s, e) => ContrastText.Text = $"{e.NewValue:0}%";
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
                    ToolTipService.SetToolTip(gear, r.Text + "设置");
                    AutomationProperties.SetName(gear, r.Text + "设置");
                    Grid.SetColumn(gear, 1);
                    g.Children.Add(gear);
                }

                var toggle = new ToggleSwitch
                {
                    Style = (Style)res["CompactToggleStyle"],
                    IsOn = r.On,
                };
                AutomationProperties.SetName(toggle, r.Text);
                Grid.SetColumn(toggle, 2);
                g.Children.Add(toggle);

                panel.Children.Add(g);
            }
        }
    }
}
