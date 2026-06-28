# ========================================
# Script PowerShell para compilar IRC App y crear instalador
# Autor: Fran Naveira
# ========================================

# Colores
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "Green"
Clear-Host

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IRC APP - BUILD SCRIPT (PowerShell)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Función para mostrar errores
function Show-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

# Función para mostrar éxito
function Show-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

# Función para mostrar info
function Show-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

# Verificar que Flutter esté instalado
try {
    $null = Get-Command flutter -ErrorAction Stop
    Show-Info "Flutter encontrado"
} catch {
    Show-Error "Flutter no encontrado en el PATH. Por favor instala Flutter."
}

# Verificar que Inno Setup esté instalado
$InnoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $InnoPath)) {
    Show-Error "Inno Setup no encontrado. Instálalo desde: https://jrsoftware.org/isdl.php"
}

# Mostrar versión de Flutter
Write-Host ""
Show-Info "Versión de Flutter:"
flutter --version
Write-Host ""

# Paso 1: Limpiar build anterior
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[1/5] Limpiando build anterior..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
try {
    flutter clean
    Show-Success "Build anterior limpiado"
} catch {
    Show-Error "Flutter clean falló: $_"
}
Write-Host ""

# Paso 2: Obtener dependencias
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[2/5] Obteniendo dependencias..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
try {
    flutter pub get
    Show-Success "Dependencias obtenidas"
} catch {
    Show-Error "Flutter pub get falló: $_"
}
Write-Host ""

# Paso 3: Compilar para Windows Release
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[3/5] Compilando aplicación (Release)..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Este proceso puede tardar varios minutos..." -ForegroundColor Yellow
Write-Host ""
try {
    flutter build windows --release
    Show-Success "Aplicación compilada exitosamente"
} catch {
    Show-Error "Compilación falló: $_"
}
Write-Host ""

# Paso 4: Verificar archivos compilados
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[4/5] Verificando archivos compilados..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$ExePath = "build\windows\x64\runner\Release\irc_app.exe"
if (-not (Test-Path $ExePath)) {
    Show-Error "No se encontró irc_app.exe en la carpeta Release"
}
Show-Success "Archivo irc_app.exe encontrado"

# Obtener información del ejecutable
$ExeInfo = Get-Item $ExePath
$ExeSize = [math]::Round($ExeInfo.Length / 1MB, 2)
Show-Info "Tamaño del ejecutable: $ExeSize MB"
Write-Host ""

# Crear carpeta de salida para instaladores
if (-not (Test-Path "installers")) {
    New-Item -ItemType Directory -Path "installers" | Out-Null
}

# Paso 5: Crear instalador con Inno Setup
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[5/5] Creando instalador con Inno Setup..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
try {
    & $InnoPath "installer.iss"
    Show-Success "Instalador creado exitosamente"
} catch {
    Show-Error "Creación del instalador falló: $_"
}
Write-Host ""

# Mostrar información del instalador creado
Write-Host "========================================" -ForegroundColor Green
Write-Host "INSTALADOR CREADO EXITOSAMENTE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Buscar el archivo del instalador
$InstallerFiles = Get-ChildItem -Path "installers" -Filter "*.exe" | Sort-Object LastWriteTime -Descending
if ($InstallerFiles.Count -gt 0) {
    $LatestInstaller = $InstallerFiles[0]
    $InstallerSize = [math]::Round($LatestInstaller.Length / 1MB, 2)
    
    Write-Host "📦 Ubicación: " -NoNewline -ForegroundColor Cyan
    Write-Host $LatestInstaller.FullName -ForegroundColor White
    Write-Host "📏 Tamaño: " -NoNewline -ForegroundColor Cyan
    Write-Host "$InstallerSize MB" -ForegroundColor White
    Write-Host "📅 Creado: " -NoNewline -ForegroundColor Cyan
    Write-Host $LatestInstaller.LastWriteTime -ForegroundColor White
    Write-Host ""
    
    # Mostrar archivos principales
    Write-Host "Archivos principales en Release:" -ForegroundColor Cyan
    Get-ChildItem -Path "build\windows\x64\runner\Release" -Filter "*.exe" | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Preguntar si desea abrir la carpeta
    $OpenFolder = Read-Host "¿Deseas abrir la carpeta de instaladores? (S/N)"
    if ($OpenFolder -eq "S" -or $OpenFolder -eq "s") {
        Start-Process "explorer.exe" -ArgumentList (Resolve-Path "installers")
    }
    
    # Preguntar si desea probar el instalador
    $TestInstaller = Read-Host "¿Deseas ejecutar el instalador ahora? (S/N)"
    if ($TestInstaller -eq "S" -or $TestInstaller -eq "s") {
        Start-Process $LatestInstaller.FullName
    }
} else {
    Write-Host "[WARNING] No se pudo encontrar el archivo del instalador" -ForegroundColor Yellow
    Write-Host "Revisa la carpeta 'installers' manualmente" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "PROCESO COMPLETADO" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos pasos:" -ForegroundColor Cyan
Write-Host "  1. ✓ Prueba el instalador en una máquina limpia" -ForegroundColor Gray
Write-Host "  2. ✓ Verifica que todos los iconos funcionen" -ForegroundColor Gray
Write-Host "  3. ✓ Prueba instalar y desinstalar" -ForegroundColor Gray
Write-Host "  4. ✓ Si todo funciona, puedes distribuir el instalador" -ForegroundColor Gray
Write-Host ""

Read-Host "Presiona Enter para salir"

