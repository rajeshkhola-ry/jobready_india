param(
    [int]$Port = 8080,
    [string]$Directory = 'build/web'
)

$ErrorActionPreference = 'Stop'

$repoRoot = 'C:\JobReadyIndia\jobready_india'
$targetDir = Join-Path $repoRoot $Directory

if (-not (Test-Path $targetDir)) {
    throw "Build output directory not found at $targetDir. Run flutter build web first."
}

Write-Host "Preparing preview server on port $Port from $targetDir" -ForegroundColor Cyan

$connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
if ($connections) {
    $processIds = $connections | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($entryProcessId in $processIds) {
        if ($entryProcessId) {
            Stop-Process -Id $entryProcessId -Force -ErrorAction SilentlyContinue
        }
    }
}

Get-CimInstance Win32_Process -Filter "name = 'python.exe'" | Where-Object {
    $_.CommandLine -match 'http\.server' -and $_.CommandLine -match [regex]::Escape("$Port")
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

Set-Location $repoRoot
Write-Host "Serving $targetDir at http://127.0.0.1:$Port" -ForegroundColor Green
& python -m http.server $Port --directory $targetDir
