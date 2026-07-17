$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$backupRoot = Join-Path (Split-Path -Parent $projectRoot) "backups"
$statusFile = Join-Path $projectRoot "BACKUP_STATUS.md"
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$backupFile = Join-Path $backupRoot "jobready_lib_backup_$timestamp.zip"

if (-not (Test-Path $backupRoot)) {
    New-Item -Path $backupRoot -ItemType Directory | Out-Null
}

$tempStaging = Join-Path $env:TEMP "jobready_backup_stage_$timestamp"
New-Item -Path $tempStaging -ItemType Directory | Out-Null

$excludeDirs = @(".git", ".dart_tool", "build", "node_modules", "backups")
$excludeFiles = @("*.tmp", "*.log")

$allItems = Get-ChildItem -Path $projectRoot -Recurse -Force
foreach ($item in $allItems) {
    $relativePath = $item.FullName.Substring($projectRoot.Length).TrimStart('\\')

    $isExcludedDir = $false
    foreach ($dir in $excludeDirs) {
        if ($relativePath -eq $dir -or $relativePath.StartsWith("$dir\\")) {
            $isExcludedDir = $true
            break
        }
    }

    if ($isExcludedDir) {
        continue
    }

    if ($item.PSIsContainer) {
        $targetDir = Join-Path $tempStaging $relativePath
        if (-not (Test-Path $targetDir)) {
            New-Item -Path $targetDir -ItemType Directory | Out-Null
        }
        continue
    }

    $skipFile = $false
    foreach ($pattern in $excludeFiles) {
        if ($item.Name -like $pattern) {
            $skipFile = $true
            break
        }
    }

    if ($skipFile) {
        continue
    }

    $targetFile = Join-Path $tempStaging $relativePath
    $targetParent = Split-Path -Parent $targetFile
    if (-not (Test-Path $targetParent)) {
        New-Item -Path $targetParent -ItemType Directory | Out-Null
    }

    Copy-Item -Path $item.FullName -Destination $targetFile -Force
}

if (Test-Path $backupFile) {
    Remove-Item -Path $backupFile -Force
}

Compress-Archive -Path (Join-Path $tempStaging "*") -DestinationPath $backupFile -CompressionLevel Optimal
Remove-Item -Path $tempStaging -Recurse -Force

$existingBackups = Get-ChildItem -Path $backupRoot -Filter "jobready_lib_backup_*.zip" | Sort-Object LastWriteTime -Descending
$keepCount = 14
if ($existingBackups.Count -gt $keepCount) {
    $existingBackups | Select-Object -Skip $keepCount | Remove-Item -Force
}

$lastBackupTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$statusLines = @(
    "# JOBREADY Backup Status",
    "",
    "Last backup: $lastBackupTime",
    "Last backup file: $backupFile",
    "Backup task: JOBREADY_Daily_Backup (daily at 21:00)",
    "Backup folder: $backupRoot"
)
Set-Content -Path $statusFile -Value $statusLines -Encoding UTF8

Write-Output "Backup created: $backupFile"
