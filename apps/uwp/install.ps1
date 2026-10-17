# 在截图机器上安装 UWP 包（需要管理员权限）：先信任自签名证书，再装依赖和应用包
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

$cer = Get-ChildItem $here -Filter '*.cer' | Select-Object -First 1
if (-not $cer) { Write-Host "::error::No .cer in $here"; exit 1 }
Import-Certificate -FilePath $cer.FullName -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
Import-Certificate -FilePath $cer.FullName -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
Write-Host "Trusted certificate $($cer.Name)"

$pkg = Get-ChildItem $here -File | Where-Object { $_.Extension -in '.msix', '.appx' } | Select-Object -First 1
if (-not $pkg) { Write-Host "::error::No .msix/.appx in $here"; exit 1 }

# 先删掉旧版本，避免“已安装更高或相同版本”的错误
Get-AppxPackage -Name 'NovaUWP' | Remove-AppxPackage -ErrorAction SilentlyContinue

$deps = @()
$depDir = Join-Path $here 'Dependencies'
if (Test-Path $depDir) {
  $deps = @(Get-ChildItem $depDir -File | Where-Object { $_.Extension -in '.msix', '.appx' } | ForEach-Object { $_.FullName })
}
Write-Host "Installing $($pkg.Name) with $($deps.Count) dependencies"
if ($deps.Count -gt 0) {
  Add-AppxPackage -Path $pkg.FullName -DependencyPath $deps -ForceApplicationShutdown
} else {
  Add-AppxPackage -Path $pkg.FullName -ForceApplicationShutdown
}

$installed = Get-AppxPackage -Name 'NovaUWP'
if (-not $installed) { Write-Host "::error::NovaUWP is not installed after Add-AppxPackage"; exit 1 }
Write-Host "Installed $($installed.PackageFullName)  (shell:AppsFolder\$($installed.PackageFamilyName)!App)"
exit 0
