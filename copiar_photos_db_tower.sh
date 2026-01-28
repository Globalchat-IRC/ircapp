#!/bin/bash

# Script para copiar base de datos de Photos a tower
# Ejecutar manualmente desde terminal (requiere permisos de acceso completo al disco)

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DB_PATH="$HOME/Pictures/temporal.photoslibrary/database/Photos.sqlite"
DEST="tower:~/backups/photos_db/Photos.sqlite"
TMP_COPY="/tmp/Photos_$(date +%Y%m%d_%H%M%S).sqlite"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📸  COPIA BASE DE DATOS PHOTOS A TOWER               ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar que existe la base de datos
if [ ! -f "$DB_PATH" ]; then
    echo -e "${YELLOW}✗${NC} No se encontró la base de datos en: $DB_PATH"
    exit 1
fi

echo -e "${BLUE}${BOLD}Información:${NC}"
echo -e "  Origen: ${CYAN}$DB_PATH${NC}"
DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
echo -e "  Tamaño: ${CYAN}$DB_SIZE${NC}"
echo -e "  Destino: ${CYAN}$DEST${NC}\n"

# Crear copia temporal
echo -e "${BLUE}${BOLD}1. Creando copia temporal...${NC}"
if cp "$DB_PATH" "$TMP_COPY" 2>&1; then
    echo -e "${GREEN}✓${NC} Copia temporal creada: $TMP_COPY\n"
else
    echo -e "${YELLOW}✗${NC} Error al crear copia temporal"
    echo -e "${YELLOW}Si ves 'Operation not permitted', necesitas:${NC}"
    echo -e "  • Preferencias del Sistema → Privacidad y Seguridad → Acceso completo al disco"
    echo -e "  • Otorgar permisos a Terminal o iTerm\n"
    exit 1
fi

# Verificar conexión SSH
echo -e "${BLUE}${BOLD}2. Verificando conexión SSH...${NC}"
if ssh -o ConnectTimeout=5 -p 62500 root@192.168.1.42 "echo OK" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Conexión SSH exitosa\n"
else
    echo -e "${YELLOW}✗${NC} No se pudo conectar a tower"
    rm -f "$TMP_COPY"
    exit 1
fi

# Crear directorio remoto si no existe
echo -e "${BLUE}${BOLD}3. Preparando directorio remoto...${NC}"
ssh -p 62500 root@192.168.1.42 "mkdir -p ~/backups/photos_db" >/dev/null 2>&1
echo -e "${GREEN}✓${NC} Directorio remoto listo\n"

# Copiar archivo con opciones mejoradas para mantener conexión
echo -e "${BLUE}${BOLD}4. Copiando archivo a tower...${NC}"
echo -e "${CYAN}Esto puede tardar varios minutos (archivo de $DB_SIZE)...${NC}\n"

# Usar rsync con opciones para mantener conexión viva y compresión
if rsync -avz \
    --progress \
    --human-readable \
    --timeout=300 \
    --partial \
    --inplace \
    --rsync-path="mkdir -p ~/backups/photos_db && rsync" \
    -e "ssh -p 62500 -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o TCPKeepAlive=yes" \
    "$TMP_COPY" \
    "$DEST"; then
    echo -e "\n${GREEN}${BOLD}✅ Copia completada exitosamente${NC}\n"
    
    # Verificar en destino
    echo -e "${BLUE}${BOLD}5. Verificando archivo en destino...${NC}"
    REMOTE_SIZE=$(ssh -p 62500 root@192.168.1.42 "ls -lh ~/backups/photos_db/Photos.sqlite 2>/dev/null | awk '{print \$5}'" || echo "")
    if [ -n "$REMOTE_SIZE" ]; then
        echo -e "${GREEN}✓${NC} Archivo en destino: ${CYAN}$REMOTE_SIZE${NC}\n"
    fi
    
    # Limpiar archivo temporal
    rm -f "$TMP_COPY"
    echo -e "${GREEN}✓${NC} Archivo temporal eliminado\n"
    
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     ✅  PROCESO COMPLETADO                              ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
else
    echo -e "\n${YELLOW}✗${NC} Error durante la copia"
    rm -f "$TMP_COPY"
    exit 1
fi
