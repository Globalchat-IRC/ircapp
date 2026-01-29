#!/usr/bin/env bash
set -euo pipefail

# Script para descargar todos los emojis de Sonic desde Slackmojis
# Los guarda en assets/emoji_animated_noto/ con nombres normalizados

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/assets/emoji_animated_noto"

mkdir -p "$OUT_DIR"

echo "📦 Descargando emojis de Sonic desde Slackmojis..."

# Lista de URLs y sus nombres de archivo correspondientes
# Formato: URL|nombre_archivo
SONIC_EMOJIS=(
  "https://slackmojis.com/emojis/59877-sonic/download|sonic_59877.gif"
  "https://slackmojis.com/emojis/10687-sonic/download|sonic_10687.gif"
  "https://slackmojis.com/emojis/43812-sonic/download|sonic_43812.gif"
  "https://slackmojis.com/emojis/46444-sonic/download|sonic_46444.gif"
  "https://slackmojis.com/emojis/92815-sonic/download|sonic_92815.gif"
  "https://slackmojis.com/emojis/85109-sonic__q/download|sonic__q_85109.gif"
  "https://slackmojis.com/emojis/73670-sonicq/download|sonicq_73670.gif"
  "https://slackmojis.com/emojis/79951-sonicq/download|sonicq_79951.gif"
  "https://slackmojis.com/emojis/79952-sonic1q/download|sonic1q_79952.gif"
  "https://slackmojis.com/emojis/85355-asonicq/download|asonicq_85355.gif"
  "https://slackmojis.com/emojis/84953-sonic2q/download|sonic2q_84953.gif"
  "https://slackmojis.com/emojis/11999-sonic-wow/download|sonic_wow_11999.gif"
  "https://slackmojis.com/emojis/63777-sonic-run/download|sonic_run_63777.gif"
  "https://slackmojis.com/emojis/70614-ssoniccq/download|ssoniccq_70614.gif"
  "https://slackmojis.com/emojis/79953-sonicnoq/download|sonicnoq_79953.gif"
  "https://slackmojis.com/emojis/79954-sonichiq/download|sonichiq_79954.gif"
  "https://slackmojis.com/emojis/103077-sonic_1up/download|sonic_1up_103077.gif"
  "https://slackmojis.com/emojis/56731-sonic_ring/download|sonic_ring_56731.gif"
  "https://slackmojis.com/emojis/84123-wtfsonicq/download|wtfsonicq_84123.gif"
  "https://slackmojis.com/emojis/81366-sonic_runq/download|sonic_runq_81366.gif"
  "https://slackmojis.com/emojis/85378-gtgsonicq/download|gtgsonicq_85378.gif"
  "https://slackmojis.com/emojis/96246-sonicwave/download|sonicwave_96246.gif"
  "https://slackmojis.com/emojis/120435-sonic-slow/download|sonic_slow_120435.gif"
  "https://slackmojis.com/emojis/82044-mhmsonicq/download|mhmsonicq_82044.gif"
  "https://slackmojis.com/emojis/81600-omgsonicq/download|omgsonicq_81600.gif"
  "https://slackmojis.com/emojis/13390-supersonic/download|supersonic_13390.gif"
  "https://slackmojis.com/emojis/4427-conga_sonic/download|conga_sonic_4427.gif"
  "https://slackmojis.com/emojis/59324-sonic_movie/download|sonic_movie_59324.gif"
  "https://slackmojis.com/emojis/69959-bruhsonic_q/download|bruhsonic_q_69959.gif"
)

download_one() {
  local url="$1"
  local filename="$2"
  local out="$OUT_DIR/$filename"
  
  if [[ -f "$out" ]]; then
    echo "↪️  Ya existe: $filename"
    return 0
  fi
  
  echo "⬇️  Descargando: $filename desde $url"
  if curl -fsSL -L "$url" -o "$out"; then
    echo "✅ Descargado: $filename"
  else
    echo "⚠️  Error al descargar: $url"
    rm -f "$out" || true
    return 1
  fi
}

for entry in "${SONIC_EMOJIS[@]}"; do
  IFS='|' read -r url filename <<< "$entry"
  download_one "$url" "$filename"
done

echo "🎉 Descarga completada. Emojis guardados en: $OUT_DIR"
