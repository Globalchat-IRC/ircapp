#!/bin/bash

# Demo del script visual - muestra la interfaz sin ejecutar rsync

# Colores y estilos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Símbolos
CHECK="✓"
CROSS="✗"
ARROW="→"
FOLDER="📁"
DISK="💾"
ROCKET="🚀"
SEARCH="🔍"
SUCCESS="✅"
WARNING="⚠️"
ERROR="❌"
INFO="ℹ️"

# Función para mostrar banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║     📸  RSYNC PHOTOS DATABASE TO TOWER  💾                ║"
    echo "║                                                            ║"
    echo "║     Copia la base de datos de Photos a servidor remoto    ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Función para mostrar caja de información
show_box() {
    local title="$1"
    local content="$2"
    local color="${3:-$BLUE}"
    
    echo -e "${color}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    printf "${color}${BOLD}║${NC} ${BOLD}%-58s${NC} ${color}${BOLD}║${NC}\n" "$title"
    printf "${color}${BOLD}║${NC} %-58s ${color}${BOLD}║${NC}\n" ""
    while IFS= read -r line; do
        printf "${color}${BOLD}║${NC} %-58s ${color}${BOLD}║${NC}\n" "$line"
    done <<< "$content"
    echo -e "${color}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

# Función para mostrar progreso visual
show_progress_bar() {
    local percent=$1
    local width=50
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    printf "${CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${percent}%%${NC}\n"
}

# Demo
show_banner

sleep 1

echo -e "${SEARCH} ${BLUE}${BOLD}Buscando bibliotecas de Photos...${NC}\n"
sleep 1

# Simular búsqueda
echo -e "${GREEN}${CHECK}${NC} Biblioteca encontrada: ${BOLD}temporal.photoslibrary${NC}\n"
sleep 1

# Mostrar información de la BD
info_content="Tamaño: 271M
Modificado: 2026-01-12 17:26:04
Ruta: /Users/fnaveira/Pictures/temporal.photoslibrary/database/Photos.sqlite"

show_box "${FOLDER} Biblioteca: temporal.photoslibrary" "$info_content" "$GREEN"

sleep 1

# Mostrar destino
dest_content="Servidor: tower:~/backups/photos_db/"
show_box "${ROCKET} Destino" "$dest_content" "$CYAN"

sleep 1

# Simular progreso
echo -e "\n${ROCKET} ${BLUE}${BOLD}Iniciando copia...${NC}\n"
sleep 0.5

for i in 0 10 20 30 40 50 60 70 80 90 100; do
    show_progress_bar $i
    sleep 0.1
done

echo ""
echo -e "${SUCCESS} ${GREEN}${BOLD}Copia completada exitosamente${NC}\n"

summary_content="Origen: temporal.photoslibrary
Destino: tower:~/backups/photos_db/
Tamaño: 271M
Estado: ${GREEN}${CHECK} Completado${NC}"

show_box "${SUCCESS} Resumen" "$summary_content" "$GREEN"

echo -e "${BLUE}${INFO}${NC} Para verificar en el servidor remoto:"
echo -e "   ${CYAN}ssh tower 'ls -lh ~/backups/photos_db/Photos.sqlite'${NC}\n"
