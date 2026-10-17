namespace Nova;

// Nova 设置面板 —— WinForms（.NET 8）
// 全部用 WinForms 自带控件：ToolStrip、TabControl、GroupBox、CheckBox、Button、TrackBar。
// WinForms 没有开关控件，用复选框。图标取自 Windows 自带的 DLL（和 Win32 版一样），不带图片资源。
public sealed class MainForm : Form
{
    private sealed record Row(string Text, bool Gear, bool On);

    private static readonly Row[] General =
    {
        new("开机自启", true, true), new("最小化到托盘", true, true), new("自动更新", true, false),
        new("硬件加速", true, true), new("垂直同步", true, false), new("显示帧率", true, false),
        new("低延迟模式", true, false), new("夜间模式", false, true), new("后台静音", false, false),
        new("发送使用统计", false, false),
    };

    private static readonly Row[] Perf =
    {
        new("帧率限制", true, true), new("动态分辨率", true, false), new("预加载资源", true, false),
        new("多线程渲染", true, true), new("省电模式", true, false),
    };

    private static readonly Row[] Display = { new("自动亮度", false, false), new("HDR", false, true) };

    private readonly Image? _gear = SysIcons.LoadBitmap(SysIcons.Settings, 16);

    public MainForm()
    {
        SuspendLayout();
        AutoScaleDimensions = new SizeF(96F, 96F);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 9F);
        Text = "Nova 设置 — WinForms";
        Icon = SysIcons.Load(SysIcons.General, 16);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        Size = new Size(920, 660);   // 外框含 Win10/11 看不见的边，可见约 906 x 653
        Padding = new Padding(8);

