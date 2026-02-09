#!/bin/bash

# Script para crear un backup en tar.gz del directorio /home/globalchat

# Directorio a comprimir
SOURCE_DIR="/home/globalchat"

# Nombre del archivo de salida con timestamp
OUTPUT_FILE="globalchat_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

# Crear el archivo tar.gz
tar -czf "$OUTPUT_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

# Verificar que se creó correctamente
if [ $? -eq 0 ]; then
    echo "✓ Backup creado exitosamente: $OUTPUT_FILE"
    echo "Tamaño del archivo: $(du -h "$OUTPUT_FILE" | cut -f1)"
else
    echo "✗ Error al crear el backup"
    exit 1
fi
