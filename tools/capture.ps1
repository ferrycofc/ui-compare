# 启动一个技术的程序：窗口居中、截图、（可选）测启动时间/内存/体积、（可选）用鼠标操作并录视频。
#
#   pwsh tools/capture.ps1 -App wpf -Dist apps/wpf/dist -OutDir out/wpf -Metrics
#   pwsh tools/capture.ps1 -App wpf -Dist dist/wpf -OutDir out/wpf -Video
#
# apps/<id>/app.json 说明见 SPEC.md。可以有 "variants"：同一个 dist 里截多个版本。
param(
  [Parameter(Mandatory)] [string]$App,
  [Parameter(Mandatory)] [string]$Dist,
  [Parameter(Mandatory)] [string]$OutDir,
  [switch]$Metrics,
  [switch]$Video,
  [string]$Suffix = ""
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$Dist = (Resolve-Path $Dist).Path
$cfg = Get-Content (Join-Path $PSScriptRoot "../apps/$App/app.json") -Raw -Encoding utf8 | ConvertFrom-Json

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class Win {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW")] public static extern bool GetWorkArea(uint a, uint b, out RECT r, uint c);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);

  static string Text(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
  static string Cls(IntPtr h) { var sb = new StringBuilder(256); GetClassName(h, sb, 256); return sb.ToString(); }

  public static IntPtr Find(string prefix, out string title) {
    IntPtr found = IntPtr.Zero; string t = null;
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      string s = Text(h);
      if (s.StartsWith(prefix)) { RECT r; GetWindowRect(h, out r); if (r.R - r.L > 200) { found = h; t = s; return false; } }
      return true;
    }, IntPtr.Zero);
    title = t; return found;
  }
  // UWP 的窗口外壳属于 ApplicationFrameHost，真正的程序进程在 CoreWindow 子窗口上
  public static uint ContentPid(IntPtr h) {
    uint pid; GetWindowThreadProcessId(h, out pid);
    uint inner = 0;
    EnumChildWindows(h, (c, l) => { if (Cls(c) == "Windows.UI.Core.CoreWindow") { GetWindowThreadProcessId(c, out inner); return false; } return true; }, IntPtr.Zero);
    return inner != 0 ? inner : pid;
  }
  public static RECT Frame(IntPtr h) {
    RECT r;
    if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))) != 0) GetWindowRect(h, out r);
    return r;
  }
  public static string MinimizeOthers(IntPtr keep) {
    var done = new StringBuilder();
    EnumWindows((h, l) => {
      if (h == keep || !IsWindowVisible(h)) return true;
      string cls = Cls(h);
      if (cls == "Shell_TrayWnd" || cls == "Shell_SecondaryTrayWnd" || cls == "Progman" || cls == "WorkerW") return true;
      RECT r; GetWindowRect(h, out r);
      if (r.R - r.L < 50 || r.B - r.T < 50) return true;
      if (Text(h).StartsWith("Nova")) return true;
      ShowWindow(h, 6);
      done.Append(cls + " '" + Text(h) + "'; ");
      return true;
    }, IntPtr.Zero);
    return done.ToString();
  }

  // ---- 鼠标：用绝对坐标的真实输入事件，程序能收到悬停、按下、拖动 ----
  public static void MoveTo(int x, int y) {
    int w = GetSystemMetrics(0), hh = GetSystemMetrics(1);
    mouse_event(0x8001, (int)Math.Round(x * 65535.0 / (w - 1)), (int)Math.Round(y * 65535.0 / (hh - 1)), 0, UIntPtr.Zero);
  }
  public static void Glide(int x, int y, int ms) {
    POINT p; GetCursorPos(out p);
    int steps = Math.Max(1, ms / 15);
    for (int i = 1; i <= steps; i++) {
      double t = (double)i / steps;
      t = t < 0.5 ? 2 * t * t : 1 - Math.Pow(-2 * t + 2, 2) / 2;
      MoveTo((int)Math.Round(p.X + (x - p.X) * t), (int)Math.Round(p.Y + (y - p.Y) * t));
      Thread.Sleep(15);
    }
  }
  public static void Down() { mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero); }
  public static void Up() { mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero); }
  public static void Click() { Down(); Thread.Sleep(80); Up(); }
  public static void Escape() { keybd_event(0x1B, 0, 0, UIntPtr.Zero); keybd_event(0x1B, 0, 2, UIntPtr.Zero); }

  // 点一下标题栏空白处激活窗口（不用键盘，避免出现键盘焦点框），然后把鼠标移到右上角
  public static void Front(IntPtr h) {
    ShowWindow(h, 9);
    SetForegroundWindow(h);
    RECT f = Frame(h);
    MoveTo(f.L + (f.R - f.L) * 3 / 5, f.T + 14);
    Click();
    Thread.Sleep(200);
    MoveTo(GetSystemMetrics(0) - 20, 8);
  }
}
"@
[Win]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$UIA = [System.Windows.Automation.AutomationElement]

