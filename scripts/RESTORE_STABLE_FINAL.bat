@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore_stable_final.ps1" -Execute
exit /b %errorlevel%
