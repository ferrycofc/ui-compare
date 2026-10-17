# 测量结果（GitHub windows-2025，x64，1920x1080，100% 缩放）

- 体积：发布文件夹的总大小（自带运行库，拷到干净的 Windows 11 就能运行）
- 内存：窗口打开后几秒的专用工作集（任务管理器“内存”那一列），多进程的加在一起
- 测试机没有显卡：用 Direct3D / OpenGL / Skia 自己画界面的程序（Dear ImGui、Flutter、Avalonia、WPF、WinUI 等）会退回软件渲染，内存和 CPU 会比真电脑上高一些
- 窗口出现：从启动程序到窗口出现的时间，第二、三次启动（热启动）的平均值；第一次（冷启动）的时间在 metrics.json 的 startup_first_ms
- 界面就绪：同样两次启动里，从启动到界面上的文字都能被读到（网页类程序窗口先出现、内容后加载，这一项更公平）；ImGui、Flutter 不向系统提供控件信息，没有这一项

| 技术 | 年份 | 版本 | 体积 | 文件数 | 内存 | 进程数 | 窗口出现 | 界面就绪 | 视频 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Win32 API | 1993 | win32-classic-2000 | 276 KB | 2 | 1.7 MB | 1 | 76 ms | 108 ms | 有 |
| Win32 API | 1993 | win32-classic | 276 KB | 2 | 1.8 MB | 1 | 60 ms | 96 ms | 有 |
| Win32 API | 1993 | win32 | 276 KB | 2 | 1.7 MB | 1 | 53 ms | 182 ms | 有 |
| MFC | 1992 | mfc | 6.2 MB | 6 | 4.5 MB | 1 | 231 ms | 317 ms | 有 |
| Qt Widgets | 1995 | qt | 26.8 MB | 25 | 22.6 MB | 1 | 322 ms | 419 ms | 有 |
| WinForms | 2002 | winforms | 159.9 MB | 463 | 7.6 MB | 1 | 118 ms | 215 ms | 有 |
| WPF | 2006 | wpf | 159.9 MB | 463 | 32.4 MB | 1 | 442 ms | 660 ms | 有 |
| Dear ImGui | 2014 | imgui | 614 KB | 1 | 63.0 MB | 1 | 34 ms | — | 有 |
| UWP | 2015 | uwp | 6.5 MB | 4 | 12.4 MB | 1 | 282 ms | 552 ms | 有 |
| Avalonia | 2016 | avalonia | 94.0 MB | 214 | 43.6 MB | 1 | 805 ms | 1130 ms | 有 |
| WinUI 3 | 2021 | winui3 | 208.2 MB | 503 | 43.6 MB | 1 | 446 ms | 681 ms | 有 |
| Flutter | 2022 | flutter | 26.8 MB | 20 | 67.6 MB | 1 | 1405 ms | — | 有 |
| .NET MAUI | 2022 | maui | 227.9 MB | 538 | 55.7 MB | 1 | 422 ms | 713 ms | 有 |
| Tauri | 2022 | tauri | 3.0 MB | 1 | 66.8 MB | 7 | 36 ms | 656 ms | 有 |
