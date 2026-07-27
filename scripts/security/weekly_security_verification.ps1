Param(
  [string]$SiteUrl = "https://getreadyjob.com",
  [string]$ApiLogPath = "c:\JobReadyIndia\jobready_india\logs\api_access.ndjson",
  [string]$AlertLogPath = "c:\JobReadyIndia\jobready_india\logs\api_key_alerts.log",
  [string]$ReportDir = "c:\JobReadyIndia\jobready_india\logs\security_reports"
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

if (-not (Test-Path $ReportDir)) {
  New-Item -ItemType Directory -Path $ReportDir | Out-Null
}

$timestamp = Get-Date
$stamp = $timestamp.ToString('yyyyMMdd_HHmmss')
$reportFile = Join-Path $ReportDir ("security_check_$stamp.md")

$headers = @{
  'Cache-Control' = 'no-cache, no-store, must-revalidate'
  'Pragma' = 'no-cache'
  'Expires' = '0'
}
$nonce = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

$panelPattern = 'Bank\s*&\s*Ads\s*API\s*Files|Download\s*Bank\s*API\s*File|Download\s*Ads\s*API\s*File'
$hiddenRefPattern = 'bank_api_packet_v1_1|ads_api_packet_v1_1|bank_ads_api_packet_v1_1|Bank\s*&\s*Ads\s*API\s*Files|Download\s*Bank\s*API\s*File|Download\s*Ads\s*API\s*File'

$legacyPaths = @(
  '/downloads/bank_api_packet_v1_1.md',
  '/downloads/ads_api_packet_v1_1.md',
  '/downloads/bank_ads_api_packet_v1_1.html',
  '/downloads/bank_ads_api_packet_v1_1.pdf'
)

$assetPaths = @(
  '/index.html',
  '/main.dart.js',
  '/main.dart.js_1.part.js',
  '/main.dart.js_2.part.js',
  '/main.dart.js_3.part.js',
  '/main.dart.js_4.part.js',
  '/main.dart.js_5.part.js',
  '/main.dart.js_6.part.js'
)

function Get-StatusCode {
  Param(
    [string]$Url,
    [System.Net.Http.HttpClient]$Client,
    [ref]$ErrorText
  )

  $ErrorText.Value = ''
  try {
    $resp = $Client.GetAsync([Uri]$Url).GetAwaiter().GetResult()
    return [int]$resp.StatusCode
  } catch {
    $ErrorText.Value = $_.Exception.Message
    return -1
  }
}

function Get-TextContent {
  Param(
    [string]$Url,
    [System.Net.Http.HttpClient]$Client
  )

  try {
    return $Client.GetStringAsync([Uri]$Url).GetAwaiter().GetResult()
  } catch {
    return $null
  }
}

function Test-RegexMatch {
  Param(
    [string]$Text,
    [string]$Pattern
  )
  return [bool]([regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
}

# 1) Homepage panel check
$homeUrl = "$SiteUrl/?nocache=$nonce"
$httpClient = New-Object System.Net.Http.HttpClient
$httpClient.DefaultRequestHeaders.Add('Cache-Control', 'no-cache, no-store, must-revalidate')
$httpClient.DefaultRequestHeaders.Add('Pragma', 'no-cache')
$homeContent = Get-TextContent -Url $homeUrl -Client $httpClient
$homeErr = ''
$homeStatusCode = Get-StatusCode -Url $homeUrl -Client $httpClient -ErrorText ([ref]$homeErr)

if ($null -eq $homeContent) {
  $homeContent = ''
}
$panelPresent = Test-RegexMatch -Text $homeContent -Pattern $panelPattern
$homeCheckPass = -not $panelPresent

# 2) Legacy URL status checks
$urlResults = @()
$legacyUrlsPass = $true
foreach ($path in $legacyPaths) {
  $url = $SiteUrl + $path + '?nocache=' + $nonce
  $urlErr = ''
  $code = Get-StatusCode -Url $url -Client $httpClient -ErrorText ([ref]$urlErr)
  $ok = ($code -eq 404 -or $code -eq 410)
  if (-not $ok) {
    $legacyUrlsPass = $false
  }
  $urlResults += [PSCustomObject]@{
    path = $path
    status = $code
    error = $urlErr
    pass = $ok
  }
}

# 3) Hidden references in homepage-delivered source
$assetResults = @()
$hiddenRefsPass = $true
foreach ($assetPath in $assetPaths) {
  $assetUrl = $SiteUrl + $assetPath + '?nocache=' + $nonce
  $content = ''
  $hasHiddenRef = $false

  try {
    $content = Get-TextContent -Url $assetUrl -Client $httpClient
    if ($null -eq $content) {
      $hasHiddenRef = $false
    } else {
      $hasHiddenRef = Test-RegexMatch -Text $content -Pattern $hiddenRefPattern
    }
  } catch {
    $hasHiddenRef = $true
  }

  if ($hasHiddenRef) {
    $hiddenRefsPass = $false
  }

  $assetResults += [PSCustomObject]@{
    asset = $assetPath
    hidden_ref_found = $hasHiddenRef
    pass = (-not $hasHiddenRef)
  }
}

# 4) API logs unusual usage summary
$logStatus = 'PASS'
$logMessage = 'No unusual key usage detected in alert log for the last 7 days.'
$recentAlerts = @()
$since = (Get-Date).ToUniversalTime().AddDays(-7)

if (-not (Test-Path $ApiLogPath)) {
  $logStatus = 'WARN'
  $logMessage = "API access log missing: $ApiLogPath"
} elseif (-not (Test-Path $AlertLogPath)) {
  $logStatus = 'WARN'
  $logMessage = "Alert log missing: $AlertLogPath"
} else {
  $recentAlerts = Get-Content -Path $AlertLogPath | Where-Object {
    if ([string]::IsNullOrWhiteSpace($_)) { return $false }
    $line = $_
    if ($line.Length -lt 20) { return $false }
    $stampText = $line.Substring(0, 19)
    try {
      $lineTime = [datetime]::Parse($stampText).ToUniversalTime()
      return $lineTime -ge $since
    } catch {
      return $false
    }
  }

  if ($recentAlerts.Count -gt 0) {
    $logStatus = 'FAIL'
    $logMessage = "Detected $($recentAlerts.Count) alert entries in the last 7 days."
  }
}

$overallPass = $homeCheckPass -and $legacyUrlsPass -and $hiddenRefsPass -and ($logStatus -ne 'FAIL')
$overallStatus = if ($overallPass) { 'PASS' } else { 'FAIL' }

$lines = @()
$lines += "# Weekly Security Verification Report"
$lines += ""
$lines += "- Time: $($timestamp.ToString('o'))"
$lines += "- Site: $SiteUrl"
$lines += "- Overall status: $overallStatus"
$lines += ""
$lines += "## 1) Homepage Bank/Ads API Panel"
$lines += "- Pass: $homeCheckPass"
$lines += "- Home status code: $homeStatusCode"
$lines += "- Panel present: $panelPresent"
$lines += ""
$lines += "## 2) Legacy Download URLs"
foreach ($result in $urlResults) {
  if ([string]::IsNullOrWhiteSpace($result.error)) {
    $lines += "- $($result.path) => status $($result.status), pass=$($result.pass)"
  } else {
    $lines += "- $($result.path) => status $($result.status), pass=$($result.pass), error=$($result.error)"
  }
}
$lines += ""
$lines += "## 3) Hidden References in Source/Bundles"
foreach ($asset in $assetResults) {
  $lines += "- $($asset.asset) => hidden_ref_found=$($asset.hidden_ref_found), pass=$($asset.pass)"
}
$lines += ""
$lines += "## 4) API Key Usage Anomaly Review"
$lines += "- Status: $logStatus"
$lines += "- Message: $logMessage"
if ($recentAlerts.Count -gt 0) {
  $lines += "- Recent alerts (last 7 days):"
  $recentAlerts | Select-Object -First 20 | ForEach-Object { $lines += "  - $_" }
}
$lines += ""
$lines += "## Report File"
$lines += "- $reportFile"

Set-Content -Path $reportFile -Value $lines -Encoding UTF8
$httpClient.Dispose()

Write-Output "SECURITY_REPORT_STATUS=$overallStatus"
Write-Output "SECURITY_REPORT_FILE=$reportFile"
Write-Output "SECURITY_LOG_STATUS=$logStatus"
