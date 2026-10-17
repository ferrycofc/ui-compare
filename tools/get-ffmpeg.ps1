# 下载 ffmpeg（录屏用），把路径写进 GITHUB_ENV 的 FFMPEG
$ErrorActionPreference = 'Stop'
$arm = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
$names = if ($arm) { @('ffmpeg-master-latest-winarm64-gpl.zip', 'ffmpeg-master-latest-win64-gpl.zip') } else { @('ffmpeg-master-latest-win64-gpl.zip') }
$dest = Join-Path $env:RUNNER_TEMP 'ffmpeg'
foreach ($n in $names) {
  try {
    $zip = Join-Path $env:RUNNER_TEMP $n
    Invoke-WebRequest "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/$n" -OutFile $zip
    Expand-Archive $zip $dest -Force
    $exe = Get-ChildItem $dest -Recurse -Filter ffmpeg.exe | Select-Object -First 1
    if ($exe) {
      & $exe.FullName -hide_banner -version | Select-Object -First 1
      if ($LASTEXITCODE -eq 0) {
        "FFMPEG=$($exe.FullName)" | Add-Content $env:GITHUB_ENV
        Write-Host "Using $($exe.FullName) from $n"
        exit 0
      }
    }
  } catch { Write-Host "Download of $n failed: $_" }
}
Write-Host "BtbN builds unavailable, trying Chocolatey"
choco install ffmpeg -y --no-progress
$exe = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($exe) { "FFMPEG=$($exe.Source)" | Add-Content $env:GITHUB_ENV; exit 0 }
Write-Host "::warning::ffmpeg not available; videos will be skipped"
