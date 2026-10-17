# WPF（.NET 8）：自带运行库发布到 apps/wpf/dist
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$dist = Join-Path $here 'dist'
if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }

dotnet publish (Join-Path $here 'NovaWpf.csproj') -c Release -r win-x64 --self-contained true -o $dist -nologo
if ($LASTEXITCODE -ne 0) { Write-Host "::error::dotnet publish failed ($LASTEXITCODE)"; exit 1 }
if (-not (Test-Path (Join-Path $dist 'Nova.exe'))) { Write-Host "::error::Nova.exe not found in $dist"; exit 1 }
Get-ChildItem $dist -Filter *.exe | ForEach-Object { Write-Host "$($_.Name)  $([Math]::Round($_.Length / 1KB)) KB" }
exit 0
