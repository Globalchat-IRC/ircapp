#!/bin/bash

# Script para extraer stream de Mixcloud Live
# Uso: ./extract_mixcloud_stream.sh <URL_MIXCLOUD_LIVE>

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# URL por defecto
URL="${1:-https://www.mixcloud.com/live/djsonic_vlc/}"

echo -e "${GREEN}=== Extractor de Stream de Mixcloud Live ===${NC}"
echo -e "URL: ${YELLOW}$URL${NC}\n"

# Verificar dependencias
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v yt-dlp &> /dev/null && ! command -v youtube-dl &> /dev/null; then
        missing_deps+=("yt-dlp o youtube-dl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Faltan las siguientes dependencias:${NC}"
        printf '%s\n' "${missing_deps[@]}"
        echo ""
        echo "Instalar con:"
        echo "  brew install curl jq yt-dlp  # macOS"
        echo "  apt install curl jq yt-dlp   # Linux"
        exit 1
    fi
}

# Método 1: Usar yt-dlp (más moderno y actualizado)
try_ytdlp() {
    echo -e "${YELLOW}[Método 1] Intentando con yt-dlp...${NC}"
    
    if command -v yt-dlp &> /dev/null; then
        # Obtener información del stream
        echo "Obteniendo información del stream..."
        yt-dlp --list-formats "$URL" 2>&1 | tee /tmp/mixcloud_formats.txt
        
        # Intentar extraer la URL del stream
        echo -e "\n${GREEN}Extrayendo URL del stream...${NC}"
        yt-dlp -g "$URL" 2>&1 | tee /tmp/mixcloud_stream_url.txt
        
        if [ -s /tmp/mixcloud_stream_url.txt ]; then
            echo -e "${GREEN}✓ URL del stream encontrada:${NC}"
            cat /tmp/mixcloud_stream_url.txt
            return 0
        fi
    else
        echo -e "${RED}yt-dlp no está instalado${NC}"
    fi
    
    return 1
}

# Método 2: Usar youtube-dl (alternativa más antigua)
try_youtubedl() {
    echo -e "\n${YELLOW}[Método 2] Intentando con youtube-dl...${NC}"
    
    if command -v youtube-dl &> /dev/null; then
        # Actualizar youtube-dl
        echo "Actualizando youtube-dl..."
        youtube-dl -U 2>/dev/null || true
        
        # Obtener información del stream
        echo "Obteniendo información del stream..."
        youtube-dl --list-formats "$URL" 2>&1 | tee /tmp/mixcloud_formats_ydl.txt
        
        # Intentar extraer la URL del stream
        echo -e "\n${GREEN}Extrayendo URL del stream...${NC}"
        youtube-dl -g "$URL" 2>&1 | tee /tmp/mixcloud_stream_url_ydl.txt
        
        if [ -s /tmp/mixcloud_stream_url_ydl.txt ]; then
            echo -e "${GREEN}✓ URL del stream encontrada:${NC}"
            cat /tmp/mixcloud_stream_url_ydl.txt
            return 0
        fi
    else
        echo -e "${RED}youtube-dl no está instalado${NC}"
    fi
    
    return 1
}

# Método 3: Inspeccionar la página web para encontrar el stream
try_web_inspection() {
    echo -e "\n${YELLOW}[Método 3] Inspeccionando página web...${NC}"
    
    # Descargar el HTML de la página
    echo "Descargando HTML..."
    curl -s -L "$URL" -o /tmp/mixcloud_page.html
    
    # Buscar URLs de stream comunes (m3u8, mpd, etc.)
    echo -e "\n${GREEN}Buscando URLs de stream en el HTML...${NC}"
    
    # Buscar m3u8 (HLS)
    grep -oE 'https?://[^"'\''[:space:]]+\.m3u8[^"'\''[:space:]]*' /tmp/mixcloud_page.html | head -5
    
    # Buscar mpd (DASH)
    grep -oE 'https?://[^"'\''[:space:]]+\.mpd[^"'\''[:space:]]*' /tmp/mixcloud_page.html | head -5
    
    # Buscar referencias a stream o live
    echo -e "\n${GREEN}Buscando referencias a 'stream' o 'live'...${NC}"
    grep -oE '"[^"]*stream[^"]*"' /tmp/mixcloud_page.html | head -10
    
    # Buscar datos JSON embebidos
    echo -e "\n${GREEN}Buscando datos JSON embebidos...${NC}"
    grep -oP '(?<=<script type="application/json">).*?(?=</script>)' /tmp/mixcloud_page.html > /tmp/mixcloud_json.txt 2>/dev/null || true
    
    if [ -s /tmp/mixcloud_json.txt ]; then
        echo "JSON encontrado, guardado en /tmp/mixcloud_json.txt"
        # Intentar extraer URLs del JSON
        cat /tmp/mixcloud_json.txt | jq -r '.. | select(type == "string" and (contains("http") or contains("stream")))' 2>/dev/null | head -20
    fi
}

# Método 4: Usar la API de Mixcloud (si está disponible)
try_api() {
    echo -e "\n${YELLOW}[Método 4] Intentando API de Mixcloud...${NC}"
    
    # Extraer el username de la URL
    USERNAME=$(echo "$URL" | grep -oP '(?<=mixcloud.com/live/)[^/]+')
    
    if [ -n "$USERNAME" ]; then
        echo "Usuario detectado: $USERNAME"
        
        # Intentar obtener información del stream
        API_URL="https://api.mixcloud.com/${USERNAME}/live/"
        echo "Consultando API: $API_URL"
        
        curl -s "$API_URL" | jq '.' 2>/dev/null | tee /tmp/mixcloud_api.json || echo "API no disponible o sin datos"
    fi
}

# Método 5: Capturar con ffmpeg/streamlink
try_streamlink() {
    echo -e "\n${YELLOW}[Método 5] Intentando con streamlink...${NC}"
    
    if command -v streamlink &> /dev/null; then
        echo "Obteniendo streams disponibles..."
        streamlink "$URL" --stream-url best 2>&1 | tee /tmp/mixcloud_streamlink.txt
    else
        echo -e "${YELLOW}streamlink no está instalado (opcional)${NC}"
        echo "Instalar con: brew install streamlink"
    fi
}

# Función principal
main() {
    check_dependencies
    
    echo -e "${GREEN}Iniciando extracción...${NC}\n"
    
    # Intentar diferentes métodos
    try_ytdlp || true
    try_youtubedl || true
    try_web_inspection || true
    try_api || true
    try_streamlink || true
    
    echo -e "\n${GREEN}=== Resumen ===${NC}"
    echo "Los resultados se han guardado en /tmp/mixcloud_*"
    echo ""
    echo "Archivos generados:"
    ls -lh /tmp/mixcloud_* 2>/dev/null || echo "No se generaron archivos"
    
    echo -e "\n${YELLOW}Nota:${NC} Mixcloud protege sus streams en vivo."
    echo "Si ningún método funcionó, considera:"
    echo "  1. Usar VLC para capturar el stream manualmente (Media > Open Network Stream)"
    echo "  2. Usar extensiones de navegador para capturar el stream"
    echo "  3. Grabar el audio del sistema con herramientas como BlackHole (macOS)"
    echo "  4. Esperar a que la emisión se guarde y descargarla después"
}

# Ejecutar
main
