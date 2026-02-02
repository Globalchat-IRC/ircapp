#!/bin/bash

# Script para crear un icono para la aplicación

# Crear un icono temporal usando sips (herramienta de macOS)
# Como no tenemos una imagen, crearemos un icono simple

ICON_DIR="/Users/fnaveira/mobile/irc_app/instalador_convertidor/Convertidor M4A a MP3.app/Contents/Resources"

# Crear un icono usando iconutil (si tenemos las imágenes)
# Por ahora, copiaremos el icono del sistema de música

# Buscar un icono de audio del sistema
if [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericAudioIcon.icns" ]; then
    cp "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericAudioIcon.icns" "$ICON_DIR/AppIcon.icns"
    echo "✓ Icono copiado exitosamente"
elif [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SoundFileIcon.icns" ]; then
    cp "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SoundFileIcon.icns" "$ICON_DIR/AppIcon.icns"
    echo "✓ Icono copiado exitosamente"
else
    echo "⚠ No se pudo encontrar un icono del sistema, la app usará el icono por defecto"
fi
