@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start.ps1" -InspectOnly
if exist "%~dp0.runtime\status.json" type "%~dp0.runtime\status.json"
if exist "%~dp0.runtime\inspection.json" type "%~dp0.runtime\inspection.json"
if exist "%~dp0.runtime\background.json" type "%~dp0.runtime\background.json"
pause
endlocal
