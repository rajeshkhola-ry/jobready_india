@echo off
setlocal
set "SCRIPT=%~dp0auto_sync_and_verify.ps1"

if not exist "%SCRIPT%" (
  echo [AUTO-SYNC] Missing script: %SCRIPT%
  pause
  exit /b 1
)

echo [AUTO-SYNC] Running one-time sync + deploy + URL check...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
echo [AUTO-SYNC] Run finished.
pause
endlocal
