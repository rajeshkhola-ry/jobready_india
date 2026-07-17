$ErrorActionPreference = 'Stop'

$projectRoot = 'C:\JobReadyIndia\jobready_india'
$exportReleases = 'C:\JobReadyIndia\GETREADYJOB_MASTER_PROJECT\Releases'
$sdkRoot = 'C:\Users\Avita\AppData\Local\Android\Sdk'
$jbrHome = 'C:\Program Files\Android\Android Studio\jbr'
$sdkManager = Join-Path $sdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
$ndkPath = Join-Path $sdkRoot 'ndk\28.2.13676358'
$gradleLock = Join-Path $projectRoot 'android\.gradle\noVersion\buildLogic.lock'

if (-not (Test-Path $jbrHome)) {
  throw "JBR/JDK path not found: $jbrHome"
}

$env:JAVA_HOME = $jbrHome
$env:Path = "$jbrHome\\bin;$env:Path"

Write-Host "Using JAVA_HOME=$env:JAVA_HOME"
& "$jbrHome\bin\java.exe" -version

Get-Process java,gradle,flutter,dart -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if (Test-Path $gradleLock) {
  Remove-Item -Force $gradleLock
}

if (Test-Path $ndkPath) {
  Remove-Item -Recurse -Force $ndkPath
}

if (-not (Test-Path $sdkManager)) {
  throw "sdkmanager not found: $sdkManager"
}

& $sdkManager '--install' 'ndk;28.2.13676358' "--sdk_root=$sdkRoot"

Set-Location $projectRoot
flutter clean
flutter pub get

$pdfTextGradle = 'C:\Users\Avita\AppData\Local\Pub\Cache\hosted\pub.dev\pdf_text-0.5.0\android\build.gradle'
if (Test-Path $pdfTextGradle) {
  $content = Get-Content -Raw $pdfTextGradle
  if ($content -match 'jcenter\(\)') {
    $content = $content -replace 'jcenter\(\)', 'mavenCentral()'
  }

  if ($content -notmatch 'jitpack\.io') {
    $content = $content -replace 'mavenCentral\(\)', "mavenCentral()`r`n        maven { url 'https://jitpack.io' }"
  }

  if ($content -match 'compileSdkVersion\s+28') {
    $content = $content -replace 'compileSdkVersion\s+28', 'compileSdkVersion 34'
  }

  if ($content -notmatch '(?m)^\s*namespace\s+"') {
    $content = $content -replace 'android\s*\{', ('android {' + [Environment]::NewLine + '    namespace "dev.aluc.pdf_text"')
  }

  $content = $content -replace "com\.tom_roush:pdfbox-android:1\.8\.10\.1", "com.github.TomRoush:PdfBox-Android:1.8.10.1"
  $content = $content -replace "com\.github\.TomRoush:PdfBox-Android:v1\.8\.10\.1", "com.github.TomRoush:PdfBox-Android:1.8.10.1"
  $content = $content -replace "com\.github\.TomRoush:PdfBox-Android:v2\.0\.27\.0", "com.github.TomRoush:PdfBox-Android:1.8.10.1"
  $content = $content -replace "com\.github\.TomRoush:PdfBox-Android:2\.0\.27\.0", "com.github.TomRoush:PdfBox-Android:1.8.10.1"

  Set-Content -Path $pdfTextGradle -Value $content -NoNewline
}

flutter build apk --release
flutter build appbundle --release

$apkSrc = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
$aabSrc = Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'

if (-not (Test-Path $apkSrc)) {
  throw "APK not generated: $apkSrc"
}
if (-not (Test-Path $aabSrc)) {
  throw "AAB not generated: $aabSrc"
}

New-Item -ItemType Directory -Force -Path $exportReleases | Out-Null
Copy-Item -Force $apkSrc (Join-Path $exportReleases 'GETREADYJOB-release.apk')
Copy-Item -Force $aabSrc (Join-Path $exportReleases 'GETREADYJOB-release.aab')

Write-Host 'Android release artifacts copied to master export.'
