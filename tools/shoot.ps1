# 启动程序，等窗口出现，把窗口放到屏幕正中，截图，并测启动时间、内存、体积。
param(
  [Parameter(Mandatory)] [string]$Exe,
  [Parameter(Mandatory)] [string]$Name,
  [string]$OutDir = "out",
  [string]$Arguments = "",
  [string]$SizePath = "",        # 发布体积按这个文件或文件夹算，默认是 exe 所在文件夹
  [string]$TitlePrefix = "Nova",
  [int]$Settle = 6,
  [int]$Timeout = 90
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Win {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW")] public static extern bool GetWorkArea(uint a, uint b, out RECT r, uint c);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);

  public static IntPtr Find(string prefix, out string title) {
    IntPtr found = IntPtr.Zero; string t = null;
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
      if (sb.ToString().StartsWith(prefix)) { found = h; t = sb.ToString(); return false; }
      return true;
    }, IntPtr.Zero);
    title = t; return found;
  }
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  // 把桌面上其它窗口（比如运行器的控制台）都最小化，截图里只留我们的窗口
  public static string MinimizeOthers() {
    var done = new StringBuilder();
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      var c = new StringBuilder(256); GetClassName(h, c, 256);
      string cls = c.ToString();
      if (cls == "Shell_TrayWnd" || cls == "Shell_SecondaryTrayWnd" || cls == "Progman" || cls == "WorkerW") return true;
      RECT r; GetWindowRect(h, out r);
      if (r.R - r.L < 50 || r.B - r.T < 50) return true;
      var t = new StringBuilder(256); GetWindowText(h, t, 256);
      if (t.ToString().StartsWith("Nova")) return true;
      ShowWindow(h, 6);
      done.Append(cls + " '" + t + "'; ");
      return true;
    }, IntPtr.Zero);
    return done.ToString();
  }
  public static RECT Frame(IntPtr h) {
    RECT r;
    if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))) != 0) GetWindowRect(h, out r);
    return r;
  }
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
  // 用鼠标点一下标题栏空白处来激活窗口（不用键盘，避免控件显示键盘焦点框），再把鼠标移到右上角
  public static void Front(IntPtr h) {
    ShowWindow(h, 9);
    SetForegroundWindow(h);
    RECT f = Frame(h);
    SetCursorPos(f.L + (f.R - f.L) * 3 / 5, f.T + 14);
    mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero); mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(200);
    SetCursorPos(GetSystemMetrics(0) - 20, 8);
    mouse_event(0x0001, 1, 0, 0, UIntPtr.Zero);
  }
}
"@
[Win]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Drawing

$Exe = (Resolve-Path $Exe).Path
if (-not $SizePath) { $SizePath = Split-Path $Exe }
Write-Host "Launching $Exe $Arguments"

[Win]::keybd_event(0x1B, 0, 0, [UIntPtr]::Zero); [Win]::keybd_event(0x1B, 0, 2, [UIntPtr]::Zero)   # 收起可能弹出的开始菜单
Start-Sleep -Milliseconds 300
Write-Host "Minimized: $([Win]::MinimizeOthers())"
Start-Sleep -Milliseconds 500

# 把鼠标移到角落，避免停在按钮上出现悬停效果
[Win]::SetCursorPos(1900, 8) | Out-Null
[Win]::mouse_event(0x0001, 1, 0, 0, [UIntPtr]::Zero)

$sw = [Diagnostics.Stopwatch]::StartNew()
$startArgs = @{ FilePath = $Exe; PassThru = $true; WorkingDirectory = (Split-Path $Exe) }
if ($Arguments) { $startArgs.ArgumentList = $Arguments }
$proc = Start-Process @startArgs

$hwnd = [IntPtr]::Zero; $title = $null
while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
  $hwnd = [Win]::Find($TitlePrefix, [ref]$title)
  if ($hwnd -ne [IntPtr]::Zero) { break }
  if ($proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 20) { break }
  Start-Sleep -Milliseconds 20
}
$startupMs = [int]$sw.Elapsed.TotalMilliseconds
if ($hwnd -eq [IntPtr]::Zero) {
  Write-Host "::error::No window titled '$TitlePrefix*' appeared (process exited: $($proc.HasExited), code: $(if ($proc.HasExited) { $proc.ExitCode }))"
  $crash = Join-Path (Split-Path $Exe) 'crash.txt'
  if (Test-Path $crash) { Get-Content $crash | Write-Host; Copy-Item $crash (Join-Path $OutDir "$Name-crash.txt") }
  Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddMinutes(-5) } -MaxEvents 10 -ErrorAction SilentlyContinue |
    Where-Object { $_.LevelDisplayName -in 'Error', 'Critical' } |
    ForEach-Object { Write-Host "--- $($_.ProviderName): $($_.Message)" }
  $bmp = New-Object System.Drawing.Bitmap([Win]::GetSystemMetrics(0), [Win]::GetSystemMetrics(1))
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen(0, 0, 0, 0, $bmp.Size); $g.Dispose()
  $bmp.Save((Join-Path $OutDir "$Name-FAILED.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  exit 1
}
Write-Host "Window '$title' after $startupMs ms"

# 放到工作区正中（按 DWM 实际可见边框计算）
$wa = New-Object Win+RECT
[Win]::GetWorkArea(0x0030, 0, [ref]$wa, 0) | Out-Null
$wr = New-Object Win+RECT; [Win]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
$fr = [Win]::Frame($hwnd)
$fw = $fr.R - $fr.L; $fh = $fr.B - $fr.T
$x = $wa.L + [int](($wa.R - $wa.L - $fw) / 2) - ($fr.L - $wr.L)
$y = $wa.T + [int](($wa.B - $wa.T - $fh) / 2) - ($fr.T - $wr.T)
[Win]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001 -bor 0x0004) | Out-Null
[Win]::Front($hwnd)
Start-Sleep -Seconds $Settle
Write-Host "Minimized before capture: $([Win]::MinimizeOthers())"
[Win]::Front($hwnd)
Start-Sleep -Milliseconds 1200

