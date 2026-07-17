param(
    [string]$Ref = "stable-2026-07-17-final",
    [switch]$Execute,
    [switch]$Force,
    [switch]$NoFetch
)

$ErrorActionPreference = "Stop"

function Write-Info($message) { Write-Host "[INFO] $message" -ForegroundColor Cyan }
function Write-WarnMsg($message) { Write-Host "[WARN] $message" -ForegroundColor Yellow }
function Write-ErrMsg($message) { Write-Host "[ERROR] $message" -ForegroundColor Red }

try {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    Set-Location $repoRoot

    Write-Info "Repository: $repoRoot"
    Write-Info "Target restore ref: $Ref"

    $isGitRepo = (& git rev-parse --is-inside-work-tree 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $isGitRepo -ne "true") {
        throw "Current directory is not a git repository."
    }

    if (-not $NoFetch) {
        Write-Info "Fetching latest refs from origin..."
        & git fetch --all --tags --prune
        if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }
    }

    & git rev-parse --verify $Ref 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Ref '$Ref' does not exist locally. Make sure the branch/tag was pushed."
    }

    $current = (& git rev-parse --short HEAD).Trim()
    $target = (& git rev-parse --short $Ref).Trim()
    $status = (& git status --porcelain)

    Write-Info "Current HEAD: $current"
    Write-Info "Target  HEAD: $target"

    if (-not $Execute) {
        if ($status) {
            Write-WarnMsg "Working tree has uncommitted changes."
            Write-WarnMsg "Dry run continues safely. Execute mode will block unless -Force is used."
        }
        Write-Host ""
        Write-Info "Dry run only. No changes were applied."
        Write-Host "Run this to execute restore:" -ForegroundColor Green
        Write-Host "  powershell -ExecutionPolicy Bypass -File scripts/restore_stable_final.ps1 -Execute"
        Write-Host ""
        exit 0
    }

    if ($status) {
        Write-WarnMsg "Working tree has uncommitted changes."
        if (-not $Force) {
            throw "Aborting to avoid data loss. Commit/stash changes or rerun with -Force."
        }
        Write-WarnMsg "Force mode enabled. Local changes may be lost after reset."
    }

    if (-not $Force) {
        $confirm = Read-Host "Type RESTORE to confirm hard reset to '$Ref'"
        if ($confirm -ne "RESTORE") {
            throw "Restore cancelled by user."
        }
    }

    Write-Info "Checking out main..."
    & git checkout main
    if ($LASTEXITCODE -ne 0) { throw "git checkout main failed." }

    Write-Info "Hard resetting main to $Ref..."
    & git reset --hard $Ref
    if ($LASTEXITCODE -ne 0) { throw "git reset --hard failed." }

    Write-Info "Pushing restored main to origin..."
    & git push origin main --force-with-lease
    if ($LASTEXITCODE -ne 0) { throw "git push failed." }

    Write-Info "Restore completed successfully."
    Write-Info "main now points to $target ($Ref)."
}
catch {
    Write-ErrMsg $_.Exception.Message
    exit 1
}
