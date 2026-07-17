@echo off
setlocal
set "SCRIPT=%~dp0rollback_last_deploy.ps1"

if not exist "%SCRIPT%" (
  echo [ROLLBACK] Missing script: %SCRIPT%
  pause
  exit /b 1
)

echo [ROLLBACK] Dry Run mode (no commit/push changes)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -DryRun

echo.
echo [ROLLBACK] Dry Run finished.
pause
endlocal
