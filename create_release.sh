#!/bin/bash

# Script para crear un release en GitHub con el DMG adjunto
# Requiere: gh CLI (GitHub CLI) instalado y autenticado
# Instalar: brew install gh
# Autenticar: gh auth login

set -e

VERSION="1.0.5"
DMG_PATH="releases/irc_app_macos_v${VERSION}.dmg"
TAG_NAME="v${VERSION}"
RELEASE_NAME="Release ${VERSION}"
RELEASE_NOTES="## Cambios en v${VERSION}

### ✨ Nuevas Funcionalidades
- **Barra de lag en tiempo real**: Muestra la latencia con el servidor IRC en el AppBar
  - Colores indicativos: Verde (<100ms), Amarillo (100-300ms), Naranja (300-500ms), Rojo (>500ms)
  - Actualización automática cada 30 segundos
  - Medición precisa usando PING/PONG del protocolo IRC

### 🔧 Mejoras
- Medición automática de lag con el servidor UnrealIRCd
- Indicador visual de calidad de conexión
- Timer de lag que se inicia automáticamente al conectar

### 🐛 Correcciones
- Mejoras en la gestión de conexión y desconexión

## Descarga

Descarga el instalador DMG para macOS desde los assets de este release."

echo "🚀 Creando release ${TAG_NAME} en GitHub..."

# Verificar que existe el DMG
if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: No se encontró el DMG en $DMG_PATH"
    exit 1
fi

# Verificar que gh está instalado
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) no está instalado"
    echo "📦 Instalar con: brew install gh"
    echo "🔐 Autenticar con: gh auth login"
    exit 1
fi

# Verificar autenticación
if ! gh auth status &> /dev/null; then
    echo "❌ Error: No estás autenticado en GitHub CLI"
    echo "🔐 Autenticar con: gh auth login"
    exit 1
fi

# Crear el release
echo "📦 Creando release con tag ${TAG_NAME}..."
gh release create "${TAG_NAME}" \
    --title "${RELEASE_NAME}" \
    --notes "${RELEASE_NOTES}" \
    "${DMG_PATH}" \
    --repo Globalchat-IRC/ircapp

echo "✅ Release creado exitosamente!"
echo "🌐 Ver en: https://github.com/Globalchat-IRC/ircapp/releases/tag/${TAG_NAME}"



