# ========================================
# INSTALLER WIZARD - IRC APP (PowerShell)
# Script interactivo para crear instalador
# Autor: Fran Naveira
# ========================================

# Configuración de colores
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

# Variables globales
$Script:Config = @{
    AppName = "IRC App"
    AppVersion = "1.0.0"
    Publisher = "Unknown Publisher"
    AppURL = "https://github.com/yourname/irc_app"
    CreateDesktop = $true
    RequireAdmin = $false
    AppGuid = ""
}

# Funciones auxiliares
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   IRC APP - INSTALLER WIZARD" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Show-Banner
    Write-Host "  [1] 🔧 Configurar información del instalador" -ForegroundColor Yellow
    Write-Host "  [2] 📦 Compilar aplicación Flutter" -ForegroundColor Yellow
    Write-Host "  [3] 🎁 Crear instalador con Inno Setup" -ForegroundColor Yellow
    Write-Host "  [4] ⚡ Hacer todo (compilar + crear instalador)" -ForegroundColor Yellow
    Write-Host "  [5] ✅ Verificar requisitos del sistema" -ForegroundColor Yellow
    Write-Host "  [6] 📂 Abrir carpeta de instaladores" -ForegroundColor Yellow
    Write-Host "  [7] 🚪 Salir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Show-Error {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
}

function Show-Info {
    param([string]$Message)
    Write-Host "[ℹ] $Message" -ForegroundColor Yellow
}

function Show-Progress {
    param([string]$Message)
    Write-Host "[⏳] $Message" -ForegroundColor Cyan
}

# Función: Cargar configuración
function Load-Config {
    if (Test-Path "installer_config.json") {
        try {
            $loaded = Get-Content "installer_config.json" | ConvertFrom-Json
            $Script:Config.AppName = $loaded.AppName
            $Script:Config.AppVersion = $loaded.AppVersion
            $Script:Config.Publisher = $loaded.Publisher
            $Script:Config.AppURL = $loaded.AppURL
            $Script:Config.CreateDesktop = $loaded.CreateDesktop
            $Script:Config.RequireAdmin = $loaded.RequireAdmin
            $Script:Config.AppGuid = $loaded.AppGuid
            return $true
        } catch {
            return $false
        }
    }
    return $false
}

# Función: Guardar configuración
function Save-Config {
    $Script:Config | ConvertTo-Json | Set-Content "installer_config.json"
}

# Función: Generar GUID
function New-Guid {
    return "{" + [guid]::NewGuid().ToString().ToUpper() + "}"
}

