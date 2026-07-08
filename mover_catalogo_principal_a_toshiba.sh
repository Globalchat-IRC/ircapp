#!/bin/bash
# Mueve el catálogo principal de Fotos del Mac al Toshiba EXT2.
set -euo pipefail

SOURCE="$HOME/Pictures/catalogo2026.photoslibrary"
DEST_NAME="CATALOGO-PRINCIPAL-FOTOS.photoslibrary"
LOG="/tmp/mover_catalogo_principal_$(date +%Y%m%d_%H%M%S).log"
TOSHIBA=""

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

find_toshiba() {
  local vol
  for vol in "/Volumes/TOSHIBA EXT2" "/Volumes/TOSHIBA EXT"; do
    if [[ -d "$vol" ]] && mount | grep -q " on ${vol} "; then
      echo "$vol"
      return 0
    fi
  done
  # ponytail: cualquier volumen montado que empiece por TOSHIBA
  for vol in /Volumes/TOSHIBA*; do
    [[ -d "$vol" ]] && mount | grep -q " on ${vol} " && { echo "$vol"; return 0; }
  done
  return 1
}

wait_toshiba() {
  log "Esperando disco Toshiba USB (conecta y enciende TOSHIBA EXT2)..."
  while ! TOSHIBA=$(find_toshiba); do sleep 3; done
  log "Toshiba detectado: $TOSHIBA"
}

quit_photos() {
  osascript -e 'tell application "Photos" to quit' 2>/dev/null || true
  sleep 2
}

write_labels() {
  local dest="$1"
  cat > "$TOSHIBA/LEEME-CATALOGO-PRINCIPAL-FOTOS.txt" <<EOF
═══════════════════════════════════════════════════════════════
  CATÁLOGO PRINCIPAL DE FOTOS (biblioteca maestra)
═══════════════════════════════════════════════════════════════

Carpeta:  $DEST_NAME
Movido desde Mac: $(date '+%Y-%m-%d %H:%M')
Origen:   ~/Pictures/catalogo2026.photoslibrary

Esta es la biblioteca PRINCIPAL de fotos de la familia.
No borrar. Las demás bibliotecas en este disco son copias o backups.

Para abrir en Fotos (Mac):
  Fotos → Archivo → Abrir → selecciona "$DEST_NAME"

O doble clic en la carpeta .photoslibrary con Fotos cerrado.
═══════════════════════════════════════════════════════════════
EOF

  cat > "$HOME/Pictures/LEEME-CATALOGO-PRINCIPAL-FOTOS.txt" <<EOF
El catálogo principal de fotos ya NO está en este Mac.

Ubicación actual:
  $DEST

Conecta TOSHIBA EXT2 y abre:
  $DEST_NAME

Ver también: LEEME-CATALOGO-PRINCIPAL-FOTOS.txt en la raíz del Toshiba.
EOF
}

main() {
  [[ -d "$SOURCE" ]] || { log "ERROR: No existe $SOURCE"; exit 1; }

  log "=== Mover catálogo principal → Toshiba ==="
  quit_photos
  wait_toshiba
  local DEST="$TOSHIBA/$DEST_NAME"

  local free_kb; free_kb=$(df -k "$TOSHIBA" | tail -1 | awk '{print $4}')
  local need_kb; need_kb=$(du -sk "$SOURCE" | awk '{print $1}')
  if (( free_kb < need_kb + 1048576 )); then
    log "ERROR: Falta espacio en Toshiba (necesario ~$((need_kb/1024/1024)) GB)"
    exit 1
  fi

  log "Copiando → $DEST (rsync, reanudable)..."
  rsync -a --info=progress2 \
    --partial --partial-dir=.rsync-partial \
    "$SOURCE/" "$DEST/" 2>&1 | tee -a "$LOG"

  local src_kb dst_kb
  src_kb=$(du -sk "$SOURCE" | awk '{print $1}')
  dst_kb=$(du -sk "$DEST" | awk '{print $1}')
  # ponytail: tolerancia 1% por metadatos HFS+
  if (( dst_kb < src_kb * 99 / 100 )); then
    log "ERROR: Tamaño destino ($dst_kb KB) < origen ($src_kb KB)"
    exit 1
  fi

  write_labels "$DEST"
  log "Etiquetas creadas (LEEME en Toshiba y ~/Pictures)"

  log "Eliminando copia del Mac..."
  rm -rf "$SOURCE"

  log "✅ Completado. Catálogo principal en: $DEST"
  log "Log: $LOG"
}

main "$@"
