#!/bin/bash

# Script para copiar temporal2026.photoslibrary archivo por archivo

SOURCE="/Volumes/Datos/temporal2026.photoslibrary"
DEST="/Volumes/TOSHIBA EXT 1/catalog_photos/temporal2026.photoslibrary"

echo "═══════════════════════════════════════════════════════════════"
echo "  COPIANDO TEMPORAL2026.PHOTOSLIBRARY (ARCHIVO POR ARCHIVO)"
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

# Crear directorio destino
mkdir -p "$DEST"
if [ $? -ne 0 ]; then
    echo "ERROR: No se puede crear el directorio destino"
    exit 1
fi

echo "Iniciando copia archivo por archivo..."
echo ""

# Contador
TOTAL=0
COPIADOS=0

# Copiar archivo por archivo
find "$SOURCE" -type f | while read -r archivo; do
    TOTAL=$((TOTAL + 1))
    
    # Obtener ruta relativa
    rel_path="${archivo#$SOURCE/}"
    dest_file="$DEST/$rel_path"
    dest_dir=$(dirname "$dest_file")
    
    # Crear directorio si no existe
    mkdir -p "$dest_dir"
    
    # Copiar archivo
    if cp "$archivo" "$dest_file" 2>/dev/null; then
        COPIADOS=$((COPIADOS + 1))
        if [ $((COPIADOS % 100)) -eq 0 ]; then
            echo "[$COPIADOS archivos] Copiando: $(basename "$archivo")"
        fi
    else
        echo "ERROR copiando: $archivo"
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ COPIA COMPLETADA"
echo "═══════════════════════════════════════════════════════════════"
echo "Archivos copiados: $COPIADOS"
