#!/bin/bash

# Script para copiar la base de datos de Photos a tower usando rsync
# Uso: ./rsync_photos_db_to_tower.sh [usuario@tower:/ruta/destino]

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración por defecto
DEFAULT_DEST="tower:~/backups/photos_db/"
PHOTOS_DB_NAME="Photos.sqlite"

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}Uso:${NC} $0 [usuario@tower:/ruta/destino]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help          Mostrar esta ayuda"
    echo "  -l, --list          Listar bibliotecas de Photos encontradas"
    echo "  -d, --dry-run       Simular sin copiar realmente"
    echo ""
    echo "Ejemplos:"
    echo "  $0                                    # Usa destino por defecto: tower:~/backups/photos_db/"
    echo "  $0 user@tower:/backups/photos/        # Especifica destino personalizado"
    echo "  $0 --list                             # Lista bibliotecas disponibles"
    echo "  $0 --dry-run                          # Simula la copia"
}

# Función para encontrar la biblioteca de Photos
find_photos_library() {
    local home_dir="$HOME"
    local pictures_dir="$home_dir/Pictures"
    
    if [ ! -d "$pictures_dir" ]; then
        echo -e "${RED}❌ No se encontró el directorio Pictures${NC}"
        return 1
    fi
    
    # Buscar bibliotecas .photoslibrary
    local libraries=()
    while IFS= read -r -d '' library; do
        libraries+=("$library")
    done < <(find "$pictures_dir" -maxdepth 1 -name "*.photoslibrary" -type d -print0 2>/dev/null)
    
    if [ ${#libraries[@]} -eq 0 ]; then
        echo -e "${RED}❌ No se encontraron bibliotecas de Photos${NC}"
        return 1
    fi
    
    # Si hay múltiples, usar la primera (o la más reciente)
    if [ ${#libraries[@]} -gt 1 ]; then
        echo -e "${YELLOW}⚠️  Se encontraron múltiples bibliotecas:${NC}"
        for i in "${!libraries[@]}"; do
            echo "  $((i+1)). ${libraries[$i]}"
        done
        echo -e "${YELLOW}Usando la primera: ${libraries[0]}${NC}"
    fi
    
    echo "${libraries[0]}"
}

# Función para listar bibliotecas
list_photos_libraries() {
    local home_dir="$HOME"
    local pictures_dir="$home_dir/Pictures"
    
    if [ ! -d "$pictures_dir" ]; then
        echo -e "${RED}❌ No se encontró el directorio Pictures${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📚 Bibliotecas de Photos encontradas:${NC}"
    local count=0
    while IFS= read -r -d '' library; do
        count=$((count + 1))
        local db_path="$library/database/$PHOTOS_DB_NAME"
        if [ -f "$db_path" ]; then
            local size=$(du -h "$db_path" | cut -f1)
            local modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$db_path" 2>/dev/null || stat -c "%y" "$db_path" 2>/dev/null | cut -d' ' -f1-2)
            echo -e "  ${GREEN}✓${NC} $count. $(basename "$library")"
            echo -e "     Ruta: $library"
            echo -e "     BD: $db_path"
            echo -e "     Tamaño: $size | Modificado: $modified"
        else
            echo -e "  ${YELLOW}⚠${NC}  $count. $(basename "$library") (BD no encontrada)"
        fi
        echo ""
    done < <(find "$pictures_dir" -maxdepth 1 -name "*.photoslibrary" -type d -print0 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        echo -e "${RED}❌ No se encontraron bibliotecas de Photos${NC}"
        return 1
    fi
}

# Función principal
main() {
    local DEST=""
    local DRY_RUN=false
    local LIST_ONLY=false
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                LIST_ONLY=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -*)
                echo -e "${RED}❌ Opción desconocida: $1${NC}"
                show_help
                exit 1
                ;;
            *)
                DEST="$1"
                shift
                ;;
        esac
    done
    
    # Si solo listar, hacerlo y salir
    if [ "$LIST_ONLY" = true ]; then
        list_photos_libraries
        exit 0
    fi
    
    # Usar destino por defecto si no se especificó
    if [ -z "$DEST" ]; then
        DEST="$DEFAULT_DEST"
        echo -e "${YELLOW}ℹ️  Usando destino por defecto: ${DEST}${NC}"
        echo -e "${YELLOW}   (Puedes especificar otro destino como argumento)${NC}"
        echo ""
    fi
    
    # Encontrar biblioteca de Photos
    echo -e "${BLUE}🔍 Buscando biblioteca de Photos...${NC}"
    PHOTOS_LIBRARY=$(find_photos_library)
    
    if [ -z "$PHOTOS_LIBRARY" ]; then
        echo -e "${RED}❌ No se pudo encontrar la biblioteca de Photos${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Biblioteca encontrada: $(basename "$PHOTOS_LIBRARY")"
    
    # Construir ruta completa a la base de datos
    DB_PATH="$PHOTOS_LIBRARY/database/$PHOTOS_DB_NAME"
    
    # Verificar que existe la base de datos
    if [ ! -f "$DB_PATH" ]; then
        echo -e "${RED}❌ No se encontró la base de datos en: $DB_PATH${NC}"
        exit 1
    fi
    
    # Obtener información de la base de datos
    DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
    DB_SIZE_BYTES=$(stat -f "%z" "$DB_PATH" 2>/dev/null || stat -c "%s" "$DB_PATH" 2>/dev/null)
    DB_MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$DB_PATH" 2>/dev/null || stat -c "%y" "$DB_PATH" 2>/dev/null | cut -d' ' -f1-2)
    
    echo -e "${GREEN}✓${NC} Base de datos encontrada:"
    echo -e "   Ruta: $DB_PATH"
    echo -e "   Tamaño: $DB_SIZE"
    echo -e "   Última modificación: $DB_MODIFIED"
    echo ""
    
    # Mostrar información de destino
    echo -e "${BLUE}📤 Destino:${NC} $DEST"
    echo ""
    
    # Construir comando rsync
    RSYNC_OPTS=(
        -avz                    # Archive, verbose, compress
        --progress              # Mostrar progreso
        --human-readable        # Tamaños legibles
        "$DB_PATH"              # Origen
        "$DEST"                 # Destino
    )
    
    if [ "$DRY_RUN" = true ]; then
        RSYNC_OPTS+=(--dry-run)
        echo -e "${YELLOW}🔍 MODO DRY-RUN (simulación)${NC}"
        echo ""
    fi
    
    # Ejecutar rsync
    echo -e "${BLUE}🚀 Iniciando copia con rsync...${NC}"
    echo ""
    
    if rsync "${RSYNC_OPTS[@]}"; then
        echo ""
        echo -e "${GREEN}✅ Copia completada exitosamente${NC}"
        echo ""
        echo -e "${GREEN}📊 Resumen:${NC}"
        echo -e "   Origen: $DB_PATH"
        echo -e "   Destino: $DEST"
        echo -e "   Tamaño: $DB_SIZE"
        
        if [ "$DRY_RUN" = false ]; then
            echo ""
            echo -e "${BLUE}💡 Para verificar en el servidor remoto:${NC}"
            echo -e "   ssh ${DEST%%:*} 'ls -lh ${DEST#*:}/$PHOTOS_DB_NAME'"
        fi
    else
        echo ""
        echo -e "${RED}❌ Error durante la copia${NC}"
        echo -e "${YELLOW}💡 Verifica:${NC}"
        echo -e "   - Que 'tower' sea accesible (ssh tower)"
        echo -e "   - Que tengas permisos de escritura en el destino"
        echo -e "   - Que la ruta de destino exista"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"
