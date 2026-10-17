# 编译 UWP 版：生成图标 → 自签名证书 → msbuild 打出签名的 .msix → 复制到 apps/uwp/dist
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
$work = Join-Path ($(if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() })) 'nova-uwp'
$pkgDir = Join-Path $work 'AppPackages'
foreach ($d in $dist, $work) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
New-Item -ItemType Directory -Force $dist, $work, $pkgDir | Out-Null

function Fail($msg) { Write-Host "::error::$msg"; exit 1 }

# ---------- 1. 看看机器上有哪些 UWP 工具 ----------
Write-Host "== UWP tooling =="
Write-Host "VSINSTALLDIR = $env:VSINSTALLDIR"
Write-Host "VSCMD_VER    = $env:VSCMD_VER"
$msbuildCmd = Get-Command msbuild -ErrorAction SilentlyContinue
if (-not $msbuildCmd) { Fail "msbuild is not on PATH (VS developer environment not loaded?)" }
Write-Host "msbuild      = $($msbuildCmd.Source)"
msbuild -version -nologo | Write-Host

# VS 安装目录：优先用开发者环境给的，否则从 msbuild 路径往上找
$vsDir = $env:VSINSTALLDIR
if (-not $vsDir) { $vsDir = (Resolve-Path (Join-Path (Split-Path $msbuildCmd.Source) '..\..\..')).Path }
$xamlRoot = Join-Path $vsDir 'MSBuild\Microsoft\WindowsXaml'
Write-Host "WindowsXaml folder: $xamlRoot  exists=$(Test-Path $xamlRoot)"
if (Test-Path $xamlRoot) { Get-ChildItem $xamlRoot | ForEach-Object { Write-Host "  $($_.Name)" } }

$xamlTargets = Get-ChildItem $xamlRoot -Recurse -Filter 'Microsoft.Windows.UI.Xaml.CSharp.targets' -ErrorAction SilentlyContinue |
  Sort-Object FullName -Descending | Select-Object -First 1
$appxTargets = Join-Path $vsDir 'MSBuild\Microsoft\VisualStudio'
$appx = Get-ChildItem $appxTargets -Recurse -Filter 'Microsoft.AppxPackage.Targets' -ErrorAction SilentlyContinue | Select-Object -First 1
Write-Host "UWP XAML targets : $(if ($xamlTargets) { $xamlTargets.FullName } else { 'MISSING' })"
Write-Host "AppxPackage targets: $(if ($appx) { $appx.FullName } else { 'MISSING' })"

$uapRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Platforms\UAP'
Write-Host "UAP platforms folder: $uapRoot  exists=$(Test-Path $uapRoot)"
$uap = @()
if (Test-Path $uapRoot) {
  $uap = @(Get-ChildItem $uapRoot -Directory | Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' -and (Test-Path (Join-Path $_.FullName 'Platform.xml')) } |
    Sort-Object { [version]$_.Name } -Descending)
  Get-ChildItem $uapRoot -Directory | ForEach-Object { Write-Host "  $($_.Name)" }
}
$netNative = Get-ChildItem (Join-Path ${env:ProgramFiles(x86)} 'Microsoft SDKs\UWPNuGetPackages') -Directory -ErrorAction SilentlyContinue
Write-Host "UWPNuGetPackages: $(($netNative | ForEach-Object Name) -join ', ')"

if (-not $xamlTargets) { Fail "UWP (C#) project system is missing: no Microsoft.Windows.UI.Xaml.CSharp.targets under $xamlRoot. The Visual Studio 'Universal Windows Platform development' workload (Microsoft.VisualStudio.Workload.Universal) is not installed in $vsDir." }
if (-not $appx) { Fail "Microsoft.AppxPackage.Targets not found under $appxTargets (UWP packaging tools missing)." }
if ($uap.Count -eq 0) { Fail "No UAP platform SDK found under $uapRoot (Windows 10/11 SDK not installed)." }
$tpv = $uap[0].Name
Write-Host "Using TargetPlatformVersion $tpv"

