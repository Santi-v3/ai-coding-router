@echo off
set "ROUTER=%~dp0Santi-KI-Router.ps1"
if "%~1"=="" (
  echo Verwendung:
  echo   Start-Router.cmd "C:\Pfad\zum\Projekt" "Aufgabe" [preview^|plan^|apply]
  exit /b 1
)
set "MODE=%~3"
if "%MODE%"=="" set "MODE=preview"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROUTER%" -Project "%~1" -Task "%~2" -Mode "%MODE%"
