#!/bin/bash

# Versión suave que no satura el servidor SSH

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

TMP_COPY="/tmp/temporal.photoslibrary_backup_20260112_191946"
DEST_HOST="root@192.168.1.42"
DEST_PATH="/root/temporal.photoslibrary"
SSH_PORT="62500"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📸  COPIA SUAVE (NO SATURA SERVIDOR)                ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar copia temporal
if [ ! -d "$TMP_COPY" ]; then
    echo -e "${RED}✗${NC} No se encontró la copia temporal: $TMP_COPY"
    exit 1
fi

TMP_SIZE=$(du -sh "$TMP_COPY" | cut -f1)
echo -e "${BLUE}Copia temporal:${NC} $TMP_COPY ($TMP_SIZE)"
echo -e "${BLUE}Destino:${NC} $DEST_HOST:$DEST_PATH\n"

# Función para verificar servidor con espera
wait_for_server() {
    local max_wait=300  # 5 minutos máximo
    local waited=0
    local interval=30   # Verificar cada 30 segundos
    
    echo -e "${BLUE}Esperando a que el servidor SSH esté disponible...${NC}"
    
    while [ $waited -lt $max_wait ]; do
        if ssh -p $SSH_PORT -o ConnectTimeout=5 -o BatchMode=yes "$DEST_HOST" "echo OK" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Servidor disponible después de ${waited}s\n"
            return 0
        fi
        
        echo -e "${YELLOW}Esperando... (${waited}s/${max_wait}s)${NC}"
        sleep $interval
        waited=$((waited + interval))
    done
    
    echo -e "${RED}✗${NC} Servidor no disponible después de ${max_wait}s\n"
    return 1
}

# Esperar a que el servidor esté disponible
if ! wait_for_server; then
    echo -e "${RED}El servidor SSH está bloqueado. Espera más tiempo y vuelve a intentar.${NC}\n"
    exit 1
fi

# Verificar espacio
echo -e "${BLUE}Verificando espacio en disco...${NC}"
AVAILABLE=$(ssh -p $SSH_PORT "$DEST_HOST" "df -h / | tail -1 | awk '{print \$4}'" | sed 's/G//')
CURRENT_SIZE=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sh $DEST_PATH 2>/dev/null | cut -f1" || echo "0")
echo -e "   Espacio disponible: ${CYAN}${AVAILABLE}G${NC}"
echo -e "   Ya copiado: ${CYAN}$CURRENT_SIZE${NC}\n"

# Transferir con opciones muy conservadoras
echo -e "${BLUE}Iniciando transferencia suave...${NC}"
echo -e "${CYAN}Usando ancho de banda limitado y timeouts largos para no saturar el servidor${NC}\n"

if rsync -avz \
    --progress \
    --human-readable \
    --timeout=1200 \
    --partial \
    --partial-dir=.rsync-partial \
    --bwlimit=10000 \
    --delay-updates \
    -e "ssh -p $SSH_PORT -o ServerAliveInterval=60 -o ServerAliveCountMax=5 -o TCPKeepAlive=yes -o Compression=yes -o ConnectTimeout=60" \
    "$TMP_COPY/" \
    "$DEST_HOST:$DEST_PATH/" 2>&1; then
    
    echo -e "\n${GREEN}${BOLD}✅ Transferencia completada exitosamente${NC}\n"
    
    # Verificar resultado
    echo -e "${BLUE}Verificando resultado...${NC}"
    REMOTE_SIZE=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sh $DEST_PATH 2>/dev/null | cut -f1" || echo "")
    if [ -n "$REMOTE_SIZE" ]; then
        echo -e "${GREEN}✓${NC} Biblioteca en destino: ${CYAN}$REMOTE_SIZE${NC}"
        echo -e "${GREEN}✓${NC} Ubicación: ${CYAN}$DEST_PATH${NC}\n"
    fi
    
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     ✅  PROCESO COMPLETADO                              ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
else
    local exit_code=$?
    echo -e "\n${YELLOW}⚠${NC}  Transferencia interrumpida (código: $exit_code)\n"
    echo -e "${YELLOW}El servidor puede haberse bloqueado de nuevo.${NC}"
    echo -e "${YELLOW}Espera 5-10 minutos y ejecuta este script de nuevo.${NC}"
    echo -e "${YELLOW}Continuará desde donde se quedó gracias a --partial${NC}\n"
    exit 1
fi
