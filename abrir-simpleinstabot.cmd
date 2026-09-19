@echo off
setlocal
set "ELECTRON_RUN_AS_NODE="
set "ELECTRON_NO_ATTACH_CONSOLE=1"

cd /d "%~dp0"

echo ====================================================================
echo   SimpleInstaBot - Inicializador Seguro
echo ====================================================================
echo.

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0abrir-simpleinstabot.ps1" -Reiniciar
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0abrir-simpleinstabot.ps1" %*
)

if errorlevel 1 goto :erro
goto :sucesso

:erro
echo.
echo ====================================================================
echo  [AVISO] Ocorreu um problema ao inicializar o bot.
echo  Leia as instrucoes acima para resolver.
echo ====================================================================
echo.
pause
goto :fim

:sucesso
echo.
echo ====================================================================
echo  [SUCESSO] O SimpleInstaBot foi iniciado com sucesso!
echo  A janela do programa ja deve estar visivel na sua area de trabalho.
echo ====================================================================
echo.
echo Voce pode fechar esta janela preta agora.
pause
goto :fim

:fim
endlocal
