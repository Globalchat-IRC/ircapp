#!/bin/bash

# Diagnóstico específico para conexión desde este Mac a tower

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TOWER_IP="192.168.1.42"
TOWER_PORT="62500"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🔍  DIAGNÓSTICO MAC → TOWER                          ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# 1. Información de red local
echo -e "${BLUE}${BOLD}1. Información de red local:${NC}"
LOCAL_IP=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
echo -e "   IP local: ${CYAN}$LOCAL_IP${NC}"
echo -e "   IP tower: ${CYAN}$TOWER_IP${NC}\n"

# 2. Conectividad básica
echo -e "${BLUE}${BOLD}2. Conectividad básica:${NC}"
if ping -c 2 -W 2 "$TOWER_IP" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Ping exitoso a tower\n"
else
    echo -e "${RED}✗${NC} No hay conectividad básica con tower\n"
    exit 1
fi

# 3. Verificación de puerto
echo -e "${BLUE}${BOLD}3. Verificación de puerto $TOWER_PORT:${NC}"
if nc -zv -w 3 "$TOWER_IP" "$TOWER_PORT" 2>&1 | grep -q "succeeded\|open"; then
    echo -e "${GREEN}✓${NC} Puerto $TOWER_PORT está accesible\n"
    PORT_ACCESSIBLE=true
else
    NC_OUTPUT=$(nc -zv -w 3 "$TOWER_IP" "$TOWER_PORT" 2>&1)
    echo -e "${RED}✗${NC} Puerto $TOWER_PORT NO está accesible"
    echo -e "   ${YELLOW}Error:${NC} $NC_OUTPUT\n"
    PORT_ACCESSIBLE=false
fi

# 4. Prueba SSH sin configuración
echo -e "${BLUE}${BOLD}4. Prueba SSH sin configuración local:${NC}"
SSH_OUTPUT=$(ssh -F /dev/null -o ConnectTimeout=5 -v -p "$TOWER_PORT" root@"$TOWER_IP" "echo OK" 2>&1)
if echo "$SSH_OUTPUT" | grep -q "Connection refused"; then
    echo -e "${RED}✗${NC} SSH rechaza la conexión\n"
    echo -e "${YELLOW}Detalles:${NC}"
    echo "$SSH_OUTPUT" | grep -E "(refused|timeout|denied)" | head -3
    echo ""
elif echo "$SSH_OUTPUT" | grep -q "Permission denied"; then
    echo -e "${YELLOW}⚠${NC}  Conexión establecida pero autenticación falló"
    echo -e "   ${GREEN}Esto es bueno - significa que el puerto SÍ está abierto${NC}\n"
    PORT_ACCESSIBLE=true
else
    echo -e "${GREEN}✓${NC} Conexión SSH exitosa\n"
    PORT_ACCESSIBLE=true
fi

# 5. Verificar firewall local (si es posible)
echo -e "${BLUE}${BOLD}5. Verificación de firewall local:${NC}"
if [ -f /usr/libexec/ApplicationFirewall/socketfilterfw ]; then
    FW_STATE=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "No accesible")
    echo -e "   Estado firewall: ${CYAN}$FW_STATE${NC}\n"
else
    echo -e "   ${YELLOW}No se pudo verificar firewall${NC}\n"
fi

# 6. Análisis y recomendaciones
echo -e "${BLUE}${BOLD}6. Análisis:${NC}\n"

if [ "$PORT_ACCESSIBLE" = false ]; then
    echo -e "${YELLOW}⚠${NC}  El puerto $TOWER_PORT está rechazando conexiones desde este Mac.\n"
    echo -e "${YELLOW}Posibles causas:${NC}"
    echo -e "  1. ${CYAN}Firewall en tower bloqueando esta IP${NC}"
    echo -e "     • Verificar en tower: ${GREEN}sudo iptables -L -n | grep $LOCAL_IP${NC}"
    echo -e "     • Verificar: ${GREEN}sudo ufw status | grep $LOCAL_IP${NC}"
    echo -e ""
    echo -e "  2. ${CYAN}SSH configurado para rechazar esta IP${NC}"
    echo -e "     • Verificar en tower: ${GREEN}sudo grep -i deny /etc/ssh/sshd_config${NC}"
    echo -e "     • Verificar: ${GREEN}sudo grep -i $LOCAL_IP /etc/hosts.deny${NC}"
    echo -e ""
    echo -e "  3. ${CYAN}Firewall local del Mac${NC}"
    echo -e "     • Verificar en Preferencias del Sistema → Seguridad → Firewall"
    echo -e ""
    echo -e "  4. ${CYAN}Restricción de red/VLAN${NC}"
    echo -e "     • Este Mac puede estar en una VLAN diferente"
    echo -e "     • Verificar configuración de red\n"
    
    echo -e "${CYAN}${BOLD}Solución recomendada:${NC}"
    echo -e "  En tower, verificar y permitir esta IP:"
    echo -e "  ${GREEN}sudo ufw allow from $LOCAL_IP to any port $TOWER_PORT${NC}"
    echo -e "  ${GREEN}sudo iptables -I INPUT -s $LOCAL_IP -p tcp --dport $TOWER_PORT -j ACCEPT${NC}\n"
else
    echo -e "${GREEN}✓${NC} El puerto está accesible. El problema puede ser de autenticación.\n"
fi

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📋  DIAGNÓSTICO COMPLETADO                           ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
