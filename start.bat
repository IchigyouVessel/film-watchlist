@echo off
rem ===============================================================
rem  Pian watchlist launcher
rem  Starts a local PowerShell web server (built into Windows),
rem  then opens the app in the default browser.
rem  No Python / Node / any third-party library required.
rem
rem  NOTE: keep this file pure ASCII - cmd.exe parses .bat files
rem  using the console code page, and non-ASCII bytes break it.
rem ===============================================================
setlocal
cd /d "%~dp0"

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" set "PS=powershell.exe"

echo Starting Pian watchlist...
start "Pian Server" /min "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"

rem ping is used as a delay: unlike timeout, it also works when stdin is redirected
ping -n 5 127.0.0.1 >nul
start "" "http://127.0.0.1:8765/"
exit /b 0
