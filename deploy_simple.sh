#!/bin/bash
set -e

echo "🚀 Iniciando despliegue..."

# Compilar si es necesario
if [ ! -f "build/web/main.dart.js" ]; then
    echo "📦 Compilando aplicación..."
    flutter build web --release
fi

echo "📤 Subiendo archivos..."
rsync -avz --delete build/web/ ceres.globalchat.org:/tmp/irc_app_build/

echo "🔐 Configurando permisos..."
ssh ceres.globalchat.org "sudo rm -rf /var/www/irc_app/* && sudo cp -r /tmp/irc_app_build/* /var/www/irc_app/ && sudo chown -R www-data:www-data /var/www/irc_app && sudo chmod -R 755 /var/www/irc_app && rm -rf /tmp/irc_app_build"

echo "✅ Despliegue completado!"
echo "📝 Verificando..."
ssh ceres.globalchat.org "ls -lh /var/www/irc_app/main.dart.js"




