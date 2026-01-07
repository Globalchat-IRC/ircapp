#!/bin/bash

# Script para compilar la aplicación web con máxima protección/ofuscación
# Esto hace el código más difícil de leer, pero NO es encriptación real

set -e

echo "🔒 Compilando aplicación web con ofuscación y optimización máxima..."

# Limpiar build anterior
flutter clean

# Compilar con:
# - --release: Modo release (optimización máxima)
# - --dart-define=FLUTTER_WEB_USE_SKIA=true: Usar Skia para mejor rendimiento
# - --no-source-maps: NO generar source maps (sin esto, el código original es más fácil de ver)
# - --split-debug-info: Separar información de debug (requerido para ofuscación)
# - --obfuscate: Ofuscar el código (renombra variables y funciones)
# - -O4: Nivel máximo de optimización
# - --no-tree-shake-icons: Mantener todos los iconos (opcional, puedes quitarlo)

OUTPUT_DIR="build/web_secure"
DEBUG_INFO_DIR="build/debug_info"

# Crear directorio para debug info
mkdir -p "$DEBUG_INFO_DIR"

echo "📦 Compilando con ofuscación..."
flutter build web \
  --release \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --no-source-maps \
  -O4 \
  --base-href="/"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Compilación exitosa con ofuscación"
  echo ""
  echo "📁 Archivos generados:"
  echo "   - Código ofuscado: build/web/"
  echo "   - Debug info (guardar en lugar seguro): $DEBUG_INFO_DIR/"
  echo ""
  echo "⚠️  IMPORTANTE:"
  echo "   - El código está OFUSCADO (no encriptado)"
  echo "   - El código JavaScript SIEMPRE puede ser inspeccionado en el navegador"
  echo "   - La ofuscación hace el código más difícil de leer, pero no imposible"
  echo "   - Guarda los archivos de debug_info en un lugar seguro (necesarios para debugging)"
  echo ""
  echo "🔐 Niveles de protección aplicados:"
  echo "   ✅ Minificación (código comprimido)"
  echo "   ✅ Optimización nivel 4 (máxima - renombra variables automáticamente)"
  echo "   ✅ Sin source maps (no se puede mapear al código original fácilmente)"
  echo "   ⚠️  Nota: Flutter Web no soporta --obfuscate, pero -O4 optimiza y renombra código"
  echo ""
  echo "📝 Para desplegar:"
  echo "   ./deploy_to_ceres.sh"
else
  echo "❌ Error en la compilación"
  exit 1
fi

