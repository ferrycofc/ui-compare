// Nova 设置面板 —— Flutter（Dart）
//
// Flutter 不用系统控件，整个界面由自带的渲染引擎一笔一笔画出来，所以在哪个平台上都长一个样。
// 这里用的是 Material 3：种子色自动生成整套深色配色，开关、滑块、标签页、导航栏都自带动画。

import 'package:flutter/material.dart';

void main() => runApp(const NovaApp());

// 种子色：Material 3 会从这一个颜色推出整套配色
const Color _seed = Color(0xFF7C6CF2);

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova 设置 — Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _seed,
        visualDensity: VisualDensity.compact,
        // 英文用默认的 Segoe UI，中文用微软雅黑（避免系统按英文区域挑到日文字形）
        fontFamilyFallback: const ['Microsoft YaHei UI', 'Microsoft YaHei'],
        sliderTheme: const SliderThemeData(
          overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
        ),
      ),
      home: const SettingsPage(),
    );
  }
}

// ---------- 内容（和其它技术完全一样） ----------
class _Opt {
  const _Opt(this.text, {this.gear = false, this.on = false});
  final String text;
  final bool gear; // 带齿轮按钮
  final bool on; // 默认打开
}

const List<_Opt> _general = [
  _Opt('开机自启', gear: true, on: true),
  _Opt('最小化到托盘', gear: true, on: true),
  _Opt('自动更新', gear: true),
  _Opt('硬件加速', gear: true, on: true),
  _Opt('垂直同步', gear: true),
  _Opt('显示帧率', gear: true),
  _Opt('低延迟模式', gear: true),
  _Opt('夜间模式', on: true),
  _Opt('后台静音'),
  _Opt('发送使用统计'),
];

const List<_Opt> _perf = [
  _Opt('帧率限制', gear: true, on: true),
  _Opt('动态分辨率', gear: true),
  _Opt('预加载资源', gear: true),
  _Opt('多线程渲染', gear: true, on: true),
  _Opt('省电模式', gear: true),
];

const List<_Opt> _display = [
  _Opt('自动亮度'),
  _Opt('HDR', on: true),
];

class _Nav {
  const _Nav(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Nav> _navItems = [
  _Nav('常规', Icons.tune, Icons.tune),
  _Nav('画面', Icons.desktop_windows_outlined, Icons.desktop_windows),
  _Nav('音频', Icons.volume_up_outlined, Icons.volume_up),
  _Nav('网络', Icons.language, Icons.language),
  _Nav('快捷键', Icons.keyboard_outlined, Icons.keyboard),
  _Nav('列表', Icons.list, Icons.list),
  _Nav('文件夹', Icons.folder_outlined, Icons.folder),
];

// 开关打开时圆点里显示一个对勾（Material 3 的样式）
final WidgetStateProperty<Icon?> _thumbIcon = WidgetStateProperty.resolveWith(
  (states) => states.contains(WidgetState.selected) ? const Icon(Icons.check) : null,
);

// ---------- 界面 ----------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _nav = 0;
  double _bright = 80;
  double _contrast = 35;
  final Map<String, bool> _on = {
    for (final o in [..._general, ..._perf, ..._display]) o.text: o.on,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _rail(scheme),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tabs(),
                    const SizedBox(height: 12),
                    Expanded(child: _columns(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 左侧导航栏：7 个图标，底部是头像和设置
  Widget _rail(ColorScheme scheme) {
    return NavigationRail(
      selectedIndex: _nav,
      onDestinationSelected: (i) => setState(() => _nav = i),
      labelType: NavigationRailLabelType.none,
      minWidth: 64,
      backgroundColor: scheme.surfaceContainer,
      trailingAtBottom: true,
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Text('N', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            const SizedBox(height: 10),
            IconButton(
              onPressed: () {},
              tooltip: '设置',
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
      destinations: [
        for (final n in _navItems)
          NavigationRailDestination(
            icon: Icon(n.icon),
            selectedIcon: Icon(n.selectedIcon),
            label: Text(n.label),
          ),
      ],
    );
  }

  // 顶部标签：图标和文字横排
  Widget _tabs() {
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      tabs: [
        for (final n in _navItems.take(5))
          Tab(
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(n.icon, size: 18),
                const SizedBox(width: 8),
                Text(n.label),
              ],
            ),
          ),
      ],
    );
  }

  // 两列卡片：左边“常规选项”，右边“性能”和“显示”
  Widget _columns(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _card(context, Icons.tune, '常规选项', [for (final o in _general) _toggleRow(o)]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(context, Icons.speed, '性能', [for (final o in _perf) _toggleRow(o)]),
              const SizedBox(height: 12),
              _card(context, Icons.light_mode_outlined, '显示', [
                for (final o in _display) _toggleRow(o),
                const Divider(height: 13, thickness: 1),
                _slider(context, '亮度', _bright, (v) => setState(() => _bright = v)),
                _slider(context, '对比度', _contrast, (v) => setState(() => _contrast = v)),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  // 卡片：标题行（图标 + 粗体字）+ 内容
  Widget _card(BuildContext context, IconData icon, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  // 一行：文字 …… [齿轮] [开关]
  Widget _toggleRow(_Opt o) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(child: Text(o.text)),
          if (o.gear)
            IconButton(
              onPressed: () {},
              tooltip: '${o.text}设置',
              iconSize: 18,
              icon: const Icon(Icons.settings_outlined),
            ),
          const SizedBox(width: 6),
          // 可访问名称 = 这一行的文字（录视频的脚本靠它找开关）
          Semantics(
            container: true,
            label: o.text,
            child: Switch(
              value: _on[o.text]!,
              thumbIcon: _thumbIcon,
              onChanged: (v) => setState(() => _on[o.text] = v),
            ),
          ),
        ],
      ),
    );
  }

  // 滑块：上面一行“名字 …… NN%”，下面是滑块，拖动时实时更新
  Widget _slider(BuildContext context, String name, double value, ValueChanged<double> onChanged) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 22,
          child: Row(
            children: [
              Expanded(child: Text(name)),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('${value.round()}%', style: muted),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 34,
          // label 同时是滑块的可访问名称（没有分档，所以不会弹出数值气泡）
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            label: name,
            semanticFormatterCallback: (v) => '${v.round()}%',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
