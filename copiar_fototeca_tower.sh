#!/bin/bash

# Script para copiar Fototeca.photoslibrary a tower

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SOURCE_LIBRARY="/Volumes/usbshare1/Fototeca.photoslibrary"
DEST_HOST="root@192.168.1.42"
DEST_PATH="/mnt/user/backups/photos_db/Fototeca.photoslibrary"
SSH_PORT="62500"
MAX_RETRIES=10

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📸  COPIA FOTOTECA A TOWER                           ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar biblioteca origen
if [ ! -d "$SOURCE_LIBRARY" ]; then
    echo -e "${RED}✗${NC} No se encontró la biblioteca: $SOURCE_LIBRARY"
    exit 1
fi

echo -e "${BLUE}Calculando tamaño de biblioteca...${NC}"
SOURCE_SIZE=$(du -sh "$SOURCE_LIBRARY" | cut -f1)
echo -e "${BLUE}Biblioteca origen:${NC} $SOURCE_LIBRARY ($SOURCE_SIZE)"
echo -e "${BLUE}Destino:${NC} $DEST_HOST:$DEST_PATH\n"

# Calcular tamaño en kilobytes (compatible con macOS) - hacerlo en background para no bloquear
echo -e "${BLUE}Calculando tamaño detallado...${NC}"
SOURCE_SIZE_KB=$(du -sk "$SOURCE_LIBRARY" 2>/dev/null | awk '{print $1}' || echo "0")
SOURCE_SIZE_BYTES=$((SOURCE_SIZE_KB * 1024))

# Función para formatear bytes a formato legible
format_bytes() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Función para formatear tiempo
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${secs}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Verificar conexión
echo -e "${BLUE}1. Verificando conexión...${NC}" >&2
if ! ssh -p $SSH_PORT -o ConnectTimeout=5 "$DEST_HOST" "echo OK" >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} No se puede conectar a tower" >&2
    exit 1
fi
echo -e "${GREEN}✓${NC} Conexión OK\n" >&2

# Verificar espacio
echo -e "${BLUE}2. Verificando espacio en disco...${NC}"
AVAILABLE=$(ssh -p $SSH_PORT "$DEST_HOST" "df -h /mnt/user/backups 2>/dev/null | tail -1 | awk '{print \$4}'" || ssh -p $SSH_PORT "$DEST_HOST" "df -h / | tail -1 | awk '{print \$4}'")
CURRENT_SIZE=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sh $DEST_PATH 2>/dev/null | cut -f1" || echo "0")
echo -e "   Espacio disponible: ${CYAN}${AVAILABLE}${NC}"
echo -e "   Ya copiado: ${CYAN}$CURRENT_SIZE${NC}\n"

# Calcular tamaño ya copiado (si existe)
REMOTE_SIZE_BYTES=0
if ssh -p $SSH_PORT "$DEST_HOST" "test -d $DEST_PATH" >/dev/null 2>&1; then
    REMOTE_SIZE_BYTES=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sk $DEST_PATH 2>/dev/null | awk '{print \$1 * 1024}'" || echo "0")
fi

# Calcular tamaño pendiente
PENDING_BYTES=$((SOURCE_SIZE_BYTES - REMOTE_SIZE_BYTES))
if [ $PENDING_BYTES -gt 0 ]; then
    PENDING_SIZE=$(format_bytes $PENDING_BYTES)
    echo -e "${BLUE}Tamaño total:${NC} ${CYAN}$SOURCE_SIZE${NC}"
    echo -e "${BLUE}Tamaño pendiente:${NC} ${CYAN}$PENDING_SIZE${NC}\n"
fi

