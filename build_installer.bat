@echo off
REM ========================================
REM Script para compilar IRC App y crear instalador
REM Autor: Fran Naveira
REM ========================================

setlocal enabledelayedexpansion

REM Colores para la consola (opcional)
color 0A

echo.
echo ========================================
echo IRC APP - BUILD SCRIPT
echo ========================================
echo.

REM Verificar que Flutter esté instalado
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter no encontrado en el PATH
    echo Por favor instala Flutter y añadelo al PATH
    pause
    exit /b 1
)

REM Verificar que Inno Setup esté instalado
set "INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%INNO_PATH%" (
    echo [ERROR] Inno Setup no encontrado en: %INNO_PATH%
    echo Por favor instala Inno Setup 6 desde: https://jrsoftware.org/isdl.php
    pause
    exit /b 1
)

REM Mostrar versión de Flutter
echo [INFO] Verificando Flutter...
flutter --version
echo.

REM Paso 1: Limpiar build anterior
echo ========================================
echo [1/5] Limpiando build anterior...
echo ========================================
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter clean fallo
    pause
    exit /b 1
)
echo [OK] Build anterior limpiado
echo.

REM Paso 2: Obtener dependencias
echo ========================================
echo [2/5] Obteniendo dependencias...
echo ========================================
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter pub get fallo
    pause
    exit /b 1
)
echo [OK] Dependencias obtenidas
echo.

REM Paso 3: Compilar para Windows Release
echo ========================================
echo [3/5] Compilando aplicacion (Release)...
echo ========================================
echo Este proceso puede tardar varios minutos...
echo.
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Compilacion fallo
    pause
    exit /b 1
)
echo [OK] Aplicacion compilada exitosamente
echo.

REM Paso 4: Verificar archivos compilados
echo ========================================
echo [4/5] Verificando archivos compilados...
echo ========================================
REM Buscar el ejecutable en diferentes ubicaciones posibles
set EXE_FOUND=0
if exist "build\windows\x64\runner\Release\irc_app.exe" (
    set EXE_PATH=build\windows\x64\runner\Release
    set EXE_FOUND=1
) else if exist "build\windows\runner\Release\irc_app.exe" (
    set EXE_PATH=build\windows\runner\Release
    set EXE_FOUND=1
) else if exist "build\windows\x64\runner\Debug\irc_app.exe" (
    echo [WARNING] Solo se encontro version Debug, compilando Release...
    call flutter build windows --release
    if exist "build\windows\x64\runner\Release\irc_app.exe" (
        set EXE_PATH=build\windows\x64\runner\Release
        set EXE_FOUND=1
    )
) else (
    echo [ERROR] No se encontro irc_app.exe
    echo.
    echo Buscando en las siguientes ubicaciones:
    if exist "build\windows" (
        echo Carpeta build\windows existe
        dir /s /b build\windows\*.exe 2>nul
    ) else (
        echo Carpeta build\windows NO existe
    )
    pause
    exit /b 1
)

if %EXE_FOUND%==0 (
    echo [ERROR] No se encontro irc_app.exe en ninguna ubicacion
    pause
    exit /b 1
)

echo [OK] Archivo irc_app.exe encontrado en: %EXE_PATH%
echo.

REM Crear carpeta de salida para instaladores
if not exist "installers" mkdir installers

REM Paso 5: Crear instalador con Inno Setup
echo ========================================
echo [5/5] Creando instalador con Inno Setup...
echo ========================================
call "%INNO_PATH%" installer.iss
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Creacion del instalador fallo
    pause
    exit /b 1
)
echo [OK] Instalador creado exitosamente
echo.

REM Mostrar información del instalador creado
echo ========================================
echo INSTALADOR CREADO EXITOSAMENTE!
echo ========================================
echo.

REM Buscar el archivo del instalador
for %%F in (installers\*.exe) do (
    set INSTALLER_FILE=%%F
    set INSTALLER_SIZE=%%~zF
)

if defined INSTALLER_FILE (
    echo Ubicacion: %INSTALLER_FILE%
    
    REM Convertir tamaño a MB
    set /a SIZE_MB=!INSTALLER_SIZE! / 1048576
    echo Tamano: !SIZE_MB! MB
    
    REM Mostrar información del ejecutable
    echo.
    echo Archivos principales:
    dir /B %EXE_PATH%\*.exe
    echo.
    
    REM Preguntar si desea abrir la carpeta
    echo.
    set /p OPEN_FOLDER="Deseas abrir la carpeta de instaladores? (S/N): "
    if /i "!OPEN_FOLDER!"=="S" (
        start explorer installers
    )
    
    REM Preguntar si desea probar el instalador
    echo.
    set /p TEST_INSTALLER="Deseas ejecutar el instalador ahora? (S/N): "
    if /i "!TEST_INSTALLER!"=="S" (
        start "" "!INSTALLER_FILE!"
    )
) else (
    echo [WARNING] No se pudo encontrar el archivo del instalador
    echo Revisa la carpeta 'installers' manualmente
)

echo.
echo ========================================
echo PROCESO COMPLETADO
echo ========================================
echo.
echo Proximos pasos:
echo 1. Prueba el instalador en una maquina limpia
echo 2. Verifica que todos los iconos funcionen
echo 3. Prueba instalar y desinstalar
echo 4. Si todo funciona, puedes distribuir el instalador
echo.

pause

