# 测量结果（GitHub windows-2025，x64，1920x1080，100% 缩放）

- 体积：发布文件夹的总大小（自带运行库，拷到干净的 Windows 11 就能运行）
- 内存：窗口打开后几秒的专用工作集（任务管理器“内存”那一列），多进程的加在一起
- 启动：从启动程序到窗口出现的时间（第一次启动，包含磁盘读取）

| 技术 | 年份 | 版本 | 体积 | 文件数 | 内存 | 进程数 | 启动 | 视频 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Win32 API | 1993 | win32-classic-2000 | 276 KB | 2 | 1.7 MB | 1 | 76 ms | 有 |
| Win32 API | 1993 | win32-classic | 276 KB | 2 | 1.8 MB | 1 | 2924 ms | 有 |
| Win32 API | 1993 | win32 | 276 KB | 2 | 1.7 MB | 1 | 408 ms | 有 |
| WinForms | 2002 | winforms | 159.9 MB | 463 | 7.6 MB | 1 | 484 ms | 有 |
| WinUI 3 | 2021 | winui3 | 208.2 MB | 503 | 43.8 MB | 1 | 711 ms | 有 |

还没有结果：mfc、qt、wpf、electron、imgui、uwp、avalonia、flutter、maui、tauri
