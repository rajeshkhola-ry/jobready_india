$ErrorActionPreference = 'Stop'

Set-Location 'C:\JobReadyIndia\jobready_india\lib'

$bootstrapUrl = 'https://getreadyjob.com/flutter_bootstrap.js'
$serviceWorkerUrl = 'https://getreadyjob.com/flutter_service_worker.js'

Invoke-WebRequest -Uri $bootstrapUrl -OutFile 'live_flutter_bootstrap.js' -UseBasicParsing
Invoke-WebRequest -Uri $serviceWorkerUrl -OutFile 'live_flutter_service_worker.js' -UseBasicParsing

$bootstrapHead = Invoke-WebRequest -Uri $bootstrapUrl -Method Head -UseBasicParsing
$swHead = Invoke-WebRequest -Uri $serviceWorkerUrl -Method Head -UseBasicParsing

Write-Output ('BOOTSTRAP_ETAG=' + $bootstrapHead.Headers['ETag'])
Write-Output ('BOOTSTRAP_LASTMOD=' + $bootstrapHead.Headers['Last-Modified'])
Write-Output ('BOOTSTRAP_CACHE=' + $bootstrapHead.Headers['Cache-Control'])

Write-Output ('SW_ETAG=' + $swHead.Headers['ETag'])
Write-Output ('SW_LASTMOD=' + $swHead.Headers['Last-Modified'])
Write-Output ('SW_CACHE=' + $swHead.Headers['Cache-Control'])