function Save-Screen([string]$name, $frame) {
  $sw = [Win]::GetSystemMetrics(0); $sh = [Win]::GetSystemMetrics(1)
  $bmp = New-Object System.Drawing.Bitmap($sw, $sh)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen(0, 0, 0, 0, $bmp.Size); $g.Dispose()
  $bmp.Save((Join-Path $OutDir "$name-full.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  if ($frame) {
    $w = $frame.R - $frame.L; $h = $frame.B - $frame.T
    $bmp.Clone((New-Object System.Drawing.Rectangle($frame.L, $frame.T, $w, $h)), $bmp.PixelFormat).Save((Join-Path $OutDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $r = Get-PadRect $frame
    $bmp.Clone((New-Object System.Drawing.Rectangle($r.X, $r.Y, $r.W, $r.H)), $bmp.PixelFormat).Save((Join-Path $OutDir "$name-pad.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  }
  $bmp.Dispose()
}

# 窗口四周留 48 像素（宽高取偶数，视频编码需要）
function Get-PadRect($frame) {
  $pad = 48
  $sw = [Win]::GetSystemMetrics(0); $sh = [Win]::GetSystemMetrics(1)
  $l = [Math]::Max(0, $frame.L - $pad); $t = [Math]::Max(0, $frame.T - $pad)
  $r = [Math]::Min($sw, $frame.R + $pad); $b = [Math]::Min($sh, $frame.B + $pad)
  $w = $r - $l; $h = $b - $t
  if ($w % 2) { $w-- }; if ($h % 2) { $h-- }
  [pscustomobject]@{ X = $l; Y = $t; W = $w; H = $h }
}

function Start-Variant($v) {
  if ($cfg.launch -and $cfg.launch -like 'appx:*') {
    $spec = $cfg.launch.Substring(5); $pkg, $appId = $spec.Split('!')
    $p = Get-AppxPackage -Name $pkg | Select-Object -First 1
    if (-not $p) { throw "Package $pkg is not installed" }
    Start-Process explorer.exe "shell:AppsFolder\$($p.PackageFamilyName)!$appId"
    return $null
  }
  $exe = Join-Path $Dist $v.exe
  $a = @{ FilePath = $exe; PassThru = $true; WorkingDirectory = (Split-Path $exe) }
  if ($v.args) { $a.ArgumentList = $v.args }
  return Start-Process @a
}

function Stop-Tree([int[]]$ids) {
  foreach ($id in $ids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
}

function Get-Tree([int[]]$roots) {
  $all = Get-CimInstance Win32_Process
  $ids = [System.Collections.Generic.HashSet[int]]::new()
  $queue = [System.Collections.Generic.Queue[int]]::new()
  foreach ($r in $roots) { if ($r -and $ids.Add($r)) { $queue.Enqueue($r) } }
  while ($queue.Count) {
    $cur = $queue.Dequeue()
    foreach ($c in ($all | Where-Object { $_.ParentProcessId -eq $cur })) { if ($ids.Add([int]$c.ProcessId)) { $queue.Enqueue([int]$c.ProcessId) } }
  }
  return ,$ids
}

# ---------- UI Automation：按名字找开关和滑块 ----------
function Get-Center($e) {
  $r = $e.Current.BoundingRectangle
  if ($r.IsEmpty -or $r.Width -le 0) { return $null }
  [pscustomobject]@{ X = [int]($r.X + $r.Width / 2); Y = [int]($r.Y + $r.Height / 2); L = [int]$r.X; W = [int]$r.Width; T = [int]$r.Y; H = [int]$r.Height }
}

function Find-ByName($root, [string]$name) {
  $c = New-Object System.Windows.Automation.PropertyCondition($UIA::NameProperty, $name)
  return @($root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $c))
}

function Test-Toggle($e) {
  if ($e.GetCurrentPropertyValue($UIA::IsTogglePatternAvailableProperty)) { return $true }
  $ct = $e.Current.ControlType
  return ($ct -eq [System.Windows.Automation.ControlType]::CheckBox)
}

function Find-Toggle($root, [string]$name) {
  $hits = Find-ByName $root $name
  foreach ($e in $hits) {
    if (Test-Toggle $e) { $c = Get-Center $e; if ($c -and $c.W -lt 120) { return $c } }
  }
  # 开关本身没有名字：找同一行、在文字右边、最靠右的那个开关/复选框
  $label = $hits | ForEach-Object { Get-Center $_ } | Where-Object { $_ } | Select-Object -First 1
  if (-not $label) { return $null }
  $best = $null
  foreach ($e in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
    if (-not (Test-Toggle $e)) { continue }
    $c = Get-Center $e
    if ($c -and [Math]::Abs($c.Y - $label.Y) -le 16 -and $c.X -gt $label.X -and $c.W -lt 120) { if (-not $best -or $c.X -gt $best.X) { $best = $c } }
  }
  return $best
}

# 把控件树写到文件里，方便排查找不到控件的问题
function Save-Tree($hwnd, [string]$path) {
  try {
    $root = $UIA::FromHandle($hwnd)
    $lines = foreach ($e in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
      $c = $e.Current; $r = $c.BoundingRectangle
      "{0}`t{1}`t{2}`t{3}`t{4},{5},{6},{7}`ttoggle={8} range={9}" -f $c.ControlType.ProgrammaticName, $c.Name, $c.AutomationId, $c.ClassName,
        [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height,
        $e.GetCurrentPropertyValue($UIA::IsTogglePatternAvailableProperty), $e.GetCurrentPropertyValue($UIA::IsRangeValuePatternAvailableProperty)
    }
    $lines | Select-Object -First 800 | Set-Content -Encoding utf8 $path
  } catch { "UIA dump failed: $_" | Set-Content -Encoding utf8 $path }
}

function Find-Slider($root, [string]$name) {
  $hits = Find-ByName $root $name
  $el = $hits | Where-Object { $_.GetCurrentPropertyValue($UIA::IsRangeValuePatternAvailableProperty) } | Select-Object -First 1
  if (-not $el) {
    $label = $hits | ForEach-Object { Get-Center $_ } | Where-Object { $_ } | Select-Object -First 1
    if (-not $label) { return $null }
    $rc = New-Object System.Windows.Automation.PropertyCondition($UIA::IsRangeValuePatternAvailableProperty, $true)
    $bestD = 1e9
    foreach ($e in $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $rc)) {
      $c = Get-Center $e
      if ($c -and $c.Y -gt $label.Y -and ($c.Y - $label.Y) -lt 80 -and $c.W -gt 100) { $d = $c.Y - $label.Y; if ($d -lt $bestD) { $bestD = $d; $el = $e } }
    }
  }
  if (-not $el) { return $null }
  $c = Get-Center $el
  $rv = $el.GetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern).Current
  $pad = if ($cfg.sliderPad) { [int]$cfg.sliderPad } else { 10 }
  $frac = if ($rv.Maximum -gt $rv.Minimum) { ($rv.Value - $rv.Minimum) / ($rv.Maximum - $rv.Minimum) } else { 0.5 }
  [pscustomobject]@{ X = [int]($c.L + $pad + ($c.W - 2 * $pad) * $frac); Y = $c.Y; L = $c.L + $pad; W = $c.W - 2 * $pad }
}

function Get-Targets($hwnd, $frame) {
  $t = @{}
  $toggles = '开机自启', '自动更新', '低延迟模式', 'HDR'
  $sliders = '亮度'
  for ($try = 0; $try -lt 4; $try++) {
    try {
      $root = $UIA::FromHandle($hwnd)
      foreach ($n in $toggles) { if (-not $t[$n]) { $c = Find-Toggle $root $n; if ($c) { $t[$n] = $c } } }
      foreach ($n in $sliders) { if (-not $t[$n]) { $c = Find-Slider $root $n; if ($c) { $t[$n] = $c } } }
      $lbl = Find-ByName $root '开机自启' | ForEach-Object { Get-Center $_ } | Where-Object { $_ } | Sort-Object X | Select-Object -First 1
      if ($lbl -and -not $t['label']) { $t['label'] = $lbl }
    } catch { Write-Host "UIA error: $_" }
    if ($t.Count -ge 6) { break }
    Start-Sleep -Seconds 1
  }
  # 不支持 UI Automation 的（比如 Dear ImGui）：用 app.json 里写好的坐标
  if ($cfg.points) {
    foreach ($p in $cfg.points.PSObject.Properties) {
      $key = if ($p.Name -eq '常规选项') { 'label' } else { $p.Name }
      if (-not $t[$key]) {
        $x = $frame.L + [int]$p.Value[0]; $y = $frame.T + [int]$p.Value[1]
        $t[$key] = [pscustomobject]@{ X = $x; Y = $y; L = $x; W = 0 }
        if ($key -eq '亮度' -and $p.Value.Count -ge 4) { $t[$key].L = $frame.L + [int]$p.Value[2]; $t[$key].W = [int]$p.Value[3] }
      }
    }
  }
  return $t
}

function Invoke-Demo($t, $frame) {
  $cx = [int](($frame.L + $frame.R) / 2); $cy = [int](($frame.T + $frame.B) / 2)
  [Win]::MoveTo($cx + 120, $frame.B - 60)
  Start-Sleep -Milliseconds 900
  if ($t['label']) {
    [Win]::Glide($t['label'].X, $t['label'].Y, 700)          # 从第一行慢慢滑过几行（悬停效果）
    Start-Sleep -Milliseconds 200
    [Win]::Glide($t['label'].X + 40, $t['label'].Y + 200, 900)
  }
  foreach ($name in '自动更新', '开机自启') {
    if ($t[$name]) { [Win]::Glide($t[$name].X, $t[$name].Y, 550); Start-Sleep -Milliseconds 250; [Win]::Click(); Start-Sleep -Milliseconds 700 }
  }
  $s = $t['亮度']
  if ($s) {
    [Win]::Glide($s.X, $s.Y, 700); Start-Sleep -Milliseconds 250
    [Win]::Down(); Start-Sleep -Milliseconds 120
    if ($s.W -gt 0) { $to40 = [int]($s.L + $s.W * 0.40); $to65 = [int]($s.L + $s.W * 0.65) } else { $to40 = $s.X - 150; $to65 = $s.X - 60 }
    [Win]::Glide($to40, $s.Y, 800); Start-Sleep -Milliseconds 250
    [Win]::Glide($to65, $s.Y, 600); Start-Sleep -Milliseconds 120
    [Win]::Up(); Start-Sleep -Milliseconds 600
  }
  foreach ($name in 'HDR', '低延迟模式') {
    if ($t[$name]) { [Win]::Glide($t[$name].X, $t[$name].Y, 600); Start-Sleep -Milliseconds 250; [Win]::Click(); Start-Sleep -Milliseconds 700 }
  }
  [Win]::Glide($cx + 120, $frame.B - 60, 700)
  Start-Sleep -Milliseconds 900
}

function Record-Demo([string]$name, $hwnd, $frame) {
  $ff = if ($env:FFMPEG) { $env:FFMPEG } else { (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source }
  if (-not $ff) { Write-Host "::warning::ffmpeg not found, skipping video"; return }
  $t = Get-Targets $hwnd $frame
  Save-Tree $hwnd (Join-Path $OutDir "$name-uia.txt")
  $found = ($t.Keys | Sort-Object) -join ', '
  Write-Host "Demo targets: $found"
  $t.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value.X),$($_.Value.Y)" } | Set-Content -Encoding utf8 (Join-Path $OutDir "$name-targets.txt")

  $r = Get-PadRect $frame
  $raw = Join-Path $env:RUNNER_TEMP "$name-raw.mkv"
  $psi = New-Object System.Diagnostics.ProcessStartInfo $ff
  $psi.Arguments = "-y -loglevel warning -stats -f gdigrab -framerate 30 -draw_mouse 1 -offset_x $($r.X) -offset_y $($r.Y) -video_size $($r.W)x$($r.H) -i desktop -c:v libx264 -preset ultrafast -qp 0 `"$raw`""
  $psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardError = $true
  $proc = [System.Diagnostics.Process]::Start($psi)
  $errTask = $proc.StandardError.ReadToEndAsync()
  Start-Sleep -Milliseconds 1500
  try { Invoke-Demo $t $frame } finally {
    $proc.StandardInput.Write('q'); $proc.StandardInput.Flush()
    if (-not $proc.WaitForExit(20000)) { $proc.Kill() }
  }
  $errTask.Result | Set-Content -Encoding utf8 (Join-Path $OutDir "$name-ffmpeg.log")
  $mp4 = Join-Path $OutDir "$name.mp4"
  & $ff -y -loglevel error -i $raw -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart $mp4
  Remove-Item $raw -ErrorAction SilentlyContinue
  if (Test-Path $mp4) { Write-Host "Video: $mp4 ($([Math]::Round((Get-Item $mp4).Length / 1MB, 1)) MB)" }
}

# ---------- 主流程 ----------
if ($cfg.install) {
  Write-Host "Installing via $($cfg.install)"
  & (Join-Path $Dist $cfg.install)
  if (-not $?) { throw "install failed" }
}

$variants = if ($cfg.variants) { $cfg.variants } else { @([pscustomobject]@{ name = $cfg.id; exe = $cfg.exe; args = $cfg.args }) }
$settle = if ($cfg.settle) { [int]$cfg.settle } else { 6 }
$failed = $false

foreach ($v in $variants) {
  $name = "$($v.name)$Suffix"
  Write-Host "=== $name"
  [Win]::Escape(); Start-Sleep -Milliseconds 300
  Write-Host "Minimized: $([Win]::MinimizeOthers([IntPtr]::Zero))"
  [Win]::MoveTo(1900, 8)

  $before = @(Get-Process | ForEach-Object Id)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $proc = Start-Variant $v
  $hwnd = [IntPtr]::Zero; $title = $null
  while ($sw.Elapsed.TotalSeconds -lt 120) {
    $hwnd = [Win]::Find('Nova', [ref]$title)
    if ($hwnd -ne [IntPtr]::Zero) { break }
    if ($proc -and $proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 20) { break }
    Start-Sleep -Milliseconds 20
  }
  $startupMs = [int]$sw.Elapsed.TotalMilliseconds
  if ($hwnd -eq [IntPtr]::Zero) {
    Write-Host "::error::$name : no window titled 'Nova*' (exited: $($proc.HasExited) code: $(if ($proc -and $proc.HasExited) { $proc.ExitCode }))"
    $crash = Join-Path $Dist 'crash.txt'; if (Test-Path $crash) { Get-Content $crash | Write-Host }
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddMinutes(-3) } -MaxEvents 8 -ErrorAction SilentlyContinue |
      Where-Object { $_.LevelDisplayName -in 'Error', 'Critical' } | ForEach-Object { Write-Host "--- $($_.ProviderName): $($_.Message)" }
    Save-Screen "$name-FAILED" $null
    if ($proc) { Stop-Tree (Get-Tree @($proc.Id)) }
    $failed = $true; continue
  }
  Write-Host "Window '$title' after $startupMs ms"

  # 放到工作区正中（按 DWM 实际可见边框算）
  $wa = New-Object Win+RECT; [Win]::GetWorkArea(0x0030, 0, [ref]$wa, 0) | Out-Null
  $wr = New-Object Win+RECT; [Win]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
  $fr = [Win]::Frame($hwnd); $fw = $fr.R - $fr.L; $fh = $fr.B - $fr.T
  $x = $wa.L + [int](($wa.R - $wa.L - $fw) / 2) - ($fr.L - $wr.L)
  $y = $wa.T + [int](($wa.B - $wa.T - $fh) / 2) - ($fr.T - $wr.T)
  [Win]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001 -bor 0x0004) | Out-Null
  [Win]::Front($hwnd)
  Start-Sleep -Seconds $settle
  Write-Host "Minimized before capture: $([Win]::MinimizeOthers($hwnd))"
  [Win]::Front($hwnd)
  Start-Sleep -Milliseconds 1500
  $fr = [Win]::Frame($hwnd)
  Save-Screen $name $fr

  $roots = @([int][Win]::ContentPid($hwnd)); if ($proc) { $roots += $proc.Id }
  $ids = Get-Tree $roots

  if ($Metrics) {
    $perf = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | Where-Object { $ids.Contains([int]$_.IDProcess) }
    $privateWs = ($perf | Measure-Object WorkingSetPrivate -Sum).Sum
    $ws = ($ids | ForEach-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue } | Measure-Object WorkingSet64 -Sum).Sum
    $files = Get-ChildItem $Dist -Recurse -File | Where-Object { $_.Extension -notin '.pdb', '.ilk', '.obj', '.exp', '.lib', '.cer', '.ps1' -and $_.Name -ne 'crash.txt' }
    $size = ($files | Measure-Object Length -Sum).Sum
    $m = [ordered]@{
      name = $v.name; tech = $cfg.tech; title = $title; startup_ms = $startupMs
      memory_mb = [Math]::Round($privateWs / 1MB, 1); working_set_mb = [Math]::Round($ws / 1MB, 1); processes = $ids.Count
      dist_size_mb = [Math]::Round($size / 1MB, 2); dist_files = $files.Count; window = "$($fr.R - $fr.L)x$($fr.B - $fr.T)"
    }
    $m | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $OutDir "$($v.name)-metrics.json")
    $m.GetEnumerator() | ForEach-Object { Write-Host ("{0,-16} {1}" -f $_.Key, $_.Value) }
  }

  if ($Video) {
    try { Record-Demo $name $hwnd $fr } catch { Write-Host "::warning::video failed for ${name}: $_" }
  }

  Stop-Tree $ids
  if ($cfg.launch) { Get-Process | Where-Object { $_.Id -notin $before -and $_.Id -in $ids } | Stop-Process -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 1
}
if ($failed) { exit 1 }
