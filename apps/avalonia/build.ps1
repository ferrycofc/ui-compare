# 编译 Avalonia 版：自包含发布到 apps/avalonia/dist（Nova.exe）
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }

dotnet --info | Select-Object -First 20 | Write-Host

dotnet publish (Join-Path $root 'Nova.csproj') -c Release -r win-x64 --self-contained true -o $dist -nologo
if ($LASTEXITCODE -ne 0) { Write-Host "::error::dotnet publish failed ($LASTEXITCODE)"; exit 1 }

if (-not (Test-Path (Join-Path $dist 'Nova.exe'))) { Write-Host "::error::dist/Nova.exe not found"; exit 1 }
Get-ChildItem $dist | Select-Object Name, Length | Format-Table -AutoSize | Out-String | Write-Host
exit 0
