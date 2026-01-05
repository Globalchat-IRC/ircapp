#!/bin/bash

# Script para desplegar IRC App v3.0.0 en ceres.globalchat.org
# Uso: ./deploy_to_ceres.sh [usuario] [ruta_destino]

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
if [ -z "$1" ]; then
    echo -e "${YELLOW}⚠️  No se especificó usuario SSH${NC}"
    read -p "Ingresa tu usuario SSH en ceres: " USER
    if [ -z "$USER" ]; then
        echo -e "${RED}❌ Error: Se requiere un usuario SSH${NC}"
        exit 1
    fi
else
    USER=$1
fi

DEST_PATH=${2:-"/var/www/irc_app"}  # Ruta por defecto

echo -e "${YELLOW}📦 Preparando archivos...${NC}"
echo "   Usuario: $USER"
echo "   Destino: $DEST_PATH"

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

# Crear directorio en ceres si no existe
echo -e "${YELLOW}📁 Creando directorio en ceres...${NC}"
ssh $USER@ceres.globalchat.org "mkdir -p $DEST_PATH"

# Subir archivos usando rsync
echo -e "${YELLOW}📤 Subiendo archivos a ceres...${NC}"
rsync -avz --progress --delete build/web/ $USER@ceres.globalchat.org:$DEST_PATH/

# Verificar permisos
echo -e "${YELLOW}🔐 Configurando permisos...${NC}"
ssh $USER@ceres.globalchat.org "sudo chown -R www-data:www-data $DEST_PATH && sudo chmod -R 755 $DEST_PATH"

echo -e "${GREEN}✅ Despliegue completado!${NC}"
echo ""
echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo "   1. Configurar Nginx (ver DEPLOY_INSTRUCTIONS.md)"
echo "   2. Verificar que el sitio esté accesible"
echo "   3. Probar conexión IRC"
echo ""
echo -e "${GREEN}🌐 URL sugerida: https://irc.globalchat.org${NC}"

