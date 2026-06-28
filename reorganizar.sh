#!/usr/bin/env bash
set -euo pipefail

# Pon DRYRUN=0 para mover de verdad. Con DRYRUN=1 solo muestra qué haría.
DRYRUN=${DRYRUN:-0}

mes_num() {
  case "$1" in
    enero) echo 01 ;;
    febrero) echo 02 ;;
    marzo) echo 03 ;;
    abril) echo 04 ;;
    mayo) echo 05 ;;
    junio) echo 06 ;;
    julio) echo 07 ;;
    agosto) echo 08 ;;
    septiembre) echo 09 ;;
    octubre) echo 10 ;;
    noviembre) echo 11 ;;
    diciembre) echo 12 ;;
    *) echo "" ;;
  esac
}

for dir in */; do
  name="${dir%/}"
  if [[ "$name" =~ ^([0-9]{1,2})\ de\ ([a-zñ]+)\ de\ ([0-9]{4})$ ]]; then
    mes_nombre="${BASH_REMATCH[2]}"
    anio="${BASH_REMATCH[3]}"
    mes="$(mes_num "$mes_nombre")"
    if [[ -z "$mes" ]]; then
      echo "⚠️  Mes desconocido: $name"
      continue
    fi
    destino="$anio/$anio-$mes"
    if [[ "$DRYRUN" == "1" ]]; then
      echo "[DRY] $name -> $destino/"
    else
      mkdir -p "$destino"
      mv -- "$name" "$destino/"
      echo "✅ $name -> $destino/"
    fi
  fi
done
