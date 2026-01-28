@echo off
REM Script para limpiar completamente y recompilar en Windows

echo ========================================
echo Limpiando proyecto completamente...
echo ========================================
echo.

REM Limpiar Flutter
echo [1/5] Limpiando Flutter...
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter clean fallo
    pause
    exit /b 1
)

REM Limpiar carpeta build
echo [2/5] Eliminando carpeta build...
if exist build (
    rmdir /s /q build
    echo [OK] Carpeta build eliminada
) else (
    echo [INFO] Carpeta build no existe
)

REM Limpiar CMakeFiles en windows
echo [3/5] Limpiando archivos CMake...
if exist windows\CMakeFiles (
    rmdir /s /q windows\CMakeFiles
    echo [OK] CMakeFiles eliminados
)
if exist windows\CMakeCache.txt (
    del windows\CMakeCache.txt
    echo [OK] CMakeCache.txt eliminado
)

REM Obtener dependencias
echo [4/5] Obteniendo dependencias...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter pub get fallo
    pause
    exit /b 1
)

REM Compilar
echo [5/5] Compilando aplicacion (Release)...
echo Este proceso puede tardar varios minutos...
echo.
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Compilacion fallo
    echo.
    echo Posibles soluciones:
    echo 1. Verifica que Visual Studio 2022 este instalado correctamente
    echo 2. Asegurate de tener "Desktop development with C++" instalado
    echo 3. Verifica que tengas espacio en disco suficiente
    echo 4. Intenta compilar sin --release primero: flutter build windows
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo COMPILACION EXITOSA!
echo ========================================
echo.
echo El ejecutable esta en:
echo build\windows\x64\runner\Release\irc_app.exe
echo.

pause
