# 编译 Win32 版（现代样式 + 经典主题两个 exe），输出到 apps/win32/dist
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
cmd /c "$here\build.cmd"
if ($LASTEXITCODE) { exit 1 }
$dist = Join-Path $here 'dist'
Remove-Item $dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dist | Out-Null
Copy-Item "$here\bin\win32.exe", "$here\bin\win32_classic.exe" $dist
Get-ChildItem $dist
