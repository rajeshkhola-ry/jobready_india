@echo off
setlocal
set "SCRIPT=%~dp0auto_sync_and_verify.ps1"

if not exist "%SCRIPT%" (
  echo [AUTO-SYNC] Missing script: %SCRIPT%
  pause
  exit /b 1
)

echo [AUTO-SYNC] Starting watch mode...
echo [AUTO-SYNC] This window will keep running and auto-sync changes.
echo [AUTO-SYNC] Press Ctrl+C to stop.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Watch

echo.
echo [AUTO-SYNC] Process ended.
pause
endlocal
