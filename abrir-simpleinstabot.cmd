@echo off
setlocal

cd /d "%~dp0"

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0abrir-simpleinstabot.ps1" -Reiniciar
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0abrir-simpleinstabot.ps1" %*
)

endlocal
