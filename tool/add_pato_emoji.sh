#!/bin/bash
# Script para añadir el emoji del pato

SOURCE_IMAGE="$1"
TARGET_DIR="assets/emoji_animated_noto"
TARGET_FILE="$TARGET_DIR/pato_antipatos.gif"

if [ -z "$SOURCE_IMAGE" ]; then
    echo "Uso: $0 <ruta_a_imagen_del_pato>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 ~/Downloads/pato.png"
    echo ""
    echo "El script convertirá la imagen a GIF si es necesario."
    exit 1
fi

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: No se encuentra el archivo: $SOURCE_IMAGE"
    exit 1
fi

mkdir -p "$TARGET_DIR"

# Si es PNG, convertir a GIF
if [[ "$SOURCE_IMAGE" == *.png ]] || [[ "$SOURCE_IMAGE" == *.PNG ]]; then
    echo "📦 Convirtiendo PNG a GIF..."
    if command -v convert &> /dev/null; then
        convert "$SOURCE_IMAGE" "$TARGET_FILE"
        echo "✅ Imagen convertida y guardada en: $TARGET_FILE"
    else
        echo "⚠️  ImageMagick no está instalado. Copiando como PNG..."
        cp "$SOURCE_IMAGE" "${TARGET_FILE%.gif}.png"
        echo "✅ Imagen copiada. Necesitarás convertirla manualmente a GIF."
    fi
else
    cp "$SOURCE_IMAGE" "$TARGET_FILE"
    echo "✅ Imagen copiada a: $TARGET_FILE"
fi

echo ""
echo "🎉 ¡Emoji del pato añadido!"
echo "   Usa :pato: en el chat para verlo"
