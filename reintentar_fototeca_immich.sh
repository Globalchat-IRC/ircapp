#!/bin/bash
set -euo pipefail

SRC="/Volumes/TOSHIBA EXT2/Fototeca-plano"
MOVED="/Volumes/TOSHIBA EXT2/Fototeca-subido"
LOG="/tmp/immich_fototeca_retry.log"
SERVER="${IMMICH_SERVER:-https://naveiragarcia.live}"
API_KEY="${IMMICH_API_KEY:?Set IMMICH_API_KEY}"

n=$(find "$SRC" -maxdepth 1 -type f | wc -l | tr -d ' ')
[[ "$n" -gt 0 ]] || { echo "Nada que reintentar."; exit 0; }

mkdir -p "$MOVED"
echo "=== Reintento $n archivos $(date) ===" | tee "$LOG"

immich-go upload from-folder \
  --server="$SERVER" \
  --api-key="$API_KEY" \
  --log-file="$LOG" \
  --on-errors continue \
  --ignore-sidecar-files \
  --exclude-extensions .aae \
  --no-ui \
  "$SRC" || true

echo "=== Post-proceso $(date) ===" | tee -a "$LOG"
python3 /Users/fnaveira/Documents/mobile/irc_app/postproceso_fototeca_immich.py "$SRC" "$MOVED" "$LOG"
