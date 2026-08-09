@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RunPadLauncher.ps1" -TargetScript "DialogCheck.ps1" -OperationName "%~n0"
set "EXITCODE=%ERRORLEVEL%"

pause
exit /b %EXITCODE%
