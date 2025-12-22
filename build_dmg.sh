#!/bin/bash

# Script para compilar la aplicación macOS y crear un DMG con el logo de GlobalChat

set -e

echo "🔨 Compilando aplicación macOS..."
export PATH="/Users/fnaveira/flutter/bin:$PATH"
flutter build macos --release

echo "📦 Creando DMG..."

APP_NAME="irc_app"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}_macos"
DMG_PATH="${DMG_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"

# Limpiar DMG anterior si existe
if [ -f "$DMG_PATH" ]; then
    rm "$DMG_PATH"
fi

# Crear directorio temporal para el DMG
TEMP_DMG_DIR="dmg_temp"
rm -rf "$TEMP_DMG_DIR"
mkdir -p "$TEMP_DMG_DIR"

# Copiar la aplicación al directorio temporal
cp -R "$APP_PATH" "$TEMP_DMG_DIR/"

# Copiar el logo al directorio temporal
if [ -f "macos/Runner/logo.png" ]; then
    cp "macos/Runner/logo.png" "$TEMP_DMG_DIR/GlobalChat Logo.png"
    echo "✅ Logo copiado al DMG"
else
    echo "⚠️  Logo no encontrado en macos/Runner/logo.png"
fi

# Crear un enlace simbólico a Applications
ln -s /Applications "$TEMP_DMG_DIR/Applications"

# Crear el DMG
echo "📦 Creando imagen DMG..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$TEMP_DMG_DIR" -ov -format UDZO "$DMG_PATH"

# Limpiar directorio temporal
rm -rf "$TEMP_DMG_DIR"

echo "✅ DMG creado: $DMG_PATH"


