using Microsoft.Maui.Controls.Shapes;

namespace NovaMaui;

public partial class MainPage : ContentPage
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
    private static readonly (string Glyph, string Text)[] Sections =
    [
        ("", "常规"), ("", "画面"), ("", "音频"), ("", "网络"),
        ("", "快捷键"), ("", "列表"), ("", "文件夹"),
    ];

    private const string IconFont = "Segoe Fluent Icons";
    private static readonly Color Accent = Color.FromArgb("#60CDFF");
    private static readonly Color Subtle = Color.FromArgb("#383838");
    private static readonly Color TextPrimary = Colors.White;
    private static readonly Color TextSecondary = Color.FromArgb("#C5C5C5");

    private readonly List<(Border Background, BoxView Pill)> _railItems = new();
    private readonly List<(Label Icon, Label Text, BoxView Line)> _tabItems = new();

    public MainPage()
    {
        InitializeComponent();

        BuildRail();
        BuildTabs();
        SelectRail(0);
        SelectTab(0);

        Fill(GeneralRows, General);
        Fill(PerfRows, Perf);
        Fill(DisplayRows, Display);

        // 滑块拖动时实时更新百分比
        Bright.ValueChanged += (_, e) => BrightText.Text = $"{e.NewValue:0}%";
        Contrast.ValueChanged += (_, e) => ContrastText.Text = $"{e.NewValue:0}%";
    }

    private static Label MakeIcon(string glyph, double size, Color color) => new()
    {
        Text = glyph,
        FontFamily = IconFont,
        FontSize = size,
        TextColor = color,
        HorizontalOptions = LayoutOptions.Center,
        VerticalOptions = LayoutOptions.Center,
    };

    private void BuildRail()
    {
        for (var i = 0; i < Sections.Length; i++)
        {
            var index = i;
            var (glyph, text) = Sections[i];

            var cell = new Grid();
            // 选中项左边的强调色小竖条
            var pill = new BoxView
            {
                WidthRequest = 3,
                HeightRequest = 16,
                CornerRadius = new CornerRadius(1.5),
                Color = Accent,
                HorizontalOptions = LayoutOptions.Start,
                VerticalOptions = LayoutOptions.Center,
            };
            cell.Children.Add(pill);
            cell.Children.Add(MakeIcon(glyph, 16, TextPrimary));

            var bg = new Border
            {
                WidthRequest = 40,
                HeightRequest = 36,
                StrokeThickness = 0,
                StrokeShape = new RoundRectangle { CornerRadius = new CornerRadius(4) },
                BackgroundColor = Colors.Transparent,
                Content = cell,
            };
            SemanticProperties.SetDescription(bg, text);

            var tap = new TapGestureRecognizer();
            tap.Tapped += (_, _) => SelectRail(index);
            bg.GestureRecognizers.Add(tap);

            Rail.Children.Add(bg);
            _railItems.Add((bg, pill));
        }
    }

    private void SelectRail(int index)
    {
        for (var i = 0; i < _railItems.Count; i++)
        {
            _railItems[i].Background.BackgroundColor = i == index ? Subtle : Colors.Transparent;
            _railItems[i].Pill.IsVisible = i == index;
        }
    }

    private void BuildTabs()
    {
        for (var i = 0; i < 5; i++)
        {
            var index = i;
            var (glyph, text) = Sections[i];

            var icon = MakeIcon(glyph, 16, TextPrimary);
            var label = new Label { Text = text, VerticalOptions = LayoutOptions.Center };
            var head = new HorizontalStackLayout { Spacing = 8, Padding = new Thickness(12, 10, 12, 8) };
            head.Children.Add(icon);
            head.Children.Add(label);

            // 选中项下面的强调色短横条
            var line = new BoxView
            {
                WidthRequest = 16,
                HeightRequest = 3,
                CornerRadius = new CornerRadius(1.5),
                Color = Accent,
                HorizontalOptions = LayoutOptions.Center,
            };

            var tab = new VerticalStackLayout { Spacing = 0 };
            tab.Children.Add(head);
            tab.Children.Add(line);
            SemanticProperties.SetDescription(tab, text);

            var tap = new TapGestureRecognizer();
            tap.Tapped += (_, _) => SelectTab(index);
            tab.GestureRecognizers.Add(tap);

            Tabs.Children.Add(tab);
            _tabItems.Add((icon, label, line));
        }
    }

    private void SelectTab(int index)
    {
        for (var i = 0; i < _tabItems.Count; i++)
        {
            var color = i == index ? TextPrimary : TextSecondary;
            _tabItems[i].Icon.TextColor = color;
            _tabItems[i].Text.TextColor = color;
            _tabItems[i].Line.Opacity = i == index ? 1 : 0;
        }
    }

    private static void Fill(VerticalStackLayout panel, Row[] rows)
    {
        foreach (var r in rows)
        {
            var g = new Grid { HeightRequest = 38 };
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Star });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            g.Children.Add(new Label { Text = r.Text, VerticalOptions = LayoutOptions.Center });

            if (r.Gear)
            {
                var gear = new Button
                {
                    Text = "",
                    FontFamily = IconFont,
                    FontSize = 14,
                    TextColor = TextSecondary,
                    BackgroundColor = Colors.Transparent,
                    BorderWidth = 0,
                    CornerRadius = 4,
                    Padding = new Thickness(0),
                    WidthRequest = 32,
                    HeightRequest = 32,
                    Margin = new Thickness(0, 0, 4, 0),
                    VerticalOptions = LayoutOptions.Center,
                };
                SemanticProperties.SetDescription(gear, $"{r.Text}设置");
                Grid.SetColumn(gear, 1);
                g.Children.Add(gear);
            }

            var sw = new Switch
            {
                IsToggled = r.On,
                OnColor = Accent,
                MinimumWidthRequest = 0,
                HorizontalOptions = LayoutOptions.End,
                VerticalOptions = LayoutOptions.Center,
            };
            // Windows 上会变成 UI Automation 名称
            SemanticProperties.SetDescription(sw, r.Text);
            Grid.SetColumn(sw, 2);
            g.Children.Add(sw);

            panel.Children.Add(g);
        }
    }
}
