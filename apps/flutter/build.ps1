# 编译 Flutter 版：克隆 Flutter stable，新建一个只带 Windows 平台的工程，换上 lib/main.dart，
# 改窗口标题、大小和深色标题栏，flutter build windows，输出到 apps/flutter/dist（exe 改名为 Nova.exe）
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$tmp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }

# ---------- 安装 Flutter ----------
$sdk = Join-Path $tmp 'flutter'
if (-not (Test-Path "$sdk\bin\flutter.bat")) {
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git $sdk
  if ($LASTEXITCODE) { Write-Host "git clone flutter failed"; exit 1 }
}
$env:PATH = "$sdk\bin;$env:PATH"
$env:CI = 'true'

flutter config --no-analytics
if ($LASTEXITCODE) { Write-Host "flutter config --no-analytics failed"; exit 1 }
flutter config --enable-windows-desktop
if ($LASTEXITCODE) { Write-Host "flutter config --enable-windows-desktop failed"; exit 1 }
flutter --version
if ($LASTEXITCODE) { Write-Host "flutter --version failed"; exit 1 }

# ---------- 新建工程，换上我们的代码 ----------
$proj = Join-Path $tmp 'nova_flutter'
Remove-Item $proj -Recurse -Force -ErrorAction SilentlyContinue
flutter create --platforms=windows --org com.nova --project-name nova_flutter $proj
if ($LASTEXITCODE) { Write-Host "flutter create failed"; exit 1 }

Copy-Item "$here\lib\main.dart" "$proj\lib\main.dart" -Force
Remove-Item "$proj\test" -Recurse -Force -ErrorAction SilentlyContinue   # 模板自带的测试引用了 MyApp，用不上

# ---------- 改 Windows 外壳（runner）的 C++ 代码 ----------
function Edit-Source([string]$path, [string]$pattern, [string]$replacement, [string]$what, [bool]$required = $true) {
  $text = [IO.File]::ReadAllText($path)
  if (-not [regex]::IsMatch($text, $pattern)) {
    if ($required) { Write-Host "Patch '$what' did not match in $path"; Get-Content $path | Write-Host; exit 1 }
    Write-Host "::warning::Patch '$what' did not match in $path (optional, skipped)"
    return
  }
  $text = [regex]::Replace($text, $pattern, $replacement)
  [IO.File]::WriteAllText($path, $text)
  Write-Host "Patched: $what"
}

$mainCpp = "$proj\windows\runner\main.cpp"
# 标题“Nova 设置 — Flutter”：非 ASCII 字符写成 C++ 的 \uXXXX 转义，runner 不加 /utf-8 也不会乱码
$title = 'Nova ' + [char]0x8BBE + [char]0x7F6E + ' ' + [char]0x2014 + ' Flutter'
$titleEsc = -join ($title.ToCharArray() | ForEach-Object {
  if ([int]$_ -gt 127) { [string][char]92 + 'u' + ([int]$_).ToString('x4') } else { [string]$_ } })
Write-Host "Title literal: $titleEsc"
Edit-Source $mainCpp 'L"nova_flutter"' ('L"' + $titleEsc + '"') 'window title'
# 外框 920 x 660（可调大小的窗口两侧和底部有 7 像素透明边，看得见的是 906 x 653）
Edit-Source $mainCpp 'Win32Window::Size\s+size\(\s*\d+\s*,\s*\d+\s*\)' 'Win32Window::Size size(920, 660)' 'window size'
# 深色标题栏：窗口创建成功后直接设 DWMWA_USE_IMMERSIVE_DARK_MODE（20）
Edit-Source $mainCpp '#include <windows.h>' "#include <windows.h>`r`n#include <dwmapi.h>`r`n#pragma comment(lib, `"dwmapi.lib`")" 'dwmapi include'
Edit-Source $mainCpp 'window\.SetQuitOnClose\(true\);' "window.SetQuitOnClose(true);`r`n  {`r`n    BOOL dark = TRUE;`r`n    ::DwmSetWindowAttribute(window.GetHandle(), 20, &dark, sizeof(dark));`r`n  }" 'dark title bar'
# 系统主题变化时模板会按注册表重新设置标题栏颜色：改成始终深色（可选）
Edit-Source "$proj\windows\runner\win32_window.cpp" 'BOOL\s+enable_dark_mode\s*=\s*light_mode\s*==\s*0\s*;' 'BOOL enable_dark_mode = TRUE;' 'always dark in UpdateTheme' $false

Write-Host "----- runner/main.cpp -----"
Get-Content $mainCpp | Write-Host

# ---------- 编译 ----------
Push-Location $proj
flutter build windows --release
$code = $LASTEXITCODE
Pop-Location
if ($code) { Write-Host "flutter build windows failed"; exit 1 }

$out = "$proj\build\windows\x64\runner\Release"
if (-not (Test-Path "$out\nova_flutter.exe")) { Get-ChildItem "$proj\build\windows" -Recurse -Filter *.exe | Select-Object FullName; Write-Host "nova_flutter.exe not found"; exit 1 }

# ---------- 打包 ----------
$dist = Join-Path $here 'dist'
Remove-Item $dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dist | Out-Null
Copy-Item "$out\*" $dist -Recurse
Rename-Item "$dist\nova_flutter.exe" 'Nova.exe'   # data\ 和 flutter_windows.dll 都按 exe 所在目录找，改名没关系

# MSVC 运行库放进 dist（干净的电脑上不用再装 VC++ 运行库）
$redist = $env:VCToolsRedistDir
if (-not $redist -or -not (Test-Path $redist)) {
  $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  $vs = & $vswhere -latest -products * -property installationPath
  $redist = Get-ChildItem "$vs\VC\Redist\MSVC" -Directory | Where-Object { $_.Name -match '^\d' } |
    Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
$crt = Get-ChildItem (Join-Path $redist 'x64') -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $crt) { Write-Host "MSVC CRT redist not found under '$redist'"; exit 1 }
Write-Host "CRT: $($crt.FullName)"
Copy-Item (Join-Path $crt.FullName 'msvcp140*.dll'), (Join-Path $crt.FullName 'vcruntime140*.dll') $dist
foreach ($f in 'Nova.exe', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'data\app.so') {
  if (-not (Test-Path (Join-Path $dist $f))) { Write-Host "$f missing in dist"; exit 1 }
}

Get-ChildItem $dist -Recurse | Select-Object FullName, Length | Format-Table -AutoSize
exit 0