# 截全屏，再裁出窗口（留一圈边，保留阴影）
$scrW = [Win]::GetSystemMetrics(0); $scrH = [Win]::GetSystemMetrics(1)
$bmp = New-Object System.Drawing.Bitmap($scrW, $scrH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
$g.Dispose()
$bmp.Save((Join-Path $OutDir "$Name-full.png"), [System.Drawing.Imaging.ImageFormat]::Png)

$fr = [Win]::Frame($hwnd)
$tight = New-Object System.Drawing.Rectangle($fr.L, $fr.T, ($fr.R - $fr.L), ($fr.B - $fr.T))
$bmp.Clone($tight, $bmp.PixelFormat).Save((Join-Path $OutDir "$Name-window.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$pad = 48
$l = [Math]::Max(0, $fr.L - $pad); $t = [Math]::Max(0, $fr.T - $pad)
$r = [Math]::Min($scrW, $fr.R + $pad); $b = [Math]::Min($scrH, $fr.B + $pad)
$bmp.Clone((New-Object System.Drawing.Rectangle($l, $t, ($r - $l), ($b - $t))), $bmp.PixelFormat).Save((Join-Path $OutDir "$Name-window-pad.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# 进程树（Electron / WebView2 会有子进程）
$owner = 0; [Win]::GetWindowThreadProcessId($hwnd, [ref]$owner) | Out-Null
$all = Get-CimInstance Win32_Process
$ids = [System.Collections.Generic.HashSet[int]]::new()
$queue = [System.Collections.Generic.Queue[int]]::new()
foreach ($root in @($proc.Id, [int]$owner)) { if ($ids.Add($root)) { $queue.Enqueue($root) } }
while ($queue.Count) {
  $cur = $queue.Dequeue()
  foreach ($c in ($all | Where-Object { $_.ParentProcessId -eq $cur })) { if ($ids.Add([int]$c.ProcessId)) { $queue.Enqueue([int]$c.ProcessId) } }
}
$perf = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | Where-Object { $ids.Contains([int]$_.IDProcess) }
$privateWs = ($perf | Measure-Object WorkingSetPrivate -Sum).Sum
$procs = $ids | ForEach-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }
$ws = ($procs | Measure-Object WorkingSet64 -Sum).Sum

if (Test-Path $SizePath -PathType Container) {
  $files = Get-ChildItem $SizePath -Recurse -File | Where-Object { $_.Extension -notin '.pdb', '.ilk', '.obj', '.exp', '.lib' }
  $size = ($files | Measure-Object Length -Sum).Sum; $fileCount = $files.Count
} else { $size = (Get-Item $SizePath).Length; $fileCount = 1 }

$metrics = [ordered]@{
  name            = $Name
  title           = $title
  startup_ms      = $startupMs
  memory_mb       = [Math]::Round($privateWs / 1MB, 1)
  working_set_mb  = [Math]::Round($ws / 1MB, 1)
  processes       = $ids.Count
  dist_size_mb    = [Math]::Round($size / 1MB, 2)
  dist_files      = $fileCount
  exe_size_kb     = [Math]::Round((Get-Item $Exe).Length / 1KB, 1)
  window          = "$($fr.R - $fr.L)x$($fr.B - $fr.T)"
}
$metrics | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $OutDir "$Name-metrics.json")
$metrics.GetEnumerator() | ForEach-Object { Write-Host ("{0,-16} {1}" -f $_.Key, $_.Value) }
if ($env:GITHUB_STEP_SUMMARY) {
  "| $Name | $startupMs ms | $($metrics.memory_mb) MB | $($metrics.processes) | $($metrics.dist_size_mb) MB ($fileCount files) |" | Add-Content $env:GITHUB_STEP_SUMMARY
}

foreach ($id in $ids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1