        // 停靠按 Controls 倒序处理：先加 Fill 的标签页，再加 Left 的图标栏
        Controls.Add(BuildTabs());
        Controls.Add(BuildRail());
        ResumeLayout(true);
    }

    // 左侧竖排图标栏：上面 7 个（单选），底部头像和设置
    private static Control BuildRail()
    {
        var strip = new ToolStrip
        {
            Dock = DockStyle.Fill,
            LayoutStyle = ToolStripLayoutStyle.VerticalStackWithOverflow,
            GripStyle = ToolStripGripStyle.Hidden,
            ImageScalingSize = new Size(24, 24),
            Padding = new Padding(2, 2, 2, 2),
        };

        var pages = new List<ToolStripButton>();
        (SysIcon Icon, string Name)[] top =
        {
            (SysIcons.General, "常规"), (SysIcons.Display, "画面"), (SysIcons.Audio, "音频"),
            (SysIcons.Network, "网络"), (SysIcons.Keys, "快捷键"), (SysIcons.List, "列表"), (SysIcons.Folder, "文件夹"),
        };
        foreach (var (icon, name) in top)
        {
            var b = RailButton(icon, name);
            b.Click += (_, _) => { foreach (var p in pages) p.Checked = p == b; };
            pages.Add(b);
            strip.Items.Add(b);
        }
        pages[0].Checked = true;

        // Alignment = Right 的项在竖排工具栏里从底部往上排：先加设置，再加头像
        foreach (var (icon, name) in new[] { (SysIcons.Settings, "设置"), (SysIcons.User, "头像") })
        {
            var b = RailButton(icon, name);
            b.Alignment = ToolStripItemAlignment.Right;
            strip.Items.Add(b);
        }

        var host = new Panel { Dock = DockStyle.Left, Width = 52, Padding = new Padding(0, 0, 8, 0) };
        host.Controls.Add(strip);
        return host;
    }

    private static ToolStripButton RailButton(SysIcon icon, string name) => new()
    {
        DisplayStyle = ToolStripItemDisplayStyle.Image,
        Image = SysIcons.LoadBitmap(icon, 24),
        ToolTipText = name,
        AccessibleName = name,
        Padding = new Padding(4),
        Margin = new Padding(0, 1, 0, 3),
    };

    // 顶部标签页（带 16px 图标），只有第一页有内容
    private Control BuildTabs()
    {
        var images = new ImageList { ColorDepth = ColorDepth.Depth32Bit, ImageSize = new Size(16, 16) };
        var tabs = new TabControl { Dock = DockStyle.Fill, ImageList = images, Padding = new Point(10, 4) };

        (SysIcon Icon, string Name)[] items =
        {
            (SysIcons.General, "常规"), (SysIcons.Display, "画面"), (SysIcons.Audio, "音频"),
            (SysIcons.Network, "网络"), (SysIcons.Keys, "快捷键"),
        };
        for (int i = 0; i < items.Length; i++)
        {
            images.Images.Add(SysIcons.Load(items[i].Icon, 16) ?? SystemIcons.Application);
            // TrackBar 不支持透明背景，所以页面用纯色（白色）而不是主题纹理
            var page = new TabPage(items[i].Name)
            {
                ImageIndex = i,
                UseVisualStyleBackColor = false,
                BackColor = SystemColors.Window,
                Padding = new Padding(6),
            };
            tabs.TabPages.Add(page);
        }
        tabs.TabPages[0].Controls.Add(BuildContent());
        return tabs;
    }

    // 两列：左“常规选项”，右上“性能”，右下“显示”
    private Control BuildContent()
    {
        var grid = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 2 };
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
        grid.RowStyles.Add(new RowStyle(SizeType.Absolute, 264F));
        grid.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));

        var general = Group("常规选项");
        var g = RowTable();
        AddToggleRows(g, General, 44);
        EndRows(g);
        general.Controls.Add(g);
        grid.Controls.Add(general, 0, 0);
        grid.SetRowSpan(general, 2);

        var perf = Group("性能");
        var p = RowTable();
        AddToggleRows(p, Perf, 40);
        EndRows(p);
        perf.Controls.Add(p);
        grid.Controls.Add(perf, 1, 0);

        var display = Group("显示");
        var d = RowTable();
        AddToggleRows(d, Display, 40);
        AddSeparator(d);
        AddSlider(d, "亮度", 80);
        AddSlider(d, "对比度", 35);
        EndRows(d);
        display.Controls.Add(d);
        grid.Controls.Add(display, 1, 1);

        return grid;
    }

    private static GroupBox Group(string title) => new()
    {
        Text = title,
        Dock = DockStyle.Fill,
        Margin = new Padding(6),
        Padding = new Padding(10, 8, 10, 6),
    };

    // 每个分组里一张三列的表：文字 | 齿轮按钮 | 复选框
    private static TableLayoutPanel RowTable()
    {
        var t = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 0 };
        t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        t.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 40F));
        t.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 28F));
        return t;
    }

    private static int NewRow(TableLayoutPanel t, int height)
    {
        t.RowStyles.Add(new RowStyle(SizeType.Absolute, height));
        t.RowCount += 1;
        return t.RowCount - 1;
    }

    // 最后一行占满剩余空间，上面的行保持固定高度
    private static void EndRows(TableLayoutPanel t)
    {
        t.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
        t.RowCount += 1;
    }

    private void AddToggleRows(TableLayoutPanel t, Row[] rows, int pitch)
    {
        foreach (var r in rows)
        {
            int y = NewRow(t, pitch);
            t.Controls.Add(new Label
            {
                Text = r.Text,
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft,
                UseMnemonic = false,
            }, 0, y);

            if (r.Gear)
            {
                t.Controls.Add(new Button
                {
                    Image = _gear,
                    Size = new Size(28, 24),
                    Anchor = AnchorStyles.None,
                    UseVisualStyleBackColor = true,
                    AccessibleName = r.Text + "设置",
                }, 1, y);
            }

            t.Controls.Add(new CheckBox
            {
                Checked = r.On,
                AutoSize = true,
                Anchor = AnchorStyles.None,
                AccessibleName = r.Text,   // 录屏脚本靠这个名字找控件
            }, 2, y);
        }
    }

    // 分隔线：经典做法，一个 2 像素高、凹陷边框的 Label
    private static void AddSeparator(TableLayoutPanel t)
    {
        int y = NewRow(t, 14);
        var line = new Label
        {
            AutoSize = false,
            Height = 2,
            BorderStyle = BorderStyle.Fixed3D,
            Anchor = AnchorStyles.Left | AnchorStyles.Right,
        };
        t.Controls.Add(line, 0, y);
        t.SetColumnSpan(line, 3);
    }

    private static void AddSlider(TableLayoutPanel t, string name, int value)
    {
        int y = NewRow(t, 24);
        t.Controls.Add(new Label { Text = name, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomLeft }, 0, y);
        var percent = new Label { Text = $"{value}%", Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomRight };
        t.Controls.Add(percent, 1, y);
        t.SetColumnSpan(percent, 2);

        y = NewRow(t, 38);
        var bar = new TrackBar
        {
            Minimum = 0,
            Maximum = 100,
            TickFrequency = 10,
            SmallChange = 1,
            LargeChange = 10,
            Value = value,
            AutoSize = false,
            Dock = DockStyle.Fill,
            AccessibleName = name,
        };
        bar.ValueChanged += (_, _) => percent.Text = $"{bar.Value}%";   // 拖动时实时更新
        t.Controls.Add(bar, 0, y);
        t.SetColumnSpan(bar, 3);
    }
}
