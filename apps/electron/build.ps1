# 构建 Electron 版：复制共用网页 → npm install → @electron/packager 打包 → apps/electron/dist/Nova.exe
# 在仓库根目录用 pwsh 运行（脚本自己按所在目录找路径，从哪里运行都行）。
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$here   = $PSScriptRoot
$shared = Join-Path $here '..\web-shared'
$web    = Join-Path $here 'web'
$dist   = Join-Path $here 'dist'
$tmp    = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }

# Electron 40+ 和 @electron/packager 20 要求 Node >= 22.12；机器上的版本太旧就临时下载一个便携版
function Use-Node22 {
  $ok = $false
  try {
    $v = (& node -v).Trim().TrimStart('v').Split('.')
    $ok = ([int]$v[0] -gt 22) -or ([int]$v[0] -eq 22 -and [int]$v[1] -ge 12)
    Write-Host "Node $(& node -v)"
  } catch { }
  if ($ok) { return }

  $ver = 'v22.23.2'
  $dir = Join-Path $tmp "node-$ver-win-x64"
  if (-not (Test-Path (Join-Path $dir 'node.exe'))) {
    $zip = Join-Path $tmp "node-$ver-win-x64.zip"
    Write-Host "Downloading Node $ver"
    Invoke-WebRequest "https://nodejs.org/dist/$ver/node-$ver-win-x64.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp -Force
  }
  $env:Path = "$dir;$env:Path"
  Write-Host "Using portable Node $(& node -v)"
}

Use-Node22

# 1. 共用网页 → apps/electron/web
if (Test-Path $web) { Remove-Item $web -Recurse -Force }
New-Item -ItemType Directory -Force $web | Out-Null
Copy-Item (Join-Path $shared '*') $web -Recurse -Force

Push-Location $here
try {
  # 2. 安装依赖（electron + @electron/packager）
  & npm.cmd install --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) { Write-Host '::error::npm install failed'; exit 1 }

  # 3. 打包（输出放到临时目录，避免把上次的结果打进去）
  $out = Join-Path $tmp 'nova-electron-pack'
  if (Test-Path $out) { Remove-Item $out -Recurse -Force }
  & node pack.mjs $out
  if ($LASTEXITCODE -ne 0) { Write-Host '::error::electron packager failed'; exit 1 }
}
finally {
  Pop-Location
}

$appDir = Join-Path $out 'Nova-win32-x64'
if (-not (Test-Path (Join-Path $appDir 'Nova.exe'))) {
  Write-Host "::error::Nova.exe not found in $appDir"
  Get-ChildItem $out -Recurse -Depth 2 | Select-Object -First 40 FullName | Out-Host
  exit 1
}

# 4. 结果 → apps/electron/dist
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force $dist | Out-Null
Copy-Item (Join-Path $appDir '*') $dist -Recurse -Force

$size = (Get-ChildItem $dist -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host ("dist: {0:N1} MB" -f ($size / 1MB))
Get-ChildItem $dist | Format-Table Name, Length -AutoSize | Out-Host
exit 0
