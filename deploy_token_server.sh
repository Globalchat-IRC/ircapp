#!/bin/bash
# Deploy token_server (LiveKit) a ceres.globalchat.org
#
# Uso: ./deploy_token_server.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REMOTE_USER="globalchat"
REMOTE_HOST="ceres.globalchat.org"
REMOTE_PATH="~/irc_app/token_server"

echo -e "${YELLOW}📦 Desplegando token_server a ${REMOTE_HOST}...${NC}"

# Verificar .env local
if [ ! -f ".env" ]; then
  echo -e "${RED}⚠️  No se encontró archivo .env${NC}"
  echo "Crea token_server/.env con:"
  echo "  LIVEKIT_API_KEY=tu_key"
  echo "  LIVEKIT_API_SECRET=tu_secret"
  exit 1
fi

# Subir archivos (excepto node_modules y .env)
rsync -avz --delete \
  --exclude='node_modules/' \
  --exclude='.env' \
  ./ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/

# Subir .env por separado (seguro)
scp .env ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/.env

# Instalar dependencias y reiniciar
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && npm install --production"

# Reiniciar con docker-compose si está disponible
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && docker compose down && docker compose up -d" 2>/dev/null || \
  echo -e "${YELLOW}⚠️  Docker no disponible, reinicia manualmente el token server${NC}"

echo -e "${GREEN}✅ token_server desplegado${NC}"
