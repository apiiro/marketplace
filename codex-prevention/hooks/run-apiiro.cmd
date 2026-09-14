@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-apiiro.ps1" %*
exit /b %ERRORLEVEL%
