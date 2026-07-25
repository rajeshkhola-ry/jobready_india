$ErrorActionPreference = 'Stop'

Set-Location 'C:\JobReadyIndia\jobready_india\lib'

$livePath = '.\live_main.dart.js'
$localPath = '..\build\web\main.dart.js'

$v1Banner = 'Upload one document or multiple files together and start working instantly'
$v2Runtime = 'Runtime: V2 | Entry: lib/main_v3.dart'

Write-Output 'LIVE_HAS_V1_BANNER'
if (Select-String -Path $livePath -Pattern $v1Banner -SimpleMatch -Quiet) {
  Write-Output 'YES'
} else {
  Write-Output 'NO'
}

Write-Output 'LIVE_HAS_V2_RUNTIME_LABEL'
if (Select-String -Path $livePath -Pattern $v2Runtime -SimpleMatch -Quiet) {
  Write-Output 'YES'
} else {
  Write-Output 'NO'
}

Write-Output 'LOCAL_HAS_V2_RUNTIME_LABEL'
if (Select-String -Path $localPath -Pattern $v2Runtime -SimpleMatch -Quiet) {
  Write-Output 'YES'
} else {
  Write-Output 'NO'
}
