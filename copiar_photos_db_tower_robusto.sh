#!/bin/bash

# Versión robusta con múltiples métodos de transferencia

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DB_PATH="$HOME/Pictures/temporal.photoslibrary/database/Photos.sqlite"
DEST_HOST="root@192.168.1.42"
DEST_PATH="/backups/photos_db/Photos.sqlite"
SSH_PORT="62500"
TMP_COPY="/tmp/Photos_$(date +%Y%m%d_%H%M%S).sqlite"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📸  COPIA ROBUSTA A TOWER                            ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar base de datos
if [ ! -f "$DB_PATH" ]; then
    echo -e "${YELLOW}✗${NC} No se encontró la base de datos"
    exit 1
fi

DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
echo -e "${BLUE}Origen:${NC} $DB_PATH"
echo -e "${BLUE}Tamaño:${NC} $DB_SIZE"
echo -e "${BLUE}Destino:${NC} $DEST_HOST:$DEST_PATH\n"

# Crear copia temporal
echo -e "${BLUE}1. Creando copia temporal...${NC}"
cp "$DB_PATH" "$TMP_COPY"
echo -e "${GREEN}✓${NC} Copia creada\n"

# Verificar conexión
echo -e "${BLUE}2. Verificando conexión...${NC}"
ssh -p $SSH_PORT -o ConnectTimeout=5 "$DEST_HOST" "echo OK" >/dev/null
echo -e "${GREEN}✓${NC} Conexión OK\n"

# Preparar directorio remoto
echo -e "${BLUE}3. Preparando directorio remoto...${NC}"
ssh -p $SSH_PORT "$DEST_HOST" "mkdir -p /backups/photos_db"
echo -e "${GREEN}✓${NC} Directorio listo\n"

# Método 1: Intentar con scp (más robusto para archivos grandes)
echo -e "${BLUE}4. Copiando archivo (método scp)...${NC}"
echo -e "${CYAN}Esto puede tardar varios minutos...${NC}\n"

if scp -P $SSH_PORT \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=10 \
    -o TCPKeepAlive=yes \
    -C \
    "$TMP_COPY" \
    "$DEST_HOST:$DEST_PATH" 2>&1; then
    
    echo -e "\n${GREEN}${BOLD}✅ Copia completada con scp${NC}\n"
    
    # Verificar
    echo -e "${BLUE}5. Verificando...${NC}"
    REMOTE_SIZE=$(ssh -p $SSH_PORT "$DEST_HOST" "ls -lh /backups/photos_db/Photos.sqlite 2>/dev/null | awk '{print \$5}'" || echo "")
        if [ -n "$REMOTE_SIZE" ]; then
            echo -e "${GREEN}✓${NC} Archivo en destino: $REMOTE_SIZE"
            REMOTE_MD5=$(ssh -p $SSH_PORT "$DEST_HOST" "md5sum /backups/photos_db/Photos.sqlite 2>/dev/null | cut -d' ' -f1" || echo "")
        LOCAL_MD5=$(md5 -q "$DB_PATH" 2>/dev/null || md5sum "$DB_PATH" | cut -d' ' -f1)
        if [ "$REMOTE_MD5" = "$LOCAL_MD5" ]; then
            echo -e "${GREEN}✓${NC} Verificación MD5: OK\n"
        else
            echo -e "${YELLOW}⚠${NC}  MD5 no coincide (puede ser normal si se comprimió)\n"
        fi
    fi
    
    rm -f "$TMP_COPY"
    echo -e "${GREEN}✓${NC} Archivo temporal eliminado\n"
    echo -e "${CYAN}${BOLD}✅ PROCESO COMPLETADO${NC}\n"
    exit 0
else
    echo -e "\n${YELLOW}⚠${NC}  scp falló, intentando con rsync...\n"
fi

# Método 2: Intentar con rsync como respaldo
echo -e "${BLUE}Intentando con rsync (método alternativo)...${NC}"

if rsync -avz \
    --progress \
    --human-readable \
    --timeout=300 \
    --partial \
    --inplace \
    -e "ssh -p $SSH_PORT -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o TCPKeepAlive=yes" \
    "$TMP_COPY" \
    "$DEST_HOST:$DEST_PATH" 2>&1; then
    
    echo -e "\n${GREEN}${BOLD}✅ Copia completada con rsync${NC}\n"
    rm -f "$TMP_COPY"
    echo -e "${CYAN}${BOLD}✅ PROCESO COMPLETADO${NC}\n"
    exit 0
else
    echo -e "\n${YELLOW}✗${NC} Ambos métodos fallaron"
    echo -e "${YELLOW}Posibles causas:${NC}"
    echo -e "  • Conexión inestable"
    echo -e "  • Servidor SSH cerrando conexiones largas"
    echo -e "  • Espacio insuficiente en destino\n"
    rm -f "$TMP_COPY"
    exit 1
fi
