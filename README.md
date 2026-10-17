# ui-compare

用同一个“Nova 设置”界面，对比 Windows 上各种 UI 技术。每个技术都用它自己的框架真实写一遍，
在 GitHub Actions 的 Windows 机器上编译、运行、截图、录操作视频，并测启动时间、内存和发布体积。

界面内容和规则见 [SPEC.md](SPEC.md)，视频文案参考见 [NOTES.md](NOTES.md)。

## 快速开始（做视频用）

1. **一次下载全部截图和视频**：[shots 分支打包下载](../../archive/refs/heads/shots.zip)，解压后看 `latest/` 文件夹。
2. **数据表**：`latest/SUMMARY.md`（体积、内存、启动时间）。
3. **自己录**：到 [Releases → nova-builds](../../releases/tag/nova-builds) 下载对应技术的 zip，解压后双击里面的 exe。
   - 程序没有数字签名，第一次运行 Windows 可能弹出“已保护你的电脑”，点“更多信息 → 仍要运行”。
   - UWP 不能直接双击运行，要先安装：用管理员身份打开 PowerShell，进入解压后的文件夹，运行
     `powershell -ExecutionPolicy Bypass -File .\install.ps1`，然后在开始菜单里打开“Nova 设置 — UWP”。
     这个脚本会把包里自带的测试证书加入“受信任”列表（UWP 必须签名才能安装）；录完可以在“管理计算机证书”里删掉名为 CN=Nova 的证书。

## 结果在哪里

| 内容 | 位置 |
| --- | --- |
| 截图、视频、测量数据 | [`shots` 分支的 `latest/`](../../tree/shots/latest)，每个技术一个文件夹 |
| 所有技术的数据表 | [`latest/SUMMARY.md`](../../blob/shots/latest/SUMMARY.md) |
| 所有窗口截图一览 | [`latest/overview.png`](../../blob/shots/latest/overview.png) |
| 编译好的程序（zip，解压即可运行） | [Releases → nova-builds](../../releases/tag/nova-builds) |

每个技术文件夹里的文件：

| 文件 | 说明 |
| --- | --- |
| `<名字>.png` | 窗口截图（Windows 11，只有窗口） |
| `<名字>-pad.png` | 窗口四周带 48 像素壁纸，适合直接放进视频 |
| `<名字>-full.png` | 整个屏幕 1920×1080 |
| `<名字>.mp4` | 操作视频：悬停、点开关、拖滑块（30 fps，和 `-pad.png` 同样大小） |
| `<名字>-x64*.png` | 在 Windows Server 2025（x64）上测数据时顺便截的图 |
| `<名字>-metrics.json` | 启动时间、内存、体积 |
| `build.log` | 编译记录 |

## 目录

| 目录 | 技术 |
| --- | --- |
| `apps/win32` | Win32 API（C++，现代样式 + 经典主题） |
| `apps/mfc` | MFC（C++，Feature Pack 视觉管理器） |
| `apps/qt` | Qt Widgets（C++） |
| `apps/winforms` | WinForms（C#） |
| `apps/wpf` | WPF（C#/XAML） |
| `apps/electron` | Electron（HTML/CSS/JS） |
| `apps/imgui` | Dear ImGui（C++，Direct3D 11） |
| `apps/uwp` | UWP（C#/XAML） |
| `apps/avalonia` | Avalonia（C#/XAML） |
| `apps/winui3` | WinUI 3 / Windows App SDK（C#/XAML） |
| `apps/flutter` | Flutter（Dart） |
| `apps/maui` | .NET MAUI（C#/XAML） |
| `apps/tauri` | Tauri（Rust + 网页） |
| `apps/web-shared` | Electron 和 Tauri 共用的网页界面 |

## 怎么生成的

`.github/workflows/shots.yml`：

1. **build**（`windows-2025`，x64）：运行 `apps/<技术>/build.ps1` 编译，输出 `apps/<技术>/dist/`；然后启动程序测数据。
2. **capture**（`windows-11-arm`，真正的 Windows 11）：把同一个 x64 程序拿过去运行（Windows 11 自带 x64 转译），
   `tools/setup-desktop.ps1` 把桌面整理干净（1920×1080、系统壁纸、关掉开机弹窗），
   `tools/capture.ps1` 截图，再用 UI Automation 找到开关和滑块，用真实的鼠标事件操作，ffmpeg 录屏。
3. **collect**：结果提交到 `shots` 分支，编译好的程序打包上传到 Releases。

只想重新跑某几个技术时，在 `ci-apps.txt` 里写它们的目录名（每行一个）再推送；写 `all` 或留空就是全部。

## 说明

- 这些虚拟机没有显卡，所以 WinUI 3 / UWP / Avalonia 的 Mica、亚克力半透明效果会退回成纯色背景。真电脑上会透出一点壁纸颜色。
  想在视频里展示这个效果，用 Releases 里的程序在自己电脑上录。
- 没有显卡也意味着动画是软件渲染的，偶尔会掉帧。录得不满意的技术，同样可以用 Releases 里的程序自己录（比如用 OBS）。
- Dear ImGui 和 Flutter 不向系统提供控件信息，录屏脚本用的是程序自己报告的坐标（ImGui）或量好的坐标（Flutter）。
- MFC 的复选框用的是普通复选框：Office 2007 皮肤画复选框要靠资源图片，在 Win11 上会退回到一种不显示对勾的画法。
- Delphi 需要注册账号才能下载编译器，没有做。
- `-full.png` 右下角的 “Test Mode” 水印是虚拟机自带的，视频建议用 `-pad.png` 和 `.mp4`。
- Win32 经典版的 `win32-classic-2000`，是程序启动时把系统颜色设成 Windows 2000 经典配色后截的，程序本身没有任何自绘。
