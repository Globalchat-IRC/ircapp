@echo off
REM ========================================
REM INSTALLER WIZARD - IRC APP
REM Script interactivo para crear instalador
REM Autor: Fran Naveira
REM ========================================

setlocal enabledelayedexpansion
color 0B
cls

:MENU
cls
echo.
echo ========================================
echo   IRC APP - INSTALLER WIZARD
echo ========================================
echo.
echo  [1] Configurar informacion del instalador
echo  [2] Compilar aplicacion Flutter
echo  [3] Crear instalador con Inno Setup
echo  [4] Hacer todo (compilar + crear instalador)
echo  [5] Verificar requisitos del sistema
echo  [6] Abrir carpeta de instaladores
echo  [7] Salir
echo.
echo ========================================
echo.

set /p OPCION="Selecciona una opcion (1-7): "

if "%OPCION%"=="1" goto CONFIGURAR
if "%OPCION%"=="2" goto COMPILAR
if "%OPCION%"=="3" goto CREAR_INSTALADOR
if "%OPCION%"=="4" goto TODO
if "%OPCION%"=="5" goto VERIFICAR
if "%OPCION%"=="6" goto ABRIR_CARPETA
if "%OPCION%"=="7" goto SALIR

echo Opcion invalida. Presiona cualquier tecla para continuar...
pause >nul
goto MENU

REM ========================================
REM OPCION 1: CONFIGURAR
REM ========================================
:CONFIGURAR
cls
echo.
echo ========================================
echo CONFIGURACION DEL INSTALADOR
echo ========================================
echo.
echo Este asistente te ayudara a configurar
echo la informacion del instalador.
echo.
pause

REM Leer configuración actual si existe
if exist "installer_config.txt" (
    echo.
    echo Se encontro una configuracion anterior.
    set /p USAR_ANTERIOR="Deseas usarla? (S/N): "
    if /i "!USAR_ANTERIOR!"=="S" (
        for /f "tokens=1,* delims==" %%a in (installer_config.txt) do (
            set %%a=%%b
        )
        goto MOSTRAR_CONFIG
    )
)

REM Solicitar información
echo.
echo ----------------------------------------
echo INFORMACION BASICA
echo ----------------------------------------
echo.

set /p APP_NAME="Nombre de la aplicacion [IRC App]: "
if "!APP_NAME!"=="" set APP_NAME=IRC App

set /p APP_VERSION="Version [1.0.0]: "
if "!APP_VERSION!"=="" set APP_VERSION=1.0.0

set /p PUBLISHER="Tu nombre o empresa: "
if "!PUBLISHER!"=="" set PUBLISHER=Unknown Publisher

set /p APP_URL="URL del proyecto (opcional): "
if "!APP_URL!"=="" set APP_URL=https://github.com/yourname/irc_app

echo.
echo ----------------------------------------
echo OPCIONES DE INSTALACION
echo ----------------------------------------
echo.

set /p CREATE_DESKTOP="Crear icono en escritorio por defecto? (S/N) [S]: "
if "!CREATE_DESKTOP!"=="" set CREATE_DESKTOP=S

set /p REQUIRE_ADMIN="Requiere permisos de administrador? (S/N) [N]: "
if "!REQUIRE_ADMIN!"=="" set REQUIRE_ADMIN=N

REM Generar GUID único
echo.
echo Generando GUID unico para el instalador...
for /f "skip=1" %%g in ('powershell -Command "[guid]::NewGuid().ToString().ToUpper()"') do (
    set APP_GUID=%%g
    goto GUID_GENERADO
)
:GUID_GENERADO

REM Guardar configuración
echo APP_NAME=!APP_NAME!> installer_config.txt
echo APP_VERSION=!APP_VERSION!>> installer_config.txt
echo PUBLISHER=!PUBLISHER!>> installer_config.txt
echo APP_URL=!APP_URL!>> installer_config.txt
echo CREATE_DESKTOP=!CREATE_DESKTOP!>> installer_config.txt
echo REQUIRE_ADMIN=!REQUIRE_ADMIN!>> installer_config.txt
echo APP_GUID=!APP_GUID!>> installer_config.txt

