#!/bin/bash

# Script de despliegue forzado sin confirmación
set -e

echo "🚀 Desplegando IRC App a ceres.globalchat.org (sin confirmación)"

# Verificar que existe el build
if [ ! -d "build/web" ]; then
    echo "❌ Error: No se encuentra build/web. Compilando..."
    flutter build web --release
fi

# Parámetros
SSH_HOST="ceres.globalchat.org"
DEST_PATH="/var/www/irc_app"
TEMP_DIR="/tmp/irc_app_$$"

echo "📤 Subiendo archivos a $SSH_HOST:$TEMP_DIR..."
rsync -avz --delete build/web/ $SSH_HOST:$TEMP_DIR/

echo "🔐 Moviendo archivos y configurando permisos..."
ssh $SSH_HOST "sudo rm -rf $DEST_PATH/* && sudo cp -r $TEMP_DIR/* $DEST_PATH/ && sudo chown -R www-data:www-data $DEST_PATH && sudo chmod -R 755 $DEST_PATH && rm -rf $TEMP_DIR"

echo "✅ Despliegue completado!"
echo "📝 Verificando archivo principal..."
ssh $SSH_HOST "ls -lh $DEST_PATH/main.dart.js | head -1"




