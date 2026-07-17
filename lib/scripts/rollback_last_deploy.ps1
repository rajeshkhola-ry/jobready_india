param(
  [string]$SiteUrl = "https://getreadyjob.com/",
  [string]$WorkflowFile = ".github/workflows/deploy-preview-gh-pages.yml",
  [int]$PollSeconds = 15,
  [int]$TimeoutMinutes = 20,
  [string]$TargetSha = "",
  [switch]$DryRun,
  [string]$ExpectedStableVersion = "v1.2.3",
  [switch]$ConfirmBackup
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "[ROLLBACK] $Message" -ForegroundColor Cyan
}

function Write-Info {
  param([string]$Message)
  Write-Host "[ROLLBACK] $Message" -ForegroundColor Gray
}

function Invoke-Git {
  param(
    [string]$RepoRoot,
    [string[]]$Arguments,
    [switch]$IgnoreExitCode
  )

  $output = & git -C $RepoRoot @Arguments 2>&1
  $exitCode = $LASTEXITCODE

  if (-not $IgnoreExitCode -and $exitCode -ne 0) {
    $joined = $Arguments -join " "
    throw "git $joined failed with exit code $exitCode. Output: $output"
  }

  return [string[]]$output
}

function Get-GitRoot {
  param([string]$StartPath)

  $root = (& git -C $StartPath rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $root) {
    throw "Unable to locate Git repository from: $StartPath"
  }

  return $root.Trim()
}

function Get-GitBranch {
  param([string]$RepoRoot)

  $branch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $branch) {
    throw "Unable to detect current Git branch."
  }

  return $branch.Trim()
}

function Get-RepoSlugFromOrigin {
  param([string]$RepoRoot)

  $origin = (& git -C $RepoRoot config --get remote.origin.url 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $origin) {
    throw "remote.origin.url is not configured."
  }

  $origin = $origin.Trim()
  $match = [regex]::Match($origin, "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(?:\.git)?$")
  if (-not $match.Success) {
    throw "Only GitHub origins are supported by this script. Found: $origin"
  }

  return "$($match.Groups['owner'].Value)/$($match.Groups['repo'].Value)"
}

function Wait-ForWorkflowRun {
  param(
    [string]$RepoSlug,
    [string]$Branch,
    [string]$ExpectedSha,
    [string]$WorkflowFile,
    [int]$PollSeconds,
    [int]$TimeoutMinutes
  )

  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
  $run = $null

  Write-Step "Waiting for GitHub Actions run for commit $ExpectedSha"

  while ((Get-Date) -lt $deadline) {
    $url = "https://api.github.com/repos/$RepoSlug/actions/runs?branch=$Branch&event=push&per_page=30"
    $resp = Invoke-RestMethod -Method Get -Uri $url -Headers @{ "User-Agent" = "jobready-rollback" }

    if ($resp.workflow_runs) {
      $run = $resp.workflow_runs |
        Where-Object { $_.head_sha -eq $ExpectedSha -and $_.path -eq $WorkflowFile } |
        Select-Object -First 1
    }

    if ($run) { break }

    Write-Info "Run not found yet. Retrying in $PollSeconds seconds..."
    Start-Sleep -Seconds $PollSeconds
  }

  if (-not $run) {
    throw "Timed out waiting for workflow run for commit $ExpectedSha"
  }

  $runId = $run.id
  Write-Info "Found run: $($run.html_url)"

  while ((Get-Date) -lt $deadline) {
    $runUrl = "https://api.github.com/repos/$RepoSlug/actions/runs/$runId"
    $details = Invoke-RestMethod -Method Get -Uri $runUrl -Headers @{ "User-Agent" = "jobready-rollback" }

    if ($details.status -eq "completed") {
      if ($details.conclusion -eq "success") {
        Write-Host "[ROLLBACK] Deploy success for $ExpectedSha" -ForegroundColor Green
        return $details
      }

      throw "Deploy completed but failed. Conclusion: $($details.conclusion). Run: $($details.html_url)"
    }

    Write-Info "Run status: $($details.status). Waiting $PollSeconds seconds..."
    Start-Sleep -Seconds $PollSeconds
  }

  throw "Timed out waiting for deploy completion."
}

function Test-LiveSite {
  param([string]$SiteUrl)

  Write-Step "Checking live site: $SiteUrl"
  $response = Invoke-WebRequest -Uri $SiteUrl -Method Get -MaximumRedirection 5 -TimeoutSec 40 -UseBasicParsing
  $status = [int]$response.StatusCode

  if ($status -lt 200 -or $status -ge 400) {
    throw "Site check failed. HTTP status: $status"
  }

  Write-Host "[ROLLBACK] Site is reachable after rollback." -ForegroundColor Green
}