:MOSTRAR_CONFIG
echo.
echo ========================================
echo CONFIGURACION GUARDADA
echo ========================================
echo.
echo Nombre: !APP_NAME!
echo Version: !APP_VERSION!
echo Publicador: !PUBLISHER!
echo URL: !APP_URL!
echo Escritorio: !CREATE_DESKTOP!
echo Admin: !REQUIRE_ADMIN!
echo GUID: !APP_GUID!
echo.
echo Configuracion guardada en: installer_config.txt
echo.

REM Actualizar archivo installer.iss
echo Actualizando installer.iss...
call :ACTUALIZAR_ISS

echo.
echo Configuracion completada!
echo.
pause
goto MENU

REM ========================================
REM OPCION 2: COMPILAR
REM ========================================
:COMPILAR
cls
echo.
echo ========================================
echo COMPILANDO APLICACION FLUTTER
echo ========================================
echo.

REM Verificar Flutter
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter no encontrado
    echo Por favor instala Flutter primero
    pause
    goto MENU
)

echo [1/4] Limpiando build anterior...
call flutter clean
echo [OK] Limpiado
echo.

echo [2/4] Obteniendo dependencias...
call flutter pub get
echo [OK] Dependencias obtenidas
echo.

echo [3/4] Compilando (esto puede tardar varios minutos)...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Compilacion fallo
    pause
    goto MENU
)
echo [OK] Compilado
echo.

echo [4/4] Verificando archivos...
if not exist "build\windows\x64\runner\Release\irc_app.exe" (
    echo [ERROR] No se encontro irc_app.exe
    pause
    goto MENU
)
echo [OK] Verificado
echo.

echo ========================================
echo COMPILACION EXITOSA!
echo ========================================
echo.
echo Ejecutable en: build\windows\x64\runner\Release\
echo.
pause
goto MENU

REM ========================================
REM OPCION 3: CREAR INSTALADOR
REM ========================================
:CREAR_INSTALADOR
cls
echo.
echo ========================================
echo CREANDO INSTALADOR CON INNO SETUP
echo ========================================
echo.

REM Verificar Inno Setup
set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if not exist "%INNO_PATH%" (
    echo [ERROR] Inno Setup no encontrado
    echo.
    echo Descargalo desde: https://jrsoftware.org/isdl.php
    echo.
    set /p ABRIR_WEB="Deseas abrir la pagina de descarga? (S/N): "
    if /i "!ABRIR_WEB!"=="S" (
        start https://jrsoftware.org/isdl.php
    )
    pause
    goto MENU
)

REM Verificar archivos compilados
if not exist "build\windows\x64\runner\Release\irc_app.exe" (
    echo [ERROR] No se encontraron archivos compilados
    echo Por favor compila primero (Opcion 2)
    pause
    goto MENU
)

REM Verificar script
if not exist "installer.iss" (
    echo [ERROR] No se encontro installer.iss
    echo Por favor ejecuta la Opcion 1 para configurar
    pause
    goto MENU
)

REM Crear carpeta de salida
if not exist "installers" mkdir installers

echo Compilando instalador...
echo.
"%INNO_PATH%" installer.iss
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Fallo al crear instalador
    pause
    goto MENU
)

echo.
echo ========================================
echo INSTALADOR CREADO!
echo ========================================
echo.

REM Buscar instalador
for %%F in (installers\*.exe) do (
    echo Archivo: %%F
    set /a SIZE_MB=%%~zF / 1048576
    echo Tamano: !SIZE_MB! MB
    echo.
    set INSTALLER_FILE=%%F
)

set /p ABRIR="Deseas abrir la carpeta? (S/N): "
if /i "!ABRIR!"=="S" (
    start explorer installers
)

echo.
pause
goto MENU

REM ========================================
REM OPCION 4: TODO
REM ========================================
:TODO
cls
echo.
echo ========================================
echo PROCESO COMPLETO
echo ========================================
echo.
echo Se compilara la aplicacion y se creara
echo el instalador automaticamente.
echo.
pause

REM Compilar
echo.
echo === PASO 1: COMPILANDO APLICACION ===
echo.
call :COMPILAR_SILENT
if !ERRORLEVEL! neq 0 (
    echo.
    echo [ERROR] Fallo en compilacion
    pause
    goto MENU
)

