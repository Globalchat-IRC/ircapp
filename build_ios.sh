#!/bin/bash

# Script para construir la app iOS para iPhone
# Uso: ./build_ios.sh

set -e

echo "🔨 Construyendo aplicación iOS..."

export PATH="/Users/fnaveira/flutter/bin:$PATH"

# Limpiar builds anteriores
echo "🧹 Limpiando builds anteriores..."
flutter clean

# Obtener dependencias
echo "📦 Obteniendo dependencias..."
flutter pub get

# Instalar pods
echo "📱 Instalando CocoaPods..."
cd ios
pod install
cd ..

# Construir para iOS
echo "🏗️  Construyendo para iOS..."
flutter build ios --release

echo ""
echo "✅ Build completado!"
echo ""
echo "📋 Próximos pasos para instalar en tu iPhone:"
echo "   1. Conecta tu iPhone por USB o Wi-Fi"
echo "   2. Abre Xcode: open ios/Runner.xcworkspace"
echo "   3. En Xcode:"
echo "      - Selecciona tu iPhone como destino"
echo "      - Ve a Signing & Capabilities"
echo "      - Selecciona tu Team (Apple ID)"
echo "      - Presiona ▶️ para instalar y ejecutar"
echo ""
echo "   O ejecuta: flutter run -d ios"



