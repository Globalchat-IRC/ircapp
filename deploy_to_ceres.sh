#!/bin/bash

# Script para desplegar IRC App v3.0.0 en ceres.globalchat.org
# Usa el alias SSH 'ceres' que tiene stunnel configurado
# Uso: ./deploy_to_ceres.sh [ruta_destino]

set -e

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Desplegando IRC App v3.0.0 a ceres.globalchat.org${NC}"

# Verificar que existe el build
if [ ! -d "build/web" ]; then
    echo -e "${RED}❌ Error: No se encuentra build/web. Ejecuta 'flutter build web --release' primero.${NC}"
    exit 1
fi

# Parámetros
# Usar alias 'ceres' que tiene stunnel configurado
DEST_PATH=${1:-"/var/www/irc_app"}  # Ruta por defecto (primer parámetro ahora es la ruta)

echo -e "${YELLOW}📦 Preparando archivos...${NC}"
echo "   Conexión: ceres (stunnel)"
echo "   Destino: $DEST_PATH"

# Asegurar que los iconos estén en el build
echo -e "${YELLOW}🔍 Verificando iconos en build...${NC}"
if [ ! -d "build/web/icons" ]; then
    mkdir -p build/web/icons
fi
# Copiar iconos desde web/icons si no están en build
if [ -d "web/icons" ]; then
    cp -f web/icons/*.png build/web/icons/ 2>/dev/null || true
    echo -e "${GREEN}   ✅ Iconos copiados${NC}"
fi

# Verificar tamaño del build
SIZE=$(du -sh build/web/ | cut -f1)
echo -e "${YELLOW}   Tamaño del build: $SIZE${NC}"

# Preguntar confirmación
read -p "¿Continuar con el despliegue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Despliegue cancelado.${NC}"
    exit 0
fi

# Intentar con alias 'ceres', si falla usar 'ceres.globalchat.org'
SSH_HOST="ceres"
if ! ssh -o ConnectTimeout=2 -o BatchMode=yes $SSH_HOST "echo test" >/dev/null 2>&1; then
    SSH_HOST="ceres.globalchat.org"
    echo -e "${YELLOW}⚠️  Alias 'ceres' no disponible, usando $SSH_HOST${NC}"
fi

# Crear directorio en ceres si no existe (con sudo)
echo -e "${YELLOW}📁 Creando directorio en ceres...${NC}"
ssh $SSH_HOST "sudo mkdir -p $DEST_PATH"

# Subir archivos usando rsync (a un directorio temporal primero)
TEMP_DIR="/tmp/irc_app_$$"
echo -e "${YELLOW}📤 Subiendo archivos a ceres (temporal)...${NC}"
rsync -avz --progress --delete build/web/ $SSH_HOST:$TEMP_DIR/

# Mover archivos al destino final y configurar permisos
echo -e "${YELLOW}🔐 Moviendo archivos y configurando permisos...${NC}"
ssh $SSH_HOST "sudo rm -rf $DEST_PATH/* && sudo cp -r $TEMP_DIR/* $DEST_PATH/ && sudo chown -R www-data:www-data $DEST_PATH && sudo chmod -R 755 $DEST_PATH && rm -rf $TEMP_DIR"

echo -e "${GREEN}✅ Despliegue completado!${NC}"
echo ""
echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo "   1. Configurar Nginx (ver DEPLOY_INSTRUCTIONS.md)"
echo "   2. Verificar que el sitio esté accesible"
echo "   3. Probar conexión IRC"
echo ""
echo -e "${GREEN}🌐 URL sugerida: https://irc.globalchat.org${NC}"