# OPCIÓN 1: Configurar
function Configure-Installer {
    Show-Banner
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "CONFIGURACIÓN DEL INSTALADOR" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Este asistente te ayudará a configurar" -ForegroundColor Gray
    Write-Host "la información del instalador." -ForegroundColor Gray
    Write-Host ""
    
    # Cargar configuración anterior si existe
    if (Load-Config) {
        Write-Host "Se encontró una configuración anterior." -ForegroundColor Yellow
        $usar = Read-Host "¿Deseas editarla? (S/N) [S]"
        if ([string]::IsNullOrEmpty($usar)) { $usar = "S" }
        if ($usar -ne "S" -and $usar -ne "s") {
            return
        }
    }
    
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "INFORMACIÓN BÁSICA" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    
    # Nombre de la aplicación
    $nombre = Read-Host "Nombre de la aplicación [$($Script:Config.AppName)]"
    if (-not [string]::IsNullOrEmpty($nombre)) {
        $Script:Config.AppName = $nombre
    }
    
    # Versión
    $version = Read-Host "Versión [$($Script:Config.AppVersion)]"
    if (-not [string]::IsNullOrEmpty($version)) {
        $Script:Config.AppVersion = $version
    }
    
    # Publicador
    $publisher = Read-Host "Tu nombre o empresa [$($Script:Config.Publisher)]"
    if (-not [string]::IsNullOrEmpty($publisher)) {
        $Script:Config.Publisher = $publisher
    }
    
    # URL
    $url = Read-Host "URL del proyecto [$($Script:Config.AppURL)]"
    if (-not [string]::IsNullOrEmpty($url)) {
        $Script:Config.AppURL = $url
    }
    
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "OPCIONES DE INSTALACIÓN" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    
    # Icono en escritorio
    $desktop = Read-Host "¿Crear icono en escritorio por defecto? (S/N) [S]"
    if ([string]::IsNullOrEmpty($desktop)) { $desktop = "S" }
    $Script:Config.CreateDesktop = ($desktop -eq "S" -or $desktop -eq "s")
    
    # Permisos de administrador
    $admin = Read-Host "¿Requiere permisos de administrador? (S/N) [N]"
    if ([string]::IsNullOrEmpty($admin)) { $admin = "N" }
    $Script:Config.RequireAdmin = ($admin -eq "S" -or $admin -eq "s")
    
    # Generar GUID si no existe
    if ([string]::IsNullOrEmpty($Script:Config.AppGuid)) {
        Write-Host ""
        Show-Progress "Generando GUID único..."
        $Script:Config.AppGuid = New-Guid
        Show-Success "GUID generado: $($Script:Config.AppGuid)"
    }
    
    # Guardar configuración
    Save-Config
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "CONFIGURACIÓN GUARDADA" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Nombre:      " -NoNewline -ForegroundColor Gray
    Write-Host $Script:Config.AppName -ForegroundColor White
    Write-Host "Versión:     " -NoNewline -ForegroundColor Gray
    Write-Host $Script:Config.AppVersion -ForegroundColor White
    Write-Host "Publicador:  " -NoNewline -ForegroundColor Gray
    Write-Host $Script:Config.Publisher -ForegroundColor White
    Write-Host "URL:         " -NoNewline -ForegroundColor Gray
    Write-Host $Script:Config.AppURL -ForegroundColor White
    Write-Host "Escritorio:  " -NoNewline -ForegroundColor Gray
    Write-Host $Script:Config.CreateDesktop -ForegroundColor White
    Write-Host "Admin:       " -NoNewline -ForegroundColor Gray
    Write-Host $Script:Config.RequireAdmin -ForegroundColor White
    Write-Host "GUID:        " -NoNewline -ForegroundColor Gray
    Write-Host $Script:Config.AppGuid -ForegroundColor White
    Write-Host ""
    
    # Actualizar installer.iss
    Show-Progress "Actualizando installer.iss..."
    Update-InstallerScript
    Show-Success "Archivo installer.iss actualizado"
    
    Write-Host ""
    Read-Host "Presiona Enter para continuar"
}

# Función: Actualizar script ISS
function Update-InstallerScript {
    $privileges = if ($Script:Config.RequireAdmin) { "admin" } else { "lowest" }
    $desktopFlags = if ($Script:Config.CreateDesktop) { "" } else { "Flags: unchecked" }
    
    $issContent = @"
; Script generado por Installer Wizard
; IRC App - Inno Setup Script

#define MyAppName "$($Script:Config.AppName)"
#define MyAppVersion "$($Script:Config.AppVersion)"
#define MyAppPublisher "$($Script:Config.Publisher)"
#define MyAppURL "$($Script:Config.AppURL)"
#define MyAppExeName "irc_app.exe"

[Setup]
AppId=$($Script:Config.AppGuid)
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=$privileges
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=installers
OutputBaseFilename=irc_app_setup_{#MyAppVersion}_x64
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; $desktopFlags

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
"@
    
    $issContent | Set-Content "installer.iss" -Encoding UTF8
}

# OPCIÓN 2: Compilar
function Compile-App {
    Show-Banner
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "COMPILANDO APLICACIÓN FLUTTER" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Verificar Flutter
    try {
        $null = Get-Command flutter -ErrorAction Stop
    } catch {
        Show-Error "Flutter no encontrado en el PATH"
        Write-Host ""
        Read-Host "Presiona Enter para continuar"
        return
    }
    
    # Paso 1: Clean
    Show-Progress "[1/4] Limpiando build anterior..."
    flutter clean | Out-Null
    Show-Success "Build anterior limpiado"
    Write-Host ""
    
    # Paso 2: Pub Get
    Show-Progress "[2/4] Obteniendo dependencias..."
    flutter pub get | Out-Null
    Show-Success "Dependencias obtenidas"
    Write-Host ""
    
    # Paso 3: Build
    Show-Progress "[3/4] Compilando (esto puede tardar varios minutos)..."
    Write-Host ""
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Show-Error "Compilación falló"
        Read-Host "Presiona Enter para continuar"
        return
    }
    Write-Host ""
    Show-Success "Aplicación compilada"
    Write-Host ""
    
    # Paso 4: Verificar
    Show-Progress "[4/4] Verificando archivos..."
    $exePath = "build\windows\x64\runner\Release\irc_app.exe"
    if (-not (Test-Path $exePath)) {
        Show-Error "No se encontró irc_app.exe"
        Read-Host "Presiona Enter para continuar"
        return
    }
    
    $exeInfo = Get-Item $exePath
    $exeSize = [math]::Round($exeInfo.Length / 1MB, 2)
    Show-Success "Ejecutable verificado ($exeSize MB)"
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "COMPILACIÓN EXITOSA!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ubicación: " -NoNewline -ForegroundColor Gray
    Write-Host "build\windows\x64\runner\Release\" -ForegroundColor White
    Write-Host ""
    
    Read-Host "Presiona Enter para continuar"
}

