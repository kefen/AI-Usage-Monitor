@echo off
setlocal
cd /d "%~dp0"
"%~dp0runtime\node.exe" src\cli.mjs probe
pause
endlocal
