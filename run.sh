#!/bin/bash

# ✅ INSTRUCCIONES DE EJECUCIÓN - IRC Client Flutter
# Este script ejecuta el cliente IRC en el simulador de iOS

set -e

echo "════════════════════════════════════════════════════════"
echo "  📱 IRC Chat Client - Flutter"
echo "  Iniciando aplicación en simulador iOS..."
echo "════════════════════════════════════════════════════════"
echo ""

# Configurar PATH
export PATH="/Users/fnaveira/flutter/bin:$PATH"

# Navegar al proyecto
PROJECT_DIR="/Users/fnaveira/mobile/irc_app"
cd "$PROJECT_DIR"

# Verificar que Flutter esté instalado
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter no encontrado. Asegúrate de tener Flutter instalado."
    exit 1
fi

echo "✅ Flutter versión:"
flutter --version | head -1
echo ""

# Limpiar builds anteriores (opcional)
echo "🧹 Limpiando builds anteriores..."
flutter clean > /dev/null 2>&1 || true

# Abrir el simulador iOS
echo "📱 Abriendo simulador iOS..."
if pgrep -q "Simulator"; then
    echo "   ✓ Simulador ya está abierto"
else
    open -a Simulator &
    sleep 5
    echo "   ✓ Simulador abierto"
fi

# Esperar a que el simulador esté listo
echo "⏳ Esperando a que el simulador esté listo..."
sleep 3

# Ejecutar la aplicación
echo ""
echo "🚀 Compilando y ejecutando la aplicación..."
echo "════════════════════════════════════════════════════════"
echo ""

# Ejecutar con modo release para mejor rendimiento
flutter run --release

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ Aplicación ejecutándose"
echo "════════════════════════════════════════════════════════"
echo ""
echo "💡 Instrucciones de uso:"
echo "   • Presiona 'R' para hot reload"
echo "   • Presiona 'Q' para salir"
echo ""
echo "🎯 Parámetros de conexión IRC:"
echo "   • Host: ceres.globalchat.org"
echo "   • Puerto: 6667"
echo "   • Nickname: Tu nombre de usuario"
echo ""
