#!/bin/bash

# Script para convertir M4A a MP3 con interfaz gráfica para Mac
# Autor: Convertidor M4A a MP3
# Fecha: 2026-01-31

# Colores para la terminal
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar banner
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║        🎵  CONVERTIDOR M4A → MP3 para Mac  🎵         ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Verificar si ffmpeg está instalado
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        osascript -e 'display dialog "FFmpeg no está instalado.\n\nPara instalarlo, ejecuta en Terminal:\nbrew install ffmpeg\n\n¿Quieres que abra las instrucciones?" buttons {"Cancelar", "Ver instrucciones"} default button "Ver instrucciones" with icon caution with title "FFmpeg no encontrado"' &> /dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}FFmpeg no está instalado. Necesitas instalarlo primero.${NC}"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "${GREEN}Opción 1: Instalar con Homebrew (recomendado)${NC}"
            echo "  1. Si no tienes Homebrew, instálalo desde: https://brew.sh"
            echo "  2. Luego ejecuta: ${BLUE}brew install ffmpeg${NC}"
            echo ""
            echo -e "${GREEN}Opción 2: Descargar binario${NC}"
            echo "  Descarga desde: https://ffmpeg.org/download.html"
            echo ""
            echo -e "${YELLOW}Después de instalar, vuelve a ejecutar este script.${NC}"
            echo ""
        fi
        exit 1
    fi
}

# Función para convertir archivo individual
convert_file() {
    local input_file="$1"
    local output_file="${input_file%.m4a}.mp3"
    
    echo -e "${BLUE}Convirtiendo: $(basename "$input_file")${NC}"
    
    # Convertir con calidad alta (320kbps)
    if ffmpeg -i "$input_file" -codec:a libmp3lame -b:a 320k "$output_file" -y 2>&1 | grep -i "error"; then
        echo -e "${RED}✗ Error al convertir: $(basename "$input_file")${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Convertido exitosamente: $(basename "$output_file")${NC}"
        return 0
    fi
}

# Función para seleccionar archivos con interfaz gráfica
select_files_gui() {
    osascript <<EOF
set fileList to choose file with prompt "Selecciona archivos M4A para convertir:" of type {"public.audio"} with multiple selections allowed
set output to ""
repeat with aFile in fileList
    set output to output & POSIX path of aFile & "\n"
end repeat
return output
EOF
}

# Función para seleccionar carpeta con interfaz gráfica
select_folder_gui() {
    osascript <<EOF
set folderPath to choose folder with prompt "Selecciona una carpeta con archivos M4A:"
return POSIX path of folderPath
EOF
}

# Menú principal con interfaz gráfica
show_menu_gui() {
    local choice=$(osascript <<EOF
set dialogResult to display dialog "¿Qué deseas hacer?" buttons {"Salir", "Convertir carpeta", "Convertir archivos"} default button "Convertir archivos" with title "Convertidor M4A → MP3" with icon note
button returned of dialogResult
EOF
)
    echo "$choice"
}

# Función principal
main() {
    show_banner
    check_ffmpeg
    
    # Mostrar menú
    choice=$(show_menu_gui)
    
    case "$choice" in
        "Convertir archivos")
            echo -e "${GREEN}Selecciona los archivos M4A a convertir...${NC}"
            files=$(select_files_gui)
            
            if [ -z "$files" ]; then
                osascript -e 'display dialog "No se seleccionaron archivos." buttons {"OK"} default button "OK" with icon stop'
                exit 0
            fi
            
            total=0
            success=0
            
            while IFS= read -r file; do
                if [ -n "$file" ] && [ -f "$file" ]; then
                    ((total++))
                    if convert_file "$file"; then
                        ((success++))
                    fi
                fi
            done <<< "$files"
            
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}Conversión completada: $success de $total archivos${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            
            osascript -e "display dialog \"Conversión completada:\n\n✓ $success de $total archivos convertidos exitosamente\" buttons {\"OK\"} default button \"OK\" with icon note with title \"Conversión completada\""
            ;;
            
        "Convertir carpeta")
            echo -e "${GREEN}Selecciona la carpeta con archivos M4A...${NC}"
            folder=$(select_folder_gui)
            
            if [ -z "$folder" ]; then
                osascript -e 'display dialog "No se seleccionó ninguna carpeta." buttons {"OK"} default button "OK" with icon stop'
                exit 0
            fi
            
            total=0
            success=0
            
            # Buscar todos los archivos M4A en la carpeta
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    ((total++))
                    if convert_file "$file"; then
                        ((success++))
                    fi
                fi
            done < <(find "$folder" -type f -name "*.m4a" -o -name "*.M4A")
            
            if [ $total -eq 0 ]; then
                echo -e "${YELLOW}No se encontraron archivos M4A en la carpeta seleccionada.${NC}"
                osascript -e 'display dialog "No se encontraron archivos M4A en la carpeta seleccionada." buttons {"OK"} default button "OK" with icon caution'
            else
                echo ""
                echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${GREEN}Conversión completada: $success de $total archivos${NC}"
                echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                
                osascript -e "display dialog \"Conversión completada:\n\n✓ $success de $total archivos convertidos exitosamente\" buttons {\"OK\"} default button \"OK\" with icon note with title \"Conversión completada\""
            fi
            ;;
            
        "Salir"|*)
            echo -e "${YELLOW}Saliendo...${NC}"
            exit 0
            ;;
    esac
}

# Ejecutar script
main