# Función para transferir con reintentos y estimación de tiempo
transfer_with_retries() {
    local attempt=1
    local start_time=$(date +%s)
    local avg_speed=0
    
    while [ $attempt -le $MAX_RETRIES ]; do
        echo -e "${BLUE}3. Intento $attempt de $MAX_RETRIES...${NC}"
        
        # Calcular tamaño pendiente antes de empezar
        local current_remote_size=0
        if ssh -p $SSH_PORT "$DEST_HOST" "test -d $DEST_PATH" >/dev/null 2>&1; then
            current_remote_size=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sk $DEST_PATH 2>/dev/null | awk '{print \$1 * 1024}'" || echo "0")
        fi
        local remaining=$((SOURCE_SIZE_BYTES - current_remote_size))
        
        if [ $remaining -gt 0 ]; then
            echo -e "${CYAN}Transfiriendo biblioteca...${NC}"
            echo -e "${BLUE}   Pendiente: ${CYAN}$(format_bytes $remaining)${NC}"
            
            # Si tenemos una velocidad promedio, estimar tiempo
            if [ $avg_speed -gt 0 ] && [ $remaining -gt 0 ]; then
                local estimated_seconds=$((remaining / avg_speed))
                if [ $estimated_seconds -gt 0 ]; then
                    echo -e "${BLUE}   Estimación: ${CYAN}$(format_time $estimated_seconds)${NC} (basado en velocidad promedio)"
                    echo -e "${BLUE}   Velocidad promedio: ${CYAN}$(format_bytes $avg_speed)/s${NC}\n"
                else
                    echo -e "${BLUE}   Estimación: ${CYAN}Calculando...${NC}\n"
                fi
            else
                echo -e "${BLUE}   Estimación: ${CYAN}Calculando velocidad...${NC}\n"
            fi
        else
            echo -e "${CYAN}Verificando archivos finales...${NC}\n"
        fi
        
        # Capturar salida de rsync para calcular velocidad
        local rsync_output=$(mktemp)
        local transfer_start=$(date +%s)
        
        # Guardar salida también en log para seguimiento
        local log_file="/tmp/rsync_fototeca_$(date +%Y%m%d_%H%M%S).log"
        
        if rsync -avz \
            --progress \
            --human-readable \
            --timeout=900 \
            --partial \
            --partial-dir=.rsync-partial \
            --bwlimit=30000 \
            -e "ssh -p $SSH_PORT -o ServerAliveInterval=10 -o ServerAliveCountMax=30 -o TCPKeepAlive=yes -o Compression=yes -o ConnectTimeout=30" \
            "$SOURCE_LIBRARY/" \
            "$DEST_HOST:$DEST_PATH/" 2>&1 | tee "$rsync_output" | tee "$log_file"; then
            
            # Calcular velocidad promedio
            local transfer_end=$(date +%s)
            local transfer_duration=$((transfer_end - transfer_start))
            if [ $transfer_duration -gt 0 ]; then
                local final_remote_size=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sk $DEST_PATH 2>/dev/null | awk '{print \$1 * 1024}'" || echo "$current_remote_size")
                local transferred=$((final_remote_size - current_remote_size))
                if [ $transferred -gt 0 ] && [ $transfer_duration -gt 0 ]; then
                    avg_speed=$((transferred / transfer_duration))
                    echo -e "\n${GREEN}✓${NC} Velocidad promedio: ${CYAN}$(format_bytes $avg_speed)/s${NC}"
                fi
            fi
            
            rm -f "$rsync_output"
            
            local total_time=$(($(date +%s) - start_time))
            echo -e "\n${GREEN}${BOLD}✅ Transferencia completada exitosamente${NC}"
            echo -e "${BLUE}Tiempo total: ${CYAN}$(format_time $total_time)${NC}\n"
            return 0
        else
            local exit_code=$?
            echo -e "\n${YELLOW}⚠${NC}  Transferencia interrumpida (código: $exit_code)\n"
            
            if [ $attempt -lt $MAX_RETRIES ]; then
                # Esperar más tiempo entre reintentos (aumenta progresivamente)
                local wait_time=$((attempt * 10))
                echo -e "${YELLOW}Esperando ${wait_time} segundos antes de reintentar...${NC}"
                echo -e "${YELLOW}(Esto permite que el servidor SSH se recupere)${NC}\n"
                sleep $wait_time
                
                # Verificar que el servidor esté disponible antes de reintentar
                echo -e "${BLUE}Verificando conexión antes de reintentar...${NC}"
                if ssh -p $SSH_PORT -o ConnectTimeout=10 "$DEST_HOST" "echo OK" >/dev/null 2>&1; then
                    echo -e "${GREEN}✓${NC} Servidor disponible\n"
                else
                    echo -e "${YELLOW}⚠${NC}  Servidor aún no disponible, esperando más...\n"
                    sleep 20
                fi
                
                attempt=$((attempt + 1))
            else
                echo -e "${RED}✗${NC} Se agotaron los reintentos\n"
                rm -f "$rsync_output"
                return 1
            fi
        fi
    done
}

# Ejecutar transferencia
if transfer_with_retries; then
    # Verificar resultado
    echo -e "${BLUE}4. Verificando resultado...${NC}"
    REMOTE_SIZE=$(ssh -p $SSH_PORT "$DEST_HOST" "du -sh $DEST_PATH 2>/dev/null | cut -f1" || echo "")
    if [ -n "$REMOTE_SIZE" ]; then
        echo -e "${GREEN}✓${NC} Biblioteca en destino: ${CYAN}$REMOTE_SIZE${NC}"
        echo -e "${GREEN}✓${NC} Ubicación: ${CYAN}$DEST_PATH${NC}\n"
    fi
    
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     ✅  PROCESO COMPLETADO                              ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
else
    echo -e "${YELLOW}La transferencia se interrumpió pero puedes reanudarla ejecutando este script de nuevo.${NC}\n"
    exit 1
fi