# OPCIÓN 3: Crear instalador
function Create-Installer {
    Show-Banner
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "CREANDO INSTALADOR CON INNO SETUP" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Verificar Inno Setup
    $innoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $innoPath)) {
        Show-Error "Inno Setup no encontrado"
        Write-Host ""
        Write-Host "Descárgalo desde: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
        Write-Host ""
        $abrir = Read-Host "¿Deseas abrir la página de descarga? (S/N)"
        if ($abrir -eq "S" -or $abrir -eq "s") {
            Start-Process "https://jrsoftware.org/isdl.php"
        }
        Read-Host "Presiona Enter para continuar"
        return
    }
    
    # Verificar archivos compilados
    if (-not (Test-Path "build\windows\x64\runner\Release\irc_app.exe")) {
        Show-Error "No se encontraron archivos compilados"
        Write-Host "Por favor compila primero (Opción 2)" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Presiona Enter para continuar"
        return
    }
    
    # Verificar script ISS
    if (-not (Test-Path "installer.iss")) {
        Show-Error "No se encontró installer.iss"
        Write-Host "Por favor configura primero (Opción 1)" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Presiona Enter para continuar"
        return
    }
    
    # Crear carpeta de salida
    if (-not (Test-Path "installers")) {
        New-Item -ItemType Directory -Path "installers" | Out-Null
    }
    
    # Compilar instalador
    Show-Progress "Compilando instalador..."
    Write-Host ""
    & $innoPath "installer.iss"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Show-Error "Falló al crear instalador"
        Read-Host "Presiona Enter para continuar"
        return
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "INSTALADOR CREADO!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Buscar instalador
    $installers = Get-ChildItem -Path "installers" -Filter "*.exe" | Sort-Object LastWriteTime -Descending
    if ($installers.Count -gt 0) {
        $latest = $installers[0]
        $size = [math]::Round($latest.Length / 1MB, 2)
        
        Write-Host "📦 Archivo:  " -NoNewline -ForegroundColor Cyan
        Write-Host $latest.Name -ForegroundColor White
        Write-Host "📏 Tamaño:   " -NoNewline -ForegroundColor Cyan
        Write-Host "$size MB" -ForegroundColor White
        Write-Host "📅 Creado:   " -NoNewline -ForegroundColor Cyan
        Write-Host $latest.LastWriteTime -ForegroundColor White
        Write-Host ""
        
        $abrir = Read-Host "¿Deseas abrir la carpeta? (S/N)"
        if ($abrir -eq "S" -or $abrir -eq "s") {
            Start-Process "explorer.exe" -ArgumentList (Resolve-Path "installers")
        }
    }
    
    Write-Host ""
    Read-Host "Presiona Enter para continuar"
}

# OPCIÓN 4: Hacer todo
function Do-Everything {
    Show-Banner
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "PROCESO COMPLETO" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Se compilará la aplicación y se creará" -ForegroundColor Gray
    Write-Host "el instalador automáticamente." -ForegroundColor Gray
    Write-Host ""
    Read-Host "Presiona Enter para continuar"
    
    # Compilar
    Write-Host ""
    Write-Host "=== PASO 1: COMPILANDO APLICACIÓN ===" -ForegroundColor Cyan
    Write-Host ""
    
    flutter clean | Out-Null
    flutter pub get | Out-Null
    flutter build windows --release
    
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Falló en compilación"
        Read-Host "Presiona Enter para continuar"
        return
    }
    
    # Crear instalador
    Write-Host ""
    Write-Host "=== PASO 2: CREANDO INSTALADOR ===" -ForegroundColor Cyan
    Write-Host ""
    
    $innoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    & $innoPath "installer.iss"
    
    if ($LASTEXITCODE -ne 0) {
        Show-Error "Falló al crear instalador"
        Read-Host "Presiona Enter para continuar"
        return
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "PROCESO COMPLETADO!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tu instalador está listo en: installers\" -ForegroundColor White
    Write-Host ""
    
    $abrir = Read-Host "¿Deseas abrir la carpeta? (S/N)"
    if ($abrir -eq "S" -or $abrir -eq "s") {
        Start-Process "explorer.exe" -ArgumentList (Resolve-Path "installers")
    }
    
    Write-Host ""
    Read-Host "Presiona Enter para continuar"
}