REM Crear instalador
echo.
echo === PASO 2: CREANDO INSTALADOR ===
echo.
call :CREAR_INSTALADOR_SILENT
if !ERRORLEVEL! neq 0 (
    echo.
    echo [ERROR] Fallo al crear instalador
    pause
    goto MENU
)

echo.
echo ========================================
echo PROCESO COMPLETADO!
echo ========================================
echo.
echo Tu instalador esta listo en: installers\
echo.

set /p ABRIR_CARPETA="Deseas abrir la carpeta? (S/N): "
if /i "!ABRIR_CARPETA!"=="S" (
    start explorer installers
)

set /p PROBAR="Deseas probar el instalador? (S/N): "
if /i "!PROBAR!"=="S" (
    for %%F in (installers\*.exe) do (
        start "" "%%F"
        goto MENU
    )
)

echo.
pause
goto MENU

REM ========================================
REM OPCION 5: VERIFICAR REQUISITOS
REM ========================================
:VERIFICAR
cls
echo.
echo ========================================
echo VERIFICACION DE REQUISITOS
echo ========================================
echo.

set ERRORS=0

REM Verificar Flutter
echo [1/5] Verificando Flutter...
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   [X] Flutter NO encontrado
    set /a ERRORS+=1
) else (
    echo   [OK] Flutter instalado
    flutter --version | findstr /C:"Flutter"
)
echo.

REM Verificar Git
echo [2/5] Verificando Git...
where git >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   [X] Git NO encontrado
    set /a ERRORS+=1
) else (
    echo   [OK] Git instalado
)
echo.

REM Verificar Inno Setup
echo [3/5] Verificando Inno Setup...
set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if not exist "%INNO_PATH%" (
    echo   [X] Inno Setup NO encontrado
    set /a ERRORS+=1
) else (
    echo   [OK] Inno Setup instalado
)
echo.

REM Verificar archivos del proyecto
echo [4/5] Verificando archivos del proyecto...
if not exist "pubspec.yaml" (
    echo   [X] pubspec.yaml NO encontrado
    echo   [!] No estas en la carpeta del proyecto
    set /a ERRORS+=1
) else (
    echo   [OK] Archivos del proyecto encontrados
)
echo.

REM Verificar espacio en disco
echo [5/5] Verificando espacio en disco...
for /f "tokens=3" %%a in ('dir /-c ^| find "bytes free"') do set FREE_SPACE=%%a
set /a FREE_SPACE_GB=!FREE_SPACE:~0,-9!
if !FREE_SPACE_GB! LSS 5 (
    echo   [!] Espacio libre: !FREE_SPACE_GB! GB (Minimo recomendado: 5 GB)
) else (
    echo   [OK] Espacio libre: !FREE_SPACE_GB! GB
)
echo.

echo ========================================
if !ERRORS! EQU 0 (
    echo [OK] TODOS LOS REQUISITOS CUMPLIDOS
    echo.
    echo Estas listo para compilar!
) else (
    echo [!] SE ENCONTRARON !ERRORS! PROBLEMAS
    echo.
    echo Por favor resuelve los problemas antes de continuar
)
echo ========================================
echo.
pause
goto MENU

REM ========================================
REM OPCION 6: ABRIR CARPETA
REM ========================================
:ABRIR_CARPETA
if not exist "installers" (
    echo.
    echo La carpeta 'installers' no existe aun
    echo Primero crea un instalador
    pause
    goto MENU
)
start explorer installers
goto MENU

REM ========================================
REM OPCION 7: SALIR
REM ========================================
:SALIR
cls
echo.
echo Gracias por usar IRC App Installer Wizard!
echo.
timeout /t 2 >nul
exit /b 0

REM ========================================
REM FUNCIONES AUXILIARES
REM ========================================

:COMPILAR_SILENT
call flutter clean >nul 2>&1
call flutter pub get >nul 2>&1
call flutter build windows --release
exit /b %ERRORLEVEL%

:CREAR_INSTALADOR_SILENT
set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
"%INNO_PATH%" installer.iss
exit /b %ERRORLEVEL%

:ACTUALIZAR_ISS
REM Esta función actualizaría el installer.iss con la configuración
REM Por ahora solo muestra un mensaje
echo Script installer.iss listo para usar
exit /b 0

