@echo off
REM Script para ejecutar IRC App y ver los logs
REM Este script crea una ventana de consola y ejecuta la app mostrando todos los logs

echo ========================================
echo IRC APP - Ejecutar con Logs
echo ========================================
echo.

REM Verificar que existe el ejecutable
if not exist "build\windows\x64\runner\Release\irc_app.exe" (
    echo [ERROR] No se encontro irc_app.exe
    echo.
    echo Asegurate de haber compilado la aplicacion primero:
    echo   flutter build windows --release
    echo.
    pause
    exit /b 1
)

echo [INFO] Ejecutando aplicacion...
echo [INFO] Los logs apareceran en esta ventana
echo.
echo ========================================
echo.

REM Ejecutar la aplicacion y mostrar logs
cd build\windows\x64\runner\Release
start "IRC App - Logs" cmd /k "irc_app.exe"

echo.
echo ========================================
echo La aplicacion se ha abierto en una nueva ventana
echo Los logs apareceran en esa ventana
echo ========================================
echo.
pause
