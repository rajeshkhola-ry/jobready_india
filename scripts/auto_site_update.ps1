param(
    [string]$RepoPath = "C:\JobReadyIndia\jobready_india",
    [string]$Remote = "origin",
    [string]$Branch = "main",
    [string]$Owner = "rajeshkhola-ry",
    [string]$Repo = "jobready_india",
    [string]$WorkflowFile = ".github/workflows/deploy-preview-gh-pages.yml",
    [string]$SiteUrl = "https://getreadyjob.com/",
    [int]$MaxWaitMinutes = 20,
    [string]$CommitMessage = "",
    [string[]]$IncludePaths = @(),
    [string[]]$ExcludePaths = @(
        "android/build",
        "build",
        "lib/build",
        ".dart_tool",
        ".idea",
        ".vscode/tasks.json",
        "lib/.vscode/tasks.json"
    )
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string[]]$Args,
        [switch]$IgnoreFailure
    )

    $output = & git @Args 2>&1
    $exit = $LASTEXITCODE

    if (-not $IgnoreFailure -and $exit -ne 0) {
        throw "git $($Args -join ' ') failed.`n$output"
    }

    return [pscustomobject]@{
        ExitCode = $exit
        Output = ($output -join "`n").Trim()
    }
}

function Invoke-GitHubApi {
    param([Parameter(Mandatory = $true)][string]$Url)

    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "jobready-auto-site-update"
    }

    return Invoke-RestMethod -Method Get -Uri $Url -Headers $headers
}

function Get-WorkflowRunForSha {
    param(
        [string]$OwnerName,
        [string]$RepoName,
        [string]$Sha,
        [string]$WorkflowPath,
        [string]$TargetBranch
    )

    $url = "https://api.github.com/repos/$OwnerName/$RepoName/actions/runs?head_sha=$Sha&per_page=30"
    $data = Invoke-GitHubApi -Url $url

    if (-not $data.workflow_runs) {
        return $null
    }

    $run = $data.workflow_runs |
        Where-Object { $_.path -eq $WorkflowPath -and $_.head_branch -eq $TargetBranch } |
        Select-Object -First 1

    return $run
}

function Get-RemoteBranchSha {
    param(
        [string]$RemoteName,
        [string]$BranchName
    )

    $result = Invoke-Git -Args @("ls-remote", "--heads", $RemoteName, $BranchName)
    if ([string]::IsNullOrWhiteSpace($result.Output)) {
        return ""
    }

    return ($result.Output -split "\s+")[0].Trim()
}

try {
    Write-Step "Preparing"

    if (-not (Test-Path $RepoPath)) {
        throw "Repo path not found: $RepoPath"
    }

    Set-Location $RepoPath

    $insideRepo = Invoke-Git -Args @("rev-parse", "--is-inside-work-tree")
    if ($insideRepo.Output -ne "true") {
        throw "Not a git repository: $RepoPath"
    }

    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $CommitMessage = "auto: site update $timestamp"
    }

    Write-Host "Repo       : $RepoPath"
    Write-Host "Branch     : $Branch"
    Write-Host "Workflow   : $WorkflowFile"
    Write-Host "Site       : $SiteUrl"

    Write-Step "Fetching latest remote state"
    Invoke-Git -Args @("fetch", $Remote, $Branch) | Out-Null

    Write-Step "Staging changes"
    if ($IncludePaths.Count -gt 0) {
        Write-Host "Mode       : include only selected paths"
        Invoke-Git -Args @("add", "--") + $IncludePaths | Out-Null
    }
    else {
        Write-Host "Mode       : auto stage all, then exclude generated/noisy paths"
        Invoke-Git -Args @("add", "-A") | Out-Null
        foreach ($path in $ExcludePaths) {
            Invoke-Git -Args @("reset", "-q", "HEAD", "--", $path) -IgnoreFailure | Out-Null
        }
    }

    $staged = Invoke-Git -Args @("diff", "--cached", "--name-only")
    $stagedFiles = @()
    if (-not [string]::IsNullOrWhiteSpace($staged.Output)) {
        $stagedFiles = $staged.Output -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }

    $targetSha = ""

    if ($stagedFiles.Count -eq 0) {
        Write-Step "No new code changes detected"
        Write-Host "Nothing staged. Skipping commit and push."
        $targetSha = (Invoke-Git -Args @("rev-parse", "HEAD")).Output
    }
    else {
        Write-Host "Files to commit:"
        $stagedFiles | ForEach-Object { Write-Host " - $_" }

        Write-Step "Committing"
        Invoke-Git -Args @("commit", "-m", $CommitMessage) | Out-Null

        $targetSha = (Invoke-Git -Args @("rev-parse", "HEAD")).Output
        Write-Host "Commit SHA  : $targetSha"

        Write-Step "Pushing"
        Invoke-Git -Args @("push", $Remote, $Branch) | Out-Null
    }

    Write-Step "Verifying remote branch head"
    $remoteSha = Get-RemoteBranchSha -RemoteName $Remote -BranchName $Branch
    Write-Host "Remote SHA  : $remoteSha"
    Write-Host "Target SHA  : $targetSha"

    if ($remoteSha -ne $targetSha) {
        Write-Host "Remote has not moved to target SHA yet. Waiting a few seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 4
        $remoteSha = Get-RemoteBranchSha -RemoteName $Remote -BranchName $Branch
        Write-Host "Remote SHA  : $remoteSha"
    }

    if ($remoteSha -ne $targetSha) {
        throw "Remote branch SHA does not match target SHA."
    }

    Write-Step "Watching deployment"
    $deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
    $run = $null

    while ((Get-Date) -lt $deadline) {
        $run = Get-WorkflowRunForSha -OwnerName $Owner -RepoName $Repo -Sha $targetSha -WorkflowPath $WorkflowFile -TargetBranch $Branch

        if ($null -eq $run) {
            Write-Host "Run not found yet for SHA $targetSha. Waiting..."
            Start-Sleep -Seconds 8
            continue
        }

        Write-Host "Run ID      : $($run.id)"
        Write-Host "Run Status  : $($run.status)"
        Write-Host "Conclusion  : $($run.conclusion)"
        Write-Host "Run URL     : $($run.html_url)"

        if ($run.status -eq "completed") {
            break
        }

        Start-Sleep -Seconds 8
    }

    if ($null -eq $run) {
        throw "No workflow run found for SHA $targetSha within timeout."
    }

    if ($run.status -ne "completed") {
        throw "Workflow did not complete in time. Last status: $($run.status)"
    }

    if ($run.conclusion -ne "success") {
        throw "Workflow completed but failed. Conclusion: $($run.conclusion). See: $($run.html_url)"
    }

    Write-Step "Checking live site"
    $response = Invoke-WebRequest -Uri $SiteUrl -UseBasicParsing -TimeoutSec 45
    $statusCode = [int]$response.StatusCode
    $title = ""

    if ($response.Content -match "<title>(.*?)</title>") {
        $title = $Matches[1]
    }

    Write-Host "HTTP Status : $statusCode"
    Write-Host "Page Title  : $title"

    if ($statusCode -lt 200 -or $statusCode -ge 400) {
        throw "Site check failed with HTTP status $statusCode"
    }

    Write-Step "Done"
    Write-Host "SUCCESS: Update and deployment verification completed."
    Write-Host "Deployed SHA: $targetSha"
    Write-Host "Workflow   : $($run.html_url)"
    Write-Host "Site       : $SiteUrl"
    exit 0
}
catch {
    Write-Host "`nFAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
