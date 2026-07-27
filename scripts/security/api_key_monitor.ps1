Param(
  [string]$LogPath = "c:\JobReadyIndia\jobready_india\logs\api_access.ndjson",
  [string]$AlertPath = "c:\JobReadyIndia\jobready_india\logs\api_key_alerts.log",
  [int]$SpikeThresholdPerHour = 500
)

$ErrorActionPreference = 'Stop'

function Write-Alert {
  Param([string]$Message)
  $line = "$(Get-Date -Format o) ALERT $Message"
  Add-Content -Path $AlertPath -Value $line
  Write-Output $line
}

function Split-EnvList {
  Param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return @()
  }
  return ($Value -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

if (-not (Test-Path $LogPath)) {
  Write-Output "No log file at $LogPath. Skipping check."
  exit 0
}

$bankAllowedIps = Split-EnvList -Value $env:BANK_API_ALLOWED_IPS
$adsAllowedIps = Split-EnvList -Value $env:ADS_API_ALLOWED_IPS
$bankAllowedRegions = (Split-EnvList -Value $env:BANK_API_ALLOWED_REGIONS) | ForEach-Object { $_.ToUpperInvariant() }
$adsAllowedRegions = (Split-EnvList -Value $env:ADS_API_ALLOWED_REGIONS) | ForEach-Object { $_.ToUpperInvariant() }

$since = (Get-Date).ToUniversalTime().AddHours(-24)
$rows = @()

Get-Content -Path $LogPath | ForEach-Object {
  if ([string]::IsNullOrWhiteSpace($_)) { return }
  try {
    $entry = $_ | ConvertFrom-Json
    if ($null -eq $entry.timestamp -or $null -eq $entry.path) { return }
    $ts = [datetime]$entry.timestamp
    if ($ts.ToUniversalTime() -lt $since) { return }
    $rows += $entry
  } catch {
    return
  }
}

if ($rows.Count -eq 0) {
  Write-Output "No entries in last 24h."
  exit 0
}

$bankRows = $rows | Where-Object { $_.path -match '/bank|/payments|ccavenue' }
$adsRows = $rows | Where-Object { $_.path -match '/ads|admob|campaign' }

foreach ($entry in $bankRows) {
  $ip = [string]$entry.ip
  $region = ([string]$entry.region).ToUpperInvariant()
  if ($bankAllowedIps.Count -gt 0 -and $ip -and -not ($bankAllowedIps -contains $ip)) {
    Write-Alert "BANK_API unknown IP $ip path=$($entry.path)"
  }
  if ($bankAllowedRegions.Count -gt 0 -and $region -and -not ($bankAllowedRegions -contains $region)) {
    Write-Alert "BANK_API unexpected region $region ip=$ip path=$($entry.path)"
  }
}

foreach ($entry in $adsRows) {
  $ip = [string]$entry.ip
  $region = ([string]$entry.region).ToUpperInvariant()
  if ($adsAllowedIps.Count -gt 0 -and $ip -and -not ($adsAllowedIps -contains $ip)) {
    Write-Alert "ADS_API unknown IP $ip path=$($entry.path)"
  }
  if ($adsAllowedRegions.Count -gt 0 -and $region -and -not ($adsAllowedRegions -contains $region)) {
    Write-Alert "ADS_API unexpected region $region ip=$ip path=$($entry.path)"
  }
}

$hourBuckets = $rows | Group-Object { ([datetime]$_.timestamp).ToUniversalTime().ToString('yyyy-MM-ddTHH') }
foreach ($bucket in $hourBuckets) {
  if ($bucket.Count -gt $SpikeThresholdPerHour) {
    Write-Alert "Traffic spike detected hour=$($bucket.Name) count=$($bucket.Count) threshold=$SpikeThresholdPerHour"
  }
}

Write-Output "Checked $($rows.Count) entries. Alerts written to $AlertPath if needed."
