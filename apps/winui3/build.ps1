# 编译 WinUI 3 版（不打包、自带运行库），输出到 apps/winui3/dist
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$out = Join-Path $env:RUNNER_TEMP 'winui3-out'
msbuild "$here\NovaWinUI.csproj" -restore -p:Configuration=Release -p:Platform=x64 -p:RuntimeIdentifier=win-x64 `
  "-p:OutDir=$out\" -v:minimal -nologo
if ($LASTEXITCODE) { exit 1 }
$dist = Join-Path $here 'dist'
Remove-Item $dist -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $out $dist -Recurse
if (-not (Test-Path "$dist\NovaWinUI.exe")) { Get-ChildItem $dist | Select-Object -First 30; throw "NovaWinUI.exe missing" }
