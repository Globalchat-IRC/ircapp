#!/bin/bash

# Script para desplegar el extractor de Mixcloud al servidor
# Este script copia el archivo PHP al servidor de GlobalChat

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Desplegando Mixcloud Stream Extractor ===${NC}\n"

# Configuración del servidor
SERVER_USER="root"
SERVER_HOST="webchat.globalchat.org"
REMOTE_PATH="/var/www/html/webchat.globalchat.org/gateway"
LOCAL_FILE="gateway/mixcloud_stream_extractor.php"

# Verificar que el archivo local existe
if [ ! -f "$LOCAL_FILE" ]; then
    echo -e "${RED}Error: No se encuentra el archivo $LOCAL_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Copiando archivo al servidor...${NC}"

# Copiar archivo al servidor
scp "$LOCAL_FILE" "${SERVER_USER}@${SERVER_HOST}:${REMOTE_PATH}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Archivo copiado exitosamente${NC}"
else
    echo -e "${RED}✗ Error al copiar el archivo${NC}"
    exit 1
fi

# Establecer permisos correctos
echo -e "${YELLOW}Estableciendo permisos...${NC}"
ssh "${SERVER_USER}@${SERVER_HOST}" "chmod 644 ${REMOTE_PATH}/mixcloud_stream_extractor.php && chown www-data:www-data ${REMOTE_PATH}/mixcloud_stream_extractor.php"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Permisos establecidos correctamente${NC}"
else
    echo -e "${RED}✗ Error al establecer permisos${NC}"
    exit 1
fi

# Probar el endpoint
echo -e "\n${YELLOW}Probando el endpoint...${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" "https://webchat.globalchat.org/gateway/mixcloud_stream_extractor.php?username=djsonic_vlc")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Endpoint funcionando correctamente${NC}"
    echo -e "\n${YELLOW}Respuesta:${NC}"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
else
    echo -e "${RED}✗ Error HTTP $HTTP_CODE${NC}"
    echo "$BODY"
fi

echo -e "\n${GREEN}=== Despliegue completado ===${NC}"
echo -e "\n${YELLOW}URL del servicio:${NC}"
echo "https://webchat.globalchat.org/gateway/mixcloud_stream_extractor.php?username=djsonic_vlc"