function Add-ReleaseHistoryEntry {
  param(
    [string]$RepoRoot,
    [string]$CommitSha,
    [string]$Status,
    [string]$Notes,
    [string]$Version = "unversioned"
  )

  $historyPath = Join-Path $RepoRoot "RELEASE_HISTORY.md"
  if (-not (Test-Path $historyPath)) {
    $header = @(
      "# RELEASE HISTORY",
      "",
      "| Version | Commit SHA | Deployment Date (UTC) | Status | Rollback Available | Notes |",
      "|---|---|---|---|---|---|"
    )
    Set-Content -Path $historyPath -Value $header -Encoding UTF8
  }

  $dateUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $shortSha = if ($CommitSha.Length -gt 7) { $CommitSha.Substring(0, 7) } else { $CommitSha }
  $safeNotes = ($Notes -replace "\|", "/")
  $line = "| $Version | $shortSha | $dateUtc | $Status | Yes | $safeNotes |"
  Add-Content -Path $historyPath -Value $line -Encoding UTF8
  Write-Info "Release history updated: $historyPath"
}

function Resolve-RollbackTargetSha {
  param(
    [string]$RepoSlug,
    [string]$Branch,
    [string]$WorkflowFile,
    [string]$CurrentHead,
    [string]$RequestedSha
  )

  if ($RequestedSha -and $RequestedSha.Trim().Length -gt 0) {
    return $RequestedSha.Trim()
  }

  $url = "https://api.github.com/repos/$RepoSlug/actions/runs?branch=$Branch&event=push&per_page=50"
  $resp = Invoke-RestMethod -Method Get -Uri $url -Headers @{ "User-Agent" = "jobready-rollback" }

  if (-not $resp.workflow_runs) {
    throw "No workflow runs found for branch '$Branch'."
  }

  $candidate = $resp.workflow_runs |
    Where-Object { $_.path -eq $WorkflowFile -and $_.status -eq "completed" -and $_.conclusion -eq "success" -and $_.head_sha -ne $CurrentHead } |
    Select-Object -First 1

  if (-not $candidate) {
    throw "Could not find a previous successful deployment different from current HEAD."
  }

  return $candidate.head_sha
}

function Get-WorkingTreeIsClean {
  param([string]$RepoRoot)

  $status = Invoke-Git -RepoRoot $RepoRoot -Arguments @("status", "--porcelain")
  return (-not $status -or $status.Count -eq 0)
}

function Get-ReleaseHistoryStableSha {
  param(
    [string]$RepoRoot,
    [string]$Version
  )

  $historyPath = Join-Path $RepoRoot "RELEASE_HISTORY.md"
  if (-not (Test-Path $historyPath)) {
    throw "RELEASE_HISTORY.md not found at repo root."
  }

  $lines = Get-Content -Path $historyPath
  foreach ($line in $lines) {
    if ($line -match "^\|\s*$([regex]::Escape($Version))\s*\|\s*([0-9a-fA-F]{7,40})\s*\|.*\|\s*Stable\s*\|") {
      return $matches[1]
    }
  }

  throw "Stable mapping for version '$Version' not found in RELEASE_HISTORY.md"
}

function Get-BackupFileFromStatus {
  param([string]$RepoRoot)

  $statusPath = Join-Path $RepoRoot "BACKUP_STATUS.md"
  if (-not (Test-Path $statusPath)) {
    return ""
  }

  $line = (Get-Content -Path $statusPath | Where-Object { $_ -like "Last backup file:*" } | Select-Object -First 1)
  if (-not $line) {
    return ""
  }

  return ($line -replace "^Last backup file:\s*", "").Trim()
}

function Confirm-SafetyChecks {
  param(
    [string]$RepoRoot,
    [string]$ExpectedVersion,
    [string]$ResolvedTargetSha,
    [switch]$DryRun,
    [switch]$ConfirmBackup
  )

  Write-Step "Safety preflight checks"

  # 1) Stable version mapping exists in release history.
  $mappedSha = Get-ReleaseHistoryStableSha -RepoRoot $RepoRoot -Version $ExpectedVersion
  Write-Info "Check 1 passed: $ExpectedVersion is mapped to stable SHA $mappedSha"

  # 2) Backup confirmation and backup file evidence.
  $backupFile = Get-BackupFileFromStatus -RepoRoot $RepoRoot
  if (-not $backupFile) {
    throw "Check 2 failed: backup file record not found in BACKUP_STATUS.md"
  }
  if (-not (Test-Path $backupFile)) {
    throw "Check 2 failed: backup file path does not exist: $backupFile"
  }
  if (-not $DryRun -and -not $ConfirmBackup) {
    throw "Check 2 failed: pass -ConfirmBackup to acknowledge v1.2.4 keep-work backup confirmation."
  }
  Write-Info "Check 2 passed: backup evidence found at $backupFile"

  # 3) Working tree must be clean for real rollback.
  if (-not $DryRun) {
    $isClean = Get-WorkingTreeIsClean -RepoRoot $RepoRoot
    if (-not $isClean) {
      throw "Check 3 failed: working tree is not clean. Commit or stash changes before rollback."
    }
    Write-Info "Check 3 passed: working tree is clean"
  } else {
    Write-Info "Check 3 skipped in DryRun: working tree cleanliness not enforced"
  }

  # 4) Target SHA must match mapped stable version SHA.
  $targetShort = if ($ResolvedTargetSha.Length -ge 7) { $ResolvedTargetSha.Substring(0, 7) } else { $ResolvedTargetSha }
  $mappedShort = if ($mappedSha.Length -ge 7) { $mappedSha.Substring(0, 7) } else { $mappedSha }
  if ($targetShort -ne $mappedShort) {
    throw "Check 4 failed: rollback target SHA '$ResolvedTargetSha' does not match $ExpectedVersion mapping '$mappedSha'."
  }
  Write-Info "Check 4 passed: rollback target matches $ExpectedVersion"
}

