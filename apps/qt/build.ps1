# 编译 Qt Widgets 版：用 aqtinstall 装 Qt 6.8.3（MSVC 2022 x64），CMake 编译，windeployqt 打包到 apps/qt/dist
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$tmp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }

$qtVersion = '6.8.3'
$qtRoot = Join-Path $tmp 'Qt'
$qtDir = Join-Path $qtRoot "$qtVersion\msvc2022_64"

# ---------- 安装 Qt ----------
python -m pip install --quiet --disable-pip-version-check aqtinstall
if ($LASTEXITCODE) { Write-Host "pip install aqtinstall failed"; exit 1 }

if (-not (Test-Path "$qtDir\bin\windeployqt.exe")) {
  $ok = $false
  for ($i = 1; $i -le 3 -and -not $ok; $i++) {   # 镜像偶尔会失败，重试几次
    python -m aqt install-qt windows desktop $qtVersion win64_msvc2022_64 -O $qtRoot
    $ok = ($LASTEXITCODE -eq 0) -and (Test-Path "$qtDir\bin\windeployqt.exe")
    if (-not $ok) { Write-Host "aqt attempt $i failed"; Start-Sleep -Seconds 10 }
  }
  if (-not $ok) { Write-Host "Qt install failed"; exit 1 }
}
Write-Host "Qt: $qtDir"

# ---------- 编译 ----------
$build = Join-Path $tmp 'qt-build'
Remove-Item $build -Recurse -Force -ErrorAction SilentlyContinue
# 用 NMake：编译环境已经由 VS 开发者命令行准备好（cl.exe 在 PATH 里），不依赖 VS 版本号
cmake -S $here -B $build -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release "-DCMAKE_PREFIX_PATH=$qtDir"
if ($LASTEXITCODE) { Write-Host "cmake configure failed"; exit 1 }
cmake --build $build
if ($LASTEXITCODE) { Write-Host "cmake build failed"; exit 1 }

$exe = Join-Path $build 'Nova.exe'
if (-not (Test-Path $exe)) { Get-ChildItem $build -Recurse -Filter *.exe | Select-Object FullName; Write-Host "Nova.exe not found"; exit 1 }

# ---------- 打包 ----------
$dist = Join-Path $here 'dist'
Remove-Item $dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dist | Out-Null
Copy-Item $exe $dist

& "$qtDir\bin\windeployqt.exe" --release --no-translations --no-system-d3d-compiler --no-system-dxc-compiler `
  --no-opengl-sw --no-compiler-runtime "$dist\Nova.exe"
if ($LASTEXITCODE) { Write-Host "windeployqt failed"; exit 1 }

# MSVC 运行库直接放进 dist（干净的电脑上不用再装 VC++ 运行库）
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
foreach ($f in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  if (-not (Test-Path (Join-Path $dist $f))) { Write-Host "$f missing"; exit 1 }
}

Get-ChildItem $dist -Recurse | Select-Object FullName, Length | Format-Table -AutoSize
exit 0
