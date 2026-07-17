param(
  [string]$SiteUrl = "https://getreadyjob.com/",
  [string]$WorkflowFile = ".github/workflows/deploy-preview-gh-pages.yml",
  [int]$PollSeconds = 15,
  [int]$TimeoutMinutes = 20,
  [switch]$Watch,
  [int]$DebounceSeconds = 8,
  [switch]$DryRun,
  [switch]$AutoStageAll
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "[AUTO-SYNC] $Message" -ForegroundColor Cyan
}

function Write-Info {
  param([string]$Message)
  Write-Host "[AUTO-SYNC] $Message" -ForegroundColor Gray
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

function Convert-PathToNormalized {
  param([string]$Path)
  return ($Path -replace "\\", "/").Trim()
}

function Test-EligibleCodePath {
  param(
    [string]$RelativePath,
    [switch]$AutoStageAll
  )

  $p = Convert-PathToNormalized $RelativePath
  if (-not $p) { return $false }

  $excludedPrefixes = @(
    ".dart_tool/",
    "build/",
    "android/build/",
    "ios/Pods/",
    "node_modules/",
    "backups/",
    ".git/"
  )

  foreach ($prefix in $excludedPrefixes) {
    if ($p.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $false
    }
  }

  if ($p -eq ".vscode/tasks.json" -or $p -eq "lib/.vscode/tasks.json") {
    return $false
  }

  if ($AutoStageAll) {
    return $true
  }

  $allowedPrefixes = @(
    "lib/",
    "web/",
    "assets/",
    "scripts/",
    ".github/"
  )

  $allowedTopFiles = @(
    "pubspec.yaml",
    "pubspec.lock",
    "README.md",
    "CNAME"
  )

  if ($allowedTopFiles -contains $p) {
    return $true
  }

  foreach ($prefix in $allowedPrefixes) {
    if ($p.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function Get-ChangedPaths {
  param([string]$RepoRoot)

  $lines = Invoke-Git -RepoRoot $RepoRoot -Arguments @("status", "--porcelain")
  $paths = New-Object System.Collections.Generic.List[string]

  foreach ($line in $lines) {
    if (-not $line) { continue }
    if ($line.Length -lt 4) { continue }

    $pathPart = $line.Substring(3).Trim()
    if (-not $pathPart) { continue }

    if ($pathPart.Contains(" -> ")) {
      $pathPart = ($pathPart -split " -> ")[-1]
    }

    $paths.Add((Convert-PathToNormalized $pathPart))
  }

  return ($paths | Select-Object -Unique)
}

function Get-EligibleChanges {
  param(
    [string]$RepoRoot,
    [switch]$AutoStageAll
  )

  $all = Get-ChangedPaths -RepoRoot $RepoRoot
  $eligible = New-Object System.Collections.Generic.List[string]
  $ignored = New-Object System.Collections.Generic.List[string]

  foreach ($path in $all) {
    if (Test-EligibleCodePath -RelativePath $path -AutoStageAll:$AutoStageAll) {
      $eligible.Add($path)
    } else {
      $ignored.Add($path)
    }
  }

  return [pscustomobject]@{
    Eligible = $eligible | Select-Object -Unique
    Ignored  = $ignored | Select-Object -Unique
  }
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
    $resp = Invoke-RestMethod -Method Get -Uri $url -Headers @{ "User-Agent" = "jobready-auto-sync" }

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
    $details = Invoke-RestMethod -Method Get -Uri $runUrl -Headers @{ "User-Agent" = "jobready-auto-sync" }

    if ($details.status -eq "completed") {
      if ($details.conclusion -eq "success") {
        Write-Host "[AUTO-SYNC] Deploy success for $ExpectedSha" -ForegroundColor Green
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

  $content = [string]$response.Content
  if (-not $content -or ($content -notmatch "flutter|JOBREADY|flt-")) {
    Write-Host "[AUTO-SYNC] Site responded, but marker text was not obvious. Please manually verify UI once." -ForegroundColor Yellow
  } else {
    Write-Host "[AUTO-SYNC] Site is reachable and serving content." -ForegroundColor Green
  }
}

function Invoke-SyncPipeline {
  param(
    [string]$RepoRoot,
    [string]$RepoSlug,
    [string]$Branch,
    [string]$WorkflowFile,
    [string]$SiteUrl,
    [int]$PollSeconds,
    [int]$TimeoutMinutes,
    [switch]$DryRun,
    [switch]$AutoStageAll
  )

  $changeSet = Get-EligibleChanges -RepoRoot $RepoRoot -AutoStageAll:$AutoStageAll
  $eligible = @($changeSet.Eligible)
  $ignored = @($changeSet.Ignored)

  if ($ignored.Count -gt 0) {
    Write-Info "Ignored non-code/safe paths:"
    foreach ($p in $ignored) {
      Write-Info "  - $p"
    }
  }

  if ($eligible.Count -eq 0) {
    Write-Step "No eligible code changes found"
    Test-LiveSite -SiteUrl $SiteUrl
    return
  }

  Write-Step "Eligible changes detected"
  foreach ($p in $eligible) {
    Write-Info "  - $p"
  }

  if ($DryRun) {
    Write-Host "[AUTO-SYNC] DryRun enabled. No commit/push was performed." -ForegroundColor Yellow
    return
  }

  Write-Step "Staging eligible files"
  Invoke-Git -RepoRoot $RepoRoot -Arguments (@("add", "--") + $eligible) | Out-Null

  $staged = Invoke-Git -RepoRoot $RepoRoot -Arguments @("diff", "--cached", "--name-only")
  if (-not $staged -or $staged.Count -eq 0) {
    Write-Info "Nothing staged after filtering; skipping commit."
    return
  }

  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $message = "auto: sync site updates ($stamp)"

  Write-Step "Creating commit"
  Invoke-Git -RepoRoot $RepoRoot -Arguments @("commit", "-m", $message) | Out-Null

  Write-Step "Pushing to origin/$Branch"
  Invoke-Git -RepoRoot $RepoRoot -Arguments @("push", "origin", $Branch) | Out-Null

  $sha = (Invoke-Git -RepoRoot $RepoRoot -Arguments @("rev-parse", "HEAD"))[0].Trim()
  Write-Info "Pushed commit: $sha"

  $run = Wait-ForWorkflowRun -RepoSlug $RepoSlug -Branch $Branch -ExpectedSha $sha -WorkflowFile $WorkflowFile -PollSeconds $PollSeconds -TimeoutMinutes $TimeoutMinutes
  Write-Info "Run URL: $($run.html_url)"

  Test-LiveSite -SiteUrl $SiteUrl
}

try {
  $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
  $repoRoot = Get-GitRoot -StartPath $scriptRoot
  $repoSlug = Get-RepoSlugFromOrigin -RepoRoot $repoRoot
  $branch = Get-GitBranch -RepoRoot $repoRoot

  Write-Step "Repository: $repoSlug ($branch)"
  Write-Info "Repo root: $repoRoot"

  if (-not $Watch) {
    Invoke-SyncPipeline -RepoRoot $repoRoot -RepoSlug $repoSlug -Branch $branch -WorkflowFile $WorkflowFile -SiteUrl $SiteUrl -PollSeconds $PollSeconds -TimeoutMinutes $TimeoutMinutes -DryRun:$DryRun -AutoStageAll:$AutoStageAll
    exit 0
  }

  Write-Step "Watch mode started"
  Write-Info "The script will auto-run after changes are stable for $DebounceSeconds seconds."
  Write-Info "Press Ctrl+C to stop."

  $lastFingerprint = ""
  $stableSince = $null

  while ($true) {
    $changeSet = Get-EligibleChanges -RepoRoot $repoRoot -AutoStageAll:$AutoStageAll
    $eligible = @($changeSet.Eligible)
    $fingerprint = ($eligible | Sort-Object) -join "|"

    if ($eligible.Count -eq 0) {
      $lastFingerprint = ""
      $stableSince = $null
      Start-Sleep -Seconds 2
      continue
    }

    if ($fingerprint -ne $lastFingerprint) {
      $lastFingerprint = $fingerprint
      $stableSince = Get-Date
      Write-Info "Detected code changes. Waiting for stability..."
      Start-Sleep -Seconds 2
      continue
    }

    if ($stableSince -and ((Get-Date) - $stableSince).TotalSeconds -ge $DebounceSeconds) {
      try {
        Invoke-SyncPipeline -RepoRoot $repoRoot -RepoSlug $repoSlug -Branch $branch -WorkflowFile $WorkflowFile -SiteUrl $SiteUrl -PollSeconds $PollSeconds -TimeoutMinutes $TimeoutMinutes -DryRun:$DryRun -AutoStageAll:$AutoStageAll
      } catch {
        Write-Host "[AUTO-SYNC] Pipeline error: $($_.Exception.Message)" -ForegroundColor Red
      }

      $lastFingerprint = ""
      $stableSince = $null
    }

    Start-Sleep -Seconds 2
  }

} catch {
  Write-Host ""
  Write-Host "[AUTO-SYNC] FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
