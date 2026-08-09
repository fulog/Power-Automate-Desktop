@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RunPadLauncher.ps1" -TargetScript "DisableExternalRunsOff.ps1" -OperationName "%~n0" -RequireAdministrator
set "EXITCODE=%ERRORLEVEL%"

pause
exit /b %EXITCODE%
