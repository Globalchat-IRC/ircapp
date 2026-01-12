#!/bin/bash

# Script para desplegar el WebSocket Gateway en ceres.globalchat.org

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Desplegando WebSocket Gateway a ceres.globalchat.org${NC}"

# Verificar que estamos en el directorio correcto
if [ ! -f "websocket-gateway.js" ]; then
    echo -e "${RED}❌ Error: websocket-gateway.js no encontrado${NC}"
    echo "Ejecuta este script desde el directorio gateway/"
    exit 1
fi

# Configuración
REMOTE_USER="${REMOTE_USER:-globalchat}"
REMOTE_HOST="ceres.globalchat.org"
REMOTE_PATH="/opt/irc-gateway"
SERVICE_NAME="irc-gateway"

# Intentar con alias 'ceres', si falla usar 'ceres.globalchat.org'
if ssh -o ConnectTimeout=5 ceres exit 2>/dev/null; then
    SSH_HOST="ceres"
else
    SSH_HOST="ceres.globalchat.org"
fi

echo -e "${YELLOW}📦 Creando directorio remoto...${NC}"
ssh ${SSH_HOST} "sudo mkdir -p ${REMOTE_PATH} && sudo chown -R ${REMOTE_USER}:${REMOTE_USER} ${REMOTE_PATH}"

echo -e "${YELLOW}📤 Subiendo archivos...${NC}"
rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '*.log' \
    ./ ${SSH_HOST}:${REMOTE_PATH}/

echo -e "${YELLOW}📥 Instalando dependencias...${NC}"
ssh ${SSH_HOST} "cd ${REMOTE_PATH} && npm install --production"

echo -e "${YELLOW}🔧 Configurando servicio systemd...${NC}"

# Crear archivo de servicio systemd
ssh ${SSH_HOST} "sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null" <<EOF
[Unit]
Description=IRC WebSocket Gateway
After=network.target

[Service]
Type=simple
User=${REMOTE_USER}
WorkingDirectory=${REMOTE_PATH}
ExecStart=/usr/bin/node websocket-gateway.js
Restart=always
RestartSec=10
Environment=PORT=4443

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}🔄 Recargando systemd y reiniciando servicio...${NC}"
ssh ${SSH_HOST} "sudo systemctl daemon-reload && sudo systemctl enable ${SERVICE_NAME} && sudo systemctl restart ${SERVICE_NAME}"

echo -e "${YELLOW}⏳ Esperando 2 segundos...${NC}"
sleep 2

echo -e "${YELLOW}📊 Estado del servicio:${NC}"
ssh ${SSH_HOST} "sudo systemctl status ${SERVICE_NAME} --no-pager -l"

echo -e "${GREEN}✅ Despliegue completado${NC}"
echo -e "${GREEN}📝 Ver logs con: ssh ${SSH_HOST} 'sudo journalctl -u ${SERVICE_NAME} -f'${NC}"






