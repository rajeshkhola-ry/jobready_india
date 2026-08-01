$ErrorActionPreference = 'Stop'

$repoRoot = 'C:\JobReadyIndia\jobready_india'
$buildDir = Join-Path $repoRoot 'build/web'
Set-Location $repoRoot

Write-Output 'Cleaning stale local preview processes...'
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
    if ($_ -and $_ -ne 0) {
        Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
    }
}

Get-CimInstance Win32_Process -Filter "name = 'python.exe'" | Where-Object {
    $_.CommandLine -match 'http\.server' -and $_.CommandLine -match '8080'
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

if (Test-Path $buildDir) {
    Remove-Item $buildDir -Recurse -Force
}

Write-Output 'Building Flutter web app from local sources...'
& flutter build web -t lib/main_v1_1.dart --release --base-href '/' --web-renderer auto

Write-Output 'Preparing local deployment bundle...'
& powershell -NoProfile -ExecutionPolicy Bypass -File '.\scripts\publish_local_web_bundle.ps1'

Write-Output 'Local web bundle prepared successfully.'
