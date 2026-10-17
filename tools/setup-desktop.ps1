# 准备 GitHub Actions 的 Windows 桌面：1920x1080、壁纸、透明效果、ClearType，并记录系统信息。
param(
  [string]$OutDir = "out",
  [int]$Width = 1920,
  [int]$Height = 1080
)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force $OutDir | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class Desk {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
    public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
    public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels;
    public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
    public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
  }
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int ChangeDisplaySettings(ref DEVMODE dm, int flags);
  [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SystemParametersInfoW")] static extern bool SpiStr(uint a, uint b, string c, uint d);
  [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW")] static extern bool SpiInt(uint a, uint b, IntPtr c, uint d);
  [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW")] static extern bool SpiGet(uint a, uint b, ref int c, uint d);
  [DllImport("dwmapi.dll")] static extern int DwmIsCompositionEnabled(out bool b);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);

  static DEVMODE New() { var d = new DEVMODE(); d.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE)); return d; }
  public static string Current() { var d = New(); EnumDisplaySettings(null, -1, ref d); return d.dmPelsWidth + "x" + d.dmPelsHeight + " " + d.dmBitsPerPel + "bpp"; }
  public static string Modes() {
    var s = new SortedSet<int>(); var d = New();
    var list = new List<string>();
    for (int i = 0; EnumDisplaySettings(null, i, ref d); i++) { string m = d.dmPelsWidth + "x" + d.dmPelsHeight; if (!list.Contains(m)) list.Add(m); }
    return string.Join(", ", list);
  }
  public static int SetRes(int w, int h) { var d = New(); EnumDisplaySettings(null, -1, ref d); d.dmPelsWidth = w; d.dmPelsHeight = h; d.dmFields = 0x80000 | 0x100000; return ChangeDisplaySettings(ref d, 1); }
  public static bool Wallpaper(string path) { return SpiStr(0x0014, 0, path, 3); }
  public static void FontSmoothing() {
    SpiInt(0x004B, 1, IntPtr.Zero, 3);          // SPI_SETFONTSMOOTHING
    SpiInt(0x200B, 0, (IntPtr)2, 3);            // SPI_SETFONTSMOOTHINGTYPE = ClearType
  }
  public static string Info() {
    int fs = 0, fst = 0, shadow = 0, ui = 0; bool comp;
    SpiGet(0x004A, 0, ref fs, 0); SpiGet(0x200A, 0, ref fst, 0); SpiGet(0x1024, 0, ref shadow, 0); SpiGet(0x103E, 0, ref ui, 0);
    DwmIsCompositionEnabled(out comp);
    return "fontSmoothing=" + fs + " smoothingType=" + fst + " dropShadow=" + shadow + " uiEffects=" + ui + " dwmComposition=" + comp;
  }
}
"@

[Desk]::SetProcessDPIAware() | Out-Null
$log = [System.Collections.Generic.List[string]]::new()
$os = Get-CimInstance Win32_OperatingSystem
$log.Add("OS: $($os.Caption) $($os.Version) build $($os.BuildNumber) $($os.OSArchitecture)")
$log.Add("Display before: $([Desk]::Current())")
$log.Add("Modes: $([Desk]::Modes())")

$set = $false
if (Get-Command Set-DisplayResolution -ErrorAction SilentlyContinue) {
  try { Set-DisplayResolution -Width $Width -Height $Height -Force -ErrorAction Stop; $set = $true; $log.Add("Set-DisplayResolution ok") } catch { $log.Add("Set-DisplayResolution failed: $_") }
}
if (-not $set) { $log.Add("ChangeDisplaySettings result: $([Desk]::SetRes($Width, $Height))") }
Start-Sleep -Seconds 2
$log.Add("Display after: $([Desk]::Current()) metrics $([Desk]::GetSystemMetrics(0))x$([Desk]::GetSystemMetrics(1))")

# 透明效果、ClearType
$p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
New-Item -Force $p -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty $p EnableTransparency 1 -Type DWord
[Desk]::FontSmoothing()
$log.Add("Effects: $([Desk]::Info())")

# 壁纸：用系统自带的
$wallDirs = @('C:\Windows\Web\Wallpaper', 'C:\Windows\Web\4K\Wallpaper')
$walls = foreach ($d in $wallDirs) { if (Test-Path $d) { Get-ChildItem $d -Recurse -Include *.jpg, *.png -ErrorAction SilentlyContinue } }
$log.Add("Wallpapers found:")
foreach ($w in $walls) { $log.Add("  $($w.FullName) $([math]::Round($w.Length/1KB))KB") }
$pick = $walls | Where-Object { $_.Name -eq 'img0.jpg' } | Select-Object -First 1
if (-not $pick) { $pick = $walls | Sort-Object Length -Descending | Select-Object -First 1 }
if ($pick) { $log.Add("Wallpaper set: $($pick.FullName) -> $([Desk]::Wallpaper($pick.FullName))") }

# 字体
foreach ($f in 'msyh.ttc', 'msyhbd.ttc', 'simsun.ttc', 'SegUIVar.ttf', 'segoeui.ttf', 'SegoeIcons.ttf', 'segmdl2.ttf', 'tahoma.ttf') {
  $log.Add("Font $f : $(Test-Path (Join-Path $env:WINDIR "Fonts\$f"))")
}
$log.Add("Culture: $((Get-Culture).Name) UI: $((Get-UICulture).Name)")

Start-Sleep -Seconds 2
Add-Type -AssemblyName System.Drawing
$sw = [Desk]::GetSystemMetrics(0); $sh = [Desk]::GetSystemMetrics(1)
$bmp = New-Object System.Drawing.Bitmap($sw, $sh)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$bmp.Save((Join-Path $OutDir '_desktop.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

$log | Set-Content -Encoding utf8 (Join-Path $OutDir '_system.txt')
$log | ForEach-Object { Write-Host $_ }
