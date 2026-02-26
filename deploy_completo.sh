#!/bin/bash
set -e

# Obtener la versión del pubspec.yaml
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')

echo "=========================================="
echo "🚀 DESPLIEGUE COMPLETO A CERES"
echo "=========================================="
echo "📌 Versión: $VERSION"
echo ""

# 1. Limpiar y compilar
# Base href "/" porque la app se sirve en la raíz (https://mobilev1.globalchat.org/)
echo "📦 Paso 1: Limpiando y compilando..."
flutter clean
flutter pub get
flutter build web --release --base-href="/"

# Verificar que el build existe
if [ ! -f "build/web/main.dart.js" ]; then
    echo "❌ Error: No se generó build/web/main.dart.js"
    exit 1
fi

# Escribir version.json para que la web fuerce recarga cuando hay nueva versión (usuarios con caché antigua)
echo "{\"version\": \"$VERSION\"}" > build/web/version.json
# Hacer que el script principal tenga ?v=VERSION para evitar caché del JS en navegadores (compatible Linux/macOS)
sed "s|main\.dart\.js|main.dart.js?v=$VERSION|g" build/web/index.html > build/web/index.html.tmp && mv build/web/index.html.tmp build/web/index.html
echo "📌 version.json e index.html (script versionado) generados: $VERSION"

echo "✅ Compilación completada"
echo ""

# 2. Mostrar información del build
echo "📊 Información del build:"
ls -lh build/web/main.dart.js
echo ""

# 3. Subir archivos
echo "📤 Paso 2: Subiendo archivos a ceres..."
rsync -avz --delete --progress --exclude='NOTICES' --exclude='*.md' --exclude='*.txt' --exclude='*.log' --exclude='*.yaml' --exclude='*.yml' build/web/ ceres.globalchat.org:/tmp/irc_app_build/

echo "✅ Archivos subidos"
echo ""

# 4. Mover y configurar permisos
echo "🔐 Paso 3: Configurando permisos en ceres..."
ssh ceres.globalchat.org "sudo rm -rf /var/www/irc_app/* && sudo cp -r /tmp/irc_app_build/* /var/www/irc_app/ && sudo chown -R www-data:www-data /var/www/irc_app && sudo chmod -R 755 /var/www/irc_app && sudo rm -f /var/www/irc_app/assets/NOTICES && rm -rf /tmp/irc_app_build"

echo "✅ Permisos configurados"
echo ""

# 5. Desplegar backend (API de Mixcloud)
echo "📡 Paso 4: Desplegando backend (API)..."
ssh ceres.globalchat.org "sudo mkdir -p /var/www/irc_app/api"
scp gateway/mixcloud_stream_extractor.php gateway/mixcloud_stream_proxy.php gateway/mixcloud_stream_extractor.sh gateway/mixcloud_stream_extractor_playwright.js gateway/mixcloud_recorded_extractor.php gateway/mixcloud_recorded_stream_playwright.js ceres.globalchat.org:/tmp/
ssh ceres.globalchat.org "sudo mv /tmp/mixcloud_stream_extractor.php /tmp/mixcloud_stream_proxy.php /tmp/mixcloud_stream_extractor.sh /tmp/mixcloud_stream_extractor_playwright.js /tmp/mixcloud_recorded_extractor.php /tmp/mixcloud_recorded_stream_playwright.js /var/www/irc_app/api/ && sudo chown www-data:www-data /var/www/irc_app/api/* && sudo chmod 755 /var/www/irc_app/api/*"

echo "📦 Instalando dependencias de Playwright..."
# Instalar Playwright localmente en el directorio api
ssh ceres.globalchat.org "cd /var/www/irc_app/api && sudo npm install playwright --prefix /var/www/irc_app/api 2>&1 | tail -5 || echo '⚠️  npm install failed'"
# Instalar navegadores de Playwright con permisos correctos
ssh ceres.globalchat.org "cd /var/www/irc_app/api && sudo PLAYWRIGHT_BROWSERS_PATH=/media/globalchat/tmp/.playwright node_modules/.bin/playwright install chromium 2>&1 | tail -5 || echo '⚠️  Playwright browsers installation may have failed, but continuing...'"

echo "✅ Backend desplegado"
echo ""

# 6. Verificar despliegue
echo "🔍 Paso 5: Verificando despliegue..."
ssh ceres.globalchat.org "ls -ltrha /var/www/irc_app/main.dart.js"
ssh ceres.globalchat.org "ls -la /var/www/irc_app/api/"

echo ""
echo "=========================================="
echo "✅ DESPLIEGUE COMPLETADO"
echo "=========================================="
echo ""
echo "📌 Versión desplegada: $VERSION"
echo "🌐 URL: https://mobilev1.globalchat.org"
echo ""
echo "💡 Recarga la página con Ctrl+Shift+R para ver los cambios"






