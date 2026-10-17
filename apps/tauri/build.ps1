# 构建 Tauri 版：复制共用网页 → npm install → 生成图标 → tauri build → apps/tauri/dist/Nova.exe
# 在仓库根目录用 pwsh 运行（脚本自己按所在目录找路径，从哪里运行都行）。Rust 首次编译约 5–10 分钟。
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$here   = $PSScriptRoot
$shared = Join-Path $here '..\web-shared'
$web    = Join-Path $here 'web'
$srcTauri = Join-Path $here 'src-tauri'
$dist   = Join-Path $here 'dist'
$tmp    = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }

Write-Host "Node $(& node -v)"
& cargo --version
if ($LASTEXITCODE -ne 0) { Write-Host '::error::cargo not found'; exit 1 }

# 1. 共用网页 → apps/tauri/web（tauri.conf.json 的 frontendDist 指向这里，会被嵌进 exe）
if (Test-Path $web) { Remove-Item $web -Recurse -Force }
New-Item -ItemType Directory -Force $web | Out-Null
Copy-Item (Join-Path $shared '*') $web -Recurse -Force

# 2. 画一个 512×512 的程序图标：紫色圆角方块 + 白色 “N”
Add-Type -AssemblyName System.Drawing
$png = Join-Path $tmp 'nova-icon.png'
$bmp = New-Object System.Drawing.Bitmap 512, 512, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Transparent)
$r = 112; $x = 16; $y = 16; $s = 480
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddArc($x, $y, $r, $r, 180, 90)
$path.AddArc($x + $s - $r, $y, $r, $r, 270, 90)
$path.AddArc($x + $s - $r, $y + $s - $r, $r, $r, 0, 90)
$path.AddArc($x, $y + $s - $r, $r, $r, 90, 90)
$path.CloseFigure()
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0x8B, 0x7C, 0xF6))
$g.FillPath($brush, $path)
$font = New-Object System.Drawing.Font 'Segoe UI', 220, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center
$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
$g.DrawString('N', $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 0, 512, 512), $fmt)
$g.Dispose()
$bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Push-Location $here
try {
  # 3. 安装 Tauri 命令行
  & npm.cmd install --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) { Write-Host '::error::npm install failed'; exit 1 }

  # 4. 由 PNG 生成全套图标（icon.ico 等）到 src-tauri/icons
  & npx.cmd tauri icon $png -o (Join-Path $srcTauri 'icons')
  if ($LASTEXITCODE -ne 0) { Write-Host '::error::tauri icon failed'; exit 1 }

  # 5. 编译发布版（不打安装包，只要 exe）
  & npx.cmd tauri build --no-bundle
  if ($LASTEXITCODE -ne 0) { Write-Host '::error::tauri build failed'; exit 1 }
}
finally {
  Pop-Location
}

# 6. exe → apps/tauri/dist/Nova.exe（Tauri 2 在 Windows/MSVC 上静态链接 WebView2Loader 和 VC 运行库，只需这一个文件）
$target = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $srcTauri 'target' }
$release = Join-Path $target 'release'
$exe = @('nova-tauri.exe', 'Nova.exe') | ForEach-Object { Join-Path $release $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exe) {
  Write-Host "::error::built exe not found in $release"
  Get-ChildItem $release -Filter *.exe -ErrorAction SilentlyContinue | Select-Object FullName | Out-Host
  exit 1
}

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force $dist | Out-Null
Copy-Item $exe (Join-Path $dist 'Nova.exe') -Force

Write-Host ("dist/Nova.exe: {0:N2} MB (from {1})" -f ((Get-Item (Join-Path $dist 'Nova.exe')).Length / 1MB), $exe)
exit 0
