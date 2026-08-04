#!/bin/bash
# Build Flutter web con ofuscación de código
# Uso: ./build_web_obfuscated.sh [output_dir]

set -e

OUTPUT_DIR="${1:-build/web}"

echo "🔨 Compilando Flutter web con ofuscación..."

flutter build web \
  -O4 \
  --no-source-maps \
  --release \
  --dart-define=FLUTTER_WEB_AUTO_DETECT=true

echo ""
echo "✅ Build completado en: $OUTPUT_DIR"
echo "📋 Debug info guardado en: $OUTPUT_DIR/debug_info"
echo "⚠️  Guarda el debug_info de forma segura (necesario para desobfuscar stack traces)"
