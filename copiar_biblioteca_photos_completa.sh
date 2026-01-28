#!/bin/bash

# Script para copiar toda la biblioteca de Photos (no solo el SQLite)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LIBRARY_NAME="temporal.photoslibrary"
SOURCE_LIBRARY="$HOME/Pictures/$LIBRARY_NAME"
DEST_HOST="root@192.168.1.42"
DEST_PATH="/backups/photos_db"
SSH_PORT="62500"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📸  COPIA BIBLIOTECA PHOTOS COMPLETA                 ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar que existe la biblioteca
if [ ! -d "$SOURCE_LIBRARY" ]; then
    echo -e "${YELLOW}✗${NC} No se encontró la biblioteca: $SOURCE_LIBRARY"
    exit 1
fi

# Intentar obtener tamaño (puede fallar por permisos)
LIBRARY_SIZE=$(du -sh "$SOURCE_LIBRARY" 2>/dev/null | cut -f1 || echo "No disponible (permisos)")
echo -e "${BLUE}Biblioteca:${NC} $LIBRARY_NAME"
echo -e "${BLUE}Tamaño total:${NC} $LIBRARY_SIZE"
echo -e "${BLUE}Destino:${NC} $DEST_HOST:$DEST_PATH/$LIBRARY_NAME\n"

# Verificar permisos
if [ ! -r "$SOURCE_LIBRARY" ]; then
    echo -e "${YELLOW}⚠${NC}  Advertencia: Puede haber problemas de permisos"
    echo -e "${YELLOW}Si falla, otorga permisos en:${NC}"
    echo -e "  Preferencias del Sistema → Privacidad → Acceso completo al disco → Terminal\n"
fi

# Verificar conexión
echo -e "${BLUE}1. Verificando conexión...${NC}"
ssh -p $SSH_PORT -o ConnectTimeout=5 "$DEST_HOST" "echo OK" >/dev/null
echo -e "${GREEN}✓${NC} Conexión OK\n"

# Preparar directorio remoto
echo -e "${BLUE}2. Preparando directorio remoto...${NC}"
ssh -p $SSH_PORT "$DEST_HOST" "mkdir -p $DEST_PATH"
echo -e "${GREEN}✓${NC} Directorio listo\n"

# Copiar toda la biblioteca
echo -e "${BLUE}3. Copiando biblioteca completa...${NC}"
echo -e "${CYAN}Esto puede tardar mucho tiempo...${NC}"
echo -e "${YELLOW}Nota: Si aparece 'Operation not permitted', necesitas permisos de acceso completo al disco${NC}\n"

# Usar rsync con opciones mejoradas para archivos grandes y conexiones inestables
if rsync -avz \
    --progress \
    --human-readable \
    --timeout=600 \
    --partial \
    --partial-dir=.rsync-partial \
    --bwlimit=50000 \
    -e "ssh -p $SSH_PORT -o ServerAliveInterval=15 -o ServerAliveCountMax=20 -o TCPKeepAlive=yes -o Compression=yes" \
    "$SOURCE_LIBRARY/" \
    "$DEST_HOST:$DEST_PATH/$LIBRARY_NAME/" 2>&1; then
    
    echo -e "\n${GREEN}${BOLD}✅ Biblioteca copiada exitosamente${NC}\n"
    
    # Verificar
    echo -e "${BLUE}4. Verificando...${NC}"
    REMOTE_SIZE=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sh $DEST_PATH/$LIBRARY_NAME 2>/dev/null | cut -f1" || echo "")
    if [ -n "$REMOTE_SIZE" ]; then
        echo -e "${GREEN}✓${NC} Biblioteca en destino: $REMOTE_SIZE"
        echo -e "${GREEN}✓${NC} Ubicación: $DEST_PATH/$LIBRARY_NAME\n"
    fi
    
    echo -e "${CYAN}${BOLD}✅ PROCESO COMPLETADO${NC}\n"
    echo -e "${BLUE}La biblioteca completa está en:${NC}"
    echo -e "  ${CYAN}$DEST_PATH/$LIBRARY_NAME${NC}\n"
else
    echo -e "\n${YELLOW}✗${NC} Error durante la copia"
    exit 1
fi
