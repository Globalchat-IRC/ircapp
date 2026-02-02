#!/bin/bash

# Script para crear el instalador DMG del Convertidor M4A a MP3
# Versión 1.0

set -e

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "═══════════════════════════════════════════════════════════"
echo "  Creando instalador DMG - Convertidor M4A a MP3"
echo "═══════════════════════════════════════════════════════════"
echo -e "${NC}"

# Directorios
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Convertidor M4A a MP3"
APP_PATH="$SCRIPT_DIR/$APP_NAME.app"
DMG_NAME="Convertidor_M4A_MP3_v1.2"
DMG_PATH="$SCRIPT_DIR/$DMG_NAME.dmg"
TEMP_DMG="$SCRIPT_DIR/temp_dmg"

# Limpiar archivos temporales anteriores
echo -e "${YELLOW}→ Limpiando archivos temporales...${NC}"
rm -rf "$TEMP_DMG"
rm -f "$DMG_PATH"

# Crear carpeta temporal para el DMG
echo -e "${YELLOW}→ Creando estructura del DMG...${NC}"
mkdir -p "$TEMP_DMG"

# Copiar la aplicación
echo -e "${YELLOW}→ Copiando aplicación...${NC}"
cp -R "$APP_PATH" "$TEMP_DMG/"

# Copiar el archivo LÉEME
echo -e "${YELLOW}→ Copiando documentación...${NC}"
cp "$SCRIPT_DIR/LÉEME.txt" "$TEMP_DMG/"

# Crear un enlace simbólico a la carpeta Aplicaciones
echo -e "${YELLOW}→ Creando enlace a Aplicaciones...${NC}"
ln -s /Applications "$TEMP_DMG/Aplicaciones"

# Crear un archivo .DS_Store personalizado para mejor presentación
# (Esto es opcional, pero hace que el DMG se vea más profesional)

# Crear el DMG
echo -e "${YELLOW}→ Creando archivo DMG...${NC}"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$TEMP_DMG" \
    -ov -format UDZO \
    -fs HFS+ \
    "$DMG_PATH"

# Limpiar
echo -e "${YELLOW}→ Limpiando archivos temporales...${NC}"
rm -rf "$TEMP_DMG"

# Verificar que el DMG se creó correctamente
if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ ¡Instalador DMG creado exitosamente!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  📦 Archivo: ${BLUE}$DMG_NAME.dmg${NC}"
    echo -e "  📍 Ubicación: ${BLUE}$SCRIPT_DIR${NC}"
    echo -e "  💾 Tamaño: ${BLUE}$DMG_SIZE${NC}"
    echo ""
    echo -e "${GREEN}Puedes compartir este archivo DMG con tu amigo.${NC}"
    echo -e "${GREEN}Al abrirlo, solo tendrá que arrastrar la aplicación${NC}"
    echo -e "${GREEN}a la carpeta Aplicaciones.${NC}"
    echo ""
    
    # Preguntar si desea abrir el DMG
    read -p "¿Deseas abrir el DMG para verificarlo? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        open "$DMG_PATH"
    fi
else
    echo -e "${RED}✗ Error al crear el DMG${NC}"
    exit 1
fi
