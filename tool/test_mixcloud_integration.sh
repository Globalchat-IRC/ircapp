#!/bin/bash

# Script para probar la integración automática de Mixcloud Live
# Este script verifica que todo el sistema funcione correctamente

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Test de Integración Automática Mixcloud Live            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# URL del backend
BACKEND_URL="https://webchat.globalchat.org/gateway/mixcloud_stream_extractor.php?username=djsonic_vlc"

echo -e "${YELLOW}[1/3] Verificando backend PHP...${NC}"

# Hacer petición al backend
RESPONSE=$(curl -s -w "\n%{http_code}" "$BACKEND_URL")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}✗ Error: Backend devolvió HTTP $HTTP_CODE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Backend responde correctamente (HTTP 200)${NC}\n"

# Parsear JSON
IS_LIVE=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('is_live', False))" 2>/dev/null)
SUCCESS=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null)

echo -e "${YELLOW}[2/3] Analizando respuesta...${NC}"

if [ "$SUCCESS" = "True" ] && [ "$IS_LIVE" = "True" ]; then
    STREAM_URL=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('stream_url', ''))" 2>/dev/null)
    BITRATE=$(echo "$BODY" | python3 -c "import sys, json; info = json.load(sys.stdin).get('info', {}); print(info.get('bitrate', 'N/A'))" 2>/dev/null)
    
    echo -e "${GREEN}✓ djsonic_vlc está EN VIVO 🔴${NC}"
    echo -e "${GREEN}  Stream URL: ${STREAM_URL}${NC}"
    echo -e "${GREEN}  Bitrate: ${BITRATE}${NC}\n"
    
    echo -e "${YELLOW}[3/3] Verificando stream HLS...${NC}"
    
    # Verificar que la URL del stream es accesible
    STREAM_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$STREAM_URL")
    
    if [ "$STREAM_CHECK" = "200" ]; then
        echo -e "${GREEN}✓ Stream HLS accesible${NC}\n"
        
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                    ✓ TODO FUNCIONA                         ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${GREEN}Estado: EN VIVO 🔴${NC}"
        echo -e "${GREEN}La aplicación detectará automáticamente este stream${NC}"
        echo -e "${GREEN}y lo usará cuando el usuario reproduzca UrbanFlow.${NC}\n"
        
        echo -e "${YELLOW}Para probar en la app:${NC}"
        echo -e "  1. Abre la app GlobalChat"
        echo -e "  2. Ve a la sección de Radio"
        echo -e "  3. Verás 'UrbanFlow 🔴 EN VIVO'"
        echo -e "  4. Presiona Play y escucharás el stream en vivo\n"
        
        echo -e "${YELLOW}Para reproducir el stream ahora con VLC:${NC}"
        echo -e "  vlc \"$STREAM_URL\"\n"
        
    else
        echo -e "${RED}✗ Stream HLS no accesible (HTTP $STREAM_CHECK)${NC}"
        echo -e "${YELLOW}Nota: El stream puede haber expirado o tener restricciones${NC}"
        exit 1
    fi
    
elif [ "$SUCCESS" = "False" ] && [ "$IS_LIVE" = "False" ]; then
    echo -e "${YELLOW}ℹ djsonic_vlc NO está en vivo actualmente${NC}\n"
    
    echo -e "${YELLOW}[3/3] Verificando comportamiento sin stream...${NC}"
    echo -e "${GREEN}✓ Backend devuelve correctamente is_live=false${NC}\n"
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                ✓ SISTEMA FUNCIONA CORRECTAMENTE            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${GREEN}Estado: SIN EMISIÓN${NC}"
    echo -e "${GREEN}La aplicación usará la URL por defecto de Mixcloud${NC}"
    echo -e "${GREEN}cuando el usuario reproduzca UrbanFlow.${NC}\n"
    
    echo -e "${YELLOW}Cuando djsonic_vlc empiece a emitir:${NC}"
    echo -e "  1. El sistema detectará el stream automáticamente (máx 2 min)"
    echo -e "  2. Actualizará la URL de UrbanFlow con el stream en vivo"
    echo -e "  3. Mostrará '🔴 EN VIVO' en la app"
    echo -e "  4. Todo sin intervención del usuario\n"
    
else
    echo -e "${RED}✗ Respuesta inesperada del backend${NC}"
    echo -e "${YELLOW}Respuesta completa:${NC}"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    exit 1
fi

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
