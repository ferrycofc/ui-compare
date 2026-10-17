# MFC 版：cl.exe 直接编译，MFC 用共享 DLL（mfc140u.dll），把 MFC 和 VC 运行库的 DLL 一起放进 dist
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$tmp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }

if (-not $env:VCToolsInstallDir) { Write-Host "::error::not in a VS developer environment"; exit 1 }
$atlmfc = Join-Path $env:VCToolsInstallDir 'atlmfc'
Write-Host "VCToolsInstallDir: $env:VCToolsInstallDir"
Write-Host "VCToolsRedistDir:  $env:VCToolsRedistDir"
if (-not (Test-Path "$atlmfc\include\afxwin.h")) { Write-Host "::error::MFC headers not installed ($atlmfc)"; exit 1 }

$obj = Join-Path $tmp 'mfc-obj'
Remove-Item $obj -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $obj | Out-Null
$dist = Join-Path $here 'dist'
Remove-Item $dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dist | Out-Null

cl /nologo /utf-8 /std:c++17 /O2 /MD /EHsc /W3 /D_AFXDLL /DUNICODE /D_UNICODE /DNDEBUG "$here\main.cpp" "/Fo$obj\" "/Fe$dist\Nova.exe" `
  /link /SUBSYSTEM:WINDOWS /ENTRY:wWinMainCRTStartup
if ($LASTEXITCODE) { Write-Host "::error::cl failed ($LASTEXITCODE)"; exit 1 }

# 运行库：在 VC 的 redist 目录里找（VS 2022 是 Microsoft.VC143.*，VS 2026 是更新的编号）
$redist = Join-Path $env:VCToolsRedistDir 'x64'
$mfcDir = Get-ChildItem $redist -Directory -Filter 'Microsoft.VC*.MFC' | Select-Object -First 1
$crtDir = Get-ChildItem $redist -Directory -Filter 'Microsoft.VC*.CRT' | Select-Object -First 1
if (-not $mfcDir -or -not $crtDir) { Get-ChildItem $redist | Select-Object Name | Out-String | Write-Host; Write-Host "::error::redist folders not found"; exit 1 }
Copy-Item "$($mfcDir.FullName)\mfc140u.dll" $dist
foreach ($f in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') { Copy-Item "$($crtDir.FullName)\$f" $dist }

Get-ChildItem $dist | ForEach-Object { Write-Host "$($_.Name)  $([Math]::Round($_.Length / 1KB)) KB" }
exit 0
