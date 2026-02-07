#!/bin/bash
# Script para descargar y añadir el emoji del pato

TARGET_DIR="assets/emoji_animated_noto"
TARGET_FILE="$TARGET_DIR/pato_antipatos.gif"
TEMP_FILE="/tmp/pato_temp.gif"

mkdir -p "$TARGET_DIR"

echo "🦆 Buscando imagen de pato pixelado..."

# Intentar descargar desde diferentes fuentes
URLS=(
    "https://emoji.gg/assets/emoji/duck.gif"
    "https://cdn.discordapp.com/emojis/duck.gif"
    "https://raw.githubusercontent.com/twitter/twemoji/master/assets/72x72/1f986.png"
)

for url in "${URLS[@]}"; do
    echo "Intentando: $url"
    if curl -fsSL "$url" -o "$TEMP_FILE" 2>/dev/null; then
        if [ -s "$TEMP_FILE" ]; then
            # Si es PNG, intentar convertir a GIF
            if file "$TEMP_FILE" | grep -q "PNG"; then
                if command -v convert &> /dev/null; then
                    convert "$TEMP_FILE" "$TARGET_FILE"
                    echo "✅ Imagen descargada y convertida a GIF: $TARGET_FILE"
                else
                    # Copiar PNG como GIF (funcionará si el código lo soporta)
                    cp "$TEMP_FILE" "$TARGET_FILE"
                    echo "✅ Imagen descargada: $TARGET_FILE"
                fi
            else
                cp "$TEMP_FILE" "$TARGET_FILE"
                echo "✅ Imagen descargada: $TARGET_FILE"
            fi
            rm -f "$TEMP_FILE"
            exit 0
        fi
    fi
done

echo "❌ No se pudo descargar automáticamente."
echo ""
echo "Por favor, descarga manualmente una imagen de pato pixelado y:"
echo "  1. Guárdala como: $TARGET_FILE"
echo "  2. O usa: ./tool/add_pato_emoji.sh <ruta_a_imagen>"
