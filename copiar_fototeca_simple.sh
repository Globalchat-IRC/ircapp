#!/bin/bash

# Script simple para copiar Fototeca con salida visible

SOURCE="/Volumes/usbshare1/Fototeca.photoslibrary/"
DEST="root@192.168.1.42:/mnt/user/backups/photos_db/Fototeca.photoslibrary/"
SSH_PORT="62500"

echo "═══════════════════════════════════════════════════════════════"
echo "  COPIANDO FOTOTECA A TOWER"
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

# Verificar conexión
echo "Verificando conexión..."
if ! ssh -p $SSH_PORT root@192.168.1.42 "echo OK" >/dev/null 2>&1; then
    echo "ERROR: No se puede conectar a tower"
    exit 1
fi
echo "✓ Conexión OK"
echo ""

# Omitir cálculo de tamaño (puede tardar mucho en bibliotecas grandes)
echo "Iniciando transferencia (el tamaño se mostrará durante la copia)..."
echo ""

# Ejecutar rsync con salida visible por archivo
echo "═══════════════════════════════════════════════════════════════"
echo "  INICIANDO TRANSFERENCIA"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "Ejecutando rsync (verás cada archivo copiándose)..."
echo ""

# Usar --info para mostrar cada archivo y progreso
# stdbuf -oL fuerza salida sin buffer (sin buffering de línea)
stdbuf -oL -eL rsync -avz \
    --info=name,progress2 \
    --human-readable \
    --timeout=900 \
    --partial \
    --partial-dir=.rsync-partial \
    --bwlimit=30000 \
    -e "ssh -p $SSH_PORT -o ServerAliveInterval=10 -o ServerAliveCountMax=30 -o TCPKeepAlive=yes -o Compression=yes -o ConnectTimeout=30" \
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
    ssh -p $SSH_PORT root@192.168.1.42 "du -sh /mnt/user/backups/photos_db/Fototeca.photoslibrary 2>/dev/null || echo 'No encontrado'"
else
    echo "  ⚠️  TRANSFERENCIA INTERRUMPIDA (código: $EXIT_CODE)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Puedes reanudar ejecutando este script de nuevo."
fi
