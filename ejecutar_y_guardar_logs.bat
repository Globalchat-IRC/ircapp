@echo off
REM Script para ejecutar IRC App y guardar logs en archivo

echo ========================================
echo IRC APP - Ejecutar y Guardar Logs
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

REM Crear carpeta de logs si no existe
if not exist "logs" mkdir logs

REM Generar nombre de archivo con timestamp
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set timestamp=%datetime:~0,8%_%datetime:~8,6%
set logfile=logs\irc_app_%timestamp%.txt

echo [INFO] Ejecutando aplicacion...
echo [INFO] Los logs se guardaran en: %logfile%
echo.
echo ========================================
echo.

REM Ejecutar y guardar logs
cd build\windows\x64\runner\Release
irc_app.exe > ..\..\..\..\..\..\%logfile% 2>&1

echo.
echo ========================================
echo Logs guardados en: %logfile%
echo ========================================
echo.
echo Presiona Enter para abrir el archivo de logs...
pause >nul

REM Abrir el archivo de logs
notepad ..\..\..\..\..\..\%logfile%
