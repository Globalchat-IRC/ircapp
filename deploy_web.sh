#!/bin/bash
# Build Flutter web con ofuscación + deploy a ceres.globalchat.org
#
# Uso:
#   ./deploy_web.sh              # Build + deploy
#   ./deploy_web.sh --build-only # Solo compilar
#   ./deploy_web.sh --deploy-only # Solo deploy (asume que build/ ya existe)
#
# Requiere: Flutter SDK instalado, acceso SSH a ceres.globalchat.org

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REMOTE_USER="globalchat"
REMOTE_HOST="ceres.globalchat.org"
REMOTE_WEB="/var/www/irc_app"  # Ruta del web server en ceres
BUILD_DIR="build/web"

DO_BUILD=true
DO_DEPLOY=true

for arg in "$@"; do
  case $arg in
    --build-only)  DO_DEPLOY=false ;;
    --deploy-only) DO_BUILD=false ;;
    --help|-h)
      echo "Uso: $0 [--build-only|--deploy-only]"
      exit 0 ;;
  esac
done

# === BUILD ===
if [ "$DO_BUILD" = true ]; then
  echo -e "${YELLOW}🔨 Compilando Flutter web...${NC}"

  # Generar package_info.json para web (package_info_plus lo necesita)
  VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
  echo "{\"version\": \"${VERSION}\", \"build_number\": \"1\"}" > web/package_info.json

  flutter build web \
    -O4 \
    --no-source-maps \
    --release \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=true

  echo -e "${GREEN}✅ Build completado en: $BUILD_DIR${NC}"
  echo -e "${YELLOW}📋 Debug info en: $BUILD_DIR/debug_info${NC}"
fi

# === DEPLOY ===
if [ "$DO_DEPLOY" = true ]; then
  if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${RED}❌ Error: $BUILD_DIR no existe. Ejecuta sin --deploy-only primero.${NC}"
    exit 1
  fi

  echo -e "${YELLOW}📤 Desplegando a $REMOTE_HOST...${NC}"

  ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo mkdir -p ${REMOTE_WEB} && sudo chown -R ${REMOTE_USER}:${REMOTE_USER} ${REMOTE_WEB}"

  rsync -avz --delete \
    --exclude='debug_info/' \
    "$BUILD_DIR/" ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WEB}/

  echo -e "${GREEN}✅ Desplegado en ${REMOTE_HOST}${NC}"
  echo -e "${GREEN}🌐 Webchat: https://${REMOTE_HOST}${NC}"

  # Guardar debug_info de forma segura
  DEBUG_BACKUP="$HOME/Documents/backups/webchat_debug_$(date +%Y%m%d).zip"
  if [ -d "$BUILD_DIR/debug_info" ]; then
    zip -r "$DEBUG_BACKUP" "$BUILD_DIR/debug_info/" 2>/dev/null && \
      echo -e "${YELLOW}🔒 Debug info guardado en: $DEBUG_BACKUP${NC}" || \
      echo -e "${YELLOW}⚠️  No se pudo guardar debug info${NC}"
  fi
fi

echo -e "${GREEN}🎉 Listo${NC}"
