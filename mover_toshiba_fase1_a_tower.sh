#!/bin/bash
# Mueve duplicados/zips del Toshiba EXT2 a Tower/backups (SMB).
# ponytail: empaqueta .photoslibrary en .tar para evitar errores de nombres largos en SMB.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

TOSHIBA="/Volumes/TOSHIBA EXT2"
SMB_URL="${TOWER_SMB_URL:-smb://Tower.local/backups}"
MOUNT="${TOWER_MOUNT:-$HOME/mnt/tower-backups}"
DEST_SUBDIR="${TOWER_DEST_SUBDIR:-toshiba-fase1-$(date +%Y%m%d)}"
DEST="$MOUNT/$DEST_SUBDIR"
LOG="/tmp/mover_toshiba_tower_$(date +%Y%m%d_%H%M%S).log"

# Origen → nombre corto en destino (evita rutas largas en SMB)
declare -a JOBS=(
  "file|${TOSHIBA}/zip/videos.tar.gz|videos.tar.gz"
  "file|${TOSHIBA}/zip/califfornia.zip|califfornia.zip"
  "file|${TOSHIBA}/zip/Boda Carol & Juan.zip|Boda-Carol-Juan.zip"
  "file|${TOSHIBA}/IMPORTAR-FOTOS/Compartido con Moni y Fran.zip|Compartido-Moni-Fran.zip"
  "tar|${TOSHIBA}/catalogos/Catalogo-1.photoslibrary|Catalogo-1.photoslibrary.tar"
)

log() { echo -e "$*" | tee -a "$LOG"; }

fmt_bytes() {
  local b=$1
  if (( b >= 1073741824 )); then
    echo "$(awk -v b="$b" 'BEGIN {printf "%.1f GB", b/1073741824}')"
  elif (( b >= 1048576 )); then
    echo "$(awk -v b="$b" 'BEGIN {printf "%.1f MB", b/1048576}')"
  else
    echo "${b} B"
  fi
}

need_bytes() {
  local path="$1"
  if [[ -f "$path" ]]; then
    stat -f%z "$path"
  else
    du -sk "$path" | awk '{print $1 * 1024}'
  fi
}

ensure_mount() {
  if mount | grep -q " on ${MOUNT} "; then
    log "${GREEN}✓${NC} SMB ya montado en ${CYAN}${MOUNT}${NC}"
    return 0
  fi

  mkdir -p "$MOUNT"
  log "${BLUE}Montando ${CYAN}${SMB_URL}${NC} → ${CYAN}${MOUNT}${NC}"

  if [[ -n "${TOWER_SMB_USER:-}" ]]; then
    mount_smbfs "//${TOWER_SMB_USER}${TOWER_SMB_PASS:+:${TOWER_SMB_PASS}}@Tower.local/backups" "$MOUNT"
  else
    # Finder/keychain; si falla: export TOWER_SMB_USER=... TOWER_SMB_PASS=...
    if ! mount_smbfs "//guest@Tower.local/backups" "$MOUNT" 2>/dev/null; then
      open "$SMB_URL" || true
      log "${YELLOW}Abre Finder, monta backups en Tower e indica:${NC}"
      log "  ${CYAN}export TOWER_MOUNT=/Volumes/backups${NC}  (o la ruta que veas)"
      log "  ${CYAN}bash $0${NC}"
      for _ in $(seq 1 30); do
        sleep 2
        for vol in "$HOME/mnt/tower-backups" /Volumes/backups /Volumes/Tower/backups /Volumes/Tower; do
          if [[ -d "$vol" ]] && mount | grep -q " on ${vol} "; then
            MOUNT="$vol"
            DEST="$MOUNT/$DEST_SUBDIR"
            log "${GREEN}✓${NC} Detectado montaje: ${CYAN}${MOUNT}${NC}"
            return 0
          fi
        done
      done
      log "${RED}✗${NC} No se pudo montar Tower/backups"
      exit 1
    fi
  fi
}