# ---------- 2. 生成清单里引用的 PNG 图标 ----------
Add-Type -AssemblyName System.Drawing
$assets = Join-Path $root 'Assets'
New-Item -ItemType Directory -Force $assets | Out-Null
function New-Logo([string]$name, [int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::FromArgb(255, 0, 120, 212))
  $size = [Math]::Max(8, [Math]::Min($w, $h) * 0.5)
  $font = New-Object System.Drawing.Font('Segoe UI', [single]$size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
  $g.DrawString('N', $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 0, $w, $h)), $fmt)
  $g.Dispose()
  $bmp.Save((Join-Path $assets $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}
New-Logo 'Square44x44Logo.png' 44 44
New-Logo 'Square150x150Logo.png' 150 150
New-Logo 'Wide310x150Logo.png' 310 150
New-Logo 'StoreLogo.png' 50 50
New-Logo 'SplashScreen.png' 620 300
Get-ChildItem $assets | ForEach-Object { Write-Host "asset $($_.Name) $($_.Length) bytes" }

# ---------- 3. 自签名代码签名证书（发布者必须和清单里的 CN=Nova 一样） ----------
$pfxPath = Join-Path $work 'Nova.pfx'
$cerPath = Join-Path $work 'Nova.cer'
$pfxPass = 'nova-uwp-ci'
# 写法照微软 MSIX 签名文档：Custom + 代码签名用途（1.3.6.1.5.5.7.3.3）+ 非 CA
$cert = New-SelfSignedCertificate -Type Custom -Subject 'CN=Nova' -CertStoreLocation 'Cert:\CurrentUser\My' `
  -KeyUsage DigitalSignature -FriendlyName 'Nova UWP test' -NotAfter (Get-Date).AddYears(2) `
  -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
$secure = ConvertTo-SecureString -String $pfxPass -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $secure | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
Write-Host "Certificate $($cert.Thumbprint) -> $pfxPath"

# ---------- 4. msbuild：还原 NuGet + 编译（.NET Native）+ 打包签名 ----------
$proj = Join-Path $root 'Nova.csproj'
msbuild $proj /restore /nologo /v:minimal `
  /p:Configuration=Release /p:Platform=x64 `
  "/p:TargetPlatformVersion=$tpv" `
  "/p:NovaXamlTargets=$($xamlTargets.FullName)" `
  /p:AppxBundle=Never /p:UapAppxPackageBuildMode=SideloadOnly `
  /p:AppxPackageSigningEnabled=true `
  "/p:PackageCertificateKeyFile=$pfxPath" `
  "/p:PackageCertificatePassword=$pfxPass" `
  "/p:AppxPackageDir=$pkgDir\" `
  /p:GenerateAppInstallerFile=false
if ($LASTEXITCODE -ne 0) { Fail "msbuild failed ($LASTEXITCODE)" }

# ---------- 5. 复制安装包、依赖、证书和安装脚本到 dist ----------
Write-Host "== AppPackages =="
Get-ChildItem $pkgDir -Recurse -File | ForEach-Object { Write-Host "  $($_.FullName.Substring($pkgDir.Length)) ($($_.Length))" }

# 正常在 $pkgDir；万一 AppxPackageDir 没生效，再找项目目录下的 AppPackages
$searchDirs = @($pkgDir, (Join-Path $root 'AppPackages')) | Where-Object { Test-Path $_ }
$pkg = Get-ChildItem $searchDirs -Recurse -File | Where-Object { $_.Extension -in '.msix', '.appx' -and $_.FullName -notmatch '\\Dependencies\\' } |
  Select-Object -First 1
if (-not $pkg) { Fail "No .msix/.appx produced under $($searchDirs -join ', ')" }
Write-Host "Package: $($pkg.FullName)"
Copy-Item $pkg.FullName $dist

$depDir = Get-ChildItem $pkg.Directory.FullName -Recurse -Directory -Filter 'x64' | Where-Object { $_.Parent.Name -eq 'Dependencies' } | Select-Object -First 1
if ($depDir) {
  $depOut = Join-Path $dist 'Dependencies'
  New-Item -ItemType Directory -Force $depOut | Out-Null
  Get-ChildItem $depDir.FullName -File | Copy-Item -Destination $depOut
} else {
  Write-Host "::warning::No Dependencies\x64 folder found (framework packages may already be on the target machine)"
}
Copy-Item $cerPath $dist
Copy-Item (Join-Path $root 'install.ps1') $dist

Write-Host "== dist =="
Get-ChildItem $dist -Recurse -File | ForEach-Object { Write-Host "  $($_.FullName.Substring($dist.Length)) ($($_.Length))" }
exit 0
