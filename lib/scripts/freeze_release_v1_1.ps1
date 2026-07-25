param(
    [string]$Version = "V1.1",
    [string]$TagName = "prod/v1.1-baseline",
    [string]$ReleaseBranch = "release/v1.1-baseline",
    [string]$OneDriveRoot = "C:\Users\Avita\OneDrive\GETREADYJOB"
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Info {
    param([string]$Message)
    Write-Output "[INFO] $Message"
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

Write-Info "Repository root: $repoRoot"

$gitOk = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $gitOk -ne "true") {
    throw "Current folder is not a git repository: $repoRoot"
}

$stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$headCommit = (git rev-parse HEAD).Trim()
$shortCommit = (git rev-parse --short HEAD).Trim()

$statusShort = git status --short
if ($statusShort) {
    Write-Info "Working tree has changes. Snapshot will still be created from current HEAD: $shortCommit"
}

$productionDir = Join-Path $OneDriveRoot "PRODUCTION\$Version"
$releasesDir = Join-Path $OneDriveRoot "RELEASES\$Version-$stamp"
$backupsDir = Join-Path $OneDriveRoot "BACKUPS\$Version-$stamp"
$docsDir = Join-Path $OneDriveRoot "DOCUMENTATION\$Version"
$recoveryDir = Join-Path $OneDriveRoot "RECOVERY\$Version"

Ensure-Directory $OneDriveRoot
Ensure-Directory (Join-Path $OneDriveRoot "PRODUCTION")
Ensure-Directory (Join-Path $OneDriveRoot "RELEASES")
Ensure-Directory (Join-Path $OneDriveRoot "BACKUPS")
Ensure-Directory (Join-Path $OneDriveRoot "DOCUMENTATION")
Ensure-Directory (Join-Path $OneDriveRoot "RECOVERY")
Ensure-Directory $productionDir
Ensure-Directory $releasesDir
Ensure-Directory $backupsDir
Ensure-Directory $docsDir
Ensure-Directory $recoveryDir

Write-Info "OneDrive release structure prepared"

$tagExistsRaw = git tag -l $TagName
$tagExists = if ($null -eq $tagExistsRaw) { "" } else { ($tagExistsRaw | Out-String).Trim() }
if (-not $tagExists) {
    git tag -a $TagName -m "GETREADYJOB $Version production baseline ($shortCommit)"
    if ($LASTEXITCODE -ne 0) { throw "Failed to create tag $TagName" }
    Write-Info "Created immutable baseline tag: $TagName"
} else {
    Write-Info "Tag already exists (left untouched): $TagName"
}

$branchExistsRaw = git branch --list $ReleaseBranch
$branchExists = if ($null -eq $branchExistsRaw) { "" } else { ($branchExistsRaw | Out-String).Trim() }
if (-not $branchExists) {
    git branch $ReleaseBranch $headCommit
    if ($LASTEXITCODE -ne 0) { throw "Failed to create branch $ReleaseBranch" }
    Write-Info "Created release branch: $ReleaseBranch"
} else {
    Write-Info "Release branch already exists (left untouched): $ReleaseBranch"
}

$bundlePath = Join-Path $releasesDir "jobready_$($Version)_$shortCommit.bundle"
git bundle create $bundlePath --branches --tags
if ($LASTEXITCODE -ne 0) { throw "Failed to create git bundle" }
Write-Info "Git bundle created: $bundlePath"

$tempStage = Join-Path $env:TEMP "jobready_release_stage_$stamp"
Ensure-Directory $tempStage

$excludeDirs = @(".git", ".dart_tool", "build", "node_modules", "backups", "V2_BACKUP", "V2_WORKING")
$excludeFiles = @("*.tmp", "*.log")

$items = Get-ChildItem -Path $repoRoot -Recurse -Force
foreach ($item in $items) {
    $relative = $item.FullName.Substring($repoRoot.Length).TrimStart('\\')

    $excluded = $false
    foreach ($d in $excludeDirs) {
        if ($relative -eq $d -or $relative.StartsWith("$d\\")) {
            $excluded = $true
            break
        }
    }
    if ($excluded) { continue }

    if ($item.PSIsContainer) {
        $targetDir = Join-Path $tempStage $relative
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        continue
    }

    foreach ($pattern in $excludeFiles) {
        if ($item.Name -like $pattern) {
            $excluded = $true
            break
        }
    }
    if ($excluded) { continue }

    $targetFile = Join-Path $tempStage $relative
    $parent = Split-Path -Parent $targetFile
    Ensure-Directory $parent
    Copy-Item -Path $item.FullName -Destination $targetFile -Force
}

$zipPath = Join-Path $backupsDir "jobready_$($Version)_$shortCommit.zip"
if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
Compress-Archive -Path (Join-Path $tempStage "*") -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -Path $tempStage -Recurse -Force
Write-Info "ZIP backup created: $zipPath"

$manifestPath = Join-Path $releasesDir "release_manifest_$stamp.txt"
@(
    "GETREADYJOB $Version Production Snapshot",
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Repository: $repoRoot",
    "Commit: $headCommit",
    "Tag: $TagName",
    "Release Branch: $ReleaseBranch",
    "Bundle: $bundlePath",
    "Zip: $zipPath"
) | Set-Content -Path $manifestPath -Encoding UTF8
Write-Info "Manifest written: $manifestPath"

$rollbackPath = Join-Path $recoveryDir "ROLLBACK_V1_1.md"
@(
    "# GETREADYJOB V1.1 Rollback Quick Steps",
    "",
    "1. Clone or open repository.",
    "2. Fetch tags and branches.",
    "3. Checkout baseline branch: $ReleaseBranch",
    "4. Confirm tag points to baseline: $TagName",
    '5. Rebuild: flutter clean ; flutter pub get ; flutter build web --release -t lib/main_v1_1.dart --base-href "/"',
    "6. Redeploy build/web using Pages workflow.",
    "",
    "Bundle recovery:",
    "- git clone <repo-url>",
    "- git bundle verify `"$bundlePath`"",
    "- git fetch `"$bundlePath`" `"$TagName`":`"$TagName`" `"$ReleaseBranch`":`"$ReleaseBranch`"",
    "- git checkout $ReleaseBranch"
) | Set-Content -Path $rollbackPath -Encoding UTF8
Write-Info "Rollback instructions written: $rollbackPath"

$productionSnapshot = Join-Path $productionDir "$Version-$stamp-$shortCommit"
Ensure-Directory $productionSnapshot
Copy-Item -Path $bundlePath -Destination (Join-Path $productionSnapshot (Split-Path $bundlePath -Leaf)) -Force
Copy-Item -Path $zipPath -Destination (Join-Path $productionSnapshot (Split-Path $zipPath -Leaf)) -Force
Copy-Item -Path $manifestPath -Destination (Join-Path $productionSnapshot (Split-Path $manifestPath -Leaf)) -Force

Write-Info "Permanent production snapshot written: $productionSnapshot"
Write-Output "[DONE] Freeze snapshot complete for $Version at commit $shortCommit"
