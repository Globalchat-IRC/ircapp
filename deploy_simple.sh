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

echo "🔐 Configurando permisos y moviendo a la raíz..."
ssh ceres.globalchat.org "
    # Hacer backup de archivos importantes si existen
    sudo mkdir -p /var/www/ceres.globalchat.org/backup_old
    
    # Limpiar archivos Flutter antiguos pero preservar api/ y otros directorios
    sudo find /var/www/ceres.globalchat.org -maxdepth 1 -type f \( -name '*.js' -o -name '*.html' -o -name 'manifest.json' -o -name 'version.json' -o -name 'favicon.png' \) -delete 2>/dev/null || true
    sudo rm -rf /var/www/ceres.globalchat.org/assets /var/www/ceres.globalchat.org/canvaskit /var/www/ceres.globalchat.org/icons 2>/dev/null || true
    
    # Copiar nueva versión
    sudo cp -r /tmp/irc_app_build/* /var/www/ceres.globalchat.org/
    
    # Configurar permisos
    sudo chown -R www-data:www-data /var/www/ceres.globalchat.org
    sudo chmod -R 755 /var/www/ceres.globalchat.org
    
    # Limpiar temporal
    rm -rf /tmp/irc_app_build
"

echo "✅ Despliegue completado!"
echo "📝 Verificando..."
ssh ceres.globalchat.org "ls -lh /var/www/ceres.globalchat.org/main.dart.js"






