#!/bin/bash
# Sube Fototeca-plano a Immich; mueve subidas, borra duplicadas en servidor.
set -euo pipefail

SRC="/Volumes/TOSHIBA EXT2/Fototeca-plano"
MOVED="/Volumes/TOSHIBA EXT2/Fototeca-subido"
LOG="/tmp/immich_fototeca_upload.log"
SERVER="${IMMICH_SERVER:-https://naveiragarcia.live}"
API_KEY="${IMMICH_API_KEY:?Set IMMICH_API_KEY}"

[[ -d "$SRC" ]] || { echo "No existe $SRC"; exit 1; }
mkdir -p "$MOVED"

echo "=== Subida $(date) ===" | tee -a "$LOG"
immich-go upload from-folder \
  --server="$SERVER" \
  --api-key="$API_KEY" \
  --log-file="$LOG" \
  --on-errors continue \
  --ignore-sidecar-files \
  --exclude-extensions .aae \
  --no-ui \
  "$SRC"

echo "=== Post-proceso $(date) ===" | tee -a "$LOG"
python3 - "$SRC" "$MOVED" "$LOG" <<'PY'
import re, sys
from pathlib import Path

src, moved, log_path = map(Path, sys.argv[1:4])
uploaded, duplicates = set(), set()

for line in log_path.read_text(errors="replace").splitlines():
    if "uploaded successfully" in line or "server asset upgraded" in line:
        kind = "up"
    elif "server has duplicate" in line or "Already on server" in line:
        kind = "dup"
    else:
        continue
    m = re.search(r"file=([^\s]+)", line)
    if not m:
        continue
    name = m.group(1).split(":")[-1]
    (uploaded if kind == "up" else duplicates).add(name)

n_mv = n_rm = 0
for name in uploaded:
    f = src / name
    if not f.is_file():
        continue
    sc = src / f"{f.stem}.aae"
    f.rename(moved / name)
    if sc.is_file():
        sc.rename(moved / sc.name)
    n_mv += 1

for name in duplicates:
    f = src / name
    sc = src / f"{Path(name).stem}.aae"
    if f.is_file():
        f.unlink()
        n_rm += 1
    if sc.is_file():
        sc.unlink()

left = sum(1 for _ in src.iterdir() if _.is_file())
print(f"Movidas (nuevas): {n_mv} -> {moved}")
print(f"Borradas (duplicadas en servidor): {n_rm}")
print(f"Quedan en origen (errores/no procesadas): {left}")
PY
