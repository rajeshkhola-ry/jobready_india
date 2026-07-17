@echo off
setlocal
set "SCRIPT=%~dp0rollback_last_deploy.ps1"

if not exist "%SCRIPT%" (
  echo [ROLLBACK] Missing script: %SCRIPT%
  pause
  exit /b 1
)

echo [ROLLBACK] Rolling back to previous stable deployment...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
echo [ROLLBACK] Command finished.
pause
endlocal
