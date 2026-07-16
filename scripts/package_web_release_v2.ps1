Set-Location "$PSScriptRoot\.."

$releaseDir = "release"
$zipPath = Join-Path $releaseDir "jobready_v2_web.zip"

if (-not (Test-Path $releaseDir)) {
  New-Item -ItemType Directory -Path $releaseDir | Out-Null
}

flutter build web --release -t lib/main_phase_7.5_.dart

if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}

Compress-Archive -Path "build\web\*" -DestinationPath $zipPath
Write-Output "V2 release package created: $zipPath"
