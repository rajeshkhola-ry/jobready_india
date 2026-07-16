Set-Location "$PSScriptRoot\.."

$releaseDir = "release"
$zipPath = Join-Path $releaseDir "jobready_v1_web.zip"

if (-not (Test-Path $releaseDir)) {
  New-Item -ItemType Directory -Path $releaseDir | Out-Null
}

flutter build web --release -t lib/main_v1.dart

if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}

Compress-Archive -Path "build\web\*" -DestinationPath $zipPath
Write-Output "V1 release package created: $zipPath"
