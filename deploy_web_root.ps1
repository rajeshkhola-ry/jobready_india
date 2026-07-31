$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "Building Flutter web app from $scriptDir" -ForegroundColor Cyan
flutter clean
flutter pub get
flutter build web --release -t lib/main_v1_1.dart --base-href "/"

$buildOutput = Join-Path $scriptDir 'build/web'
$deployOutput = Join-Path $scriptDir 'deploy_web_root'

if (-not (Test-Path $buildOutput)) {
    throw "Expected build output not found at $buildOutput"
}

if (Test-Path $deployOutput) {
    Remove-Item -Recurse -Force $deployOutput
}

New-Item -ItemType Directory -Force -Path $deployOutput | Out-Null
Copy-Item -Recurse -Force "$buildOutput\*" $deployOutput

Write-Host "Deployment artifacts written to $deployOutput" -ForegroundColor Green
