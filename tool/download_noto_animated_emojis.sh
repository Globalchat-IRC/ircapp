#!/usr/bin/env bash
set -euo pipefail

# Descarga un subconjunto de Noto Emoji Animation (GIF 512) para usarlos como assets locales.
# Fuente (CDN oficial): https://fonts.gstatic.com/s/e/notoemoji/latest/{codepoint}/512.gif
#
# Uso:
#   bash tool/download_noto_animated_emojis.sh
#
# Nota: Descarga SOLO los codepoints definidos en lib/services/emoji_service.dart (animatedEmojiMap).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_FILE="$ROOT_DIR/lib/services/emoji_service.dart"
OUT_DIR="$ROOT_DIR/assets/emoji_animated_noto"

mkdir -p "$OUT_DIR"

echo "📦 Extrayendo codepoints *animados* desde: $SRC_FILE"

# Limitar al bloque animatedEmojiMap para no incluir el mapa gigante de emojis estáticos.
ANIM_BLOCK=$(
  awk '
    /animatedEmojiMap[[:space:]]*=[[:space:]]*\{/ {inside=1; next}
    inside && /^[[:space:]]*\};[[:space:]]*$/ {inside=0}
    inside {print}
  ' "$SRC_FILE"
)

# Extrae codepoints del bloque (ej: ':party:': '1f389', o ':heart_animated:': '2764_fe0f',)
CODEPOINTS=$(
  echo "$ANIM_BLOCK" \
    | grep -E "':[A-Za-z0-9_+-]+:':[[:space:]]*'[0-9a-fA-F_]+'," \
    | sed -E "s/.*':[A-Za-z0-9_+-]+:':[[:space:]]*'([0-9a-fA-F_]+)'.*/\\1/" \
    | tr '[:upper:]' '[:lower:]' \
    | sort -u
)

if [[ -z "${CODEPOINTS}" ]]; then
  echo "❌ No se encontraron codepoints en animatedEmojiMap"
  exit 1
fi

echo "✅ Encontrados $(echo "$CODEPOINTS" | wc -l | tr -d ' ') codepoints. Descargando..."

BASE="https://fonts.gstatic.com/s/e/notoemoji/latest"

download_one () {
  local cp="$1"
  local cp_lc
  cp_lc="$(echo "$cp" | tr '[:upper:]' '[:lower:]')"
  local url="$BASE/$cp_lc/512.gif"
  local out="$OUT_DIR/$cp_lc.gif"

  if [[ -f "$out" ]]; then
    echo "↪️  Ya existe: $out"
    return 0
  fi

  echo "⬇️  $cp_lc -> $url"
  if ! curl -fsSL "$url" -o "$out"; then
    echo "⚠️  No disponible (404 u otro error): $url"
    rm -f "$out" || true
  fi
}

while IFS= read -r cp; do
  download_one "$cp"
done <<< "$CODEPOINTS"

echo "🎉 Listo. Assets en: $OUT_DIR"
