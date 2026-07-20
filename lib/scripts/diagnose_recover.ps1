param(
  [int]$WebPort = 54322,
  [string]$Target = "lib/main_v1_1.dart",
  [switch]$SkipAnalyze
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "[DIAGNOSE] $Message" -ForegroundColor Cyan
}

function Invoke-CommandChecked {
  param(
    [string]$Command,
    [string[]]$Arguments
  )

  Write-Host "> $Command $($Arguments -join ' ')" -ForegroundColor DarkGray
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
  }
}

function Stop-PortProcess {
  param([int]$Port)

  $connections = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
  if (-not $connections) {
    Write-Host "No listening process found on port $Port."
    return
  }

  $pids = $connections | Select-Object -ExpandProperty OwningProcess -Unique
  foreach ($procId in $pids) {
    try {
      $proc = Get-Process -Id $procId -ErrorAction Stop
      Write-Host "Stopping PID $procId ($($proc.ProcessName)) on port $Port..."
      Stop-Process -Id $procId -Force -ErrorAction Stop
    } catch {
      Write-Host "Could not stop PID ${procId}: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
}

try {
  $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
  $pushedLocation = $false
  Push-Location $projectRoot
  $pushedLocation = $true

  Write-Step "Project root: $projectRoot"

  $requiredFiles = @(
    "main_v1_1.dart",
    "Pages/admin_gate_page.dart",
    "Pages/coming_soon_page.dart",
    "Pages/home_page_v2.dart",
    "Pages/v2/converter/converter_workspace_page.dart",
    "Pages/system_check_page.dart"
  )

  Write-Step "Checking core files"
  $missing = @()
  foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
      $missing += $file
    }
  }

  if ($missing.Count -gt 0) {
    throw "Missing required files: $($missing -join ', ')"
  }
  Write-Host "Core files look good."

  Write-Step "Scanning for placeholder release text"
  $patterns = @(
    "coming in phase",
    "feature coming soon",
    "coming soon"
  )

  $scanPaths = @("main_v1_1.dart", "Pages", "Widgets", "Services")
  $scanFiles = @()
  foreach ($scanPath in $scanPaths) {
    if (Test-Path $scanPath -PathType Leaf) {
      $scanFiles += (Resolve-Path $scanPath).Path
    } elseif (Test-Path $scanPath -PathType Container) {
      $scanFiles += Get-ChildItem -Path $scanPath -Recurse -File -Filter "*.dart" | Select-Object -ExpandProperty FullName
    }
  }

  $hits = @()
  if ($scanFiles.Count -gt 0) {
    $hits = Select-String -Path $scanFiles -Pattern $patterns -SimpleMatch -ErrorAction SilentlyContinue
  }

  if ($hits) {
    Write-Host "Found placeholder text in active app files:" -ForegroundColor Yellow
    $hits | Select-Object -First 20 | ForEach-Object {
      Write-Host " - $($_.Path):$($_.LineNumber) -> $($_.Line.Trim())" -ForegroundColor Yellow
    }
    Write-Host "Continuing recovery, but review these lines before release." -ForegroundColor Yellow
  } else {
    Write-Host "No placeholder release text found in scanned files."
  }

  Write-Step "Stopping stale process on port $WebPort"
  Stop-PortProcess -Port $WebPort

  Write-Step "Cleaning Flutter build artifacts"
  Invoke-CommandChecked -Command "flutter" -Arguments @("clean")

  Write-Step "Restoring dependencies"
  Invoke-CommandChecked -Command "flutter" -Arguments @("pub", "get")

  if (-not $SkipAnalyze) {
    Write-Step "Running analyzer"
    Invoke-CommandChecked -Command "flutter" -Arguments @("analyze")
  } else {
    Write-Host "Analyzer skipped by flag."
  }

  Write-Step "Starting app in Chrome"
  Write-Host "Use this URL after launch: http://localhost:$WebPort/#/home" -ForegroundColor Green
  & flutter run -d chrome --web-port $WebPort -t $Target

} catch {
  Write-Host ""
  Write-Host "[DIAGNOSE] FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  if ($pushedLocation) {
    Pop-Location
  }
}
