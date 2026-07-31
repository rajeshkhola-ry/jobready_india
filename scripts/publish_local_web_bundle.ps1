$ErrorActionPreference = 'Stop'

$repoRoot = 'C:\JobReadyIndia\jobready_india'
$buildRoot = Join-Path $repoRoot 'build/web'
$targetRoot = Join-Path $repoRoot 'deploy_web_root'

if (-not (Test-Path $buildRoot)) {
    throw "Build output not found at $buildRoot"
}

if (Test-Path $targetRoot) {
    Remove-Item $targetRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
Copy-Item -Path (Join-Path $buildRoot '*') -Destination $targetRoot -Recurse -Force

Write-Output 'LOCAL_WEB_BUNDLE_READY'
Write-Output $targetRoot
