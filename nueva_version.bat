@echo off
REM ========================================
REM Script para crear nueva versión
REM Automatiza el proceso de release
REM ========================================

setlocal enabledelayedexpansion
color 0A
cls

echo.
echo ========================================
echo   CREAR NUEVA VERSION - IRC APP
echo ========================================
echo.

REM Verificar que estamos en la carpeta correcta
if not exist "pubspec.yaml" (
    echo [ERROR] No se encontro pubspec.yaml
    echo Este script debe ejecutarse desde la raiz del proyecto
    pause
    exit /b 1
)

REM Obtener versión actual
for /f "tokens=2" %%a in ('findstr /C:"version:" pubspec.yaml') do set CURRENT_VERSION=%%a
echo Version actual: %CURRENT_VERSION%
echo.

REM Solicitar nueva versión
echo Ejemplos de versionado:
echo - Bug fixes:       1.0.0 --^> 1.0.1
echo - Nuevas features: 1.0.0 --^> 1.1.0
echo - Cambios grandes: 1.0.0 --^> 2.0.0
echo.
set /p NEW_VERSION="Nueva version (ej: 1.0.1): "

if "%NEW_VERSION%"=="" (
    echo [ERROR] Debes especificar una version
    pause
    exit /b 1
)

echo.
echo ----------------------------------------
echo Version actual: %CURRENT_VERSION%
echo Nueva version:  %NEW_VERSION%
echo ----------------------------------------
echo.

set /p CONFIRM="Es correcto? (S/N): "
if /i not "%CONFIRM%"=="S" (
    echo Cancelado por el usuario
    pause
    exit /b 0
)

REM Actualizar pubspec.yaml
echo.
echo [1/7] Actualizando pubspec.yaml...
powershell -Command "(Get-Content pubspec.yaml) -replace 'version:.*', 'version: %NEW_VERSION%' | Set-Content pubspec.yaml"
echo [OK] pubspec.yaml actualizado

REM Limpiar build anterior
echo.
echo [2/7] Limpiando build anterior...
call flutter clean >nul 2>&1
echo [OK] Build limpiado

REM Obtener dependencias
echo.
echo [3/7] Obteniendo dependencias...
call flutter pub get >nul 2>&1
echo [OK] Dependencias actualizadas

REM Compilar aplicacion
echo.
echo [4/7] Compilando aplicacion (puede tardar varios minutos)...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Fallo la compilacion
    pause
    exit /b 1
)
echo [OK] Aplicacion compilada

REM Crear instalador
echo.
echo [5/7] Creando instalador con Inno Setup...
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Fallo la creacion del instalador
    pause
    exit /b 1
)
echo [OK] Instalador creado

REM Commit a Git
echo.
echo [6/7] Haciendo commit a Git...
git add .
git commit -m "Version %NEW_VERSION%"
if %ERRORLEVEL% neq 0 (
    echo [WARNING] No se pudo hacer commit (puede no haber cambios)
)
echo [OK] Commit realizado

REM Push a GitHub
echo.
echo [7/7] Subiendo a GitHub...
git push
if %ERRORLEVEL% neq 0 (
    echo [WARNING] No se pudo hacer push
    echo Ejecuta manualmente: git push
)
echo [OK] Codigo subido a GitHub

REM Mostrar resumen
echo.
echo ========================================
echo PROCESO COMPLETADO!
echo ========================================
echo.
echo Version: %NEW_VERSION%
echo Instalador: installers\irc_app_setup_%NEW_VERSION%_x64.exe
echo.
echo SIGUIENTES PASOS:
echo.
echo 1. Ve a: https://github.com/Globalchat-IRC/ircapp/releases/new
echo 2. Tag version: v%NEW_VERSION%
echo 3. Release title: IRC App v%NEW_VERSION%
echo 4. Describe los cambios
echo 5. Arrastra el instalador desde: installers\
echo 6. Publica el release
echo.
echo Despues de publicar, los usuarios recibiran
echo la notificacion de actualizacion automaticamente!
echo.

set /p OPEN_FOLDER="Deseas abrir la carpeta de instaladores? (S/N): "
if /i "%OPEN_FOLDER%"=="S" (
    start explorer installers
)

set /p OPEN_GITHUB="Deseas abrir GitHub Releases? (S/N): "
if /i "%OPEN_GITHUB%"=="S" (
    start https://github.com/Globalchat-IRC/ircapp/releases/new
)

echo.
pause

