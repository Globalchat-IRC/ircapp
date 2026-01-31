#!/bin/bash
# Script para extraer el stream de Mixcloud Live
# Uso: ./mixcloud_stream_extractor.sh djsonic_vlc

USERNAME="${1:-djsonic_vlc}"
URL="https://www.mixcloud.com/live/${USERNAME}/"

# Obtener la URL del stream
STREAM_URL=$(curl -s "$URL" | grep -o 'https://[^"]*\.m3u8' | head -1)

# Generar respuesta JSON
if [ -n "$STREAM_URL" ]; then
    echo "{\"success\":true,\"stream_url\":\"$STREAM_URL\",\"username\":\"$USERNAME\",\"is_live\":true,\"timestamp\":$(date +%s),\"format\":\"HLS\",\"type\":\"m3u8\"}"
else
    echo "{\"success\":false,\"is_live\":false,\"username\":\"$USERNAME\",\"message\":\"No hay emisión en directo actualmente\",\"timestamp\":$(date +%s)}"
fi