try {
  $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
  $repoRoot = Get-GitRoot -StartPath $scriptRoot
  $repoSlug = Get-RepoSlugFromOrigin -RepoRoot $repoRoot
  $branch = Get-GitBranch -RepoRoot $repoRoot
  $head = (Invoke-Git -RepoRoot $repoRoot -Arguments @("rev-parse", "HEAD"))[0].Trim()

  Write-Step "Repository: $repoSlug ($branch)"
  Write-Info "Repo root: $repoRoot"
  Write-Info "Current HEAD: $head"

  $target = Resolve-RollbackTargetSha -RepoSlug $repoSlug -Branch $branch -WorkflowFile $WorkflowFile -CurrentHead $head -RequestedSha $TargetSha
  Write-Info "Rollback target stable SHA: $target"

  Confirm-SafetyChecks -RepoRoot $repoRoot -ExpectedVersion $ExpectedStableVersion -ResolvedTargetSha $target -DryRun:$DryRun -ConfirmBackup:$ConfirmBackup

  Invoke-Git -RepoRoot $repoRoot -Arguments @("cat-file", "-e", "$target^{commit}") | Out-Null

  $commitsToRevert = Invoke-Git -RepoRoot $repoRoot -Arguments @("rev-list", "$target..HEAD")
  $commitCount = @($commitsToRevert).Count

  if ($commitCount -eq 0) {
    Write-Host "[ROLLBACK] Nothing to rollback. HEAD already equals target." -ForegroundColor Yellow
    Test-LiveSite -SiteUrl $SiteUrl
    exit 0
  }

  Write-Step "Rollback plan"
  Write-Info "Will revert $commitCount commit(s) to return to $target"

  if ($DryRun) {
    Write-Host "[ROLLBACK] DryRun enabled. No commit/push performed." -ForegroundColor Yellow
    Write-Info "Would run git revert --no-commit for each commit in: $target..HEAD"
    Write-Info "Would create a rollback commit and push to origin/$branch"
    Write-Info "Would wait for deployment success and then test $SiteUrl"
    Write-Info "Would append a release row to RELEASE_HISTORY.md"
    exit 0
  }

  Write-Step "Applying rollback (reverting commits)"
  foreach ($sha in $commitsToRevert) {
    if (-not $sha) { continue }
    Write-Info "Reverting $sha"
    try {
      Invoke-Git -RepoRoot $repoRoot -Arguments @("revert", "--no-commit", $sha) | Out-Null
    } catch {
      Invoke-Git -RepoRoot $repoRoot -Arguments @("revert", "--abort") -IgnoreExitCode | Out-Null
      throw "Rollback conflict while reverting $sha. Resolve manually, then rerun."
    }
  }

  & git -C $repoRoot diff --cached --quiet --exit-code
  if ($LASTEXITCODE -eq 0) {
    Write-Host "[ROLLBACK] No staged rollback changes; nothing to commit." -ForegroundColor Yellow
    exit 0
  }

  $shortTarget = $target.Substring(0, [Math]::Min(8, $target.Length))
  $message = "rollback: restore stable deploy $shortTarget"

  Write-Step "Creating rollback commit"
  Invoke-Git -RepoRoot $repoRoot -Arguments @("commit", "-m", $message) | Out-Null

  Write-Step "Pushing rollback to origin/$branch"
  Invoke-Git -RepoRoot $repoRoot -Arguments @("push", "origin", $branch) | Out-Null

  $newHead = (Invoke-Git -RepoRoot $repoRoot -Arguments @("rev-parse", "HEAD"))[0].Trim()
  Write-Info "Rollback commit pushed: $newHead"

  $run = Wait-ForWorkflowRun -RepoSlug $repoSlug -Branch $branch -ExpectedSha $newHead -WorkflowFile $WorkflowFile -PollSeconds $PollSeconds -TimeoutMinutes $TimeoutMinutes
  Write-Info "Run URL: $($run.html_url)"

  Add-ReleaseHistoryEntry -RepoRoot $repoRoot -CommitSha $newHead -Status "Rollback" -Notes "Rollback applied to restore stable deploy $shortTarget"

  Test-LiveSite -SiteUrl $SiteUrl

} catch {
  Write-Host ""
  Write-Host "[ROLLBACK] FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