# OPCIÓN 5: Verificar requisitos
function Verify-Requirements {
    Show-Banner
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "VERIFICACIÓN DE REQUISITOS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    $errors = 0
    
    # Flutter
    Write-Host "[1/5] Verificando Flutter..." -ForegroundColor Cyan
    try {
        $null = Get-Command flutter -ErrorAction Stop
        Show-Success "Flutter instalado"
        flutter --version | Select-String "Flutter" | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } catch {
        Show-Error "Flutter NO encontrado"
        $errors++
    }
    Write-Host ""
    
    # Git
    Write-Host "[2/5] Verificando Git..." -ForegroundColor Cyan
    try {
        $null = Get-Command git -ErrorAction Stop
        Show-Success "Git instalado"
    } catch {
        Show-Error "Git NO encontrado"
        $errors++
    }
    Write-Host ""
    
    # Inno Setup
    Write-Host "[3/5] Verificando Inno Setup..." -ForegroundColor Cyan
    $innoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (Test-Path $innoPath) {
        Show-Success "Inno Setup instalado"
    } else {
        Show-Error "Inno Setup NO encontrado"
        $errors++
    }
    Write-Host ""
    
    # Archivos del proyecto
    Write-Host "[4/5] Verificando archivos del proyecto..." -ForegroundColor Cyan
    if (Test-Path "pubspec.yaml") {
        Show-Success "Archivos del proyecto encontrados"
    } else {
        Show-Error "pubspec.yaml NO encontrado"
        Show-Info "No estás en la carpeta del proyecto"
        $errors++
    }
    Write-Host ""
    
    # Espacio en disco
    Write-Host "[5/5] Verificando espacio en disco..." -ForegroundColor Cyan
    $drive = Get-PSDrive C
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    if ($freeSpaceGB -lt 5) {
        Write-Host "      [!] Espacio libre: $freeSpaceGB GB (Mínimo recomendado: 5 GB)" -ForegroundColor Yellow
    } else {
        Show-Success "Espacio libre: $freeSpaceGB GB"
    }
    Write-Host ""
    
    Write-Host "========================================" -ForegroundColor Cyan
    if ($errors -eq 0) {
        Write-Host "[✓] TODOS LOS REQUISITOS CUMPLIDOS" -ForegroundColor Green
        Write-Host ""
        Write-Host "¡Estás listo para compilar!" -ForegroundColor White
    } else {
        Write-Host "[✗] SE ENCONTRARON $errors PROBLEMAS" -ForegroundColor Red
        Write-Host ""
        Write-Host "Por favor resuelve los problemas antes de continuar" -ForegroundColor Yellow
    }
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Read-Host "Presiona Enter para continuar"
}

# OPCIÓN 6: Abrir carpeta
function Open-InstallersFolder {
    if (Test-Path "installers") {
        Start-Process "explorer.exe" -ArgumentList (Resolve-Path "installers")
    } else {
        Show-Banner
        Show-Info "La carpeta 'installers' no existe aún"
        Write-Host "Primero crea un instalador" -ForegroundColor Gray
        Write-Host ""
        Read-Host "Presiona Enter para continuar"
    }
}

# MAIN LOOP
$running = $true
Load-Config | Out-Null

while ($running) {
    Show-Menu
    $opcion = Read-Host "Selecciona una opción (1-7)"
    
    switch ($opcion) {
        "1" { Configure-Installer }
        "2" { Compile-App }
        "3" { Create-Installer }
        "4" { Do-Everything }
        "5" { Verify-Requirements }
        "6" { Open-InstallersFolder }
        "7" { 
            Clear-Host
            Write-Host ""
            Write-Host "¡Gracias por usar IRC App Installer Wizard!" -ForegroundColor Cyan
            Write-Host ""
            Start-Sleep -Seconds 1
            $running = $false
        }
        default {
            Show-Banner
            Show-Error "Opción inválida"
            Start-Sleep -Seconds 1
        }
    }
}

