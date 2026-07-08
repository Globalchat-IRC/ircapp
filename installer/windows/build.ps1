# GlobalChat - compilar y empaquetar para Windows
# Ejecutar en PowerShell desde la raiz del proyecto:
#   .\installer\windows\build.ps1

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $Root

Write-Host "==> flutter pub get"
flutter pub get

Write-Host "==> flutter build windows --release"
flutter build windows --release

$ReleaseDir = Join-Path $Root "build\windows\x64\runner\Release"
$Exe = Join-Path $ReleaseDir "GlobalChat.exe"
if (-not (Test-Path $Exe)) {
    throw "No se genero $Exe"
}

$Iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $Iscc)) {
    $Iscc = "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
}
if (-not (Test-Path $Iscc)) {
    Write-Warning "Inno Setup no encontrado. App compilada en: $ReleaseDir"
    Write-Warning "Instala Inno Setup 6 y ejecuta: ISCC.exe installer\windows\GlobalChat.iss"
    exit 0
}

Write-Host "==> Inno Setup"
& $Iscc (Join-Path $PSScriptRoot "GlobalChat.iss")

$Out = Join-Path $Root "build\windows\installer"
Write-Host "Listo. Instalador en: $Out"
