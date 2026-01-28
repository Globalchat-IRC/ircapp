#!/bin/bash

# Versión alternativa que copia primero a un lugar temporal

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
TMP_COPY="/tmp/${LIBRARY_NAME}_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📸  COPIA BIBLIOTECA PHOTOS (MÉTODO ALTERNATIVO)     ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar que existe la biblioteca
if [ ! -d "$SOURCE_LIBRARY" ]; then
    echo -e "${YELLOW}✗${NC} No se encontró la biblioteca: $SOURCE_LIBRARY"
    exit 1
fi

echo -e "${BLUE}Este método copia primero a /tmp y luego transfiere${NC}"
echo -e "${BLUE}Esto puede ayudar a evitar problemas de permisos${NC}\n"

# Verificar conexión
echo -e "${BLUE}1. Verificando conexión...${NC}"
ssh -p $SSH_PORT -o ConnectTimeout=5 "$DEST_HOST" "echo OK" >/dev/null
echo -e "${GREEN}✓${NC} Conexión OK\n"

# Preparar directorio remoto
echo -e "${BLUE}2. Preparando directorio remoto...${NC}"
ssh -p $SSH_PORT "$DEST_HOST" "mkdir -p $DEST_PATH"
echo -e "${GREEN}✓${NC} Directorio listo\n"

# Copiar a temporal primero
echo -e "${BLUE}3. Copiando biblioteca a directorio temporal local...${NC}"
echo -e "${CYAN}Esto puede tardar...${NC}\n"

if cp -R "$SOURCE_LIBRARY" "$TMP_COPY" 2>&1; then
    echo -e "${GREEN}✓${NC} Copia local completada\n"
    
    # Obtener tamaño
    TMP_SIZE=$(du -sh "$TMP_COPY" 2>/dev/null | cut -f1 || echo "calculando...")
    echo -e "${BLUE}Tamaño de la copia temporal:${NC} $TMP_SIZE\n"
    
    # Transferir a tower
    echo -e "${BLUE}4. Transfiriendo a tower...${NC}"
    echo -e "${CYAN}Esto puede tardar mucho tiempo...${NC}\n"
    
    if rsync -avz \
        --progress \
        --human-readable \
        --timeout=600 \
        --partial \
        --partial-dir=.rsync-partial \
        --bwlimit=50000 \
        -e "ssh -p $SSH_PORT -o ServerAliveInterval=15 -o ServerAliveCountMax=20 -o TCPKeepAlive=yes -o Compression=yes" \
        "$TMP_COPY/" \
        "$DEST_HOST:$DEST_PATH/$LIBRARY_NAME/" 2>&1; then
        
        echo -e "\n${GREEN}${BOLD}✅ Biblioteca copiada exitosamente${NC}\n"
        
        # Verificar
        echo -e "${BLUE}5. Verificando...${NC}"
        REMOTE_SIZE=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sh $DEST_PATH/$LIBRARY_NAME 2>/dev/null | cut -f1" || echo "")
        if [ -n "$REMOTE_SIZE" ]; then
            echo -e "${GREEN}✓${NC} Biblioteca en destino: $REMOTE_SIZE"
            echo -e "${GREEN}✓${NC} Ubicación: $DEST_PATH/$LIBRARY_NAME\n"
        fi
        
        # Limpiar temporal
        echo -e "${BLUE}6. Limpiando archivos temporales...${NC}"
        rm -rf "$TMP_COPY"
        echo -e "${GREEN}✓${NC} Archivos temporales eliminados\n"
        
        echo -e "${CYAN}${BOLD}✅ PROCESO COMPLETADO${NC}\n"
        echo -e "${BLUE}La biblioteca completa está en:${NC}"
        echo -e "  ${CYAN}$DEST_PATH/$LIBRARY_NAME${NC}\n"
    else
        echo -e "\n${YELLOW}✗${NC} Error durante la transferencia"
        echo -e "${YELLOW}La copia temporal está en:${NC} $TMP_COPY"
        echo -e "${YELLOW}Puedes intentar transferirla manualmente más tarde${NC}\n"
        exit 1
    fi
else
    echo -e "${YELLOW}✗${NC} Error al copiar a temporal"
    echo -e "${YELLOW}Verifica permisos de acceso completo al disco${NC}\n"
    exit 1
fi
