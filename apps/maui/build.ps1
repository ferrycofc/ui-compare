# 编译 .NET MAUI 版（Windows，非打包、自包含）到 apps/maui/dist（Nova.exe）
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }

# 在项目目录里运行，让 global.json 选 .NET 9 SDK（机器上也装了 .NET 10）
Push-Location $root
try {
  dotnet --version
  if ($LASTEXITCODE -ne 0) { Write-Host "::error::dotnet not found"; exit 1 }

  # MAUI 的 Windows 部分是一个 dotnet workload
  dotnet workload install maui-windows
  if ($LASTEXITCODE -ne 0) { Write-Host "::error::dotnet workload install maui-windows failed ($LASTEXITCODE)"; exit 1 }
  dotnet workload list

  dotnet publish Nova.csproj -c Release -f net9.0-windows10.0.19041.0 -r win-x64 `
    -p:WindowsPackageType=None -p:WindowsAppSDKSelfContained=true -p:SelfContained=true `
    -o $dist -nologo
  if ($LASTEXITCODE -ne 0) { Write-Host "::error::dotnet publish failed ($LASTEXITCODE)"; exit 1 }
}
finally { Pop-Location }

if (-not (Test-Path (Join-Path $dist 'Nova.exe'))) {
  Get-ChildItem $dist -ErrorAction SilentlyContinue | Select-Object -First 40 Name | Out-String | Write-Host
  Write-Host "::error::dist/Nova.exe not found"; exit 1
}
Write-Host "dist: $((Get-ChildItem $dist -Recurse -File).Count) files"
exit 0
