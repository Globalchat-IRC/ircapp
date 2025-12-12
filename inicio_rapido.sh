#!/bin/bash

# 🚀 INICIO RÁPIDO - IRC Client Flutter
# Script para ejecutar la aplicación en el simulador iOS

echo "📱 IRC Client Flutter - Inicio Rápido"
echo "======================================"
echo ""

# 1. Configurar PATH de Flutter
echo "✓ Configurando Flutter..."
export PATH="/Users/fnaveira/flutter/bin:$PATH"

# 2. Navegar al proyecto
cd /Users/fnaveira/mobile/irc_app || exit 1
echo "✓ Directorio: $(pwd)"

# 3. Verificar dependencias
echo "✓ Verificando dependencias..."
flutter doctor --no-android --no-web 2>&1 | grep -E "Flutter|Xcode|iOS|Connected"

# 4. Obtener dependencias si es necesario
if [ ! -d "build" ]; then
    echo "✓ Descargando dependencias..."
    flutter pub get
fi

# 5. Abrir simulador iOS si no está abierto
echo "✓ Iniciando simulador iOS..."
if ! pgrep -q "Simulator"; then
    open -a Simulator
    sleep 3
fi

# 6. Ejecutar la aplicación
echo ""
echo "✓ Compilando y ejecutando en simulador..."
echo ""
flutter run

# Instrucciones de uso
echo ""
echo "======================================"
echo "🎯 INSTRUCCIONES DE USO:"
echo "======================================"
echo ""
echo "1. Pantalla de Login:"
echo "   - Host: ceres.globalchat.org (por defecto)"
echo "   - Puerto: 6667 (por defecto)"
echo "   - Nickname: Tu nombre de usuario IRC"
echo "   - Presiona 'Connect'"
echo ""
echo "2. Pantalla de Chat:"
echo "   - Izquierda: Lista de canales"
echo "   - Centro: Mensajes del canal"
echo "   - Derecha: Usuarios del canal"
echo "   - Botón 'Join': Unirse a nuevo canal"
echo "   - Botón Rojo: Desconectarse"
echo ""
echo "3. Hot Reload:"
echo "   - Presiona 'R' en la terminal para hot reload"
echo "   - Presiona 'Q' para salir"
echo ""
