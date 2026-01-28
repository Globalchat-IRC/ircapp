#!/bin/bash

# Script para limpiar estado de red del Mac sin reiniciar

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🔧  LIMPIAR RED MAC (SIN REINICIAR)                  ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# 1. Matar procesos SSH colgados
echo -e "${BLUE}1. Cerrando procesos SSH colgados...${NC}"
killall ssh 2>/dev/null && echo -e "${GREEN}✓${NC} Procesos SSH cerrados" || echo -e "${YELLOW}⚠${NC}  No había procesos SSH"
killall ssh-agent 2>/dev/null && echo -e "${GREEN}✓${NC} ssh-agent cerrado" || echo -e "${YELLOW}⚠${NC}  No había ssh-agent"
echo ""

# 2. Limpiar cache DNS
echo -e "${BLUE}2. Limpiando cache DNS...${NC}"
sudo dscacheutil -flushcache 2>/dev/null && echo -e "${GREEN}✓${NC} Cache DNS limpiado" || echo -e "${RED}✗${NC} Error al limpiar DNS"
sudo killall -HUP mDNSResponder 2>/dev/null && echo -e "${GREEN}✓${NC} mDNSResponder reiniciado" || echo -e "${RED}✗${NC} Error al reiniciar mDNSResponder"
echo ""

# 3. Reiniciar interfaz de red
echo -e "${BLUE}3. Reiniciando interfaz de red...${NC}"
INTERFACE=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
if [ -n "$INTERFACE" ]; then
    echo -e "   Interfaz detectada: ${CYAN}$INTERFACE${NC}"
    sudo ifconfig "$INTERFACE" down 2>/dev/null
    sleep 2
    sudo ifconfig "$INTERFACE" up 2>/dev/null
    echo -e "${GREEN}✓${NC} Interfaz $INTERFACE reiniciada"
else
    echo -e "${YELLOW}⚠${NC}  No se pudo detectar interfaz de red"
fi
echo ""

# 4. Reiniciar servicios de red
echo -e "${BLUE}4. Reiniciando servicios de red...${NC}"
sudo launchctl unload /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist 2>/dev/null
sleep 1
sudo launchctl load /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist 2>/dev/null
echo -e "${GREEN}✓${NC} Servicios de red reiniciados"
echo ""

# 5. Esperar a que la red se estabilice
echo -e "${BLUE}5. Esperando estabilización de red...${NC}"
sleep 3
echo -e "${GREEN}✓${NC} Red estabilizada"
echo ""

# 6. Verificar conectividad
echo -e "${BLUE}6. Verificando conectividad...${NC}"
if ping -c 1 192.168.1.42 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Conectividad a tower OK"
else
    echo -e "${RED}✗${NC} No hay conectividad a tower"
fi
echo ""

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     ✅  LIMPIEZA COMPLETADA                              ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Ahora prueba conectar:${NC}"
echo -e "${BLUE}ssh -p 62500 root@192.168.1.42${NC}\n"
