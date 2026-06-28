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

# Escribir version.json para que la web fuerce recarga cuando hay nueva versión.
echo "{\"version\": \"$VERSION\"}" > build/web/version.json
# Flutter web arranca desde flutter_bootstrap.js, por lo que hay que versionar
# tanto el bootstrap en index.html como la referencia a main.dart.js dentro del bootstrap.
sed "s|flutter_bootstrap\.js|flutter_bootstrap.js?v=$VERSION|g" build/web/index.html > build/web/index.html.tmp && mv build/web/index.html.tmp build/web/index.html
sed "s|main\.dart\.js|main.dart.js?v=$VERSION|g" build/web/flutter_bootstrap.js > build/web/flutter_bootstrap.js.tmp && mv build/web/flutter_bootstrap.js.tmp build/web/flutter_bootstrap.js
echo "📌 version.json, index.html y flutter_bootstrap.js versionados: $VERSION"

echo "✅ Compilación completada"
echo ""

# 2. Mostrar información del build
echo "📊 Información del build:"
ls -lh build/web/main.dart.js
echo ""

# Rutas reales en ceres
REMOTE_WEB_ROOT="/var/www/mobilev1.globalchat.org"
REMOTE_API_ROOT="$REMOTE_WEB_ROOT/api"
REMOTE_LEGACY_ROOT="/var/www/irc_app"

# 3. Subir archivos
echo "📤 Paso 2: Subiendo archivos a ceres..."
rsync -avz --delete --progress --exclude='NOTICES' --exclude='*.md' --exclude='*.txt' --exclude='*.log' --exclude='*.yaml' --exclude='*.yml' build/web/ ceres.globalchat.org:/tmp/irc_app_build/

echo "✅ Archivos subidos"
echo ""

# 4. Mover y configurar permisos
echo "🔐 Paso 3: Configurando permisos en ceres..."
ssh ceres.globalchat.org "sudo mkdir -p $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT && sudo rm -rf $REMOTE_WEB_ROOT/* && sudo cp -r /tmp/irc_app_build/* $REMOTE_WEB_ROOT/ && sudo rm -rf $REMOTE_LEGACY_ROOT/* && sudo cp -r /tmp/irc_app_build/* $REMOTE_LEGACY_ROOT/ && sudo chown -R www-data:www-data $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT && sudo chmod -R 755 $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT && sudo rm -f $REMOTE_WEB_ROOT/assets/NOTICES $REMOTE_LEGACY_ROOT/assets/NOTICES && rm -rf /tmp/irc_app_build"

echo "✅ Permisos configurados"
echo ""

# 5. Desplegar backend (API de Mixcloud)
echo "📡 Paso 4: Desplegando backend (API)..."
ssh ceres.globalchat.org "sudo mkdir -p $REMOTE_API_ROOT $REMOTE_LEGACY_ROOT/api"
scp gateway/mixcloud_stream_extractor.php gateway/mixcloud_stream_proxy.php gateway/mixcloud_stream_extractor.sh gateway/mixcloud_stream_extractor_playwright.js gateway/mixcloud_recorded_extractor.php gateway/mixcloud_recorded_stream_playwright.js gateway/avatar_upload_proxy.php gateway/qualia_radio_status.php ceres.globalchat.org:/tmp/
ssh ceres.globalchat.org "sudo cp /tmp/mixcloud_stream_extractor.php /tmp/mixcloud_stream_proxy.php /tmp/mixcloud_stream_extractor.sh /tmp/mixcloud_stream_extractor_playwright.js /tmp/mixcloud_recorded_extractor.php /tmp/mixcloud_recorded_stream_playwright.js /tmp/avatar_upload_proxy.php /tmp/qualia_radio_status.php $REMOTE_API_ROOT/ && sudo cp /tmp/mixcloud_stream_extractor.php /tmp/mixcloud_stream_proxy.php /tmp/mixcloud_stream_extractor.sh /tmp/mixcloud_stream_extractor_playwright.js /tmp/mixcloud_recorded_extractor.php /tmp/mixcloud_recorded_stream_playwright.js /tmp/avatar_upload_proxy.php /tmp/qualia_radio_status.php $REMOTE_LEGACY_ROOT/api/ && sudo rm -f /tmp/mixcloud_stream_extractor.php /tmp/mixcloud_stream_proxy.php /tmp/mixcloud_stream_extractor.sh /tmp/mixcloud_stream_extractor_playwright.js /tmp/mixcloud_recorded_extractor.php /tmp/mixcloud_recorded_stream_playwright.js /tmp/avatar_upload_proxy.php /tmp/qualia_radio_status.php && sudo chown www-data:www-data $REMOTE_API_ROOT/* $REMOTE_LEGACY_ROOT/api/* && sudo chmod 755 $REMOTE_API_ROOT/* $REMOTE_LEGACY_ROOT/api/*"

echo "📦 Instalando dependencias de Playwright..."
# Instalar Playwright localmente en el directorio api
ssh ceres.globalchat.org "cd $REMOTE_API_ROOT && sudo npm install playwright --prefix $REMOTE_API_ROOT 2>&1 | tail -5 || echo '⚠️  npm install failed'"
# Instalar navegadores de Playwright con permisos correctos
ssh ceres.globalchat.org "cd $REMOTE_API_ROOT && sudo PLAYWRIGHT_BROWSERS_PATH=/media/globalchat/tmp/.playwright node_modules/.bin/playwright install chromium 2>&1 | tail -5 || echo '⚠️  Playwright browsers installation may have failed, but continuing...'"

echo "✅ Backend desplegado"
echo ""

# 6. Verificar despliegue
echo "🔍 Paso 5: Verificando despliegue..."
ssh ceres.globalchat.org "ls -ltrha $REMOTE_WEB_ROOT/main.dart.js $REMOTE_LEGACY_ROOT/main.dart.js"
ssh ceres.globalchat.org "ls -la $REMOTE_API_ROOT/"

echo ""
echo "=========================================="
echo "✅ DESPLIEGUE COMPLETADO"
echo "=========================================="
echo ""
echo "📌 Versión desplegada: $VERSION"
echo "🌐 URL: https://mobilev1.globalchat.org"
echo ""
echo "💡 Recarga la página con Ctrl+Shift+R para ver los cambios"






