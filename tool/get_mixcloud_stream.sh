#!/usr/bin/env bash
# Script para extraer la URL del stream de Mixcloud
# Uso: ./get_mixcloud_stream.sh https://www.mixcloud.com/djsonic_vlc/

set -euo pipefail

MIXCLOUD_URL="${1:-https://www.mixcloud.com/djsonic_vlc/}"

echo "🔍 Extrayendo URL del stream de Mixcloud..."
echo "📡 URL: $MIXCLOUD_URL"
echo ""

# Verificar si yt-dlp está instalado
if ! command -v yt-dlp &> /dev/null; then
  echo "❌ yt-dlp no está instalado"
  echo "💡 Instalar con: brew install yt-dlp (macOS) o pip install yt-dlp"
  exit 1
fi

# Extraer URL del stream usando yt-dlp
echo "📥 Extrayendo URL del stream con yt-dlp..."
STREAM_URL=$(yt-dlp -g --format "bestaudio" "$MIXCLOUD_URL" 2>&1 | head -1 || echo "")

if [ -z "$STREAM_URL" ]; then
  echo "❌ No se pudo extraer la URL del stream"
  exit 1
fi

echo ""
echo "✅ URL de stream encontrada:"
echo "$STREAM_URL"
echo ""
echo "⚠️  NOTA: Esta URL es DASH (manifest.mpd), no M3U8 (HLS)"
echo "⚠️  Las URLs de Mixcloud pueden tener tokens que expiran"
echo "⚠️  Flutter web puede no soportar DASH directamente"
echo ""
echo "💡 Recomendaciones:"
echo "1. Contactar al propietario para obtener una URL directa del stream (Icecast/Shoutcast)"
echo "2. Usar un servicio proxy que convierta DASH a un formato compatible"
echo "3. Verificar si hay una URL M3U8 disponible en la página de Mixcloud"
echo ""
echo "📋 Para usar esta URL en el código, actualiza:"
echo "   lib/providers/radio_provider.dart"
echo "   source: '$STREAM_URL'"
