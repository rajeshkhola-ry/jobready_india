$ErrorActionPreference = 'Stop'

Set-Location 'C:\JobReadyIndia\jobready_india'

$indexResponse = Invoke-WebRequest -Uri 'https://getreadyjob.com/' -UseBasicParsing
$indexResponse.Content | Out-File -FilePath 'live_index.html' -Encoding utf8

$jsUrl = 'https://getreadyjob.com/main.dart.js'
Invoke-WebRequest -Uri $jsUrl -OutFile 'live_main.dart.js' -UseBasicParsing

$indexHead = Invoke-WebRequest -Uri 'https://getreadyjob.com/' -Method Head -UseBasicParsing
$jsHead = Invoke-WebRequest -Uri $jsUrl -Method Head -UseBasicParsing

Write-Output 'LIVE_DOWNLOAD_OK'
Write-Output 'INDEX_HEADERS'
$indexHead.Headers.GetEnumerator() | ForEach-Object { '{0}: {1}' -f $_.Key, $_.Value }
Write-Output 'JS_HEADERS'
$jsHead.Headers.GetEnumerator() | ForEach-Object { '{0}: {1}' -f $_.Key, $_.Value }
