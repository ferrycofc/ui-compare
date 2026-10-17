# 把系统 DLL 里的图标排成一张图（带编号），用来给 Win32 / WinForms 等挑系统自带图标。
param([string]$OutDir = "out", [string[]]$Dlls = @('imageres.dll', 'shell32.dll', 'ddores.dll'))
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force $OutDir | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class Ico {
  [DllImport("shell32.dll", CharSet = CharSet.Unicode)] public static extern uint ExtractIconEx(string f, int i, IntPtr[] large, IntPtr[] small, uint n);
  [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);
}
"@
foreach ($dll in $Dlls) {
  $path = Join-Path $env:WINDIR "System32\$dll"
  if (-not (Test-Path $path)) { continue }
  $count = [Ico]::ExtractIconEx($path, -1, $null, $null, 0)
  $cols = 24; $cell = 56; $rows = [Math]::Ceiling($count / $cols)
  $bmp = New-Object System.Drawing.Bitmap(($cols * $cell), ($rows * $cell))
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::White)
  $font = New-Object System.Drawing.Font('Segoe UI', 7)
  for ($i = 0; $i -lt $count; $i++) {
    $large = New-Object IntPtr[] 1
    [Ico]::ExtractIconEx($path, $i, $large, $null, 1) | Out-Null
    $x = ($i % $cols) * $cell; $y = [Math]::Floor($i / $cols) * $cell
    if ($large[0] -ne [IntPtr]::Zero) {
      $ic = [System.Drawing.Icon]::FromHandle($large[0])
      $g.DrawIcon($ic, $x + 12, $y + 4)
      [Ico]::DestroyIcon($large[0]) | Out-Null
    }
    $g.DrawString("$i", $font, [System.Drawing.Brushes]::Black, ($x + 2), ($y + 40))
  }
  $g.Dispose()
  $bmp.Save((Join-Path $OutDir "icons-$($dll -replace '\.dll$','').png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "$dll : $count icons"
}
