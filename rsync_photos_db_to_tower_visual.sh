#!/usr/bin/env bash
# Compatible con bash y zsh

# Script visual para copiar la base de datos de Photos a tower usando rsync
# Versión con interfaz gráfica y visual mejorada

set -e

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

# Configuración
DEFAULT_DEST="tower:~/backups/photos_db/"
PHOTOS_DB_NAME="Photos.sqlite"

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
    local max_width=58
    
    echo -e "${color}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    # Título con padding
    local title_padded=$(printf "%-58s" "$title")
    printf "${color}${BOLD}║${NC} ${BOLD}%s${NC} ${color}${BOLD}║${NC}\n" "$title_padded"
    printf "${color}${BOLD}║${NC} %-58s ${color}${BOLD}║${NC}\n" ""
    
    # Procesar contenido línea por línea
    while IFS= read -r line; do
        # Si la línea es muy larga, truncarla o dividirla
        if [ ${#line} -gt $max_width ]; then
            # Truncar y añadir "..."
            local truncated="${line:0:$((max_width-3))}..."
            printf "${color}${BOLD}║${NC} %-58s ${color}${BOLD}║${NC}\n" "$truncated"
        else
            printf "${color}${BOLD}║${NC} %-58s ${color}${BOLD}║${NC}\n" "$line"
        fi
    done <<< "$content"
    
    echo -e "${color}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

# Función para mostrar progreso visual
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${percentage}%%${NC}"
}

# Función para diálogo de macOS
show_dialog() {
    local title="$1"
    local message="$2"
    local buttons="$3"
    local default_button="${4:-1}"
    
    osascript -e "tell application \"System Events\"
        display dialog \"$message\" buttons {$buttons} default button $default_button with title \"$title\" with icon note
        return button returned of result
    end tell" 2>/dev/null || echo "Cancel"
}

# Función para diálogo de entrada
show_input_dialog() {
    local title="$1"
    local message="$2"
    local default="$3"
    
    osascript -e "tell application \"System Events\"
        text returned of (display dialog \"$message\" default answer \"$default\" with title \"$title\" buttons {\"Cancelar\", \"Aceptar\"} default button \"Aceptar\" with icon note)
    end tell" 2>/dev/null || echo ""
}

# Función para encontrar bibliotecas
find_photos_libraries() {
    local home_dir="$HOME"
    local pictures_dir="$home_dir/Pictures"
    local libraries=()
    
    if [ ! -d "$pictures_dir" ]; then
        return 1
    fi
    
    while IFS= read -r -d '' library; do
        libraries+=("$library")
    done < <(find "$pictures_dir" -maxdepth 1 -name "*.photoslibrary" -type d -print0 2>/dev/null)
    
    printf '%s\n' "${libraries[@]}"
}

# Función para seleccionar biblioteca interactivamente
select_library() {
    local libraries=("$@")
    local count=${#libraries[@]}
    
    if [ $count -eq 0 ]; then
        return 1
    fi
    
    if [ $count -eq 1 ]; then
        echo "${libraries[0]}"
        return 0
    fi
    
    # Mostrar menú visual
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║${NC} ${BOLD}Selecciona la biblioteca de Photos:${NC}"
    echo -e "${CYAN}${BOLD}╠════════════════════════════════════════════════════════════╣${NC}"
    
    local i=1
    for lib in "${libraries[@]}"; do
        local name=$(basename "$lib")
        local db_path="$lib/database/$PHOTOS_DB_NAME"
        if [ -f "$db_path" ]; then
            local size=$(du -h "$db_path" | cut -f1)
            printf "${CYAN}${BOLD}║${NC}  ${GREEN}${CHECK}${NC} $i. ${BOLD}%s${NC}\n" "$name"
            printf "${CYAN}${BOLD}║${NC}     Tamaño: %s\n" "$size"
        else
            printf "${CYAN}${BOLD}║${NC}  ${YELLOW}${WARNING}${NC} $i. %s (BD no encontrada)\n" "$name"
        fi
        i=$((i + 1))
    done
    
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Solicitar selección
    while true; do
        echo -ne "${YELLOW}Selecciona (1-$count): ${NC}"
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $count ]; then
            echo "${libraries[$((choice - 1))]}"
            return 0
        else
            echo -e "${RED}${CROSS} Selección inválida. Intenta de nuevo.${NC}"
        fi
    done
}

# Función para obtener información de la BD
get_db_info() {
    local db_path="$1"
    local info=()
    
    if [ -f "$db_path" ]; then
        local size=$(du -h "$db_path" | cut -f1)
        local modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$db_path" 2>/dev/null || stat -c "%y" "$db_path" 2>/dev/null | cut -d' ' -f1-2)
        # Mostrar ruta relativa al home para que sea más corta
        local short_path="${db_path/#$HOME/~}"
        
        info+=("Tamaño: $size")
        info+=("Modificado: $modified")
        info+=("Ruta: $short_path")
    fi
    
    printf '%s\n' "${info[@]}"
}

# Función principal
main() {
    show_banner
    
    # Buscar bibliotecas
    echo -e "${SEARCH} ${BLUE}${BOLD}Buscando bibliotecas de Photos...${NC}\n"
    
    local libraries
    # Compatible con zsh y bash - construye array línea por línea
    libraries=()
    while IFS= read -r line; do
        [ -n "$line" ] && libraries+=("$line")
    done < <(find_photos_libraries)
    
    if [ ${#libraries[@]} -eq 0 ]; then
        show_box "Error" "No se encontraron bibliotecas de Photos en ~/Pictures" "$RED"
        show_dialog "Error" "No se encontraron bibliotecas de Photos.\n\nVerifica que tengas una biblioteca de Photos configurada." "OK" 1
        exit 1
    fi
    
    # Seleccionar biblioteca
    local selected_library
    selected_library=$(select_library "${libraries[@]}")
    
    if [ -z "$selected_library" ]; then
        exit 1
    fi
    
    local library_name=$(basename "$selected_library")
    local db_path="$selected_library/database/$PHOTOS_DB_NAME"
    
    # Verificar que existe la BD
    if [ ! -f "$db_path" ]; then
        show_box "Error" "No se encontró la base de datos:\n$db_path" "$RED"
        exit 1
    fi
    
    # Mostrar información de la BD
    local db_info
    # Compatible con zsh y bash - construye array línea por línea
    db_info=()
    while IFS= read -r line; do
        [ -n "$line" ] && db_info+=("$line")
    done < <(get_db_info "$db_path")
    
    # Construir texto con saltos de línea reales
    local info_text=""
    for line in "${db_info[@]}"; do
        if [ -n "$info_text" ]; then
            info_text+=$'\n'
        fi
        info_text+="$line"
    done
    
    show_box "${FOLDER} Biblioteca: $library_name" "$info_text" "$GREEN"
    
    # Solicitar destino
    echo -e "${ARROW} ${BLUE}${BOLD}Configuración de destino:${NC}\n"
    echo -e "${INFO} Destino por defecto: ${CYAN}${DEFAULT_DEST}${NC}"
    echo -ne "${YELLOW}¿Usar destino por defecto? (s/n): ${NC}"
    read -r use_default
    
    local dest=""
    if [[ "$use_default" =~ ^[sS] ]]; then
        dest="$DEFAULT_DEST"
    else
        echo -ne "${YELLOW}Ingresa destino (usuario@servidor:/ruta): ${NC}"
        read -r dest
        if [ -z "$dest" ]; then
            dest="$DEFAULT_DEST"
        fi
    fi
    
    show_box "${ROCKET} Destino" "Servidor: $dest" "$CYAN"
    
    # Confirmación visual
    local db_size=$(du -h "$db_path" | cut -f1)
    
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║${NC} ${BOLD}Confirmar Copia${NC}"
    echo -e "${CYAN}${BOLD}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}${BOLD}║${NC} Origen: $library_name"
    echo -e "${CYAN}${BOLD}║${NC} Destino: $dest"
    echo -e "${CYAN}${BOLD}║${NC} Tamaño: $db_size"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Intentar diálogo de macOS, si falla usar confirmación por terminal
    local response=""
    response=$(show_dialog "Confirmar Copia" "¿Confirmar copia?\n\nOrigen: $library_name\nDestino: $dest\nTamaño: $db_size" "{\"Cancelar\", \"Confirmar\"}" 2) 2>/dev/null
    
    # Si el diálogo falló o el usuario canceló, usar confirmación por terminal
    if [ "$response" != "Confirmar" ]; then
        echo -ne "${YELLOW}¿Confirmar y proceder con la copia? (s/n): ${NC}"
        read -r confirm_terminal
        
        if [[ ! "$confirm_terminal" =~ ^[sS] ]]; then
            echo -e "\n${YELLOW}${WARNING} Operación cancelada por el usuario${NC}\n"
            exit 0
        fi
    fi
    
    # Ejecutar rsync con progreso visual
    echo -e "\n${ROCKET} ${BLUE}${BOLD}Iniciando copia...${NC}\n"
    
    # Crear archivo temporal para capturar progreso y errores
    local temp_file=$(mktemp)
    local error_file=$(mktemp)
    
    # Ejecutar rsync y capturar tanto output como errores
    rsync -avz --progress --human-readable "$db_path" "$dest" > "$temp_file" 2> "$error_file" &
    local rsync_pid=$!
    
    # Mostrar progreso mientras se ejecuta
    local last_line=""
    local last_percent=0
    while kill -0 $rsync_pid 2>/dev/null; do
        if [ -f "$temp_file" ]; then
            local current_line=$(tail -n 1 "$temp_file" 2>/dev/null | grep -o '[0-9]*%' | head -1 || echo "")
            if [ -n "$current_line" ]; then
                local percent=$(echo "$current_line" | tr -d '%')
                if [ "$percent" != "$last_percent" ]; then
                    show_progress "$percent" 100
                    last_percent="$percent"
                fi
            fi
        fi
        sleep 0.3
    done
    
    # Esperar a que termine y obtener código de salida
    wait $rsync_pid
    local exit_code=$?
    
    # Limpiar línea de progreso
    echo ""
    
    # Verificar si hay errores en el archivo de errores
    local has_errors=false
    if [ -s "$error_file" ]; then
        local error_content=$(cat "$error_file")
        if echo "$error_content" | grep -qiE "(error|failed|connection refused|permission denied)"; then
            has_errors=true
        fi
    fi
    
    # Limpiar archivos temporales
    rm -f "$temp_file" "$error_file"
    
    # Verificar éxito (código de salida 0 y sin errores)
    if [ $exit_code -eq 0 ] && [ "$has_errors" = false ]; then
        echo -e "\n${SUCCESS} ${GREEN}${BOLD}Copia completada exitosamente${NC}\n"
        
        # Construir resumen con saltos de línea reales
        local summary=""
        summary+="Origen: $library_name"
        summary+=$'\n'
        summary+="Destino: $dest"
        summary+=$'\n'
        summary+="Tamaño: $db_size"
        summary+=$'\n'
        summary+="Estado: ${GREEN}${CHECK} Completado${NC}"
        
        show_box "${SUCCESS} Resumen" "$summary" "$GREEN"
        
        # Diálogo de éxito (opcional, no crítico si falla)
        show_dialog "Éxito" "La base de datos se copió exitosamente a:\n$dest" "OK" 1 2>/dev/null || true
        
        echo -e "${BLUE}${INFO}${NC} Para verificar en el servidor remoto:"
        local dest_host="${dest%%:*}"
        local dest_path="${dest#*:}"
        # Limpiar doble slash si existe
        dest_path="${dest_path//\/\//\/}"
        echo -e "   ${CYAN}ssh $dest_host 'ls -lh $dest_path/$PHOTOS_DB_NAME'${NC}\n"
    else
        echo -e "\n${ERROR} ${RED}${BOLD}Error durante la copia${NC}\n"
        
        # Construir mensaje de error con saltos de línea reales
        local error_msg=""
        error_msg+="Verifica:"
        error_msg+=$'\n'
        error_msg+="• Que 'tower' sea accesible (ssh tower)"
        error_msg+=$'\n'
        error_msg+="• Que tengas permisos de escritura"
        error_msg+=$'\n'
        error_msg+="• Que la ruta de destino exista"
        error_msg+=$'\n'
        error_msg+=$'\n'
        error_msg+="Código de error: $exit_code"
        
        show_box "${ERROR} Error" "$error_msg" "$RED"
        
        # Diálogo de error (opcional, no crítico si falla)
        show_dialog "Error" "Ocurrió un error durante la copia.\n\nVerifica la conexión y permisos.\n\nCódigo: $exit_code" "OK" 1 2>/dev/null || true
        
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
