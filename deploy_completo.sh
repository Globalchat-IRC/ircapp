#!/bin/bash
set -e

echo "=========================================="
echo "🚀 DESPLIEGUE COMPLETO A CERES"
echo "=========================================="
echo ""

# 1. Limpiar y compilar
echo "📦 Paso 1: Limpiando y compilando..."
flutter clean
flutter pub get
flutter build web --release

# Verificar que el build existe
if [ ! -f "build/web/main.dart.js" ]; then
    echo "❌ Error: No se generó build/web/main.dart.js"
    exit 1
fi

echo "✅ Compilación completada"
echo ""

# 2. Mostrar información del build
echo "📊 Información del build:"
ls -lh build/web/main.dart.js
echo ""

# 3. Subir archivos
echo "📤 Paso 2: Subiendo archivos a ceres..."
rsync -avz --delete --progress build/web/ ceres.globalchat.org:/tmp/irc_app_build/

echo "✅ Archivos subidos"
echo ""

# 4. Mover y configurar permisos
echo "🔐 Paso 3: Configurando permisos en ceres..."
ssh ceres.globalchat.org "sudo rm -rf /var/www/irc_app/* && sudo cp -r /tmp/irc_app_build/* /var/www/irc_app/ && sudo chown -R www-data:www-data /var/www/irc_app && sudo chmod -R 755 /var/www/irc_app && rm -rf /tmp/irc_app_build"

echo "✅ Permisos configurados"
echo ""

# 5. Verificar despliegue
echo "🔍 Paso 4: Verificando despliegue..."
ssh ceres.globalchat.org "ls -ltrha /var/www/irc_app/main.dart.js"

echo ""
echo "=========================================="
echo "✅ DESPLIEGUE COMPLETADO"
echo "=========================================="
echo ""
echo "🌐 URL: https://mobilev1.globalchat.org"
echo ""
echo "💡 Recarga la página con Ctrl+Shift+R para ver los cambios"




