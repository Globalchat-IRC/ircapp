#!/bin/bash
# Script para crear un ZIP con solo los archivos necesarios para Windows

echo "📦 Creando paquete para Windows..."
echo ""

# Crear carpeta temporal
TEMP_DIR="irc_app_windows"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copiar archivos esenciales
echo "✓ Copiando código fuente (lib/)..."
cp -R lib "$TEMP_DIR/"

echo "✓ Copiando recursos (assets/)..."
cp -R assets "$TEMP_DIR/" 2>/dev/null || true

echo "✓ Copiando configuración Windows (windows/)..."
cp -R windows "$TEMP_DIR/"

echo "✓ Copiando tests (test/)..."
cp -R test "$TEMP_DIR/" 2>/dev/null || true

echo "✓ Copiando archivos de configuración..."
cp pubspec.yaml "$TEMP_DIR/"
cp pubspec.lock "$TEMP_DIR/"
cp .gitignore "$TEMP_DIR/"
cp analysis_options.yaml "$TEMP_DIR/" 2>/dev/null || true

echo "✓ Copiando scripts de compilación..."
cp build_installer.bat "$TEMP_DIR/"
cp build_installer.ps1 "$TEMP_DIR/"
cp installer.iss "$TEMP_DIR/"

echo "✓ Copiando documentación..."
cp README.md "$TEMP_DIR/" 2>/dev/null || true
cp GUIA_COMPILAR_WINDOWS.md "$TEMP_DIR/" 2>/dev/null || true

# Crear ZIP
ZIP_NAME="irc_app_para_windows.zip"
echo ""
echo "📦 Creando ZIP: $ZIP_NAME..."
cd ..
zip -r "$ZIP_NAME" "$TEMP_DIR" > /dev/null
cd irc_app

# Mostrar tamaño
SIZE=$(du -sh "$TEMP_DIR" | cut -f1)
ZIP_SIZE=$(du -sh "../$ZIP_NAME" | cut -f1)

echo ""
echo "✅ ¡Paquete creado exitosamente!"
echo ""
echo "📁 Carpeta temporal: $TEMP_DIR ($SIZE)"
echo "📦 Archivo ZIP: ../$ZIP_NAME ($ZIP_SIZE)"
echo ""
echo "🚀 Próximos pasos:"
echo "   1. Copia el archivo ZIP a Windows"
echo "   2. Extrae el contenido"
echo "   3. Ejecuta: flutter pub get"
echo "   4. Ejecuta: .\build_installer.bat"
echo ""
