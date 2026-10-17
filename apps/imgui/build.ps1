# Dear ImGui 版：下载 ImGui 1.91.6 源码，用 cl.exe 直接编译成一个 exe（静态运行库，不依赖任何 DLL）
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$tmp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$src = Join-Path $tmp 'imgui-src'

if (-not (Test-Path "$src\imgui.cpp")) {
  Remove-Item $src -Recurse -Force -ErrorAction SilentlyContinue
  git clone --depth 1 --branch v1.91.6 https://github.com/ocornut/imgui $src
  if ($LASTEXITCODE) { Write-Host "::error::git clone failed"; exit 1 }
}

$obj = Join-Path $tmp 'imgui-obj'
Remove-Item $obj -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $obj | Out-Null
$dist = Join-Path $here 'dist'
Remove-Item $dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dist | Out-Null

$sources = @(
  "$here\main.cpp",
  "$src\imgui.cpp", "$src\imgui_draw.cpp", "$src\imgui_tables.cpp", "$src\imgui_widgets.cpp",
  "$src\backends\imgui_impl_win32.cpp", "$src\backends\imgui_impl_dx11.cpp"
)
cl /nologo /utf-8 /std:c++17 /O2 /MT /EHsc /W3 /DUNICODE /D_UNICODE /DNDEBUG "/I$src" "/I$src\backends" `
  $sources "/Fo$obj\" "/Fe$dist\Nova.exe" `
  /link /SUBSYSTEM:WINDOWS d3d11.lib dxgi.lib d3dcompiler.lib dwmapi.lib user32.lib gdi32.lib
if ($LASTEXITCODE) { Write-Host "::error::cl failed ($LASTEXITCODE)"; exit 1 }

Get-ChildItem $dist | ForEach-Object { Write-Host "$($_.Name)  $([Math]::Round($_.Length / 1KB)) KB" }
exit 0
