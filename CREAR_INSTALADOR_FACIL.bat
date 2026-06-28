@echo off
REM ========================================
REM ATAJO RAPIDO - IRC APP INSTALLER
REM Este script ejecuta el wizard sin problemas
REM ========================================

title IRC App - Crear Instalador

cls
echo.
echo ========================================
echo   IRC APP - CREAR INSTALADOR
echo ========================================
echo.
echo Este script te guiara para crear el instalador
echo de forma facil y sin complicaciones.
echo.
echo REQUISITOS: Flutter, Visual Studio, Inno Setup
echo.
pause

REM Verificar que estamos en la carpeta correcta
if not exist "pubspec.yaml" (
    echo.
    echo [ERROR] No se encontro pubspec.yaml
    echo Este script debe ejecutarse desde la carpeta raiz del proyecto irc_app
    echo.
    pause
    exit /b 1
)

REM Ejecutar el wizard batch
if exist "installer_wizard.bat" (
    call installer_wizard.bat
) else (
    echo.
    echo [ERROR] No se encontro installer_wizard.bat
    echo Asegurate de haber copiado todos los archivos del paquete instalador_windows
    echo.
    pause
    exit /b 1
)