move_file() {
  local src="$1" name="$2"
  local dst="$DEST/$name"
  [[ -e "$src" ]] || { log "${YELLOW}⊘${NC} No existe: $src"; return 0; }
  [[ -e "$dst" ]] && { log "${YELLOW}⊘${NC} Ya en destino: $name"; rm -f "$src"; return 0; }

  local bytes; bytes=$(need_bytes "$src")
  log "${BLUE}→${NC} Copiando ${CYAN}$(basename "$src")${NC} ($(fmt_bytes "$bytes"))"

  if command -v rsync >/dev/null && rsync -ah --info=progress2 -- "$src" "$dst" >>"$LOG" 2>&1; then
    :
  elif cp -p "$src" "$dst"; then
    :
  else
    log "${RED}✗${NC} Error copiando $src"
    return 1
  fi

  local rb; rb=$(stat -f%z "$dst")
  [[ "$rb" -eq "$bytes" ]] || { log "${RED}✗${NC} Tamaño distinto: $src"; rm -f "$dst"; return 1; }
  rm -f "$src"
  log "${GREEN}✓${NC} Movido y verificado: ${CYAN}$name${NC}"
}

move_tar() {
  local src="$1" name="$2"
  local dst="$DEST/$name"
  [[ -d "$src" ]] || { log "${YELLOW}⊘${NC} No existe: $src"; return 0; }
  [[ -f "$dst" ]] && { log "${YELLOW}⊘${NC} Ya en destino: $name"; rm -rf "$src"; return 0; }

  local bytes; bytes=$(need_bytes "$src")
  log "${BLUE}→${NC} Empaquetando ${CYAN}$(basename "$src")${NC} ($(fmt_bytes "$bytes")) → tar en SMB"

  # ponytail: tar directo al destino; no cabe staging local (119 GB > 96 GB libres)
  if tar -cf "$dst" -C "$(dirname "$src")" "$(basename "$src")" 2>>"$LOG"; then
    local rb; rb=$(stat -f%z "$dst")
    (( rb > 1000000 )) || { log "${RED}✗${NC} Tar inválido"; rm -f "$dst"; return 1; }
    rm -rf "$src"
    log "${GREEN}✓${NC} Biblioteca en ${CYAN}$name${NC} ($(fmt_bytes "$rb"))"
  else
    log "${RED}✗${NC} Error creando tar en Tower (¿nombres largos o espacio?)"
    rm -f "$dst"
    return 1
  fi
}

main() {
  [[ -d "$TOSHIBA" ]] || { log "${RED}✗${NC} Conecta TOSHIBA EXT2"; exit 1; }

  log "${CYAN}${BOLD}Mover Toshiba fase 1 → Tower/backups${NC}"
  log "Log: ${CYAN}$LOG${NC}\n"

  ensure_mount
  mkdir -p "$DEST"
  log "Destino: ${CYAN}$DEST${NC}\n"

  local free; free=$(df -k "$MOUNT" | tail -1 | awk '{print $4 * 1024}')
  log "Espacio libre en Tower: ${CYAN}$(fmt_bytes "$free")${NC}\n"

  local total=0 kind src name
  for job in "${JOBS[@]}"; do
    IFS='|' read -r kind src name <<< "$job"
    [[ -e "$src" ]] && total=$((total + $(need_bytes "$src")))
  done
  log "Pendiente mover: ${CYAN}~$(fmt_bytes "$total")${NC}\n"
  (( free >= total )) || log "${YELLOW}⚠${NC}  Puede faltar espacio en Tower\n"

  for job in "${JOBS[@]}"; do
    IFS='|' read -r kind src name <<< "$job"
    case "$kind" in
      file) move_file "$src" "$name" ;;
      tar)  move_tar "$src" "$name" ;;
    esac
  done

  log "\n${GREEN}${BOLD}✅ Fase 1 completada${NC}"
  log "Contenido en: ${CYAN}$DEST${NC}"
  df -h "$MOUNT" | tail -1 | tee -a "$LOG"
}

main "$@"
