#!/bin/bash
# Despliegue rápido a ceres: compila incremental (sin clean) y sube solo lo que cambia.
# Uso:
#   ./deploy_simple.sh          → rápido (~1-2 min): JS/HTML/manifiestos
#   ./deploy_simple.sh --full   → sube todo el build (assets incluidos, ~30 min)
set -e

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
REMOTE_WEB_ROOT="/var/www/mobilev1.globalchat.org"
REMOTE_LEGACY_ROOT="/var/www/irc_app"
SSH_HOST="ceres.globalchat.org"
TMP="/tmp/irc_app_hot_$$"

echo "=========================================="
echo "⚡ DESPLIEGUE RÁPIDO A CERES"
echo "=========================================="
echo "📌 Versión: $VERSION"
echo "📌 Modo: $([ "$FULL" = true ] && echo 'completo (assets)' || echo 'rápido (solo código)')"
echo ""

# 1. Compilar incremental (sin flutter clean)
echo "📦 Compilando (incremental)..."
flutter build web --release --base-href="/"

if [ ! -f "build/web/main.dart.js" ]; then
    echo "❌ Error: no se generó build/web/main.dart.js"
    exit 1
fi

# Versionar para forzar recarga en clientes
echo "{\"version\": \"$VERSION\"}" > build/web/version.json
sed "s|flutter_bootstrap\.js[^\"']*|flutter_bootstrap.js?v=$VERSION|g" build/web/index.html > build/web/index.html.tmp && mv build/web/index.html.tmp build/web/index.html
sed "s|main\.dart\.js[^\"']*|main.dart.js?v=$VERSION|g" build/web/flutter_bootstrap.js > build/web/flutter_bootstrap.js.tmp && mv build/web/flutter_bootstrap.js.tmp build/web/flutter_bootstrap.js

echo "✅ Build listo ($(du -sh build/web/main.dart.js | cut -f1) main.dart.js)"
echo ""

# 2. Subir
if [ "$FULL" = true ]; then
    echo "📤 Subiendo build completo..."
    rsync -avz --delete \
        --exclude='NOTICES' --exclude='*.md' --exclude='*.txt' \
        --exclude='*.log' --exclude='*.yaml' --exclude='*.yml' \
        build/web/ "$SSH_HOST:/tmp/irc_app_build/"
    REMOTE_SRC="/tmp/irc_app_build"
else
    echo "📤 Subiendo solo archivos de código (~6-10 MB)..."
    mkdir -p /tmp/irc_app_hot_local/assets
    cp build/web/main.dart.js \
       build/web/flutter_bootstrap.js \
       build/web/flutter.js \
       build/web/flutter_service_worker.js \
       build/web/index.html \
       build/web/version.json \
       build/web/.last_build_id \
       build/web/manifest.json \
       /tmp/irc_app_hot_local/ 2>/dev/null || true
    cp build/web/assets/AssetManifest.bin \
       build/web/assets/AssetManifest.bin.json \
       build/web/assets/FontManifest.json \
       /tmp/irc_app_hot_local/assets/ 2>/dev/null || true
    # Shaders solo si existen (cambian raramente)
    if [ -d "build/web/assets/shaders" ]; then
        mkdir -p /tmp/irc_app_hot_local/assets/shaders
        cp -r build/web/assets/shaders/* /tmp/irc_app_hot_local/assets/shaders/
    fi

    rsync -avz /tmp/irc_app_hot_local/ "$SSH_HOST:$TMP/"
    rm -rf /tmp/irc_app_hot_local
    REMOTE_SRC="$TMP"
fi

echo "✅ Archivos subidos"
echo ""

# 3. Instalar en ceres (ambas rutas: mobilev1 + irc_app legacy)
echo "🔐 Instalando en ceres..."
if [ "$FULL" = true ]; then
    ssh "$SSH_HOST" "sudo mkdir -p $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT && \
        sudo rm -rf $REMOTE_WEB_ROOT/* && sudo cp -r $REMOTE_SRC/* $REMOTE_WEB_ROOT/ && \
        sudo rm -rf $REMOTE_LEGACY_ROOT/* && sudo cp -r $REMOTE_SRC/* $REMOTE_LEGACY_ROOT/ && \
        sudo chown -R www-data:www-data $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT && \
        sudo chmod -R 755 $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT && \
        sudo rm -f $REMOTE_WEB_ROOT/assets/NOTICES $REMOTE_LEGACY_ROOT/assets/NOTICES && \
        rm -rf $REMOTE_SRC"
else
    ssh "$SSH_HOST" "sudo mkdir -p $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT $REMOTE_WEB_ROOT/assets $REMOTE_LEGACY_ROOT/assets && \
        sudo cp $REMOTE_SRC/main.dart.js $REMOTE_SRC/flutter_bootstrap.js $REMOTE_SRC/flutter.js \
            $REMOTE_SRC/flutter_service_worker.js $REMOTE_SRC/index.html $REMOTE_SRC/version.json \
            $REMOTE_SRC/.last_build_id $REMOTE_SRC/manifest.json $REMOTE_WEB_ROOT/ 2>/dev/null; \
        sudo cp $REMOTE_SRC/main.dart.js $REMOTE_SRC/flutter_bootstrap.js $REMOTE_SRC/flutter.js \
            $REMOTE_SRC/flutter_service_worker.js $REMOTE_SRC/index.html $REMOTE_SRC/version.json \
            $REMOTE_SRC/.last_build_id $REMOTE_SRC/manifest.json $REMOTE_LEGACY_ROOT/ 2>/dev/null; \
        sudo cp $REMOTE_SRC/assets/* $REMOTE_WEB_ROOT/assets/ 2>/dev/null; \
        sudo cp $REMOTE_SRC/assets/* $REMOTE_LEGACY_ROOT/assets/ 2>/dev/null; \
        [ -d $REMOTE_SRC/assets/shaders ] && sudo mkdir -p $REMOTE_WEB_ROOT/assets/shaders $REMOTE_LEGACY_ROOT/assets/shaders && \
            sudo cp -r $REMOTE_SRC/assets/shaders/* $REMOTE_WEB_ROOT/assets/shaders/ && \
            sudo cp -r $REMOTE_SRC/assets/shaders/* $REMOTE_LEGACY_ROOT/assets/shaders/; \
        sudo chown -R www-data:www-data $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT && \
        sudo chmod -R 755 $REMOTE_WEB_ROOT $REMOTE_LEGACY_ROOT && \
        rm -rf $REMOTE_SRC"
fi

echo ""
echo "=========================================="
echo "✅ DESPLIEGUE RÁPIDO COMPLETADO"
echo "=========================================="
echo "📌 Versión: $VERSION"
echo "🌐 URL: https://mobilev1.globalchat.org"
echo "💡 Recarga con Ctrl+Shift+R"
echo ""
echo "ℹ️  Si añadiste assets nuevos, usa: ./deploy_simple.sh --full"
