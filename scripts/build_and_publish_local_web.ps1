$ErrorActionPreference = 'Stop'

$repoRoot = 'C:\JobReadyIndia\jobready_india'
Set-Location $repoRoot

Write-Output 'Building Flutter web app from local sources...'
& flutter build web -t lib/main_v1_1.dart --release --base-href '/'

Write-Output 'Preparing local deployment bundle...'
& powershell -NoProfile -ExecutionPolicy Bypass -File '.\scripts\publish_local_web_bundle.ps1'

Write-Output 'Local web bundle prepared successfully.'
