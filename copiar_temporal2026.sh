#!/bin/bash

# Script para copiar temporal2026.photoslibrary a TOSHIBA EXT 1

SOURCE="/Volumes/Datos/temporal2026.photoslibrary/"
DEST="/Volumes/TOSHIBA EXT 1/catalog_photos/temporal2026.photoslibrary/"

echo "═══════════════════════════════════════════════════════════════"
echo "  COPIANDO TEMPORAL2026.PHOTOSLIBRARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Origen: $SOURCE"
echo "Destino: $DEST"
echo ""

# Verificar origen
if [ ! -d "$SOURCE" ]; then
    echo "ERROR: No se encuentra $SOURCE"
    exit 1
fi

# Verificar que el destino existe o crearlo
DEST_PARENT="/Volumes/TOSHIBA EXT 1/catalog_photos"
if [ ! -d "$DEST_PARENT" ]; then
    echo "Creando directorio destino: $DEST_PARENT"
    mkdir -p "$DEST_PARENT"
    if [ $? -ne 0 ]; then
        echo "ERROR: No se puede crear el directorio destino"
        exit 1
    fi
fi

# Verificar espacio disponible en destino (sin calcular tamaño origen para ahorrar tiempo)
echo "Verificando espacio disponible en destino..."
DEST_AVAILABLE=$(df -k "$DEST_PARENT" | tail -1 | awk '{print $4}')

if [ -n "$DEST_AVAILABLE" ]; then
    DEST_AVAILABLE_GB=$((DEST_AVAILABLE / 1024 / 1024))
    echo "Espacio disponible destino: ~${DEST_AVAILABLE_GB} GB"
fi
echo ""

# Iniciar transferencia
echo "═══════════════════════════════════════════════════════════════"
echo "  INICIANDO TRANSFERENCIA"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Ejecutar rsync con salida visible
rsync -avz \
    --human-readable \
    --timeout=900 \
    --partial \
    --partial-dir=.rsync-partial \
    --progress \
    "$SOURCE" \
    "$DEST" 2>&1

EXIT_CODE=$?

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ $EXIT_CODE -eq 0 ]; then
    echo "  ✅ TRANSFERENCIA COMPLETADA"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Verificando tamaño en destino:"
    du -sh "$DEST" 2>/dev/null || echo "No encontrado"
else
    echo "  ⚠️  TRANSFERENCIA INTERRUMPIDA (código: $EXIT_CODE)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Puedes reanudar ejecutando este script de nuevo."
fi
