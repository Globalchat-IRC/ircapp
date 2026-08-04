#!/bin/bash
# Script para extraer el stream de Mixcloud Live
# Uso: ./mixcloud_stream_extractor.sh djsonic_vlc
# Extrae el stream HLS desde: https://www.mixcloud.com/live/USERNAME/

USERNAME="${1:-djsonic_vlc}"
URL="https://www.mixcloud.com/live/${USERNAME}/"

# Descargar el HTML de la página de Mixcloud Live con User-Agent adecuado
# Usar timeout para evitar que se cuelgue
HTML=$(curl -s -L --max-time 10 --connect-timeout 5 "$URL" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
    -H "Accept-Language: en-US,en;q=0.5")

# Verificar que se obtuvo HTML válido (no una página de error)
if [ -z "$HTML" ] || echo "$HTML" | grep -qiE "(error|404|not found|access denied)"; then
    echo "{\"success\":false,\"is_live\":false,\"username\":\"$USERNAME\",\"message\":\"No se pudo acceder a la página de Mixcloud Live\",\"timestamp\":$(date +%s)}"
    exit 0
fi

# Extraer el JSON del script app-context que contiene el estado del stream
# Usar sed en lugar de grep -P para compatibilidad con BSD grep (macOS)
APP_CONTEXT=$(echo "$HTML" | sed -n 's/.*<script id="app-context" type="text\/x-mixcloud">\([^<]*\).*/\1/p' | head -1)

# Verificar si hay streaming activo en el JSON
IS_STREAMING=$(echo "$APP_CONTEXT" | grep -oE '"isStreaming":\s*(true|false)' | grep -oE '(true|false)')

# NOTA: NO salir temprano aunque isStreaming sea false, porque Mixcloud carga el stream
# dinámicamente con JavaScript. El HTML estático puede mostrar isStreaming:false incluso
# cuando está en vivo. Siempre intentar buscar el stream URL.

# Intentar obtener la URL del stream de varias formas (incluso si isStreaming es false)
# 1. Buscar en el HTML directamente con regex más flexible
STREAM_URL=$(echo "$HTML" | grep -oE 'https://live-[a-z0-9-]+\.mixcloud\.com/[^"'\''[:space:]]+\.m3u8[^"'\''[:space:]]*' | head -1)

# 2. Si no se encuentra, buscar en scripts JavaScript (el stream puede estar en variables JS)
if [ -z "$STREAM_URL" ]; then
    STREAM_URL=$(echo "$HTML" | grep -oE 'https://live-[a-z0-9-]+\.mixcloud\.com/[^"'\''[:space:]]+\.m3u8' | head -1)
fi

# 3. Buscar en el JSON embebido o en variables JavaScript
if [ -z "$STREAM_URL" ]; then
    STREAM_URL=$(echo "$HTML" | grep -oE 'https://[^"'\''[:space:]]+\.m3u8[^"'\''[:space:]]*' | grep -iE 'live-.*mixcloud|mixcloud.*live' | head -1)
fi

# 3. Intentar obtener desde el widget de live de Mixcloud
if [ -z "$STREAM_URL" ]; then
    # Extraer el dominio del widget de live desde app-context
    LIVE_WIDGET_DOMAIN=$(echo "$APP_CONTEXT" | grep -oE '"live-widget":"[^"]+"' | grep -oE 'https://[^"]+')
    
    if [ -n "$LIVE_WIDGET_DOMAIN" ]; then
        # Intentar obtener información del widget
        WIDGET_RESPONSE=$(curl -s -L --max-time 10 "${LIVE_WIDGET_DOMAIN}/live/${USERNAME}/" \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" 2>/dev/null)
        
        if [ -n "$WIDGET_RESPONSE" ]; then
            STREAM_URL=$(echo "$WIDGET_RESPONSE" | grep -oE 'https://live-[^"'\''[:space:]]+\.mixcloud\.com/[^"'\''[:space:]]+\.m3u8[^"'\''[:space:]]*' | head -1)
        fi
    fi
fi

# 4. Intentar usar yt-dlp si está disponible (método más confiable)
if [ -z "$STREAM_URL" ] && command -v yt-dlp &> /dev/null; then
    # Redirigir stderr a /dev/null para evitar mensajes que interfieren con el JSON
    YTDLP_STREAM=$(yt-dlp -g "$URL" 2>/dev/null | grep -E '\.m3u8' | head -1)
    if [ -n "$YTDLP_STREAM" ]; then
        STREAM_URL="$YTDLP_STREAM"
    fi
fi

# 5. Buscar en cualquier m3u8 (último recurso)
if [ -z "$STREAM_URL" ]; then
    STREAM_URL=$(echo "$HTML" | grep -oE 'https://[^"'\''[:space:]]+\.m3u8[^"'\''[:space:]]*' | head -1)
fi

# Validar que la URL sea de Mixcloud Live y contenga .m3u8
if [ -n "$STREAM_URL" ] && echo "$STREAM_URL" | grep -qE '^https://live-[^/]+\.mixcloud\.com/.*\.m3u8'; then
    # Escapar la URL para JSON (escapar comillas y barras)
    ESCAPED_URL=$(echo "$STREAM_URL" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    # Generar respuesta JSON exitosa
    echo "{\"success\":true,\"stream_url\":\"$ESCAPED_URL\",\"username\":\"$USERNAME\",\"is_live\":true,\"timestamp\":$(date +%s),\"format\":\"HLS\",\"type\":\"m3u8\"}"
else
    # No se encontró la URL del stream. Intentar una última vez con una búsqueda más amplia
    # Buscar cualquier URL que contenga "live" y ".m3u8" en todo el HTML
    FINAL_STREAM_URL=$(echo "$HTML" | grep -iE 'live.*m3u8|m3u8.*live' | grep -oE 'https://[^"'\''[:space:]]+\.m3u8[^"'\''[:space:]]*' | head -1)
    
    if [ -n "$FINAL_STREAM_URL" ] && echo "$FINAL_STREAM_URL" | grep -qE 'https://.*\.m3u8'; then
        # Encontramos una URL de stream, validarla
        ESCAPED_URL=$(echo "$FINAL_STREAM_URL" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        echo "{\"success\":true,\"stream_url\":\"$ESCAPED_URL\",\"username\":\"$USERNAME\",\"is_live\":true,\"timestamp\":$(date +%s),\"format\":\"HLS\",\"type\":\"m3u8\"}"
    elif [ "$IS_STREAMING" = "true" ]; then
        # isStreaming es true pero no encontramos la URL
        echo "{\"success\":false,\"is_live\":true,\"username\":\"$USERNAME\",\"message\":\"Stream en vivo detectado pero la URL del stream se carga dinámicamente con JavaScript. Se requiere un navegador headless para extraerla.\",\"timestamp\":$(date +%s)}"
    else
        # No está en vivo según el HTML estático
        echo "{\"success\":false,\"is_live\":false,\"username\":\"$USERNAME\",\"message\":\"No hay emisión en directo actualmente (nota: Mixcloud carga el stream dinámicamente, puede que necesite un navegador headless para detectarlo)\",\"timestamp\":$(date +%s)}"
    fi
fi
