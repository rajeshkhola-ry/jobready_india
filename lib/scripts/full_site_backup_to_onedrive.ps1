$ErrorActionPreference = 'Stop'

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$backupDir = Join-Path $env:USERPROFILE 'OneDrive\JobReadyIndia_Backups'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$commit = (git -C $sourceRoot rev-parse --short HEAD).Trim()
$zipPath = Join-Path $backupDir ("jobready_india_full_{0}_{1}.zip" -f $stamp, $commit)

$mode = 'FULL_COPY'

try {
    Compress-Archive -Path (Join-Path $sourceRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
}
catch {
    # Fallback path if any file is locked (for example under node_modules).
    $mode = 'TRACKED_FILES_FALLBACK'
    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }
    git -C $sourceRoot archive --format=zip --output=$zipPath HEAD
}

$item = Get-Item $zipPath
$hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash

Write-Output ("BACKUP_MODE={0}" -f $mode)
Write-Output ("BACKUP_FILE={0}" -f $item.FullName)
Write-Output ("BACKUP_SIZE={0}" -f $item.Length)
Write-Output ("BACKUP_TIME={0}" -f $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
Write-Output ("BACKUP_SHA256={0}" -f $hash)
