"""汇总 latest/ 里所有技术的测量数据和截图：生成 SUMMARY.md 和 overview.png。"""
import json
import pathlib
import sys

from PIL import Image, ImageDraw

ORDER = ["win32", "mfc", "qt", "winforms", "wpf", "electron", "imgui", "uwp",
         "avalonia", "winui3", "flutter", "maui", "tauri"]
YEARS = {"win32": "1993", "mfc": "1992", "qt": "1995", "winforms": "2002", "wpf": "2006",
         "electron": "2013", "imgui": "2014", "uwp": "2015", "avalonia": "2016",
         "winui3": "2021", "flutter": "2022", "maui": "2022", "tauri": "2022"}

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "latest")
apps = sorted([p.name for p in root.iterdir() if p.is_dir()],
              key=lambda a: ORDER.index(a) if a in ORDER else 99)

rows = []
for app in apps:
    for m in sorted((root / app).glob("*-metrics.json")):
        d = json.loads(m.read_text(encoding="utf-8-sig"))
        shots = [p.name for p in (root / app).glob(f"{d['name']}*.png")]
        video = (root / app / f"{d['name']}.mp4").exists()
        rows.append((app, d, video))

lines = [
    "# 测量结果（GitHub windows-2025，x64，1920x1080，100% 缩放）",
    "",
    "- 体积：发布文件夹的总大小（自带运行库，拷到干净的 Windows 11 就能运行）",
    "- 内存：窗口打开后几秒的专用工作集（任务管理器“内存”那一列），多进程的加在一起",
    "- 窗口出现：从启动程序到窗口出现的时间，连续启动三次取中位数（第一次的时间在 metrics.json 的 startup_first_ms）",
    "- 界面就绪：从启动到界面上的文字都能被读到（网页类程序窗口先出现、内容后加载，这一项更公平）；ImGui 不支持辅助功能，没有这一项",
    "",
    "| 技术 | 年份 | 版本 | 体积 | 文件数 | 内存 | 进程数 | 窗口出现 | 界面就绪 | 视频 |",
    "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
]
for app, d, video in rows:
    size = d["dist_size_mb"]
    size_s = f"{size * 1024:.0f} KB" if size < 1 else f"{size:.1f} MB"
    lines.append(f"| {d['tech']} | {YEARS.get(app, '')} | {d['name']} | {size_s} | {d['dist_files']} | "
                 f"{d['memory_mb']} MB | {d['processes']} | {d['startup_ms']} ms | "
                 f"{str(d['ready_ms']) + ' ms' if d.get('ready_ms') else '—'} | {'有' if video else '—'} |")
missing = [a for a in ORDER if a not in apps]
if missing:
    lines += ["", "还没有结果：" + "、".join(missing)]
(root / "SUMMARY.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))

# 总览图：每个版本一张窗口截图（Windows 11 机器上截的）
tiles = []
for app in apps:
    for p in sorted((root / app).glob("*.png")):
        n = p.stem
        if n.endswith(("-full", "-pad", "-x64", "-FAILED")) or n.startswith("_") or "desktop" in str(p.parent.name):
            continue
        tiles.append((n, p))
if tiles:
    tw, th, cols = 453, 327, 4
    rows_n = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows_n * (th + 24)), "white")
    draw = ImageDraw.Draw(sheet)
    for i, (n, p) in enumerate(tiles):
        im = Image.open(p).convert("RGB")
        im.thumbnail((tw - 8, th - 8))
        x, y = (i % cols) * tw, (i // cols) * (th + 24)
        sheet.paste(im, (x + 4, y + 4))
        draw.text((x + 6, y + th + 4), n, fill="black")
    sheet.save(root / "overview.png")
